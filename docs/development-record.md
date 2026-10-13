# Windows CLI development record

This is the handoff record for the `windows` branch of `tw93/Mole`, not the paid Windows app or the macOS CLI. Read [AGENTS.md](../AGENTS.md) for current policy and [development pitfalls](development-pitfalls.md) for reusable lessons. Git history retains individual edits; this file records completed batches and their delivery boundaries. Recheck live state before resuming work.

## 2026-10-13: Windows CLI review fixes

All ten findings in this batch were fixed and pushed to `windows`. No tag, version bump or release was part of this batch.

| Finding | Result | Commit |
| --- | --- | --- |
| Environment-only dry-run ignored by clean and optimize | Both honor `MOLE_DRY_RUN=1` | `01a2e0b5` |
| Cleanup could traverse junction ancestors or remove a replacement directory | Bind and recheck Windows file identities; retain unknown targets | `01a2e0b5` |
| Directory whitelist and native cleanup owner boundaries differed | Protect descendants, resolve actual owner roots, retain Gradle locks; automatic Docker builder pruning disabled because local exclusions cannot constrain remote roots | `01a2e0b5` |
| Purge matched authored generic folders or Git-owned content | Scope artifacts to ecosystems, exclude `.idea`, recheck tracked content and nested repositories | `01a2e0b5` |
| Analyze accepted hidden actions during deletion | Ignore further action keys while allowing quit | `b8b27771` |
| Test runner could report incomplete validation as success | Require a nonempty passing Pester result and successful Go checks unless explicitly skipped | `a4df0c66` |
| Source update retained stale native tools | Refresh both tools from matching release source or build current source; preserve old binaries on failure | `59b3bcc4` |
| Generated CMD launcher altered special arguments | Pass arguments through native `-File` invocation and preserve exit status, including self-removal | `59b3bcc4` |
| Package-manager update guidance required Git first | Show the appropriate package-manager command before the Git prerequisite | `59b3bcc4` |
| An older same-path scan could replace a newer scan | Register request identity before asynchronous dispatch | `b8b27771` |

Verification at `a4df0c66`: Windows PowerShell 5.1 with Pester 5.7.1 passed 317 tests with no failures or skips; Go tests, Analyze race tests, Windows cross-build and native Windows Analyze tests passed. Regression fixtures were observed failing against the prior behavior. Remote [Check](https://github.com/tw93/Mole/actions/runs/38374255543) and [Validation](https://github.com/tw93/Mole/actions/runs/38374255484) passed, including PowerShell 5.1 and 7.

## 2026-10-13: Recoverable uninstall leftovers

Commit `ab00bd7c` sends verified leftover install folders to Recycle Bin through the shell recycle operation, with no permanent-delete fallback. It rechecks identity and protected descendants and excludes recycled bytes from reclaimed-space totals. This was a separate implementation batch following the review fixes.

The implementing session reported 324 passing Windows VM tests, passing Go tests and Windows cross-build, plus actual recycle/restore and locked-file retention checks. Remote [Check](https://github.com/tw93/Mole/actions/runs/38375839905) and [Validation](https://github.com/tw93/Mole/actions/runs/38375839592) passed, including PowerShell 5.1 and 7, Build and Security.

Delivery boundary for both batches: source is on `windows`; these entries do not establish that a signed release or package-manager update contains the changes. Release work requires its own authorization and the checks in [RELEASE.md](../RELEASE.md).
