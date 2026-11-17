"""Mede quantos bytes cada estratégia de consulta lê no BigQuery.

Mesma pergunta (gasto de 2023) respondida de vários jeitos. Para cada consulta mostra:
- a estimativa do dry run (usa só metadados de partição: é o pior caso)
- o que foi realmente processado (inclui a poda de colunas e de blocos)
- o que foi cobrado (mínimo de 10 MB por consulta)
"""

from google.cloud import bigquery

PROJETO = "portfolio-de-pedro"
bq = bigquery.Client(project=PROJETO)


def um_valor(sql: str):
    return next(iter(bq.query(sql).result()))


tipo = um_valor("""
    select tipo_despesa_sk, tipo_despesa from marts.dim_tipo_despesa
    where regexp_contains(upper(tipo_despesa), r'PASSAGE') limit 1
""")
fornecedor = um_valor("""
    select fornecedor_sk, nome from marts.dim_fornecedor
    where fornecedor_sk != -1 order by lancamentos desc limit 1
""")

FILTRO_2023 = "data_competencia between '2023-01-01' and '2023-12-31'"
CONSULTAS = [
    ("1. Staging, só valor",
     "select sum(valor_liquido) from staging.stg_despesas where ano = 2023"),
    ("1b. Staging, usando lancamento_id",
     "select count(distinct lancamento_id) from staging.stg_despesas where ano = 2023"),
    ("2. Fato, coluna correlacionada",
     "select sum(valor_liquido) from marts.fct_despesas where ano_competencia = 2023"),
    ("3. Fato, filtro na partição",
     f"select sum(valor_liquido) from marts.fct_despesas where {FILTRO_2023}"),
    ("4. Fato, partição + cluster",
     (f"select sum(valor_liquido) from marts.fct_despesas "
      f"where {FILTRO_2023} and tipo_despesa_sk = {tipo.tipo_despesa_sk}")),
    ("5. Fato, coluna não correlacionada",
     (f"select sum(valor_liquido) from marts.fct_despesas "
      f"where fornecedor_sk = {fornecedor.fornecedor_sk}")),
]

print(f"Cluster: tipo_despesa_sk = {tipo.tipo_despesa_sk} ({tipo.tipo_despesa})")
print(f"Não correlacionada: fornecedor_sk = {fornecedor.fornecedor_sk} ({fornecedor.nome})\n")
print(f"{'Consulta':<36} {'Estimado':>10} {'Processado':>11} {'Cobrado':>9}")

for nome, sql in CONSULTAS:
    estimativa = bq.query(sql, job_config=bigquery.QueryJobConfig(dry_run=True, use_query_cache=False))
    job = bq.query(sql, job_config=bigquery.QueryJobConfig(use_query_cache=False))
    job.result()
    print(
        f"{nome:<36} "
        f"{estimativa.total_bytes_processed / 1e6:>7.1f} MB "
        f"{job.total_bytes_processed / 1e6:>8.1f} MB "
        f"{(job.total_bytes_billed or 0) / 1e6:>6.0f} MB"
    )