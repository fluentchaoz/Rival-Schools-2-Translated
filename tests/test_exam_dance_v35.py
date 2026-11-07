"""Private-fixture integration checks for the v35 graphics batch."""
import os,sys,struct,unittest
from pathlib import Path
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from practice_disc_v30 import Disc,decode,file_sha
from build_practice_v30 import tim
from build_exam_dance_v35 import MASTER,NAMES,selector_plan
from native_resource_catalog import require_catalog

@unittest.skipUnless(os.getenv('JG2_V34_BIN') and os.getenv('JG2_V35_BIN'),'private fixtures required')
class GraphicsContracts(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.old=Disc(os.environ['JG2_V34_BIN']);cls.new=Disc(os.environ['JG2_V35_BIN'])
  if file_sha(cls.old.path)!=MASTER:raise ValueError('wrong v34 master')
 def decoded(self,d,n):return decode(d.record(n))[0]
 def pix(self,d,n,at=0):return tim(self.decoded(d,n),at)['pixels']
 def test_catalog_and_iso_geometry(self):
  self.assertEqual(self.old.records,self.new.records);self.assertEqual(require_catalog(self.new)['bound_entries'],876)
 def test_all_unclaimed_records_are_exact(self):
  allowed={'DAT2/CEFT5.BIZ','DAT2/DANCE.BIZ','DAT1/MGAME06.BIN','DAT1/MGAME07.BIN','DAT2/SIKEN20.BIZ','DAT2/SIKEN2.BIZ','DAT2/SIKEN1.BIZ','DAT2/SIKEN10.BIZ','DAT2/SIKENKK.BIZ','SLPS_021.20'}|{f'DAT2/MINITTL{k}.BIZ'for k in '9ABC'}
  for n in self.old.records:
   if n not in allowed:self.assertEqual(self.old.record(n),self.new.record(n),n)
 def test_boot_title_points_exam_intro_sprint_and_prior_atlases_retained(self):
  for n in ['TITLE','MENU','SPRINT','CEFT4','CEFT6']+[f'MINITTL{k}'for k in '012345678']:
   path=f'DAT2/{n}.BIZ';self.assertEqual(self.old.record(path),self.new.record(path),path)
  self.assertEqual(self.old.record('DAT2/TESTMJ.TIZ'),self.new.record('DAT2/TESTMJ.TIZ'))
 def test_selector_tables_retain_order_code_and_nonoverlapping_name_cells(self):
  plan=selector_plan(Path('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'));seen=set()
  for start,count in plan:
   self.assertLessEqual(start%12+count,12)
   for i in range(start,start+count):self.assertNotIn(i,seen);seen.add(i);self.assertLess(i,60)
  for n,base in [('DAT1/MGAME06.BIN',0x2b0),('DAT1/MGAME07.BIN',0x280)]:
   a=self.old.record(n);b=self.new.record(n);allowed=set()
   for i,((_,s,c),(ns,nc))in enumerate(zip(NAMES,plan)):
    off=base+i*4;self.assertEqual(a[off:off+4],bytes([1,s,c,0]));self.assertEqual(b[off:off+4],bytes([1,ns,nc,0]));allowed|={off+1,off+2}
   self.assertTrue(all(x==y or i in allowed for i,(x,y)in enumerate(zip(a,b))))
  for k in '9ABC':
   n=f'DAT2/MINITTL{k}.BIZ';self.assertEqual(self.decoded(self.old,n)[:0x91800],self.decoded(self.new,n)[:0x91800])
   a=self.pix(self.old,n,0x91800);b=self.pix(self.new,n,0x91800);self.assertTrue(np.array_equal(a[180:200],b[180:200]))
 def test_existing_english_dance_captions_and_replay_unchanged(self):
  a=self.decoded(self.old,'DAT2/DANCE.BIZ');b=self.decoded(self.new,'DAT2/DANCE.BIZ');ta=tim(a,0);tb=tim(b,0);mask=np.zeros(ta['pixels'].shape,dtype=bool);mask[:96,512:768]=True
  self.assertTrue(np.array_equal(ta['pixels'][~mask],tb['pixels'][~mask]));self.assertTrue(np.array_equal(ta['palette'],tb['palette']))
  for y in range(0,96,24):self.assertGreater(np.count_nonzero(tb['pixels'][y:y+24,512:768]),30)
 def test_ball_number_space_border_scoring_digits_and_aim_gauges_preserved(self):
  a=self.pix(self.old,'DAT2/CEFT5.BIZ',0x10800);b=self.pix(self.new,'DAT2/CEFT5.BIZ',0x10800)
  for y,x,h,w in [(72,54,16,50),(86,0,2,128),(0,0,56,240),(0,512,256,256),(180,656,60,112)]:self.assertTrue(np.array_equal(a[y:y+h,x:x+w],b[y:y+h,x:x+w]))
 def test_result_archive_headers_palettes_and_dynamic_grade_alphabet_preserved(self):
  a=self.old.record('DAT2/SIKEN20.BIZ');b=self.new.record('DAT2/SIKEN20.BIZ');self.assertEqual(a[:0x800],b[:0x800])
  for i in range(2):
   off,n=struct.unpack_from('<II',a,i*8);da=decode(a[off:off+n])[0];db=decode(b[off:off+n])[0]
   for at in [0,0x8800,0x45000,0x58800]:self.assertTrue(np.array_equal(tim(da,at)['palette'],tim(db,at)['palette']))
   pa=tim(da,0)['pixels'];pb=tim(db,0)['pixels'];self.assertTrue(np.array_equal(pa[60:80,:144],pb[60:80,:144]));self.assertTrue(np.array_equal(pa[80:110,:144],pb[80:110,:144]))
 def test_only_three_term_title_members_and_lengths_change_within_slots(self):
  a=self.old.record('DAT2/SIKENKK.BIZ');b=self.new.record('DAT2/SIKENKK.BIZ')
  for i in range(33):
   ao,an=struct.unpack_from('<II',a,i*8);bo,bn=struct.unpack_from('<II',b,i*8);self.assertEqual(ao,bo);self.assertLessEqual(bn,0x800)
   if i<30:self.assertEqual(a[i*8:i*8+8],b[i*8:i*8+8]);self.assertEqual(a[ao:ao+0x800],b[bo:bo+0x800])
   else:
    da=decode(a[ao:ao+an])[0];db=decode(b[bo:bo+bn])[0];self.assertEqual(len(da),len(db));self.assertTrue(np.array_equal(tim(da,0)['palette'],tim(db,0)['palette']))
if __name__=='__main__':unittest.main()
