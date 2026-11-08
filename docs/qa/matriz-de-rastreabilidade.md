# Matriz de rastreabilidade QA

| Requisito / regra | Flutter | Django | Playwright API | Android integration |
|---|---|---|---|---|
| JWT, refresh, rejeição, sessão, perfil e avatar | `auth_service_test.dart`, widgets de sessão | `accounts.tests.AuthenticationApiTests` | `auth.spec.ts`, `account.spec.ts` | QA-INT-001 aprovado: login/logout no A71 |
| Amizade confirmada, requisição e ações autorizadas | telas/serviço de amizades e convite | `friends.tests.FriendshipAPITests` | `friends.spec.ts` | Fixture real para fluxo de convite |
| Viagem, campos, datas, capa e organizador | formulário, cards, `TripsService` | `trips.tests.TripModelTests`, `TripAPITests` | `trips.spec.ts` | Criar viagem no fluxo smoke 1 |
| Acesso privado e papéis | gerenciar viagem e TripDetails widgets | trip API + permissões/transferência/saída | `permissions.spec.ts` | Acesso autorizado na UI |
| Convite pendente/aceito/recusado | convites e `TripDetailsScreen` | trip invite API cases | `invitations.spec.ts` | QA-INT-002 aprovado: segunda conta aceitou pela UI |
| Despesas, quatro divisões, valores/versão | `TripsService`, formulário financeiro e widget | `trips.test_finance` | `expenses.spec.ts` | QA-INT-001 aprovou criação e persistência de gasto no A71; modalidades adicionais em Android não executadas |
| Saldos, acertos, concorrência e bloqueios | acertos e saldo widgets; serviço autenticado em rede mockada | finance domain/API tests | `settlements.spec.ts` | QA-INT-004 (ciclo completo de duas contas em UI) não executado |
| Notificações, leitura e isolamento | service/screen/shell | `notifications.tests.NotificationEventTests` | `notifications.spec.ts` | QA-INT-006 de UI Android não executado |
| Avatares e responsividade | `user_avatar_test`, cartões e telas | — | — | Validação Android depende do device acessível |

Cobertura estática de linhas não é uma medida de completude desta matriz; regras são rastreadas por cenários, asserções de estado e autorização. QA-INT-003–006 não foram implementados/executados no Android; os resultados Playwright exercitam contratos HTTP correspondentes, mas não comprovam comportamento da UI nativa.
