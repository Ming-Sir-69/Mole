# Windows CLI development pitfalls

Read only the section matching the change. [AGENTS.md](../AGENTS.md) owns current safety and compatibility policy; this reference explains verified failure mechanisms from the October 2026 Windows review. [The development record](development-record.md) holds delivery evidence.

## PowerShell path and Git probes

Windows PowerShell 5.1 can return no item for a missing `.git` path without the expected exception, including under bracket-containing paths. Absence of an exception is not proof of existence. The purge ancestor probe uses `File.GetAttributes` and classifies only file/path-not-found errors as missing; other failures retain the candidate. Read its current implementation in [bin/purge.ps1](../bin/purge.ps1) before changing the probe.

Git for Windows rejects `GIT_CONFIG_GLOBAL=NUL` in the tested configuration; the isolated purge process uses `/dev/null`. Preserve its Git environment isolation, literal case-insensitive pathspecs and explicit UTF-8 output decoding. Test a tracked artifact and an eligible untracked artifact under the same bracket-containing path. A test that only expects zero candidates can pass because discovery is entirely broken. [PurgeBoundary.Tests.ps1](../tests/PurgeBoundary.Tests.ps1) includes these controls, Unicode paths and inherited index/pathspec overrides.

## CMD launchers and PowerShell binding

Do not turn paths or arguments into interpolated PowerShell source. The generated launcher uses `DisableDelayedExpansion` and native `-File` argument forwarding. Its `(goto)` transfer also supports removing the running batch file; changing that sequence can lose scoped environment variables, report a missing batch file or overwrite the child's exit status.

Root and command-local flags have different PowerShell binding paths: a long root help flag may arrive in remaining arguments, while a short help flag may bind to the root switch even for a child command. Exercise both routing and the real generated launcher. [InstallLifecycle.Tests.ps1](../tests/InstallLifecycle.Tests.ps1) covers special characters, command-local flags and exit status after self-removal.

When checking decoded JSON argument arrays in PowerShell 5.1, assign the decoded value before asserting its elements. Wrapping the conversion pipeline in an array can count one emitted array object rather than its individual arguments, falsely suggesting argument loss.

## Test isolation and false success

A global `git` function left by one Pester file can intercept later tests that need the real executable. A passing isolated file does not prove suite isolation. Keep mocks file-scoped, restore modified process environment in `finally` or teardown, and run the full suite after changes to shared mocks. [GitProxy.Tests.ps1](../tests/GitProxy.Tests.ps1) uses a local stub with Pester-managed mocks.

For process-tree timeout fixtures, have the parent record the spawned child PID immediately. Waiting for a cold child PowerShell to write its own PID can fail on CI even when cancellation works. Keep a positive child-existence assertion, verify termination, and bound fixture cleanup by both PID and start time; do not change production timeouts to accommodate the harness.

Use the runner's result and exit status, not a count of matching output lines. [TestRunner.Tests.ps1](../tests/TestRunner.Tests.ps1) executes child runners with real passing, failing, empty and skipped suites plus native Go failures. Keep positive controls alongside refusal cases; an always-failing runner is not a safety improvement.

For Windows VM tests launched as SYSTEM, create a private fixture profile before starting jobs, and set process-local `USERPROFILE`, `APPDATA` and `LOCALAPPDATA`. Set `SystemTemp`, `TEMP` and `TMP` together to an unprotected fixture directory outside Windows and other protected roots. Setting only `TEMP` and `TMP` can leave Pester or .NET using the system temp directory. Do not change the host's permanent environment or weaken production protection for test fixtures. If Pester is installed outside standard module locations, prepend that directory to process-local `PSModulePath` so child PowerShell processes can find it too.

When copying a source archive from macOS, exclude AppleDouble `._*` files and extended attributes at export. Those metadata files can be discovered as tests or install entries on Windows. Inspect the extracted inventory before interpreting a new parse or discovery failure as a product bug. Keep machine-specific runners and temporary paths outside tracked documentation.

## Asynchronous Analyze actions

Two scans can target the same path and still represent different requests. Establish request identity before dispatch, then validate both identity and path when accepting results. Separately test that busy deletion rejects action keys and still permits quit. [lifecycle_test.go](../cmd/analyze/lifecycle_test.go) covers these boundaries; path equality alone or a busy rendering state does not enforce them.

## Native evidence and release evidence

Cross-compilation proves the Go source builds for Windows; it does not exercise PowerShell, junction behavior, shell recycling or CMD quoting. Use actual Windows fixtures for those surfaces and mock destructive third-party owner commands. Preserve dry-run and positive eligible-target controls alongside protected-target tests.

A passing CI run and pushed source do not establish delivery in signed packages. Keep source, native validation and release evidence separate in the development record, and verify the actual release channel before telling users an update contains a fix.

## Installer inventory and shared directories

A documentation-only change can still change uninstall behavior: the October 13 development notes were initially missing from the install inventory, and both PowerShell CI jobs failed. Every shipped nested file belongs in `Get-MoleInstallNestedFiles`; its inventory test is a required check even for docs. A familiar directory name such as `bin` or `scripts` does not establish ownership of all its contents. Merge installation files and remove exact known files, preserving unknown entries and nonempty Git metadata. Test a shared directory, a pre-created empty directory and a linked ancestor independently.

Release-source equivalence needs the release tag locally. A shallow branch clone may omit it even when the native source is unchanged; missing evidence must not silently select an older binary. Fetch tags through the existing install/update path and test unrelated source changes separately from native source changes.

## Parent selections and accounting

Protecting a child path is insufficient when another entry point moves its whole parent. Analyze must inspect protected descendants at review and at its final recycle boundary, while uninstall additionally verifies surviving installed-app owners from a complete inventory rather than its filtered menu. Keep unknown ownership or incomplete traversal read-only.

Owner pruning may retain most of its store. A preview lists the root but cannot call its full size reclaimable; a successful command can still release zero measurable bytes. Preserve that distinction through summary rendering. Empty PowerShell pipelines can produce no `Measure-Object` result under strict mode, so accumulating file lengths must handle an empty set explicitly. Native nonzero exit codes also do not throw automatically in Windows PowerShell 5.1: check `LASTEXITCODE` before counting success.
