"""v43: English INFIRMARY label replacing the Japanese strip (0,220,128,24) in background TIMs."""
import numpy as np
from build_practice_v30 import tim,rgb_palette,replace_pixels
from build_exam_dance_v35 import raster
TEXT='INFIRMARY'
VARIANTS=((16,True),(12,True),(12,False),(10,False))
def patch_label(before,font,offsets=(0,),variant=0):
 size,edge=VARIANTS[variant]
 after=bytearray(before);claims=[]
 for at in offsets:
  t=tim(after,at);pal=rgb_palette(t).astype(int);fill=int(np.argmin(((pal-np.array([255,255,255]))**2).sum(1)));outline=int(np.argmin(((pal-np.array([25,25,25]))**2).sum(1)))
  pix=t['pixels'].copy();cell=np.zeros((24,128),np.uint8);cell[1:23,4:104]=raster(TEXT,100,22,font,fill,outline if edge else None,size);pix[220:244,:128]=cell
  replace_pixels(after,t,pix,[(0,220,128,24)]);claims.append(dict(tim_offset=hex(at),rectangles=[(0,220,128,24)]))
 return bytes(after),claims
