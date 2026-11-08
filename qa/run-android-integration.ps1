param(
  [string]$DeviceId = "RX8NB0B7M5J"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$adbPath = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
$pythonPath = Join-Path $repoRoot "backend\.venv\Scripts\python.exe"
$serverPath = Join-Path $PSScriptRoot "playwright\qa_server.py"
$serverWorkDir = Join-Path $PSScriptRoot "playwright"
$qaPackage = "com.example.tripmate.qa"
$qaRoot = Join-Path $env:TEMP "tripmate-qa-runs"
$runId = "android-$([guid]::NewGuid().ToString('N'))"
$runDir = Join-Path $qaRoot "run-$runId"
$stopPath = Join-Path $runDir "STOP"
$evidenceDir = Join-Path $repoRoot "docs\qa\evidencias"
$logPath = Join-Path $evidenceDir "android-$runId.log"
$errorLogPath = Join-Path $evidenceDir "android-$runId-error.log"
$oldRunId = $env:TRIPMATE_QA_RUN_ID
$serverProcess = $null
$qaPackageWasAbsent = $false
$testExitCode = 1
$reverseConfigured = $false

if (!(Test-Path $adbPath)) { throw "ADB não encontrado: $adbPath" }
if (!(Test-Path $pythonPath)) { throw "Ambiente virtual Django não encontrado: $pythonPath" }

$deviceState = & $adbPath -s $DeviceId get-state
if ($LASTEXITCODE -ne 0 -or $deviceState.Trim() -ne "device") {
  throw "Dispositivo $DeviceId não está conectado e autorizado."
}

$installedQaPackage = & $adbPath -s $DeviceId shell pm list packages --user 0 $qaPackage
if ($installedQaPackage -match [regex]::Escape("package:$qaPackage")) {
  throw "A variante $qaPackage já está instalada; não reutilizarei estado existente."
}
$qaPackageWasAbsent = $true
$existingReverse = & $adbPath -s $DeviceId reverse --list
if ($existingReverse -match 'tcp:8765') {
  throw "ADB reverse tcp:8765 já está configurado; não substituirei o mapeamento existente."
}

New-Item -ItemType Directory -Force -Path $evidenceDir | Out-Null
$env:TRIPMATE_QA_RUN_ID = $runId

try {
  $serverProcess = Start-Process `
    -FilePath $pythonPath `
    -ArgumentList @("`"$serverPath`"") `
    -WorkingDirectory $serverWorkDir `
    -WindowStyle Hidden `
    -PassThru `
    -RedirectStandardOutput $logPath `
    -RedirectStandardError $errorLogPath

  $ready = $false
  for ($attempt = 0; $attempt -lt 120; $attempt++) {
    if ($serverProcess.HasExited) {
      throw "Servidor QA encerrou antes de ficar pronto. Consulte $logPath"
    }
    try {
      $null = Invoke-WebRequest -Uri "http://127.0.0.1:8765/admin/login/" -TimeoutSec 2
      $ready = $true
      break
    } catch {
      Start-Sleep -Milliseconds 500
    }
  }
  if (!$ready) { throw "Servidor QA não ficou pronto. Consulte $logPath" }

  & $adbPath -s $DeviceId reverse tcp:8765 tcp:8765
  if ($LASTEXITCODE -ne 0) { throw "Não foi possível configurar adb reverse." }
  $reverseConfigured = $true

  Push-Location $repoRoot
  try {
    & "D:\src\flutter\bin\flutter.bat" drive `
      --driver=test_driver\integration_test.dart `
      --target=integration_test\tripmate_smoke_test.dart `
      -d $DeviceId --flavor qa --dart-define=TRIPMATE_API_HOST=http://127.0.0.1:8765
    $testExitCode = $LASTEXITCODE
  } finally {
    Pop-Location
  }
} finally {
  if ($serverProcess -and !$serverProcess.HasExited) {
    if (Test-Path $runDir) {
      [System.IO.File]::WriteAllText($stopPath, "stop")
      try { $serverProcess.WaitForExit(10000) | Out-Null } catch {}
    }
    if (!$serverProcess.HasExited) {
      Stop-Process -Id $serverProcess.Id -Force
    }
  }
  if ($reverseConfigured) {
    & $adbPath -s $DeviceId reverse --remove tcp:8765 2>$null | Out-Null
  }
  if ($qaPackageWasAbsent) {
    $installedAfter = & $adbPath -s $DeviceId shell pm list packages --user 0 $qaPackage
    if ($installedAfter -match [regex]::Escape("package:$qaPackage")) {
      & $adbPath -s $DeviceId uninstall $qaPackage | Out-Null
    }
  }
  if ($null -eq $oldRunId) {
    Remove-Item Env:TRIPMATE_QA_RUN_ID -ErrorAction SilentlyContinue
  } else {
    $env:TRIPMATE_QA_RUN_ID = $oldRunId
  }
}

if ($testExitCode -ne 0) {
  throw "Testes de integração falharam com código $testExitCode. Evidência do servidor: $logPath"
}
Write-Output "Teste de integração QA aprovado em $DeviceId. Evidência: $logPath"
