"""Convert approved generated art to bounded native sprite/background contributions."""
import json,zlib,base64,struct
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
from scipy.ndimage import label,binary_fill_holes,binary_dilation
from practice_disc_v30 import sha,file_sha
from build_practice_v30 import tim,rgb_palette,replace_pixels,quantize
from build_exam_dance_v35 import raster

LOGOS=[('DAT2/MA_TIT.BIZ',0,(513,1,250,126),9,'large',0),('DAT2/MA_TIT.BIZ',0,(517,137,85,62),8,'small',0),('DAT2/MENU.BIZ',0x22800,(1136,0,104,72),10,'small',0)]
LOGOS += [(f'DAT2/SELP{k}.BIZ',0x17800,(876,152,148,66),28,'small',1)for k in range(1,6)]

def pack(a):return base64.b85encode(zlib.compress(a.tobytes(),9)).decode()
def unpack(s,w,h):return np.frombuffer(zlib.decompress(base64.b85decode(s)),dtype=np.uint8).reshape(h,w).copy()
def palette_hash(t,p):return sha(t['palette'][p*16:(p+1)*16].astype('<u2').tobytes())

def sprite(im,w,h,t,p,clear):
 alpha=im.getchannel('A');box=alpha.point(lambda x:255 if x>=128 else 0).getbbox()
 if box is None:raise ValueError('empty logo alpha')
 # This is native sprite conversion. Hidden RGB behind alpha never enters pixels.
 crop=im.crop(box).resize((w-2,h-2),Image.Resampling.LANCZOS);a=np.array(crop);mask=a[:,:,3]>=128
 pal=rgb_palette(t,p).astype(np.int32);words=t['palette'][p*16:(p+1)*16];choices=[i for i in range(16)if i!=clear and words[i]!=0]
 result=np.full((h,w),clear,dtype=np.uint8)
 for y in range(h-2):
  colors=a[y,:,:3].astype(np.int32);ix=np.argmin(((colors[:,None,:]-pal[None,choices,:])**2).sum(2),axis=1);row=np.array(choices,dtype=np.uint8)[ix];result[y+1,1:w-1][mask[y]]=row[mask[y]]
 return result

def prepare_assets(disc,logo_path,backdrop_path):
 logo=Image.open(logo_path).convert('RGBA');background=Image.open(backdrop_path).convert('RGB').resize((512,480),Image.Resampling.LANCZOS)
 if np.min(np.array(logo)[:,:,3])!=0:raise ValueError('logo lacks transparent pixels')
 halves={'large':logo.crop((0,0,logo.width,logo.height*53//100)),'small':logo.crop((0,logo.height*53//100,logo.width,logo.height))}
 from practice_disc_v30 import decode
 assets=dict(kind='menu-art-v36',logo_sha256=file_sha(logo_path),background_sha256=file_sha(backdrop_path),logos=[],backdrops=[])
 for name,at,box,p,key,clear in LOGOS:
  data=decode(disc.record(name))[0];t=tim(data,at);x,y,w,h=box;pix=sprite(halves[key],w,h,t,p,clear)
  assets['logos'].append(dict(path=name,tim_offset=at,cell=box,palette=p,clear_index=clear,palette_sha256=palette_hash(t,p),source_pixels_sha256=sha(t['pixels'][y:y+h,x:x+w].tobytes()),pixels_z85=pack(pix)))
 stored=disc.record('DAT2/SIKEN20.BIZ')
 for i in range(2):
  off,n=struct.unpack_from('<II',stored,i*8);dec=decode(stored[off:off+n])[0];t=tim(dec,0x8800);pal=rgb_palette(t);pix=quantize(background,pal)
  assets['backdrops'].append(dict(member=i,palette_sha256=sha(t['palette'].astype('<u2').tobytes()),pixels_z85=pack(pix)))
 return assets

def apply_logos(before,path,assets):
 after=bytearray(before);claims=[]
 for entry in assets['logos']:
  if entry['path']!=path:continue
  at=entry['tim_offset'];t=tim(before,at);x,y,w,h=entry['cell']
  if palette_hash(t,entry['palette'])!=entry['palette_sha256']or sha(t['pixels'][y:y+h,x:x+w].tobytes())!=entry['source_pixels_sha256']:raise ValueError('logo preimage '+path)
  pix=tim(after,at)['pixels'].copy();pix[y:y+h,x:x+w]=unpack(entry['pixels_z85'],w,h);replace_pixels(after,tim(after,at),pix,[entry['cell']]);claims.append(dict(tim_offset=hex(at),rectangles=[entry['cell']],palette=entry['palette']))
 return bytes(after),claims

def apply_record_labels(before,font):
 after=bytearray(before);t=tim(before,0x10800);pix=t['pixels'].copy();rects=[]
 for x,y,w,text in [(720,128,48,'CURRENT'),(200,240,56,'HI SCORE')]:
  cell=np.zeros((16,w),dtype=np.uint8);cell[:10]=raster(text,w,10,font,14,2,9);pix[y:y+16,x:x+w]=cell;rects.append((x,y,w,16))
 replace_pixels(after,t,pix,rects);return bytes(after),[dict(tim_offset='0x10800',rectangles=rects)]

def largest(mask):
 ids,n=label(mask)
 if not n:return np.zeros_like(mask)
 counts=np.bincount(ids.ravel());counts[0]=0;return ids==counts.argmax()

def foreground_mask(t,member):
 """Conservative source-derived protection for sheet, props and existing English UI."""
 rgb=rgb_palette(t)[t['pixels']].astype(np.int32);h,w=t['pixels'].shape;yy,xx=np.indices((h,w))
 paper=(rgb.min(2)>140)&(xx>=35)&(xx<480)&(yy>60)&(yy<430)
 paper=binary_fill_holes(largest(paper));paper=binary_dilation(paper,iterations=1);keep=paper.copy()
 # Original paper drop shadow: same silhouette shifted thirteen left/twelve down.
 keep[12:,:-13]|=paper[:-12,13:]
 if member==1:
  # The report heading and return hint were authored in v35; retain exact pixels.
  keep[31:67,169:339]=True;keep[410:433,342:431]=True
  # Source-bound register silhouette, with the English ROLL label inside it.
  mask=Image.new('L',(w,h));ImageDraw.Draw(mask).polygon([(205,257),(289,265),(278,411),(187,400)],fill=255);keep|=np.array(mask)>0
  # Connected prop silhouettes distinguish gray/wood objects from scattered
  # gold/red text. Restrict to finite source-derived regions, then fill lens holes.
  r,g,b=[rgb[:,:,i]for i in range(3)];prop=(b>g*.50)|((r<82)&(g<82))
  for box,poly in [((70,328,185,419),None),((240,205,451,475),[(432,207),(450,218),(350,384),(358,411),(273,474),(242,474),(245,448),(298,391),(291,373),(312,364),(424,227)])]:
   x0,y0,x1,y1=box;candidate=prop[y0:y1,x0:x1].copy()
   if poly:
    p=Image.new('L',(w,h));ImageDraw.Draw(p).polygon(poly,fill=255);candidate&=np.array(p)[y0:y1,x0:x1]>0
   component=binary_fill_holes(largest(candidate));component=binary_dilation(component,iterations=1);keep[y0:y1,x0:x1]|=component
 return keep

def apply_backdrop(before,member,assets):
 after=bytearray(before);t=tim(before,0x8800);entry=assets['backdrops'][member]
 if entry['member']!=member or sha(t['palette'].astype('<u2').tobytes())!=entry['palette_sha256']:raise ValueError('backdrop palette binding')
 keep=foreground_mask(t,member);new=unpack(entry['pixels_z85'],512,480);pix=t['pixels'].copy();pix[~keep]=new[~keep]
 replace_pixels(after,t,pix,[(0,0,512,480)])
 if not np.array_equal(t['pixels'][keep],tim(after,0x8800)['pixels'][keep]):raise ValueError('foreground modified')
 return bytes(after),[dict(tim_offset='0x8800',rectangles=[(0,0,512,480)],masked_pixels=int((~keep).sum()),protected_pixels=int(keep.sum()),foreground_mask_sha256=sha(keep.tobytes()))]
