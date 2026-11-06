"""Meaningful codec parity, preservation and preflight checks for practice v30."""
import ctypes,os,random,struct,sys,tempfile,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from practice_disc_v30 import compress_python,decode,regenerate
from build_practice_v30 import tim,patch_labels,patch_landing,rules_panel,GAMES,run
from types import SimpleNamespace
class Practice(unittest.TestCase):
 def test_encoder_c_python_parity_and_roundtrip(self):
  path=os.environ.get('JG2_V30_ENCODER')
  if not path:self.skipTest('optional compiled encoder path not supplied')
  lib=ctypes.CDLL(path);lib.practice_compress.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_int];lib.practice_compress.restype=ctypes.c_int
  rng=random.Random(30)
  for words in [[0]*9000,[rng.randrange(64)for _ in range(12000)],([1,2,3,4]*1800)]:
   data=struct.pack('<'+'H'*len(words),*words)
   for prefix in [0,123]:
    expected=compress_python(data,128,400,prefix,3000);out=ctypes.create_string_buffer(len(data)*2+65536);inp=ctypes.create_string_buffer(data)
    n=lib.practice_compress(inp,len(words),out,len(out),128,400,prefix,3000);self.assertGreater(n,0);self.assertEqual(out.raw[:n],expected)
    actual,p=decode(expected);self.assertEqual(actual,data);self.assertEqual(p['crossing_blocks'],0);self.assertLessEqual(p['max_page'],3000)
 def test_literal_only_stream_rejects_unrepresentable_page_schedule(self):
  # An all-unique word stream cannot supply the four copy tokens needed to tile
  # a 2048-byte native input page. Refuse it instead of emitting unsafe blocks.
  with self.assertRaisesRegex(ValueError,'page schedule'):
   compress_python(struct.pack('<'+'H'*1500,*range(1500)),128,400,0,3000)
 def test_wrong_master_fails_before_output_creation(self):
  with tempfile.TemporaryDirectory()as d:
   root=Path(d);master=root/'fake.bin';master.write_bytes(b'wrong');out=root/'output'
   with self.assertRaisesRegex(ValueError,'expected recovered v29'):run(SimpleNamespace(master=master,output=out,font=root/'missing.ttf',accelerator=None))
   self.assertFalse(out.exists());self.assertEqual(master.read_bytes(),b'wrong')
 def test_actual_assets_preserve_palettes_and_readable_ownership(self):
  path=os.environ.get('JG2_V30_AUDIT')
  if not path:self.skipTest('private source fixture not supplied')
  font=Path(os.environ['JG2_V30_FONT']);root=Path(path)
  for key,g in GAMES.items():
   before=(root/f'MINITTL{key}.BIZ.decoded').read_bytes();after=bytearray(before)
   patch_labels(after,font);patch_landing(after,g,font)
   for page in range(len(g['rules'])):rules_panel(after,g,page,font)
   for at in [0,0x18800,0x55000]+([0x91800]if len(g['rules'])>1 else []):
    a=tim(before,at);b=tim(after,at);self.assertEqual(a['palette'].tolist(),b['palette'].tolist());self.assertEqual(before[at:a['offset']],after[at:b['offset']])
   # Header crop stays binary with the native face and outline palette indices.
   pix=tim(after,0)['pixels']
   self.assertTrue(set(pix[48:72,512:720].ravel()).issubset({0,1,14}))
 def test_mode2_checksum_regeneration_stability(self):
  source=os.environ.get('JG2_V30_MASTER')
  if not source:self.skipTest('private disc not supplied')
  with open(source,'rb')as f:
   for sector in [16,617,263450]:
    f.seek(sector*2352);raw=f.read(2352);self.assertEqual(regenerate(raw),raw)
    changed=bytearray(raw);changed[100]^=1;fixed=regenerate(changed);self.assertNotEqual(fixed,raw);self.assertEqual(regenerate(fixed),fixed)
if __name__=='__main__':unittest.main()
