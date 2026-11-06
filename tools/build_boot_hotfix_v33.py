"""Correct the single v32 title catalog signature byte; all other records stay exact."""
import sys,struct,shutil,json
from pathlib import Path
from practice_disc_v30 import Disc,file_sha,sha,regenerate
from native_resource_catalog import audit_catalog,require_catalog
def build(master,out):
 if out.exists() or out.with_suffix('.cue').exists():raise ValueError('Choose a new output path; existing files are never overwritten')
 if file_sha(master)!='4cfa22fde28be1d805b141fe67f0bbe0f9cbcf999d6f015abd858e4b8dc8654b':raise ValueError('Expected exact failed v32 image; no output created')
 D=Disc(master);title=D.record('DAT2/TITLE.BIZ');exe=D.record('SLPS_021.20');lba,size=D.records['DAT2/TITLE.BIZ'];n=lba+150
 bcd=lambda v:v//10*16+v%10
 key=bytes([bcd(n//4500),bcd(n%4500//75),bcd(n%75),0])+struct.pack('<I',size)
 positions=[i for i in range(0,len(exe)-11,4)if exe[i:i+8]==key];assert positions==[0x770d4],positions;offset=positions[0]+8;assert exe[offset:offset+4]==bytes.fromhex('00087042');assert title[:4]==bytes.fromhex('00007042');new=bytearray(exe);new[offset:offset+4]=title[:4];changed=[i for i,(a,b)in enumerate(zip(exe,new))if a!=b];assert changed==[0x770dd]
 out.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(master,out);exelba,exesize=D.records['SLPS_021.20'];sector=exelba+offset//2048;within=offset%2048
 with out.open('r+b')as f:
  f.seek(sector*2352);raw=f.read(2352);assert regenerate(raw)==raw;s=bytearray(raw);s[24+within:24+within+4]=title[:4];s=regenerate(s);assert regenerate(s)==s;f.seek(sector*2352);f.write(s)
 V=Disc(out);assert V.record('SLPS_021.20')==new
 for path in D.records:
  if path!='SLPS_021.20':assert V.record(path)==D.record(path),path
 actual=[]
 with master.open('rb')as a,out.open('rb')as b:
  l=0
  while True:
   x=a.read(2352*1024);y=b.read(2352*1024);assert len(x)==len(y)
   if not x:break
   for p in range(0,len(x),2352):
    if x[p:p+2352]!=y[p:p+2352]:actual.append(l+p//2352)
   l+=len(x)//2352
 assert actual==[sector];out.with_suffix('.cue').write_bytes(f'FILE "{out.name}" BINARY\r\n  TRACK 01 MODE2/2352\r\n    INDEX 01 00:00:00\r\n'.encode())
 report=dict(kind='v33 title-loader catalog hotfix',input_sha256=file_sha(master),output_sha256=file_sha(out),changed_iso_record='SLPS_021.20',changed_payload_bytes=1,payload_byte_offset='0x770dd',catalog_entry_offset='0x770d4',catalog_signature_offset='0x770dc',old_signature='00087042',new_signature=title[:4].hex(),title_lba=lba,title_size=size,changed_raw_sectors=actual,all_946_other_records_unchanged=True,title_graphics_and_all_v32_translations_unchanged=True,sector_edc_ecc_passed=True,native_boot_test='pending',prior_v32_native_result='User reports freeze after no-memory-card screen')
 report['catalog_before']=audit_catalog(D);report['catalog_after']=require_catalog(V)
 if report['catalog_before']['bound_entries']!=876 or len(report['catalog_before']['mismatches'])!=1:raise ValueError('Unexpected source catalog population')
 out.with_name('boot-hotfix-v33-report.json').write_text(json.dumps(report,indent=2)+'\n');print('V33 VERIFIED',report['output_sha256'])
 return report

if __name__=='__main__':
 import argparse
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('master',type=Path);p.add_argument('output',type=Path);a=p.parse_args();build(a.master,a.output)
