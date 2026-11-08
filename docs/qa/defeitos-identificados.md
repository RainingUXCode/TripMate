# Defeitos e ocorrências de QA

## QA-TOOL-001 — quoting do caminho do servidor no runner Android

- **Severidade:** baixa; ferramenta de QA.
- **Módulo:** `qa/run-android-integration.ps1`.
- **Reprodução:** executar o script em um workspace cujo caminho contenha espaços. A tentativa inicial dividiu o caminho ao passá-lo ao Python.
- **Esperado:** iniciar `qa_server.py` no diretório correto e aplicar apenas o reverse QA.
- **Obtido:** servidor encerrou antes de iniciar.
- **Correção:** o argumento do servidor passou a ser citado explicitamente.
- **Reteste:** servidor inicializou em `127.0.0.1:8765`, migrou banco temporário e respondeu ao health request; a execução final 14B validou os fluxos UI no A71.
- **Status:** corrigido e retestado de ponta a ponta em QA-INT-001/002.
- **Evidência:** `docs/qa/evidencias/etapa-14b.md`. Logs brutos locais são excluídos do Git.

## QA-ENV-001 — aparelho Android bloqueado

- **Severidade:** bloqueio de validação, não defeito do produto.
- **Módulo:** ambiente físico de integração.
- **Reprodução:** iniciar flavor QA no A71; tela de bloqueio segura permanece à frente do app, sem fornecer autenticação do dispositivo.
- **Esperado:** integração conseguir interagir com a UI no dispositivo autorizado e desbloqueado.
- **Obtido:** os dois testes `integration_test` não completaram; apenas compilação/instalação do flavor foram verificadas.
- **Status:** bloqueado. Não tentamos contornar o mecanismo de bloqueio. O pacote QA e reverse temporário foram limpos; `tcp:8000` foi preservado.
- **Evidência histórica:** `docs/qa/evidencias/android-integracao-bloqueada.md`; os fluxos foram concluídos depois na Etapa 14B.

## Defeitos de produto — baseline da Etapa 14

Nenhum defeito de produto reproduzido nas 100 verificações Flutter, 94 Django e 13 Playwright da Etapa 14. Isso não representa garantia de ausência de defeitos fora dos cenários cobertos.

## Etapa 14B — ocorrências da integração

### QA-INT-001 — seletores de teste incompatíveis com a UI real

- **Severidade:** ferramenta de teste.
- **Ocorrências:** o teste esperava saudação única apesar de haver snackbar com o nome, usava `OK` embora o seletor de data apresente `Confirmar`, e comparava valor monetário como texto de uma linha embora o componente permita quebra de linha.
- **Correções:** seletor exato da saudação, rótulo `Confirmar` e verificação monetária pela resposta persistida do endpoint real.
- **Status:** encerrado como defeitos da automação corrigidos. O smoke final passou, confirmou a despesa persistida pela API e completou o fluxo de gerenciamento no A71.

### QA-INT-002 — estado de sessão entre casos no mesmo processo Android

- **Severidade:** ferramenta de teste.
- **Obtido:** após falha anterior antes do logout, o próximo caso tentou localizar campos de login enquanto a sessão continuava ativa. A falha subsequente foi efeito cascata, não validação do fluxo de convite.
- **Status:** encerrado como defeito da automação corrigido. O smoke final voltou à Home antes do logout de troca de conta; QA-ANDROID-002 passou e confirmou o aceite e os dois participantes.

### QA-TOOL-002 — screenshot via canal Flutter Driver

- **Severidade:** ferramenta de evidência.
- **Obtido:** pedido de screenshot pelo canal de integração não retornou no A71 e bloqueou a continuação do teste.
- **Correção:** screenshot de integração removido; evidência de tela real foi capturada pelo ADB enquanto o flavor `.qa` estava aberto. Os logs sanitizados permanecem em `docs/qa/evidencias/`.
