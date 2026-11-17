{{ config(
    materialized='table',
    partition_by={'field': 'data_competencia', 'data_type': 'date', 'granularity': 'month'},
    cluster_by=['partido_real', 'tipo_despesa']
) }}

-- Tabela larga para o Looker Studio: um lançamento por linha, já com nomes legíveis.
-- Toda regra de negócio fica no dbt; o dashboard só visualiza.
select
    c.lancamento_id,
    c.data_competencia,
    c.tipo_beneficiario,
    c.deputado,
    c.uf,
    c.partido_real,
    c.partido_fonte,
    c.classificacao,
    c.classificacao not in ('igual', 'lideranca') as eh_divergente,
    t.tipo_despesa,
    fo.tipo_pessoa as tipo_fornecedor,
    case
        when fo.fornecedor_sk = -1   then fo.nome                     -- 'Não informado'
        when fo.tipo_pessoa = 'PJ'   then fo.nome
        when fo.tipo_pessoa = 'PF'   then 'Pessoa física (oculto)'    -- LGPD
        else 'Outro (oculto)'                                         -- documento não identificável
    end as fornecedor,
    c.valor_liquido
from {{ ref('int_despesas_classificadas') }} as c
inner join {{ ref('dim_tipo_despesa') }} as t using (tipo_despesa_sk)
inner join {{ ref('dim_fornecedor') }}   as fo using (fornecedor_sk)
