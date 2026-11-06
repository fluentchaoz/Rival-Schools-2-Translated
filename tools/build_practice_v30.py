"""Build six English practice interfaces from the exact recovered v29 disc.

Requires Python 3.11+, Pillow and NumPy. No original game data is embedded.
Usage: python tools/build_practice_v30.py v29.bin new-output --font font.ttf
Optional accelerator: --accelerator /path/to/practice_lz shared library.
"""
import argparse,json,shutil,struct,textwrap
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from practice_disc_v30 import Disc,sha,file_sha,decode,compress,regenerate
MASTER='f4f974c40220dd82925d4b17d6a31b3f95218a6017783666851204ea3040c67f'
GAMES={
 '5':dict(name='HOME RUN CONTEST',bubble=[256,137,493,282],color=[255,74,82],rules=[[
 ('RULES','Face 10 pitches. Your five longest hits count toward your total distance. Fouls and missed swings count as 0 m.'),
 ('CONTROLS','D-PAD: Move the batter up, down, left or right to choose your position.\nCIRCLE: Swing the bat.')]]),
 '6':dict(name='PK SHOOTOUT',bubble=[251,117,488,261],color=[255,164,32],rules=[[
 ('RULES','Take five penalty kicks each. The player with the most goals wins.'),
 ('KICKER CONTROLS','D-PAD: Aim the shot.\nPress any face button to begin your run-up.\nBefore the kick, use the D-pad to bend the ball.'),
 ('SHOT BUTTONS','CROSS: Hard shot\nCIRCLE: Soft shot\nTRIANGLE / SQUARE: Explosive Goal (uses GUTS)\nL1: Show / hide the aim gauge\nR1: Change the camera view')],[
 ('GOALKEEPER','D-PAD LEFT / RIGHT: Move the keeper.\nD-PAD + a face button: Attempt a save. The button determines the save.'),
 ('SAVE BUTTONS','TRIANGLE: Strong Shining Save (uses GUTS)\nCROSS: Strong save\nCIRCLE: Weak save\nSQUARE: Weak Shining Save (uses GUTS)'),
 ('AIM GAUGE','The gauge shows the horizontal and vertical angles of the shot.')]]),
 '7':dict(name='EXPLOSIVE SHOT',bubble=[24,106,263,250],color=[16,205,164],rules=[[
 ('RULES','Knock down the scoring panels in the goal. Your total over six balls counts. Hit the goalposts to knock panels down for frame points. Curve the ball for style points.'),
 ('CONTROLS','D-PAD: Aim the shot.\nCIRCLE or CROSS: Begin your run-up.\nBefore the kick, use the D-pad to bend the ball.'),
 ('BUTTONS','CIRCLE: Hard shot\nCROSS: Soft shot\nL1: Change the camera view')]]),
 '8':dict(name='SERVICE ACE',bubble=[257,127,495,272],color=[90,189,41],rules=[[
 ('RULES','Aim serves at the character faces and catch them in the blast to score. Your total over eight serves counts.'),
 ('CONTROLS','1. D-PAD LEFT / RIGHT: Aim your serve.\n2. Press CIRCLE to set the power.\n3. Hold the button to choose the vertical launch angle.\n4. Release the button to serve.'),
 ('GAUGES','POWER: Sets the strength of your serve.\nVERTICAL ANGLE: Sets how high you hit the serve.')]]),
 'B':dict(name='FIERY SPRINT',bubble=[254,125,492,269],color=[255,222,32],rules=[[
 ('RULES','Race for the best time over 100 m. Time your button presses to the speed gauge to accelerate.'),
 ('START','Press CIRCLE or CROSS with the starting countdown. Starting before the countdown reaches 0 is a false start.'),
 ('ACCELERATE','Press CIRCLE or CROSS in time with the speed gauge. Good timing builds speed; do not simply mash the buttons.')]]),
 'C':dict(name='DOKI-WAKU-DANCE',bubble=[235,127,474,272],color=[255,131,222],rules=[[
 ('RULES','Watch which buttons light up while your partner dances. On your turn, repeat the same buttons. Take turns and build your affection by matching the sequence and timing.'),
 ('CONTROLS','1. Watch the buttons light up in order during your partner\'s dance.\n2. When your turn begins, repeat those buttons in the same order.'),
 ('AFFECTION GAUGE','Successful dancing raises the gauge.')]])}
LABELS=[
 (0,0,200,'HOME RUN CONTEST'),(0,24,152,'PK SHOOTOUT'),(0,48,216,'EXPLOSIVE SHOT'),(0,72,184,'SERVICE ACE'),
 (0,96,144,'GAME START'),(144,96,48,'BACK'),(0,120,160,'1P START'),(0,144,160,'VS START'),
 (0,168,160,'RULES & CONTROLS'),(160,168,96,'HOME RUN'),(0,192,120,'BEST RECORD'),(120,192,16,'P'),
 (160,192,32,'BATSU'),(192,192,48,'SHOMA'),(0,216,160,'CURRENT BEST'),(160,216,16,'P'),(192,216,24,'HYO'),(216,216,24,'GAN'),
 (512,0,208,'RETURN TO MODE MENU'),(512,48,208,'FIERY SPRINT'),(512,168,104,'WATCH MODE')]

def tim(data,at):
 if data[at:at+4]!=b'\x10\0\0\0':raise ValueError('TIM identity')
 flags=struct.unpack_from('<I',data,at+4)[0]
 if flags not in (8,9):raise ValueError('expected indexed TIM')
 n,_,_,cw,ch=struct.unpack_from('<IHHHH',data,at+8);pal_at=at+20
 if n!=12+cw*ch*2:raise ValueError('palette geometry')
 pal=np.array(struct.unpack_from('<'+'H'*(cw*ch),data,pal_at),dtype=np.int32);q=at+8+n
 size,x,y,w,h=struct.unpack_from('<IHHHH',data,q);width=w*(4 if flags==8 else 2)
 if size!=12+w*h*2 or q+size>len(data):raise ValueError('TIM extent')
 raw=np.frombuffer(data[q+12:q+size],dtype=np.uint8)
 if flags==8:
  pix=np.empty(raw.size*2,dtype=np.uint8);pix[::2]=raw&15;pix[1::2]=raw>>4
 else:pix=raw.copy()
 return dict(at=at,mode=flags&7,width=width,height=h,offset=q+12,palette=pal,palette_offset=pal_at,pixels=pix.reshape(h,width),x=x,y=y)

def rgb_palette(t,p=0):
 pal=t['palette'][p*(16 if t['mode']==0 else 256):(p+1)*(16 if t['mode']==0 else 256)]
 return np.stack([(pal&31)*255//31,((pal>>5)&31)*255//31,((pal>>10)&31)*255//31],axis=1).astype(np.uint8)
def rgb_image(t,p=0):return Image.fromarray(rgb_palette(t,p)[t['pixels']])
def replace_pixels(data,t,pix,owned):
 before=t['pixels'];mask=np.zeros(before.shape,dtype=bool)
 for x,y,w,h in owned:
  if x<0 or y<0 or x+w>t['width'] or y+h>t['height']:raise ValueError('rectangle bounds')
  mask[y:y+h,x:x+w]=True
 if np.any((before!=pix)&~mask):raise ValueError('pixel write escaped owned rectangles')
 raw=pix.ravel()
 if t['mode']==0:raw=raw[::2]|(raw[1::2]<<4)
 data[t['offset']:t['offset']+raw.size]=raw.tobytes()
 # Verify metadata, palette and all bytes outside pixel data are untouched by caller.

def fitted(draw,text,width,height,fontpath,maxsize=24,minsize=5):
 for size in range(maxsize,minsize-1,-1):
  font=ImageFont.truetype(str(fontpath),size);b=draw.textbbox((0,0),text,font=font,stroke_width=1)
  if b[2]-b[0]+2<=width and b[3]-b[1]+2<=height:return font,b
 raise ValueError('text cannot fit: '+text)

def paint_text(im,box,text,fontpath,fill,outline=None,maxsize=24):
 x,y,w,h=box;d=ImageDraw.Draw(im)
 if im.mode=='L':d.fontmode='1'
 font,b=fitted(d,text,w,h,fontpath,maxsize)
 d.text((x+(w-(b[2]-b[0]))//2-b[0],y+(h-(b[3]-b[1]))//2-b[1]),text,font=font,fill=fill,stroke_width=1 if outline is not None else 0,stroke_fill=outline)

def quantize(im,pal):
 a=np.array(im,dtype=np.int32);colors=pal.astype(np.int32);out=np.empty(a.shape[:2],dtype=np.uint8)
 for y in range(a.shape[0]):out[y]=np.argmin(((a[y,:,None,:]-colors[None,:,:])**2).sum(axis=2),axis=1)
 return out

def patch_labels(data,fontpath):
 t=tim(data,0)
 if (t['width'],t['height'],t['mode'])!=(768,256,0):raise ValueError('shared atlas geometry')
 pix=t['pixels'].copy();owned=[];previews=[]
 for x,y,w,text in LABELS:
  im=Image.new('L',(w,24),0);paint_text(im,(0,0,w,24),text,fontpath,14,1,20)
  pix[y:y+24,x:x+w]=np.array(im);owned.append((x,y,w,24));previews.append({'text':text,'cell':[x,y,w,24]})
 replace_pixels(data,t,pix,owned);return owned,previews

def patch_landing(data,game,fontpath):
 t=tim(data,0x18800)
 if (t['width'],t['height'],t['mode'])!=(512,480,1):raise ValueError('landing geometry')
 pal=rgb_palette(t);im=rgb_image(t);original=np.array(im);d=ImageDraw.Draw(im)
 # Deliberate English title panel occupies the original heading/stamp region.
 box=(16,20,484,100);d.rounded_rectangle((16,20,499,119),radius=8,fill=(25,18,25),outline=(255,222,90),width=2)
 paint_text(im,(24,29,468,46),game['name'],fontpath,(255,235,130),(0,0,0),32)
 paint_text(im,(24,78,468,27),'PRACTICE',fontpath,(255,255,255),(0,0,0),19)
 x0,y0,x1,y1=game['bubble'];cx=(x0+x1)//2;cy=(y0+y1)//2;color=tuple(game['color'])
 d=ImageDraw.Draw(im);d.rounded_rectangle((x0,y0,x1,y1),radius=9,fill=color,outline=(25,18,25),width=2)
 lines=['Good thinking!','Practice hard so',"you\'re ready for",'the real thing!']
 for i,line in enumerate(lines):paint_text(im,(cx-95,cy-38+i*19,190,19),line,fontpath,(255,255,255),(0,0,0),15)
 # Quantize only owned rectangles; untouched pixels retain exact original indices.
 pix=t['pixels'].copy();owned=[box,(x0,y0,x1-x0+1,y1-y0+1)];q=quantize(im,pal)
 for x,y,w,h in owned:pix[y:y+h,x:x+w]=q[y:y+h,x:x+w]
 replace_pixels(data,t,pix,owned);return owned

def wrapped(draw,text,font,width):
 result=[]
 for paragraph in text.split('\n'):
  line=''
  for word in paragraph.split():
   trial=(line+' '+word).strip()
   if draw.textlength(trial,font=font)>width and line:result.append(line);line=word
   else:line=trial
  result.append(line)
 return result

def rules_panel(data,game,page,fontpath):
 at=0x55000 if page==0 else 0x91800;t=tim(data,at)
 if (t['width'],t['height'],t['mode'])!=(512,480,1):raise ValueError('rules geometry')
 im=rgb_image(t);d=ImageDraw.Draw(im);d.rounded_rectangle((12,20,499,475),radius=8,fill=(25,18,30),outline=(255,222,90),width=2)
 title=game['name']+' - RULES'
 paint_text(im,(24,29,464,36),title,fontpath,(255,235,130),(0,0,0),22)
 sections=game['rules'][page]
 for size in range(17,12,-1):
  font=ImageFont.truetype(str(fontpath),size);layout=[];y=87
  for heading,body in sections:
   lines=wrapped(d,body,font,454);layout.append((heading,lines,y));y+=26+len(lines)*(size+4)+17
  if y<=437:break
 else:raise ValueError('rules page overflow')
 for heading,lines,y in layout:
  d.text((28,y),heading,font=ImageFont.truetype(str(fontpath),17),fill=(255,222,90));y+=26
  for line in lines:d.text((28,y),line,font=font,fill=(255,255,255));y+=size+4
 footer=('CIRCLE: NEXT   ' if len(game['rules'])>1 and page==0 else 'CIRCLE: PREVIOUS   ' if page else '')+'CROSS / START: BACK'
 paint_text(im,(22,444,468,23),footer,fontpath,(255,235,130),None,14)
 pix=t['pixels'].copy();q=quantize(im,rgb_palette(t));pix[20:476,12:500]=q[20:476,12:500];owned=[(12,20,488,456)];replace_pixels(data,t,pix,owned);return owned

def run(a):
 if file_sha(a.master)!=MASTER or a.master.stat().st_size!=663216960:raise ValueError('expected recovered v29 image')
 if a.output.exists():raise ValueError('output already exists; choose a new directory')
 fontpath=a.font.resolve();ImageFont.truetype(str(fontpath),16);disc=Disc(a.master)
 if len(disc.records)!=947:raise ValueError('ISO population changed')
 a.output.mkdir(parents=True);(a.output/'previews').mkdir();replacements={};reports=[];shared=None
 for key in '0123456789ABC':
  name=f'DAT2/MINITTL{key}.BIZ';stored=disc.record(name);before,sp=decode(stored)
  if sha(before[:0x18800])!='fdf7e3570a22668e169a297a901dcc5a6b747aaae0c911b1e1ac0ec20b8b50cf':raise ValueError('shared atlas source identity')
  after=bytearray(before);claims=[];owned,labels=patch_labels(after,fontpath);claims.append((0,owned))
  if key in GAMES:
   g=GAMES[key];claims.append((0x18800,patch_landing(after,g,fontpath)))
   for page in range(len(g['rules'])):claims.append((0x55000 if page==0 else 0x91800,rules_panel(after,g,page,fontpath)))
   for i,at in enumerate([0x18800]+[0x55000]+([0x91800]if len(g['rules'])>1 else [])):rgb_image(tim(after,at)).save(a.output/'previews'/f'{key}-{i}.png')
  mask=bytearray(len(before))
  for at,rects in claims:
   t=tim(before,at);stride=t['width']//(2 if t['mode']==0 else 1)
   for x,y,w,h in rects:
    for yy in range(y,y+h):
     start=t['offset']+yy*stride+x//(2 if t['mode']==0 else 1);n=w//(2 if t['mode']==0 else 1);mask[start:start+n]=b'\1'*n
  if any(x!=y and not mask[i] for i,(x,y)in enumerate(zip(before,after))):raise ValueError('decoded byte ownership violated')
  encoded,compression=compress(bytes(after),stored,a.accelerator)
  replacements[name]=encoded;reports.append(dict(path=name,input_stored_sha256=sha(stored),input_decoded_sha256=sha(before),output_stored_sha256=sha(encoded),output_decoded_sha256=sha(after),claims=[dict(tim_offset=hex(at),rectangles=rects)for at,rects in claims],compression=compression))
  print(name,'ready',flush=True)
 # The native Diary sprint row consumes 144 pixels, not the full 152-pixel wording.
 name='DAT2/MGCOCK.TIZ';stored=disc.record(name);before,sp=decode(stored);after=bytearray(before);t=tim(before,0)
 if (t['width'],t['height'],t['mode'])!=(1024,256,0):raise ValueError('Diary atlas geometry')
 pix=t['pixels'].copy();im=Image.new('L',(144,24),0);paint_text(im,(0,0,144,24),'FIERY SPRINT',fontpath,14,1,19);pix[168:192,256:408]=0;pix[168:192,256:400]=np.array(im)
 replace_pixels(after,t,pix,[(256,168,152,24)]);encoded,pr=compress(bytes(after),stored,a.accelerator);replacements[name]=encoded
 reports.append(dict(path=name,input_stored_sha256=sha(stored),output_stored_sha256=sha(encoded),compression=pr,claims=[dict(tim_offset='0x0',rectangles=[[256,168,152,24]],native_consumed_width=144)]))
 # Every changed byte belongs to one named record. Source files stay read-only.
 output=a.output/'justice-gakuen2-practice-v30.bin';shutil.copyfile(a.master,output);changed={}
 with output.open('r+b') as f:
  for name,new in replacements.items():
   lba,size=disc.records[name]
   if len(new)!=size:raise ValueError('record length changed')
   for off in range(0,size,2048):
    sector=lba+off//2048;f.seek(sector*2352);raw=f.read(2352);s=bytearray(raw);part=new[off:off+2048];s[24:24+len(part)]=part
    if s!=raw:
     s=regenerate(s)
     if regenerate(raw)!=raw:raise ValueError('source sector integrity failed')
     f.seek(sector*2352);f.write(s);changed[sector]=s
 verify=Disc(output)
 for name,new in replacements.items():
  if verify.record(name)!=new:raise ValueError('disc record readback failed')
 # Independent whole-image comparison must find exactly the written sectors.
 actual=[]
 with a.master.open('rb') as left,output.open('rb') as right:
  sector=0
  while True:
   x=left.read(2352*1024);y=right.read(2352*1024)
   if not x:break
   if len(x)!=len(y):raise ValueError('disc length changed')
   for p in range(0,len(x),2352):
    if x[p:p+2352]!=y[p:p+2352]:
     sn=sector+p//2352;actual.append(sn)
     if sn not in changed or regenerate(y[p:p+2352])!=y[p:p+2352]:raise ValueError('sector ownership/integrity failed')
   sector+=len(x)//2352
 if sorted(changed)!=actual:raise ValueError('changed-sector accounting')
 if file_sha(a.master)!=MASTER:raise ValueError('master changed')
 outsha=file_sha(output);cue=output.with_suffix('.cue');cue.write_bytes(f'FILE "{output.name}" BINARY\r\n  TRACK 01 MODE2/2352\r\n    INDEX 01 00:00:00\r\n'.encode())
 report=dict(kind='Practice interfaces v30',master_sha256=MASTER,output_sha256=outsha,disc_bytes=output.stat().st_size,font_sha256=file_sha(fontpath),records=reports,practice_games=6,rules_pages=7,shared_menu_copies=13,changed_sector_count=len(changed),native_gameplay='pending',code_and_save_records_unchanged=True,source_profile_limits_and_final_input_pages_preserved=True,changed_sector_ownership_and_checksums_passed=True)
 (a.output/'practice-v30-report.json').write_text(json.dumps(report,indent=2)+'\n')
 print('V30 COMPLETE',outsha,flush=True)
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('master',type=Path);p.add_argument('output',type=Path);p.add_argument('--font',type=Path,required=True);p.add_argument('--accelerator');run(p.parse_args())
