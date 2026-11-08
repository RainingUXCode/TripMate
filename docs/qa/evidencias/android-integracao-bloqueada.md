# Evidência de bloqueio Android — 07/11/2026

Janela aproximada local: **22:52–23:00 (America/Sao_Paulo)**.

- Dispositivo detectado: Samsung SM-A715F (A71), ADB autorizado.
- Flavor compilado: `qa`; pacote temporário `com.example.tripmate.qa`.
- Host QA: `127.0.0.1:8765`, SQLite/media sob `%TEMP%\tripmate-qa-runs\run-<id>`.
- API QA inicializou e aceitou uma criação de conta efêmera.
- Estado físico observado: `mWakefulness=Dozing`; após acordar o display, permaneceu a tela de bloqueio segura. Não tentamos desbloquear o telefone nem usar credenciais não fornecidas.
- Resultado: dois cenários iniciados, nenhum completado; **bloqueados, não aprovados**.
- Limpeza: processo QA e reverse `8765` removidos pelo script. O reverse preexistente `tcp:8000 -> tcp:8000` foi conferido e preservado.
- Logs brutos da execução permanecem no ambiente local e são excluídos do Git. O resultado histórico está registrado nesta evidência e no relatório de execução.
