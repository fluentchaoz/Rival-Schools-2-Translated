"""Layout/ownership checks against actual v31/v32 discs and the original anchors."""
import os,sys,tempfile,unittest,struct
from pathlib import Path
from types import SimpleNamespace
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from practice_disc_v30 import Disc,decode
from build_practice_v30 import tim
from build_menu_fixes_v31 import RETRIES,RECTS,assert_owned
from build_title_exam_v32 import patch_points,patch_retry_alignment,patch_title,patch_exam_member,unpack_exam,build
class Layouts(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.source=Disc(os.environ['JG2_V32_MASTER']);cls.result=Disc(os.environ['JG2_V32_OUTPUT']);cls.original=Disc(os.environ['JG2_V32_V29']);cls.font=Path(os.environ['JG2_V32_FONT']);cls.art=Path(os.environ['JG2_V32_TITLE'])
 def test_points_ink_survives_conservative_native_crop(self):
  before=decode(self.source.record('DAT2/MENU.BIZ'))[0];after,claim=patch_points(before,self.font);assert_owned(before,after,claim);p=tim(after,0x22800)['pixels'][224:248,544:624]
  self.assertTrue(np.any(p[:16]==15));self.assertFalse(np.any(p[16:]));self.assertEqual(claim['text'],'CURRENT POINTS')
 def test_replay_centers_match_original_japanese_in_all_three_families(self):
  for name,at,x,y,pal in RETRIES:
   before=decode(self.source.record(name))[0];after,claim=patch_retry_alignment(before,at,x,y,self.font);assert_owned(before,after,claim);old=tim(decode(self.original.record(name))[0],at)['pixels'][y:y+60,x:x+112];new=tim(after,at)['pixels'][y:y+60,x:x+112]
   for a,b,w,h in RECTS[1:]:
    centers=[]
    for p in [old,new]:
     yy,xx=np.where(np.isin(p[b:b+h,a:a+w],[8,9,10,11,12]));centers.append(((xx.min()+xx.max())/2+a,(yy.min()+yy.max())/2+b))
    self.assertEqual(*centers)
   self.assertTrue(np.array_equal(tim(before,at)['palette'],tim(after,at)['palette']))
 def test_title_audio_headers_palette_and_footer_are_exact(self):
  old=decode(self.source.record('DAT2/TITLE.BIZ'))[0];new=decode(self.result.record('DAT2/TITLE.BIZ'))[0];t=tim(old,0x6000);a=tim(new,0x6000)
  self.assertEqual(old[:t['offset']],new[:a['offset']]);self.assertTrue(np.array_equal(t['pixels'][400:],a['pixels'][400:]));self.assertFalse(np.array_equal(t['pixels'][:384],a['pixels'][:384]))
 def test_exam_table_and_other_32_members_unchanged(self):
  old=self.source.record('DAT2/TESTMJ.TIZ');new=self.result.record('DAT2/TESTMJ.TIZ');self.assertEqual(old[:34*8],new[:34*8])
  for i in range(33):
   off,size=struct.unpack_from('<II',old,i*8)
   if i!=30:self.assertEqual(old[off:off+size],new[off:off+size])
   else:
    a=decode(old[off:off+size])[0];b=decode(new[off:off+size])[0];self.assertTrue(np.array_equal(tim(a,0)['palette'],tim(b,0)['palette']));self.assertFalse(np.array_equal(unpack_exam(a),unpack_exam(b)))
 def test_exam_only_declared_tiles_and_header_change(self):
  archive=self.source.record('DAT2/TESTMJ.TIZ');off,size=struct.unpack_from('<II',archive,30*8);before=decode(archive[off:off+size])[0];after,claim=patch_exam_member(before,self.font);assert_owned(before,after,claim);self.assertEqual(claim['source_tiles'],list(range(8,54)));self.assertEqual(claim['row_tile_counts'],[9,7,13,9,8])
 def test_prior_practice_batch_and_sprint_label_are_retained(self):
  for name in ['DAT2/MGCOCK.TIZ']+[f'DAT2/MINITTL{k}.BIZ'for k in '0123456789ABC']:self.assertEqual(self.source.record(name),self.result.record(name),name)
 def test_wrong_input_fails_before_output_creation(self):
  with tempfile.TemporaryDirectory()as d:
   root=Path(d);p=root/'bad.bin';p.write_bytes(b'wrong');out=root/'new'
   with self.assertRaisesRegex(ValueError,'exact v31'):build(SimpleNamespace(master=p,output=out,font=self.font,title_image=self.art,accelerator=None))
   self.assertFalse(out.exists())
if __name__=='__main__':unittest.main()
