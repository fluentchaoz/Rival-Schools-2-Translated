"""Exercise the read-only probe with synthetic raw-sector ISO images, no game data.

POWERSHELL=/path/to/pwsh python -m unittest discover -s tests -p test_stat_result_probe.py
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import zipfile

REPO = Path(__file__).resolve().parents[1]
PS = os.environ.get("POWERSHELL") or shutil.which("pwsh")
SOURCE_HASH = "0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e"
MASTER_HASH = "2ff4d83cca04a22a217883ac9c29b3e2fa9c5c4796d9661db3f95d9acd92149a"
PATHS = ("DAT1/MGAME.BIN", "DAT2/MGK04.BIZ", "DAT2/MGCOCK.TIZ", "SLPS_021.20")


def digest(data):
    return hashlib.sha256(data).hexdigest()


def both(value, width):
    return value.to_bytes(width, "little") + value.to_bytes(width, "big")


def record(name, lba, size, flags=0):
    name = name if isinstance(name, bytes) else name.encode("ascii")
    raw = bytearray(33 + len(name) + (len(name) % 2 == 0))
    raw[0] = len(raw)
    raw[2:10] = both(lba, 4)
    raw[10:18] = both(size, 4)
    raw[25] = flags
    raw[28:32] = both(1, 2)
    raw[32] = len(name)
    raw[33:33 + len(name)] = name
    return raw


def fixture(patched=False):
    blocks = [bytearray(2048) for _ in range(80)]
    pvd = blocks[16]
    pvd[0:7] = b"\x01CD001\x01"
    pvd[128:132] = both(2048, 2)
    root = record(b"\0", 20, 4096, 2)
    pvd[156:156 + len(root)] = root
    dat1 = record("DAT1", 22, 2048, 2)
    dat2 = record("DAT2", 23, 4096, 2)
    blocks[20][:len(dat1 + dat2)] = dat1 + dat2
    payloads = {}
    lba = 26
    for index, path in enumerate(PATHS):
        size = (3001, 4097, 81, 5000)[index]
        data = bytes((j + index * 37 + int(patched)) % 256 for j in range(size))
        payloads[path] = data
        for offset in range(0, size, 2048):
            chunk = data[offset:offset + 2048]
            blocks[lba + offset // 2048][:len(chunk)] = chunk
        entry = record(path.split("/")[-1] + ";1", lba, size)
        # Root and DAT2 deliberately put later entries after sector padding.
        directory_lba = (22, 23, 24, 21)[index]
        blocks[directory_lba][:len(entry)] = entry
        lba += (size + 2047) // 2048
    sectors = []
    for index, block in enumerate(blocks):
        raw = bytearray(2352)
        raw[:12] = b"\x00" + b"\xff" * 10 + b"\x00"
        mode = 1 if index >= 26 and index % 2 else 2
        raw[15] = mode
        offset = 16
        if mode == 2:
            raw[16:24] = b"\x00\x00\x08\x00" * 2
            offset = 24
        raw[offset:offset + 2048] = block
        sectors.append(raw)
    return b"".join(sectors), payloads


@unittest.skipUnless(PS, "PowerShell is required")
class ProbeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="jg2-stat-probe-")
        self.root = Path(self.temp.name)
        self.recovery = self.root / "recovery with spaces"
        roms = self.recovery / "project/upstream/roms"
        roms.mkdir(parents=True)
        self.source = roms / "Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).bin"
        self.master = self.root / "working-v17h.bin"
        self.source_data, self.original_records = fixture()
        self.master_data, self.master_records = fixture(True)
        self.source.write_bytes(self.source_data)
        self.master.write_bytes(self.master_data)
        self.state = self.recovery / "recovery-state.json"
        self.state.write_text(json.dumps({"v17h_bin": str(self.master)}))
        self.marker = self.recovery / "project/source-must-stay.txt"
        self.marker.write_bytes(b"unchanged source\r\n")
        self.output = self.root / "private export.zip"
        self.script = self.root / "probe.ps1"
        self.bind_fixture()

    def tearDown(self):
        self.temp.cleanup()

    def bind_fixture(self):
        script = (REPO / "probe_stat_results_v18.ps1").read_text()
        # Only expected identities and image length differ in this temporary
        # test copy. The public script exposes no hash-bypass parameters.
        script = script.replace(SOURCE_HASH, digest(self.source.read_bytes()))
        script = script.replace(MASTER_HASH, digest(self.master.read_bytes()))
        script = script.replace("[long]663216960", f"[long]{len(self.source_data)}")
        self.script.write_text(script)

    def run_probe(self, *args):
        tracked = (self.source, self.master, self.state, self.marker)
        before = {p: p.read_bytes() for p in tracked}
        result = subprocess.run(
            [PS, "-NoProfile", "-File", str(self.script), "-RecoveryRoot", str(self.recovery),
             "-OutputZip", str(self.output), *args],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=45,
            env=dict(os.environ, POWERSHELL_TELEMETRY_OPTOUT="1", POWERSHELL_UPDATECHECK="Off"),
        )
        self.assertEqual(before, {p: p.read_bytes() for p in tracked}, result.stdout)
        return result

    def assert_no_output(self):
        self.assertFalse(self.output.exists())
        self.assertFalse(Path(str(self.output) + ".partial").exists())

    def test_exact_records_and_manifest_round_trip(self):
        result = self.run_probe()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("STAT-RESULT EXPORT COMPLETE", result.stdout)
        with zipfile.ZipFile(self.output) as archive:
            self.assertEqual(len(archive.namelist()), 9)
            report = json.loads(archive.read("manifest.json"))
            self.assertTrue(report["inputs_unchanged"])
            self.assertEqual(report["original_sha256"], digest(self.source_data))
            self.assertEqual(report["v17h_sha256"], digest(self.master_data))
            for role, records in (("original", self.original_records), ("v17h", self.master_records)):
                for path, data in records.items():
                    entry = role + "/" + path
                    self.assertEqual(archive.read(entry), data)
                    metadata = next(r for r in report["records"] if r["zip_entry"] == entry)
                    self.assertEqual(metadata["sha256"], digest(data))
                    self.assertEqual(metadata["bytes"], len(data))
        self.assertFalse(Path(str(self.output) + ".partial").exists())

    def test_check_only_creates_nothing(self):
        before = set(self.root.rglob("*"))
        result = self.run_probe("-CheckOnly")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("Preflight passed", result.stdout)
        self.assertEqual(set(self.root.rglob("*")), before)
        self.assert_no_output()

    def test_wrong_image_hash_rejected(self):
        for path in (self.source, self.master):
            with self.subTest(image=path.name):
                original = path.read_bytes()
                path.write_bytes(original[:-1] + bytes([original[-1] ^ 1]))
                result = self.run_probe()
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertIn("SHA-256 mismatch", result.stdout)
                self.assert_no_output()
                path.write_bytes(original)

    def test_existing_output_and_partial_are_preserved(self):
        for path in (self.output, Path(str(self.output) + ".partial")):
            with self.subTest(path=path.name):
                path.write_bytes(b"existing user work")
                result = self.run_probe()
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertIn("Output already exists", result.stdout)
                self.assertEqual(path.read_bytes(), b"existing user work")
                path.unlink()

    def test_missing_record_rejected_before_output(self):
        data = self.master_data.replace(b"MGCOCK.TIZ;1", b"XXCOCK.TIZ;1")
        self.master.write_bytes(data)
        self.bind_fixture()
        result = self.run_probe()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("ISO file not found", result.stdout)
        self.assert_no_output()

    def test_malformed_records_rejected_before_output(self):
        cases = (
            (22 * 2352 + 24 + 6, "dual-endian"),
            (26 * 2352 + 20, "XA subheaders differ"),
            (26 * 2352 + 1, "Invalid raw-sector sync"),
        )
        for offset, message in cases:
            with self.subTest(message=message):
                data = bytearray(self.master_data)
                data[offset] ^= 1
                self.master.write_bytes(data)
                self.bind_fixture()
                result = self.run_probe()
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertIn(message, result.stdout)
                self.assert_no_output()

    def test_out_of_bounds_extent_rejected_before_output(self):
        data = bytearray(self.master_data)
        offset = 22 * 2352 + 24 + 2
        data[offset:offset + 8] = both(1000, 4)
        self.master.write_bytes(data)
        self.bind_fixture()
        result = self.run_probe()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("outside the disc", result.stdout)
        self.assert_no_output()


if __name__ == "__main__":
    unittest.main()
