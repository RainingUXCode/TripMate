# API de notificações internas

Todas as rotas exigem JWT. Os dados sempre são limitados ao usuário autenticado.

- `GET /api/notifications/` lista da mais recente para a mais antiga, paginada
  (20 por página; `page_size` configurável até 50).
- `GET /api/notifications/unread-count/` retorna `{"unread_count": N}` calculado
  diretamente no banco.
- `POST /api/notifications/{id}/read/` marca a notificação do usuário como lida;
  repetir a operação é seguro. IDs de outros usuários retornam 404.
- `POST /api/notifications/read-all/` marca como lidas somente as notificações
  do usuário autenticado.

Cada item contém `event_type`, título, mensagem, estado de leitura, timestamps e
referência tipada ao recurso. Acertos também informam `context_id` com o ID da
viagem. Referências servem para navegação; os endpoints de domínio continuam sendo
a autoridade de acesso.

Eventos são criados dentro da mesma transação das operações de amizade, convite,
acerto e transferência. `event_key` tem unicidade no banco para evitar avisos
duplicados em uma mesma ocorrência. Reconvites e novas solicitações após recusa
recebem chaves distintas por ocorrência.
