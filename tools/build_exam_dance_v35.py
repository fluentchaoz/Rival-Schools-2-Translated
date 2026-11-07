"""English exam results, ball HUD and dance selector/captions on exact v34.
No game data embedded. Python 3.11+, Pillow and NumPy required to build.
"""
import argparse,json,struct,shutil,math
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageFont,ImageOps
from practice_disc_v30 import Disc,decode,compress,file_sha,sha,regenerate
from build_practice_v30 import tim,rgb_image,rgb_palette,replace_pixels
from native_resource_catalog import audit_catalog,require_catalog
from build_practice_layout_v34 import bitmap,pixel_label
MASTER='2ed4e3233c01b0f1eccf804bffdce6ed6c1f268ce71cf94109c839e86894734a'
NAMES=[('KYOSUKE',5,2),('BATSU',0,2),('HINATA',2,3),('SHOMA',7,2),('NATSU',9,1),('ROBERTO',12,4),('ROY',16,2),('TIFFANY',18,6),('BOWMAN',24,4),('EDGE',28,3),('AKIRA',31,3),('GAN',34,1),('HIDEO',36,2),('KYOKO',38,2),('RAIZO',40,2),('HYO',42,1),('AKIRA',43,3),('SAKURA',48,3),('DAIGO',51,2),('HAYATO',53,2),('RAN',56,2),('NAGARE',55,1)]
CAPTIONS=[('ヘイ！ブラザー！','Hey, brother!'),('さあゴキゲンな',"Let's get groovy!"),('Doki-Waku-Danceが始まるぜ！','Doki-Waku Dance starts now!'),('準備はいいか？ヒアウィーゴー！','Ready? Here we go!')]

def ink(text,w,h,font,maxsize=18,pad=1,stroke=0):
 im=Image.new('L',(w,h));d=ImageDraw.Draw(im);d.fontmode='1'
 for size in range(maxsize,4,-1):
  f=ImageFont.truetype(str(font),size);b=d.textbbox((0,0),text,font=f,stroke_width=stroke)
  if b[2]-b[0]<=w-pad*2 and b[3]-b[1]<=h-pad*2:break
 else:raise ValueError('text does not fit: '+text)
 d.text(((w-(b[2]-b[0]))//2-b[0],(h-(b[3]-b[1]))//2-b[1]),text,font=f,fill=255,stroke_width=stroke)
 return np.array(im)>0

def raster(text,w,h,font,fill=14,outline=None,maxsize=18,clear=0):
 result=np.full((h,w),clear,dtype=np.uint8);core=ink(text,w,h,font,maxsize,pad=2 if outline is not None else 1)
 if outline is not None:
  edge=np.zeros_like(core)
  for dy in [-1,0,1]:
   for dx in [-1,0,1]:
    # Core has two pixels of padding; rolls cannot wrap ink.
    edge|=np.roll(np.roll(core,dy,0),dx,1)
  result[edge]=outline
 result[core]=fill;return result

def write_cells(data,at,cells):
 t=tim(data,at);pix=t['pixels'].copy();rects=[]
 for box,replacement in cells:
  x,y,w,h=box
  if replacement.shape!=(h,w):raise ValueError('replacement geometry')
  pix[y:y+h,x:x+w]=replacement;rects.append(box)
 replace_pixels(data,t,pix,rects);return dict(tim_offset=hex(at),rectangles=rects)

def assert_claims(before,after,claims):
 if len(before)!=len(after):raise ValueError('decoded extent changed')
 allowed=np.zeros(len(before),dtype=bool)
 for claim in claims:
  t=tim(before,int(claim['tim_offset'],16));factor=2 if t['mode']==0 else 1;stride=t['width']//factor
  for x,y,w,h in claim['rectangles']:
   for row in range(y,y+h):
    a=t['offset']+row*stride+x//factor;b=t['offset']+row*stride+(x+w+factor-1)//factor;allowed[a:b]=True
 old=np.frombuffer(before,dtype=np.uint8);new=np.frombuffer(after,dtype=np.uint8)
 if np.any((old!=new)&~allowed):raise ValueError('write escaped texture claims')

def selector_plan(font):
 used=[0]*5;plan=[]
 # Stable descriptor order is retained; only owned start/count fields change.
 counts=[math.ceil((bitmap(n).shape[1]+4)/20)for n,_,_ in NAMES]
 starts=[None]*22
 for i in sorted(range(22),key=lambda i:-counts[i]):
  row=next((r for r in range(5)if used[r]+counts[i]<=12),None)
  if row is None:raise ValueError('names exceed native five rows')
  starts[i]=row*12+used[row];used[row]+=counts[i]
 return list(zip(starts,counts))

def patch_selector(before,font,plan):
 after=bytearray(before);cells=[];names=np.zeros((100,240),dtype=np.uint8)
 for (name,_,_),(start,count) in zip(NAMES,plan):
  x=start%12*20;y=start//12*20;names[y:y+20,x:x+count*20]=pixel_label(name,count*20,20,15,1)
 cells.append(((0,0,240,100),names))
 for start,count,text in [(60,4,'TAIYO HIGH'),(64,4,'GORIN HIGH'),(72,8,'PACIFIC HIGH'),(80,4,'GEDO HIGH'),(84,8,'JUSTICE HIGH'),(92,2,'BOY'),(94,2,'GIRL')]:
  cells.append(((start%12*20,start//12*20,count*20,20),raster(text,count*20,20,font,15,1,12)))
 cells += [((0,160,100,20),raster('PLAYER',100,20,font,15,1,14)),((100,160,100,20),raster('PARTNER',100,20,font,15,1,14)),((0,200,40,20),raster('OK',40,20,font,15,1,14))]
 claim=write_cells(after,0x91800,cells);return bytes(after),[claim]

def patch_overlay(before,base,plan):
 after=bytearray(before);owned=[]
 for i,((_,start,count),(newstart,newcount))in enumerate(zip(NAMES,plan)):
  p=base+i*4
  if before[p:p+4]!=bytes([1,start,count,0]):raise ValueError('selector descriptor drift')
  after[p+1:p+3]=bytes([newstart,newcount]);owned.extend([p+1,p+2])
 if any(a!=b and i not in owned for i,(a,b)in enumerate(zip(before,after))):raise ValueError('overlay escaped data fields')
 return bytes(after),dict(kind='selector-descriptor-data',base=hex(base),owned_offsets=owned,renderer_code_and_character_order_preserved=True)

def patch_ball(before,font):
 after=bytearray(before);t=tim(before,0x10800);cells=[]
 for box,text in [((216,56,40,16),'STYLE'),((136,72,40,16),'FRAME'),((240,0,16,16),'P')]:
  x,y,w,h=box;cell=np.zeros((h,w),dtype=np.uint8);cell[:10]=raster(text,w,10,font,14,2,9);cells.append((box,cell))
 # Slanted strip: preserve the border, number space and native colored ramp.
 pix=t['pixels'];strip=pix[72:88,:128].copy()
 for x,w,text in [(6,48,'LEFT'),(104,24,'BALL')]:
  # Only lettering rows 0..13 are owned. Restore their source strip base by
  # extending each column's intact bottom row; border/number area stays exact.
  cell=strip[:14,x:x+w].copy();cell[:]=strip[14,x:x+w]
  mask=ink(text,w,12,font,11);edge=np.zeros_like(mask)
  for dy in [-1,0,1]:
   for dx in [-1,0,1]:edge|=np.roll(np.roll(mask,dy,0),dx,1)
  # Keep ink in the upper 12 rows with source white face/black shadow roles.
  cell[:12][edge]=2;cell[:12][mask]=14;strip[:14,x:x+w]=cell
 cells.extend([((6,72,48,14),strip[:14,6:54]),((104,72,24,14),strip[:14,104:128])])
 claim=write_cells(after,0x10800,cells);return bytes(after),[claim]

def patch_dance(before,font):
 after=bytearray(before);t=tim(before,0);cells=[]
 for row,(_,english)in enumerate(CAPTIONS):
  old=t['pixels'][row*24:row*24+24,512:768];ys,xs=np.where(old!=0);width=min(256,int(xs.max())+1)
  im=np.zeros((24,256),dtype=np.uint8);im[:,:width]=raster(english,width,24,font,6,1,18);cells.append(((512,row*24,256,24),im))
 claim=write_cells(after,0,cells);return bytes(after),[claim]

def patch_result_atlas(before,font):
 after=bytearray(before);t=tim(before,0);pix=t['pixels'];cells=[]
 # Source result page: native opaque round badges, indices 0 and 15 are not
 # assumed to be transparent. Keep their silhouettes and native background.
 for x,y,text in [(200,40,'PASS'),(200,72,'FAIL')]:
  old=pix[y:y+32,x:x+56].copy();palette=rgb_palette(t);words=t['palette'][:16]
  clear=int(next((i for i,v in enumerate(words)if v==0),0));body=old!=clear
  # The old lettering consists of low-valued ink; badge fill is index 14/15.
  values,counts=np.unique(old[body],return_counts=True);base=int(values[np.argmax(counts)])
  mask=ink(text,50,18,font,12);yy,xx=np.where(mask);cell=old.copy()
  # Preserve exact outside silhouette; fill its interior then write new ink.
  cell[body]=base;inkindex=2 if y==40 else 8
  for dy,dx in zip(yy,xx):
   py=dy+7;px=dx+3
   if body[py,px]:cell[py,px]=inkindex
  cells.append(((x,y,56,32),cell))
 # The tiny two-line remaining-time caption is a distinct, source-bound cell.
 cell=np.zeros((30,40),dtype=np.uint8);cell[:14]=raster('LEFT',40,14,font,1,None,11);cell[14:]=raster('TIME',40,16,font,1,None,11)
 cells.append(((144,80,40,30),cell))
 claim=write_cells(after,0,cells);return bytes(after),[claim]

def stamp_pixels(t,text,font):
 pal=t['palette'][:16];vals,counts=np.unique(t['pixels'],return_counts=True);clear=int(next(i for i in vals[np.argsort(-counts)]if pal[i]==0));face=int(vals[np.argsort(-counts)][1])
 if face==clear:raise ValueError('stamp color roles')
 im=Image.new('L',(160,390));d=ImageDraw.Draw(im);d.rounded_rectangle((4,4,155,385),radius=15,outline=255,width=7)
 for i,char in enumerate(text):
  core=ink(char,128,82,font,78,pad=3);a=np.array(im);a[30+i*82:112+i*82,16:144][core]=255;im=Image.fromarray(a)
 im=im.rotate(-27,resample=Image.Resampling.NEAREST,expand=True);im=ImageOps.contain(im,(t['width']-6,t['height']-6),Image.Resampling.NEAREST)
 result=np.full((t['height'],t['width']),clear,dtype=np.uint8);mask=np.array(im)>0;x=(t['width']-im.width)//2;y=(t['height']-im.height)//2;result[y:y+im.height,x:x+im.width][mask]=face
 return result

def paint_sheet(before,font):
 after=bytearray(before);t=tim(before,0x8800);pix=t['pixels'].copy();pal=rgb_palette(t);claims=[];paper=pix[82:98,104:168].copy()
 def color(word):
  matches=np.where((t['palette']&0x7fff)==(word&0x7fff))[0]
  if not len(matches):raise ValueError('sheet palette role '+hex(word))
  return int(matches[0])
 def label(box,text,maxsize=18,kind='paper'):
  x,y,w,h=box;old=pix[y:y+h,x:x+w].copy();rgb=pal[old]
  if kind in ['heading','hint']:old[:]=color(0x816e)
  else:old[:]=np.tile(paper,(math.ceil(h/16),math.ceil(w/64)))[:h,:w]
  fill=color(0x3be0)if kind=='heading'else color(0x69f4)if kind=='hint'else int(np.argmin(((pal.astype(int)-np.array([180,30,210]))**2).sum(1)))
  core=ink(text,w,h,font,maxsize,pad=2);old[core]=fill;pix[y:y+h,x:x+w]=old;claims.append(box)
 summary=bool(np.any((t['palette']&0x7fff)==0x3be0))
 if summary:label((169,31,170,36),'EXAM RESULTS',20,'heading')
 label((99,109,310,34),'1999 EXAM REPORT',21)
 for box,text in [((79,151,110,25),'EXAM'),((207,151,161,25),'RECORD'),((381,151,53,25),'GRADE')]:label(box,text,15)
 # The record-history variant has a second table. The summary variant has
 # scenery below the first table instead; choose by sampled paper preimage.
 if np.mean(pal[pix[245:270,80:190]])>150:
  for box,text in [((79,245,110,29),'EXAM'),((207,245,161,29),'BEST RECORD'),((385,245,47,29),'RESULT'),((76,280,120,27),'FIRST TERM'),((76,312,120,27),'SECOND TERM'),((76,345,120,27),'YEAR FINAL'),((201,282,39,13),'LEFT'),((201,295,39,14),'TIME'),((297,315,29,28),'X')]:label(box,text,13)
 if summary:
  label((342,410,89,23),'X: BACK',13,'hint')
  # Source-bound attendance-register label: retain the tilted paper silhouette.
  x,y,w,h=224,294,45,34;cell=pix[y:y+h,x:x+w].copy();poly=Image.new('L',(w,h));ImageDraw.Draw(poly).polygon([(3,2),(44,8),(40,32),(0,24)],fill=255);inside=np.array(poly)>0
  cell[inside]=241;letters=Image.fromarray((ink('ROLL',34,12,font,9)*255).astype(np.uint8)).rotate(-8,expand=True,resample=Image.Resampling.NEAREST);lm=np.array(letters)>0;layer=np.zeros((h,w),dtype=bool);lx=(w-letters.width)//2;ly=(h-letters.height)//2;layer[ly:ly+letters.height,lx:lx+letters.width]=lm;cell[layer&inside]=4
  pix[y:y+h,x:x+w]=cell;claims.append((x,y,w,h))
 replace_pixels(after,t,pix,claims);outclaims=[dict(tim_offset='0x8800',rectangles=claims)]
 for at,text in [(0x45000,'PASS'),(0x58800,'FAIL')]:
  ts=tim(before,at);outclaims.append(write_cells(after,at,[((0,0,ts['width'],ts['height']),stamp_pixels(ts,text,font))]))
 return bytes(after),outclaims

def archive(stored,patches,accelerator,allow_slot_growth=False):
 result=bytearray(stored);reports=[]
 for index,patch in patches.items():
  off,size=struct.unpack_from('<II',stored,index*8);original=stored[off:off+size];before=decode(original)[0];after,claims=patch(before);assert_claims(before,after,claims)
  if allow_slot_growth:
   slot=0x800
   if off%slot or off+slot>len(stored)or size>slot:raise ValueError('title archive slot contract')
   encoded,profile=compress(after,original+bytes(slot-size),accelerator);result[off:off+slot]=encoded
   struct.pack_into('<I',result,index*8+4,profile['rebuilt']['stream_bytes'])
  else:
   encoded,profile=compress(after,original,accelerator);result[off:off+size]=encoded
  reports.append(dict(member=index,offset=off,size=size,claims=claims,compression=profile,input_sha256=sha(original),output_sha256=sha(encoded)))
 if not allow_slot_growth and result[:0x800]!=stored[:0x800]:raise ValueError('archive table changed')
 return bytes(result),reports

def run(a):
 if a.master.stat().st_size!=663216960 or file_sha(a.master)!=MASTER:raise ValueError('Expected exact v34 BIN')
 if a.output.exists():raise ValueError('Choose new output folder')
 source=Disc(a.master);require_catalog(source);a.output.mkdir(parents=True);(a.output/'previews').mkdir();plan=selector_plan(a.font);replacements={};reports=[]
 def regular(name,patch):
  stored=source.record(name);before=decode(stored)[0];after,claims=patch(before);assert_claims(before,after,claims);encoded,pr=compress(after,stored,a.accelerator);replacements[name]=encoded
  for j,c in enumerate(claims):rgb_image(tim(after,int(c['tim_offset'],16))).save(a.output/'previews'/(name.split('/')[-1]+f'-{j}.png'))
  reports.append(dict(path=name,claims=claims,compression=pr,input_sha256=sha(stored),output_sha256=sha(encoded)));print(name,'ready',flush=True)
 regular('DAT2/CEFT5.BIZ',lambda b:patch_ball(b,a.font));regular('DAT2/DANCE.BIZ',lambda b:patch_dance(b,a.font))
 for key in '9ABC':regular(f'DAT2/MINITTL{key}.BIZ',lambda b:patch_selector(b,a.font,plan))
 for name,base in [('DAT1/MGAME06.BIN',0x2b0),('DAT1/MGAME07.BIN',0x280)]:
  before=source.record(name);after,claim=patch_overlay(before,base,plan);replacements[name]=after;reports.append(dict(path=name,claim=claim))
 # Result archive providers have identical atlas and stamp layouts. Summary
 # backgrounds differ; both 1999 variants and the basics result provider are patched.
 def result_patch(b):
  first,claims=patch_result_atlas(b,a.font);second,more=paint_sheet(first,a.font);return second,claims+more
 stored=source.record('DAT2/SIKEN20.BIZ');new,rep=archive(stored,{0:result_patch,1:result_patch},a.accelerator);replacements['DAT2/SIKEN20.BIZ']=new;reports.append(dict(path='DAT2/SIKEN20.BIZ',members=rep))
 # Canonical atlas mirrors: these retain result providers in the wide menu pages.
 canonical=patch_result_atlas(decode(source.record('DAT2/SIKEN2.BIZ'))[0],a.font)[0]
 regular('DAT2/SIKEN2.BIZ',lambda b:patch_result_atlas(b,a.font))
 def mirror(b):
  out=bytearray(b);src=tim(canonical,0)['pixels'];cells=[]
  for (sx,sy,w,h),(x,y) in [((200,40,56,32),(616,64)),((200,72,56,32),(672,64))]:cells.append(((x,y,w,h),src[sy:sy+h,sx:sx+w]))
  return bytes_after(out,0x3c800,cells)
 for key in ['SIKEN1','SIKEN10']:regular('DAT2/'+key+'.BIZ',mirror)
 def title(text):
  def patch(b):
   out=bytearray(b);t=tim(b,0);vals,counts=np.unique(t['pixels'],return_counts=True);pal=t['palette'][:16];clear=int(next(i for i in vals[np.argsort(-counts)]if pal[i]==0));fill=int(vals[np.argsort(-counts)][1]);return bytes_after(out,0,[((0,0,124,28),raster(text,124,28,a.font,fill,None,12,clear))])
  return patch
 new,rep=archive(source.record('DAT2/SIKENKK.BIZ'),{30:title('FIRST TERM FINAL'),31:title('SECOND TERM FINAL'),32:title('YEAR FINAL')},a.accelerator,allow_slot_growth=True);replacements['DAT2/SIKENKK.BIZ']=new;reports.append(dict(path='DAT2/SIKENKK.BIZ',members=rep))
 # Catalog signature rebindings are data-only; leave code and resource extents intact.
 bindings=audit_catalog(source,replacements)['mismatches'];exe=bytearray(source.record('SLPS_021.20'))
 for row in bindings:
  if row['path']not in replacements:raise ValueError('unexpected loader mismatch')
  p=row['signature_offset'];exe[p:p+4]=replacements[row['path']][:4]
 if bindings:replacements['SLPS_021.20']=bytes(exe)
 require_catalog(source,replacements);target=a.output/'justice-gakuen2-exam-dance-v35.bin';shutil.copyfile(a.master,target);changed={}
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
 report=dict(kind='Exam results, ball HUD and dance v35',master_sha256=MASTER,output_sha256=file_sha(target),disc_bytes=target.stat().st_size,font_sha256=file_sha(a.font),records=reports,selector_plan=plan,captions=CAPTIONS,catalog_rebindings=bindings,catalog_audit=cat,changed_sector_count=len(changed),untargeted_records_preserved=947-len(replacements),checksums_and_sector_ownership_passed=True,native_gameplay='pending',scope_limits='Decorative background school-name patterns retained; unseen exam/practice screens remain possible follow-up work.')
 (a.output/'exam-dance-v35-report.json').write_text(json.dumps(report,indent=2)+'\n');print('V35 COMPLETE',report['output_sha256'],flush=True)

def bytes_after(data,at,cells):
 claim=write_cells(data,at,cells);return bytes(data),[claim]
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('master',type=Path);p.add_argument('output',type=Path);p.add_argument('--font',type=Path,required=True);p.add_argument('--accelerator');run(p.parse_args())
