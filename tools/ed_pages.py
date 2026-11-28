"""Ending/epilogue narration pages (task 011): dump contact sheets or print size/volume stats.

Usage (project venv, run from C:\Users\Fluent\JG2-Project): python repo/tools/ed_pages.py dump|stats
Pages: DAT2/ED*.BIZ text TIM at 0x4000, DAT2/EDB*.BIZ text TIM at 0x5f800. Output goes under work/hud (not committed).
"""
import sys
cmd = sys.argv[1] if len(sys.argv) > 1 else 'stats'
if cmd == 'dump':
    exec(compile(open(__file__, encoding='utf-8').read().split('#--DUMP--')[1].split('#--STATS--')[0], 'dump', 'exec'))
else:
    exec(compile(open(__file__, encoding='utf-8').read().split('#--STATS--')[1], 'stats', 'exec'))
#--DUMP--
import sys,glob,re; sys.path.insert(0,'repo/tools'); 
import numpy as np
from PIL import Image,ImageDraw
from practice_disc_v30 import Disc, decode
from build_practice_v30 import tim, rgb_image
ORIG='1-KEEP/original-disc/Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).bin'
d=Disc(ORIG)
pages=[]
for name in sorted(d.records):
    m=re.match(r'DAT2/(ED\d\d|EDB\d\d)\.BIZ$',name)
    if not m: continue
    data=decode(d.record(name))[0]
    off=0x4000 if m.group(1).startswith('ED') and not m.group(1).startswith('EDB') else 0x5f800
    try: t=tim(data,off)
    except Exception as e: print(name,'ERR',e); continue
    pages.append((m.group(1),t))
print(len(pages))
import pickle
for k in range(0,len(pages),4):
    grp=pages[k:k+4]
    H=sum(t['height']+16 for _,t in grp); S=Image.new('RGB',(512,H),(30,30,30)); dr=ImageDraw.Draw(S); y=0
    for n,t in grp:
        dr.text((2,y+1),n+' %dx%d'%(t['width'],t['height']),fill=(0,255,255)); S.paste(rgb_image(t).convert('RGB'),(0,y+14)); y+=t['height']+16
    S.save('work/hud/pages_%02d.png'%(k//4))
print([n for n,_ in pages])

#--STATS--
import sys,re; sys.path.insert(0,'repo/tools')
import numpy as np
from practice_disc_v30 import Disc, decode
from build_practice_v30 import tim
d=Disc('1-KEEP/original-disc/Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).bin')
tot=0; rows=[]
for name in sorted(d.records):
    m=re.match(r'DAT2/(ED\d\d|EDB\d\d)\.BIZ$',name)
    if not m: continue
    data=decode(d.record(name))[0]
    off=0x4000 if not m.group(1).startswith('EDB') else 0x5f800
    t=tim(data,off); p=t['pixels']; bg=np.bincount(p.ravel()).argmax()
    ink=(p!=bg)
    chars=0
    for y0 in range(0,p.shape[0]-23,24):
        cols=np.where(ink[y0:y0+24].any(axis=0))[0]
        # approx: 16 px per glyph over occupied columns
        chars+=int(ink[y0:y0+24].any(axis=0).sum()//14)
    rows.append((m.group(1),t['width'],t['height'],chars)); tot+=chars
for r in rows: print(*r)
print('total approx JP chars',tot)
