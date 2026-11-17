{% docs __overview__ %}

# Data warehouse da Cota Parlamentar (CEAP)

Despesas da Cota para o Exercício da Atividade Parlamentar da Câmara dos Deputados,
2019 a 2026: **1,69 milhão de lançamentos**, modelados em esquema estrela no BigQuery.

## Destaques
- **SCD tipo 2 em `dim_deputado`**, construída a partir do log de eventos da API
  (`/deputados/{id}/historico`). O partido do arquivo da CEAP é **retroativo**
  (ex.: "UNIÃO", fundado em 2022, aparece em despesas de 2019).
- **R$ 460,8 mi (27%)** das despesas de deputados aparecem na fonte com um partido
  diferente do que o deputado tinha na data do gasto. Veja `rpt_divergencia_partido`.
- **Grão de lançamento**, com chave substituta: o `ideDocumento` da fonte não é único.
- **`fct_despesas` particionada por mês de competência** e clusterizada.

## Camadas
| Camada | Conteúdo |
| --- | --- |
| `raw` | Dados como a fonte entrega (tudo em texto) |
| `staging` | Limpeza e tipagem, sem regra de negócio |
| `marts` | Esquema estrela: `fct_despesas` + 4 dimensões |

Clique no botão azul no canto inferior direito para ver o **grafo de linhagem**.

{% enddocs %}