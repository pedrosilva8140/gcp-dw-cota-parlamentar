-- Compara o partido da fonte (retroativo) com o partido real na data da despesa (SCD2)
-- e classifica cada divergência: renomeação, fusão/incorporação ou troca real.
with lancamentos as (
    select
        f.valor_liquido,
        f.partido_na_despesa as partido_fonte,
        d.partido            as partido_real
    from {{ ref('fct_despesas') }} as f
    inner join {{ ref('dim_deputado') }} as d using (deputado_sk)
    where f.tipo_beneficiario = 'deputado'
),

classificados as (
    select
        l.*,
        case
            when l.partido_fonte is null                    then 'sem_partido_na_fonte'
            when l.partido_fonte = l.partido_real           then 'igual'
            when s.tipo = 'renomeacao'                      then 'renomeacao'
            when s.tipo in ('fusao', 'incorporacao')        then 'fusao_ou_incorporacao'
            else 'troca_real'
        end as classificacao
    from lancamentos as l
    left join {{ ref('partidos_sucessao') }} as s
        on  s.sigla_antiga = l.partido_real   -- na data, o deputado estava no partido antigo
        and s.sigla_nova   = l.partido_fonte  -- e a fonte mostra o sucessor
)

select
    classificacao,
    count(*)                                                              as lancamentos,
    round(sum(valor_liquido) / 1e6, 1)                                    as valor_milhoes,
    round(100 * sum(valor_liquido) / sum(sum(valor_liquido)) over (), 1)  as pct_valor
from classificados
group by classificacao
