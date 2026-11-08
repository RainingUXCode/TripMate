# API financeira

Base: `/api/trips/<trip_id>/finance/`. JWT obrigatório. Somente membros
`accepted` podem consultar dados ou registrar operações. O orçamento é exclusivo
do organizador. O Flutter não foi alterado nesta etapa.

## Endpoints

| Método | Caminho relativo | Operação |
| --- | --- | --- |
| GET / PUT | `budget/` | Consultar / definir orçamento |
| GET | `summary/` | Totais, saldos e propostas disponíveis |
| GET / POST | `expenses/` | Listar (inclui canceladas) / criar |
| GET / PUT / DELETE | `expenses/<id>/` | Consultar / substituir / cancelar logicamente |
| GET | `proposals/` | Sugestões determinísticas, sem registrar pagamentos |
| GET / POST | `settlements/` | Listar histórico completo / declarar pagamento |
| GET | `settlements/<id>/` | Consultar pagamento |
| POST | `settlements/<id>/confirm/` | Confirmação pela contraparte |
| POST | `settlements/<id>/cancel/` | Cancelar pendente por qualquer envolvido |
| GET | `history/` | Eventos, ator, instante e snapshots históricos |

IDs são inteiros. Valores monetários devem ser strings decimais com ponto,
até 12 dígitos inteiros e duas casas; valores JSON de ponto flutuante são
rejeitados. Todas as respostas monetárias possuem duas casas. Datas usam ISO
`YYYY-MM-DD`; instantes incluem fuso. Campos desconhecidos/protegidos retornam
400; autoria e viagem são derivadas do JWT e da URL. IDs de despesas/acertos
são sempre pesquisados dentro da viagem da URL. Não há dados privados de e-mail.

## Orçamento

`PUT budget/`:

```json
{"budget_amount": "4000.00"}
```

Resposta: `{"budget_amount":"4000.00"}`. `null` remove o planejamento;
`"0.00"` é permitido. Valores negativos são rejeitados. Não é alterado por
despesas. A criação anterior de viagens continua compatível; viagens antigas
recebem orçamento nulo. O orçamento é editado exclusivamente por este endpoint,
e fica somente para leitura no admin.

## Despesas e divisões

`POST expenses/`:

```json
{
  "description": "Almoço",
  "amount": "100.00",
  "expense_date": "2026-11-07",
  "paid_by": 1,
  "mode": "equal",
  "shares": [{"user_id": 2}, {"user_id": 3}]
}
```

Exemplo de resposta (datas abreviadas aqui apenas para leitura):

```json
{
  "id": 12, "trip_id": 5, "description": "Almoço", "amount": "100.00",
  "expense_date": "2026-11-07", "paid_by": 1, "created_by": 2,
  "updated_by": 2, "mode": "equal", "cancelled": false, "version": 1,
  "created_at": "2026-11-07T12:00:00+00:00",
  "updated_at": "2026-11-07T12:00:00+00:00",
  "shares": [{"user_id": 2, "amount": "50.00", "value": null},
             {"user_id": 3, "amount": "50.00", "value": null}]
}
```

Autor, pagador e participantes da divisão podem ser diferentes. Apenas pagador
e participantes aceitos são elegíveis; a seleção pode ser parcial e excluir o
pagador. IDs duplicados são rejeitados. O autor original jamais é substituído.
Somente ele pode alterar/cancelar; organizadores não têm poder adicional.

Modalidades (`shares[].value` é o parâmetro original persistido):

* `equal`: sem `value`, divide por igual entre selecionados.
* `exact`: `value` monetário de cada parcela, soma exatamente igual ao total.
* `percent`: `value` percentual com até quatro casas, não negativo, soma 100.
* `units`: `value` inteiro positivo (string), representando cotas.

Exemplos para 100 reais: exact `["60.00","40.00"]`; percent
`["60","40"]`; units `["3","2"]`. Use os mesmos objetos com IDs da requisição
anterior e substitua `mode` e os valores. O servidor calcula e persiste cada
parcela. Valores exatos e parcelas podem ser zero; o total deve ser positivo.

Arredondamento: converter o total em centavos inteiros, calcular quociente e
resto com pesos inteiros, atribuir os centavos remanescentes por maior resto;
empates usam ID crescente do usuário. Não há `float` em cálculos. Exemplo:
10 reais entre IDs 1,2,3 resulta em 3,34 / 3,33 / 3,33. Os parâmetros originais
e as parcelas calculadas permanecem persistidos.

`PUT expenses/12/` exige corpo completo e `"version":1`. A versão incrementa;
versão ausente retorna 400 e desatualizada retorna 409. Não há PATCH parcial.
`DELETE expenses/12/` exige corpo `{"version":2}` e retorna o registro
cancelado; nenhuma exclusão física é executada. Alterações guardam snapshots
antes/depois, autor da mudança e instante no histórico.

Política conservadora de integridade: despesas existentes não podem ser
editadas/canceladas enquanto existir qualquer acerto pendente ou confirmado na
viagem. Novas despesas também ficam bloqueadas enquanto houver pagamentos
pendentes. Cancele ou confirme esses pagamentos primeiro. Após confirmação,
novas despesas são permitidas, mas as anteriores ficam congeladas para não
reescrever obrigações já quitadas. Não existe reversão de acertos confirmados
nem lançamento negativo: correções retroativas exigirão um fluxo explícito de
ajustes em uma etapa futura. Não tente apagar o histórico pelo admin.

## Saldos e propostas

`summary/` retorna `budget_amount`, `total_spent`, `remaining_budget`,
`consumed_percent`, `expense_count`, `finance_version`, `participants` e
`proposals`. Despesas canceladas não compõem os totais. Orçamento pode ser
ultrapassado; restante pode ser negativo e percentual maior que 100. Quando o
orçamento é nulo ou zero, o percentual é `null` (divisão indefinida em zero).

Cada participante contém `user_id`, `paid`, `due`, `gross_balance`, `sent`,
`received`, `balance`. Fórmulas:

```
gross_balance = paid - due
balance = gross_balance + sent_confirmed - received_confirmed
```

Positivo = recebe, negativo = paga. Pendentes não reduzem o saldo confirmado.
A soma de todos os saldos é zero. Usuários com histórico continuam presentes
mesmo se uma futura rotina remover sua participação.

Propostas usam saldos restantes, reservando os valores de pendentes. Devedores
e credores são percorridos por ID crescente e pareados pelo menor saldo. Exemplo:
`[{"debtor_id":2,"creditor_id":1,"amount":"50.00"}]`. É apenas uma sugestão,
nunca uma quitação automática. Um par específico não é uma dívida imutável:
o acerto formaliza uma transferência válida entre um devedor e um credor da
viagem, respeitando ambos os saldos disponíveis.

## Pagamentos e confirmação

`POST settlements/`:

```json
{"debtor_id":2,"creditor_id":1,"amount":"50.00",
 "request_key":"8f6ee938-b5be-4e18-99b0-77ac22acdc24"}
```

`request_key` é UUID criado pelo cliente para a intenção de pagamento. É único
na viagem, inclusive se cancelado; repetição retorna 409. Nunca gere nova chave
automaticamente para repetir uma requisição cujo resultado ficou desconhecido.
Consulte o histórico para reconciliar. Resposta inclui IDs, valor, chave,
status, `created_by_id`, `confirmed_by_id`, `cancelled_by_id` e respectivas datas.

O registrante deve ser devedor ou credor e membro aceito. Ambos devem estar
aceitos e ser pessoas diferentes. Valor positivo não pode superar o que o
devedor deve nem o que o credor tem a receber, incluindo reservas pendentes.
Declaração cria `pending`; a contraparte (e somente ela) envia corpo `{}` a
`confirm/`. Confirmação cria o efeito no saldo e grava identidade e data.
Repetição de confirmação retorna 409. `cancel/` é permitido aos envolvidos
apenas enquanto pendente, libera a reserva e mantém o registro. Estados
confirmados são imutáveis; não há exclusão de pagamentos. Histórico é visível
aos participantes aceitos da viagem.

## Concorrência e saídas

Toda escrita financeira usa `transaction.atomic` e a primeira operação é um
UPDATE de `Trip.finance_version`, antes de ler saldos. No PostgreSQL isto
serializa pela linha da viagem; no SQLite obtém bloqueio de escritor. Não se
depende de `select_for_update` no SQLite. Conflitos de banco retornam 409 com
rollback integral. Não repetir POST automaticamente. A migration e a suíte
usam SQLite; testar carga/concorrência novamente ao adotar outro banco.
Alterações diretas via ORM/SQL que contornem serviços não são suportadas;
constraints protegem sinais, duplicidades e estados simples, mas somas entre
linhas e elegibilidade requerem os serviços. O admin financeiro é somente leitura.

`finance.exit_eligibility(trip,user)` retorna `can_leave` (e o alias legado
`eligible`), códigos de `reasons` e mensagens sob o mesmo bloqueio financeiro.
Bloqueia saldo devedor/credor, acerto pendente envolvido e organizador. A saída
revalida esses dados e marca a participação `left` dentro da mesma transação; o
resultado da consulta não é um passe reutilizável. O organizador deve transferir
a outro membro aceito antes de sair. `TripOrganizerTransfer` preserva a auditoria
da transferência; despesas, parcelas, autores, pagadores, acertos e eventos não
são alterados. Saídas e transferências compartilham o bloqueio por
`Trip.finance_version` com as escritas financeiras. SQLite serializa escritores;
validar novamente a contenção em PostgreSQL antes da publicação.
