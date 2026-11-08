# API de viagens

O módulo financeiro está documentado em [FINANCE_API.md](FINANCE_API.md).

Todos os endpoints abaixo exigem `Authorization: Bearer <access_token>`.

## Criar viagem e convidar amigos

`POST /api/trips/`

Sem fotografia, o corpo pode ser JSON. Para enviar fotografia, use `multipart/form-data`:

- `name`, `destination`, `start_date`, `end_date` e, opcionalmente, `description`.
- `cover_image`: arquivo JPG, PNG ou WebP de até 8 MB e dimensões máximas de 8192 × 8192.
- `invitee_ids`: IDs de amigos já confirmados. Em multipart, envie como lista JSON, por
  exemplo `[12, 34]` (campo textual contendo `"[12,34]"`). Também é aceito repetir o campo.

O organizador é derivado do JWT e recebe uma participação `accepted`. Os convidados são
validados como amigos confirmados e recebem status `pending`. A viagem, a participação
do organizador e todos os convites são gravados em uma transação. Se algum registro
falhar, a criação é revertida e o arquivo de capa salvo durante a tentativa é removido.
Convites inválidos fazem a operação inteira retornar `400`; conflito de integridade
retorna `409`.

## Consultar viagens

- `GET /api/trips/`: viagens criadas pelo usuário ou nas quais sua participação foi aceita.
- `GET /api/trips/<trip_id>/`: mesmos critérios; convites pendentes e recusados não dão
  acesso. A resposta inclui `cover_image_url` (ou `null`), `organizer`,
  `accepted_participants`, `accepted_participants_count` e `pending_invites`.
- `can_delete` é verdadeiro somente para o organizador quando não há histórico
  financeiro nem transferência de organização protegendo a viagem.
- `pending_invites` só contém dados públicos e só é preenchido para o organizador.
- `rejected_invitees` contém somente dados públicos e só é preenchido para o
  organizador, para que a interface não ofereça convites que a API recusaria.
  Respostas de participantes não incluem e-mail.

## Excluir viagem

`DELETE /api/trips/<trip_id>/` é restrito ao organizador. A aplicação solicita uma
confirmação reforçada antes da chamada. Viagens com histórico de transferência ou
registros financeiros protegidos não podem ser excluídas e retornam `409`.

## Alterar capa

`PATCH /api/trips/<trip_id>/` com `multipart/form-data` e o campo `cover_image`.
Somente o organizador pode editar a viagem ou substituir a capa. A imagem anterior é
removida do storage depois que a atualização do banco é confirmada. A capa é opcional.

## Convidar amigos para viagem existente

`POST /api/trips/<trip_id>/invitations/`

```json
{"user_ids": [12, 34]}
```

Somente o organizador pode usar esta operação. Todos os IDs devem corresponder a amigos
confirmados e não podem já ter uma linha de participação. A lista é validada por inteiro
e criada atomicamente; convites repetidos retornam erro sem criar convites parciais.

## Convites recebidos e resposta

- `GET /api/trips/invitations/`: convites pendentes do usuário autenticado. Retorna uma
  prévia com viagem, datas, capa e organizador, sem descrição ou dados privados completos.
- `POST /api/trips/<trip_id>/invitation/accept/`: aceita o convite do próprio usuário.
- `POST /api/trips/<trip_id>/invitation/reject/`: recusa o convite do próprio usuário.

As ações só encontram convites pendentes pertencentes ao usuário autenticado. IDs de
terceiros ou convites já respondidos retornam `404`. Após aceitar, o usuário passa a
ter acesso aos detalhes privados e entra na contagem de participantes aceitos.

## Saída voluntária e transferência de organização

- `GET /api/trips/<trip_id>/leave-eligibility/` consulta a elegibilidade do próprio
  usuário. Retorna `can_leave`, compatível com `eligible`, uma lista de códigos em
  `reasons` e mensagens correspondentes em `reason_messages`. Os códigos possíveis são
  `outstanding_debt`, `outstanding_credit`, `pending_settlement` e
  `organizer_transfer_required`. O endpoint usa o bloqueio da viagem para consultar
  saldos consistentes; conflitos de gravação retornam `409`.
- `POST /api/trips/<trip_id>/leave/` aceita `{}` e sempre atua sobre o usuário do JWT.
  A elegibilidade financeira é recalculada dentro da mesma transação da saída. Se
  permitida, a participação muda para `left`; ela não é apagada. O organizador atual
  precisa primeiro transferir a organização. Saldo, acerto pendente ou organizador
  retornam `409` com os códigos/mensagens aplicáveis. Após sair, o usuário perde o
  acesso à viagem e ela deixa de aparecer em sua listagem.
- `POST /api/trips/<trip_id>/transfer-organizer/` recebe
  `{"new_organizer_id": 12}`. Somente o organizador atual pode transferir, e o sucessor
  precisa ser participante `accepted` da viagem. O organizador anterior continua
  participante aceito; a transferência não o remove nem altera registros financeiros.
  A resposta é a representação atualizada da viagem.
- `DELETE /api/trips/<trip_id>/members/<user_id>/` permite ao organizador remover
  outro participante aceito. A API verifica os bloqueios financeiros sob o mesmo lock
  de saída e marca a participação como `left`, preservando despesas e histórico.
  O organizador não pode remover a si mesmo; erros de permissão ou pendências são
  retornados pelo backend.

Cada transferência cria um registro imutável `TripOrganizerTransfer` com viagem,
organizador anterior, sucessor, autor da operação e instante. Participações que saem
mantêm sua linha `TripMember` com status `left`, preservando as FKs e o histórico
financeiro. Uma futura nova convocação pode reutilizar essa linha: ela volta a `pending`
sem inserir uma duplicata para o mesmo usuário/viagem.

## URLs das capas

`cover_image_url` é montada a partir do storage configurado pelo Django e da origem da
requisição. Em desenvolvimento, os arquivos usam `MEDIA_ROOT`/`MEDIA_URL`. Ambientes
persistentes devem configurar um storage durável no backend antes da publicação.
