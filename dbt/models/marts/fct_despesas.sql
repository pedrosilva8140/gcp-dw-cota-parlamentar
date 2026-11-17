-- Fato de despesas da CEAP. Grão: um lançamento do arquivo de origem.
-- Deputado resolvido "ponto no tempo" contra a dim_deputado (SCD2).
{{ config(
    materialized='table',
    partition_by={'field': 'data_competencia', 'data_type': 'date', 'granularity': 'month'},
    cluster_by=['tipo_despesa_sk', 'deputado_sk']
) }}

with despesas as (
    select
        *,
        coalesce(data_emissao, date(ano, mes, 1)) as data_referencia
    from {{ ref('stg_despesas') }}
),

versoes as (
    select deputado_sk, deputado_id, valido_de, valido_ate
    from {{ ref('dim_deputado') }}
    where deputado_id is not null
)

select
    -- chaves
    d.lancamento_id,
    case
        when d.tipo_beneficiario = 'lideranca' then -1
        else v.deputado_sk
    end                                                     as deputado_sk,
    if(d.fornecedor_documento is null, -1, farm_fingerprint(d.fornecedor_documento)) as fornecedor_sk,
    d.subcota_id                                            as tipo_despesa_sk,
    d.data_emissao,
    date(d.ano, d.mes, 1)                                   as data_competencia,

    -- atributos degenerados (do próprio lançamento)
    d.despesa_id,
    d.tipo_beneficiario,
    d.beneficiario_id,
    d.partido_na_despesa,   -- retroativo na fonte; mantido para comparação com o SCD2
    d.ano                                                   as ano_competencia,
    d.mes                                                   as mes_competencia,
    d.parcela,
    d.trecho,
    d.url_documento,

    -- métricas (negativos são estornos)
    d.valor_documento,
    d.valor_glosa,
    d.valor_liquido

from despesas as d
left join versoes as v
    on  d.deputado_id = v.deputado_id
    and d.data_referencia >= v.valido_de
    and d.data_referencia <  coalesce(v.valido_ate, date '9999-12-31')
