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

## 2026-10-13: Follow-up review closure

The follow-up queue contained eleven confirmed findings and three checks awaiting reproduction. All fourteen were resolved in the commits below; the extra checks confirmed native exit-code loss, missing release tags after a shallow clone and unsafe proxy-value rendering. No release or version bump is included.

| Item | Final result | Commit |
| --- | --- | --- |
| 1. Development docs missing from install inventory | Both docs and newly shipped files are listed; inventory regression passes | `b033245a` |
| 2. Shared installation directories | Merge copies without clearing directories; remove exact files, retain unknown files and Git metadata, reject linked paths | `b033245a` |
| 3. Shared application install folders | Complete ownership inventory gates preview and final leftover recycling | `2ec4f9b1` |
| 4. Analyze parent selection containing protected data | Bounded descendant review and physical identity recheck before recycling | `5a986a96` |
| 5. Bracket-containing whitelist paths | Literal spelling and descendants remain protected before wildcard interpretation | `2ec4f9b1` |
| 6. Copied install missing its installer | Copy the installer so self-removal remains available | `b033245a` |
| 7. Literal trailing apostrophes | Preserve parsed positional and named arguments | `5a986a96` |
| 8. Service changes for protected cleanup targets | Leave FontCache and Windows Update state alone | `2ec4f9b1` |
| 9. Native optimization failure counted as success | Check native exit status before counting ARP cleanup | `2ec4f9b1` |
| 10. Owner cache output and accounting disagreed | Export preview roots; measure only complete before/after deltas; distinguish unmeasured successful activity | `2ec4f9b1` |
| 11. Generic names marked cleanable | Keep explicit cache-tag hints; remove unsupported name-only hints | `5a986a96` |
| 12. CLI exit status | Propagate native TUI errors and reject unknown commands without stale help status | `5a986a96` |
| 13. Shallow clone release-tag evidence | Fetch tags on update and avoid a shallow fresh clone; document when Go is required | `b033245a` |
| 14. Proxy credentials in malformed or registry values | Sanitize all three proxy sources; never render an unparsed value | `5a986a96` |

Verification before submission: Windows PowerShell 5.1 / Pester 5.7.1 completed 360 tests with zero failures or skips; the final optimize mock adjustment was separately rerun (6 passed). All 49 PowerShell scripts parsed. Go tests, race tests, vet and Windows cross-build passed. The Windows-native Analyze suite passed; the opt-in real Recycle Bin integration test stayed disabled, while all three new recycle safety fixtures passed with a mocked sink. Old-code red runs covered the shared directories, missing installer, ownership, whitelist, service state, native failure, routing and protected-descendant findings; a second red run covered both launcher links and the Git worktree pointer. A local Git fixture confirmed tag absence in a shallow clone, presence in a full clone and restoration through `pull --tags`.

Sibling checks included five owner-cache commands, three proxy input forms, two generated launchers, preview and final uninstall guards, and both directory and file forms of Git metadata. Source and test delivery is complete for this queue; signed release and package-manager delivery remain outside this batch. Remote CI must be checked against the actual branch head rather than inferred from this local evidence.

The first remote follow-up run passed Windows PowerShell 5.1 but exposed a timing-dependent process-tree test under PowerShell 7: its child had not written its PID before cancellation. The fixture now records the PID from the parent and checks termination independently of child startup, with identity-bound fixture cleanup. Production timeout settings are unchanged.

The next remote run passed both PowerShell suites and exposed a Go fixture under the runner’s `AppData\Local\Temp` path, which intentionally suppresses cleanable hints. The cache-evidence fixture now uses relative paths inside its private temporary directory, with separate assertions for the three handled-path exclusions. The old fixture failed under the matching Windows temporary path; the corrected full native Analyze suite passed there. Production hint policy is unchanged.

Final source revision `88cf57e8` passed [Check](https://github.com/tw93/Mole/actions/runs/38382721940) and [Validation](https://github.com/tw93/Mole/actions/runs/38382721936), including both PowerShell versions, Go tests, Build and Security Checks.

## 2026-10-13: Security review and physical Windows acceptance

Added [SECURITY_AUDIT.md](../SECURITY_AUDIT.md), following the macOS CLI audit's threat-surface, deletion-boundary, privilege, distribution, coverage and limitation structure. Claims were checked against the Windows implementations and workflows. Corrected `SECURITY.md`'s stale statement that no operation uses the Recycle Bin and distinguished release policy from artifact verification. `AGENTS.md` now points future safety work to the review. Product behavior is unchanged.

Documentation validation: local references and whitespace checks passed. Windows VM PowerShell 5.1 ran both installation suites with 36 passed, zero failed or skipped, including the shipped-file inventory. `SECURITY_AUDIT.md` was already reserved in the installer inventory and needed no installer change.

The physical-machine acceptance queue remains separate from the passing source/CI evidence:

| Item | State | Evidence or remaining work |
| --- | --- | --- |
| ThinkPad control channel | Verified | Raising the existing UU Remote terminal restored automated typing and Return. A read-only marker command returned successfully. SSH was not needed, and connection/security settings were not changed. |
| Machine and source identity | Verified | The same x64 ThinkPad retrieved the full `windows` branch at `9ef61141` through a maintainer-approved per-command Git proxy. No persistent network setting changed. |
| PowerShell compatibility | Verified with targeted follow-up | At `9ef61141`, PowerShell 5.1 and 7 each completed 360 tests: 358 passed, 2 failed, zero skipped. Both failures occur while creating symbolic-link fixtures without the required privilege, before the safety assertions. The initial longer temporary root also broke fixture creation; a short isolated root removed those failures. At installed revision `4ae61859`, both previously failing link cases passed under temporary elevation in PowerShell 5.1 and 7, each reporting 2 passed, 0 failed, 0 skipped (22 unrelated cases not selected). This was a targeted rerun, not a new full-suite run. |
| Native Go and build | Verified at `dff5ad1b` | Native `go test -timeout 90s ./cmd/...`, `go vet ./cmd/...` and `go build ./cmd/...` each returned 0; `gofmt -l cmd` reported no files. The initial fixture root under Public was correctly protected; moving only the isolated test root outside that tree resolved the fixture failures. |
| Safety and interactive acceptance | Partially verified | The fixture suite above exercised path, ownership and dry-run checks. Status and Analyze rendered on the ThinkPad and returned to the prompt with Ctrl+C. Analyze inspected only the isolated test directory. Real Go recycle integration passed for files, junctions and directories containing junctions, preserving the target data. PowerShell preview retained its fixture, real recycling removed it and shell restore recovered its exact content. Narrow-window rendering remains pending; real app uninstall, service mutation and user-data cleanup are excluded. |
| Review documentation | Complete | Safety model and limitations recorded, including advisory CI checks, path-based race limitations and differences between native recycle APIs. |

Source acquisition is complete. Native Go checks are complete. Real recycle/restore and both privileged link fixtures have now passed on this physical machine. Narrow-window rendering is blocked by the remote terminal: changing the Windows console to 60 columns did not resize the UU display viewport, producing overlapping output. The console size was restored; this capture is not a valid narrow-window product verdict. A matching native Windows terminal viewport is still required, and VM/CI results do not close that hardware check. Raw machine logs remain local. No release is included.

## 2026-10-13: CLI loading and result presentation

The four PowerShell maintenance commands now share the macOS CLI summary frame, blue heading and human-readable sizes. Cleanup sections, application/project scans and slow optimize probes use the same four loading frames as the Mac CLI. A background CLR timer keeps the mark moving during synchronous PowerShell work; redirected output remains static, result rows stop the timer before printing, and command exit paths stop it. The nested user-temp section no longer interrupts its parent section. Uninstall preview uses the shared summary too. Analyze already uses the same loading frames and Status uses the same initial loading text, so neither Go renderer changed.

Verification: Windows VM PowerShell 5.1 / Pester 5.7.1 passed all 366 tests with zero failures or skips. Baseline regression runs failed for redirected animation, summary framing, result-row coordination and the missing background timer. The final scanner-contract assertion verifies the actual activity/status label and completion stop. Changed scripts passed encoding and whitespace checks. Source revision `dff5ad1b` passed [Check](https://github.com/tw93/Mole/actions/runs/38403088212) and [Validation](https://github.com/tw93/Mole/actions/runs/38403088133), including both PowerShell versions, Go, Build and Security Checks. ThinkPad retrieved that revision and displayed the shared summary and distinct loading frames during a synchronous wait; Ctrl+C cleared the loading line and returned the prompt. Both PowerShell 5.1 and 7 then passed all six presentation tests on the same physical source revision. This was a read-only helper preview, not a real cleanup or uninstall. Status and Analyze also rendered and exited through Ctrl+C on the ThinkPad. Narrow-window command rendering remains pending. No release or version bump is included.

The existing ThinkPad source installation was updated in place to `4ae61859`, and the installer rebuilt both native tools successfully. The installed `mo --version` reports Mole 1.33.0 / Source, and launching `mo` renders the main menu. This is the latest source installation, not a new tagged release. Temporary elevation was limited to the two link fixtures; developer mode and persistent network/security settings were not changed.

## 2026-10-13: Mixed-language lists and completion presentation

The four-item follow-up covers uninstall alignment, unknown Store sizes, abrupt maintenance completion and Analyze's unexplained percentage placeholders. Uninstall and Purge now truncate and pad names by terminal display cells. At 80 columns, the ASCII, Chinese and long-name fixture rows all end at column 59; the old Chinese row ended at 64. A 40-column project fixture including its item suffix stays within 39 columns. Store inventory uses a separate read-only, bounded, no-follow measurement rather than deletion identity checks; unavailable sizes say `Unknown`, and the v3 cache invalidates old zero measurements. All four shared summary callers now wait 180 ms after stopping loading only in an interactive terminal, then print the result; redirected commands do not wait. Analyze leaves an unknown percentage blank rather than printing `--`, retaining the fixed column and complete-denominator requirement.

Windows PowerShell 5.1 / Pester 5.7.1 passed 374 tests, zero failures or skips. Eight new regression checks were observed failing against old production, including the actual uninstall menu and Store inventory caller; the percentage regression also failed against the old formatter. Go tests, vet and the Windows cross-build passed. In an ordinary-user Windows VM, Calculator, ZuneMusic and Camera changed from 0 KB to 20,834, 37,351 and 23,281 KB respectively without permission changes. An 80-column native Windows console screenshot also confirmed that the ASCII, Chinese, mixed and truncated fixture sizes share the same right edge. Source revision `68d26ec9` passed [Check](https://github.com/tw93/Mole/actions/runs/38423864711) and [Validation](https://github.com/tw93/Mole/actions/runs/38423864665), including both PowerShell versions, Go, Build and Security Checks. The ThinkPad installation was updated in place to this revision and rebuilt both native tools. Its actual uninstall menu showed aligned Chinese, ASCII and truncated names; ZuneMusic, Camera, Calculator, WebMedia and MPEG2 entries now showed 36.4 MB, 23.0 MB, 18.4 MB, 4.9 MB and 1.8 MB. No application was selected or removed. Clean and optimize dry runs reached their final summaries without performing cleanup or maintenance; optimize also displayed its loading state, and its Windows Update probe remained unavailable. The rebuilt Analyze rendered the isolated acceptance directory with complete percentages and returned to the prompt on cancellation. Screenshot sampling confirms the endpoints, not the subjective feel of the 180 ms transition. Narrow native-console acceptance remains the separate pending check described above. No release is included.

## 2026-10-14: Product synchronization and remaining safety differences

Root [SYNC.md](../SYNC.md) now owns the two-CLI adaptation queue and routes app comparisons to their private owners. All four project guides use the same names, workflow, status vocabulary and evidence boundaries. This file remains the runtime/delivery record rather than a second synchronization backlog.

`0b78b46b` retains deletion targets when whitelist metadata/content cannot be read, handles literal bracket filenames and removes Spotify Data/Storage from automatic cleanup. `3a7f8b7b` selects the registered normal command only for the verified Proton Pass 1.37.0 / Proton AG / Update.exe case. Seven neighboring command registrations preserve their quiet behavior. Installer ownership includes root `SYNC.md` and the portable `CLAUDE.md` entry point, which routes to `AGENTS.md` without duplicating its rules.

Verification: an isolated Windows ARM64 VM on Windows PowerShell 5.1 with Pester 6.2.0 passed all 386 tests, zero failed or skipped, including installation inventory. The focused old-source run reported 106 passed and five failed, exactly the three protection cases, Spotify preservation and the Proton Pass command. Its earlier setup attempt used protected SYSTEM temp paths and was discarded; the corrected run set SystemTemp, TEMP and TMP together as the existing pitfalls guide requires. Go tests and the Windows cross-build passed. After adding the portable agent entry point to installation ownership, both installer suites passed again (36 passed, zero failed or skipped). Real application uninstall, cleanup of user data, a new ThinkPad installation and signed release delivery were not performed. Relevant CI must be read at the final pushed SHA.

## 2026-10-14: Large-tree cleanup time

A cleanup target with tens of thousands of files was kept instead of cleaned. Measured on the Windows ARM64 VM (Windows PowerShell 5.1, folders of 50 files each, validation with `Get-SafeDirectoryTreeItems`): 5,000 files took 4.5 s, 20,000 took 18.9 s, and 50,000 reached the 15 s walk limit and returned `Success = $false`. The walk limit itself is unchanged.

Two costs dominated and neither changes what is checked. The whitelist file was read and its default patterns re-expanded for every child; it is now read once per tree and matched with the same rule (the new test compares it with `Test-WhitelistPattern` over wildcard, bracket, backtick, trailing-backslash and case variants, and fails when backtick handling is removed). Each child also reopened its whole ancestor chain right after the walk had verified the parent; a child now reads only its own identity and reuses the parent's chain, which the removal sink still rebuilds and compares in full. A test pins that chains match a fresh snapshot of every item, that a replaced directory still fails the recheck, and that the walk takes no per-child ancestor snapshot (13 calls before, 6 after).

After: 5,000 files 1.6 s, 20,000 files 6.3 s, 50,000 files 18.3 s with `Success = $true`. The walk alone dropped from 14.5 s to 7.2 s at 50,000 files. Results come from one VM, so a ThinkPad or a machine with real-time scanning will differ. Windows PowerShell 5.1 / Pester 5.6.1 passed 396 of 398 tests; the two failures are the launcher symbolic-link case, which needs administrator rights in this VM. Not changed: the 15 s walk limit, the 100,000-entry and 10 s Analyze review limit, and the `Program Files` protection.

## 2026-10-14: Windows CLI 1.34.0 release

`V1.34.0-windows` was tagged on `6f3fba47` and published with `make_latest: false`; `releases/latest` still names the macOS release. The first tag run failed before any release object existed, for two reasons the plain CI runs had not exposed: the hosted runner carries two Go installs, so the test runner's single-path assumption failed its Go gate after 398 Pester tests passed (`f1de8140`), and the release build re-runs the tests under StrictMode, where Pester read the unbound `<sha256>` and `<name>` in one test title as variables (`6f3fba47`). Both were reproduced before fixing: the second only under `Set-StrictMode -Version Latest` in the VM. A `workflow_dispatch` rehearsal then passed the whole build without creating a release, and the unreleased tag was recreated on the fixed commit.

Signing ran in the Windows 11 ARM64 VM with an x64 `signtool.exe` from the Microsoft.Windows.SDK.BuildTools package (itself Valid, Microsoft-signed) and the Certum certificate in the user store. `sign-release.ps1` signed 25 files inside the zip (22 scripts, `mo.exe`, `analyze.exe`, `status.exe`) and both TUI executables. Independently of the script, all 27 files were Valid with the expected thumbprint and a timestamp, the zip differed from the unsigned one only by signature blocks (script bodies equal once the block is removed, 57 other files byte for byte), and the rewritten `SHA256SUMS.txt` is ASCII without a BOM. After publishing, the public downloads matched `SHA256SUMS.txt` and a fresh source install without Go at the tag fetched `analyze.exe` and `status.exe` from the release, signatures Valid, `mo --version` printing 1.34.0.

Not done: ThinkPad acceptance of this release (the device was offline in UU Remote), and the winget and Scoop manifests, which are submissions to other projects. Pester in the VM passed 397 of 399 tests; the two failures are the launcher symbolic-link case, which needs administrator rights there and passes on the hosted runner.

## 2026-10-14: System image check and SFC result (CLI-SYNC-10)

`mo optimize` now reads the system image verdict through `Repair-WindowsImage -Online -CheckHealth` when elevated and suggests `DISM /Online /Cleanup-Image /RestoreHealth` with its time cost when the image is repairable; it never runs the repair itself. The opt-in System File Checker result is decoded as UTF-16, since the old reader matched no phrase and reported every scan as completed, and a result it cannot read now points to CBS.log. Verification in the Windows ARM64 VM: the full Pester suite passed 406 of 408 with the same two elevation-only symbolic-link failures as the unchanged baseline (397 of 399), and the two SFC result cases fail when the old reader is restored. No tag, version bump or release was part of this batch.

## 2026-10-15: Update from a PowerShell 7 terminal (#1744)

`mo update` started from PowerShell 7 could not refresh `analyze.exe` and `status.exe` without Go. `mo.cmd` runs Windows PowerShell 5.1 through `cmd.exe`, so the child inherits PowerShell 7's `PSModulePath` first; in 5.1 `Get-FileHash` is a script function of `Microsoft.PowerShell.Utility`, so it stopped resolving, and the restore `catch` reported that as an ordinary unavailable release. `mole.ps1` now drops the PowerShell 7 module folders for its own process under Windows PowerShell (`Repair-MoleModulePath`, user folders kept, system modules guaranteed), the download is hashed through .NET (`Get-MoleFileSha256`), and a failed fetch of a verified release prints its cause. The launcher text is unchanged: its `(goto)` line ends the batch context, so a variable set there either reverts or leaks into an interactive `cmd` session. Because `mo update` pulls the source and then runs the new `install.ps1`, a source install picks the fix up on its first update.

Verification: the six new Pester cases ran under PowerShell 7.6.7 on macOS and failed against the old `tui_binaries.ps1` and `mole.ps1`; the Core, Install and InstallLifecycle files showed no failure beyond the unchanged macOS baseline, which is Windows-API cases only. The Windows PowerShell 5.1 and pwsh 7 runs are CI's at the pushed SHA. The reported PowerShell 7 parent with a `cmd.exe`-started 5.1 child was not reproduced on a Windows machine. No tag, version bump or release was part of this batch.

## 2026-10-15: Debug session log and source commit (CLI-SYNC-11)

`mo <command> --debug` printed no debug line before this batch: each command script loaded `lib/core/log.ps1` before its `Main` set `MOLE_DEBUG`, and nothing called `Enable-DebugMode`. The router now opens `~\.config\mole\mole_debug_session.log` before a `--debug` command (`993ea1ca`), the module reads `MOLE_DEBUG` at load time so the command's own debug and message lines reach the file, and the run ends with the saved path, as on macOS. `c8efaff9` builds that path by interpolation after a macOS PowerShell run showed `Join-Path` throwing on an empty `USERPROFILE`, which would have stopped every command from loading. `6cd37894` adds the source commit to `mo --version` and the session header. MSI detection was left out because no release ships an MSI.

Verification: CI Validation at `c8efaff9` passed 424 of 424 Pester tests under both Windows PowerShell 5.1 and pwsh 7, with no skips. Under PowerShell 7.6.7 on macOS, the router, version, session and empty-`USERPROFILE` cases failed against the previous `mole.ps1` and `lib/core/log.ps1`, and the remaining failures matched the unchanged macOS baseline of Windows-API cases. The child case that runs Windows PowerShell after the router set `MOLE_DEBUG` was verified only on CI. No real `--debug` run on a Windows machine, tag, version bump or release was part of this batch.

## 2026-10-15: Operation log (CLI-SYNC-12)

`Write-MoleOperation` in `lib/core/log.ps1` appends each real removal, recycle and failure at `Remove-SafeItem` and `Remove-SafeItems` (and so `Remove-OldFiles` and `Clear-DirectoryContents`), and each app outcome in `mo uninstall`, to `~\.config\mole\operations.log`. Lines follow the macOS CLI format, `[time] [command run=id] ACTION path (detail)`, under one session marker written with the first record, so a run that removes nothing leaves the log untouched. The router sets the run id. Control characters are escaped and backslashes stay literal; dry runs write nothing; `MO_NO_OPLOG=1` turns it off, and `scripts/test.ps1` sets it so local test removals stay out of a developer's own log; past 5 MB the log moves to `.old`. Mole's own scratch, cache and download files are not recorded, as on macOS. A `mo history` reader is CLI-SYNC-13 and waits on a product decision.

Verification: CI Validation at `551692e5` passed 429 of 429 Pester tests under both Windows PowerShell 5.1 and pwsh 7, with no skips, including the five `Operation log` cases. Under PowerShell 7.6.7 on macOS the writer itself was exercised directly (record format, escaping, `MO_NO_OPLOG=1`, rotation) and the escaping case passed; the four sink cases need Windows path removal, which the macOS baseline cannot do, so they were not run red against the previous sinks. No real cleanup on a Windows machine, tag, version bump or release was part of this batch.

## 2026-10-15: mo history (CLI-SYNC-13)

`mo history` reads `operations.log` back as recent sessions with their action counts and recent operations, newest first, as text or `--json`, with `--limit N` or `--limit=N` from 1 to 200; an invalid argument exits 2, propagated by the router as for analyze and status (`289ead20`). Each record now ends in exactly one parenthesis-free detail (`-` when empty) so a path holding parentheses reads back whole; the log format had not shipped, so no fallback was kept. README copies list the command and the log in all nine languages.

Verification: CI Validation at `289ead20` passed 441 of 441 Pester tests under both Windows PowerShell 5.1 and pwsh 7 with no skips, and Check passed. The twelve new cases include end-to-end runs through `mole.ps1` for both limit spellings, text output and the three refusals. Under PowerShell 7.6.7 on macOS the six reader cases passed and the router was exercised for text, JSON, both limit spellings and every refusal; the command cases need Windows PowerShell and ran only on CI. No tag, version bump or release was part of this batch.
