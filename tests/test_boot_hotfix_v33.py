"""Regression for the v32 loader mismatch and narrowly scoped v33 repair."""
import os,sys,tempfile,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from practice_disc_v30 import Disc,regenerate
from native_resource_catalog import audit_catalog,require_catalog,catalog_key
from build_boot_hotfix_v33 import build
class BootHotfix(unittest.TestCase):
 @classmethod
 def setUpClass(cls):cls.old=Disc(os.environ['JG2_V33_V32']);cls.new=Disc(os.environ['JG2_V33_OUTPUT'])
 def test_failed_v32_is_rejected_by_loader_contract_gate(self):
  result=audit_catalog(self.old);self.assertEqual(result['bound_entries'],876);self.assertEqual([r['path']for r in result['mismatches']],['DAT2/TITLE.BIZ'])
  with self.assertRaisesRegex(ValueError,'catalog signature'):require_catalog(self.old)
 def test_all_876_bound_catalog_entries_match_after_hotfix(self):
  r=require_catalog(self.new);self.assertEqual(r,dict(bound_entries=876,mismatches=[]))
 def test_only_the_single_declared_data_byte_changes(self):
  a=self.old.record('SLPS_021.20');b=self.new.record('SLPS_021.20');self.assertEqual([i for i,(x,y)in enumerate(zip(a,b))if x!=y],[0x770dd]);self.assertEqual(b[0x770dc:0x770e0],self.new.record('DAT2/TITLE.BIZ')[:4]);self.assertEqual(a[0x770d4:0x770dc],catalog_key(*self.old.records['DAT2/TITLE.BIZ']))
 def test_all_946_other_records_stay_exact(self):
  for name in self.old.records:
   if name!='SLPS_021.20':self.assertEqual(self.old.record(name),self.new.record(name),name)
 def test_changed_sector_has_valid_checksum(self):
  with self.new.path.open('rb')as f:f.seek(263688*2352);s=f.read(2352)
  self.assertEqual(regenerate(s),s)
 def test_wrong_input_is_rejected_without_output(self):
  with tempfile.TemporaryDirectory()as d:
   root=Path(d);p=root/'wrong.bin';p.write_bytes(b'bad');out=root/'new.bin'
   with self.assertRaisesRegex(ValueError,'exact failed v32'):build(p,out)
   self.assertFalse(out.exists());self.assertFalse(out.with_suffix('.cue').exists())
if __name__=='__main__':unittest.main()
