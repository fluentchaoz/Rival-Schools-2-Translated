"""Build approved loading card, shared pause menus, Guts and rooftop event on exact v36."""
import argparse,json,struct,shutil,collections
from pathlib import Path
from practice_disc_v30 import Disc,decode,compress,file_sha,sha,regenerate
from native_resource_catalog import audit_catalog,require_catalog
from build_exam_dance_v35 import assert_claims
from build_practice_v30 import tim,rgb_image
from compress_tail_v36 import compress_tail
from practice_roof_v37 import *
MASTER='9885ee49e0404d43218b36e7b40b7308a9b7300274e6984f0aa3a260cdba95f1'
ROOT=Path(__file__).resolve().parents[1]
def run(a):
 if a.master.stat().st_size!=663216960 or file_sha(a.master)!=MASTER:raise ValueError('Expected exact v36 BIN')
 if a.output.exists():raise ValueError('Choose new output folder')
 source=Disc(a.master);require_catalog(source);a.output.mkdir(parents=True);(a.output/'previews').mkdir();replacements={};reports=[]
 def regular(name,patch):
  stored=source.record(name);before=decode(stored)[0];after,claims=patch(before);assert_claims(before,after,claims);encoded,pr=compress(after,stored,a.accelerator);replacements[name]=encoded
  reports.append(dict(path=name,claims=claims,compression=pr,input_sha256=sha(stored),output_sha256=sha(encoded)));print(name,'ready',flush=True)
 regular('DAT2/CEFT5.BIZ',lambda b:patch_guts(b,a.font));regular('DAT2/OVER.TIZ',lambda b:patch_pause_texture(b,a.font))
 pause=[]
 for name in source.records:
  if not(name.startswith('DAT1/')or name=='SLPS_021.20'):continue
  before=source.record(name);after,hits=patch_pause_overlay(before)
  if hits:replacements[name]=after;pause.append(name);reports.append(dict(path=name,pause_descriptors=hits,executable_instructions_unchanged=True));print(name,'pause descriptors ready',flush=True)
 if len(pause)!=11:raise ValueError('pause consumer inventory '+str(pause))
 loading=json.loads((ROOT/'assets/loading_kyosuke_v37.json').read_text());roof=json.loads((ROOT/'assets/rooftop_v37.json').read_text());locations=json.loads((ROOT/'assets/roof_locations_v37.json').read_text())
 def archive(name,patches):
  stored=source.record(name);out=bytearray(stored);members=[]
  for i,patch in patches.items():
   off,n=struct.unpack_from('<II',stored,i*8);original=stored[off:off+n];before=decode(original)[0];after,claims=patch(before);assert_claims(before,after,claims)
   try:encoded,pr=compress_tail(after,original,a.tail_accelerator)
   except ValueError as exc:
    # Loading artwork changes from the first pixel: there may be no full source
    # page before the edit. Rebuild it using the original complete stream limits.
    if not any(x in str(exc)for x in ('no reusable source prefix','tail exceeds','tail final')):raise
    encoded,pr=compress(after,original,a.accelerator)
   out[off:off+n]=encoded;members.append(dict(member=i,claims=claims,compression=pr,input_sha256=sha(original),output_sha256=sha(encoded)))
   for j,c in enumerate(claims):
    if name=='DAT2/ALOAD32.BIZ':rgb_image(tim(after,int(c['tim_offset'],16))).save(a.output/'previews'/f'loading-{i}-{j}.png')
  if out[:0x800]!=stored[:0x800]:raise ValueError('archive table changed')
  replacements[name]=bytes(out);reports.append(dict(path=name,members=members));print(name,'archive ready',flush=True)
 archive('DAT2/ALOAD32.BIZ',{32:lambda b:patch_loading(b,loading)})
 grouped=collections.defaultdict(lambda:collections.defaultdict(list))
 for e in locations:grouped[e['path']][e['member']].append(e)
 for name,ms in grouped.items():
  def patch_location_checked(b,entries):
   for e in entries:
    t=tim(b,e['tim_offset'])
    if sha(t['pixels'][220:244,:128].tobytes())!=e['pixel_sha256']:raise ValueError('rooftop label preimage')
   return patch_location(b,[e['tim_offset']for e in entries],a.font)
  archive(name,{i:lambda b,es=es:patch_location_checked(b,es)for i,es in ms.items()})
 name=roof['path'];stored=source.record(name);before=decode(stored)[0];reference=decode(source.record('DAT2/MGC01.BIZ'))[0]
 for gap in range(0,512,4):
  after,proof=patch_roof(before,reference,roof,gap)
  try:encoded,pr=compress_tail(after,stored,a.tail_accelerator);break
  except ValueError as exc:
   if 'tail exceeds'not in str(exc)and 'tail final'not in str(exc):raise
 else:raise ValueError('Rooftop does not fit original compressed slot')
 replacements[name]=encoded;reports.append(dict(path=name,rooftop=proof,compression=pr,input_sha256=sha(stored),output_sha256=sha(encoded)));print(name,'106 rooftop coordinates ready',flush=True)
 # Catalog signature rebindings are data-only; leave code and resource extents intact.
 bindings=audit_catalog(source,replacements)['mismatches'];exe=bytearray(replacements.get('SLPS_021.20',source.record('SLPS_021.20')))
 for row in bindings:
  if row['path']not in replacements:raise ValueError('unexpected loader mismatch')
  p=row['signature_offset'];exe[p:p+4]=replacements[row['path']][:4]
 if bindings:replacements['SLPS_021.20']=bytes(exe)
 require_catalog(source,replacements);target=a.output/'justice-gakuen2-practice-roof-v37.bin';shutil.copyfile(a.master,target);changed={}
 with target.open('r+b')as f:
  for name,new in replacements.items():
   lba,size=source.records[name]
   if len(new)!=size:raise ValueError('ISO extent changed')
   for off in range(0,size,2048):
    sector=lba+off//2048;f.seek(sector*2352);raw=f.read(2352);s=bytearray(raw);part=new[off:off+2048];s[24:24+len(part)]=part
    if s!=raw:
     if regenerate(raw)!=raw:raise ValueError('source sector checksum')
     s=regenerate(s);f.seek(sector*2352);f.write(s);changed[sector]=s
 verify=Disc(target)
 for name in source.records:
  if verify.record(name)!=replacements.get(name,source.record(name)):raise ValueError('record readback '+name)
 actual=[]
 with a.master.open('rb')as left,target.open('rb')as right:
  lba=0
  while True:
   x=left.read(2352*1024);y=right.read(2352*1024)
   if len(x)!=len(y):raise ValueError('disc size changed')
   if not x:break
   for i in range(0,len(x),2352):
    if x[i:i+2352]!=y[i:i+2352]:
     n=lba+i//2352;actual.append(n)
     if n not in changed or regenerate(y[i:i+2352])!=y[i:i+2352]:raise ValueError('sector ownership/checksum')
   lba+=len(x)//2352
 if actual!=sorted(changed):raise ValueError('sector accounting')
 cat=require_catalog(verify)
 if file_sha(a.master)!=MASTER:raise ValueError('input modified')
 target.with_suffix('.cue').write_bytes(f'FILE "{target.name}" BINARY\r\n  TRACK 01 MODE2/2352\r\n    INDEX 01 00:00:00\r\n'.encode())
 report=dict(kind='Practice and rooftop v37',master_sha256=MASTER,output_sha256=file_sha(target),disc_bytes=target.stat().st_size,font_sha256=file_sha(a.font),records=reports,catalog_rebindings=bindings,catalog_audit=cat,changed_sector_count=len(changed),untargeted_records_preserved=len(source.records)-len(replacements),checksums_and_sector_ownership_passed=True,native_gameplay='pending',pause_consumers=pause,roof_dialogue_coordinates=106,roof_event_entries=53,roof_label_copies=len(locations),roof_background_archives=len(grouped),other_loading_cards_unchanged=49,scope_limits='Complete reviewed Edge/Daigo rooftop encounter only; other rooftop events and unrelated Japanese loading cards remain follow-up targets.')
 (a.output/'practice-roof-v37-report.json').write_text(json.dumps(report,indent=2)+'\n');print('V37 COMPLETE',report['output_sha256'],flush=True)
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('master',type=Path);p.add_argument('output',type=Path);p.add_argument('--font',type=Path,required=True);p.add_argument('--accelerator',required=True);p.add_argument('--tail-accelerator',required=True);run(p.parse_args())
