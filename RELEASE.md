# Mole for Windows (CLI) - Release Guide

A Windows release goes through three hands: CI builds the assets into a draft release, the maintainer signs them on Windows, and the signed files replace the draft's before it is published. The macOS CLI on `main` has its own `V*` tags and release workflow; the two never share a version number.

## Tags

| Tag | Result |
|---|---|
| `V1.31.0-windows` | Stable release |
| `V1.31.0-beta.1-windows` | Prerelease (any `-` left after removing `-windows`) |

Every Windows release keeps `make_latest: false`. The macOS installer and `mo update` resolve the stable macOS version through `releases/latest`, so a Windows release marked latest would break macOS updates. When editing a release by hand, leave "Set as the latest release" unchecked.

## Assets

| File | Purpose |
|---|---|
| `mole-<version>-x64.zip` | Portable install; `mo.exe` at its root is what package managers put on PATH |
| `analyze-windows-x64.exe`, `status-windows-x64.exe` | TUIs that source installs download on first use |
| `SHA256SUMS.txt` | Checksums of the three files above; the TUI download refuses a file that does not match |

## 1. Prepare

1. CI is green on the `windows` commit you will tag: `Check` and `Validation`, including both PowerShell legs.
2. Bump the version in one commit: `VERSION` and `$script:MoleDefaultVersion` in `lib/core/version.ps1`.

## 2. Tag

```powershell
git tag V1.31.0-windows
git push origin V1.31.0-windows
```

`.github/workflows/release-windows.yml` runs the tests, runs `scripts/build-release.ps1`, and creates a **draft** release with the unsigned assets.

## 3. Sign

On a Windows machine with the code-signing certificate available (for Certum, log in to SimplySign Desktop first; the session expires after a few idle hours):

```powershell
gh release download V1.31.0-windows --repo tw93/Mole --dir C:\mole-release
$env:MOLE_SIGN_PARAMS = "/fd sha256 /tr http://time.certum.pl /td sha256 /sha1 <thumbprint>"
.\scripts\sign-release.ps1 -Path C:\mole-release
```

The script needs an x64 `signtool.exe` (it finds the Windows SDK build tools or vpk's copy, or set `MOLE_SIGNTOOL`). It signs every `.ps1` and `.exe` in the zip and both TUI executables, verifies each signature and timestamp against the thumbprint, rebuilds the zip, and rewrites `SHA256SUMS.txt`. A timestamp or HSM hiccup is retried once; a second failure stops the script.

If the Windows machine has no `gh`, download and upload the files from another machine through a shared folder.

## 4. Publish

```powershell
gh release upload V1.31.0-windows C:\mole-release\* --repo tw93/Mole --clobber
gh release edit V1.31.0-windows --repo tw93/Mole --draft=false --latest=false
```

Then check:

- `gh api repos/tw93/Mole/releases/latest --jq .tag_name` still prints the macOS tag.
- A downloaded asset matches `SHA256SUMS.txt`, and `Get-AuthenticodeSignature` reports `Valid` for `mo.exe`.

## 5. Package managers

Render and submit the winget, Scoop and Chocolatey manifests as described in `packaging/README.md`.
