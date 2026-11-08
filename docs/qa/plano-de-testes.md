# Plano de testes — TripMate QA Etapa 14

## Objetivo e escopo

Verificar regressões do MVP nas camadas Flutter (serviços, widgets e navegação), Django REST Framework (regras de negócio, privacidade, financeiro e notificações), API via Playwright e fluxo Flutter instalado em Android. O backend permanece sem alteração funcional nesta etapa; as únicas mudanças no backend são testes de autenticação e dependência de cobertura.

## Critérios

- **Entrada:** dependências existentes instaladas, banco de desenvolvimento preservado, ambiente de QA isolado e device identificado antes de executar integração.
- **Saída:** suíte executada com resultado reportado, validações Django concluídas, análise Flutter limpa ou diagnósticos restantes documentados, e cenários não executados explicitamente pendentes.
- **Aprovação:** asserções de estado e pós-condições passam; somente status observado na execução pode ser aprovado.

## Ambiente e ferramentas

- Windows PowerShell, Flutter e Dart SDK, Python virtualenv `backend/.venv`, Django/DRF do projeto, Playwright TypeScript com `@playwright/test`, Android Debug Bridge e Samsung Galaxy A71.
- Django tests usam o banco temporário criado pelo test runner. Playwright inicia uma instância local em `127.0.0.1:8765` com SQLite e media em diretório temporário exclusivo por execução. A integração usa flavor `.qa` e host via `TRIPMATE_API_HOST`, sem substituir a configuração padrão do app.
- Nunca executar mutações de Playwright contra o SQLite usado no desenvolvimento. O servidor QA recusa porta ocupada, vincula somente loopback e valida o diretório de dados temporários.

## Estratégia

1. Inventariar testes por arquivo/caso e relacioná-los aos módulos.
2. Rodar análise estática e suíte Flutter com cobertura.
3. Rodar `manage.py check`, migrations em dry-run, testes Django com `coverage.py`.
4. Rodar Playwright API serialmente contra o servidor descartável.
5. Tentar os fluxos Android apenas em flavor QA e interromper se o dispositivo exigir desbloqueio não fornecido.
6. Preservar logs resumidos sem tokens, senhas, dados pessoais ou traces contendo credenciais.

## Funcionalidades críticas e riscos

Autenticação JWT e isolamento de conta; amizades e convites pendentes/aceitos; privacidade e permissões de viagem; despesas e divisões; controle de versão; saldos, acertos e idempotência; bloqueio de operações incompatíveis com histórico financeiro; notificações privadas. Riscos de QA incluem cobertura de linhas não representar integralmente regras e estado externo do A71 impedir testes de toque.

## Limitações

Playwright valida a API HTTP, não os widgets nativos Flutter. `flutter test --coverage` cobre testes unitários/widget e não é cobertura dos fluxos Android. A integração Android só pode ser declarada executada se for concluída no dispositivo desbloqueado; build ou instalação isoladamente não contam como sucesso de cenário.

## Execução adicional — Etapa 14B (08/11/2026)

Esta rodada preserva os resultados históricos da Etapa 14 e complementa os testes de conta, transporte HTTP, permissões e integração nativa. O Android usa `flutter drive` com `integration_test_driver.dart`, flavor `qa`, servidor em loopback `127.0.0.1:8765` e banco/mídia exclusivos por execução. Os dados de registro e viagem são artificiais e ficam apenas no banco temporário.

- Flutter: 107 testes aprovados; análise estática sem diagnósticos; cobertura 3.868/5.693 linhas (67,9%). Cobertura de `lib/services`: 331/559 (59,2%).
- Django: 101 testes aprovados; `check` e verificação de migrations aprovados; cobertura de código de aplicação 1.197/1.310 (91,4%), com `accounts` em 194/218 (89,0%).
- Playwright API: 15 testes aprovados, incluindo atualização cadastral e upload, rejeição e remoção de avatar.
- Android A71: QA-INT-001 e QA-INT-002 passaram no flavor QA; a despesa foi persistida e o convite foi aceito pela segunda conta. O smoke final está identificado em [relatorio-de-execucao.md](relatorio-de-execucao.md). As capturas e logs são exclusivamente de execução QA.

Os cenários Android complementares 003–006 não foram implementados nem executados nesta rodada. Eles abrangem fluxos nativos multiusuário de divisão financeira, ciclo completo de acertos, confirmações destrutivas e navegação por notificações. A automação cobre partes das regras por Flutter/Django/Playwright, conforme a matriz, mas isso não valida a interface Android nem substitui os cenários pendentes.
