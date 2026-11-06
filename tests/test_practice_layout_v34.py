"""Integration checks against private v33/v34 fixtures, supplied through env vars."""
import os,sys,struct,unittest
from pathlib import Path
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from practice_disc_v30 import Disc,decode,file_sha
from build_practice_v30 import tim
from build_menu_fixes_v31 import RETRIES
from native_resource_catalog import require_catalog
from build_practice_layout_v34 import MASTER

@unittest.skipUnless(os.getenv('JG2_V33_BIN') and os.getenv('JG2_V34_BIN'),'private fixture paths required')
class NativeGraphicsContracts(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.old=Disc(os.environ['JG2_V33_BIN']);cls.new=Disc(os.environ['JG2_V34_BIN'])
  if file_sha(cls.old.path)!=MASTER:raise ValueError('wrong v33 fixture')
 def pixels(self,disc,name,at=0):return tim(decode(disc.record(name))[0],at)['pixels']
 def test_all_native_catalog_signatures_match(self):
  a=require_catalog(self.new);self.assertEqual(a['bound_entries'],876)
 def test_boot_title_and_exam_intro_and_all_replay_panels_retained(self):
  for name in ['DAT2/TITLE.BIZ','DAT2/TESTMJ.TIZ','DAT2/MGCOCK.TIZ']:self.assertEqual(self.old.record(name),self.new.record(name))
  for name,at,x,y,p in RETRIES:
   self.assertTrue(np.array_equal(self.pixels(self.old,name,at)[y:y+60,x:x+112],self.pixels(self.new,name,at)[y:y+60,x:x+112]))
 def test_popup_cells_follow_real_consumers_and_leave_right_padding(self):
  overlay=self.old.record('DAT1/MGAME06.BIN')
  expected=[(192,216,20,20),(200,192,40,20),(160,192,40,20),(160,168,80,20),(216,216,20,20)]
  actual=[struct.unpack_from('<4H',overlay,0x1a8+i*12+4)for i in range(5)]
  self.assertEqual(actual,expected)
  for key in '0123456789ABC':
   p=self.pixels(self.new,f'DAT2/MINITTL{key}.BIZ')
   for x,y,w,h in expected+[(144,96,40,20)]:
    cell=p[y:y+h,x:x+w];self.assertGreater(int((cell==14).sum()),20)
    self.assertFalse(np.any(cell[:,-1]));self.assertFalse(np.any(cell[-1]))
 def test_points_ink_uses_safe_native_rows_and_solid_lettering(self):
  p=self.pixels(self.new,'DAT2/MENU.BIZ',0x22800)[224:248,544:624]
  self.assertFalse(np.any(p[16:]));self.assertEqual(set(np.unique(p)),{0,1})
  self.assertGreater(int((p==1).sum()),300)
 def test_exam_decimals_colon_portraits_and_palettes_unchanged(self):
  for key in [4,6]:
   name=f'DAT2/CEFT{key}.BIZ';a=decode(self.old.record(name))[0];b=decode(self.new.record(name))[0];ta=tim(a,0x10800);tb=tim(b,0x10800)
   self.assertTrue(np.array_equal(ta['palette'],tb['palette']))
   mask=np.zeros(ta['pixels'].shape,dtype=bool);mask[:96,256:416]=True;mask[96:128,184:208]=True
   self.assertTrue(np.array_equal(ta['pixels'][~mask],tb['pixels'][~mask]))
   self.assertFalse(np.any(tb['pixels'][96:128,200:208]))
 def test_all_unclaimed_iso_records_unchanged(self):
  claimed={f'DAT2/MINITTL{k}.BIZ'for k in '0123456789ABC'}|{'DAT2/MENU.BIZ','DAT2/SPRINT.BIZ','DAT2/CEFT5.BIZ','DAT2/CEFT4.BIZ','DAT2/CEFT6.BIZ','SLPS_021.20'}
  self.assertEqual(self.old.records,self.new.records)
  for name in self.old.records:
   if name not in claimed:self.assertEqual(self.old.record(name),self.new.record(name),name)
if __name__=='__main__':unittest.main()
