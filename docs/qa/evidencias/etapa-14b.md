# Evidências — Etapa 14B

**Dispositivo:** Samsung Galaxy A71.

**Data local:** 08/11/2026.
**Ambiente Android:** flavor `qa`, API `127.0.0.1:8765`, SQLite e mídia isolados por execução.

## Resultados automatizados

- Flutter: análise limpa e 107 testes aprovados; cobertura registrada em `coverage/lcov.info` (artefato local, não versionar).
- Django: 101 testes aprovados; `check` e migrations sem diferenças; cobertura escrita em `%TEMP%`.
- Playwright API: 15 testes aprovados; execução usa o servidor efêmero e JSON `qa/playwright/test-results/report.json`.
- Android QA-INT-001/002: aprovados via `flutter drive` no A71; o runner concluiu os dois fluxos no flavor `qa`. Os casos Android 003–006 não foram executados.

## Arquivos de evidência

- Captura real do A71: [android-qa-14b-home.png](android-qa-14b-home.png). Foi obtida via `adb shell screencap` enquanto a variante QA estava ativa; as contas e a viagem exibidas são fixtures artificiais.
- O relatório de execução contém a síntese sanitizada dos resultados; logs brutos são ignorados e permanecem somente no ambiente local.
- Relatório Playwright sanitizado: `qa/playwright/test-results/report.json` registra nomes de testes e status; traces de falha não são publicados como evidência.

Captura por `integration_test`/Flutter Driver foi retirada após o canal de screenshot bloquear a execução no A71; a captura externa via ADB comprovou a tela efetivamente renderizada. Nenhum dado do banco de desenvolvimento foi usado. O runner encerrou removendo a variante QA e o reverse temporário `8765`, preservando o reverse existente `8000`.
