"""v39 Mode Select thumbnails: erase Japanese lettering and draw English with a native-looking 3x5 pixel font.
Edits are bounded to explicit rectangles inside the thumbnail TIMs of DAT2/MENU.BIZ."""
import numpy as np
from scipy.ndimage import binary_dilation
from build_thumbnail_v38 import FONT
FONT=dict(FONT)
FONT.update({'"':'101101000000000','-':'000000111000000','(':'010100100100010',')':'010001001001010',':':'000010000010000','/':'001001010100100',
'0':'111101101101111','1':'010110010010111','2':'111001111100111','3':'111001111001111','4':'101101111001001','5':'111100111001111','6':'111100111101111','7':'111001010010010','8':'111101111101111','9':'111101111001111'})
def glyph(c):return np.array([int(v)for v in FONT[c]],dtype=np.uint8).reshape(5,3)

# erase: (rect, colours to remove, protected colours, grow).  text: (x, y, string, fill, shadow or None)
THUMBS={
0x83800:dict(
 erase=[((8,8,104,80),{10,11,12,13,14},set(),1)],
 text=[(12,10+10*n,s,14,1)for n,s in enumerate(["THE STAMP RALLY!","IT'S QUITE A BIG EVENT.","\"UH-OH, I'M STILL MISSING","SOME GOOD STAMPS!\"","THE SCHOOL'S POPULAR EVENT","\"THIS IS IT!\"","RAN SETS OUT TO GATHER","INFO ON THE INCIDENT."])]),
0x89800:dict(
 erase=[((36,3,60,12),{10,8,4},{14},0),((8,18,86,68),{9,12,13,14},set(),1)],
 text=[(50,6,'OPTIONS',10,2),(11,19,'CPU LEVEL',9,None)]+[(11,26+6*n,s,14,0)for n,s in enumerate(['GAME SPEED','TIME LIMIT','MATCH (CPU)','MATCH (VS)','CPU PARTNER SELECT','BUTTON CONFIG','SOUND TEST','VOICE'])]+[(11,82,'DEFAULT',14,0)]),
0x8b800:dict(
 erase=[((48,3,28,12),{10,7},set(),1),((8,17,30,8),{12,13,14,11},set(),1),((8,33,60,8),{11,12,13,14},set(),1),((30,69,45,8),{9,11,13,14},set(),1),((25,80,75,8),{9,11,12},set(),1)],
 text=[(54,6,'DATA',10,2),(11,19,'LOAD',14,1),(11,35,'AUTO SAVE',14,1),(51,35,'OFF',12,1),(34,70,'SAVE OK?',14,1),(30,82,'CARD IN SLOT 1',12,0)]),
0x8d800:dict(
 erase=[((46,2,38,12),{12,14,7,9},set(),1),((14,17,48,38),{11,13,14},set(),1),((8,55,45,8),{12,13,14,11},set(),1),((18,66,88,14),{10,11,13,14},set(),1)],
 text=[(58,5,'SHOP',12,0)]+[(16,19+8*n,s,14,2)for n,s in enumerate(['RARE CARD','RARE CARD X10','HINATA SET','MUSIC SET','TIFFANY SET'])]+[(12,57,'POINTS',14,0),(19,68,'WELCOME!',14,1),(19,74,'WHAT ARE YOU AFTER?',14,1)]),
0x91800:dict(
 erase=[((14,14,50,16),{3,7,8,10,11,12},set(),1)],
 fill=[((25,3,71,5),11)]+[((7,65,24,5),6),((7,70,24,1),4),((7,72,24,5),6),((7,77,24,1),4),((7,79,24,5),6),((7,84,24,1),4),((7,86,15,5),6),((82,65,21,5),4)],
 text=[(17,16,"YOUR TEAM'S",3,None),(17,23,'OVERALL RATING:',3,None),(33,3,'TEAM SYNERGY',2,None),(7,65,'ATTACK',14,None),(7,72,'GUARD',14,None),(7,79,'COMBOS',14,None),(7,86,'GUTS',14,None),(83,65,'SCORE',14,None)]),
0x93800:dict(
 erase=[],fill=[((52,7,22,7),8)],
 text=[(55,8,'TEAM',14,1)]),
0x95800:dict(
 erase=[((38,0,52,11),{9},{14},1)],
 text=[(44,3,'TOURNAMENT',9,2)]),
0x97800:dict(
 erase=[((44,2,44,12),{10},{14},1)],
 text=[(53,4,'LEAGUE',10,2)]),
0x9b800:dict(
 erase=[((14,44,62,26),{9,11,13,14},set(),0),((26,80,46,6),{9,11,13,14},set(),0)],
 fill=[((37,4,58,6),2)],
 text=[(52,5,'EDIT MODE',12,None),(14,45,'SAVE THIS DATA TO',14,None),(14,51,'THE MEMORY CARD?',14,None),(30,81,'YES',14,None),(58,81,'NO',14,None)]),
}
def erase(pix,rect,colors,protect,grow):
 x,y,w,h=rect;sub=pix[y:y+h,x:x+w];mask=np.isin(sub,list(colors))
 if grow:
  g=binary_dilation(mask,iterations=grow)&~mask;g&=~np.isin(sub,list(protect|colors)) if protect else g;mask|=g&~np.isin(sub,list(protect))
 for r in range(h):
  row=pix[y+r];xs=[c for c in range(w)if mask[r,c]]
  for c in xs:
   best=None
   for d in range(1,24):
    for cc in (c-d,c+d):
     if 0<=cc<w and not mask[r,cc]:best=sub[r,cc];break
    if best is not None:break
   if best is None:best=pix[y+max(r-1,0),x+c]
   sub[r,c]=best
def draw(pix,x,y,text,fill,shadow):
 for k,c in enumerate(text):
  if c not in FONT:raise ValueError('glyph '+c)
  g=glyph(c)==1;cx=x+k*4
  if shadow is not None:
   for yy,xx in zip(*np.nonzero(g)):
    if 0<=y+yy+1<pix.shape[0] and 0<=cx+xx+1<pix.shape[1] and pix[y+yy+1,cx+xx+1]!=fill:pix[y+yy+1,cx+xx+1]=shadow
  for yy,xx in zip(*np.nonzero(g)):pix[y+yy,cx+xx]=fill
def patch_all(before,tim,replace_pixels,thumbs=THUMBS):
 after=bytearray(before);claims=[]
 for at,spec in thumbs.items():
  t=tim(before,at)
  if (t['mode'],t['width'],t['height'])!=(0,128,96):raise ValueError('thumbnail geometry')
  pix=t['pixels'].copy();rects=[]
  for rect,colors,protect,grow in spec['erase']:erase(pix,rect,colors,protect,grow);rects.append(rect)
  for (x,y,w,h),v in spec.get('fill',[]):pix[y:y+h,x:x+w]=v;rects.append((x,y,w,h))
  for x,y,s,f,sh in spec['text']:
   if x<0 or y<0 or x+len(s)*4>128:raise ValueError('text out of bounds '+s)
   draw(pix,x,y,s,f,sh);rects.append((x,y,len(s)*4+1,6))
  replace_pixels(after,t,pix,rects);claims.append(dict(tim_offset=hex(at),rectangles=rects))
 return bytes(after),claims
