-- Limpeza e tipagem das despesas da CEAP. Sem regra de negócio.
-- Grão: uma linha por LANÇAMENTO do arquivo CEAP (não por documento).
-- Não existe chave natural: o ideDocumento se repete (passagens com vários trechos,
-- estornos, IDs reaproveitados entre beneficiários) e vale '0' para telefonia e postais.

with fonte as (
    select
        d.*,
        _table_suffix as ano_arquivo,
        -- hash da linha BRUTA inteira (inclui colunas que não expomos, como txtPassageiro)
        farm_fingerprint(concat(_table_suffix, '|', to_json_string(d))) as hash_linha
    from {{ source('raw', 'despesas') }} as d
),

numerada as (
    select
        *,
        -- separa linhas 100% idênticas no arquivo de origem
        row_number() over (partition by hash_linha order by ano_arquivo) as ocorrencia
    from fonte
)

select
    -- chave substituta: única por lançamento
    farm_fingerprint(concat(cast(hash_linha as string), '|', cast(ocorrencia as string))) as lancamento_id,
    ocorrencia > 1                                          as eh_duplicata_exata,

    -- identificadores de origem
    nullif(nullif(trim(ideDocumento), ''), '0')             as despesa_id,       -- '0' = placeholder
    safe_cast(nullif(ideCadastro, '') as int64)             as deputado_id,      -- ID da API (nulo para lideranças)
    safe_cast(nullif(nuDeputadoId, '') as int64)            as beneficiario_id,  -- ID interno da cota
    case
        when nullif(ideCadastro, '') is null then 'lideranca'
        else 'deputado'
    end                                                     as tipo_beneficiario,

    -- quem gastou (como estava na data da despesa)
    trim(txNomeParlamentar)                                 as nome_parlamentar,
    nullif(trim(sgPartido), '')                             as partido_na_despesa,
    nullif(nullif(trim(sgUF), ''), 'NA')                    as uf,

    -- o que foi gasto
    safe_cast(nullif(numSubCota, '') as int64)              as subcota_id,
    trim(txtDescricao)                                      as tipo_despesa,
    nullif(trim(txtDescricaoEspecificacao), '')             as especificacao,

    -- com quem
    trim(txtFornecedor)                                     as fornecedor,
    nullif(regexp_replace(txtCNPJCPF, r'[^0-9]', ''), '')   as fornecedor_documento,

    -- quando
    safe_cast(left(datEmissao, 10) as date)                 as data_emissao,
    safe_cast(numAno as int64)                              as ano,
    safe_cast(numMes as int64)                              as mes,
    safe_cast(ano_arquivo as int64)                         as ano_arquivo,

    -- quanto (valores negativos são estornos legítimos)
    safe_cast(nullif(vlrDocumento, '') as numeric)          as valor_documento,
    safe_cast(nullif(vlrGlosa, '') as numeric)              as valor_glosa,
    safe_cast(nullif(vlrLiquido, '') as numeric)            as valor_liquido,

    -- detalhes
    safe_cast(nullif(numParcela, '') as int64)              as parcela,
    nullif(trim(txtTrecho), '')                             as trecho,
    nullif(trim(urlDocumento), '')                          as url_documento
    -- txtPassageiro fica de fora (LGPD); entra só no hash, que não é reversível

from numerada
