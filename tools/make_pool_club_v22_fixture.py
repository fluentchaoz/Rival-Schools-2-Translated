"""Private QA image constructor; never a translated game distribution.

Requires the verified original and v21 record-fixture outputs. Recomputes native
Mode 2/Form 1 checksums for the replaced records, preserving all else.
"""
import argparse,hashlib,json,shutil
from pathlib import Path
FORWARD=[0]*256;BACKWARD=[0]*256;EDC=[0]*256
for v in range(256):
 doubled=((v<<1)^(0x11d if v&128 else 0))&255;FORWARD[v]=doubled;BACKWARD[v^doubled]=v;r=v
 for _ in range(8):r=(r>>1)^(0xd8018001 if r&1 else 0)
 EDC[v]=r

def ecc(src,major,minor,mult,inc):
 out=bytearray(major*2);size=major*minor
 for m in range(major):
  ix=(m>>1)*mult+(m&1);a=b=0
  for _ in range(minor):v=src[ix];ix=(ix+inc)%size;a^=v;b^=v;a=FORWARD[a]
  a=BACKWARD[FORWARD[a]^b];out[m]=a;out[m+major]=a^b
 return out

def regenerate(s):
 assert len(s)==2352 and s[15]==2 and not(s[18]&32) and s[16:20]==s[20:24]
 w=bytearray(s);v=0
 for b in w[16:0x818]:v=(v>>8)^EDC[(v^b)&255]
 w[0x818:0x81c]=v.to_bytes(4,'little');head=w[12:16];w[12:16]=bytes(4)
 w[0x81c:0x8c8]=ecc(w[12:],86,24,2,86);w[0x8c8:]=ecc(w[12:],52,43,86,88);w[12:16]=head;return w

def make(original,records,index,output):
 assert hashlib.sha256(original.read_bytes()).hexdigest()=='0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e'
 assert not output.exists(),'fixture output already exists'
 rows=json.loads(index.read_text());wanted=['DAT2/MGG04T.BIZ','DAT2/MGG04.BZZ','DAT2/MGBGG04.BZZ']
 if (records/'MGAME.BIN').exists():wanted+=['DAT1/MGAME.BIN','DAT2/MGCOCK.TIZ']
 with original.open('rb')as f:f.seek(109905*2352);s=f.read(2352);assert regenerate(s)==s
 shutil.copyfile(original,output)
 with output.open('r+b')as f:
  for path in wanted:
   r=next(r for r in rows if r['path']==path);b=(records/Path(path).name).read_bytes();assert len(b)==r['size']
   for i in range(0,len(b),2048):
    at=(r['lba']+i//2048)*2352;f.seek(at);s=bytearray(f.read(2352));part=b[i:i+2048];s[24:24+len(part)]=part;f.seek(at);f.write(regenerate(s))
 report={'kind':'original disc with v21 record-fixture substitutions and optional actual shared records; lacks the complete earlier English build','fixture_master_sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'fixture_text_sha256':hashlib.sha256((records/'MGG04T.BIZ').read_bytes()).hexdigest(),'records':wanted}
 output.with_suffix('.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('original',type=Path);p.add_argument('v21_records',type=Path);p.add_argument('index',type=Path);p.add_argument('output',type=Path);a=p.parse_args();make(a.original,a.v21_records,a.index,a.output)
