$ErrorActionPreference = "Stop"

$modulePath = Join-Path $PSScriptRoot "..\src\FF14PatchDirect.psm1"
Import-Module $modulePath -Force -DisableNameChecking
$config = Get-FF14PatchDirectConfig

if (-not (Test-FF14PatchDirectAdministrator)) {
    Write-Error "This script must run as Administrator."
    exit 100
}

$installRoot = $config.StateDir
$installSrc = Join-Path $installRoot "src"
$installScripts = Join-Path $installRoot "scripts"
New-Item -ItemType Directory -Path $installSrc,$installScripts -Force | Out-Null

Copy-Item -LiteralPath (Join-Path $PSScriptRoot "..\src\FF14PatchDirect.psm1") -Destination (Join-Path $installSrc "FF14PatchDirect.psm1") -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "Watch-FF14PatchDirect.ps1") -Destination (Join-Path $installScripts "Watch-FF14PatchDirect.ps1") -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "Sync-FF14PatchDirect.ps1") -Destination (Join-Path $installScripts "Sync-FF14PatchDirect.ps1") -Force

$target = Join-Path $installScripts "Watch-FF14PatchDirect.ps1"
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$target`""
$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest -LogonType Interactive
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

Register-ScheduledTask -TaskName $config.TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName $config.TaskName

[pscustomobject]@{
    Success = $true
    TaskName = $config.TaskName
    InstallRoot = $installRoot
    Log = (Join-Path $installRoot "maintainer.log")
    Time = (Get-Date).ToString("s")
} | ConvertTo-Json -Depth 4
