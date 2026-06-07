# FF14PatchDirect

一个专门给《最终幻想 XIV》国际服补丁下载用的 Windows 小工具。

它的目标很朴素：当 FF14 国际服启动器下载补丁很慢、卡住，或者被 VPN、TUN/TAP、fake-IP、游戏加速器之类的虚拟网卡绕进去时，尽量把官方国际服补丁流量拉回到你电脑当前的正常网络出口。

它不是代理，也不是魔法加速器，更不会修改游戏文件。它做的事情只有两类：

- 把 FF14 官方补丁域名解析到可用的公开 CDN 地址。
- 给这些 CDN IP 添加单独路由，让补丁流量走正常默认网关。

如果你的网络本身正常，它可以作为一个“少折腾一点”的国际服补丁下载修复工具；如果问题来自运营商、Square Enix 服务器、地区限制、账号状态或防火墙策略，它就不一定能帮上忙。

[English README](README.en.md)

## 搜索关键词

如果你是从搜索引擎或 GitHub 找来的，可以用这些关键词判断是不是同一个问题：

- FF14 国际服下载慢
- FF14 国际服补丁下载卡住
- FFXIV patch download slow
- FFXIV launcher stuck
- FFXIV Global client patch
- `patch-dl.ffxiv.com`
- `patch-gamever.ffxiv.com`
- Clash / Mihomo / fake-IP / TUN / TAP / VPN 导致游戏下载慢
- Windows hosts 路由修复 FF14 下载

## 它能做什么

- 通过多个公开 DNS-over-HTTPS 服务解析 FF14 国际服补丁域名。
- 自动维护 Windows `hosts` 文件中的专属托管块。
- 为解析到的 CDN IP 添加持久 `/32` 路由。
- 安装后每 30 秒刷新一次补丁域名和路由。
- 如果补丁下载持续低速，会尝试轮换 `patch-dl.ffxiv.com` 的 CDN 地址。
- 提供卸载脚本，清理计划任务、托管 hosts 块和已记录的路由。

## 什么时候适合用

比较适合这些情况：

- FF14 国际服启动器下载补丁速度很慢。
- 下载进度长时间不动，重启启动器偶尔又能继续。
- 电脑上开过 VPN、Clash、Mihomo、WireGuard、OpenVPN、游戏加速器或 fake-IP DNS 模式。
- 你希望 FF14 国际服补丁流量尽量走家里或办公室的正常网络，而不是被虚拟网卡接管。

不太适合这些情况：

- 你的网络必须全程走 VPN 才能上网。
- 你遇到的是账号、区服、官方维护或登录限制。
- 你使用的是非国际服客户端，补丁域名和 CDN 规则可能完全不同。
- 你希望它提升所有网站、所有游戏、所有下载的速度。

## 使用前请看一眼

这个工具需要管理员权限，因为它会修改：

- Windows hosts 文件
- Windows 持久路由表
- Windows 计划任务

脚本只会管理自己标记的内容。hosts 文件里由本工具写入的部分会被包在下面两行之间：

```text
# BEGIN FF14 PATCH DIRECT
# END FF14 PATCH DIRECT
```

卸载脚本只会删除这段托管内容，不会清空你的整个 hosts 文件。

## 系统要求

- Windows 10 或 Windows 11
- PowerShell 5.1 或更高版本
- 管理员权限
- 一个可用的正常默认网关
- FF14 国际服官方启动器

## 快速开始

下载 Release 里的压缩包并解压。

在解压后的目录里，右键用管理员身份打开 PowerShell，然后运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Sync-FF14PatchDirect.ps1 -RestartLauncher -SkipStallMonitor
```

这会执行一次同步，并尝试重启 FF14 启动器。

## 安装后台维护

如果你希望它之后自动刷新域名和路由，运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-FF14PatchDirect.ps1
```

安装后会创建一个 Windows 计划任务：

```text
FF14PatchDirect-Maintainer
```

它会在你登录 Windows 后自动启动，并在后台维护补丁域名和路由。

## 卸载和清理

不想用了，运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Uninstall-FF14PatchDirect.ps1
```

它会尝试清理：

- `FF14PatchDirect-Maintainer` 计划任务
- hosts 文件里的 `FF14 PATCH DIRECT` 托管块
- 工具记录过的持久路由

运行日志和状态文件默认在：

```text
C:\ProgramData\FF14PatchDirect
```

## 兼容旧脚本名

早期本地修复版本使用过这些脚本名，现在它们仍然保留为兼容入口：

- `Apply-FF14Bypass.ps1`
- `FF14BypassMaintainer.ps1`
- `Install-FF14BypassMaintainer.ps1`

新用户建议直接使用 `scripts` 目录里的 `FF14PatchDirect` 脚本。

## 它大概是怎么工作的

FF14PatchDirect 会先找出当前 Windows 里最像“正常网络出口”的默认路由，同时避开常见虚拟网卡名称，例如：

```text
VPN, TUN, TAP, Wintun, WireGuard, OpenVPN, Clash, Mihomo, Loopback, Bluetooth
```

然后它会解析 FF14 官方补丁域名，把结果写入 hosts 托管块，并给这些 IP 添加单独的持久路由。这样启动器访问补丁 CDN 时，更有机会直接走正常网关。

如果你的虚拟网卡名称比较特殊，可以在 `src\FF14PatchDirect.psm1` 里调整：

```powershell
ExcludedInterfacePattern
```

## 自检

开发或改脚本后，可以运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\FF14PatchDirect.Tests.ps1
```

目前自检覆盖：

- CDN 地址轮换
- hosts 托管块生成
- hosts 托管块移除
- 默认配置路径和域名

## 支持这个项目

如果这个工具帮你省下了一点等待补丁下载的时间，那就已经很好了。

如果你愿意请作者喝杯咖啡、继续维护这个小工具，可以通过 GitHub Sponsors 支持：

[https://github.com/sponsors/liu061231-code](https://github.com/sponsors/liu061231-code)

面向国际用户，也可以使用 PayPal 扫码：

<img src="assets/donation-paypal.jpg" alt="PayPal 收款码" width="360">

国内用户可以使用支付宝扫一扫：

<img src="assets/donation-alipay.jpg" alt="支付宝收款码" width="360">

如果暂时不方便赞助，也完全没关系。点一个 Star、提一个 Issue、告诉我哪个网络环境下有效或无效，都同样有帮助。这个项目本来就是从一次真实的 FF14 下载卡顿里长出来的，能帮到更多人就是它最好的去处。

## 免责声明

这个项目与 Square Enix、Final Fantasy XIV 官方没有任何关系。

请在理解脚本行为后再用管理员权限运行它。网络环境千差万别，本工具只负责尽量让 FF14 国际服补丁流量走正常默认网关，不保证在所有地区、所有运营商、所有代理或加速器配置下都有效。
