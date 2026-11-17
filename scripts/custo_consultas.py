"""Mede quantos bytes cada estratégia de consulta lê no BigQuery.

Mesma pergunta (gasto total de 2023) respondida de 4 jeitos. Executa de verdade,
sem cache, porque o dry run não considera o efeito do cluster.
"""

from google.cloud import bigquery

PROJETO = "portfolio-de-pedro"
bq = bigquery.Client(project=PROJETO)

# Um tipo de despesa frequente, para o filtro de cluster
tipo = next(iter(bq.query("""
    select tipo_despesa_sk, tipo_despesa
    from marts.dim_tipo_despesa
    where regexp_contains(upper(tipo_despesa), r'PASSAGE')
    limit 1
""").result()))

FILTRO_2023 = "data_competencia between '2023-01-01' and '2023-12-31'"
CONSULTAS = [
    ("1. Staging (view sobre a raw)",
     "select sum(valor_liquido) from staging.stg_despesas where ano = 2023"),
    ("2. Fato, filtro em coluna comum",
     "select sum(valor_liquido) from marts.fct_despesas where ano_competencia = 2023"),
    ("3. Fato, filtro na partição",
     f"select sum(valor_liquido) from marts.fct_despesas where {FILTRO_2023}"),
    ("4. Fato, partição + cluster",
     f"select sum(valor_liquido) from marts.fct_despesas "
     f"where {FILTRO_2023} and tipo_despesa_sk = {tipo.tipo_despesa_sk}"),
]

config = bigquery.QueryJobConfig(use_query_cache=False)
print(f"Filtro de cluster: tipo_despesa_sk = {tipo.tipo_despesa_sk} ({tipo.tipo_despesa})\n")
print(f"{'Consulta':<34} {'Processado':>12} {'Cobrado':>10}")
for nome, sql in CONSULTAS:
    job = bq.query(sql, job_config=config)
    job.result()
    processado = job.total_bytes_processed / 1e6
    cobrado = (job.total_bytes_billed or 0) / 1e6
    print(f"{nome:<34} {processado:>9.1f} MB {cobrado:>7.0f} MB")
