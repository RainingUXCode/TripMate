# Inventário automatizado de testes

Gerado por `python qa/generate_inventory.py` a partir das declarações de teste. Status Flutter/Django/Android representam a última execução indicada explicitamente pelos argumentos do gerador; Playwright vem do relatório JSON da execução. Não contém tokens, credenciais ou dados de fixture.

| ID | Arquivo | Módulo | Cenário | Tipo | Resultado |
|---|---|---|---|---|---|
| QA-FLT-001 | test/auth_service_test.dart | auth_service_test | renova e grava access e refresh tokens novos | Unit/widget | Aprovado |
| QA-FLT-002 | test/auth_service_test.dart | auth_service_test | sessão expirada limpa dados locais | Unit/widget | Aprovado |
| QA-FLT-003 | test/auth_service_test.dart | auth_service_test | falha de conexão no refresh preserva a sessão para nova tentativa | Unit/widget | Aprovado |
| QA-FLT-004 | test/auth_service_test.dart | auth_service_test | perfil renova uma vez após 401 e persiste a resposta do usuário | Unit/widget | Aprovado |
| QA-FLT-005 | test/auth_service_test.dart | auth_service_test | falha de refresh ao consultar perfil não apaga conta por erro de rede | Unit/widget | Aprovado |
| QA-FLT-006 | test/auth_service_test.dart | auth_service_test | updateAccount envia valores normalizados e tratamento de erro HTTP | Unit/widget | Aprovado |
| QA-FLT-007 | test/auth_service_test.dart | auth_service_test | alteração de senha limpa tokens e usuário para exigir novo login | Unit/widget | Aprovado |
| QA-FLT-008 | test/authenticated_shell_test.dart | authenticated_shell_test | alternar abas mantém uma única shell e Início volta direto | Widget | Aprovado |
| QA-FLT-009 | test/authenticated_shell_test.dart | authenticated_shell_test | o sino recebe a contagem não lida real compartilhada | Widget | Aprovado |
| QA-FLT-010 | test/authenticated_shell_test.dart | authenticated_shell_test | eventos de notificação abrem destinos atuais e autorizados | Widget | Aprovado |
| QA-FLT-011 | test/authenticated_shell_test.dart | authenticated_shell_test | aceitar convite atualiza Home e o contador de viagens do Perfil | Widget | Aprovado |
| QA-FLT-012 | test/create_trip_screen_test.dart | create_trip_screen_test | campos principais têm ícones alinhados e hierarquia tipográfica | Widget | Aprovado |
| QA-FLT-013 | test/create_trip_screen_test.dart | create_trip_screen_test | date validation rejects an end date before the start date | Unit/widget | Aprovado |
| QA-FLT-014 | test/create_trip_screen_test.dart | create_trip_screen_test | requires name, destination and dates before saving | Widget | Aprovado |
| QA-FLT-015 | test/create_trip_screen_test.dart | create_trip_screen_test | creates a trip and returns Home through the form route | Widget | Aprovado |
| QA-FLT-016 | test/create_trip_screen_test.dart | create_trip_screen_test | selects, deselects and submits confirmed friends with a cover | Widget | Aprovado |
| QA-FLT-017 | test/create_trip_screen_test.dart | create_trip_screen_test | shows a friendly error for unsupported image formats | Widget | Aprovado |
| QA-FLT-018 | test/create_trip_screen_test.dart | create_trip_screen_test | returns to Home, requests refresh and does not open details | Widget | Aprovado |
| QA-FLT-019 | test/create_trip_screen_test.dart | create_trip_screen_test | keeps field values after API failure | Widget | Aprovado |
| QA-FLT-020 | test/create_trip_screen_test.dart | create_trip_screen_test | ignores a second submit while the first request is pending | Widget | Aprovado |
| QA-FLT-021 | test/notifications_screen_test.dart | notifications_screen_test | renders empty and error retry states | Widget | Aprovado |
| QA-FLT-022 | test/notifications_screen_test.dart | notifications_screen_test | loads real items, marks one read and opens its target | Widget | Aprovado |
| QA-FLT-023 | test/notifications_screen_test.dart | notifications_screen_test | mark all and notification bell use real unread state | Widget | Aprovado |
| QA-FLT-024 | test/notifications_screen_test.dart | notifications_screen_test | keeps long notification text readable with larger text scale | Widget | Aprovado |
| QA-FLT-025 | test/notifications_screen_test.dart | notifications_screen_test | loads the next page when the list is scrolled | Widget | Aprovado |
| QA-FLT-026 | test/notifications_service_test.dart | notifications_service_test | loads real unread count and paginated notification rows | Unit/widget | Aprovado |
| QA-FLT-027 | test/notifications_service_test.dart | notifications_service_test | reading endpoints use the authenticated user and expected methods | Unit/widget | Aprovado |
| QA-FLT-028 | test/notifications_service_test.dart | notifications_service_test | does not hide HTTP authorization and connection errors | Unit/widget | Aprovado |
| QA-FLT-029 | test/profile_friend_count_test.dart | profile_friend_count_test | exibe zero quando não há amizades confirmadas | Widget | Aprovado |
| QA-FLT-030 | test/profile_friend_count_test.dart | profile_friend_count_test | conta amigos confirmados e ignora solicitações pendentes | Widget | Aprovado |
| QA-FLT-031 | test/profile_friend_count_test.dart | profile_friend_count_test | atualiza a contagem ao reativar a aba Perfil | Widget | Aprovado |
| QA-FLT-032 | test/profile_friend_count_test.dart | profile_friend_count_test | falha inicial mostra marcador neutro sem bloquear o Perfil | Widget | Aprovado |
| QA-FLT-033 | test/profile_friend_count_test.dart | profile_friend_count_test | falha posterior preserva a última contagem válida | Widget | Aprovado |
| QA-FLT-034 | test/settlements_screen_test.dart | settlements_screen_test | mostra sugestões e histórico vazios sem criar acerto | Widget | Aprovado |
| QA-FLT-035 | test/settlements_screen_test.dart | settlements_screen_test | sheet de detalhes exibe operação confirmada e fecha pelo X | Widget | Aprovado |
| QA-FLT-036 | test/settlements_screen_test.dart | settlements_screen_test | status pendente e cancelado têm rótulos explícitos | Widget | Aprovado |
| QA-FLT-037 | test/settlements_screen_test.dart | settlements_screen_test | sheet ocupa a largura e rola com texto ampliado e nomes longos | Widget | Aprovado |
| QA-FLT-038 | test/settlements_screen_test.dart | settlements_screen_test | declara valor permitido e envia chave UUID como string | Widget | Aprovado |
| QA-FLT-039 | test/settlements_screen_test.dart | settlements_screen_test | oculta ação para não envolvido e rejeita valor acima da sugestão | Widget | Aprovado |
| QA-FLT-040 | test/settlements_screen_test.dart | settlements_screen_test | contraparte confirma e participante envolvido cancela pendência | Widget | Aprovado |
| QA-FLT-041 | test/settlements_screen_test.dart | settlements_screen_test | reconcilia falha ambígua de criação sem repetir POST | Widget | Aprovado |
| QA-FLT-042 | test/settlements_screen_test.dart | settlements_screen_test | sheet é rolável em tela estreita e escala ampliada | Widget | Aprovado |
| QA-FLT-043 | test/settlements_screen_test.dart | settlements_screen_test | não oferece repetir confirmação até consultar o estado remoto | Widget | Aprovado |
| QA-FLT-044 | test/splash_screen_test.dart | splash_screen_test | loads the supplied Lottie once, tints it purple and opens Welcome | Widget | Aprovado |
| QA-FLT-045 | test/splash_screen_test.dart | splash_screen_test | routes an authenticated user to Home after the animation | Widget | Aprovado |
| QA-FLT-046 | test/splash_screen_test.dart | splash_screen_test | reduced motion skips playback and still waits for session readiness | Widget | Aprovado |
| QA-FLT-047 | test/splash_screen_test.dart | splash_screen_test | removes the white background layer and retains the embedded plane PNG | Unit/widget | Aprovado |
| QA-FLT-048 | test/trip_card_test.dart | trip_card_test | mantém nome e destino agrupados acima dos participantes | Widget | Aprovado |
| QA-FLT-049 | test/trip_card_test.dart | trip_card_test | nomes e destinos longos cabem em largura estreita e escala maior | Widget | Aprovado |
| QA-FLT-050 | test/trip_card_test.dart | trip_card_test | capa real usa BoxFit.cover e mantém o badge de datas | Widget | Aprovado |
| QA-FLT-051 | test/trip_details_screen_test.dart | trip_details_screen_test | exibe capa, dados e apenas participantes aceitos | Widget | Aprovado |
| QA-FLT-052 | test/trip_details_screen_test.dart | trip_details_screen_test | usa placeholder e apresenta estado real sem participantes | Widget | Aprovado |
| QA-FLT-053 | test/trip_details_screen_test.dart | trip_details_screen_test | orçamento e avatares do hero não são cortados | Widget | Aprovado |
| QA-FLT-054 | test/trip_details_screen_test.dart | trip_details_screen_test | card do grupo mostra total e conta apenas despesas ativas | Widget | Aprovado |
| QA-FLT-055 | test/trip_details_screen_test.dart | trip_details_screen_test | card não inventa contagem enquanto a lista está indisponível | Widget | Aprovado |
| QA-FLT-056 | test/trip_details_screen_test.dart | trip_details_screen_test | a ação de convidar amigos só aparece para o organizador | Widget | Aprovado |
| QA-FLT-057 | test/trip_details_screen_test.dart | trip_details_screen_test | organizador ainda pode abrir convite sem amigos disponíveis | Widget | Aprovado |
| QA-FLT-058 | test/trip_details_screen_test.dart | trip_details_screen_test | contagens e Pago por pessoa incluem somente usuários aceitos | Widget | Aprovado |
| QA-FLT-059 | test/trip_details_screen_test.dart | trip_details_screen_test | mostra bloqueio financeiro retornado pelo backend sem tentar sair | Widget | Aprovado |
| QA-FLT-060 | test/trip_details_screen_test.dart | trip_details_screen_test | sai após confirmar, atualiza listas e retorna à Home | Widget | Aprovado |
| QA-FLT-061 | test/trip_details_screen_test.dart | trip_details_screen_test | transferência atualiza o organizador sem retirar o antigo membro | Widget | Aprovado |
| QA-FLT-062 | test/trip_details_screen_test.dart | trip_details_screen_test | remoção de participante exige confirmação e preserva a tela | Widget | Aprovado |
| QA-FLT-063 | test/trip_details_screen_test.dart | trip_details_screen_test | exclusão exige digitar o nome exato e volta à tela anterior | Widget | Aprovado |
| QA-FLT-064 | test/trip_details_screen_test.dart | trip_details_screen_test | retorno do gerenciamento mantém a aba Gastos selecionada | Widget | Aprovado |
| QA-FLT-065 | test/trip_details_screen_test.dart | trip_details_screen_test | ações destrutivas usam vermelho apenas nos ícones e hero iguala botões | Widget | Aprovado |
| QA-FLT-066 | test/trip_details_screen_test.dart | trip_details_screen_test | as duas abas alternam sem exibir Roteiro nem recarregar a viagem | Widget | Aprovado |
| QA-FLT-067 | test/trip_details_screen_test.dart | trip_details_screen_test | abre Acertos a partir de Gastos e retorna sem perder a aba | Widget | Aprovado |
| QA-FLT-068 | test/trip_details_screen_test.dart | trip_details_screen_test | novo gasto envia as quatro modalidades sem converter dinheiro para double | Widget | Aprovado |
| QA-FLT-069 | test/trip_details_screen_test.dart | trip_details_screen_test | ações de edição e cancelamento só aparecem para o autor | Widget | Aprovado |
| QA-FLT-070 | test/trip_details_screen_test.dart | trip_details_screen_test | falha permite tentar novamente e botão voltar retorna | Widget | Aprovado |
| QA-FLT-071 | test/trip_details_screen_test.dart | trip_details_screen_test | textos extensos e escala ampliada não causam overflow | Widget | Aprovado |
| QA-FLT-072 | test/trip_invitations_test.dart | trip_invitations_test | aceita convite, atualiza estado e só oferece detalhes depois | Widget | Aprovado |
| QA-FLT-073 | test/trip_invitations_test.dart | trip_invitations_test | recusa exige confirmação antes da operação | Widget | Aprovado |
| QA-FLT-074 | test/trip_invitations_test.dart | trip_invitations_test | só consulta os detalhes privados ao abrir após aceitar | Widget | Aprovado |
| QA-FLT-075 | test/trip_invitations_test.dart | trip_invitations_test | protege contra duas submissões simultâneas | Widget | Aprovado |
| QA-FLT-076 | test/trip_invitations_test.dart | trip_invitations_test | falha ambígua exige consulta bem-sucedida antes de repetir | Widget | Aprovado |
| QA-FLT-077 | test/trip_invitations_test.dart | trip_invitations_test | remove convite já respondido pelo servidor após consultar lista | Widget | Aprovado |
| QA-FLT-078 | test/trip_invitations_test.dart | trip_invitations_test | regressão A71: mapeia IDs de amizade para usuários e filtra memberships | Widget | Aprovado |
| QA-FLT-079 | test/trip_invitations_test.dart | trip_invitations_test | vários amigos elegíveis enviam seus IDs de usuário reais | Widget | Aprovado |
| QA-FLT-080 | test/trip_invitations_test.dart | trip_invitations_test | amigo que saiu da viagem pode receber novo convite | Widget | Aprovado |
| QA-FLT-081 | test/trip_invitations_test.dart | trip_invitations_test | distingue ausência de amigos de todos já vinculados | Widget | Aprovado |
| QA-FLT-082 | test/trip_invitations_test.dart | trip_invitations_test | falha ao carregar amizades exibe erro e permite tentar novamente | Widget | Aprovado |
| QA-FLT-083 | test/trip_invitations_test.dart | trip_invitations_test | não reaproveita a conta anterior se o usuário mudar | Widget | Aprovado |
| QA-FLT-084 | test/trip_invitations_test.dart | trip_invitations_test | reconsulta a viagem após falha ambígua ao enviar convites | Widget | Aprovado |
| QA-FLT-085 | test/trip_invitations_test.dart | trip_invitations_test | convite com textos longos cabe em tela estreita e escala maior | Widget | Aprovado |
| QA-FLT-086 | test/trip_listing_test.dart | trip_listing_test | Home mostra no máximo duas viagens reais e Ver todas lista todas | Widget | Aprovado |
| QA-FLT-087 | test/trip_listing_test.dart | trip_listing_test | Perfil mostra — sem dados e atualiza a contagem real | Widget | Aprovado |
| QA-FLT-088 | test/trip_listing_test.dart | trip_listing_test | Perfil preserva contagem em erro e limpa ao trocar de conta | Widget | Aprovado |
| QA-FLT-089 | test/trips_service_test.dart | trips_service_test | createTrip sends multipart fields, cover and invitation IDs | Unit/widget | Aprovado |
| QA-FLT-090 | test/trips_service_test.dart | trips_service_test | getTrips and getTrip parse API data and use their paths | Unit/widget | Aprovado |
| QA-FLT-091 | test/trips_service_test.dart | trips_service_test | invitation APIs use documented paths, methods and public preview data | Unit/widget | Aprovado |
| QA-FLT-092 | test/trips_service_test.dart | trips_service_test | keeps invitation conflict status for stale or already answered invites | Unit/widget | Aprovado |
| QA-FLT-093 | test/trips_service_test.dart | trips_service_test | exit and organizer transfer use documented endpoints and payloads | Unit/widget | Aprovado |
| QA-FLT-094 | test/trips_service_test.dart | trips_service_test | member removal and trip deletion use authenticated DELETE endpoints | Unit/widget | Aprovado |
| QA-FLT-095 | test/trips_service_test.dart | trips_service_test | does not repeat ambiguous leave or transfer POSTs | Unit/widget | Aprovado |
| QA-FLT-096 | test/trips_service_test.dart | trips_service_test | finance requests use real endpoints and preserve decimal strings and versions | Unit/widget | Aprovado |
| QA-FLT-097 | test/trips_service_test.dart | trips_service_test | sorts trips newest first with descending ID as a stable tie breaker | Unit/widget | Aprovado |
| QA-FLT-098 | test/trips_service_test.dart | trips_service_test | settlement service uses documented paths and payloads | Unit/widget | Aprovado |
| QA-FLT-099 | test/trips_service_test.dart | trips_service_test | resolves relative cover URLs against the API host | Unit/widget | Aprovado |
| QA-FLT-100 | test/trips_service_test.dart | trips_service_test | retries once after refreshing an expired access token | Unit/widget | Aprovado |
| QA-FLT-101 | test/trips_service_test.dart | trips_service_test | does not repeat create after an ambiguous connection failure | Unit/widget | Aprovado |
| QA-FLT-102 | test/trips_service_test.dart | trips_service_test | uses the API detail for validation errors | Unit/widget | Aprovado |
| QA-FLT-103 | test/trips_service_test.dart | trips_service_test | turns connection failures into a Portuguese service error | Unit/widget | Aprovado |
| QA-FLT-104 | test/user_avatar_test.dart | user_avatar_test | foto é recortada pelo círculo e preenche com BoxFit.cover | Widget | Aprovado |
| QA-FLT-105 | test/user_avatar_test.dart | user_avatar_test | iniciais permanecem centralizadas em tamanhos diferentes | Widget | Aprovado |
| QA-FLT-106 | test/user_avatar_test.dart | user_avatar_test | falha ao carregar foto apresenta o fallback circular | Widget | Aprovado |
| QA-FLT-107 | test/user_avatar_test.dart | user_avatar_test | avatares sobrepostos conservam recorte e contorno | Widget | Aprovado |
| QA-DJ-001 | backend/accounts/tests.py | accounts | login returns jwt and normalized public user | API/model/domain | Aprovado |
| QA-DJ-002 | backend/accounts/tests.py | accounts | invalid credentials are rejected | API/model/domain | Aprovado |
| QA-DJ-003 | backend/accounts/tests.py | accounts | current user requires valid jwt | API/model/domain | Aprovado |
| QA-DJ-004 | backend/accounts/tests.py | accounts | current user exposes only authenticated account | API/model/domain | Aprovado |
| QA-DJ-005 | backend/accounts/tests.py | accounts | refresh rotates access token for valid refresh | API/model/domain | Aprovado |
| QA-DJ-006 | backend/accounts/tests.py | accounts | refresh rejects invalid token | API/model/domain | Aprovado |
| QA-DJ-007 | backend/accounts/tests.py | accounts | profile can be read and name updated without leaking password | API/model/domain | Aprovado |
| QA-DJ-008 | backend/accounts/tests.py | accounts | email update requires current password and updates login username | API/model/domain | Aprovado |
| QA-DJ-009 | backend/accounts/tests.py | accounts | profile rejects duplicate email and empty patch | API/model/domain | Aprovado |
| QA-DJ-010 | backend/accounts/tests.py | accounts | password change validates and requires reauthentication | API/model/domain | Aprovado |
| QA-DJ-011 | backend/accounts/tests.py | accounts | avatar upload persists safe image and delete is idempotent | API/model/domain | Aprovado |
| QA-DJ-012 | backend/accounts/tests.py | accounts | avatar rejects non image and oversized upload | API/model/domain | Aprovado |
| QA-DJ-013 | backend/accounts/tests.py | accounts | profile and avatar require authentication | API/model/domain | Aprovado |
| QA-DJ-014 | backend/friends/tests.py | friends | search requires authentication | API/model/domain | Aprovado |
| QA-DJ-015 | backend/friends/tests.py | friends | search returns other users | API/model/domain | Aprovado |
| QA-DJ-016 | backend/friends/tests.py | friends | search supports partial name | API/model/domain | Aprovado |
| QA-DJ-017 | backend/friends/tests.py | friends | search email is exact and case insensitive | API/model/domain | Aprovado |
| QA-DJ-018 | backend/friends/tests.py | friends | search excludes self and inactive accounts | API/model/domain | Aprovado |
| QA-DJ-019 | backend/friends/tests.py | friends | user cannot add themselves | API/model/domain | Aprovado |
| QA-DJ-020 | backend/friends/tests.py | friends | send friend request | API/model/domain | Aprovado |
| QA-DJ-021 | backend/friends/tests.py | friends | duplicate friend request is blocked | API/model/domain | Aprovado |
| QA-DJ-022 | backend/friends/tests.py | friends | reverse request is blocked | API/model/domain | Aprovado |
| QA-DJ-023 | backend/friends/tests.py | friends | receiver can reject and sender is blocked for seven days | API/model/domain | Aprovado |
| QA-DJ-024 | backend/friends/tests.py | friends | original sender can resend after seven days | API/model/domain | Aprovado |
| QA-DJ-025 | backend/friends/tests.py | friends | declining user can start new request immediately | API/model/domain | Aprovado |
| QA-DJ-026 | backend/friends/tests.py | friends | only recipient can reject request | API/model/domain | Aprovado |
| QA-DJ-027 | backend/friends/tests.py | friends | participant can cancel pending and remove friendship | API/model/domain | Aprovado |
| QA-DJ-028 | backend/friends/tests.py | friends | receiver can accept request | API/model/domain | Aprovado |
| QA-DJ-029 | backend/friends/tests.py | friends | sender cannot accept request | API/model/domain | Aprovado |
| QA-DJ-030 | backend/friends/tests.py | friends | accepted friendship is visible to both | API/model/domain | Aprovado |
| QA-DJ-031 | backend/friends/tests.py | friends | unrelated user cannot delete friendship | API/model/domain | Aprovado |
| QA-DJ-032 | backend/notifications/tests.py | notifications | friend request creates one private notification | API/model/domain | Aprovado |
| QA-DJ-033 | backend/notifications/tests.py | notifications | trip creation and later invite create notifications | API/model/domain | Aprovado |
| QA-DJ-034 | backend/notifications/tests.py | notifications | settlement pending confirmation and transfer events | API/model/domain | Aprovado |
| QA-DJ-035 | backend/notifications/tests.py | notifications | failed business operations create no notifications | API/model/domain | Aprovado |
| QA-DJ-036 | backend/notifications/tests.py | notifications | list count read read all pagination and user isolation | API/model/domain | Aprovado |
| QA-DJ-037 | backend/notifications/tests.py | notifications | endpoints require authentication | API/model/domain | Aprovado |
| QA-DJ-038 | backend/notifications/tests.py | notifications | notifications are persisted for a new authenticated client | API/model/domain | Aprovado |
| QA-DJ-039 | backend/trips/test_finance.py | trips | all modes and exact sum | API/model/domain | Aprovado |
| QA-DJ-040 | backend/trips/test_finance.py | trips | invalid splits | API/model/domain | Aprovado |
| QA-DJ-041 | backend/trips/test_finance.py | trips | invalid amounts and precision | API/model/domain | Aprovado |
| QA-DJ-042 | backend/trips/test_finance.py | trips | all accepted members can create author not payer | API/model/domain | Aprovado |
| QA-DJ-043 | backend/trips/test_finance.py | trips | pending rejected external and unauthenticated | API/model/domain | Aprovado |
| QA-DJ-044 | backend/trips/test_finance.py | trips | only original author edits or cancels | API/model/domain | Aprovado |
| QA-DJ-045 | backend/trips/test_finance.py | trips | protected fields invalid users and atomicity | API/model/domain | Aprovado |
| QA-DJ-046 | backend/trips/test_finance.py | trips | other trip expense not found | API/model/domain | Aprovado |
| QA-DJ-047 | backend/trips/test_finance.py | trips | budget permission null zero and overrun | API/model/domain | Aprovado |
| QA-DJ-048 | backend/trips/test_finance.py | trips | api settlement flow and history no email | API/model/domain | Aprovado |
| QA-DJ-049 | backend/trips/test_finance.py | trips | balances pending confirmed and proposals | API/model/domain | Aprovado |
| QA-DJ-050 | backend/trips/test_finance.py | trips | pending reserves balance and freezes expenses | API/model/domain | Aprovado |
| QA-DJ-051 | backend/trips/test_finance.py | trips | invalid settlements | API/model/domain | Aprovado |
| QA-DJ-052 | backend/trips/test_finance.py | trips | cancelled payment restores reservation and preserves history | API/model/domain | Aprovado |
| QA-DJ-053 | backend/trips/test_finance.py | trips | confirmed payment protects original expense and trip | API/model/domain | Aprovado |
| QA-DJ-054 | backend/trips/test_finance.py | trips | exit debtor creditor pending neutral and organizer | API/model/domain | Aprovado |
| QA-DJ-055 | backend/trips/test_finance.py | trips | database constraints | API/model/domain | Aprovado |
| QA-DJ-056 | backend/trips/test_finance.py | trips | exit racing new expense is serialized and keeps history consistent | API/model/domain | Aprovado |
| QA-DJ-057 | backend/trips/test_finance.py | trips | competing confirmations only apply once | API/model/domain | Aprovado |
| QA-DJ-058 | backend/trips/test_finance.py | trips | competing payments cannot overreserve | API/model/domain | Aprovado |
| QA-DJ-059 | backend/trips/tests.py | trips | creates valid trip and links existing organizer | API/model/domain | Aprovado |
| QA-DJ-060 | backend/trips/tests.py | trips | description is optional | API/model/domain | Aprovado |
| QA-DJ-061 | backend/trips/tests.py | trips | end date before start date fails model validation | API/model/domain | Aprovado |
| QA-DJ-062 | backend/trips/tests.py | trips | database constraint blocks invalid direct save | API/model/domain | Aprovado |
| QA-DJ-063 | backend/trips/tests.py | trips | trip membership statuses are available | API/model/domain | Aprovado |
| QA-DJ-064 | backend/trips/tests.py | trips | duplicate trip member is rejected by database | API/model/domain | Aprovado |
| QA-DJ-065 | backend/trips/tests.py | trips | trips order by creation date then descending id | API/model/domain | Aprovado |
| QA-DJ-066 | backend/trips/tests.py | trips | all endpoints require authentication | API/model/domain | Aprovado |
| QA-DJ-067 | backend/trips/tests.py | trips | create trip and accepted organizer membership | API/model/domain | Aprovado |
| QA-DJ-068 | backend/trips/tests.py | trips | create trip with valid cover and friend invites | API/model/domain | Aprovado |
| QA-DJ-069 | backend/trips/tests.py | trips | create trip rejects invalid or oversized cover | API/model/domain | Aprovado |
| QA-DJ-070 | backend/trips/tests.py | trips | create with invite failure rolls back trip and cover | API/model/domain | Aprovado |
| QA-DJ-071 | backend/trips/tests.py | trips | create is atomic when organizer membership fails | API/model/domain | Aprovado |
| QA-DJ-072 | backend/trips/tests.py | trips | invalid dates and missing required fields return 400 | API/model/domain | Aprovado |
| QA-DJ-073 | backend/trips/tests.py | trips | protected creator and membership fields are ignored | API/model/domain | Aprovado |
| QA-DJ-074 | backend/trips/tests.py | trips | user without access gets 404 for private detail | API/model/domain | Aprovado |
| QA-DJ-075 | backend/trips/tests.py | trips | accepted member can view but pending member cannot | API/model/domain | Aprovado |
| QA-DJ-076 | backend/trips/tests.py | trips | list only includes owned or accepted trips | API/model/domain | Aprovado |
| QA-DJ-077 | backend/trips/tests.py | trips | list order and accepted participant count | API/model/domain | Aprovado |
| QA-DJ-078 | backend/trips/tests.py | trips | organizer can edit trip | API/model/domain | Aprovado |
| QA-DJ-079 | backend/trips/tests.py | trips | accepted non organizer cannot edit | API/model/domain | Aprovado |
| QA-DJ-080 | backend/trips/tests.py | trips | organizer can invite confirmed friend and duplicate is rejected | API/model/domain | Aprovado |
| QA-DJ-081 | backend/trips/tests.py | trips | non friend and non organizer cannot send trip invites | API/model/domain | Aprovado |
| QA-DJ-082 | backend/trips/tests.py | trips | rejected invitees are visible only to the organizer | API/model/domain | Aprovado |
| QA-DJ-083 | backend/trips/tests.py | trips | rejected member cannot be invited again | API/model/domain | Aprovado |
| QA-DJ-084 | backend/trips/tests.py | trips | invitee can list preview and accept own invitation | API/model/domain | Aprovado |
| QA-DJ-085 | backend/trips/tests.py | trips | invitee can reject own invitation but third party cannot act | API/model/domain | Aprovado |
| QA-DJ-086 | backend/trips/tests.py | trips | only organizer can add trip cover | API/model/domain | Aprovado |
| QA-DJ-087 | backend/trips/tests.py | trips | patch validates dates against existing value | API/model/domain | Aprovado |
| QA-DJ-088 | backend/trips/tests.py | trips | organizer can delete and memberships are cascaded | API/model/domain | Aprovado |
| QA-DJ-089 | backend/trips/tests.py | trips | trip with financial history cannot be deleted | API/model/domain | Aprovado |
| QA-DJ-090 | backend/trips/tests.py | trips | other accepted participant cannot delete | API/model/domain | Aprovado |
| QA-DJ-091 | backend/trips/tests.py | trips | can delete is limited to organizer without protected history | API/model/domain | Aprovado |
| QA-DJ-092 | backend/trips/tests.py | trips | member can leave and history and trip remain | API/model/domain | Aprovado |
| QA-DJ-093 | backend/trips/tests.py | trips | leave revalidates financial state after eligibility query | API/model/domain | Aprovado |
| QA-DJ-094 | backend/trips/tests.py | trips | organizer removes accepted member without deleting financial history | API/model/domain | Aprovado |
| QA-DJ-095 | backend/trips/tests.py | trips | only organizer can remove an accepted member | API/model/domain | Aprovado |
| QA-DJ-096 | backend/trips/tests.py | trips | removal is blocked by financial balance | API/model/domain | Aprovado |
| QA-DJ-097 | backend/trips/tests.py | trips | transfer preserves membership and financial authorship then old owner can leave | API/model/domain | Aprovado |
| QA-DJ-098 | backend/trips/tests.py | trips | transfer requires current organizer and accepted successor | API/model/domain | Aprovado |
| QA-DJ-099 | backend/trips/tests.py | trips | left member can be invited again without duplicate membership | API/model/domain | Aprovado |
| QA-DJ-100 | backend/trips/tests.py | trips | exit eligibility reports debt credit pending and organizer | API/model/domain | Aprovado |
| QA-DJ-101 | backend/trips/tests.py | trips | nonexistent trip ids return 404 for authenticated user | API/model/domain | Aprovado |
| QA-API-001 | qa/playwright/tests/account.spec.ts | Account | perfil atualiza nome, exige senha ao trocar email e isola contas | API Playwright | Aprovado |
| QA-API-002 | qa/playwright/tests/account.spec.ts | Account | avatar aceita imagem válida, rejeita arquivo falso e permite remoção | API Playwright | Aprovado |
| QA-API-003 | qa/playwright/tests/auth.spec.ts | Auth | login, refresh, credenciais inválidas e proteção JWT | API Playwright | Aprovado |
| QA-API-004 | qa/playwright/tests/expenses.spec.ts | Expenses | quatro modalidades persistem parcelas monetárias calculadas pelo backend | API Playwright | Aprovado |
| QA-API-005 | qa/playwright/tests/expenses.spec.ts | Expenses | edição exige autoria e versão, cancelamento preserva registro histórico | API Playwright | Aprovado |
| QA-API-006 | qa/playwright/tests/friends.spec.ts | Friends | solicitação pendente só é aceita pelo destinatário | API Playwright | Aprovado |
| QA-API-007 | qa/playwright/tests/invitations.spec.ts | Invitations | convite permanece pendente, é privado e só passa a acesso após aceite | API Playwright | Aprovado |
| QA-API-008 | qa/playwright/tests/invitations.spec.ts | Invitations | convite é restrito ao organizador e apenas amigos podem ser convidados | API Playwright | Aprovado |
| QA-API-009 | qa/playwright/tests/notifications.spec.ts | Notifications | notificações são isoladas por usuário e leitura atualiza contador | API Playwright | Aprovado |
| QA-API-010 | qa/playwright/tests/permissions.spec.ts | Permissions | organizador remove participante aceito e terceiro não altera viagem | API Playwright | Aprovado |
| QA-API-011 | qa/playwright/tests/permissions.spec.ts | Permissions | transferência preserva o acesso e permite a saída posterior do antigo organizador | API Playwright | Aprovado |
| QA-API-012 | qa/playwright/tests/settlements.spec.ts | Settlements | pagamento pendente só é confirmado pela contraparte e atualiza saldos | API Playwright | Aprovado |
| QA-API-013 | qa/playwright/tests/settlements.spec.ts | Settlements | acerto pendente bloqueia nova despesa e mantém saldo reservado | API Playwright | Aprovado |
| QA-API-014 | qa/playwright/tests/trips.spec.ts | Trips | viagem é consultável pelo organizador e protegida contra terceiros | API Playwright | Aprovado |
| QA-API-015 | qa/playwright/tests/trips.spec.ts | Trips | organizador edita e pode excluir viagem sem histórico protegido | API Playwright | Aprovado |
| QA-INT-001 | integration_test/tripmate_smoke_test.dart | Android | QA real: login, criar viagem, lançar gasto, gerenciar e sair | Integration | Aprovado |
| QA-INT-002 | integration_test/tripmate_smoke_test.dart | Android | QA real: convite de viagem aceito na segunda conta | Integration | Aprovado |

Total inventariado: **225** casos declarados (inclui integração preparada).
