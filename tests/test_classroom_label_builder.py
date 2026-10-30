"""v19 wrapper boundary tests; synthetic inputs contain no game data.

Set POWERSHELL to pwsh when it is not on PATH. Fixture copies substitute only
expected image identities/length and, for one test, the available-space probe.
"""
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
BUILDER = REPO / "build_classroom_label_english_v19.ps1"
PS = os.environ.get("POWERSHELL") or shutil.which("pwsh")
MASTER = "d720ea2ae3c2c1c52981b0536642b836ec8e2151c6e94b658abdd1a49e094068"
SOURCE = "0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e"


@unittest.skipUnless(PS, "PowerShell required")
class ClassroomBuilderTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="jg2-classroom-builder-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.upstream = self.root / "upstream with spaces"
        self.rust = self.upstream / "src/diary_scene/runtime_bundle_build.rs"
        self.rust.parent.mkdir(parents=True)
        self.original = b"\xef\xbb\xbf// Source with BOM, CRLF and \xc3\xa9.\r\n"
        self.rust.write_bytes(self.original)
        (self.upstream / "Cargo.toml").write_text("# fixture")
        self.master = self.root / "master.bin"
        self.source = self.root / "source.bin"
        self.master.write_bytes(b"m" * 32)
        self.source.write_bytes(b"s" * 32)
        self.font = self.root / "fixture-font.ttf"
        self.font.write_bytes(b"font fixture; no renderer runs in wrapper tests")
        self.work = self.root / "candidate"
        fake = self.root / "fake-bin"
        fake.mkdir()
        self.cargo = fake / ("cargo.cmd" if os.name == "nt" else "cargo")
        self.set_cargo_exit(42)
        self.env = dict(os.environ, PATH=str(fake) + os.pathsep + os.environ.get("PATH", ""))
        self.env.pop("CARGO_TARGET_DIR", None)

    def set_cargo_exit(self, code):
        self.cargo.write_text(f"@echo off\r\necho simulated cargo run 1>&2\r\nexit /b {code}\r\n" if os.name == "nt"
                              else f"#!/bin/sh\nprintf 'simulated cargo run\\n' >&2\nexit {code}\n")
        self.cargo.chmod(0o755)

    def fixture(self, low_disk=False):
        text = BUILDER.read_text(encoding="utf-8-sig")
        text = text.replace(MASTER, hashlib.sha256(self.master.read_bytes()).hexdigest())
        text = text.replace(SOURCE, hashlib.sha256(self.source.read_bytes()).hexdigest())
        text = text.replace("[long]663216960", "[long]32")
        if low_disk:
            self.assertIn("$Available = [long]$Drive.AvailableFreeSpace", text)
            text = text.replace("$Available = [long]$Drive.AvailableFreeSpace", "$Available = [long]0")
        path = self.root / "fixture.ps1"
        path.write_text(text)
        return path

    def run_builder(self, script, *flags, auto=False):
        result = subprocess.run(
            [PS, "-NoProfile", "-File", str(script), "-RecoveryRoot", str(self.root),
             "-UpstreamRoot", str(self.upstream),
             *([] if auto else ["-MasterBin", str(self.master)]), "-FontPath", str(self.font),
             "-SourceBin", str(self.source), "-WorkRoot", str(self.work), *flags],
            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            env=self.env, timeout=60,
        )
        self.assertEqual(self.rust.read_bytes(), self.original, result.stdout)
        self.assertEqual(self.master.read_bytes(), b"m" * 32)
        self.assertEqual(self.source.read_bytes(), b"s" * 32)
        return result

    def test_wrong_master_before_any_write(self):
        result = self.run_builder(BUILDER)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("v18 master hash mismatch", result.stdout)
        self.assertFalse(self.work.exists())

    def test_check_only_does_not_create_candidate(self):
        result = self.run_builder(self.fixture(), "-CheckOnly")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("Preflight passed", result.stdout)
        self.assertFalse(self.work.exists())

    def test_insufficient_space_before_any_write(self):
        result = self.run_builder(self.fixture(low_disk=True))
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("Not enough free space", result.stdout)
        self.assertFalse(self.work.exists())

    def test_existing_work_is_preserved(self):
        self.work.mkdir()
        keep = self.work / "previous-build.txt"
        keep.write_bytes(b"keep previous build")
        result = self.run_builder(self.fixture())
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("Output already exists", result.stdout)
        self.assertEqual(keep.read_bytes(), b"keep previous build")
        self.assertEqual(list(self.work.iterdir()), [keep])

    def test_compile_failure_restores_source_and_retains_backup(self):
        result = self.run_builder(self.fixture())
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("exit code 42", result.stdout)
        self.assertEqual((self.work / "runtime_bundle_build.pre-v19.rs.bak").read_bytes(), self.original)
        self.assertIn("simulated cargo run", (self.work / "build-v19.log").read_text())

    def test_missing_success_outputs_are_not_reported_as_built(self):
        self.set_cargo_exit(0)
        result = self.run_builder(self.fixture())
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("did not produce required output", result.stdout)
        self.assertNotIn("CANDIDATE BUILT", result.stdout)

    def test_default_discovery_selects_exact_v18(self):
        valid = self.root / "candidates/stat-results-v18-good/build/justice-gakuen2-stat-results-v18.bin"
        wrong = self.root / "candidates/stat-results-v18-wrong/build/justice-gakuen2-stat-results-v18.bin"
        for path in (valid, wrong):
            path.parent.mkdir(parents=True)
        valid.write_bytes(self.master.read_bytes())
        wrong.write_bytes(b"unrelated candidate")
        result = self.run_builder(self.fixture(), "-CheckOnly", auto=True)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("v18 input: " + str(valid), result.stdout)
        self.assertFalse(self.work.exists())
        self.assertEqual(wrong.read_bytes(), b"unrelated candidate")

    def test_missing_font_before_any_write(self):
        self.font.unlink()
        result = self.run_builder(self.fixture())
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("Missing required file", result.stdout)
        self.assertFalse(self.work.exists())


if __name__ == "__main__":
    unittest.main()
