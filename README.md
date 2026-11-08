# TripMate

Aplicativo mobile para planejar viagens em grupo, convidar amigos e registrar como as despesas são divididas e acertadas entre os participantes.

## Funcionalidades

- Cadastro, login e sessão JWT, com atualização de token.
- Perfil com edição de dados e gerenciamento de foto.
- Busca de usuários e solicitações de amizade.
- Criação de viagens com datas, destino, foto de capa e convites a amigos.
- Aceite e recusa de convites; gerenciamento de participantes e organização da viagem.
- Registro de despesas com divisão igualitária, valores exatos, porcentagens ou cotas.
- Resumo de despesas e saldos; pagamentos declarados como acertos que precisam da confirmação da contraparte.
- Central de notificações internas para eventos do aplicativo.
- Navegação principal entre Home, Amigos e Perfil, além das telas de viagens.

## Tecnologias

- **Aplicativo:** Flutter e Dart; Material, Manrope, `http`, `flutter_secure_storage`, `image_picker` e Lottie.
- **API:** Python, Django REST Framework, SimpleJWT e Pillow.
- **Dados locais de desenvolvimento:** SQLite e arquivos de mídia do Django.
- **QA:** testes unitários e de widget Flutter, testes Django, integração Android com `integration_test` e testes de API Playwright/TypeScript.

## Arquitetura resumida

O Flutter apresenta as telas e chama os serviços HTTP autenticados com JWT. A API Django valida permissões e regras de domínio de contas, amizades, viagens, convites, despesas, acertos e notificações. O SQLite e o diretório de mídia local servem ao desenvolvimento; não são incluídos no Git. Os testes Playwright e o runner Android usam ambiente QA isolado, sem apontar para o banco de desenvolvimento.

## Estrutura

```text
lib/                    Aplicativo Flutter: telas, modelos, serviços e widgets
assets/                 Fonte, imagens e animação usadas pelo app
android/                Projeto Android, flavors dev e qa e Gradle Wrapper
backend/                Projeto Django e aplicativos accounts, friends, trips e notifications
qa/playwright/          Testes HTTP da API com Playwright
integration_test/       Testes de integração executados no dispositivo Android
test/                   Testes Flutter unitários e de widget
docs/qa/                Plano, casos, matriz, cobertura e evidências de QA
```

## Requisitos

- Flutter/Dart compatível com a restrição `sdk: ^3.13.7` em `pubspec.yaml`.
- Python 3.12 ou mais recente e pip.
- Node.js compatível com Playwright Test 1.56 ou mais recente, para os testes de API.
- Para testes físicos Android: Android SDK/ADB e dispositivo autorizado.

## Configurar o Flutter

Na raiz do repositório:

```powershell
flutter pub get
flutter analyze
flutter test
```

O flavor `dev` é o padrão. A origem da API pode ser definida em execução sem editar o código:

```powershell
# Emulador Android padrão: o host da máquina é acessível por 10.0.2.2.
flutter run --flavor dev --dart-define=TRIPMATE_API_HOST=http://10.0.2.2:8000
```

Em um dispositivo físico conectado por ADB, encaminhe a porta local do backend:

```powershell
adb reverse tcp:8000 tcp:8000
flutter run --flavor dev
```

O aplicativo usa `http://127.0.0.1:8000` por padrão. O encaminhamento ADB faz essa origem chegar ao computador de desenvolvimento.

## Configurar e executar o Django

No PowerShell, a partir da raiz do repositório:

```powershell
py -3.12 -m venv backend/.venv
backend/.venv/Scripts/Activate.ps1
python -m pip install -r backend/requirements.txt

# Defina uma chave local aleatória para esta sessão do terminal.
$env:DJANGO_SECRET_KEY = (python -c "import secrets; print(secrets.token_urlsafe(50))")

Set-Location backend
python manage.py migrate
python manage.py check
python manage.py runserver 0.0.0.0:8000
```

`DJANGO_SECRET_KEY` é configuração local e nunca deve ser publicada. Se a variável não estiver definida, Django gera uma chave temporária aleatória ao iniciar; nesse caso, reiniciar o servidor invalida tokens existentes. Defina uma chave local estável para a sessão de desenvolvimento. `DEBUG=True`, o SQLite e a mídia local são destinados ao desenvolvimento, não à produção.

A API local inclui `/api/auth/`, `/api/friends/`, `/api/trips/` e `/api/notifications/`. Os contratos de viagem e finanças estão documentados em `backend/trips/API.md` e `backend/trips/FINANCE_API.md`; notificações em `backend/notifications/API.md`.

## Testes

```powershell
# Flutter
flutter analyze
flutter test --coverage

# Django
Set-Location backend
python manage.py test
python manage.py makemigrations --check --dry-run

# Playwright API (com o backend/.venv configurado)
Set-Location ../qa/playwright
npm ci
npm test
```

Playwright inicia um servidor QA local na porta `8765` com banco e mídia temporários. Para testar a integração nativa em um A71 conectado e desbloqueado, execute da raiz:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File qa/run-android-integration.ps1
```

O runner utiliza somente o flavor `qa`, contas artificiais e armazenamento temporário. Consulte os [procedimentos e resultados de QA](docs/qa/README.md) antes de repetir a execução.

## Limitações atuais do MVP

- O projeto está preparado para desenvolvimento local; não há configuração de backend de produção, serviço de armazenamento de mídia de produção ou publicação na Play Store neste repositório.
- A aba/funcionalidade de roteiro não faz parte do MVP.
- As integrações Android QA-INT-003–006 (financeiro completo, ciclo de acerto, ações destrutivas e notificações pela UI) ainda precisam ser implementadas e validadas no dispositivo. Os testes de API não substituem essa validação nativa.
- Notificações são internas ao aplicativo; não há integração de push/Firebase.

Consulte [docs/qa/README.md](docs/qa/README.md) para a estratégia, inventário, resultados e evidências das suítes.
