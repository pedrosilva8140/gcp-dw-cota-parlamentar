-- O join ponto no tempo não pode multiplicar linhas: o fato deve ter
-- exatamente o mesmo número de linhas da staging (1 linha por lançamento).
with contagens as (
    select
        (select count(*) from {{ ref('fct_despesas') }}) as fato,
        (select count(*) from {{ ref('stg_despesas') }}) as staging
)

select *
from contagens
where fato != staging
