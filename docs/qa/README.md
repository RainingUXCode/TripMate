# TripMate — Quality Assurance

Esta pasta concentra plano, casos, matriz, inventário automatizado, execução, cobertura, defeitos e evidências sanitizadas das Etapas 14 e 14B. Na Etapa 14B, as duas integrações Android previstas originalmente passaram no A71; os cenários complementares Android 003–006 seguem pendentes e não são inferidos a partir dos testes HTTP.

## Estrutura

- [Plano](plano-de-testes.md)
- [Casos críticos](casos-de-teste.md)
- [Matriz de rastreabilidade](matriz-de-rastreabilidade.md)
- [Inventário de 225 casos declarados](inventario-de-testes.md)
- [Relatório de execução](relatorio-de-execucao.md)
- [Relatório de cobertura](relatorio-de-cobertura.md)
- [Defeitos e bloqueios](defeitos-identificados.md)
- [Evidência resumida da Etapa 14B](evidencias/etapa-14b.md)
- `evidencias/`: resumos de resultados sem credenciais ou dados privados.

## Execução no Windows

### Flutter (na raiz do repositório)

```powershell
flutter analyze
flutter test
flutter test --coverage
```

### Django (diretório `backend`)

```powershell
Set-Location backend
# Necessário apenas no ambiente sem coverage.py instalado:
.\.venv\Scripts\python.exe -m pip install -r requirements-qa.txt
.\.venv\Scripts\python.exe manage.py check
.\.venv\Scripts\python.exe manage.py makemigrations --check --dry-run
.\.venv\Scripts\python.exe manage.py test --verbosity 1
$coverageFile = Join-Path $env:TEMP 'tripmate-etapa14.coverage'
.\.venv\Scripts\python.exe -m coverage run --data-file="$coverageFile" manage.py test --verbosity 1
.\.venv\Scripts\python.exe -m coverage report --data-file="$coverageFile" --omit='*/tests.py,*/test_*.py,*/migrations/*,*/admin.py,*/apps.py,*/urls.py' -m
```

O test runner Django usa o banco de testes; o comando não apaga nem recria `backend/db.sqlite3`.

### Playwright (diretório `qa/playwright`)

```powershell
Set-Location qa/playwright
npm ci
npm test
```

`npm test` inicia o servidor de API em loopback na porta `8765`, com banco/media temporários exclusivos, aplica migrations e os remove ao parar. Não aponte a suíte para o servidor do ambiente pessoal. Não é necessário instalar browser: a automação usa `APIRequestContext`.

### Integração Flutter/Android

Com o A71 conectado, autorizado e desbloqueado:

```powershell
Set-Location (git rev-parse --show-toplevel)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File qa/run-android-integration.ps1
```

O runner verifica o flavor/package `.qa`, banco/media descartáveis e porta `8765`, configura apenas o reverse desta porta e limpa seus próprios artefatos. Ele usa `flutter drive` com o driver oficial do `integration_test`. Aborta se o package QA já existir ou se `8765` estiver ocupada. Não altera deliberadamente o reverse `8000` já usado pelo app principal.

### Regerar inventário

Após executar as suítes, atualize os estados observados:

```powershell
python qa/generate_inventory.py --flutter Aprovado --django Aprovado --integration Bloqueado
```

Para uma nova execução, não copie o status atual sem verificar os resultados; use `--help` para opções `Aprovado`, `Reprovado`, `Bloqueado` ou `Não executado`. Playwright usa o estado do relatório JSON mais recente.

## Segurança e interpretação

Não versionar `.coverage`, `coverage/lcov.info`, trace Playwright, JWT, senhas ou fixtures de usuários reais. Cobertura de linhas é apenas uma métrica; consulte os cenários rastreados. Build Android ou instalação QA, sem conclusão de asserções, não equivale a fluxo aprovado.
