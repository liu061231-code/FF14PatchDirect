$ErrorActionPreference = "Continue"

$modulePath = Join-Path $PSScriptRoot "..\src\FF14PatchDirect.psm1"
Import-Module $modulePath -Force -DisableNameChecking

$config = Get-FF14PatchDirectConfig

if (-not (Test-FF14PatchDirectAdministrator)) {
    Write-Error "This script must run as Administrator."
    exit 100
}

while ($true) {
    try {
        Sync-FF14PatchDirect -Config $config | Out-Null
    } catch {
        Write-FF14PatchDirectLog -Config $config -Message "sync failed: $($_.Exception.Message)"
    }
    Start-Sleep -Seconds $config.SyncIntervalSeconds
}
