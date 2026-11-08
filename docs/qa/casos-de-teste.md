# Casos de teste QA

Este catálogo descreve os cenários críticos. O inventário completo dos testes automatizados, com IDs por caso, arquivo, módulo, tipo e resultado, está em [inventario-de-testes.md](inventario-de-testes.md).

| ID | Módulo e objetivo | Pré-condição/dados | Procedimento e resultado esperado | Resultado observado / status | Automação e evidência |
|---|---|---|---|---|---|
| QA-AUTH-001 | Login válido emite JWT | Conta efêmera válida | POST login; receber access/refresh e usuário público | **Aprovado**; login/refresh e payload público passaram | Django + Playwright; `django-resumo.md`, `playwright-resumo.json` |
| QA-AUTH-002 | Credenciais inválidas | Conta não correspondente | POST login; credenciais rejeitadas sem sessão | **Aprovado**; rejeição verificada | Django + Playwright; mesmos resumos |
| QA-AUTH-003 | Perfil, e-mail e avatar | Duas contas e imagem QA | Atualizar nome/e-mail; exigir senha atual; carregar/validar/remover avatar; impedir mistura de contas | **Aprovado** na rodada 14B: Django e Playwright; 13 casos Django em accounts e 2 specs HTTP | `accounts/tests.py`, `account.spec.ts` |
| QA-TRIP-001 | Privacidade de viagem | Organizador, participante aceito e terceiro | Consultar detalhe com cada identidade; só organizador/aceito acessam | **Aprovado**; terceiro recebeu resposta privada esperada e listagem isolada | Django + Playwright; mesmos resumos |
| QA-INV-001 | Convite pendente e aceite | Dois amigos confirmados e viagem existente | Convidar; conferir estado pending; destinatário aceita; confirmar membro accepted | **Aprovado**; estados e acesso pós-aceite passaram | Django + Playwright; mesmos resumos |
| QA-FIN-001 | Divisões financeiras e valores | Participantes aceitos; quantias decimais | Exercitar igual, exata, porcentagem e cotas; total deve reconciliar em centavos | **Aprovado** nas verificações executadas; divisão e rejeição de valores inválidos cobertas | Django + Playwright + Flutter; relatórios/resumos |
| QA-FIN-002 | Versão e bloqueios de acerto | Despesa/acerto pendente | Editar com versão atual e obsoleta; tentar operação bloqueada; confirmar conflito e estado preservado | **Aprovado**; conflitos e bloqueio por acerto passaram | Django + Playwright; mesmos resumos |
| QA-SET-001 | Acerto exige contraparte | Saldo válido entre duas pessoas | Criar acerto; impedir autoconfirmação; contraparte confirma; saldo atualiza | **Aprovado**; contraparte, reserva de saldo e idempotência cobertas | Django + Playwright; mesmos resumos |
| QA-NOTIF-001 | Notificações privadas | Eventos de mais de uma conta | Listar/contar/marcar leitura em cada conta; não vazar eventos entre usuários | **Aprovado**; isolamento, leitura e contagem passaram | Django + Playwright + Flutter; mesmos resumos |
| QA-WIDGET-001 | TripDetails regressão | Tela com dados controlados | Alternar Visão geral/Gastos; dados financeiros e participantes exibidos; Roteiro ausente | **Aprovado** dentro da suíte Flutter de 100 casos | Flutter widget; `flutter-resumo.md` |
| QA-ANDROID-001 | Login, viagem, gasto e gerenciamento | A71 conectado/desbloqueado; backend QA efêmero | Completar o fluxo na variante `.qa`; validar persistência após navegação | **Aprovado na execução final 14B**: login, criação, despesa persistida, troca de abas/dados e gerenciamento concluídos no A71 | `integration_test/tripmate_smoke_test.dart`; [evidência 14B](evidencias/etapa-14b.md) |
| QA-ANDROID-002 | Convite aceito pela segunda conta | A71 desbloqueado e amizade de QA | Criar convite pendente, entrar como convidado e aceitar; contador/lista atualiza | **Aprovado na execução final 14B**: convite pendente consultado pela segunda conta, aceite pela UI e presença dos dois participantes confirmada | `integration_test/tripmate_smoke_test.dart`; [evidência 14B](evidencias/etapa-14b.md) |

Os cenários Android 003–006 (financeiro em UI, acerto completo, operações destrutivas com confirmação e notificações em UI) **não foram executados**. As correspondentes verificações de API são relatadas na suíte Playwright, sem equivalência com validação nativa.

## Convenções de status

- **Aprovado:** teste realmente executado com todas as asserções passando.
- **Reprovado:** falha observada na implementação/asserção válida.
- **Bloqueado:** dependência externa impede executar o cenário.
- **Não executado:** cenário não iniciado.

Os status definitivos são preenchidos no relatório após a execução, e não inferidos do código do teste.
