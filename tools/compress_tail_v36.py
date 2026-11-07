"""Preserve complete source pages before the first changed decoded byte."""
import ctypes,struct
from pathlib import Path
from practice_disc_v30 import decode

def compress_tail(data,source,accelerator):
 old,sp=decode(source)
 if len(old)!=len(data):raise ValueError('decoded extent changed')
 first=next((i for i,(a,b)in enumerate(zip(old,data))if a!=b),None)
 if first is None:return source,dict(source=sp,rebuilt=sp,preserved_input_prefix_bytes=sp['stream_bytes'],preserved_decoded_prefix_bytes=len(data))
 # Locate complete native input pages and their decoded word positions.
 p=words=0;cut=start=0
 while p<len(source):
  control=struct.unpack_from('<H',source,p)[0];p+=2;done=False
  for _ in range(16):
   v=struct.unpack_from('<H',source,p)[0];p+=2
   if control&0x8000:
    n=v>>11
    if n==0:n=struct.unpack_from('<H',source,p)[0];p+=2
    if n==0 and (v&2047)==0:done=True;break
    words+=n
   else:words+=1
   control=(control<<1)&65535
  if done:break
  if p%2048==0 and words*2<=first:cut,start=p,words
  if words*2>first:break
 if not cut:raise ValueError('no reusable source prefix')
 lib=ctypes.CDLL(str(Path(accelerator).resolve()));fn=lib.practice_compress_tail;fn.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_void_p]+[ctypes.c_int]*6;fn.restype=ctypes.c_int
 inp=ctypes.create_string_buffer(data);buf=ctypes.create_string_buffer(len(data)*2+65536);final=(sp['stream_bytes']-1)//2048*2048
 def encode(prefix):
  n=fn(inp,len(data)//2,buf,len(buf),sp['max_match'],sp['max_block'],start+prefix,sp['max_page'],start)
  if n<0:raise ValueError('tail encoder '+str(n))
  return source[:cut]+buf.raw[:n]
 result=encode(0)
 if len(result)<=final:
  lo,hi=0,len(data)//2-start;found=None
  while lo<=hi:
   mid=(lo+hi)//2;c=encode(mid)
   if len(c)<=final:lo=mid+1
   else:found=(c,mid);hi=mid-1
  if found is None:raise ValueError('tail final page')
  result,prefix=found
 else:prefix=0
 for shift in range(65):
  if shift:result=encode(prefix+shift)
  rp=decode(result,True)
  if final<len(result)<=len(source) and not rp['crossing_blocks'] and all(rp[k]<=sp[k]for k in ('max_match','max_block','max_page')):break
 else:raise ValueError('tail exceeds source slot/profile')
 if decode(result)[0]!=data:raise ValueError('tail readback')
 return result+bytes(len(source)-len(result)),dict(source=sp,rebuilt=rp,preserved_input_prefix_bytes=cut,preserved_decoded_prefix_bytes=start*2)
