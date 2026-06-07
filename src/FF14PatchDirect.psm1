$ErrorActionPreference = "Stop"

$script:BeginMarker = "# BEGIN FF14 PATCH DIRECT"
$script:EndMarker = "# END FF14 PATCH DIRECT"

function Get-FF14PatchDirectConfig {
    [CmdletBinding()]
    param()

    $domains = @{
        "patch-dl.ffxiv.com" = @(
            "23.216.55.9",
            "23.216.55.18",
            "23.206.188.206",
            "23.206.188.213",
            "23.56.109.133",
            "23.56.109.135",
            "23.56.109.143",
            "23.56.109.144"
        )
        "patch-gamever.ffxiv.com" = @("119.252.37.136")
        "patch-bootver.ffxiv.com" = @("23.62.54.10", "23.62.54.12")
        "frontier.ffxiv.com" = @("119.252.36.135")
        "config-dl.ffxiv.com" = @("119.252.37.167")
    }

    [pscustomobject]@{
        ProductName = "FF14PatchDirect"
        StateDir = "C:\ProgramData\FF14PatchDirect"
        TaskName = "FF14PatchDirect-Maintainer"
        Domains = $domains
        ExcludedInterfacePattern = "VPN|TUN|TAP|Wintun|WireGuard|OpenVPN|Clash|Mihomo|Loopback|Bluetooth"
        DnsTimeoutSeconds = 5
        SyncIntervalSeconds = 30
        LowThroughputMBps = 3
        LowThroughputSamples = 3
        RestartCooldownMinutes = 5
        LauncherPath = "C:\Program Files (x86)\SquareEnix\FINAL FANTASY XIV - A Realm Reborn\boot\ffxivboot64.exe"
    }
}

function Test-FF14PatchDirectAdministrator {
    [CmdletBinding()]
    param()

    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Rotate-FF14PatchDirectItems {
    [CmdletBinding()]
    param(
        [string[]]$Items,
        [int]$Offset = 0
    )

    $unique = @($Items | Where-Object { $_ } | Sort-Object -Unique)
    if ($unique.Count -le 1) {
        return $unique
    }

    $shift = $Offset % $unique.Count
    if ($shift -eq 0) {
        return $unique
    }
    return @($unique[$shift..($unique.Count - 1)] + $unique[0..($shift - 1)])
}

function Get-FF14PatchDirectHostsPath {
    [CmdletBinding()]
    param()

    Join-Path $env:SystemRoot "System32\drivers\etc\hosts"
}

function Update-FF14PatchDirectHostsContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Content,

        [Parameter(Mandatory)]
        [hashtable]$DomainIps
    )

    $pattern = "(?ms)^" + [regex]::Escape($script:BeginMarker) + ".*?^" + [regex]::Escape($script:EndMarker) + "\r?\n?"
    $cleanContent = [regex]::Replace($Content, $pattern, "").TrimEnd()

    $lines = @($script:BeginMarker)
    $lines += "# Managed by FF14PatchDirect. Routes Final Fantasy XIV patch traffic through the normal default gateway."
    foreach ($domain in ($DomainIps.Keys | Sort-Object)) {
        foreach ($ip in @($DomainIps[$domain] | Where-Object { $_ } | Sort-Object -Unique)) {
            $lines += "{0}`t{1}" -f $ip, $domain
        }
    }
    $lines += $script:EndMarker

    $prefix = ""
    if ($cleanContent) {
        $prefix = $cleanContent + [Environment]::NewLine + [Environment]::NewLine
    }

    return $prefix + ($lines -join [Environment]::NewLine) + [Environment]::NewLine
}

function Remove-FF14PatchDirectHostsContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Content
    )

    $pattern = "(?ms)^" + [regex]::Escape($script:BeginMarker) + ".*?^" + [regex]::Escape($script:EndMarker) + "\r?\n?"
    return [regex]::Replace($Content, $pattern, "").TrimEnd() + [Environment]::NewLine
}

function Write-FF14PatchDirectLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [object]$Config = (Get-FF14PatchDirectConfig)
    )

    New-Item -ItemType Directory -Path $Config.StateDir -Force | Out-Null
    $line = "{0} {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Add-Content -LiteralPath (Join-Path $Config.StateDir "maintainer.log") -Value $line -Encoding UTF8
}

function Get-FF14PatchDirectState {
    [CmdletBinding()]
    param(
        [object]$Config = (Get-FF14PatchDirectConfig)
    )

    $statePath = Join-Path $Config.StateDir "state.json"
    if (Test-Path -LiteralPath $statePath) {
        try {
            return Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
        } catch {
            Write-FF14PatchDirectLog -Config $Config -Message "state read failed: $($_.Exception.Message)"
        }
    }

    [pscustomobject]@{
        PatchDlOffset = 0
        LowCount = 0
        LastBytes = 0
        LastSample = ""
        LastRestart = ""
        LastIps = @()
    }
}

function Save-FF14PatchDirectState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$State,

        [object]$Config = (Get-FF14PatchDirectConfig)
    )

    New-Item -ItemType Directory -Path $Config.StateDir -Force | Out-Null
    $State | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $Config.StateDir "state.json") -Encoding UTF8
}

function Get-FF14PatchDirectDefaultRoute {
    [CmdletBinding()]
    param(
        [object]$Config = (Get-FF14PatchDirectConfig)
    )

    $routes = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue |
        Where-Object {
            $_.NextHop -and
            $_.NextHop -ne "0.0.0.0" -and
            $_.InterfaceAlias -notmatch $Config.ExcludedInterfacePattern
        } |
        Sort-Object RouteMetric, InterfaceMetric

    if ($routes) {
        return $routes[0]
    }

    return $null
}

function Resolve-FF14PatchDirectDomainIps {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [string[]]$FallbackIps = @(),

        [object]$Config = (Get-FF14PatchDirectConfig)
    )

    $ips = New-Object System.Collections.Generic.List[string]
    $queries = @(
        @{ Uri = "https://dns.alidns.com/resolve?name=$Name&type=A"; Headers = @{} },
        @{ Uri = "https://dns.google/resolve?name=$Name&type=A"; Headers = @{} },
        @{ Uri = "https://cloudflare-dns.com/dns-query?name=$Name&type=A"; Headers = @{ accept = "application/dns-json" } }
    )

    foreach ($query in $queries) {
        try {
            $response = Invoke-RestMethod -Uri $query.Uri -Headers $query.Headers -TimeoutSec $Config.DnsTimeoutSeconds
            foreach ($answer in @($response.Answer)) {
                if ($answer.type -eq 1 -and $answer.data -match "^\d{1,3}(\.\d{1,3}){3}$") {
                    $ips.Add([string]$answer.data)
                }
            }
        } catch {
            Write-FF14PatchDirectLog -Config $Config -Message "DNS query failed for $Name via $($query.Uri): $($_.Exception.Message)"
        }
    }

    foreach ($ip in @($FallbackIps)) {
        if ($ip) {
            $ips.Add([string]$ip)
        }
    }

    return @($ips | Sort-Object -Unique)
}

function Set-FF14PatchDirectHostsBlock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$DomainIps
    )

    $hostsPath = Get-FF14PatchDirectHostsPath
    $content = [System.IO.File]::ReadAllText($hostsPath)
    $updated = Update-FF14PatchDirectHostsContent -Content $content -DomainIps $DomainIps
    [System.IO.File]::WriteAllText($hostsPath, $updated, [System.Text.Encoding]::ASCII)
}

function Clear-FF14PatchDirectHostsBlock {
    [CmdletBinding()]
    param()

    $hostsPath = Get-FF14PatchDirectHostsPath
    $content = [System.IO.File]::ReadAllText($hostsPath)
    $updated = Remove-FF14PatchDirectHostsContent -Content $content
    [System.IO.File]::WriteAllText($hostsPath, $updated, [System.Text.Encoding]::ASCII)
}

function Ensure-FF14PatchDirectRoute {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$IP,

        [Parameter(Mandatory)]
        [int]$InterfaceIndex,

        [Parameter(Mandatory)]
        [string]$Gateway,

        [object]$Config = (Get-FF14PatchDirectConfig)
    )

    $existing = Get-NetRoute -DestinationPrefix "$IP/32" -InterfaceIndex $InterfaceIndex -NextHop $Gateway -ErrorAction SilentlyContinue
    if (-not $existing) {
        & route.exe -p delete $IP | Out-Null
        & route.exe -p add $IP mask 255.255.255.255 $Gateway metric 1 if $InterfaceIndex | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-FF14PatchDirectLog -Config $Config -Message "route add failed for $IP exit=$LASTEXITCODE"
        }
    }
}

function Remove-FF14PatchDirectRoutes {
    [CmdletBinding()]
    param(
        [object]$Config = (Get-FF14PatchDirectConfig)
    )

    $state = Get-FF14PatchDirectState -Config $Config
    foreach ($ip in @($state.LastIps)) {
        if ($ip -match "^\d{1,3}(\.\d{1,3}){3}$") {
            & route.exe -p delete $ip | Out-Null
        }
    }
}

function Restart-FF14PatchDirectLauncher {
    [CmdletBinding()]
    param(
        [object]$Config = (Get-FF14PatchDirectConfig)
    )

    Write-FF14PatchDirectLog -Config $Config -Message "restarting FF14 launcher"
    Get-Process ffxivlauncher64,ffxivupdater64 -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    if (Test-Path -LiteralPath $Config.LauncherPath) {
        Start-Process -FilePath $Config.LauncherPath
    }
}

function Update-FF14PatchDirectStallState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$State,

        [Parameter(Mandatory)]
        [object]$Route,

        [Parameter(Mandatory)]
        [string[]]$PatchIps,

        [object]$Config = (Get-FF14PatchDirectConfig)
    )

    $adapterStats = Get-NetAdapterStatistics -Name $Route.InterfaceAlias -ErrorAction SilentlyContinue
    if (-not $adapterStats) {
        return
    }

    $now = Get-Date
    $launcher = Get-Process ffxivlauncher64 -ErrorAction SilentlyContinue | Select-Object -First 1
    $hasPatchConnection = $false
    if ($launcher) {
        $connections = Get-NetTCPConnection -OwningProcess $launcher.Id -ErrorAction SilentlyContinue
        $hasPatchConnection = [bool]($connections | Where-Object { $_.RemotePort -eq 80 -and $PatchIps -contains $_.RemoteAddress })
    }

    if (-not $hasPatchConnection) {
        $State.LowCount = 0
        $State.LastBytes = [int64]$adapterStats.ReceivedBytes
        $State.LastSample = $now.ToString("o")
        Save-FF14PatchDirectState -State $State -Config $Config
        return
    }

    $lastSample = $null
    if ($State.LastSample) {
        try { $lastSample = [DateTime]::Parse($State.LastSample) } catch {}
    }

    if (-not $lastSample) {
        $State.LastBytes = [int64]$adapterStats.ReceivedBytes
        $State.LastSample = $now.ToString("o")
        Save-FF14PatchDirectState -State $State -Config $Config
        return
    }

    $elapsed = [Math]::Max(1, ($now - $lastSample).TotalSeconds)
    $delta = [int64]$adapterStats.ReceivedBytes - [int64]$State.LastBytes
    $mbps = ($delta / 1MB) / $elapsed

    if ($mbps -lt $Config.LowThroughputMBps) {
        $State.LowCount = [int]$State.LowCount + 1
        Write-FF14PatchDirectLog -Config $Config -Message ("low patch throughput sample {0}: {1:n2} MB/s" -f $State.LowCount, $mbps)
    } else {
        $State.LowCount = 0
    }

    $lastRestart = $null
    if ($State.LastRestart) {
        try { $lastRestart = [DateTime]::Parse($State.LastRestart) } catch {}
    }
    $canRestart = (-not $lastRestart) -or (($now - $lastRestart).TotalMinutes -ge $Config.RestartCooldownMinutes)

    if ([int]$State.LowCount -ge $Config.LowThroughputSamples -and $canRestart) {
        $State.PatchDlOffset = ([int]$State.PatchDlOffset + 1) % [Math]::Max(1, $PatchIps.Count)
        $State.LowCount = 0
        $State.LastRestart = $now.ToString("o")
        Save-FF14PatchDirectState -State $State -Config $Config
        Restart-FF14PatchDirectLauncher -Config $Config
        return
    }

    $State.LastBytes = [int64]$adapterStats.ReceivedBytes
    $State.LastSample = $now.ToString("o")
    Save-FF14PatchDirectState -State $State -Config $Config
}

function Sync-FF14PatchDirect {
    [CmdletBinding()]
    param(
        [switch]$RestartLauncher,
        [switch]$SkipStallMonitor,
        [object]$Config = (Get-FF14PatchDirectConfig)
    )

    if (-not (Test-FF14PatchDirectAdministrator)) {
        throw "This command must run as Administrator."
    }

    $route = Get-FF14PatchDirectDefaultRoute -Config $Config
    if (-not $route) {
        throw "No normal default route was found. Check network adapters or adjust ExcludedInterfacePattern."
    }

    $state = Get-FF14PatchDirectState -Config $Config
    $domainIps = @{}
    foreach ($domain in ($Config.Domains.Keys | Sort-Object)) {
        $domainIps[$domain] = @(Resolve-FF14PatchDirectDomainIps -Name $domain -FallbackIps $Config.Domains[$domain] -Config $Config)
    }
    $domainIps["patch-dl.ffxiv.com"] = @(Rotate-FF14PatchDirectItems -Items $domainIps["patch-dl.ffxiv.com"] -Offset ([int]$state.PatchDlOffset))

    Set-FF14PatchDirectHostsBlock -DomainIps $domainIps

    $allIps = @($domainIps.Values | ForEach-Object { $_ } | Sort-Object -Unique)
    foreach ($ip in $allIps) {
        Ensure-FF14PatchDirectRoute -IP $ip -InterfaceIndex $route.InterfaceIndex -Gateway $route.NextHop -Config $Config
    }

    $state.LastIps = @($allIps)
    Save-FF14PatchDirectState -State $state -Config $Config

    ipconfig /flushdns | Out-Null
    if (-not $SkipStallMonitor) {
        Update-FF14PatchDirectStallState -State $state -Route $route -PatchIps $domainIps["patch-dl.ffxiv.com"] -Config $Config
    }

    if ($RestartLauncher) {
        Restart-FF14PatchDirectLauncher -Config $Config
    }

    Write-FF14PatchDirectLog -Config $Config -Message ("synced domains={0} ips={1} gateway={2} if={3}" -f $domainIps.Count, $allIps.Count, $route.NextHop, $route.InterfaceIndex)
    [pscustomobject]@{
        Success = $true
        Domains = $domainIps.Count
        IPs = $allIps.Count
        Gateway = $route.NextHop
        InterfaceIndex = $route.InterfaceIndex
        InterfaceAlias = $route.InterfaceAlias
        Time = (Get-Date).ToString("s")
    }
}

Export-ModuleMember -Function @(
    "Get-FF14PatchDirectConfig",
    "Test-FF14PatchDirectAdministrator",
    "Rotate-FF14PatchDirectItems",
    "Update-FF14PatchDirectHostsContent",
    "Remove-FF14PatchDirectHostsContent",
    "Get-FF14PatchDirectHostsPath",
    "Write-FF14PatchDirectLog",
    "Get-FF14PatchDirectState",
    "Save-FF14PatchDirectState",
    "Get-FF14PatchDirectDefaultRoute",
    "Resolve-FF14PatchDirectDomainIps",
    "Set-FF14PatchDirectHostsBlock",
    "Clear-FF14PatchDirectHostsBlock",
    "Ensure-FF14PatchDirectRoute",
    "Remove-FF14PatchDirectRoutes",
    "Restart-FF14PatchDirectLauncher",
    "Update-FF14PatchDirectStallState",
    "Sync-FF14PatchDirect"
)
