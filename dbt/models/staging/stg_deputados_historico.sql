-- Eventos reais do histórico de cada deputado.
-- Descarta os eventos sintéticos "Nome/Partido no início da legislatura"
-- (situacao nula e data fixa em 2023-02-01 para qualquer legislatura).
select
    deputado_id,
    coalesce(
        safe.parse_datetime('%Y-%m-%dT%H:%M:%S', data_hora),
        safe.parse_datetime('%Y-%m-%dT%H:%M', data_hora)
    )                                     as data_hora,
    nullif(trim(sigla_partido), '')       as partido,     -- "S.PART." é um valor válido
    nullif(trim(sigla_uf), '')            as uf,
    id_legislatura,
    situacao,
    condicao_eleitoral,
    descricao_status,
    nome,
    nome_eleitoral
from {{ source('raw', 'deputados_historico') }}
where situacao is not null
