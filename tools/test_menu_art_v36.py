"""Integration ownership and semantics checks on a private exact-v35/v36 pair."""
import argparse,json,struct
from pathlib import Path
import numpy as np
from practice_disc_v30 import Disc,decode,file_sha,sha
from build_practice_v30 import tim
from menu_art_v36 import LOGOS,apply_logos,apply_record_labels,apply_backdrop,foreground_mask
from backup_text_v36 import banks,patch,TEXT,tokens,ARENA,LIMIT
from native_resource_catalog import require_catalog
from build_menu_art_v36 import MASTER

def run(a):
 assert file_sha(a.master)==MASTER
 old=Disc(a.master);new=Disc(a.output);report=json.loads(a.report.read_text());assets=json.loads(a.assets.read_text());checks=[]
 assert old.records==new.records and len(old.records)==947
 assert require_catalog(new)=={'bound_entries':876,'mismatches':[]};checks.append('947 ISO extents and 876 native loader bindings')
 changed={r['path']for r in report['records']}|({'SLPS_021.20'}if report['catalog_rebindings']else set())
 for name in old.records:
  if name not in changed:assert old.record(name)==new.record(name),name
 checks.append('all untargeted records exactly preserved')
 for name in dict.fromkeys(e[0]for e in LOGOS):
  before=decode(old.record(name))[0];after=decode(new.record(name))[0];assert after==apply_logos(before,name,assets)[0]
 checks.append('eight logo cells: exact assets, neighboring atlas pixels and palettes preserved')
 before=decode(old.record('DAT2/CEFT5.BIZ'))[0];after=decode(new.record('DAT2/CEFT5.BIZ'))[0];assert after==apply_record_labels(before,a.font)[0];checks.append('Service Ace caption ownership, values and gauges preserved')
 ref=decode(old.record('DAT2/MGC01.BIZ'))[0];count=0;allocations=0
 for name in sorted(old.records):
  if not(name.startswith('DAT2/MG')and name.endswith('.BIZ')and name!='DAT2/MGSTAFF1.BIZ'):continue
  before=decode(old.record(name))[0];after=decode(new.record(name))[0];gap=next(r['backup']['arena_gap']for r in report['records']if r['path']==name);expected,proof=patch(before,ref,a.font,gap);assert after==expected;bs=banks(before);ns=banks(after)
  for sel,ms in bs.items():
   for i,m in enumerate(ms):
    if sel!=5 or i not in set(TEXT)|{2}:assert ns[sel][i]==m
  # Read back every translated glyph sequence and line break from actual pointers.
  reverse={v:k for k,v in proof['glyph_codes'].items()}
  for i,text in TEXT.items():
   rendered=''.join('\n'if c==0x3000 else reverse[c]for c,args in tokens(ns[5][i])if c!=0x3001);assert rendered==text
  assert list(tokens(ns[5][2]))[:10]==list(tokens(bs[5][2]))[:10]
  spec=next(r['compression']for r in report['records']if r['path']==name);cut=spec['preserved_input_prefix_bytes'];assert old.record(name)[:cut]==new.record(name)[:cut]
  sp=decode(old.record(name),True);rp=decode(new.record(name),True);assert not rp['crossing_blocks'];assert all(rp[k]<=sp[k]for k in ('max_page','max_block','max_match'));assert (rp['stream_bytes']-1)//2048==(sp['stream_bytes']-1)//2048
  count+=1;allocations+=len(proof['new_glyph_slots'])
 assert count==78;checks.append('2262 Backup translations and 78 date-unit alphabets; untargeted payloads/control rows preserved')
 for month in ('04','06','08','09','11'):
  path=f'DAT2/MGG{month}.BZZ';src=old.record(path);out=new.record(path);assert src[:0x800]==out[:0x800]
  for i,s in enumerate('TOPGJ'):
   off,n=struct.unpack_from('<II',out,i*8);assert out[off:off+n]==new.record(f'DAT2/MGG{month}{s}.BIZ')
 checks.append('all 78 compressed prefixes retained, original page/block/match bounds and final input pages preserved')
 checks.append('25 bundled runtime mirrors match exactly; archive tables preserved')
 for i in range(2):
  src=old.record('DAT2/SIKEN20.BIZ');out=new.record('DAT2/SIKEN20.BIZ');off,n=struct.unpack_from('<II',src,i*8);before=decode(src[off:off+n])[0];after=decode(out[off:off+n])[0]
  assert after==apply_backdrop(before,i,assets)[0];t=tim(before,0x8800);nt=tim(after,0x8800);keep=foreground_mask(t,i);assert np.array_equal(t['pixels'][keep],nt['pixels'][keep]);assert before[:0x8800]==after[:0x8800] and before[0x45000:]==after[0x45000:]
 checks.append('both exam backdrop variants: original report/props, result atlas and PASS/FAIL stamps preserved')
 result=dict(kind='Menu art v36 integration validation',checks=checks,passed=len(checks),failed=0,new_glyph_allocations=allocations,output_sha256=file_sha(a.output),native_gameplay='pending',powershell_execution='not executed; equivalent Python updater separately verified')
 a.validation.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('master',type=Path);p.add_argument('output',type=Path);p.add_argument('report',type=Path);p.add_argument('validation',type=Path);p.add_argument('--assets',type=Path,default=Path(__file__).resolve().parents[1]/'assets/menu_art_v36.json');p.add_argument('--font',type=Path,default=Path('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'));run(p.parse_args())
