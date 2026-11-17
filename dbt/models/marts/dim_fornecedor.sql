-- Fornecedores identificados pelo documento (só dígitos).
-- CPF de pessoa física não é exposto (LGPD): entra só no hash da chave.
with por_documento as (
    select
        fornecedor_documento,
        array_agg(fornecedor order by data_emissao desc limit 1)[offset(0)] as nome,
        count(*) as lancamentos
    from {{ ref('stg_despesas') }}
    where fornecedor_documento is not null
    group by fornecedor_documento
)

select
    farm_fingerprint(fornecedor_documento)                          as fornecedor_sk,
    nome,
    case length(fornecedor_documento)
        when 14 then 'PJ'
        when 11 then 'PF'
        else 'Outro'
    end                                                             as tipo_pessoa,
    if(length(fornecedor_documento) = 14, fornecedor_documento, null) as cnpj,
    lancamentos
from por_documento

union all

select -1, 'Não informado', null, null, null
