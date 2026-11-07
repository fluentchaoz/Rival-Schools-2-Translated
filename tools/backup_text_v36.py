"""Bounded selector-5 Backup messages on the existing pointer-indexed dialogue banks."""
import struct,collections
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from practice_disc_v30 import sha
from build_practice_v30 import tim
BASE=0x800d0000;ARENA=0x31000;LIMIT=0x4a000
# Preserve all Yes/No rows at their original row numbers (rows 2 and 3).
TEXT={
0:'CHOOSE AN ACTION.\nSAVE\nLOAD\nRETURN TO MENU',
1:'CHECKING CARD...\nWAIT.',
3:'CHOOSE A SAVE SLOT.',
4:'SAVE TO THIS SLOT?\n\nYES\nNO',
5:'OVERWRITE THIS DATA?\n\nYES\nNO',
6:'SAVING...\nKEEP CARD INSERTED.',
7:'SAVE DONE.',
8:'CHOOSE A LOAD SLOT.',
9:'LOAD THIS SLOT?\n\nYES\nNO',
10:'SAVE BEFORE EXITING?\n\nYES\nNO',
11:'SAVE CLEAR DATA?\n\nYES\nNO',
12:'QUIT WITHOUT SAVING?\n\nYES\nNO',
13:'NOT SAVED.\nPRESS ANY BUTTON.',
14:'THANKS FOR PLAYING.\nPRESS ANY BUTTON.',
15:'CARD NOT FORMATTED.\nFORMAT IT?\nYES\nNO',
16:'FORMATTING CARD...\nKEEP CARD INSERTED.',
17:'FORMAT DONE.',
18:'CANNOT LOAD\nCLEAR DATA.',
19:'DATA IS CORRUPT.\nCANNOT LOAD.',
20:'NO CARD.',
21:'CARD FOUND.',
22:'CARD NOT FORMATTED.',
23:'FILE NOT FOUND.',
24:'MEMORY CARD FULL.\n1 BLOCK REQUIRED.',
25:'NO DATA.',
26:'FORMAT FAILED.',
27:'SAVE FAILED.',
28:'LOAD FAILED.',
29:'CARD CHECK FAILED.'}
for text in TEXT.values():
 if len(text.split('\n'))>4 or any(len(s)>20 for s in text.split('\n')):raise ValueError('translation exceeds native 20x4 window')

def tokens(message):
 words=struct.unpack('<'+'H'*(len(message)//2),message);i=0
 while i<len(words):
  code=words[i];i+=1;args=()
  if code in (0x3002,0x3003)or 0x2003<=code<=0x2009:args=(words[i],);i+=1
  yield code,args
  if code==0x3001:
   if any(words[i:]):raise ValueError('nonzero message padding')
   return
 raise ValueError('missing terminator')

def banks(data):
 if len(data)!=0x51800:raise ValueError('dialogue record extent')
 result={}
 for selector in range(8):
  pointer=struct.unpack_from('<I',data,ARENA+selector*4)[0]
  if pointer==0:continue
  table=pointer-BASE
  if table%4 or not ARENA+32<=table<LIMIT:raise ValueError('bank table pointer')
  messages=[]
  while True:
   p=struct.unpack_from('<I',data,table)[0];table+=4
   if p==0xffffffff:break
   start=p-BASE;j=start
   if start%4 or not ARENA+32<=start<LIMIT:raise ValueError('message pointer')
   while True:
    if j+2>LIMIT:raise ValueError('message extent')
    code=struct.unpack_from('<H',data,j)[0];j+=2
    if code==0x3001:break
    if code in (0x3002,0x3003)or 0x2003<=code<=0x2009:j+=2
   end=(j+3)&~3
   if any(data[j:end]):raise ValueError('message alignment')
   messages.append(bytes(data[start:end]))
  result[selector]=messages
 return result

def fingerprint(data,message,t):
 cache={};out=[];slots=(ARENA-t['offset'])//200
 for code,args in tokens(message):
  if code<slots:
   if code not in cache:cache[code]=sha(data[t['offset']+code*200:t['offset']+(code+1)*200])
   out.append(('glyph',cache[code]))
  else:out.append((code,args))
 return out

def glyph(char,font):
 im=Image.new('L',(20,20));d=ImageDraw.Draw(im);d.fontmode='1';f=ImageFont.truetype(str(font),14);b=d.textbbox((0,0),char,font=f)
 d.text(((20-b[2]+b[0])//2-b[0],(20-b[3]+b[1])//2-b[1]),char,font=f,fill=255)
 core=np.array(im)>0;edge=np.zeros_like(core)
 for y in [-1,0,1]:
  for x in [-1,0,1]:edge|=np.roll(np.roll(core,y,0),x,1)
 pix=np.zeros((20,20),dtype=np.uint8);pix[edge]=4;pix[core]=14;raw=pix.ravel();return (raw[::2]|raw[1::2]<<4).tobytes()

def compact(data,bs,gap=0):
 out=bytearray(data);out[ARENA:LIMIT]=bytes(LIMIT-ARENA);p=ARENA+32+gap;pool={}
 for selector,messages in bs.items():
  pointers=[]
  for m in messages:
   if m not in pool:
    if p+len(m)>LIMIT:raise ValueError('message arena overflow')
    pool[m]=p;out[p:p+len(m)]=m;p+=len(m)
   pointers.append(pool[m])
  table=p
  for address in pointers:
   struct.pack_into('<I',out,p,address+BASE);p+=4
  struct.pack_into('<I',out,p,0xffffffff);p+=4
  struct.pack_into('<I',out,ARENA+selector*4,table+BASE)
 if p>LIMIT:raise ValueError('pointer tables overflow')
 if banks(out)!=bs:raise ValueError('pointer rebuild readback')
 return out,p-ARENA

AUDITED_VARIANTS={'289e778c853edd3c9bfa1604c5f285e98ddf11d01bdc7cc8d7e46f95b52efacb': [11, 18, 24, 2, 30], 'ec4fb880974775af6e05fdce6c8419af2c593f7a3b357c4f3f24cf36ddd632d0': [11, 18, 2, 30]}

def patch(data,reference,font,arena_gap=0):
 t=tim(data,0);rt=tim(reference,0);bs=banks(data);ref=banks(reference)
 if len(bs.get(5,[]))!=31:raise ValueError('Backup selector population')
 # Confirm source meanings by exact glyph imagery, independent of glyph indices.
 for i in list(TEXT)+[2,30]:
  if fingerprint(data,bs[5][i],t)!=fingerprint(reference,ref[5][i],rt):
   # Reviewed quiz/title banks use earlier English ASCII/digit font variants.
   # Their CLEAR, one-block warning, date alphabet and Cancel have the same meaning.
   if i not in AUDITED_VARIANTS.get(sha(data),[]):raise ValueError(f'Backup preimage differs at entry {i}')
 used={code for ms in bs.values()for m in ms for code,args in tokens(m)if code<(ARENA-t['offset'])//200};fixed=t['height']//20;slots=(ARENA-t['offset'])//200
 chars=sorted(set(''.join(TEXT.values()).replace('\n','')+'MD'));after=bytearray(data);codes={};added=[]
 for char in chars:
  # Reuse the v28 English alphabet by exact glyph imagery, independently of
  # per-bank indices. This avoids allocating a second full ASCII alphabet.
  canonical={c:707+i for i,c in enumerate('ABCDEFGHIJKLMNOPRSTUVWXYQZ')}
  canonical.update({'!':701,"'":702,',':703,'-':704,'.':705,'/':706,'?':66})
  if char in canonical:
   rp=rt['offset']+canonical[char]*200;raw=reference[rp:rp+200]
  elif char==' ':raw=bytes(200)
  elif char=='1':
   digit=list(tokens(bs[5][2]))[1][0];rp=t['offset']+digit*200;raw=data[rp:rp+200]
  else:raw=glyph(char,font)
  matching=next((i for i in range(slots)if after[t['offset']+i*200:t['offset']+(i+1)*200]==raw),None)
  if matching is None:
   matching=next((i for i in range(fixed,slots)if i not in used and i not in added and not any(after[t['offset']+i*200:t['offset']+(i+1)*200])),None)
   if matching is None:raise ValueError('no empty glyph slots')
   p=t['offset']+matching*200;after[p:p+200]=raw;added.append(matching)
  codes[char]=matching
 desired={s:ms.copy()for s,ms in bs.items()}
 for index,text in TEXT.items():
  # These finite messages have only glyphs, line breaks and the terminator.
  if any(c>=0x2000 and c not in (0x3000,0x3001)for c,args in tokens(bs[5][index])):raise ValueError('unexpected protected Backup control')
  w=[0x3000 if c=='\n'else codes[c]for c in text]+[0x3001]
  if len(w)%2:w.append(0)
  desired[5][index]=struct.pack('<'+'H'*len(w),*w)
 # Preserve the native decimal alphabet and the fixed 13-cell date layout.
 w=[code for code,args in tokens(bs[5][2])if code!=0x3001]
 if len(w)!=13:raise ValueError('date alphabet contract')
 w=w[:10]+[codes['M'],codes['D'],0x061e,0x3001];desired[5][2]=struct.pack('<14H',*w)
 after,usedbytes=compact(after,desired,arena_gap)
 allowed=np.zeros(len(data),dtype=bool);allowed[ARENA:LIMIT]=True
 for index in added:allowed[t['offset']+index*200:t['offset']+(index+1)*200]=True
 if np.any((np.frombuffer(data,dtype=np.uint8)!=np.frombuffer(after,dtype=np.uint8))&~allowed):raise ValueError('unowned dialogue write')
 actual=banks(after)
 for selector,ms in bs.items():
  for i,m in enumerate(ms):
   if selector!=5 or i not in set(TEXT)|{2}:
    if actual[selector][i]!=m:raise ValueError('untargeted message changed')
 if actual[5][30]!=bs[5][30]:raise ValueError('English Cancel hint changed')
 return bytes(after),dict(arena_gap=arena_gap,selector=5,translated_messages=29,date_unit_message=2,date_digits_unchanged=True,yes_no_rows_preserved=True,other_payloads_and_fixed_glyphs_preserved=True,glyph_offset=t['offset'],new_glyph_slots=added,glyph_codes=codes,arena_used=usedbytes,arena_capacity=LIMIT-ARENA)
