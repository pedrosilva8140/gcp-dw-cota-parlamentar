-- Cada deputado deve ter exatamente uma versão atual. Retorna os que violam a regra.
select deputado_id, count(*) as versoes_atuais
from {{ ref('dim_deputado') }}
where deputado_id is not null and eh_atual
group by deputado_id
having count(*) != 1
