# Relatório de cobertura — QA Etapa 14

## Flutter

- Comando: `flutter test --coverage`
- Medida: cobertura de linhas executadas pelo conjunto `flutter_test`/testes de widget; não inclui execução Android nativa.
- Resultado: **3.779 de 5.693 linhas = 66,4%**.

| Diretório `lib/` | Linhas cobertas | Linhas consideradas | Cobertura |
|---|---:|---:|---:|
| `screens` | 3.185 | 4.696 | 67,8% |
| `services` | 242 | 559 | 43,3% |
| `widgets` | 244 | 299 | 81,6% |
| `models` | 44 | 45 | 97,8% |
| arquivos na raiz/core e demais | 64 | 94 | 68,1% |

O artefato bruto `coverage/lcov.info` é gerado localmente e permanece ignorado pelo Git. A cobertura não mede quantas regras estão corretas; serviços e fluxos de rede ainda têm caminhos sem execução no teste de widget.

## Django

- Ferramenta: `coverage.py 7.17.2` (registrada em `backend/requirements-qa.txt`).
- Comando: execução de toda a suíte Django pelo test runner, seguida de `coverage report` excluindo testes, migrations, admin, configuração de apps e URLs.
- Resultado dos módulos de aplicação: **1.102 de 1.310 linhas = 84,1%**.
- Incluindo arquivos de teste e migrations, o mesmo run mostra 2.259/2.478 linhas (91,2%); essa métrica é secundária e não representa cobertura do código de produção.

| Área de produção | Cobertura de linhas |
|---|---:|
| `accounts` (models, serializers e views) | 99/218 — 45,4% |
| `friends` (models, serializers, throttles e views) | 143/175 — 81,7% |
| `trips` e financeiro (models, serializers, services, views e domínio) | 747/800 — 93,4% |
| `notifications` (models, serializers, services, views e paginação) | 83/85 — 97,6% |

O arquivo de dados da cobertura foi colocado em `%TEMP%`, e não no banco SQLite de desenvolvimento. Cobertura de cenário/regras é rastreada separadamente em [matriz-de-rastreabilidade.md](matriz-de-rastreabilidade.md).

Os módulos com maior lacuna são autenticação/perfil (`accounts`, em especial serializers/views) e o transporte de API no Flutter (`services`). Os testes de widget usam fakes para isolar serviços; a cobertura Playwright verifica os contratos HTTP, mas não substitui testes unitários Flutter específicos dos adaptadores.

## Complemento — Etapa 14B (08/11/2026)

| Suíte / área | Etapa 14 | Etapa 14B | Método |
|---|---:|---:|---|
| Flutter total | 3.779/5.693 (66,4%) | 3.868/5.693 (**67,9%**) | `flutter test --coverage`; 107 testes aprovados |
| Flutter `lib/services` | 242/559 (43,3%) | 331/559 (**59,2%**) | Inclui 7 testes novos de `AuthService` com `MockClient` e secure storage mockado |
| Django produção | 1.102/1.310 (84,1%) | 1.197/1.310 (**91,4%**) | 101 testes Django aprovados; cobertura salva em `%TEMP%` |
| Django `accounts` | 99/218 (45,4%) | 194/218 (**89,0%**) | Casos de perfil, troca de e-mail, senha, upload/rejeição/remoção de avatar e autenticação |

As métricas de linhas representam caminhos executados e não provam todos os comportamentos. A cobertura Flutter não inclui os fluxos físicos de `integration_test`; os resultados Android devem ser lidos separadamente no relatório de execução.

Na integração física, QA-INT-001/002 passaram no Galaxy A71. QA-INT-003/004/005/006 não foram implementados nem executados nesta etapa; portanto, as métricas de código e os testes de API não devem ser interpretados como cobertura desses fluxos na UI Android.
