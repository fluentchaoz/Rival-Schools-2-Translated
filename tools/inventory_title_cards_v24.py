"""Read-only TIM title-card inventory. Private previews never belong in Git."""
import argparse,hashlib,json,struct
from pathlib import Path
from PIL import Image,ImageDraw
from inspect_pool_club_v22 import decompress
SOURCE='0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e'
def run(disc,index,output,private):
 assert hashlib.sha256(disc.read_bytes()).hexdigest()==SOURCE;private.mkdir(parents=True,exist_ok=True);rows=json.loads(index.read_text());matches=[];seen={};tiles=[]
 with disc.open('rb')as f:
  for r in rows:
   if not(r['path'].startswith('DAT2/MGBG')and r['path'].endswith('.BZZ')):continue
   b=bytearray()
   for i in range(0,r['size'],2048):f.seek((r['lba']+i//2048)*2352+24);b+=f.read(min(2048,r['size']-i))
   slots=[];j=0
   while True:
    off,n=struct.unpack_from('<II',b,j);j+=8
    if not off and not n:break
    assert off+n<=len(b);slots.append((off,n))
   for member,(off,n)in enumerate(slots):
    d=decompress(b[off:off+n]);at=0
    while True:
     at=d.find(b'\x10\0\0\0\x09\0\0\0',at)
     if at<0:break
     try:
      cl=struct.unpack_from('<I',d,at+8)[0];pos=at+8+cl;size,x,y,w,h=struct.unpack_from('<IHHHH',d,pos);end=pos+size
      assert w==128 and h==220 and cl==524 and end<=len(d)and size==12+256*220
     except (AssertionError,struct.error):at+=4;continue
     sha=hashlib.sha256(d[at:end]).hexdigest();matches.append({'record':r['path'],'member':member,'tim_offset':at,'tim_sha256':sha,'member_stored_sha256':hashlib.sha256(b[off:off+n]).hexdigest()})
     if sha not in seen:
      ix=len(seen);seen[sha]=ix;pal=struct.unpack_from('<256H',d,at+20);p=d[pos+12:end];rgb=[tuple(((pal[v]>>s)&31)*255//31 for s in [0,5,10])for v in p];im=Image.new('RGB',(256,220));im.putdata(rgb);im2=Image.new('RGB',(512,110));im2.paste(im.crop((0,0,256,110)),(0,0));im2.paste(im.crop((0,110,256,220)),(256,0));im2.save(private/f'title-{ix}.png');tiles.append(im2)
     at=end
 report={'kind':'Candidate 256x220 8bpp title TIM inventory; visual classification required','source_sha256':SOURCE,'unique_candidates':len(seen),'references':matches};output.write_text(json.dumps(report,indent=2)+'\n')
 for start in range(0,len(tiles),12):
  subset=tiles[start:start+12];sheet=Image.new('RGB',(560,len(subset)*120),'#202020');dr=ImageDraw.Draw(sheet)
  for i,im in enumerate(subset):dr.text((0,i*120),str(start+i),fill='yellow');sheet.paste(im,(45,i*120))
  sheet.save(private/f'sheet-{start}.png')
 print(len(seen),'unique candidates;',len(matches),'references')
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('disc',type=Path);p.add_argument('index',type=Path);p.add_argument('output',type=Path);p.add_argument('private',type=Path);a=p.parse_args();run(a.disc,a.index,a.output,a.private)
