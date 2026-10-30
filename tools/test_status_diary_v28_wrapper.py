"""Offline packaging guards. This does not execute Windows PowerShell."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class WrapperTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ps = (ROOT / 'build_status_diary_english_v28.ps1').read_text()
        cls.rust = (ROOT / 'patches/status_diary_v28.rs').read_text()

    def test_embedded_source_is_exact(self):
        self.assertIn("$Rust = @'\n" + self.rust + "\n'@", self.ps)
        self.assertEqual(self.ps.count("$Rust = @'"), 1)
        self.assertEqual(self.ps.count("\n'@"), 1)

    def test_production_and_packet_identities_agree(self):
        for constant, ps_variable in [('MASTER_HASH', 'ExpectedMasterHash'), ('SOURCE_HASH', 'ExpectedSourceHash'), ('PACKET_HASH', 'ExpectedPacketHash')]:
            value = re.search(r'const ' + constant + r':&str="([a-f0-9]{64})"', self.rust)[1]
            self.assertIn('$' + ps_variable + ' = "' + value + '"', self.ps)
        self.assertIn('const MASTER_HASH:&str="3f5b7630fd3115804c892e75c37213fbfff148b28ed657d0424ecba0614dc34e"', self.rust)

    def test_preflight_precedes_writes(self):
        self.assertLess(self.ps.index('if ($CheckOnly)'), self.ps.index('[IO.Directory]::CreateDirectory($WorkRoot)'))
        self.assertIn('[IO.FileMode]::CreateNew', self.ps)
        self.assertIn('[IO.File]::WriteAllBytes($RustPath,$OriginalRust)', self.ps)
        self.assertIn('if (Test-Path -LiteralPath $WorkRoot)', self.ps)

    def test_private_packet_is_runtime_input(self):
        self.assertIn('Read-PrivatePacket', self.ps)
        self.assertIn('GetEntry("status_diary_v28.json")', self.ps)
        self.assertIn('HashBytes $Data', self.ps)
        self.assertIn('fs::read(&packet_path)', self.rust)
        self.assertNotIn('english_prose_draft', self.rust)
        self.assertNotIn('fitted_text":"', self.rust)

    def test_environment_and_report_checks(self):
        for name in ('MASTER', 'SOURCE', 'OUTPUT', 'FONT', 'PACKET', 'QA_DUMP'):
            self.assertIn('"JG2_V28_' + name + '"', self.ps)
        self.assertIn('$env:JG2_V28_QA_DUMP = $null', self.ps)
        self.assertIn('[Environment]::SetEnvironmentVariable($Name,$SavedEnvironment[$Name],"Process")', self.ps)
        self.assertIn('$Report.translated_coordinates + $Report.custom_coordinates_preserved', self.ps)
        for stale in ('JG2_V27_', 'PACKET_REPLACE', 'pool/club dialogue', 'club-baseball-palette'):
            self.assertNotIn(stale, self.ps)


if __name__ == '__main__':
    unittest.main()
