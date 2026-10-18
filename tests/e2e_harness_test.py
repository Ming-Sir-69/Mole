"""Mock-only tests of the Mac-hosted Windows release runner."""

from contextlib import ExitStack, redirect_stdout
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch
import zipfile


SPEC = importlib.util.spec_from_file_location(
    "e2e_windows", Path(__file__).resolve().parents[1] / "scripts/e2e_windows.py")
E2E = importlib.util.module_from_spec(SPEC)
# Windows CI exercises orchestration, never the Unix terminal implementation.
with patch.dict("sys.modules", {name: Mock() for name in ("fcntl", "pty", "termios")}):
    SPEC.loader.exec_module(E2E)


class DependencyTests(unittest.TestCase):
    def run_candidate(self, failed=None, keep_going=True, download_fixture=None):
        with tempfile.TemporaryDirectory() as tmp, ExitStack() as stack:
            run = object.__new__(E2E.Run)
            run.id, run.dir = "fixture", Path(tmp)
            run.keep_going, run.steps, run.failed = keep_going, [], False
            run.info, run.remote = {"work": "fixture", "profile": "fixture"}, Mock(target="fixture")
            run.token = "fixture"
            calls = []
            real_download = E2E.download
            for name in ("preflight", "deploy", "download", "install", "launch", "uninstall", "history", "analyze", "smoke"):
                def action(_run, name=name):
                    calls.append(name)
                    if name == "download" and download_fixture:
                        return real_download(_run)
                    if name == failed:
                        raise E2E.StepFailed("injected failure: " + name)
                stack.enter_context(patch.object(E2E, name, side_effect=action))
            stack.enter_context(patch.object(E2E, "Run", return_value=run))
            stack.enter_context(patch.object(E2E, "cleanup", return_value=[]))
            stack.enter_context(patch.object(E2E.subprocess, "run", side_effect=AssertionError("real process")))
            stack.enter_context(patch.object(E2E.subprocess, "Popen", side_effect=AssertionError("real terminal")))
            stack.enter_context(patch.object(E2E.urllib.request, "urlopen", side_effect=AssertionError("real network")))
            if download_fixture:
                asset = {"name": "WinMerge-x64-PerUser-Setup.exe", "browser_download_url": "https://fixture.invalid/setup.exe",
                         "digest": "sha256:" + "a" * 64}
                response = io.BytesIO(json.dumps({"assets": [asset]}).encode())
                stack.enter_context(patch.object(E2E.urllib.request, "urlopen", return_value=response))
                run.remote.ps_json.return_value = {"hash": "b" * 64 if download_fixture == "checksum" else "a" * 64,
                                                   "signature": "Invalid" if download_fixture == "signature" else "Valid"}
                if download_fixture == "network":
                    run.remote.ps_json.side_effect = E2E.StepFailed("download interrupted")
            stack.enter_context(patch("sys.argv", ["e2e", "--host", "fixture"] + (["--keep-going"] if keep_going else [])))
            with redirect_stdout(io.StringIO()), self.assertRaises(SystemExit) as exit_result:
                E2E.main()
            self.assertEqual(exit_result.exception.code, 1 if failed else 0)
            return calls

    def test_failed_prerequisites_block_dependent_actions_with_keep_going(self):
        expected = {
            "preflight": ["preflight"],
            "deploy": ["preflight", "deploy"],
            "download": ["preflight", "deploy", "download", "smoke"],
            "install": ["preflight", "deploy", "download", "install", "smoke"],
            "launch": ["preflight", "deploy", "download", "install", "launch", "smoke"],
            "uninstall": ["preflight", "deploy", "download", "install", "launch", "uninstall", "smoke"],
        }
        for failed, wanted in expected.items():
            with self.subTest(failed=failed):
                self.assertEqual(self.run_candidate(failed), wanted)

    def test_read_only_failure_keeps_independent_analyze_and_smoke(self):
        self.assertEqual(self.run_candidate("history")[-3:], ["history", "analyze", "smoke"])

    def test_default_stops_after_first_failure(self):
        self.assertEqual(self.run_candidate("download", keep_going=False), ["preflight", "deploy", "download"])

    def test_failed_transfer_checksum_and_signature_block_installation(self):
        for failure in ("network", "checksum", "signature"):
            with self.subTest(failure=failure):
                self.assertEqual(self.run_candidate("download", download_fixture=failure),
                                 ["preflight", "deploy", "download", "smoke"])

    def test_success_keeps_the_full_flow(self):
        self.assertEqual(self.run_candidate(), ["preflight", "deploy", "download", "install", "launch", "uninstall", "history", "analyze", "smoke"])


class DeploymentTests(unittest.TestCase):
    def deploy_fixture(self, *, unpacked=True, mkdir_code=0, version_code=0, version_text="Mole 1.36.0", build_failure=None):
        with tempfile.TemporaryDirectory() as tmp, ExitStack() as stack:
            root = Path(tmp)
            (root / "source.txt").write_text("dirty working source")
            run = object.__new__(E2E.Run)
            commit = "1" * 40
            run.info = {"goarch": "amd64", "work": "fixture", "mole": "fixture/mole.ps1", "commit": commit}
            run.remote = Mock()
            run.remote.ps.side_effect = [
                subprocess.CompletedProcess([], mkdir_code, "", "mkdir failed"),
                subprocess.CompletedProcess([], version_code, version_text, "version failed"),
            ]
            run.remote.ps_json.return_value = unpacked
            refs, builds, uploads = [], [], []

            def process(argv, **kwargs):
                if argv[:2] == ["git", "archive"]:
                    refs.append(argv[-1])
                    with zipfile.ZipFile(argv[argv.index("-o") + 1], "w") as archive:
                        archive.writestr("mole/source.txt", "committed source")
                        archive.writestr("mole/mole.ps1", "committed script")
                elif argv[:2] == ["go", "build"]:
                    source = (Path(kwargs["cwd"]) / "source.txt").read_text()
                    builds.append((source, kwargs["env"].get("GOWORK")))
                    if argv[-1] == build_failure:
                        return subprocess.CompletedProcess(argv, 1, "", "build failed")
                    Path(argv[argv.index("-o") + 1]).write_text(source)
                else:
                    self.fail(f"unexpected process: {argv}")
                return subprocess.CompletedProcess(argv, 0, "", "")

            def put(local, _remote):
                with zipfile.ZipFile(local) as archive:
                    uploads.append({name: archive.read(name).decode() for name in (
                        "mole/mole.ps1", "mole/bin/analyze.exe", "mole/bin/status.exe")})

            run.remote.put.side_effect = put
            stack.enter_context(patch.object(E2E, "ROOT", root))
            stack.enter_context(patch.object(E2E.subprocess, "run", side_effect=process))
            error = None
            try:
                E2E.deploy(run)
            except E2E.StepFailed as exc:
                error = exc
            return refs, builds, uploads, run.remote, error

    def test_archive_uses_the_preflight_commit_despite_head_changes(self):
        refs, _, _, _, error = self.deploy_fixture()
        self.assertIsNone(error)
        self.assertEqual(refs, ["1" * 40])

    def test_binaries_and_scripts_share_the_archive_despite_dirty_workspace(self):
        _, builds, uploads, _, error = self.deploy_fixture()
        self.assertIsNone(error)
        self.assertEqual(builds, [("committed source", "off")] * 2)
        self.assertEqual(uploads, [{"mole/mole.ps1": "committed script",
                                   "mole/bin/analyze.exe": "committed source",
                                   "mole/bin/status.exe": "committed source"}])

    def test_failed_deployment_does_not_report_success(self):
        for failure in ({"unpacked": False}, {"mkdir_code": 1}, {"version_code": 1}, {"version_text": ""}):
            with self.subTest(failure=failure):
                _, _, _, remote, error = self.deploy_fixture(**failure)
                self.assertIsNotNone(error)
                if "mkdir_code" in failure:
                    remote.put.assert_not_called()

    def test_either_failed_native_build_prevents_upload(self):
        for tool in ("analyze", "status"):
            with self.subTest(tool=tool):
                _, _, uploads, remote, error = self.deploy_fixture(build_failure=f"./cmd/{tool}/")
                self.assertIsNotNone(error)
                self.assertEqual(uploads, [])
                remote.ps.assert_not_called()


if __name__ == "__main__":
    unittest.main()
