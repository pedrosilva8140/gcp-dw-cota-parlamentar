-- Calendário do menor ao maior data_emissao encontrado nas despesas.
with limites as (
    select min(data_emissao) as inicio, max(data_emissao) as fim
    from {{ ref('stg_despesas') }}
)

select
    data,
    extract(year from data)                     as ano,
    extract(quarter from data)                  as trimestre,
    extract(month from data)                    as mes,
    format_date('%Y-%m', data)                  as ano_mes,
    extract(dayofweek from data)                as dia_semana,  -- 1 = domingo
    extract(dayofweek from data) in (1, 7)      as eh_fim_de_semana
from limites, unnest(generate_date_array(inicio, fim)) as data
