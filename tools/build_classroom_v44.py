"""v44: English classroom + ground scenes (MGM04 selectors 0/1, entries 0-66) on exact v43."""
import argparse,json,shutil
from pathlib import Path
from practice_disc_v30 import Disc,decode,compress,file_sha,sha,regenerate
from native_resource_catalog import audit_catalog,require_catalog
from compress_tail_v36 import compress_tail
from practice_roof_v37 import patch_roof
MASTER='1d294d44df7d7eff8f726a64110497d136e226c65762076b8940dde1cff25900'
ROOT=Path(__file__).resolve().parents[1]
def run(a):
 if a.master.stat().st_size!=663216960 or file_sha(a.master)!=MASTER:raise ValueError('Expected exact v43 BIN')
 if a.output.exists():raise ValueError('Choose new output folder')
 source=Disc(a.master);require_catalog(source);a.output.mkdir(parents=True);replacements={};reports=[]
 spec=json.loads((ROOT/'assets/classroom_v44.json').read_text());name=spec['path'];stored=source.record(name);before=decode(stored)[0];reference=decode(source.record('DAT2/MGC01.BIZ'))[0]
 for gap in range(0,2048,4):
  after,proof=patch_roof(before,reference,spec,gap)
  try:encoded,pr=compress_tail(after,stored,a.tail_accelerator);break
  except ValueError as exc:
   if 'tail exceeds'not in str(exc)and 'tail final'not in str(exc):raise
 else:raise ValueError('Classroom scenes do not fit original compressed slot')
 replacements[name]=encoded;reports.append(dict(path=name,infirmary=proof,compression=pr,input_sha256=sha(stored),output_sha256=sha(encoded)));print(name,len(spec['entries']),'infirmary coordinates ready',flush=True)
 bindings=audit_catalog(source,replacements)['mismatches'];exe=bytearray(source.record('SLPS_021.20'))
 for row in bindings:
  if row['path']not in replacements:raise ValueError('unexpected loader mismatch')
  p=row['signature_offset'];exe[p:p+4]=replacements[row['path']][:4]
 if bindings:replacements['SLPS_021.20']=bytes(exe)
 require_catalog(source,replacements);target=a.output/'justice-gakuen2-classroom-v44.bin';shutil.copyfile(a.master,target);changed={}
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
 report=dict(kind='Classroom and ground scenes v44',master_sha256=MASTER,output_sha256=file_sha(target),disc_bytes=target.stat().st_size,records=reports,catalog_rebindings=bindings,catalog_audit=cat,changed_sector_count=len(changed),untargeted_records_preserved=len(source.records)-len(replacements),checksums_and_sector_ownership_passed=True,native_gameplay='pending',entries_per_variant=len(spec['entries'])//2)
 (a.output/'classroom-v44-report.json').write_text(json.dumps(report,indent=2)+'\n');print('V44 COMPLETE',report['output_sha256'],'changed sectors',len(changed),flush=True)
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('master',type=Path);p.add_argument('output',type=Path);p.add_argument('--accelerator',required=True);p.add_argument('--tail-accelerator',required=True);run(p.parse_args())
