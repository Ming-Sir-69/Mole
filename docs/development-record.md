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
