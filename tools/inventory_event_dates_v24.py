"""Read-only original-disc inventory. Reports coordinates/checksums, never game text."""
import argparse,hashlib,json,struct
from pathlib import Path
from inspect_pool_club_v22 import decompress,banks
SOURCE='0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e'
def run(disc,index,out):
 assert hashlib.sha256(disc.read_bytes()).hexdigest()==SOURCE
 rows=json.loads(index.read_text());results=[]
 with disc.open('rb')as f:
  for r in rows:
   if not(r['path'].startswith('DAT2/MGG')and r['path'].endswith('.BIZ')):continue
   b=bytearray()
   for i in range(0,r['size'],2048):f.seek((r['lba']+i//2048)*2352+24);b+=f.read(min(2048,r['size']-i))
   d=decompress(b);date=[]
   try:
    for s,i,w in banks(d):
     # 200A/200B are runtime month/day insertions, not literal glyphs.
     codes=[];j=0
     while j<len(w):
      c=w[j];j+=1;codes.append(c)
      if c in [0x3002,0x3003]or 0x2003<=c<=0x2009:j+=1
     if 0x200a in codes or 0x200b in codes:date.append({'selector':s,'entry':i,'month':0x200a in codes,'day':0x200b in codes,'payload_sha256':hashlib.sha256(struct.pack('<'+'H'*len(w),*w)).hexdigest()})
    status='parsed'
   except (AssertionError,struct.error,IndexError):status='requires separate layout reader'
   results.append({'path':r['path'],'stored_sha256':hashlib.sha256(b).hexdigest(),'decoded_bytes':len(d),'status':status,'date_entries':date})
 report={'kind':'Read-only original event-bank date inventory; does not cover title-card graphics or every other dialogue archive','source_sha256':SOURCE,'records':results,'date_entry_count':sum(len(r['date_entries'])for r in results)};out.write_text(json.dumps(report,indent=2)+'\n');print(len(results),'records;',report['date_entry_count'],'date entries')
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('disc',type=Path);p.add_argument('index',type=Path);p.add_argument('output',type=Path);a=p.parse_args();run(a.disc,a.index,a.output)
