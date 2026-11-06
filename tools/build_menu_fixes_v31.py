"""Apply the Current Points / replay fixes to the exact v30 candidate.

The full FIERY SPRINT strip and every earlier v30 interface are preserved.
No game data is embedded. Python 3.11+, Pillow and NumPy are required.
"""
import argparse,collections,json,shutil
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from practice_disc_v30 import Disc,decode,compress,sha,file_sha,regenerate
from build_practice_v30 import tim,rgb_image,replace_pixels,fitted
MASTER='c9fdc6a749084fdf972b4debb36dda6b77cb44e0b34f4161d27573130dc44815'
RECORDS={
 'DAT2/MENU.BIZ':'47b73374d061f3a5aa5073cf8b89246402c9e9ea384c722e44fca3edbccfa480',
 'DAT2/SPRINT.BIZ':'ef71b8eca77eda653f782f3da5961661a9a5fc07740cf341db3f3da8d765f856',
 'DAT2/DANCE.BIZ':'c9f7101db87397e5ced246c569dc188d2cde38ce568fa632603325b67d5b72e0',
 'DAT2/CEFT5.BIZ':'bd2c33fcdffb05ee673c71707310b93f80beae8eaaeda9c45d3cc1cb62778bb8'}
RETRIES=[('DAT2/SPRINT.BIZ',0,0,68,21),('DAT2/DANCE.BIZ',0,256,82,21),('DAT2/CEFT5.BIZ',0x10800,656,180,49)]
RECTS=[(10,8,94,22),(18,30,35,22),(58,30,44,22)]

def glyph_mask(text,w,h,fontpath,maxsize=13):
 im=Image.new('L',(w,h));d=ImageDraw.Draw(im);d.fontmode='1';font,b=fitted(d,text,w,h,fontpath,maxsize)
 d.text(((w-(b[2]-b[0]))//2-b[0],(h-(b[3]-b[1]))//2-b[1]),text,font=font,fill=255)
 return np.array(im)>127

def stamp(pix,box,text,fontpath,fill,outline=1):
 x,y,w,h=box;mask=glyph_mask(text,w-2,h-2,fontpath)
 core=np.zeros((h,w),dtype=bool);core[1:-1,1:-1]=mask;edge=np.zeros_like(core)
 for yy in [-1,0,1]:
  for xx in [-1,0,1]:edge|=np.roll(np.roll(core,yy,0),xx,1)
 region=pix[y:y+h,x:x+w];region[edge]=outline
 # Keep the native question and answer palette ramps separate.
 for row in range(h):region[row,core[row]]=fill if isinstance(fill,int) else fill[min(len(fill)-1,row*len(fill)//h)]
 return dict(text=text,cell=list(box),ink_pixels=int(core.sum()))

def patch_points(before,fontpath):
 after=bytearray(before);t=tim(before,0x22800)
 if (t['width'],t['height'],t['mode'])!=(1280,256,0):raise ValueError('mode-select atlas geometry changed')
 pix=t['pixels'].copy();x,y,w,h=544,224,80,24;old=pix[y:y+h,x:x+w].copy();pix[y:y+h,x:x+w]=0
 labels=[stamp(pix,(x,y,w,12),'CURRENT',fontpath,15),stamp(pix,(x,y+12,w,12),'POINTS',fontpath,15)]
 replace_pixels(after,t,pix,[(x,y,w,h)])
 return bytes(after),dict(kind='current-points',tim_offset='0x22800',rectangles=[[x,y,w,h]],source_pixel_sha256=sha(old.tobytes()),labels=labels)

def validate_retry(original,after):
 if original.shape!=(60,112)or after.shape!=original.shape:raise ValueError('retry panel geometry')
 writable=np.zeros(original.shape,dtype=bool)
 for x,y,w,h in RECTS:
  writable[y:y+h,x:x+w]=True;allowed={0,1,2,3,4,5,6,7,15}if y<30 else{0,1,8,9,10,11,12,15}
  if not set(after[y:y+h,x:x+w].ravel().tolist())<=allowed:raise ValueError('retry palette ramp changed')
 if np.any((original!=after)&~writable):raise ValueError('retry frame or background outside lettering changed')
 if np.array_equal(original,after):raise ValueError('retry panel unchanged')

def patch_retry(before,at,x,y,fontpath):
 after=bytearray(before);t=tim(before,at);original=t['pixels'][y:y+60,x:x+112].copy()
 if original.shape!=(60,112)or t['mode']!=0:raise ValueError('retry panel extent changed')
 panel=original.copy();labels=[]
 # Reconstruct each owned text rectangle with the exact source checkerboard
 # phase. Its two background indices are native 0 and 15.
 values={}
 for parity in [0,1]:
  samples=[int(original[yy,xx])for yy in range(4,56)for xx in range(4,108)if(xx+yy)%2==parity and original[yy,xx]in[0,15]]
  values[parity]=collections.Counter(samples).most_common(1)[0][0]
 if set(values.values())!={0,15}:raise ValueError('retry checkerboard binding changed')
 for box,text,ramp in zip(RECTS,['PLAY AGAIN?','YES','NO'],[[7,7,6,5,4,3],12,12]):
  a,b,w,h=box
  for yy in range(b,b+h):
   for xx in range(a,a+w):panel[yy,xx]=values[(xx+yy)%2]
  labels.append(stamp(panel,box,text,fontpath,ramp))
 validate_retry(original,panel);pix=t['pixels'].copy();pix[y:y+60,x:x+112]=panel;owned=[(x+a,y+b,w,h)for a,b,w,h in RECTS];replace_pixels(after,t,pix,owned)
 return bytes(after),dict(kind='replay',tim_offset=hex(at),rectangles=owned,panel=[x,y,112,60],source_pixel_sha256=sha(original.tobytes()),frame_unchanged=True,question_answer_palette_ramps_preserved=True,labels=labels)

def assert_owned(before,after,claim):
 t=tim(before,int(claim['tim_offset'],16));mask=bytearray(len(before));stride=t['width']//2
 for x,y,w,h in claim['rectangles']:
  # Pixel checks are nibble-exact; here byte ownership admits both nibbles
  # in boundary bytes. TIM metadata/palettes remain outside those ranges.
  for yy in range(y,y+h):
   a=t['offset']+yy*stride+x//2;b=t['offset']+yy*stride+(x+w+1)//2;mask[a:b]=b'\1'*(b-a)
 if len(before)!=len(after)or any(a!=b and not mask[i]for i,(a,b)in enumerate(zip(before,after))):raise ValueError('decoded write escaped owned lettering')

def build(a):
 if a.master.stat().st_size!=663216960 or file_sha(a.master)!=MASTER:raise ValueError('Expected exact v30 candidate; no files changed')
 if a.output.exists():raise ValueError('Choose a new output directory')
 font=a.font.resolve();ImageFont.truetype(str(font),16);source=Disc(a.master)
 if len(source.records)!=947:raise ValueError('ISO population changed')
 for name,expected in RECORDS.items():
  if sha(source.record(name))!=expected:raise ValueError('source record identity: '+name)
 a.output.mkdir(parents=True);(a.output/'previews').mkdir();replacements={};reports=[]
 for name in RECORDS:
  stored=source.record(name);before,sp=decode(stored)
  if name=='DAT2/MENU.BIZ':after,claim=patch_points(before,font);palette=0
  else:
   _,at,x,y,palette=next(r for r in RETRIES if r[0]==name);after,claim=patch_retry(before,at,x,y,font)
  assert_owned(before,after,claim);encoded,profile=compress(after,stored,a.accelerator);replacements[name]=encoded
  preview=rgb_image(tim(after,int(claim['tim_offset'],16)),palette);box=claim.get('panel',claim['rectangles'][0]);x,y,w,h=box;preview.crop((x,y,x+w,y+h)).resize((w*4,h*4),Image.Resampling.NEAREST).save(a.output/'previews'/(name.split('/')[-1]+'.png'))
  reports.append(dict(path=name,input_stored_sha256=sha(stored),output_stored_sha256=sha(encoded),input_decoded_sha256=sha(before),output_decoded_sha256=sha(after),claim=claim,compression=profile));print(name,'ready',flush=True)
 # Explicit retention proof for the full Sprint selection label from v30.
 diary=source.record('DAT2/MGCOCK.TIZ');dd=decode(diary)[0];strip=tim(dd,0)['pixels'][168:192,256:400];strip_hash=sha(strip.tobytes())
 target=a.output/'justice-gakuen2-menu-fixes-v31.bin';shutil.copyfile(a.master,target);changed={}
 with target.open('r+b')as f:
  for name,new in replacements.items():
   lba,size=source.records[name]
   if len(new)!=size:raise ValueError('record size changed')
   for off in range(0,size,2048):
    sector=lba+off//2048;f.seek(sector*2352);raw=f.read(2352);s=bytearray(raw);chunk=new[off:off+2048];s[24:24+len(chunk)]=chunk
    if s!=raw:
     if regenerate(raw)!=raw:raise ValueError('source sector checksum')
     s=regenerate(s);f.seek(sector*2352);f.write(s);changed[sector]=s
 verify=Disc(target)
 for name,new in replacements.items():
  if verify.record(name)!=new:raise ValueError('patched record readback')
 for name in source.records:
  if name not in replacements and verify.record(name)!=source.record(name):raise ValueError('unowned record changed: '+name)
 if verify.record('DAT2/MGCOCK.TIZ')!=diary:raise ValueError('Sprint label regressed')
 actual=[]
 with a.master.open('rb')as left,target.open('rb')as right:
  lba=0
  while True:
   x=left.read(2352*1024);y=right.read(2352*1024)
   if len(x)!=len(y):raise ValueError('disc length changed')
   if not x:break
   for i in range(0,len(x),2352):
    if x[i:i+2352]!=y[i:i+2352]:
     n=lba+i//2352;actual.append(n)
     if n not in changed or regenerate(y[i:i+2352])!=y[i:i+2352]:raise ValueError('unowned sector or invalid checksum')
   lba+=len(x)//2352
 if actual!=sorted(changed):raise ValueError('sector accounting')
 if file_sha(a.master)!=MASTER:raise ValueError('master modified')
 outsha=file_sha(target);target.with_suffix('.cue').write_bytes(f'FILE "{target.name}" BINARY\r\n  TRACK 01 MODE2/2352\r\n    INDEX 01 00:00:00\r\n'.encode())
 report=dict(kind='Menu fixes v31',master_sha256=MASTER,output_sha256=outsha,disc_bytes=target.stat().st_size,font_sha256=file_sha(font),records=reports,retry_panels=3,minigames_covered=6,changed_sector_count=len(changed),earlier_v30_records_unchanged=True,sprint_strip_sha256=strip_hash,sprint_native_width=144,decoded_lettering_ownership_and_palettes_preserved=True,all_943_untargeted_records_unchanged=True,whole_image_sector_ownership_and_edc_ecc_passed=True,native_gameplay='pending',title_screen_changed=False)
 (a.output/'menu-fixes-v31-report.json').write_text(json.dumps(report,indent=2)+'\n');print('V31 COMPLETE',outsha,flush=True)
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('master',type=Path);p.add_argument('output',type=Path);p.add_argument('--font',type=Path,required=True);p.add_argument('--accelerator');build(p.parse_args())
