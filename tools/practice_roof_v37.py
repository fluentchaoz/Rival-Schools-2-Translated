"""Source-bound v37 loading, Guts, pause descriptors and rooftop contributions."""
import json,re,struct
from pathlib import Path
import numpy as np
from PIL import Image
from practice_disc_v30 import sha,file_sha,decode
from build_practice_v30 import tim,rgb_palette,replace_pixels,quantize
from build_exam_dance_v35 import raster,ink
from menu_art_v36 import pack,unpack
from backup_text_v36 import banks,tokens,compact,ARENA,LIMIT
HEADER=bytes([0,9,1,0,2,2,0,3,1]);RESUME=bytes([1,3,1,0,4,2,0,5,1]);BACK=bytes([1,8,1,0,5,1])
PAUSE_MAP={HEADER:bytes([0,12,1,0,13,2,1,12,1]),RESUME:bytes([0,14,1,0,15,2,1,14,1]),BACK:bytes([0,16,1,1,16,1])}

def patch_pause_overlay(before):
 after=bytearray(before);owned=[];hits=[]
 for pat,new in PAUSE_MAP.items():
  p=0
  while True:
   p=before.find(pat,p)
   if p<0:break
   if pat==HEADER:
    if before[p-5:p-3]!=bytes([5,4])or before[p-3:p]not in (bytes([0,0,1]),bytes([1,0,1])):raise ValueError('header descriptor context')
   else:
    expected=bytes([4,3])if pat==RESUME else bytes([2,2])
    if before[p-2:p]!=expected:raise ValueError('pause choice descriptor context')
   after[p:p+len(pat)]=new;owned.extend(range(p,p+len(pat)));hits.append(dict(offset=p,before=pat.hex(),after=new.hex()));p+=len(pat)
 counts=sorted(len([h for h in hits if h['before']==p.hex()])for p in PAUSE_MAP)
 if hits and counts==[0,1,2]:
  # Main executable's equivalent second action is a longer mode-return label.
  # Rebind its descriptor to BACK; retain the original data extent and action.
  mode=bytes.fromhex('0a080007010102010107010001020106010102010008020005010000')
  p=before.find(mode)
  if p<0 or before.find(mode,p+1)>=0:raise ValueError('main pause return descriptor')
  new=bytes([2,2,0,16,1,1,16,1]);after[p:p+8]=new;owned.extend(range(p,p+8));hits.append(dict(offset=p,before=before[p:p+8].hex(),after=new.hex(),kind='main-pause-mode-return'))
 elif hits and counts!=[1,1,2]:raise ValueError('pause menu population')
 if any(a!=b and i not in owned for i,(a,b)in enumerate(zip(before,after))):raise ValueError('pause writes escaped descriptor data')
 return bytes(after),hits

def patch_pause_texture(before,font):
 after=bytearray(before);t=tim(before,0);pix=t['pixels'].copy();rects=[]
 for text,w,parts in [
 ('P PAUSE',96,[(192,144,24),(192,156,48),(216,144,24)]),
 ('RESUME',96,[(192,168,24),(192,180,48),(216,168,24)]),
 ('BACK',48,[(192,192,24),(216,192,24)])]:
  # Native pause lettering is wide and twelve pixels high. Fill each proven
  # strip horizontally so 1/P stay adjacent and the English is legible.
  core=ink(text,w,12,font,11,pad=2);ys,xs=np.where(core);cropped=Image.fromarray((core[:,xs.min():xs.max()+1]*255).astype(np.uint8));wide=np.array(cropped.resize((w-4,12),Image.Resampling.NEAREST))>0
  mask=np.zeros((12,w),dtype=bool);mask[:,2:w-2]=wide;edge=np.zeros_like(mask)
  for dy in (-1,0,1):
   for dx in (-1,0,1):edge|=np.roll(np.roll(mask,dy,0),dx,1)
  row=np.zeros((12,w),np.uint8);row[edge]=7;row[mask]=1;start=0
  for x,y,width in parts:
   if np.any(t['pixels'][y:y+12,x:x+width]):raise ValueError('pause destination not empty')
   pix[y:y+12,x:x+width]=row[:,start:start+width];rects.append((x,y,width,12));start+=width
 replace_pixels(after,t,pix,rects);return bytes(after),[dict(tim_offset='0x0',rectangles=rects)]

def patch_guts(before,font):
 after=bytearray(before);t=tim(before,0x10800);pix=t['pixels'].copy();strip=pix[56:72,:88].copy();cell=strip[:14,6:54].copy();cell[:]=strip[14,6:54]
 mask=ink('GUTS',48,12,font,11);edge=np.zeros_like(mask)
 for dy in (-1,0,1):
  for dx in (-1,0,1):edge|=np.roll(np.roll(mask,dy,0),dx,1)
 cell[:12][edge]=2;cell[:12][mask]=14;pix[56:70,6:54]=cell;replace_pixels(after,t,pix,[(6,56,48,14)])
 return bytes(after),[dict(tim_offset='0x10800',rectangles=[(6,56,48,14)])]

def patch_roof(before,reference,spec,gap=0):
 if sha(before)!=spec['source_decoded_sha256']:raise ValueError('rooftop provider preimage')
 bs=banks(before);desired={s:ms.copy()for s,ms in bs.items()};t=tim(before,0);rt=tim(reference,0);slots=(ARENA-t['offset'])//200
 canonical={c:707+i for i,c in enumerate('ABCDEFGHIJKLMNOPRSTUVWXYQZ')};canonical.update({'!':701,"'":702,',':703,'-':704,'.':705,'/':706,'?':66})
 chars=set(re.sub(r'\{\d+\}','',''.join(e['text']for e in spec['entries'])).replace('\n',''));codes={}
 for c in sorted(chars):
  raw=bytes(200)if c==' 'else reference[rt['offset']+canonical[c]*200:rt['offset']+(canonical[c]+1)*200]
  found=next((i for i in range(slots)if before[t['offset']+i*200:t['offset']+(i+1)*200]==raw),None)
  if found is None:raise ValueError('rooftop missing existing English glyph '+c)
  codes[c]=found
 targets=set()
 for e in spec['entries']:
  s,i=e['selector'],e['index'];old=bs[s][i];targets.add((s,i))
  if sha(old)!=e['source_payload_sha256']:raise ValueError('rooftop message preimage')
  controls=[(c,a)for c,a in tokens(old)if c>=0x2000 and c not in (0x3000,0x3001)]
  words=[];nextcontrol=0
  for part in re.split(r'(\{\d+\})',e['text']):
   if not part:continue
   if part.startswith('{'):
    index=int(part[1:-1]);assert index==nextcontrol;nextcontrol+=1;c,args=controls[index];words.extend([c,*args])
   else:words.extend(0x3000 if c=='\n'else codes[c]for c in part)
  assert nextcontrol==len(controls);words.append(0x3001)
  if len(words)%2:words.append(0)
  desired[s][i]=struct.pack('<'+'H'*len(words),*words)
  if [(c,a)for c,a in tokens(desired[s][i])if c>=0x2000 and c not in (0x3000,0x3001)]!=controls:raise ValueError('rooftop controls changed')
 after,used=compact(before,desired,gap)
 if after[:ARENA]!=before[:ARENA]or after[LIMIT:]!=before[LIMIT:]:raise ValueError('rooftop escaped text arena')
 actual=banks(after)
 for s,ms in bs.items():
  for i,m in enumerate(ms):
   if (s,i)not in targets and actual[s][i]!=m:raise ValueError('untargeted message changed')
 return bytes(after),dict(translated_coordinates=len(targets),selectors=[0,1],indices=[67,119],arena_gap=gap,arena_used=used,all_other_payloads_and_all_font_pixels_preserved=True,controls_preserved=True,english_codes=codes)

def prepare_loading(disc,path):
 stored=disc.record('DAT2/ALOAD32.BIZ');off,n=struct.unpack_from('<II',stored,32*8);before=decode(stored[off:off+n])[0];t=tim(before,0);im=Image.open(path).convert('RGB').resize((512,480),Image.Resampling.LANCZOS);pix=quantize(im,rgb_palette(t))
 return dict(member=32,source_stored_sha256=sha(stored[off:off+n]),source_decoded_sha256=sha(before),source_image_sha256=file_sha(path),palette_sha256=sha(t['palette'].astype('<u2').tobytes()),pixels_z85=pack(pix))

def patch_loading(before,asset):
 if sha(before)!=asset['source_decoded_sha256']:raise ValueError('loading member binding')
 after=bytearray(before);t=tim(before,0)
 if sha(t['palette'].astype('<u2').tobytes())!=asset['palette_sha256']:raise ValueError('loading palette binding')
 replace_pixels(after,t,unpack(asset['pixels_z85'],512,480),[(0,0,512,480)])
 if after[0x3c800:]!=before[0x3c800:]:raise ValueError('loading message TIM changed')
 return bytes(after),[dict(tim_offset='0x0',rectangles=[(0,0,512,480)])]

def patch_location(before,offsets,font):
 after=bytearray(before);claims=[]
 for at in offsets:
  t=tim(after,at);pal=rgb_palette(t).astype(int);fill=int(np.argmin(((pal-np.array([255,255,255]))**2).sum(1)));outline=int(np.argmin(((pal-np.array([25,25,25]))**2).sum(1)))
  pix=t['pixels'].copy();cell=np.zeros((24,128),np.uint8);cell[1:23,4:80]=raster('ROOFTOP',76,22,font,fill,outline,16);pix[220:244,:128]=cell;replace_pixels(after,t,pix,[(0,220,128,24)]);claims.append(dict(tim_offset=hex(at),rectangles=[(0,220,128,24)]))
 return bytes(after),claims
