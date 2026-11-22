"""v47: dialogue tier 1 on exact v46 (largest prefix of each record that fits its arena/slot)."""
import argparse,json,shutil
from pathlib import Path
from practice_disc_v30 import Disc,decode,compress,file_sha,sha,regenerate
from native_resource_catalog import audit_catalog,require_catalog
from compress_tail_v36 import compress_tail
from shared_v46 import patch_shared
MASTER='7e5a778ec573f7fe0ce3225baa1a5e9dd41838be25a7345a99a9eb0ad5476d17'
ROOT=Path(__file__).resolve().parents[1]
def run(a):
 if a.master.stat().st_size!=663216960 or file_sha(a.master)!=MASTER:raise ValueError('Expected exact v46 BIN')
 if a.output.exists():raise ValueError('Choose new output folder')
 source=Disc(a.master);require_catalog(source);a.output.mkdir(parents=True);replacements={};reports=[];skipped=[]
 spec=json.loads((ROOT/'assets/dialogue_spec.json').read_text());reference=decode(source.record('DAT2/MGC01.BIZ'))[0]
 def attempt(name,stored,before,rec,k):
  one=dict(source_decoded_sha256=rec['source_decoded_sha256'],entries=rec['entries'][:k]);err=None
  try:after,proof=patch_shared(before,reference,one,0)
  except ValueError as exc:return None,str(exc)
  for gap in range(0,256,4):
   if gap:
    try:after,proof=patch_shared(before,reference,one,gap)
    except ValueError as exc:return None,str(exc)
   try:encoded,pr=compress_tail(after,stored,a.tail_accelerator);return (encoded,proof,pr),None
   except ValueError as exc:
    if 'tail exceeds'not in str(exc)and 'tail final'not in str(exc)and 'no reusable'not in str(exc):raise
    err=str(exc)
    try:encoded,pr=compress(after,stored,a.accelerator);return (encoded,proof,pr),None
    except ValueError as exc2:err=str(exc2)
  return None,err
 for name,rec in spec.items():
  stored=source.record(name);before=decode(stored)[0];n=len(rec['entries']);best=None;err=None
  res,err=attempt(name,stored,before,rec,n)
  if res:best=(n,res)
  else:
   lo,hi=0,n
   while lo<hi:
    mid=(lo+hi+1)//2;res,e2=attempt(name,stored,before,rec,mid)
    if res:lo=mid;best=(mid,res)
    else:hi=mid-1;err=e2
  done=best is not None
  if done:
   k,(encoded,proof,pr)=best;proof=dict(proof,entries_requested=n,entries_applied=k)
  if not done:skipped.append(dict(path=name,reason=err));print('SKIPPED',name,err,flush=True);continue
  replacements[name]=encoded;reports.append(dict(path=name,shared=proof,compression=pr,input_sha256=sha(stored),output_sha256=sha(encoded)));print(name,proof['entries_applied'],'of',proof['entries_requested'],'ready',flush=True)
 bindings=audit_catalog(source,replacements)['mismatches'];exe=bytearray(source.record('SLPS_021.20'))
 for row in bindings:
  if row['path']not in replacements:raise ValueError('unexpected loader mismatch')
  p=row['signature_offset'];exe[p:p+4]=replacements[row['path']][:4]
 if bindings:replacements['SLPS_021.20']=bytes(exe)
 require_catalog(source,replacements);target=a.output/'justice-gakuen2-dialogue-v84.bin';shutil.copyfile(a.master,target);changed={}
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
 report=dict(kind='Dialogue batch v84',master_sha256=MASTER,output_sha256=file_sha(target),disc_bytes=target.stat().st_size,records=reports,skipped=skipped,catalog_rebindings=bindings,catalog_audit=cat,changed_sector_count=len(changed),untargeted_records_preserved=len(source.records)-len(replacements),checksums_and_sector_ownership_passed=True,native_gameplay='pending')
 (a.output/'dialogue-v84-report.json').write_text(json.dumps(report,indent=2)+'\n');print('V49 COMPLETE',report['output_sha256'],'changed sectors',len(changed),'skipped',len(skipped),flush=True)
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('master',type=Path);p.add_argument('output',type=Path);p.add_argument('--accelerator',required=True);p.add_argument('--tail-accelerator',required=True);run(p.parse_args())
