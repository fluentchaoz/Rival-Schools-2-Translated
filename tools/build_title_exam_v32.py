"""Install the supplied title art and repair native UI/exam layouts on exact v31."""
import argparse,collections,json,shutil,struct
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from practice_disc_v30 import Disc,decode,compress,sha,file_sha,regenerate
from native_resource_catalog import require_catalog
from build_practice_v30 import tim,rgb_image,rgb_palette,replace_pixels,quantize
from build_menu_fixes_v31 import RETRIES,RECTS,stamp,assert_owned
MASTER='f9a3d199c9f535188258203b3a4ddea159755fe35b52e88a8c0c273871b7e7f2'
# Native first-term body reconstructed from the reported frame: sequential
# 32x16 source tiles 8..53, regrouped into 9/7/13/9/8 tiles per display row.
EXAM_ROWS=[9,7,13,9,8]
EXAM_LINES=["Dodge Hideo's energy waves",'and touch Hideo!','Use sidesteps and dashes','to get past his shots.','Master those moves!']

def patch_points(before,fontpath):
 after=bytearray(before);t=tim(before,0x22800);pix=t['pixels'].copy();x,y,w,h=544,224,80,24
 # Keep the entire one-line label within the top 16 source rows, avoiding
 # dependence on the unverified lower rows that clipped in the native frame.
 im=Image.new('L',(160,16),0);d=ImageDraw.Draw(im);d.fontmode='1';font=ImageFont.truetype(str(fontpath),14);text='CURRENT POINTS';b=d.textbbox((0,0),text,font=font,stroke_width=1);rw=b[2]-b[0]+2
 im=Image.new('L',(rw,16),0);d=ImageDraw.Draw(im);d.fontmode='1';d.text((1-b[0],(16-(b[3]-b[1]))//2-b[1]),text,font=font,fill=15,stroke_width=1,stroke_fill=1)
 im=im.resize((78,16),Image.Resampling.NEAREST);pix[y:y+24,x:x+80]=0;pix[y:y+16,x+1:x+79]=np.array(im)
 replace_pixels(after,t,pix,[(x,y,w,h)])
 if np.any(pix[y+16:y+24,x:x+80]):raise ValueError('points label exceeds safe native height')
 return bytes(after),dict(kind='points-single-line',tim_offset='0x22800',rectangles=[[x,y,w,h]],safe_native_rows=16,text=text)

def patch_retry_alignment(before,at,x,y,fontpath):
 after=bytearray(before);t=tim(before,at);panel=t['pixels'][y:y+60,x:x+112].copy();old=panel.copy();roles={}
 for parity in [0,1]:
  values=[int(panel[yy,xx])for yy in range(4,56)for xx in range(4,108)if(xx+yy)%2==parity and panel[yy,xx]in[0,15]];roles[parity]=collections.Counter(values).most_common(1)[0][0]
 if set(roles.values())!={0,15}:raise ValueError('checkerboard phase changed')
 reports=[]
 # Original Japanese ink centers, measured in all three original native panels:
 # YES (33.5,42), NO (76.5,42). Match these anchors, not the full source-cell center.
 for box,text,anchor in [(RECTS[1],'YES',(33.5,42)),(RECTS[2],'NO',(76.5,42))]:
  a,b,w,h=box
  for yy in range(b,b+h):
   for xx in range(a,a+w):panel[yy,xx]=roles[(xx+yy)%2]
  layer=np.zeros((60,112),dtype=np.uint8);stamp(layer,box,text,fontpath,12);ys,xs=np.where(layer==12);dx=round(anchor[0]-(xs.min()+xs.max())/2);dy=round(anchor[1]-(ys.min()+ys.max())/2);yy,xx=np.where(layer!=0);nx=xx+dx;ny=yy+dy
  if np.any((nx<a)|(nx>=a+w)|(ny<b)|(ny>=b+h)):raise ValueError('aligned answers leave owned cell')
  panel[ny,nx]=layer[yy,xx];ys,xs=np.where((panel==12)&(np.indices(panel.shape)[1]>=a)&(np.indices(panel.shape)[1]<a+w)&(np.indices(panel.shape)[0]>=b)&(np.indices(panel.shape)[0]<b+h));center=[float((xs.min()+xs.max())/2),float((ys.min()+ys.max())/2)]
  if center!=list(anchor):raise ValueError('native answer anchor mismatch')
  reports.append(dict(text=text,shift=[dx,dy],ink_center=center))
 if not np.array_equal(old[8:30,10:104],panel[8:30,10:104]):raise ValueError('question changed')
 pix=t['pixels'].copy();pix[y:y+60,x:x+112]=panel;rects=[(x+a,y+b,w,h)for a,b,w,h in RECTS[1:]];replace_pixels(after,t,pix,rects)
 return bytes(after),dict(kind='replay-native-alignment',tim_offset=hex(at),rectangles=rects,panel=[x,y,112,60],answers=reports)

def patch_title(before,imagepath):
 after=bytearray(before);t=tim(before,0x6000)
 if (t['width'],t['height'],t['mode'])!=(512,480,1):raise ValueError('title image geometry')
 # Main picture only. Keep original English copyright pixels and the entire
 # lower 80 rows intact; PRESS START is a separate runtime element.
 im=Image.open(imagepath).convert('RGB').resize((512,480),Image.Resampling.LANCZOS)
 newrgb=np.array(im,dtype=np.float32);oldrgb=np.array(rgb_image(t),dtype=np.float32)
 for yy in range(384,400):
  weight=(400-yy)/16;newrgb[yy]=newrgb[yy]*weight+oldrgb[yy]*(1-weight)
 q=quantize(Image.fromarray(np.rint(newrgb).astype(np.uint8)),rgb_palette(t));pix=t['pixels'].copy();pix[:400]=q[:400]
 replace_pixels(after,t,pix,[(0,0,512,400)])
 if after[:t['offset']]!=before[:t['offset']] or not np.array_equal(pix[400:],t['pixels'][400:]):raise ValueError('title prefix/palette/footer changed')
 return bytes(after),dict(kind='supplied-title-screen',tim_offset='0x6000',rectangles=[[0,0,512,400]],image_sha256=file_sha(imagepath),original_audio_headers_palettes_and_lower_80_rows_preserved=True,runtime_start_prompt_unchanged=True)

def exam_tiles(decoded):return tim(decoded,0)['pixels']
def unpack_exam(decoded):
 pix=exam_tiles(decoded);canvas=np.zeros((80,416),dtype=np.uint8);tile=8
 for row,n in enumerate(EXAM_ROWS):
  for col in range(n):canvas[row*16:row*16+16,col*32:col*32+32]=pix[tile//8*16:tile//8*16+16,tile%8*32:tile%8*32+32];tile+=1
 return canvas

def patch_exam_member(before,fontpath):
 after=bytearray(before);t=tim(before,0);pix=t['pixels'].copy()
 if (t['width'],t['height'],t['mode'])!=(256,256,0):raise ValueError('exam TIM geometry')
 canvas=Image.new('L',(416,80),0);d=ImageDraw.Draw(canvas);d.fontmode='1';font=ImageFont.truetype(str(fontpath),13)
 for row,(n,line)in enumerate(zip(EXAM_ROWS,EXAM_LINES)):
  box=d.textbbox((0,0),line,font=font)
  if box[2]-box[0]+4>n*32 or box[3]-box[1]>14:raise ValueError('exam line exceeds native row')
  d.text((2,row*16+1-box[1]),line,font=font,fill=1)
 target=np.array(canvas);tile=8;rects=[]
 for row,n in enumerate(EXAM_ROWS):
  for col in range(n):
   x=tile%8*32;y=tile//8*16;pix[y:y+16,x:x+32]=target[row*16:row*16+16,col*32:col*32+32];rects.append((x,y,32,16));tile+=1
 # The term title's native consumer admits 160 pixels.
 header=Image.new('L',(256,16),0);hd=ImageDraw.Draw(header);hd.fontmode='1';hf=ImageFont.truetype(str(fontpath),12);hd.text((2,0),'FIRST TERM EXAM',font=hf,fill=1);pix[:16]=np.array(header);rects.append((0,0,256,16));replace_pixels(after,t,pix,rects)
 if not np.array_equal(unpack_exam(after),target):raise ValueError('exam tile repack readback')
 return bytes(after),dict(member=30,source_tiles=list(range(8,54)),row_tile_counts=EXAM_ROWS,lines=EXAM_LINES,source_layout_evidence='Native screenshot: first-term instruction; source reconstruction visually matched all five lines',tim_offset='0x0',rectangles=rects,other_tiles_and_palette_preserved=True)

def patch_exam_archive(stored,fontpath,accelerator):
 p=0;entries=[]
 while True:
  off,size=struct.unpack_from('<II',stored,p);p+=8
  if off==size==0:break
  entries.append((off,size))
 if len(entries)!=33:raise ValueError('exam archive member count changed')
 at,size=entries[30];original=stored[at:at+size];before,_=decode(original);after,claim=patch_exam_member(before,fontpath);encoded,profile=compress(after,original,accelerator);result=bytearray(stored);result[at:at+size]=encoded
 if result[:at]!=stored[:at]or result[at+size:]!=stored[at+size:]:raise ValueError('unowned exam member/table changed')
 return bytes(result),dict(kind='first-term-exam',member_claim=claim,compression=profile,member_table_and_other_32_members_unchanged=True)

def build(a):
 if a.master.stat().st_size!=663216960 or file_sha(a.master)!=MASTER:raise ValueError('Expected exact v31 BIN')
 if a.output.exists():raise ValueError('Output already exists')
 font=a.font.resolve();ImageFont.truetype(str(font),16);source=Disc(a.master);a.output.mkdir(parents=True);(a.output/'previews').mkdir();replacements={};reports=[]
 for name in ['DAT2/MENU.BIZ']+[r[0]for r in RETRIES]+['DAT2/TITLE.BIZ','DAT2/TESTMJ.TIZ']:
  stored=source.record(name)
  if name=='DAT2/TESTMJ.TIZ':
   encoded,claim=patch_exam_archive(stored,font,a.accelerator);profile=None
   # Preview the actual rearranged body, not the packed source atlas.
   off,size=struct.unpack_from('<II',encoded,30*8);dec=decode(encoded[off:off+size])[0];canvas=unpack_exam(dec);pal=rgb_palette(tim(dec,0));pal[0]=255;Image.fromarray(pal[canvas]).resize((832,240),Image.Resampling.NEAREST).save(a.output/'previews'/'first-term-exam.png')
  else:
   before,_=decode(stored)
   if name=='DAT2/MENU.BIZ':after,claim=patch_points(before,font);palette=0;box=claim['rectangles'][0]
   elif name=='DAT2/TITLE.BIZ':after,claim=patch_title(before,a.title_image);palette=0;box=[0,0,512,480]
   else:
    _,at,x,y,palette=next(r for r in RETRIES if r[0]==name);after,claim=patch_retry_alignment(before,at,x,y,font);box=claim['panel']
   if name!='DAT2/TITLE.BIZ':assert_owned(before,after,claim)
   encoded,profile=compress(after,stored,a.accelerator);preview=rgb_image(tim(after,int(claim['tim_offset'],16)),palette);x,y,w,h=box;preview.crop((x,y,x+w,y+h)).save(a.output/'previews'/(name.split('/')[-1]+'.png'))
  replacements[name]=encoded;reports.append(dict(path=name,input_sha256=sha(stored),output_sha256=sha(encoded),claim=claim,compression=profile));print(name,'ready',flush=True)
 # Gate reproduction of the withdrawn v32: old image/CRC checks missed loader signatures.
 require_catalog(source,replacements)
 target=a.output/'justice-gakuen2-title-exam-v32.bin';shutil.copyfile(a.master,target);changed={}
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
 report=dict(kind='Title/exam/layout v32',master_sha256=MASTER,output_sha256=outsha,disc_bytes=target.stat().st_size,title_image_sha256=file_sha(a.title_image),font_sha256=file_sha(font),records=reports,changed_sector_count=len(changed),all_941_untargeted_iso_records_unchanged=True,native_gameplay='pending',checksums_and_sector_ownership_passed=True,exam_scope='First-term introduction member 30 only; other 32 members retained',title_scope='Supplied artwork installed above row 400; original audio, palette, copyright and runtime prompt preserved')
 (a.output/'title-exam-v32-report.json').write_text(json.dumps(report,indent=2)+'\n');print('V32 COMPLETE',outsha,flush=True)
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('master',type=Path);p.add_argument('output',type=Path);p.add_argument('--title-image',type=Path,required=True);p.add_argument('--font',type=Path,required=True);p.add_argument('--accelerator');build(p.parse_args())
