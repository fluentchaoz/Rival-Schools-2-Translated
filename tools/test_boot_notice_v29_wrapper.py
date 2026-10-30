"""Offline packaging checks; does not execute Windows PowerShell."""
import re,unittest
from pathlib import Path
R=Path(__file__).resolve().parents[1]
class Wrapper(unittest.TestCase):
 def test_embedded_module_and_identities(self):
  ps=(R/'build_boot_notice_english_v29.ps1').read_text();rs=(R/'patches/boot_notice_v29.rs').read_text();self.assertIn("$Rust = @'\n"+rs+"\n'@",ps)
  for c,v in [('MASTER','ExpectedMasterHash'),('SOURCE','ExpectedSourceHash')]:self.assertIn('$'+v+' = "'+re.search(r'const '+c+r':&str="([a-f0-9]{64})"',rs)[1]+'"',ps)
 def test_backup_preflight_and_restoration(self):
  ps=(R/'build_boot_notice_english_v29.ps1').read_text();self.assertLess(ps.index('if ($CheckOnly)'),ps.index('[IO.Directory]::CreateDirectory($WorkRoot)'));self.assertIn('[IO.FileMode]::CreateNew',ps);self.assertIn('[IO.File]::WriteAllBytes($RustPath,$OriginalRust)',ps);self.assertIn('[Environment]::SetEnvironmentVariable',ps);self.assertNotIn('$FontPath',ps);self.assertNotIn('$Packet',ps)
 def test_production_scope(self):
  ps=(R/'build_boot_notice_english_v29.ps1').read_text();self.assertIn('$Report.messages -ne 2',ps);self.assertIn('$Report.record_copies -ne 4',ps);self.assertIn('status-diary-v28-*',ps);self.assertNotIn('JG2_V28_',ps);self.assertIn('boot-notice-v29-report.json',ps)
if __name__=='__main__':unittest.main()
