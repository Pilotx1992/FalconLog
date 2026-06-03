# KB2003 on-device auto backup QA runner (debug build).
# Wireless ADB: uses debug simulate-Wi-Fi flag (physical Wi-Fi off drops adb).
# USB ADB: set -UsePhysicalWifiToggle to disable/enable device Wi-Fi.

param(
    [string]$DeviceId = "adb-2c99fd39-RaTUj6._adb-tls-connect._tcp",
    [switch]$UsePhysicalWifiToggle
)

$ErrorActionPreference = "Stop"
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$projectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$logFile = Join-Path $projectRoot "falconlog_auto_backup_kb2003_qa.log"

Set-Location $projectRoot

Write-Host "=== KB2003 Auto Backup QA ===" -ForegroundColor Cyan
Write-Host "Device: $DeviceId"
Write-Host "Log file: $logFile"

& $adb -s $DeviceId shell getprop ro.product.model
& $adb -s $DeviceId logcat -c

$logcatJob = Start-Job -ScriptBlock {
    param($adbPath, $device, $outFile)
    & $adbPath -s $device logcat -v time 2>&1 |
        Select-String -Pattern "AutoBackupQA|AutoBackupReconciler|AutoBackupWorker|AutoBackupStateStore|BackupService|WorkManager|KB2003_QA" |
        ForEach-Object { $_.Line } |
        Tee-Object -FilePath $outFile
} -ArgumentList $adb, $DeviceId, $logFile

function Set-DeviceWifi([bool]$Enabled) {
    $state = if ($Enabled) { "enable" } else { "disable" }
    Write-Host "Wi-Fi $state..." -ForegroundColor Yellow
    & $adb -s $DeviceId shell svc wifi $state | Out-Null
    Start-Sleep -Seconds 2
}

$wifiDisabled = $false
$wifiEnabled = $false
$testExit = 1

try {
    $flutter = (Get-Command flutter -ErrorAction Stop).Source
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $flutter
    $psi.Arguments = "test integration_test/kb2003_auto_backup_qa_test.dart -d $DeviceId --reporter expanded"
    $psi.WorkingDirectory = $projectRoot
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    [void]$proc.Start()

    while (-not $proc.HasExited) {
        $line = $proc.StandardOutput.ReadLine()
        if ($null -eq $line) {
            Start-Sleep -Milliseconds 200
            continue
        }
        Write-Host $line

        if ($UsePhysicalWifiToggle -and $line -match "KB2003_QA_SIGNAL:DISABLE_WIFI_NOW" -and -not $wifiDisabled) {
            Set-DeviceWifi $false
            $wifiDisabled = $true
        }
        if ($UsePhysicalWifiToggle -and $line -match "KB2003_QA_SIGNAL:ENABLE_WIFI_NOW" -and -not $wifiEnabled) {
            Set-DeviceWifi $true
            $wifiEnabled = $true
        }
        if ($line -match "KB2003_QA_SIGNAL:SIMULATE_WIFI_OFF") {
            Write-Host "Using debug simulate-Wi-Fi (wireless ADB safe)" -ForegroundColor DarkCyan
        }
        if ($line -match "KB2003_QA_SIGNAL:PASS") {
            Write-Host "QA protocol completed successfully." -ForegroundColor Green
        }
    }

    while (-not $proc.StandardOutput.EndOfStream) {
        $tail = $proc.StandardOutput.ReadLine()
        if ($tail) { Write-Host $tail }
    }
    $stderr = $proc.StandardError.ReadToEnd()
    if ($stderr) { Write-Host $stderr -ForegroundColor DarkYellow }

    $testExit = $proc.ExitCode
}
finally {
    if (-not $wifiEnabled) {
        Set-DeviceWifi $true
    }
    Stop-Job $logcatJob -ErrorAction SilentlyContinue
    Remove-Job $logcatJob -Force -ErrorAction SilentlyContinue
    & $adb -s $DeviceId logcat -d 2>&1 |
        Select-String -Pattern "AutoBackupQA|AutoBackupReconciler|AutoBackupWorker|AutoBackupStateStore|BackupService|WorkManager|KB2003_QA" |
        ForEach-Object { $_.Line } |
        Out-File -FilePath $logFile -Encoding utf8
}

Write-Host ""
Write-Host "Saved filtered log: $logFile"
if ($testExit -eq 0) {
    Write-Host "RESULT: GREEN" -ForegroundColor Green
} else {
    Write-Host "RESULT: FAILED (exit $testExit)" -ForegroundColor Red
}
exit $testExit
