"""Ingestão da Cota Parlamentar (CEAP) e dos deputados para o BigQuery (camada raw).

Princípio: a ingestão guarda o dado como a fonte entrega. Filtros e regras ficam no dbt.
"""

import argparse
import csv
import gzip
import io
import json
import os
import time
import urllib.error
import urllib.request
import zipfile
from datetime import UTC, datetime

from google.cloud import bigquery, storage

PROJETO = os.environ.get("GOOGLE_CLOUD_PROJECT", "portfolio-de-pedro")
BUCKET = os.environ.get("BUCKET", f"{PROJETO}-cota-raw")
URL_DESPESAS = "https://www.camara.leg.br/cotas/Ano-{ano}.csv.zip"
URL_API = "https://dadosabertos.camara.leg.br/api/v2"
URL_DEPUTADOS = f"{URL_API}/deputados?itens=100&ordem=ASC&ordenarPor=nome"
URL_HISTORICO = f"{URL_API}/deputados/{{id}}/historico"
ERROS_TEMPORARIOS = {429, 500, 502, 503, 504}


def hoje() -> str:
    return datetime.now(UTC).date().isoformat()


def baixar(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "portfolio-de/1.0"})
    with urllib.request.urlopen(req, timeout=300) as resp:
        return resp.read()


def baixar_json(url: str, tentativas: int = 4) -> dict:
    """Baixa JSON tentando de novo, com espera crescente, em erros temporários."""
    for tentativa in range(tentativas):
        try:
            return json.loads(baixar(url))
        except urllib.error.HTTPError as erro:
            if erro.code not in ERROS_TEMPORARIOS or tentativa == tentativas - 1:
                raise
        except urllib.error.URLError:
            if tentativa == tentativas - 1:
                raise
        time.sleep(2**tentativa)
    raise RuntimeError(f"Falha ao baixar {url}")


def carregar_tabela(bq: bigquery.Client, linhas: list[dict], tabela: str, schema: list) -> None:
    config = bigquery.LoadJobConfig(
        schema=schema,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,  # recarga idempotente
    )
    bq.load_table_from_json(linhas, f"{PROJETO}.raw.{tabela}", job_config=config).result()
    print(f"{PROJETO}.raw.{tabela}: {len(linhas)} linhas")


# ---------------------------------------------------------------- despesas
def schema_do_cabecalho(csv_bytes: bytes) -> list[bigquery.SchemaField]:
    """Camada raw: todas as colunas como STRING, na ordem do arquivo. A tipagem acontece no dbt."""
    primeira_linha = csv_bytes.split(b"\n", 1)[0].decode("utf-8-sig")
    colunas = next(csv.reader([primeira_linha], delimiter=";"))
    return [bigquery.SchemaField(coluna.strip(), "STRING") for coluna in colunas]


def carregar_despesas(ano: int, gcs: storage.Client, bq: bigquery.Client) -> None:
    conteudo = baixar(URL_DESPESAS.format(ano=ano))
    with zipfile.ZipFile(io.BytesIO(conteudo)) as arquivo_zip:
        csv_bytes = arquivo_zip.read(arquivo_zip.namelist()[0])

    # O BigQuery não lê .zip, mas lê .gz: recomprimir reduz o upload em ~10x
    blob = gcs.bucket(BUCKET).blob(f"despesas/ano={ano}/despesas.csv.gz")
    blob.upload_from_string(gzip.compress(csv_bytes), content_type="application/gzip")

    config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.CSV,
        field_delimiter=";",
        skip_leading_rows=1,
        allow_quoted_newlines=True,
        schema=schema_do_cabecalho(csv_bytes),
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
    )
    tabela = f"{PROJETO}.raw.despesas_{ano}"
    bq.load_table_from_uri(f"gs://{BUCKET}/{blob.name}", tabela, job_config=config).result()
    print(f"{tabela}: {bq.get_table(tabela).num_rows} linhas")


# ---------------------------------------------------------------- deputados (estado atual)
def carregar_deputados(bq: bigquery.Client) -> None:
    """Lê a API página a página (seguindo o link 'next')."""
    url, linhas = URL_DEPUTADOS, []
    while url:
        resposta = baixar_json(url)
        for d in resposta["dados"]:
            linhas.append({
                "id": d["id"],
                "nome": d["nome"],
                "partido": d["siglaPartido"],
                "uf": d["siglaUf"],
                "id_legislatura": d["idLegislatura"],
                "data_carga": hoje(),
            })
        url = next((link["href"] for link in resposta["links"] if link["rel"] == "next"), None)

    carregar_tabela(bq, linhas, "deputados", [
        bigquery.SchemaField("id", "INTEGER"),
        bigquery.SchemaField("nome", "STRING"),
        bigquery.SchemaField("partido", "STRING"),
        bigquery.SchemaField("uf", "STRING"),
        bigquery.SchemaField("id_legislatura", "INTEGER"),
        bigquery.SchemaField("data_carga", "DATE"),
    ])


# ---------------------------------------------------------------- histórico (log de eventos)
def ids_de_deputados(bq: bigquery.Client) -> list[int]:
    """Todos os deputados com despesa (2019-2026) mais os atuais da API."""
    sql = f"""
        select distinct safe_cast(ideCadastro as int64) as id
        from `{PROJETO}.raw.despesas_*`
        where ideCadastro != ''
        union distinct
        select id from `{PROJETO}.raw.deputados`
    """
    return sorted(linha.id for linha in bq.query(sql).result() if linha.id is not None)


def carregar_historico(bq: bigquery.Client) -> None:
    """Eventos de cada deputado (posse, troca de partido, afastamento...), sem filtros."""
    ids = ids_de_deputados(bq)
    linhas = []
    for posicao, deputado_id in enumerate(ids, start=1):
        for evento in baixar_json(URL_HISTORICO.format(id=deputado_id))["dados"]:
            linhas.append({
                "deputado_id": deputado_id,
                "data_hora": evento.get("dataHora"),
                "sigla_partido": evento.get("siglaPartido"),
                "sigla_uf": evento.get("siglaUf"),
                "id_legislatura": evento.get("idLegislatura"),
                "situacao": evento.get("situacao"),
                "condicao_eleitoral": evento.get("condicaoEleitoral"),
                "descricao_status": evento.get("descricaoStatus"),
                "nome": evento.get("nome"),
                "nome_eleitoral": evento.get("nomeEleitoral"),
                "data_carga": hoje(),
            })
        if posicao % 100 == 0:
            print(f"  histórico: {posicao}/{len(ids)} deputados")
        time.sleep(0.1)  # pausa curta: API pública

    carregar_tabela(bq, linhas, "deputados_historico", [
        bigquery.SchemaField("deputado_id", "INTEGER"),
        bigquery.SchemaField("data_hora", "STRING"),
        bigquery.SchemaField("sigla_partido", "STRING"),
        bigquery.SchemaField("sigla_uf", "STRING"),
        bigquery.SchemaField("id_legislatura", "INTEGER"),
        bigquery.SchemaField("situacao", "STRING"),
        bigquery.SchemaField("condicao_eleitoral", "STRING"),
        bigquery.SchemaField("descricao_status", "STRING"),
        bigquery.SchemaField("nome", "STRING"),
        bigquery.SchemaField("nome_eleitoral", "STRING"),
        bigquery.SchemaField("data_carga", "DATE"),
    ])


# ---------------------------------------------------------------- execução
def main() -> None:
    parser = argparse.ArgumentParser(description="Ingestão da CEAP para o BigQuery")
    parser.add_argument("--anos", nargs="+", type=int, default=[datetime.now(UTC).year])
    parser.add_argument(
        "--etapas",
        nargs="+",
        choices=["despesas", "deputados", "historico"],
        default=["despesas", "deputados", "historico"],
    )
    args = parser.parse_args()

    bq = bigquery.Client(project=PROJETO)
    if "despesas" in args.etapas:
        gcs = storage.Client(project=PROJETO)
        for ano in args.anos:
            carregar_despesas(ano, gcs, bq)
    if "deputados" in args.etapas:
        carregar_deputados(bq)
    if "historico" in args.etapas:
        carregar_historico(bq)


if __name__ == "__main__":
    main()
