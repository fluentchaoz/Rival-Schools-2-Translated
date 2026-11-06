"""Bounded UI graphics corrections on the exact boot-tested v33 image.

No source game bytes are included. Requires Pillow/NumPy; see PRACTICE_LAYOUT_V34.md.
"""
import argparse,json,shutil,struct
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from practice_disc_v30 import Disc,decode,compress,sha,file_sha,regenerate
from build_practice_v30 import tim,rgb_image,replace_pixels
from build_menu_fixes_v31 import assert_owned
from native_resource_catalog import audit_catalog,require_catalog

MASTER='1efd2f0231f9eaaa941830406450e705063d141fe23caa88f2bfe08dfeff03a9'
# Unscaled five-column bitmap glyphs. No horizontal squeezing/antialiasing.
GLYPHS={
'A':['01110','10001','10001','11111','10001','10001','10001'],
'B':['11110','10001','10001','11110','10001','10001','11110'],
'C':['01111','10000','10000','10000','10000','10000','01111'],
'D':['11110','10001','10001','10001','10001','10001','11110'],
'E':['11111','10000','10000','11110','10000','10000','11111'],
'F':['11111','10000','10000','11110','10000','10000','10000'],
'G':['01111','10000','10000','10111','10001','10001','01111'],
'H':['10001','10001','10001','11111','10001','10001','10001'],
'I':['11111','00100','00100','00100','00100','00100','11111'],
'J':['00111','00010','00010','00010','10010','10010','01100'],
'K':['10001','10010','10100','11000','10100','10010','10001'],
'L':['10000','10000','10000','10000','10000','10000','11111'],
'M':['10001','11011','10101','10101','10001','10001','10001'],
'N':['10001','11001','10101','10011','10001','10001','10001'],
'O':['01110','10001','10001','10001','10001','10001','01110'],
'P':['11110','10001','10001','11110','10000','10000','10000'],
'Q':['01110','10001','10001','10001','10101','10010','01101'],
'R':['11110','10001','10001','11110','10100','10010','10001'],
'S':['01111','10000','10000','01110','00001','00001','11110'],
'T':['11111','00100','00100','00100','00100','00100','00100'],
'U':['10001','10001','10001','10001','10001','10001','01110'],
'V':['10001','10001','10001','10001','10001','01010','00100'],
'W':['10001','10001','10001','10101','10101','10101','01010'],
'X':['10001','10001','01010','00100','01010','10001','10001'],
'Y':['10001','10001','01010','00100','00100','00100','00100'],
'Z':['11111','00001','00010','00100','01000','10000','11111']}

def bitmap(text):
 parts=[]
 for char in text:
  if parts:parts.append(np.zeros((7,1),dtype=bool))
  parts.append(np.zeros((7,0),dtype=bool) if char==' ' else np.array([[x=='1' for x in row]for row in GLYPHS[char]]))
 return np.concatenate(parts,axis=1)

def pixel_label(text,w,h,fill=14,shadow=None):
 mask=np.repeat(bitmap(text),2,axis=0);mh,mw=mask.shape
 if mw>w-2 or mh>h-2:raise ValueError('native cell too small: '+text)
 result=np.zeros((h,w),dtype=np.uint8);y=(h-mh)//2;x=(w-mw)//2
 if shadow is not None:result[y+1:y+mh+1,x+1:x+mw+1][mask]=shadow
 result[y:y+mh,x:x+mw][mask]=fill
 return result

def patch_atlas(before):
 after=bytearray(before);t=tim(before,0);pix=t['pixels'].copy();rects=[]
 # MGAME06 +0x1a8..0x204 contains screen x/y, source x/y and w/h.
 # SHOMA starts at 200, NOT 192; those eight pixels belong to BATSU's cell.
 entries=[(144,96,48,40,'BACK'),(160,168,96,80,'HOME RUN'),
          (160,192,80,40,'BATSU'),(200,192,40,40,'SHOMA'),
          (192,216,24,20,'HYO'),(216,216,24,20,'GAN')]
 # Clear old oversized BATSU/SHOMA writers once, before writing actual cells.
 pix[192:216,160:240]=0;rects.append((160,192,80,24))
 for x,y,clearw,w,text in entries:
  if text not in ['BATSU','SHOMA']:pix[y:y+24,x:x+clearw]=0;rects.append((x,y,clearw,24))
  pix[y:y+20,x:x+w]=pixel_label(text,w,20,14,1)
 for x,text in [(208,'S'),(232,'F')]:
  old=pix[:20,x:x+20].copy();cell=old.copy()
  yy,xx=np.indices(cell.shape);erase=((cell>=1)&(cell<=8))|((cell!=0)&(xx>=2)&(xx<18)&(yy>=3)&(yy<16))
  cell[erase]=15;ink=pixel_label(text,20,20,1)>0
  if np.any(ink&(old==0)):raise ValueError('speed marker escapes original disk')
  cell[ink]=1;pix[:20,x:x+20]=cell;rects.append((x,0,20,20))
 replace_pixels(after,t,pix,rects)
 return bytes(after),dict(tim_offset='0x0',rectangles=rects,labels=[dict(text=e[4],source=[e[0],e[1]],native_size=[e[3],20])for e in entries],speed_markers='F=fast, S=slow; original disks retained')

def patch_points(before):
 after=bytearray(before);t=tim(before,0x22800);pix=t['pixels'].copy();pix[224:248,544:624]=0
 pix[224:240,544:624]=pixel_label('CURRENT POINTS',80,16,1)
 replace_pixels(after,t,pix,[(544,224,80,24)])
 return bytes(after),dict(tim_offset='0x22800',rectangles=[(544,224,80,24)],text='CURRENT POINTS',style='unsqueezed 5x7 bitmap, two rows per pixel, solid dark native index 1',native_safe_height=16)

def styled(text,w,h,font):
 for size in range(h-2,5,-1):
  f=ImageFont.truetype(str(font),size);im=Image.new('L',(w,h));d=ImageDraw.Draw(im);d.fontmode='1';b=d.textbbox((0,0),text,font=f)
  if b[2]-b[0]<=w-6 and b[3]-b[1]<=h-6:break
 else:raise ValueError('banner text cannot fit')
 d.text(((w-(b[2]-b[0]))//2-b[0],(h-(b[3]-b[1]))//2-b[1]),text,font=f,fill=255)
 core=np.array(im)>0;edge=np.zeros_like(core)
 for dy in [-1,0,1]:
  for dx in [-1,0,1]:edge|=np.roll(np.roll(core,dy,0),dx,1)
 result=np.zeros((h,w),dtype=np.uint8);result[edge]=1
 for y in range(h):result[y,core[y]]=max(5,15-y*10//h)
 return result

def patch_win(before,at,x,y,font):
 after=bytearray(before);t=tim(before,at);pix=t['pixels'].copy();pix[y:y+24,x:x+56]=styled('WIN',56,24,font);rects=[(x,y,56,24)];replace_pixels(after,t,pix,rects)
 return bytes(after),dict(tim_offset=hex(at),rectangles=rects,text='WIN',native_palette=19 if at==0 else 47)

def vertical(text):
 result=np.zeros((96,80),dtype=np.uint8);core=np.zeros((96,80),dtype=bool)
 # Each original column is sampled as two 80x48 halves. Clear y=48 seam.
 # Place whole glyphs on each side; no glyph is cut by sprite assembly.
 halves=[text[:(len(text)+1)//2],text[(len(text)+1)//2:]]
 for half,word in enumerate(halves):
  step=48//len(word)
  for i,char in enumerate(word):
   glyph=np.repeat(np.repeat(bitmap(char),2,axis=0),5,axis=1)
   gh,gw=glyph.shape;y=half*48+i*step+(step-gh)//2;x=(80-gw)//2
   for row in range(gh):core[y+row,x:x+gw]=glyph[row]
 # Native announcement CLUT: 15 is cyan offset shadow, 1 is dark edge,
 # 4..10 is the red-to-orange face. Preserve these color roles.
 result[1:,2:][core[:-1,:-2]]=15
 edge=np.zeros_like(core)
 for dy in [-1,0,1]:
  for dx in [-1,0,1]:edge|=np.roll(np.roll(core,dy,0),dx,1)
 result[edge]=1
 for y in range(96):result[y,core[y]]=4+min(6,y*7//96)
 return result

def patch_exam_hud(before):
 after=bytearray(before);t=tim(before,0x10800);pix=t['pixels'].copy();rects=[]
 for x,text in [(256,'START'),(336,'FINISH')]:
  pix[:96,x:x+80]=vertical(text);rects.append((x,0,80,96))
 # Native term prefix uses two 16-pixel glyphs, each stored in a 24-wide cell.
 # Retain the decimal alphabet, colon, portraits, speech bubbles and palettes.
 for y,text in [(96,'TA'),(112,'SK')]:
  pix[y:y+16,184:208]=0;cell=pixel_label(text,16,16,15);core=cell>0;edge=np.zeros_like(core)
  for dy in [-1,0,1]:
   for dx in [-1,0,1]:edge|=np.roll(np.roll(core,dy,0),dx,1)
  cell[edge]=1;cell[core]=15;pix[y:y+16,184:200]=cell;rects.append((184,y,24,16))
 replace_pixels(after,t,pix,rects)
 return bytes(after),dict(tim_offset='0x10800',rectangles=rects,texts=['START','FINISH','TASK'],prefix_glyph_width=16,native_digits_colon_and_palettes_preserved=True)

def build(a):
 if a.master.stat().st_size!=663216960 or file_sha(a.master)!=MASTER:raise ValueError('Expected exact boot-tested v33 BIN')
 if a.output.exists():raise ValueError('Choose a new output directory')
 source=Disc(a.master);require_catalog(source);a.output.mkdir(parents=True);(a.output/'previews').mkdir();replacements={};reports=[]
 jobs=[(f'DAT2/MINITTL{k}.BIZ',patch_atlas)for k in '0123456789ABC']
 jobs += [('DAT2/MENU.BIZ',patch_points),('DAT2/SPRINT.BIZ',lambda b:patch_win(b,0,104,128,a.font)),('DAT2/CEFT5.BIZ',lambda b:patch_win(b,0x10800,592,232,a.font))]
 jobs += [(f'DAT2/CEFT{k}.BIZ',patch_exam_hud)for k in [4,6]]
 for name,patch in jobs:
  stored=source.record(name);before=decode(stored)[0];after,claim=patch(before);assert_owned(before,after,claim)
  encoded,profile=compress(after,stored,a.accelerator);replacements[name]=encoded
  at=int(claim['tim_offset'],16);palette=claim.get('native_palette',0)
  rgb_image(tim(after,at),palette).save(a.output/'previews'/(name.split('/')[-1]+'.png'))
  reports.append(dict(path=name,input_sha256=sha(stored),output_sha256=sha(encoded),claim=claim,compression=profile));print(name,'ready',flush=True)
 # Bind only changed resource signatures, preserving all loader code/positions/sizes.
 catalog=audit_catalog(source,replacements);exe=bytearray(source.record('SLPS_021.20'));bindings=[]
 for row in catalog['mismatches']:
  if row['path'] not in replacements:raise ValueError('unexpected catalog mismatch')
  p=row['signature_offset'];exe[p:p+4]=replacements[row['path']][:4];bindings.append(row)
 if bindings:replacements['SLPS_021.20']=bytes(exe)
 final_catalog=require_catalog(source,replacements)
 target=a.output/'justice-gakuen2-practice-layout-v34.bin';shutil.copyfile(a.master,target);changed={}
 with target.open('r+b')as f:
  for name,new in replacements.items():
   lba,size=source.records[name]
   if len(new)!=size:raise ValueError('record extent changed')
   for off in range(0,size,2048):
    sector=lba+off//2048;f.seek(sector*2352);raw=f.read(2352);s=bytearray(raw);part=new[off:off+2048];s[24:24+len(part)]=part
    if s!=raw:
     if regenerate(raw)!=raw:raise ValueError('source sector checksum')
     s=regenerate(s);f.seek(sector*2352);f.write(s);changed[sector]=s
 verify=Disc(target)
 for name in source.records:
  if verify.record(name)!=replacements.get(name,source.record(name)):raise ValueError('record readback/retention '+name)
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
 require_catalog(verify)
 if file_sha(a.master)!=MASTER:raise ValueError('master modified')
 target.with_suffix('.cue').write_bytes(f'FILE "{target.name}" BINARY\r\n  TRACK 01 MODE2/2352\r\n    INDEX 01 00:00:00\r\n'.encode())
 report=dict(kind='Practice layout and exam HUD v34',master_sha256=MASTER,output_sha256=file_sha(target),disc_bytes=target.stat().st_size,records=reports,catalog_rebindings=bindings,catalog_audit=final_catalog,changed_sector_count=len(changed),untargeted_records_preserved=947-len(replacements),title_and_exam_intro_and_replay_panels_unchanged=True,whole_image_sector_ownership_and_checksums_passed=True,native_gameplay='pending')
 (a.output/'practice-layout-v34-report.json').write_text(json.dumps(report,indent=2)+'\n');print('V34 COMPLETE',report['output_sha256'],flush=True)
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('master',type=Path);p.add_argument('output',type=Path);p.add_argument('--font',type=Path,required=True);p.add_argument('--accelerator');build(p.parse_args())
