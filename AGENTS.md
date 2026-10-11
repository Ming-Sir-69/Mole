# Mole for Windows (CLI) Agent Guide

This file is the source of truth for any AI agent working on the `windows` branch of `tw93/Mole` (Claude Code, Codex, etc.). The macOS CLI lives on `main` with its own guide; do not apply macOS rules (`/System`, Bash 3.2, Bats) here.

## Project

Mole for Windows is the free, open-source, terminal-first Windows maintenance CLI: PowerShell 5.1 scripts (`mole.ps1`, `bin/*.ps1`, `lib/**`), two Go TUIs (`cmd/analyze`, `cmd/status`) and the `mo.exe` launcher (`cmd/mo`) that package managers put on PATH. It is GPL-3.0, like `main`. Safety matters more than speed: a cleanup that deletes the wrong thing costs more than one that skips.

## Product Boundary

Mole for Windows, the paid native GUI, is a separate private product. This branch stays the narrower, scriptable CLI, the same relationship as the macOS CLI and Mole Mac: shared product values, no required feature parity.

Changes that come to this branch from the paid app:

- Safety fixes, such as a protected path or an over-broad match.
- Correctness fixes for a surface this CLI already has, such as uninstall sizes or duplicate entries.
- Public "never delete this" rules and exclusions.

Changes that stay out:

- GUI-only capabilities: app updates through winget, startup management, Doctor, tray, the treemap and MFT-based Analyze, deeper Status metrics, AI cleanup.
- The elevated batch protocol.
- The measured per-app uninstall leftover catalog.

A feature request asking for one of those gets a short "not planned for the CLI" answer, not a port. Fixes found here, including community PRs, are an input for the paid app; record them in its sync ledger rather than here.

## Commands

```powershell
.\scripts\test.ps1                 # Pester tests and Go tests
Invoke-Pester -Path .\tests        # PowerShell tests only
go test ./cmd/...                  # Go tests only
go build -o bin\analyze.exe .\cmd\analyze
go build -o bin\status.exe .\cmd\status
$env:MOLE_DRY_RUN = "1"; .\mole.ps1 clean   # preview, no changes
.\mole.ps1 clean --dry-run
```

On macOS, `GOOS=windows go build ./cmd/...` and `gofmt -l cmd` check the Go side; PowerShell behavior needs Windows.

## Safety Rules

- Delete only through `Remove-SafeItem`, `Remove-SafeItems`, `Remove-SafeDirectoryTree`, `Remove-OldFiles` and `Clear-DirectoryContents` in `lib/core/file_ops.ps1`. They go through `Test-SafePath` (protected paths and the whitelist) and honor dry-run mode. A raw `Remove-Item -Recurse -Force` is flagged by the Validation workflow.
- `Test-ProtectedPath` in `lib/core/base.ps1` fails closed: an empty or unparsable path counts as protected. Keep it that way.
- `$script:ProtectedPaths` (system roots such as `C:\Windows` and `C:\Program Files`) are protected with everything below them; `$script:ExactProtectedPaths` protects the user profile root itself while still allowing targeted cache cleanup under it (#1122). Add to these lists, never route around them.
- Every command that deletes or uninstalls (`clean`, `uninstall`, `purge`, `optimize`) only reports in dry-run mode, whether set by `--dry-run` or `MOLE_DRY_RUN=1`. `uninstall --dry-run` names the uninstaller it would run and starts none; `tests/DryRun.Tests.ps1` mocks `Start-Process` and `Remove-AppxPackage` to fail if called.
- The bulk delete helpers write nothing to the pipeline and count dry-run results too, so the clean summary and `clean-list.txt` match the preview. A caller that ignores `Remove-SafeItem`'s boolean assigns it to `$null`.
- `%LOCALAPPDATA%\Mole` is the Mole for Windows app's data folder (license, settings, registry backups). New installs default to `%LOCALAPPDATA%\Programs\mole-cli`; an existing source install there keeps updating in place. `install.ps1 -Uninstall` removes only the entries `Get-MoleInstallEntries` lists, keeps everything else, refuses a folder without `mole.ps1`, and never falls back to another folder; `tests/Install.Tests.ps1` locks this.
- `~/.gitconfig.lock` is never deleted: Git holds it while it writes the config, and neither age nor an idle git process proves the write is over (same rule as `main`).
- Verify cleanup and uninstall changes with dry-run first; tests must not need a real UAC prompt.
- Known limit: a `node_modules` holding a junction (pnpm, `npm link`) is not removed by purge; Windows PowerShell 5.1 does not recurse into the junction, so its target is safe, but the removal fails.
- Uninstall sizes come from the registry `EstimatedSize` (KB) with `InstallLocation` measured as a fallback; a vendor value can be wrong (#1717), so treat outliers as unverified rather than trusting them for sorting.

## Compatibility

- The target is Windows PowerShell 5.1 on Windows 10 and 11. CI runs Pester under both Windows PowerShell 5.1 and pwsh 7; code that only works in pwsh 7 (`??`, `?.`, ternary, `-Parallel`) is a bug.
- Keep scripts ASCII or UTF-8 with BOM; Windows PowerShell 5.1 reads BOM-less non-ASCII text through the legacy code page.
- Go: the toolchain is pinned once, by `toolchain` in `go.mod`, and every workflow reads it through `go-version-file`.

## CI

- `Check`: `gofmt -l` must be clean, PowerShell syntax must parse, golangci-lint is pinned and advisory until its existing findings are fixed. CI never commits on its own.
- Run `actionlint` on workflow changes before pushing; a step's `shell:` cannot read the matrix, which GitHub rejects before any job starts.
- `Validation`: Pester on both PowerShell versions, Go tests, binary build, security checks.
- Actions are pinned by commit SHA, the same versions `main` uses.

## Release

Read `RELEASE.md` before any release work. In short:

- Tags are `V<version>-windows`; a version with a pre-release segment publishes a prerelease. The version lives in `VERSION` and `lib/core/version.ps1`; bump both together.
- The workflow creates a draft. `scripts/sign-release.ps1` signs every `.ps1` and `.exe` on a Windows machine with the code-signing certificate (CI never has the key), then the signed files replace the draft's and it is published. Attestations are not used, because signing replaces the bytes CI built.
- Every Windows release keeps `make_latest: false`, because the macOS installer and `mo update` resolve stable versions through `releases/latest`.
- `scripts/build-release.ps1` produces every asset and calls `scripts/write-checksums.ps1`; `SHA256SUMS.txt` must list the zip and both TUI executables, since `lib/core/tui_binaries.ps1` refuses a download it cannot match and never falls back to building after a mismatch.
- Package-manager manifests are templates in `packaging/`, filled by `scripts/render-packaging.ps1` from the published `SHA256SUMS.txt`. `mo update` prints the winget or Scoop upgrade command for those installs.
- Releases, tags and package-manager submissions need the maintainer's explicit go-ahead.

## GitHub

- Windows issues and PRs live in `tw93/Mole`; PRs target the `windows` branch. Prefer reviewing and merging a contributor PR over landing an equivalent fix yourself.
- Never point users to the private paid-app repository. Reply in the reporter's language, start with `@reporter`, and give the exact command to update: `mo update` for source installs.
