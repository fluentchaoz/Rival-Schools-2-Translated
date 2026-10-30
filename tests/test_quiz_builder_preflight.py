"""Regression checks for the v17h PowerShell wrapper; no game data required.

Run with Python 3 and PowerShell on PATH, or set POWERSHELL to its executable.
Synthetic copies substitute fixture hashes only; the production file is untouched.
The fake cargo command deliberately fails to exercise exact source restoration.
"""

import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
BUILDER = REPO / "build_quiz_fixed_ui_english_v17h.ps1"
MASTER_HASH = "67ad4b9d628d0141493a42b456dfd8ce7631d3e9fdd7b2d387ceb84362127a51"
SOURCE_HASH = "0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e"
POWERSHELL = os.environ.get("POWERSHELL") or shutil.which("pwsh") or shutil.which("powershell")


@unittest.skipUnless(POWERSHELL, "PowerShell is required")
class QuizBuilderPreflight(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="quiz-preflight-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.upstream = self.root / "upstream"
        self.rust = self.upstream / "src/diary_scene/runtime_bundle_build.rs"
        self.rust.parent.mkdir(parents=True)
        self.original = b"\xef\xbb\xbf// Existing source: \xc3\xa9\r\n// Preserve BOM and CRLF.\r\n"
        self.rust.write_bytes(self.original)
        self.master = self.root / "master.bin"
        self.source = self.root / "source.bin"
        self.master.write_bytes(b"synthetic translated master")
        self.source.write_bytes(b"synthetic original source")
        self.work = self.root / "candidate"
        fake_bin = self.root / "fake-bin"
        fake_bin.mkdir()
        cargo = fake_bin / ("cargo.cmd" if os.name == "nt" else "cargo")
        cargo.write_text("@echo off\r\necho simulated compiler failure 1>&2\r\nexit /b 42\r\n"
                         if os.name == "nt" else "#!/bin/sh\nprintf 'simulated compiler failure\\n' >&2\nexit 42\n")
        cargo.chmod(0o755)
        self.env = dict(os.environ, PATH=str(fake_bin) + os.pathsep + os.environ.get("PATH", ""))
        self.env.pop("CARGO_TARGET_DIR", None)

    def fixture_script(self, low_disk=False):
        text = BUILDER.read_text(encoding="utf-8-sig")
        text = text.replace(MASTER_HASH, hashlib.sha256(self.master.read_bytes()).hexdigest())
        text = text.replace(SOURCE_HASH, hashlib.sha256(self.source.read_bytes()).hexdigest())
        if low_disk:
            probe = "$Available = [long]$Drive.AvailableFreeSpace"
            self.assertIn(probe, text)
            text = text.replace(probe, "$Available = [long]0")
        script = self.root / "fixture-builder.ps1"
        script.write_text(text, encoding="utf-8-sig")
        return script

    def run_builder(self, script, *extra):
        return subprocess.run(
            [POWERSHELL, "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
             "-File", str(script), "-MasterBin", str(self.master), "-SourceBin", str(self.source),
             "-UpstreamRoot", str(self.upstream), "-WorkRoot", str(self.work), *extra],
            env=self.env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=60,
        )

    def assert_untouched(self):
        self.assertEqual(self.rust.read_bytes(), self.original)
        self.assertEqual(self.master.read_bytes(), b"synthetic translated master")
        self.assertEqual(self.source.read_bytes(), b"synthetic original source")

    def test_production_rejects_wrong_master_before_writing(self):
        result = self.run_builder(BUILDER)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("v16 master hash mismatch", result.stdout)
        self.assertFalse(self.work.exists())
        self.assert_untouched()

    def test_check_only_performs_no_writes(self):
        result = self.run_builder(self.fixture_script(), "-CheckOnly")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("Preflight passed", result.stdout)
        self.assertFalse(self.work.exists())
        self.assert_untouched()

    def test_low_disk_stops_before_source_or_output_writes(self):
        result = self.run_builder(self.fixture_script(low_disk=True))
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("Not enough free space", result.stdout)
        self.assertFalse(self.work.exists())
        self.assert_untouched()

    def test_existing_output_is_preserved(self):
        output = self.work / "build/justice-gakuen2-quiz-fixed-ui-v17h.bin"
        output.parent.mkdir(parents=True)
        output.write_bytes(b"keep this previous build")
        result = self.run_builder(self.fixture_script())
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("Output already exists", result.stdout)
        self.assertEqual(output.read_bytes(), b"keep this previous build")
        self.assert_untouched()

    def test_compiler_failure_restores_exact_source_and_keeps_backup(self):
        result = self.run_builder(self.fixture_script())
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("exit code 42", result.stdout)
        self.assertEqual((self.work / "runtime_bundle_build.pre-v17h.rs.bak").read_bytes(), self.original)
        self.assertIn("simulated compiler failure", (self.work / "build-v17h.log").read_text())
        self.assert_untouched()


if __name__ == "__main__":
    unittest.main(verbosity=2)
