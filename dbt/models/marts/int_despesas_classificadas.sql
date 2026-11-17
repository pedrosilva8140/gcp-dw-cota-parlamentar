{{ config(materialized='ephemeral') }}

-- Um registro por lançamento, com o partido real na data (SCD2) e a classificação
-- da divergência em relação ao partido da fonte (retroativo).
-- Fonte única da regra: usado pelo rpt_divergencia_partido e pelo rpt_painel_despesas.
with lancamentos as (
    select
        f.lancamento_id,
        f.deputado_sk,
        f.fornecedor_sk,
        f.tipo_despesa_sk,
        f.data_competencia,
        f.tipo_beneficiario,
        f.valor_liquido,
        f.partido_na_despesa as partido_fonte,
        d.partido            as partido_real,
        d.nome               as deputado,
        d.uf
    from {{ ref('fct_despesas') }} as f
    inner join {{ ref('dim_deputado') }} as d using (deputado_sk)
)

select
    l.*,
    case
        when l.tipo_beneficiario != 'deputado'          then 'lideranca'
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
