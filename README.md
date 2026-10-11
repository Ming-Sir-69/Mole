<div align="center">
  <h1>Mole for Windows</h1>
  <p><b>Deep clean, uninstall apps, optimize, analyze disk, and monitor your Windows PC. Free open-source CLI.</b></p>
  <a href="https://github.com/tw93/mole/stargazers"><img src="https://img.shields.io/github/stars/tw93/mole?style=flat-square" alt="Stars"></a>
  <a href="https://github.com/tw93/Mole/releases"><img src="https://img.shields.io/github/v/release/tw93/mole?filter=*-windows&include_prereleases&label=version&style=flat-square" alt="Version"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL_v3-blue.svg?style=flat-square" alt="License"></a>
  <a href="https://github.com/tw93/mole/commits/windows"><img src="https://img.shields.io/github/commit-activity/m/tw93/mole/windows?style=flat-square" alt="Commits"></a>
  <a href="https://twitter.com/HiTw93"><img src="https://img.shields.io/badge/follow-Tw93-red?style=flat-square&logo=Twitter" alt="Twitter"></a>
  <a href="https://t.me/+9f9gf4ZrFSQ2OWVl"><img src="https://img.shields.io/badge/chat-Telegram-blueviolet?style=flat-square&logo=Telegram" alt="Telegram"></a>
</div>

> 💡 This branch is the free open-source Windows CLI (`mo`). Prefer a native app? [Mole for Windows](https://mole.fit/windows) is a separate download with review-before-delete cleanup, app updates, startup management, disk drill-downs, and live status. The macOS CLI lives on the [main branch](https://github.com/tw93/Mole).

## Features

- **All-in-one CLI toolkit**: Combines CCleaner, IObit Uninstaller, WinDirStat, and Task Manager style workflows in one terminal command
- **Deep clean**: Removes temp files, caches, logs, and browser leftovers to reclaim disk space
- **Smart uninstaller**: Removes apps together with their leftover install folders
- **Disk analyzer**: Explores disk usage with an interactive TUI and finds large files
- **System maintenance**: Flushes DNS, rebuilds icon and font caches, and checks disk health
- **Live monitoring**: Shows real-time CPU, memory, disk, network, and process stats

## Quick Start

Mole runs on Windows 10 and 11 with the built-in Windows PowerShell 5.1. Git is needed for the script install and `mo update`. The script installs into `%LOCALAPPDATA%\Programs\mole-cli` and adds `mo` and `mole` to your PATH.

**Install via script**

```powershell
iwr -useb https://raw.githubusercontent.com/tw93/Mole/windows/quick-install.ps1 | iex
```

**Run**

```powershell
mo                           # Interactive menu
mo clean                     # Deep cleanup
mo uninstall                 # Remove installed apps + their leftovers
mo optimize                  # Refresh caches & services
mo analyze                   # Visual disk explorer
mo status                    # Live system health dashboard
mo purge                     # Clean project build artifacts

mo update                    # Update Mole
mo remove                    # Remove Mole from this PC
mo --help                    # Show help
mo --version                 # Show installed version
```

**Preview safely**

```powershell
mo clean --dry-run
mo uninstall --dry-run
mo optimize --dry-run
mo purge --dry-run

mo clean --dry-run --debug   # Preview + detailed logs
mo clean --whitelist         # Manage protected paths
mo clean --system            # Include system-level cleanup (run as administrator)
mo purge --paths             # Configure project scan directories
mo analyze D:\               # Analyze another drive
```

<details>
<summary><strong>Other install options</strong></summary>

To review the code before installing, clone the `windows` branch and run the installer in place. It keeps `.git`, so `mo update` works later:

```powershell
$installDir = "$env:LOCALAPPDATA\Programs\mole-cli"
git clone --branch windows https://github.com/tw93/Mole.git $installDir
powershell -ExecutionPolicy Bypass -File "$installDir\install.ps1" -InstallDir $installDir -AddToPath
```

Add `-CreateShortcut` for a Start Menu entry. To uninstall, run `mo remove`.

</details>

## Safety

Mole can delete files, so it validates paths and protects system and profile locations. `uninstall`, `purge`, and `remove` ask for confirmation before removing anything. When Mole cannot prove an item is safe to change, it skips it.

- `clean`, `uninstall`, `purge`, and `remove` can delete files, so review them with `--dry-run` first and add `--debug` when needed
- Deletions are permanent; Mole does not move files to the Recycle Bin
- Run Mole as your normal user; system-level steps are skipped unless PowerShell runs as administrator
- Protect paths with `mo clean --whitelist`
- `C:\Windows`, `C:\Program Files`, Windows Defender folders, and your profile root are never touched

Review [SECURITY.md](SECURITY.md) for reporting guidance and safety boundaries.

## Features in Detail

The examples below are shortened. Available items and sizes depend on your PC.

### Clean

```powershell
mo clean --dry-run
```

```
Clean Your Windows

Dry Run Mode - Preview only, no deletions

⚙ Microsoft Windows 11 Pro | Free space: 100.34GB

➤ User essentials
  → User temp files (>7d old) (109 items, 529.3MB dry)
  → Thumbnail cache (15 items, 11.1MB dry)
  → Memory dumps (10 items, 72.0MB dry)

➤ Browser caches
  → Edge Cache (2 items, 95.0MB dry)
  → Edge Code Cache (2 items, 26.5MB dry)

➤ Developer tools
  → NuGet HTTP cache (1 items, 596.1MB dry)

Dry run complete - no changes made

  Potential space: 1.32GB
  Items found: 176
  Categories: 15

  Detailed list: C:\Users\you\.config\mole\clean-list.txt
  Run without --dry-run to apply cleanup
```

The detailed list holds every path the preview found. Copy any of them into the whitelist to keep it.

### Uninstall

```powershell
mo uninstall
```

Lists installed programs from the registry and Windows Apps with their size and last use, then removes the ones you pick with their own uninstaller and cleans the leftover install folder. `mo uninstall --dry-run` shows which uninstaller each app would use and what would be removed, without running anything.

### Optimize

```powershell
mo optimize --dry-run
```

```
Optimize and Maintain

 DRY RUN MODE - No changes will be made

⚙ System  6.2/12GB RAM | 154/254GB Disk | Uptime 4.1d

➤ DNS Cache
  → Would flush DNS cache

➤ Disk Health
  ✓ harddisk SSD - Healthy

➤ Icon Cache Rebuild
  → Would stop Explorer
  → Would delete icon cache files (iconcache_*.db)
  → Would restart Explorer

Dry Run Complete - No Changes Made

  Would apply 3 optimizations
  Run without --dry-run to apply changes
```

Steps such as disk optimization, network settings, and the Windows Search index need administrator access and are skipped otherwise; run PowerShell as administrator to include them.

### Analyze

```powershell
mo analyze
mo analyze D:\
```

An interactive disk explorer: arrow keys move through folders, a large-file view lists files over 100 MB, and deleting from it asks for confirmation first.

### Status

```powershell
mo status
```

A live dashboard with a health score, CPU, memory, disk, network, and the busiest processes.

### Purge

```powershell
mo purge --dry-run
```

Finds build artifacts (`node_modules`, `target`, `build`, `dist`, `venv`, and more) in your project folders and lets you pick which projects to clean; nothing is selected until you choose. Configure the scanned folders with `mo purge --paths`.

## Community

Thanks to everyone who helped build Mole. Go follow them. ❤️

<a href="https://github.com/tw93/Mole/graphs/contributors">
  <img src="./CONTRIBUTORS.svg?v=2" alt="Mole contributors" width="1000" />
</a>

## Support

- If Mole helped you, give it a star, [share it](https://twitter.com/intent/tweet?url=https://github.com/tw93/Mole/tree/windows&text=Mole%20-%20Deep%20clean%20and%20optimize%20your%20Windows%20PC.), or open an issue or PR
- Contributions are welcome; read [CONTRIBUTING.md](CONTRIBUTING.md) first
- I have two cats, TangYuan and Coke, and if Mole makes your life a little easier, feel free to treat them to <a href="https://cats.tw93.fun?name=Mole" target="_blank">canned food 🥩</a>

## License

Mole is open source under GPL-3.0; see [LICENSE](LICENSE). Any modified version you share must remain under the same license. If you fork Mole, please use a distinct name and credit Mole as the upstream source; see [TRADEMARK.md](TRADEMARK.md).
