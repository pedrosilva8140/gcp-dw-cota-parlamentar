-- Dimensão de deputados, SCD tipo 2: uma versão por período em cada partido/UF.
-- Fonte do histórico: API /deputados/{id}/historico (o partido do arquivo da CEAP é retroativo).
-- Validade semiaberta: [valido_de, valido_ate). A versão atual tem valido_ate nulo.

with eventos as (
    select *
    from {{ ref('stg_deputados_historico') }}
    where partido is not null
),

-- 1 evento por deputado por dia (o último), para evitar versões de duração zero
um_por_dia as (
    select
        deputado_id,
        date(data_hora) as data_evento,
        partido,
        uf
    from eventos
    qualify row_number() over (
        partition by deputado_id, date(data_hora)
        order by data_hora desc
    ) = 1
),

-- mantém só os eventos em que partido ou UF mudaram
mudancas as (
    select *
    from um_por_dia
    qualify
        lag(partido) over (partition by deputado_id order by data_evento) is null
        or lag(partido) over (partition by deputado_id order by data_evento) != partido
        or lag(uf) over (partition by deputado_id order by data_evento) != uf
),

-- nome mais recente de cada deputado
nomes as (
    select
        deputado_id,
        array_agg(nome order by data_hora desc limit 1)[offset(0)] as nome
    from eventos
    group by deputado_id
),

versoes as (
    select
        m.deputado_id,
        n.nome,
        m.partido,
        m.uf,
        m.partido = 'S.PART.'                                                   as eh_sem_partido,
        m.data_evento,
        row_number() over (partition by m.deputado_id order by m.data_evento)  as numero_versao,
        lead(m.data_evento) over (partition by m.deputado_id order by m.data_evento) as valido_ate
    from mudancas as m
    inner join nomes as n using (deputado_id)
)

select
    farm_fingerprint(concat(cast(deputado_id as string), '|', cast(data_evento as string))) as deputado_sk,
    deputado_id,
    nome,
    partido,
    uf,
    eh_sem_partido,
    numero_versao,
    data_evento,                                                -- data real do evento na API
    if(numero_versao = 1, date '1900-01-01', data_evento) as valido_de,  -- 1ª versão vale "desde sempre"
    valido_ate,
    valido_ate is null                                    as eh_atual
from versoes

union all

-- membro especial: lançamentos de lideranças (sem deputado)
select
    -1, null, 'Não se aplica (liderança)', null, null, false,
    1, null, date '1900-01-01', null, true
