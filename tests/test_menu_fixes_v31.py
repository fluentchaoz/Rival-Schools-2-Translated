"""Native atlas ownership, palette roles, input guards and v30 retention."""
import os,sys,tempfile,unittest
from pathlib import Path
from types import SimpleNamespace
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from practice_disc_v30 import Disc,decode,sha
from build_practice_v30 import tim
from build_menu_fixes_v31 import patch_points,patch_retry,validate_retry,assert_owned,build,RETRIES,RECTS,glyph_mask
class MenuFixes(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.disc=Disc(os.environ['JG2_V31_MASTER']);cls.font=Path(os.environ['JG2_V31_FONT'])
 def test_points_has_exact_owned_cell_and_preserves_all_other_decoded_bytes(self):
  before=decode(self.disc.record('DAT2/MENU.BIZ'))[0];after,claim=patch_points(before,self.font);assert_owned(before,after,claim)
  a=tim(before,0x22800);b=tim(after,0x22800);self.assertTrue(np.array_equal(a['palette'],b['palette']));self.assertEqual(claim['rectangles'],[[544,224,80,24]])
  self.assertEqual([v['text']for v in claim['labels']],['CURRENT','POINTS']);self.assertNotEqual(before,after)
 def test_all_three_replay_families_preserve_frames_and_palette_roles(self):
  for name,at,x,y,pal in RETRIES:
   before=decode(self.disc.record(name))[0];after,claim=patch_retry(before,at,x,y,self.font);assert_owned(before,after,claim)
   a=tim(before,at);b=tim(after,at);self.assertTrue(np.array_equal(a['palette'],b['palette']));validate_retry(a['pixels'][y:y+60,x:x+112],b['pixels'][y:y+60,x:x+112])
   self.assertEqual([v['text']for v in claim['labels']],['PLAY AGAIN?','YES','NO'])
 def test_retry_validation_rejects_frame_and_wrong_answer_ramp(self):
  name,at,x,y,pal=RETRIES[0];before=decode(self.disc.record(name))[0];after,_=patch_retry(before,at,x,y,self.font)
  old=tim(before,at)['pixels'][y:y+60,x:x+112];new=tim(after,at)['pixels'][y:y+60,x:x+112].copy();new[0,0]^=1
  with self.assertRaisesRegex(ValueError,'frame'):validate_retry(old,new)
  new=tim(after,at)['pixels'][y:y+60,x:x+112].copy();new[35,20]=7
  with self.assertRaisesRegex(ValueError,'ramp'):validate_retry(old,new)
 def test_yes_no_letters_have_matching_height(self):
  heights=[]
  for text,box in [('YES',RECTS[1]),('NO',RECTS[2])]:
   x,y,w,h=box;mask=glyph_mask(text,w-2,h-2,self.font);yy,_=np.where(mask);heights.append(int(yy.max()-yy.min()+1))
  self.assertEqual(*heights)
 def test_wrong_master_rejected_before_output(self):
  with tempfile.TemporaryDirectory()as d:
   root=Path(d);master=root/'wrong.bin';master.write_bytes(b'wrong');out=root/'new'
   with self.assertRaisesRegex(ValueError,'exact v30'):build(SimpleNamespace(master=master,output=out,font=self.font,accelerator=None))
   self.assertFalse(out.exists())
 def test_full_sprint_strip_and_v30_practice_records_retained_in_actual_output(self):
  result=Disc(os.environ['JG2_V31_OUTPUT'])
  for name in ['DAT2/MGCOCK.TIZ']+[f'DAT2/MINITTL{k}.BIZ'for k in '0123456789ABC']:
   self.assertEqual(self.disc.record(name),result.record(name),name)
if __name__=='__main__':unittest.main()
