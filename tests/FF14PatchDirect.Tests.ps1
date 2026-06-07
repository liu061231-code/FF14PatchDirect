$ErrorActionPreference = "Stop"

$modulePath = Join-Path $PSScriptRoot "..\src\FF14PatchDirect.psm1"
Import-Module $modulePath -Force -DisableNameChecking

function Assert-Equal {
    param(
        [object]$Actual,
        [object]$Expected,
        [string]$Message
    )
    if ($Actual -ne $Expected) {
        throw "$Message Expected '$Expected', got '$Actual'."
    }
}

function Assert-MatchText {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$Message
    )
    if ($Text -notmatch $Pattern) {
        throw "$Message Pattern '$Pattern' was not found."
    }
}

$rotated = Rotate-FF14PatchDirectItems -Items @("a", "b", "c") -Offset 1
Assert-Equal ($rotated -join ",") "b,c,a" "Items should rotate from the requested offset."

$deduped = Rotate-FF14PatchDirectItems -Items @("b", "a", "b", "") -Offset 0
Assert-Equal ($deduped -join ",") "a,b" "Items should be stable and unique before rotation."

$hosts = @"
127.0.0.1 localhost

# BEGIN FF14 PATCH DIRECT
1.1.1.1 patch-dl.ffxiv.com
# END FF14 PATCH DIRECT
"@

$domainIps = @{
    "patch-dl.ffxiv.com" = @("23.216.55.18", "23.216.55.9")
    "config-dl.ffxiv.com" = @("119.252.37.167")
}
$updated = Update-FF14PatchDirectHostsContent -Content $hosts -DomainIps $domainIps
Assert-MatchText $updated "127\.0\.0\.1 localhost" "Existing hosts content should be preserved."
Assert-MatchText $updated "# BEGIN FF14 PATCH DIRECT" "Managed block should be added."
Assert-MatchText $updated "23\.216\.55\.9\s+patch-dl\.ffxiv\.com" "Patch host mapping should be present."
Assert-MatchText $updated "119\.252\.37\.167\s+config-dl\.ffxiv\.com" "Config host mapping should be present."
if (($updated | Select-String "# BEGIN FF14 PATCH DIRECT" -AllMatches).Matches.Count -ne 1) {
    throw "Managed hosts block should appear exactly once."
}

$removed = Remove-FF14PatchDirectHostsContent -Content $updated
if ($removed -match "FF14 PATCH DIRECT") {
    throw "Managed hosts block should be removable."
}
Assert-MatchText $removed "127\.0\.0\.1 localhost" "Removing the managed block should preserve user hosts entries."

$config = Get-FF14PatchDirectConfig
Assert-Equal ([bool]$config.Domains["patch-dl.ffxiv.com"]) $true "Default config should include patch-dl.ffxiv.com."
Assert-Equal $config.StateDir "C:\ProgramData\FF14PatchDirect" "Default state directory should be product-neutral."

Write-Host "All FF14PatchDirect self-tests passed."
