"""Ingestão da Cota Parlamentar (CEAP) e do cadastro de deputados para o BigQuery (camada raw)."""

import argparse
import csv
import gzip
import io
import json
import os
import urllib.request
import zipfile
from datetime import UTC, datetime

from google.cloud import bigquery, storage

PROJETO = os.environ.get("GOOGLE_CLOUD_PROJECT", "portfolio-de-pedro")
BUCKET = os.environ.get("BUCKET", f"{PROJETO}-cota-raw")
URL_DESPESAS = "https://www.camara.leg.br/cotas/Ano-{ano}.csv.zip"
URL_DEPUTADOS = "https://dadosabertos.camara.leg.br/api/v2/deputados?itens=100&ordem=ASC&ordenarPor=nome"


def baixar(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "portfolio-de/1.0"})
    with urllib.request.urlopen(req, timeout=300) as resp:
        return resp.read()


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
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,  # recarga idempotente
    )
    tabela = f"{PROJETO}.raw.despesas_{ano}"
    bq.load_table_from_uri(f"gs://{BUCKET}/{blob.name}", tabela, job_config=config).result()
    print(f"{tabela}: {bq.get_table(tabela).num_rows} linhas")


def carregar_deputados(bq: bigquery.Client) -> None:
    """Lê a API página a página (seguindo o link 'next') e substitui raw.deputados."""
    url, linhas = URL_DEPUTADOS, []
    hoje = datetime.now(UTC).date().isoformat()
    while url:
        resposta = json.loads(baixar(url))
        for d in resposta["dados"]:
            linhas.append({
                "id": d["id"],
                "nome": d["nome"],
                "partido": d["siglaPartido"],
                "uf": d["siglaUf"],
                "id_legislatura": d["idLegislatura"],
                "data_carga": hoje,
            })
        url = next((link["href"] for link in resposta["links"] if link["rel"] == "next"), None)

    config = bigquery.LoadJobConfig(
        schema=[
            bigquery.SchemaField("id", "INTEGER"),
            bigquery.SchemaField("nome", "STRING"),
            bigquery.SchemaField("partido", "STRING"),
            bigquery.SchemaField("uf", "STRING"),
            bigquery.SchemaField("id_legislatura", "INTEGER"),
            bigquery.SchemaField("data_carga", "DATE"),
        ],
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
    )
    tabela = f"{PROJETO}.raw.deputados"
    bq.load_table_from_json(linhas, tabela, job_config=config).result()
    print(f"{tabela}: {len(linhas)} deputados")


def main() -> None:
    parser = argparse.ArgumentParser(description="Ingestão da CEAP para o BigQuery")
    parser.add_argument("--anos", nargs="+", type=int, default=[datetime.now(UTC).year])
    args = parser.parse_args()

    gcs = storage.Client(project=PROJETO)
    bq = bigquery.Client(project=PROJETO)
    for ano in args.anos:
        carregar_despesas(ano, gcs, bq)
    carregar_deputados(bq)


if __name__ == "__main__":
    main()