"""v43: English INFIRMARY background label on exact v42."""
import argparse,json,struct,shutil,collections
from pathlib import Path
from practice_disc_v30 import Disc,decode,compress,file_sha,sha,regenerate
from native_resource_catalog import audit_catalog,require_catalog
from build_exam_dance_v35 import assert_claims
from build_practice_v30 import tim,rgb_image
from compress_tail_v36 import compress_tail
from infirmary_label_v43 import patch_label
MASTER='50d1bdaaa65dd48433bdace7841a853517978d4c668666af7a305e1593f53282'
ROOT=Path(__file__).resolve().parents[1]
def run(a):
 if a.master.stat().st_size!=663216960 or file_sha(a.master)!=MASTER:raise ValueError('Expected exact v42 BIN')
 if a.output.exists():raise ValueError('Choose new output folder')
 source=Disc(a.master);require_catalog(source);a.output.mkdir(parents=True);(a.output/'previews').mkdir();replacements={};reports=[];skipped=[]
 labels=json.loads((ROOT/'assets/infirmary_labels_v43.json').read_text());grouped=collections.defaultdict(lambda:collections.defaultdict(list))
 for e in labels:grouped[e['path']][e['member']].append(e)
 def archive(name,patches):
  stored=source.record(name);out=bytearray(stored);members=[]
  for i,patch in patches.items():
   off,n=struct.unpack_from('<II',stored,i*8);original=stored[off:off+n];before=decode(original)[0]
   for variant in range(4):
    after,claims=patch(before,variant);assert_claims(before,after,claims)
    try:encoded,pr=compress_tail(after,original,a.tail_accelerator);break
    except ValueError as exc:
     if not any(x in str(exc)for x in ('no reusable source prefix','tail exceeds','tail final')):raise
     try:encoded,pr=compress(after,original,a.accelerator);break
     except ValueError:continue
   else:skipped.append(dict(path=name,member=i,reason='no spare compressed space'));print('SKIPPED',name,i,flush=True);continue
   pr=dict(pr,label_variant=variant)
   out[off:off+n]=encoded;members.append(dict(member=i,claims=claims,compression=pr,input_sha256=sha(original),output_sha256=sha(encoded)))
   if name=='DAT2/MGBGM04.BZZ':rgb_image(tim(after,0)).save(a.output/'previews'/f'label-{i}.png')
  if out[:0x800]!=stored[:0x800]:raise ValueError('archive table changed')
  replacements[name]=bytes(out);reports.append(dict(path=name,members=members));print(name,'archive ready',flush=True)
 for name,ms in grouped.items():
  def checked(b,entries,variant):
   for e in entries:
    t=tim(b,e['tim_offset'])
    if sha(t['pixels'][220:244,:128].tobytes())!=e['pixel_sha256']:raise ValueError('infirmary label preimage')
   return patch_label(b,a.font,[e['tim_offset']for e in entries],variant)
  archive(name,{i:lambda b,v,es=es:checked(b,es,v)for i,es in ms.items()})
 bindings=audit_catalog(source,replacements)['mismatches'];exe=bytearray(source.record('SLPS_021.20'))
 for row in bindings:
  if row['path']not in replacements:raise ValueError('unexpected loader mismatch')
  p=row['signature_offset'];exe[p:p+4]=replacements[row['path']][:4]
 if bindings:replacements['SLPS_021.20']=bytes(exe)
 require_catalog(source,replacements);target=a.output/'justice-gakuen2-infirmary-label-v43.bin';shutil.copyfile(a.master,target);changed={}
 with target.open('r+b')as f:
  for rec,new in replacements.items():
   lba,size=source.records[rec]
   if len(new)!=size:raise ValueError('ISO extent changed')
   for off in range(0,size,2048):
    sector=lba+off//2048;f.seek(sector*2352);raw=f.read(2352);s=bytearray(raw);part=new[off:off+2048];s[24:24+len(part)]=part
    if s!=raw:
     if regenerate(raw)!=raw:raise ValueError('source sector checksum')
     s=regenerate(s);f.seek(sector*2352);f.write(s);changed[sector]=s
 verify=Disc(target)
 for rec in source.records:
  if verify.record(rec)!=replacements.get(rec,source.record(rec)):raise ValueError('record readback '+rec)
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
 report=dict(kind='Infirmary label v43',master_sha256=MASTER,output_sha256=file_sha(target),disc_bytes=target.stat().st_size,records=reports,catalog_rebindings=bindings,catalog_audit=cat,changed_sector_count=len(changed),untargeted_records_preserved=len(source.records)-len(replacements),checksums_and_sector_ownership_passed=True,native_gameplay='pending',label_copies=len(labels),skipped_copies=skipped,patched_copies=len(labels)-len(skipped),font_sha256=file_sha(a.font))
 (a.output/'infirmary-label-v43-report.json').write_text(json.dumps(report,indent=2)+'\n');print('V43 COMPLETE',report['output_sha256'],'changed sectors',len(changed),flush=True)
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('master',type=Path);p.add_argument('output',type=Path);p.add_argument('--font',type=Path,required=True);p.add_argument('--accelerator',required=True);p.add_argument('--tail-accelerator',required=True);run(p.parse_args())
