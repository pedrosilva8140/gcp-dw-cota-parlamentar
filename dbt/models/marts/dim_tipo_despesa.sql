-- Tipos de despesa (subcotas da CEAP). Se o nome mudou ao longo dos anos, usa o mais recente.
select
    subcota_id                                                        as tipo_despesa_sk,
    array_agg(tipo_despesa order by data_emissao desc limit 1)[offset(0)] as tipo_despesa,
    count(distinct tipo_despesa)                                      as variacoes_de_nome
from {{ ref('stg_despesas') }}
where subcota_id is not null
group by subcota_id
