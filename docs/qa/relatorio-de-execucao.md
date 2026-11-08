# Relatório de execução — QA Etapa 14

**Data:** 07/11/2026 (America/Sao_Paulo, UTC−03:00). Os horários de suíte abaixo são locais; nenhum token, senha ou dado de conta foi incluído neste relatório.

## Resumo

| Suíte | Comando / ferramenta | Executados | Aprovados | Reprovados | Ignorados/bloqueados | Resultado |
|---|---|---:|---:|---:|---:|---|
| Flutter análise | `flutter analyze` | análise do projeto | — | 0 | 0 | Aprovada; executada ~23:10; `No issues found` |
| Flutter unit/widget/regressão | `flutter test --coverage` | 100 | 100 | 0 | 0 | Aprovada na execução final ~23:17:30–23:18:08, ~38 s |
| Django | `python -m coverage run ... manage.py test --verbosity 1` | 94 | 94 | 0 | 0 | Aprovada; ~23:10:51–23:13:47, 176,112 s |
| Django check/migrations | `manage.py check`; `makemigrations --check --dry-run` | 2 verificações | 2 | 0 | 0 | Aprovadas ~23:15; sem alterações de migration |
| Playwright API | `npm test` em `qa/playwright` | 13 | 13 | 0 | 0 | Aprovada; 22:44:59–22:46:46, 107,064 s |
| Flutter Android | `qa/run-android-integration.ps1` no Samsung Galaxy A71 | 2 preparados | 0 | 0 | 2 bloqueados | ~22:52–23:00; APK QA compilado/instalado; fluxos bloqueados pela tela de bloqueio |
| Build Android padrão | `flutter build apk --debug --no-pub` | flavor `dev` | — | — | 0 | Aprovado; ~23:11:18–23:13:56, 158,1 s |

## Auditoria e cobertura existente

O inventário encontrou 13 arquivos de teste Flutter, cobrindo shell, criação de viagem, notificações, contador de amigos, acertos, splash, card, tela de detalhes, convites, listagem, serviços e avatar. O conjunto Flutter já tinha cobertura de widget e serviço extensa; foram reaproveitados os 100 casos existentes e acrescentados dois fluxos `integration_test` reais para execução Android.

O backend tinha casos em `friends`, `trips` e `notifications`, incluindo privacidade, regras de amizade/convite, divisões financeiras, saldos, confirmações, idempotência e gestão. `accounts/tests.py` era vazio; foram acrescentados seis testes JWT/privacidade.

Foi criado um projeto Playwright independente com 13 cenários API, sem navegador, usando `APIRequestContext` e servidor Django efêmero. A suíte confirma estados posteriores e permissões além de códigos HTTP.

## Android e isolamento

O APK `qa` foi construído no flavor `qa`, com identificador `com.example.tripmate.qa` e base URL de QA na porta `8765`. O A71 estava em estado de bloqueio seguro (`Dozing`, tela de bloqueio visível). O fluxo UI ficou sem interação e foi interrompido, sem tentar contornar o bloqueio. Os cenários Android estão **bloqueados**, não aprovados. O script remove a variante QA ao terminar e remove apenas o reverse `8765`; o reverse preexistente `8000` permaneceu preservado. O build comum `dev` também compilou sem `--flavor`, mantendo o identificador base e host local padrão.

Playwright gravou cada execução em SQLite e media temporários com ID exclusivo, em loopback. As mutações não foram direcionadas ao banco local de desenvolvimento.

## Ajustes de QA

- Corrigidos os dez diagnósticos informativos de lint que a análise inicial reportava, usando apenas alterações de estilo/estrutura sem mudança de comportamento.
- Ajustado o script Android para citar corretamente o caminho do servidor com espaços e isolar o tráfego pela porta `8765`.
- Configurado o flavor de desenvolvimento como padrão (`dev`, pacote/base URL existentes), mantendo `qa` como flavor isolado; `flutter analyze` passou após a configuração.
- A expectativa Playwright de acesso privado de terceiro foi alinhada ao contrato observado: Django retorna `404` para objeto fora do queryset autorizado.
- Não foi identificado defeito de produto nas suítes executadas. A inicialização Android, a primeira vez, falhou pelo quoting; corrigida e o servidor QA iniciou, mas o cenário permaneceu bloqueado pelo estado seguro do aparelho.

## Limitações e acompanhamento

Integração visual no Android não foi validada. Desbloquear o A71 e executar `powershell -ExecutionPolicy Bypass -File qa/run-android-integration.ps1` é a única pendência para validar os dois fluxos nativos. Também ficam para etapa futura os cenários Android dedicados de acerto/contraparte e de confirmação destrutiva no gerenciamento. Não foram declarados aprovados com base apenas na compilação.

## Execução identificada — Etapa 14B (08/11/2026)

Esta seção complementa o histórico acima; não o substitui.

| Suíte | Executados | Aprovados | Reprovados | Resultado observado |
|---|---:|---:|---:|---|
| Flutter analyze | análise do projeto | — | 0 | Aprovada, sem diagnósticos |
| Flutter unit/widget | 107 | 107 | 0 | Aprovada; `flutter test --coverage` |
| Django | 101 | 101 | 0 | Aprovada; `manage.py check` e `makemigrations --check --dry-run` sem problemas |
| Playwright API | 15 | 15 | 0 | Aprovada; 2 casos novos de perfil e avatar |
| Android QA-INT-001/002 | 2 declarações | 2 | 0 | **Aprovada** na execução final do A71, flavor `qa`; persistência da despesa e convite aceito verificados. |
| Android QA-INT-003–006 | 0 | 0 | 0 | Não executados como testes Android. Regras associadas cobertas parcialmente por API e Flutter conforme matriz. |

### Cobertura e duração

- Flutter: 3.868/5.693 linhas (67,9%); serviços 331/559 (59,2%). 107 testes passaram.
- Django: 1.197/1.310 linhas de aplicação (91,4%); `accounts` 194/218 (89,0%). 101 testes passaram em aproximadamente 150 s.
- Playwright: 15/15 passaram em aproximadamente 1 min 24 s, com DB/media temporários exclusivos.
- Android: Samsung Galaxy A71, flavor `qa`, host loopback `127.0.0.1:8765`. QA-INT-001/002 passaram na execução final; tentativas anteriores com falhas da automação foram mantidas como histórico local. A captura `android-qa-14b-home.png` foi obtida pelo ADB e não é mock. Logs brutos são excluídos do Git.

### Alterações de QA nesta rodada

- Adicionados 7 testes `AuthService`, 7 testes Django de conta (13 no arquivo após a expansão) e 2 cenários Playwright de perfil/avatar.
- O problema de exclusão de avatar observado no primeiro teste Django era cache de relação no objeto de usuário de `force_authenticate`; o teste agora autentica uma instância recarregada. O endpoint não foi alterado.
- Runner passou a usar `flutter drive` e o driver oficial do `integration_test`, pois o modo `flutter test -d` apenas abria a aplicação e não conduzia os testes no dispositivo.
- Corrigidas expectativas/teste de saudação e data. O preço da despesa é verificado na resposta persistida pela API, sem depender de quebra visual de linha.

Após a execução final, o runner removeu o pacote `com.example.tripmate.qa` e o reverse temporário `tcp:8765`; o reverse `tcp:8000` foi preservado. Android QA-INT-003–006 continuam não executados nesta etapa.
