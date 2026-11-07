"""Build the four v36 localization fixes against the exact v35 master."""
import argparse,json,struct,shutil
from pathlib import Path
from practice_disc_v30 import Disc,decode,compress,file_sha,sha,regenerate
from native_resource_catalog import audit_catalog,require_catalog
from build_exam_dance_v35 import assert_claims,archive
from menu_art_v36 import apply_logos,apply_record_labels,apply_backdrop
from backup_text_v36 import patch as patch_backup
from compress_tail_v36 import compress_tail
MASTER='c25207ba7f18dd73e56f5569d3df7dcdf3d9f92cc605dbbf17692b28a6e9cf8c'
def run(a):
 if a.master.stat().st_size!=663216960 or file_sha(a.master)!=MASTER:raise ValueError('Expected exact v35 BIN')
 if a.output.exists():raise ValueError('Choose new output folder')
 source=Disc(a.master);require_catalog(source);a.output.mkdir(parents=True);replacements={};reports=[]
 assets=json.loads(a.assets.read_text())
 if assets['kind']!='menu-art-v36':raise ValueError('art binding')
 def regular(name,patch):
  stored=source.record(name);before=decode(stored)[0];after,claims=patch(before);assert_claims(before,after,claims);encoded,pr=compress(after,stored,a.accelerator);replacements[name]=encoded
  reports.append(dict(path=name,claims=claims,compression=pr,input_sha256=sha(stored),output_sha256=sha(encoded)));print(name,'ready',flush=True)
 for name in dict.fromkeys(e['path']for e in assets['logos']):regular(name,lambda b,n=name:apply_logos(b,n,assets))
 regular('DAT2/CEFT5.BIZ',lambda b:apply_record_labels(b,a.font))
 stored=source.record('DAT2/SIKEN20.BIZ');new,rep=archive(stored,{i:lambda b,i=i:apply_backdrop(b,i,assets)for i in range(2)},a.accelerator);replacements['DAT2/SIKEN20.BIZ']=new;reports.append(dict(path='DAT2/SIKEN20.BIZ',members=rep));print('backdrop ready',flush=True)
 reference=decode(source.record('DAT2/MGC01.BIZ'))[0]
 names=sorted(n for n in source.records if n.startswith('DAT2/MG')and n.endswith('.BIZ')and n!='DAT2/MGSTAFF1.BIZ')
 if len(names)!=78:raise ValueError('runtime bank inventory changed')
 for name in names:
  stored=source.record(name);before=decode(stored)[0]
  # Search harmless pool alignment; retain every decoder bound and record extent.
  for gap in range(0,512,4):
   after,proof=patch_backup(before,reference,a.font,gap)
   try:encoded,pr=compress_tail(after,stored,a.tail_accelerator);break
   except ValueError as exc:
    if not any(t in str(exc)for t in ('compressed output exceeds','decoder profile exceeded','final input page','tail exceeds','tail final')):raise
  else:raise ValueError('No bounded dialogue encoding: '+name)
  replacements[name]=encoded
  reports.append(dict(path=name,backup=proof,compression=pr,input_sha256=sha(stored),output_sha256=sha(encoded)));print(name,'Backup ready',flush=True)
 for month in ('04','06','08','09','11'):
  name=f'DAT2/MGG{month}.BZZ';stored=source.record(name);out=bytearray(stored);members=[]
  for i,school in enumerate('TOPGJ'):
   off,size=struct.unpack_from('<II',stored,i*8);runtime=f'DAT2/MGG{month}{school}.BIZ'
   if stored[off:off+size]!=source.record(runtime):raise ValueError('bundle mirror binding '+runtime)
   if len(replacements[runtime])!=size:raise ValueError('bundle extent')
   out[off:off+size]=replacements[runtime];members.append(runtime)
  replacements[name]=bytes(out);reports.append(dict(path=name,exact_runtime_mirrors=members,table_unchanged=out[:0x800]==stored[:0x800]));print(name,'mirrors ready',flush=True)
 # Catalog signature rebindings are data-only; leave code and resource extents intact.
 bindings=audit_catalog(source,replacements)['mismatches'];exe=bytearray(source.record('SLPS_021.20'))
 for row in bindings:
  if row['path']not in replacements:raise ValueError('unexpected loader mismatch')
  p=row['signature_offset'];exe[p:p+4]=replacements[row['path']][:4]
 if bindings:replacements['SLPS_021.20']=bytes(exe)
 require_catalog(source,replacements);target=a.output/'justice-gakuen2-menu-art-v36.bin';shutil.copyfile(a.master,target);changed={}
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
 report=dict(kind='Menu logos, Backup, Service Ace and exam backdrop v36',master_sha256=MASTER,output_sha256=file_sha(target),disc_bytes=target.stat().st_size,font_sha256=file_sha(a.font),records=reports,catalog_rebindings=bindings,catalog_audit=cat,changed_sector_count=len(changed),untargeted_records_preserved=len(source.records)-len(replacements),checksums_and_sector_ownership_passed=True,native_gameplay='pending',backup_runtime_banks=len(names),backup_messages=29*len(names),bundle_mirrors=25)
 (a.output/'menu-art-v36-report.json').write_text(json.dumps(report,indent=2)+'\n');print('V36 COMPLETE',report['output_sha256'],flush=True)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('master',type=Path);p.add_argument('output',type=Path);p.add_argument('--font',type=Path,required=True);p.add_argument('--accelerator');p.add_argument('--tail-accelerator',required=True);p.add_argument('--assets',type=Path,default=Path(__file__).resolve().parents[1]/'assets/menu_art_v36.json');run(p.parse_args())
