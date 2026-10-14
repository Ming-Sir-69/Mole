# Product synchronization

This is the synchronization entry point for **Mole CLI (Windows)**, branch `windows` of `tw93/Mole`. Workflow and the four canonical product names are in [AGENTS.md](AGENTS.md#product-synchronization). Source review baseline: `2e1566af`, 2026-10-14, Asia/Singapore. This is a source/record review, not a new full runtime audit or a release.

## Ownership

- The two CLIs: the [Windows branch SYNC.md](https://github.com/tw93/Mole/blob/windows/SYNC.md) owns the shared CLI adaptation queue; the macOS entry links to it rather than duplicating rows.
- Mole CLI (macOS) with Mole Mac: the app's root `SYNC.md` owns the detailed comparison.
- Mole CLI (Windows) with Mole for Windows, and the two apps: Mole for Windows' root `SYNC.md` owns the detailed comparison.
- App-owned records remain private. Public CLI records contain public behavior, source and tests only; never copy private catalogs, implementation details, support data or repository links here.

## CLI adaptation queue

| ID | Topic | Status | Source, destination and next check |
| --- | --- | --- | --- |
| CLI-SYNC-01 | Offline music preservation | Implemented | `0b78b46b`, `lib/clean/caches.ps1`, preserves Spotify Data and Storage during automatic cleanup. Public preservation principle from Mole CLI (macOS) `b364d17d`; Windows fixtures retain both stores and exercise a neighboring eligible cache. |
| CLI-SYNC-02 | Unknown protection state | Implemented | `0b78b46b`, `lib/core/base.ps1:Test-Whitelisted`: only missing files are empty; metadata/content failures retain targets. Literal bracket filenames and the real `Remove-SafeItem` consumer have regressions. |
| CLI-SYNC-03 | Registered uninstall compatibility | Implemented | `3a7f8b7b`, `bin/uninstall.ps1:Get-UninstallLaunch`: the exact Proton Pass 1.37.0 / Proton AG / Update.exe case uses its registered normal command. Seven neighboring registrations keep their quiet command. No real app uninstall was performed in this pass. |
| CLI-SYNC-04 | Cleanup ownership, dry-run and stale scans | Implemented | `01a2e0b5`, `b8b27771`, `2ec4f9b1`, `5a986a96`; Windows-specific identity, authored-content, shared-owner and scan-request checks. Existing tests and delivery receipts are in the development record. Path rechecks are not atomic handles. |
| CLI-SYNC-05 | Terminal lists and completion | Implemented | `68d26ec9`; display-cell width, readable Store sizes, terminal-only completion transition and blank unknown Analyze percentages. ThinkPad receipt `7d1051af`; narrow native console acceptance still pending. |
| CLI-SYNC-06 | Uninstall configuration references | Pending | Mole CLI (macOS) `eb21fff1`; identify existing Windows consumers and exact non-secret configuration files before adapting. Never broaden automatic deletion or print file contents. |
| CLI-SYNC-07 | Process CPU denominator | Intentional difference | Both CLIs use one logical CPU as 100%; Windows `cmd/status/metrics.go:processInfoFromSamples` preserves that contract. Mole for Windows uses a whole-machine denominator. |
| CLI-SYNC-08 | GUI-only bulk app updates and lifetime totals | Not applicable | This CLI has self-update, not the app's bulk updater or lifetime-statistics store. Do not create either merely to port an app fix. |
| CLI-SYNC-09 | Generated media and recordings | Pending | Mole CLI (macOS) `b364d17d` stopped treating rendered and exported media as cache. Windows `lib/clean/apps.ps1:Clear-GameMediaFiles` (opt-in `-GameMedia`) still removes recordings older than 90 days from ShadowPlay, Radeon ReLive, Xbox captures, Screen Recordings and OBS, and `Clear-AdobeData` empties `Team Projects Cache`. Not changed here: the opt-in is an explicit user choice and whether these folders count as cache is a product decision. Next check: the maintainer decides per folder; any removal needs a fixture that keeps an authored recording. |
| CLI-SYNC-10 | System image check and SFC result | Implemented | From Mole for Windows 0.11.5, which stopped repairing the system image inside Optimize after a repair downloaded from Windows Update for 16.5 minutes. `bin/optimize.ps1:Test-SystemImage` reads `Repair-WindowsImage -Online -CheckHealth` (0.4 s in the ARM64 VM, a language-independent enum) on every elevated run and only prints the `RestoreHealth` command with its time cost; the CLI never runs the repair. `Read-SfcOutput` decodes redirected `sfc.exe` output as UTF-16: read as ANSI every other byte was NUL (1560 of 3120 in the VM) and no result phrase ever matched, so every scan printed "Scan completed"; an unread or localized result now points to CBS.log instead of claiming success. Pester `System image and file checks`; the SFC cases fail against the old reader. Not released. |

## Verification and delivery

[Development record](docs/development-record.md) owns dated Pester/Go/CI and physical-machine receipts; [security review](SECURITY_AUDIT.md) owns residual deletion/distribution risks. Those receipts are not repeated here. Latest Windows stable on 2026-10-14: `V1.34.0-windows`, tag source `6f3fba47`, published 07:47 UTC with `make_latest: false`. Its zip and both TUI executables were signed in the Windows ARM64 VM; the public downloads match `SHA256SUMS.txt`, every signature is Valid with a timestamp, and a source install without Go at the tag fetched both tools from it. CLI-SYNC-01..03 shipped in it. ThinkPad delivery of this release and the winget and Scoop manifests are not done. CLI-SYNC-06 and CLI-SYNC-09 stay pending.
