# FF14PatchDirect

FF14PatchDirect is a Windows PowerShell tool for improving Final Fantasy XIV Global / International client patch download reliability on normal home or office networks.

It does not run a proxy, tunnel, or packet accelerator. Instead, it keeps official FFXIV Global / International patch domains resolved to public CDN addresses and adds host routes so patch traffic uses the normal default gateway instead of being captured by VPN, TUN, TAP, fake-IP, or similar virtual adapters.

## Search keywords

If you found this from a search engine or GitHub, these are the problems this project is meant to match:

- FFXIV patch download slow
- FFXIV launcher stuck
- FFXIV Global client patch download
- FF14 international launcher download slow
- `patch-dl.ffxiv.com`
- `patch-gamever.ffxiv.com`
- Clash / Mihomo / fake-IP / TUN / TAP / VPN routing issues
- Windows hosts route fix for FFXIV patch downloads

## What it does

- Resolves FFXIV Global / International patch and launcher domains through multiple public DNS-over-HTTPS providers.
- Maintains a clearly marked block in the Windows `hosts` file.
- Adds persistent `/32` routes for the resolved CDN IP addresses through the normal default route.
- Refreshes the mappings every 30 seconds when installed as a scheduled task.
- Rotates `patch-dl.ffxiv.com` CDN addresses if patch throughput stays low.
- Provides an uninstall script that removes the scheduled task, managed hosts block, and known managed routes.

## When this helps

This is useful when the FFXIV Global / International launcher is slow or stuck because patch traffic is being routed through a VPN, game booster, fake-IP DNS mode, TUN/TAP adapter, or other virtual network path.

It can also help on ordinary networks where one CDN edge is slow, because the maintainer periodically refreshes DNS answers and can rotate patch CDN addresses.

This is not a general internet speed booster and does not bypass Square Enix, regional, account, firewall, ISP, or server-side restrictions. It is aimed at the Global / International client; other regional clients may use different patch domains and CDN behavior.

## Requirements

- Windows 10 or Windows 11
- PowerShell 5.1 or later
- Administrator privileges
- A working normal default gateway
- Final Fantasy XIV Global / International official launcher

## Quick start

Open PowerShell as Administrator in this folder.

Run once and restart the launcher:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Sync-FF14PatchDirect.ps1 -RestartLauncher -SkipStallMonitor
```

Install the background maintainer:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-FF14PatchDirect.ps1
```

Uninstall and clean up:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Uninstall-FF14PatchDirect.ps1
```

## Compatibility wrappers

The older local script names are kept as wrappers:

- `Apply-FF14Bypass.ps1`
- `FF14BypassMaintainer.ps1`
- `Install-FF14BypassMaintainer.ps1`

New users should prefer the `scripts\*FF14PatchDirect.ps1` entry points.

## Logs and state

Runtime files are stored under:

```text
C:\ProgramData\FF14PatchDirect
```

The maintainer log is:

```text
C:\ProgramData\FF14PatchDirect\maintainer.log
```

## How it works

The tool chooses the lowest-metric normal default route while excluding common virtual adapter names such as VPN, TUN, TAP, Wintun, WireGuard, OpenVPN, Clash, Mihomo, Loopback, and Bluetooth. It then writes official FFXIV patch domain mappings to a managed hosts block and adds persistent host routes for the resolved CDN IPs through that gateway.

All generated hosts entries are surrounded by:

```text
# BEGIN FF14 PATCH DIRECT
# END FF14 PATCH DIRECT
```

The uninstall script removes only this managed block.

## Testing

Run the self-tests:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\FF14PatchDirect.Tests.ps1
```

The tests cover CDN list rotation, hosts block generation/removal, and the default publish-safe configuration.

## Support

If this project saves you some waiting time, that is already a win.

If you would like to support maintenance, you can use GitHub Sponsors:

[https://github.com/sponsors/liu061231-code](https://github.com/sponsors/liu061231-code)

For international users, PayPal is also available:

<img src="assets/donation-paypal.jpg" alt="PayPal donation QR code" width="360">

Alipay is available for users in China:

<img src="assets/donation-alipay.jpg" alt="Alipay donation QR code" width="360">

Stars, issues, and real-world reports are also genuinely useful. This project came from a real FFXIV patch download problem, and feedback is what makes it safer for more network setups.

## Safety notes

- Read the scripts before running them with Administrator privileges.
- The tool changes the Windows hosts file and persistent routes.
- If your network uses a legitimate VPN as the only internet path, this tool may not help.
- If a virtual adapter should not be excluded, edit `ExcludedInterfacePattern` in `src\FF14PatchDirect.psm1`.

## Project summary

This project started as a local FFXIV repair script. The original implementation hardcoded one gateway and one interface index for one machine. The current version generalizes the design by detecting the normal default route, dynamically resolving official patch domains, storing state under a neutral product path, adding install/uninstall commands, and documenting the exact network behavior for public use.
