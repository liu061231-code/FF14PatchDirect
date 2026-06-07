$ErrorActionPreference = "Stop"

& (Join-Path $PSScriptRoot "scripts\Sync-FF14PatchDirect.ps1") -RestartLauncher -SkipStallMonitor
