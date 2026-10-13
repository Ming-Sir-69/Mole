# Product synchronization

This is the synchronization entry point for **Mole CLI (Windows)**, branch `windows` of `tw93/Mole`. Workflow and the four canonical product names are in [AGENTS.md](AGENTS.md#product-synchronization). Source review baseline: `7d1051af`, 2026-10-14, Asia/Singapore. This is a source/record review, not a new full runtime audit or a release.

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

## Verification and delivery

[Development record](docs/development-record.md) owns dated Pester/Go/CI and physical-machine receipts; [security review](SECURITY_AUDIT.md) owns residual deletion/distribution risks. Those receipts are not repeated here. Latest Windows stable checked on 2026-10-14: `V1.33.0-windows`, tag source `6d6a16cf`. Later source fixes and the ThinkPad development installation are not a new signed release. CLI-SYNC-01..03 are implemented and tested in the VM; new signed-release and ThinkPad delivery remain unverified. Release readiness still requires the release runbook, not this source-state reconciliation.
