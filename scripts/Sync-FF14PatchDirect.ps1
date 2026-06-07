$ErrorActionPreference = "Stop"

param(
    [switch]$RestartLauncher,
    [switch]$SkipStallMonitor
)

$modulePath = Join-Path $PSScriptRoot "..\src\FF14PatchDirect.psm1"
Import-Module $modulePath -Force -DisableNameChecking

$result = Sync-FF14PatchDirect -RestartLauncher:$RestartLauncher -SkipStallMonitor:$SkipStallMonitor
$result | ConvertTo-Json -Depth 5
