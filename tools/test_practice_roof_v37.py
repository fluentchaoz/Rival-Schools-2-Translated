"""Integration checks for exact v36/v37 private images; no native emulator claim."""
import argparse,json,struct,re
from pathlib import Path
import numpy as np
from practice_disc_v30 import *
from build_practice_v30 import tim
from build_exam_dance_v35 import assert_claims
from native_resource_catalog import require_catalog
from practice_roof_v37 import *
from build_practice_roof_v37 import MASTER,ROOT

def run(a):
 assert file_sha(a.master)==MASTER
 old=Disc(a.master);new=Disc(a.target);report=json.loads(a.report.read_text());checks=[]
 assert old.records==new.records and len(old.records)==947
 assert require_catalog(new)==dict(bound_entries=876,mismatches=[]);checks.append('947 ISO extents and 876 native catalog bindings preserved')
 changed={r['path']for r in report['records']}
 for name in old.records:
  if name not in changed:assert old.record(name)==new.record(name),name
 checks.append('all untargeted records, including v36 logos/Backup/exam backdrop, retained exactly')
 for name,patch in [('DAT2/CEFT5.BIZ',lambda b:patch_guts(b,a.font)),('DAT2/OVER.TIZ',lambda b:patch_pause_texture(b,a.font))]:
  before=decode(old.record(name))[0];after=decode(new.record(name))[0];expected,claims=patch(before);assert after==expected;assert_claims(before,after,claims)
 checks.append('Guts: only caption lettering changes; number space, strip borders and all other HUD pixels retained')
 checks.append('Pause font: only source-empty cells allocated; original Japanese/shared glyphs and palettes retained')
 for name in report['pause_consumers']:
  before=old.record(name);after=new.record(name);expected,hits=patch_pause_overlay(before)
  if name=='SLPS_021.20':
   expected=bytearray(expected)
   for binding in report['catalog_rebindings']:
    p=binding['signature_offset'];expected[p:p+4]=new.record(binding['path'])[:4]
  assert after==expected,name
  assert len(hits)==4
 checks.append('11 pause consumers: descriptor-only changes, 1P/2P digit selection and executable instructions retained')
 loading=json.loads((ROOT/'assets/loading_kyosuke_v37.json').read_text());src=old.record('DAT2/ALOAD32.BIZ');out=new.record('DAT2/ALOAD32.BIZ');assert src[:0x800]==out[:0x800]
 for i in range(50):
  off,n=struct.unpack_from('<II',src,i*8)
  if i!=32:assert src[off:off+n]==out[off:off+n]
  else:
   before=decode(src[off:off+n])[0];after=decode(out[off:off+n])[0];expected,claims=patch_loading(before,loading);assert after==expected;assert before[0x3c800:]==after[0x3c800:];assert_claims(before,after,claims)
 checks.append('Approved Kyosuke loading member installed; separate NOW LOADING sprite and 49 other members unchanged')
 locations=json.loads((ROOT/'assets/roof_locations_v37.json').read_text());grouped={}
 for e in locations:grouped.setdefault(e['path'],{}).setdefault(e['member'],[]).append(e['tim_offset'])
 for name,ms in grouped.items():
  src=old.record(name);out=new.record(name);assert src[:0x800]==out[:0x800];i=0
  while True:
   off,n=struct.unpack_from('<II',src,i*8)
   if not off and not n:break
   if i in ms:
    before=decode(src[off:off+n])[0];after=decode(out[off:off+n])[0];expected,claims=patch_location(before,ms[i],a.font);assert after==expected;assert_claims(before,after,claims)
   else:assert src[off:off+n]==out[off:off+n]
   i+=1
 checks.append('16 rooftop label copies across 11 archives: owned text strips only; backgrounds and other members retained')
 spec=json.loads((ROOT/'assets/rooftop_v37.json').read_text());src=old.record(spec['path']);out=new.record(spec['path']);before=decode(src)[0];after=decode(out)[0];row=next(r for r in report['records']if r['path']==spec['path']);expected,proof=patch_roof(before,decode(old.record('DAT2/MGC01.BIZ'))[0],spec,row['rooftop']['arena_gap']);assert after==expected
 bs=banks(before);actual=banks(after);reverse={v:k for k,v in proof['english_codes'].items()};targets={(e['selector'],e['index'])for e in spec['entries']}
 for e in spec['entries']:
  raw=actual[e['selector']][e['index']];text='';controls=[]
  for c,args in tokens(raw):
   if c==0x3001:break
   if c==0x3000:text+='\n'
   elif c>=0x2000:text+='{'+str(len(controls))+'}';controls.append([c,list(args)])
   else:text+=reverse[c]
  assert text==e['text'] and controls==e['controls']
  for line in text.split('\n'):
   expanded=re.sub(r'\{(\d+)\}',lambda m:'XXXXXX'if controls[int(m[1])][0]in(0x2003,0x2004)else'',line);assert len(expanded)<=20
  assert len(text.split('\n'))<=4
 for s,ms in bs.items():
  for i,m in enumerate(ms):
   if (s,i)not in targets:assert actual[s][i]==m
 assert before[:ARENA]==after[:ARENA]and before[LIMIT:]==after[LIMIT:]
 for i,rows in [(69,2),(86,3)]:
  for s in (0,1):assert len(actual[s][i])>0;assert len(next(e['text']for e in spec['entries']if e['selector']==s and e['index']==i).split('\n'))==rows
 checks.append('106 rooftop coordinates (53 per variant): English readback, 20x4 bounds, name/timing controls and choice rows preserved')
 checks.append('All other rooftop-provider payloads, every font pixel and all event script bytes retained')
 for r in report['records']:
  profiles=([r['compression']]if 'compression'in r else [m['compression']for m in r.get('members',[])])
  for proof in profiles:
   sp,rp=proof['source'],proof['rebuilt'];assert all(rp[k]<=sp[k]for k in ('max_match','max_block','max_page'));assert (rp['stream_bytes']-1)//2048==(sp['stream_bytes']-1)//2048
   assert rp['crossing_blocks']==proof.get('preserved_prefix_crossing_blocks',0)
 checks.append('All rebuilt streams retain original source slot/final page and decoder bounds; no new page crossings')
 result=dict(kind='Practice and rooftop v37 integration validation',passed=len(checks),failed=0,checks=checks,output_sha256=file_sha(a.target),native_gameplay='pending',powershell_execution='not executed; equivalent Python updater verification recorded separately')
 a.validation.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('master',type=Path);p.add_argument('target',type=Path);p.add_argument('report',type=Path);p.add_argument('validation',type=Path);p.add_argument('--font',type=Path,default=Path('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'));run(p.parse_args())
