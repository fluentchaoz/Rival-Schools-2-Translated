"""Private inspection helper. Never commit its extracted records or previews."""
import argparse,hashlib,json,struct
from pathlib import Path
from PIL import Image,ImageDraw

def decompress(d):
 out=bytearray();p=0
 def word():
  nonlocal p
  if p+2>len(d):raise ValueError('truncated stream')
  v=int.from_bytes(d[p:p+2],'little');p+=2;return v
 while True:
  c=word()
  for _ in range(16):
   if c&0x8000:
    t=word();n=t>>11;dist=t&2047
    if n==0:n=word()
    if dist==0:
     if n==0:return bytes(out)
     out+=bytes(n*2)
    else:
     for i in range(n):out+=out[-dist*2:][:2]
   else:out+=word().to_bytes(2,'little')
   c=(c<<1)&65535

def banks(d):
 result=[]
 for sel in range(8):
  value=struct.unpack_from('<I',d,0x31000+sel*4)[0]
  if not value:continue
  table=value-0x800d0000;ptrs=[]
  while True:
   p=struct.unpack_from('<I',d,table+len(ptrs)*4)[0]
   if p==0xffffffff:break
   ptrs.append(p-0x800d0000)
  for i,p in enumerate(ptrs):
   end=ptrs[i+1] if i+1<len(ptrs) else table
   result.append((sel,i,struct.unpack('<'+'H'*((end-p)//2),d[p:end])))
 return result

def render(d,words):
 out=Image.new('RGB',(640,115),'#17262b');x=y=j=0
 while j<len(words):
  c=words[j];j+=1
  if c==0x3001:break
  if c==0x3000:x=0;y+=22;continue
  if c in [0x3002,0x3003] or 0x2003<=c<=0x2009:j+=1;continue
  if c>=1001:continue
  raw=d[384+c*200:384+(c+1)*200];pix=[v for a in raw for v in (a&15,a>>4)]
  if x+20>640:x=0;y+=22
  if y+20>115:break
  tile=Image.new('RGB',(20,20));tile.putdata([(255,255,255)if v>=8 else(0,0,0)for v in pix]);out.paste(tile,(x,y));x+=20
 return out

def pages(d,sel,start,end,out):
 rows=[(s,i,w)for s,i,w in banks(d)if s==sel and start<=i<end]
 for page in range((len(rows)+11)//12):
  group=rows[page*12:page*12+12];im=Image.new('RGB',(800,len(group)*120),'#17262b');draw=ImageDraw.Draw(im)
  for n,(s,i,w)in enumerate(group):draw.text((0,n*120+5),f'bank{s} entry{i}',fill='yellow');im.paste(render(d,w),(150,n*120))
  im.save(out/f'bank{sel}-{start+page*12}.png')

def extract(disc,out):
 assert hashlib.sha256(disc.read_bytes()).hexdigest()=='0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e'
 out.mkdir(parents=True,exist_ok=True)
 with disc.open('rb') as f:
  def read(lba,size):
   data=bytearray()
   for i in range(0,size,2048):f.seek((lba+i//2048)*2352+24);data+=f.read(min(2048,size-i))
   return bytes(data)
  def walk(lba,size,parent=''):
   b=read(lba,size);i=0
   while i<len(b):
    n=b[i]
    if not n:i=(i//2048+1)*2048;continue
    r=b[i:i+n];i+=n;name=r[33:33+r[32]]
    if name in [b'\0',b'\1']:continue
    path=parent+name.decode('ascii').split(';')[0];l=struct.unpack_from('<I',r,2)[0];size=struct.unpack_from('<I',r,10)[0]
    if r[25]&2:yield from walk(l,size,path+'/')
    else:yield {'path':path,'lba':l,'size':size}
  root=read(16,2048)[156:];rows=list(walk(struct.unpack_from('<I',root,2)[0],struct.unpack_from('<I',root,10)[0]));(out/'index.json').write_text(json.dumps(rows,indent=2))
  wanted=['DAT2/MGG04T.BIZ','DAT2/MGG04.BZZ','DAT2/MGBGG04.BZZ','DAT2/MGCOCK.TIZ','DAT1/MGAME.BIN']
  for r in rows:
   if r['path']in wanted:
    b=read(r['lba'],r['size']);p=out/Path(r['path']).name;p.write_bytes(b)
    if p.suffix in ['.BIZ','.TIZ']:
     d=decompress(b);p.with_suffix('.decoded').write_bytes(d)
     if p.stem=='MGG04T':
      for sel in [0,1]:pages(d,sel,57,210,out)
      pages(d,2,0,108,out)
      pages(d,5,0,31,out)
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('original_bin',type=Path);a.add_argument('private_output',type=Path);p=a.parse_args();extract(p.original_bin,p.private_output)
