-- Quanto do gasto aparece na fonte com um partido diferente do real na data da despesa,
-- por tipo de divergência. A regra de classificação está em int_despesas_classificadas.
select
    classificacao,
    count(*)                                                              as lancamentos,
    round(sum(valor_liquido) / 1e6, 1)                                    as valor_milhoes,
    round(100 * sum(valor_liquido) / sum(sum(valor_liquido)) over (), 1)  as pct_valor
from {{ ref('int_despesas_classificadas') }}
where tipo_beneficiario = 'deputado'
group by classificacao
