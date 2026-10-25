"""Synthetic tests of recovery boundaries. No game disc or font is included.

POWERSHELL=/path/to/pwsh python3 -m unittest discover -s tests -p test_recovery_runner.py
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
PS = os.environ.get("POWERSHELL") or shutil.which("pwsh")


def sha(data):
    return hashlib.sha256(data).hexdigest()


def quote(value):
    return "'" + str(value).replace("'", "''") + "'"


@unittest.skipUnless(PS, "PowerShell is required")
class RecoveryTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="jg2-recovery-test-")
        self.root = Path(self.tmp.name)
        self.kit = self.root / "kit"
        self.kit.mkdir()
        self.build = self.root / "build"
        self.source = self.root / "source.bin"
        self.source.write_bytes(b"original")
        self.font = self.root / "arial.fixture"
        self.font.write_bytes(b"font fixture")
        runner = (REPO / "recovery/rebuild_quiz_from_original.ps1").read_text(encoding="utf-8-sig")
        # Only the platform/host/font adapters differ. Identity, ownership,
        # free-space, checkpoint and stage execution logic are production code.
        runner = runner.replace('if ($env:OS -ne "Windows_NT") { throw "Run this recovery kit in Windows PowerShell on the PC with the original disc and Arial font." }', '')
        runner = runner.replace('$Shell = Join-Path $env:SystemRoot "System32/WindowsPowerShell/v1.0/powershell.exe"', '$Shell = ' + quote(PS))
        runner = runner.replace('$Font = "C:\\Windows\\Fonts\\arial.ttf"', '$Font = ' + quote(self.font))
        self.runner = self.kit / "rebuild_quiz_from_original.ps1"
        self.runner.write_text(runner)
        # First attempt leaves an injected source edit and exits; the second
        # attempt proves that resume restored the pristine pre-step source.
        stage = r'''
$ErrorActionPreference = "Stop"
$src = Join-Path $PSScriptRoot "upstream/src/sample.rs"
$attempt = Join-Path $PSScriptRoot "attempt"
if (-not (Test-Path $attempt)) {
    [IO.File]::WriteAllText($attempt, "first")
    [IO.File]::WriteAllText($src, "interrupted injection")
    exit 7
}
if ([IO.File]::ReadAllText($src) -ne "pristine") { throw "checkpoint was not restored" }
$out = Join-Path $PSScriptRoot "upstream/work/result.bin"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $out) | Out-Null
[IO.File]::WriteAllText($out, "rebuilt!")
[IO.File]::WriteAllText([IO.Path]::ChangeExtension($out, ".cue"), "fixture cue")
'''
        (self.kit / "stage.ps1").write_text(stage)
        self.plan = {
            "schema": 1, "upstream_commit": "fixture-head", "rust_toolchain": "fixture-toolchain",
            "source_sha256": sha(self.source.read_bytes()), "source_bytes": 8,
            "stages": [{"script": "stage.ps1", "output": "work/result.bin", "sha256": sha(b"rebuilt!"), "arguments": ""}],
            "files": {p.name: sha(p.read_bytes()) for p in self.kit.iterdir()},
        }
        (self.kit / "recovery-plan.json").write_text(json.dumps(self.plan))

    def tearDown(self):
        self.tmp.cleanup()

    def run_runner(self, *flags):
        # Mock only external prerequisite commands, never file/hash/checkpoint
        # functions. The real child PowerShell executes the synthetic builder.
        text = r'''
function git { $global:LASTEXITCODE = 0; "fixture-head" }
function cargo { $global:LASTEXITCODE = 0 }
function rustc { $global:LASTEXITCODE = 0 }
function rustup { $global:LASTEXITCODE = 0 }
'''
        text += "& " + quote(self.runner) + " -SourceBin " + quote(self.source) + " -BuildRoot " + quote(self.build)
        text += " " + " ".join(flags)
        env = dict(os.environ, POWERSHELL_TELEMETRY_OPTOUT="1", POWERSHELL_UPDATECHECK="Off")
        return subprocess.run([PS, "-NoProfile", "-Command", text], env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=60)

    def initialize_resume(self):
        project = self.build / "project"
        project.mkdir(parents=True)
        for name in self.plan["files"]:
            shutil.copyfile(self.kit / name, project / name)
        src = project / "upstream/src"
        src.mkdir(parents=True)
        (src / "sample.rs").write_text("pristine")
        (self.build / "logs").mkdir()
        (self.build / "checkpoints").mkdir()
        self.state = {
            "schema": 1, "build_root": str(self.build), "plan_sha256": sha((self.kit / "recovery-plan.json").read_bytes()),
            "font_sha256": sha(self.font.read_bytes()), "prepared": True, "completed": 0,
            "source_stamp": sha(("/sample.rs " + sha(b"pristine")).encode()),
            "active_step": "", "checkpoint": "", "checkpoint_sha256": "", "v17h_bin": "", "v17h_sha256": "",
        }
        self.write_state()

    def write_state(self):
        (self.build / "recovery-state.json").write_text(json.dumps(self.state))

    def test_check_only_is_read_only(self):
        result = self.run_runner("-CheckOnly")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("Preflight passed", result.stdout)
        self.assertFalse(self.build.exists())

    def test_wrong_original_does_not_create_build(self):
        self.source.write_bytes(b"wrong")
        result = self.run_runner("-CheckOnly")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("SHA-256 mismatch", result.stdout)
        self.assertFalse(self.build.exists())

    def test_unrelated_existing_folder_preserved(self):
        self.build.mkdir()
        keep = self.build / "keep.txt"
        keep.write_text("user work")
        result = self.run_runner("-Resume", "-CheckOnly")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("not an initialized recovery folder", result.stdout)
        self.assertEqual(keep.read_text(), "user work")

    def test_modified_kit_rejected(self):
        (self.kit / "stage.ps1").write_text("throw 'modified'")
        result = self.run_runner("-CheckOnly")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("SHA-256 mismatch", result.stdout)
        self.assertFalse(self.build.exists())

    def test_modified_source_blocks_resume(self):
        self.initialize_resume()
        source = self.build / "project/upstream/src/sample.rs"
        source.write_text("user edits")
        result = self.run_runner("-Resume", "-CheckOnly")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("Generated source changed", result.stdout)
        self.assertEqual(source.read_text(), "user edits")

    def test_bad_completed_image_blocks_resume(self):
        self.initialize_resume()
        output = self.build / "project/upstream/work/result.bin"
        output.parent.mkdir()
        output.write_bytes(b"wrong output")
        self.state["completed"] = 1
        self.write_state()
        result = self.run_runner("-Resume", "-CheckOnly")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("SHA-256 mismatch", result.stdout)
        self.assertEqual(output.read_bytes(), b"wrong output")

    def test_failed_step_resumes_from_source_checkpoint(self):
        self.initialize_resume()
        first = self.run_runner("-Resume", "-StopAtV16")
        self.assertNotEqual(first.returncode, 0, first.stdout)
        self.assertIn("exit code 7", first.stdout)
        source = self.build / "project/upstream/src/sample.rs"
        self.assertEqual(source.read_text(), "interrupted injection")
        failed_state = json.loads((self.build / "recovery-state.json").read_text())
        self.assertEqual(failed_state["completed"], 0)
        self.assertEqual(failed_state["active_step"], "stage-01")
        second = self.run_runner("-Resume", "-StopAtV16")
        self.assertEqual(second.returncode, 0, second.stdout)
        self.assertIn("V16 RESTORED", second.stdout)
        self.assertEqual(source.read_text(), "pristine")
        state = json.loads((self.build / "recovery-state.json").read_text())
        self.assertEqual(state["completed"], 1)
        self.assertEqual(state["active_step"], "")
        self.assertEqual(self.source.read_bytes(), b"original")


if __name__ == "__main__":
    unittest.main()
