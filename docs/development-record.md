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
| Machine and source identity | Partially verified; source retrieval blocked | Lenovo model `20UAS2DR00`, Windows 11 Pro `10.0.26200`, x64; PowerShell `5.1.26100.7920` and `7.6.6`, Pester `5.9.1`, Go `1.27.2 windows/amd64`. The existing installation reports `86e2b2508032d4ce671eb67bc2ce42bda075b2bc`. Latest-source cloning stalled, and the single bounded retry timed out at 60 seconds. A read-only GitHub HTTPS probe returned curl status 28 (connection timeout); Git HTTP proxy was unset and no URL rewrite was configured. This does not establish the underlying network cause. |
| PowerShell compatibility | Pending | Run the complete nonempty Pester suite under 5.1 and 7 on that source; retain runner summaries, skips and exit status. |
| Native Go and build | Pending | Run Go tests, vet, formatting and builds for Analyze, Status and the launcher on x64 hardware; record any unavailable tooling separately. |
| Safety and interactive acceptance | Pending | Run fixture-based path, ownership, dry-run and recycle checks. Inspect read-only CLI/TUI startup and exit behavior. Real app uninstall, service mutation and user-data cleanup are excluded. |
| Review documentation | Complete | Safety model and limitations recorded, including advisory CI checks, path-based race limitations and differences between native recycle APIs. |

Resume latest-source acquisition in the isolated test directory after the machine can reach GitHub. No further retries, alternate download route or network changes were attempted after the failed retry. The PowerShell and Go test queues have not run on this physical machine for the reviewed revision. Use the repository test runner and the actual CI workflow as the command inventory; never substitute an observed desktop, transferred file, VM result or past test log for a completed ThinkPad run. Store raw machine logs locally, and add only sanitized evidence here. No release is included.
