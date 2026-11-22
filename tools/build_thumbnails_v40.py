"""v40: Tournament name labels and English headers on the large Mode Select panel pictures, on exact v39."""
import argparse,json,shutil
from pathlib import Path
import numpy as np
from PIL import Image
from practice_disc_v30 import Disc,decode,compress,file_sha,sha,regenerate
from native_resource_catalog import audit_catalog,require_catalog
from build_exam_dance_v35 import assert_claims
from build_practice_v30 import tim,rgb_image,replace_pixels
from compress_tail_v36 import compress_tail
MASTER='a358f7e6ad010cf61118a883f6c98be44182e637b667352130810b38fcd91df0'
RECORD='DAT2/MENU.BIZ';TIM_AT=0x8f800
X0,Y0,W,H=21,67,89,18            # rectangle that holds the Japanese dialogue text
FILL=11                          # existing beige palette index used by the original lettering
LINES=["OH MY, ARE YOU OKAY?","ZONING OUT HERE ISN'T","SAFE, YOU KNOW."]
# Native-looking 3x5 pixel capitals; the thumbnail is only 128x96 so legibility is limited by design.
FONT={'A':'010101111101101','B':'110101110101110','C':'011100100100011','D':'110101101101110','E':'111100110100111','F':'111100110100100','G':'011100101101011','H':'101101111101101','I':'111010010010111','J':'001001001101010','K':'101101110101101','L':'100100100100111','M':'101111111101101','N':'110101101101101','O':'010101101101010','P':'110101110100100','Q':'010101101111011','R':'110101110101101','S':'011100010001110','T':'111010010010010','U':'101101101101111','V':'101101101101010','W':'101101111111101','X':'101101010101101','Y':'101101010010010','Z':'111001010100111',
'?':'110001010000010',',':'000000000010100','.':'000000000000010',"'":'010010000000000','!':'010010010000010',' ':'000000000000000'}
def glyph(c):return np.array([int(v)for v in FONT[c]],dtype=np.uint8).reshape(5,3)
import thumbnails_v40 as T
def patch_thumbnail(before):
 after,claims=T.patch_all(before,tim,replace_pixels);return after,claims,b''
def run(a):
 if a.master.stat().st_size!=663216960 or file_sha(a.master)!=MASTER:raise ValueError('Expected exact v39 BIN')
 if a.output.exists():raise ValueError('Choose new output folder')
 source=Disc(a.master);require_catalog(source);a.output.mkdir(parents=True);replacements={};reports=[]
 stored=source.record(RECORD);before=decode(stored)[0];after,claims,preimage=patch_thumbnail(before);assert_claims(before,after,claims)
 try:encoded,pr=compress_tail(after,stored,a.tail_accelerator)
 except ValueError as exc:
  print('tail compression unavailable (',exc,') - full recompression',flush=True);encoded,pr=compress(after,stored,a.accelerator)
 replacements[RECORD]=encoded;reports.append(dict(path=RECORD,claims=claims,compression=pr,input_sha256=sha(stored),output_sha256=sha(encoded),source_region_sha256=sha(preimage)))
 [(rgb_image(tim(after,k)).save(a.output/f'thumb-{k:x}-v40.png'),rgb_image(tim(before,k)).save(a.output/f'thumb-{k:x}-v39.png'))for k in list(T.SMALL)+list(T.BIG)]
 bindings=audit_catalog(source,replacements)['mismatches'];exe=bytearray(source.record('SLPS_021.20'))
 for row in bindings:
  p=row['signature_offset'];exe[p:p+4]=replacements[row['path']][:4]
 if bindings:replacements['SLPS_021.20']=bytes(exe)
 require_catalog(source,replacements);target=a.output/'justice-gakuen2-thumbnails-v40.bin';shutil.copyfile(a.master,target);changed={}
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
 report=dict(kind='Mode Select name labels and panel headers v40',master_sha256=MASTER,output_sha256=file_sha(target),disc_bytes=target.stat().st_size,records=reports,catalog_audit=cat,changed_sector_count=len(changed),untargeted_records_preserved=len(source.records)-len(replacements),checksums_and_sector_ownership_passed=True,native_gameplay='pending',thumbnails=[hex(k)for k in list(T.SMALL)+list(T.BIG)])
 (a.output/'thumbnails-v40-report.json').write_text(json.dumps(report,indent=2)+'\n');print('V40 COMPLETE',report['output_sha256'],'changed sectors',len(changed),flush=True)
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('master',type=Path);p.add_argument('output',type=Path);p.add_argument('--accelerator',required=True);p.add_argument('--tail-accelerator',required=True);run(p.parse_args())
