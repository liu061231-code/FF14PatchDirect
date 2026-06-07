$ErrorActionPreference = "Continue"

$modulePath = Join-Path $PSScriptRoot "..\src\FF14PatchDirect.psm1"
Import-Module $modulePath -Force -DisableNameChecking
$config = Get-FF14PatchDirectConfig

if (-not (Test-FF14PatchDirectAdministrator)) {
    Write-Error "This script must run as Administrator."
    exit 100
}

Stop-ScheduledTask -TaskName $config.TaskName -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName $config.TaskName -Confirm:$false -ErrorAction SilentlyContinue

try {
    Clear-FF14PatchDirectHostsBlock
} catch {
    Write-FF14PatchDirectLog -Config $config -Message "hosts cleanup failed: $($_.Exception.Message)"
}

try {
    Remove-FF14PatchDirectRoutes -Config $config
} catch {
    Write-FF14PatchDirectLog -Config $config -Message "route cleanup failed: $($_.Exception.Message)"
}

[pscustomobject]@{
    Success = $true
    TaskName = $config.TaskName
    StateDir = $config.StateDir
    Time = (Get-Date).ToString("s")
} | ConvertTo-Json -Depth 4
