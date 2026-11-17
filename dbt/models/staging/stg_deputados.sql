-- Cadastro atual dos deputados (API). Uma linha por deputado.
select
    id               as deputado_id,
    nome,
    partido,
    uf,
    id_legislatura,
    data_carga
from {{ source('raw', 'deputados') }}
