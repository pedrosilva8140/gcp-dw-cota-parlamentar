-- Regressão com caso verificado na API: Fausto Pinato (66828) ficou no PP até 2026-04-29
-- e está no UNIÃO desde então. Afirma diretamente as duas versões esperadas.
-- Retorna uma linha (= teste falha) se qualquer uma não existir exatamente uma vez.
with verificacao as (
    select
        countif(partido = 'PP' and valido_ate = date '2026-04-29')                  as versao_pp,
        countif(partido = 'UNIÃO' and valido_de = date '2026-04-29' and eh_atual)   as versao_uniao
    from {{ ref('dim_deputado') }}
    where deputado_id = 66828
)

select *
from verificacao
where versao_pp != 1 or versao_uniao != 1
