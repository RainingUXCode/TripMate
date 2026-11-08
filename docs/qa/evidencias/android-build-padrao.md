# Evidência de build Android padrão — 07/11/2026

Janela local aproximada: **23:11:18–23:13:56 (America/Sao_Paulo)**.

- Comando: `flutter build apk --debug --no-pub` (o flavor `dev` era o padrão).
- Gradle executou `assembleDevDebug` sem precisar de `--flavor`.
- Resultado: `√ Built build\app\outputs\flutter-apk\app-dev-debug.apk` (158,1 s).
- O APK foi apenas compilado; não foi instalado nem executado por esse comando.
