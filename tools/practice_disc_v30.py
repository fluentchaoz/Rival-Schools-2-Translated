"""Bounded PSX record I/O and source-profiled LZ support for the v30 builder."""
import collections,ctypes,hashlib,struct
from pathlib import Path

def sha(data):return hashlib.sha256(data).hexdigest()
def file_sha(path):
 with Path(path).open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
class Disc:
 def __init__(self,path):self.path=Path(path);self.f=self.path.open('rb');self.records=self.index()
 def read(self,lba,size):
  out=bytearray()
  for o in range(0,size,2048):
   self.f.seek((lba+o//2048)*2352+24);part=self.f.read(min(2048,size-o))
   if len(part)!=min(2048,size-o):raise ValueError('truncated ISO record')
   out.extend(part)
  return bytes(out)
 def record(self,name):return self.read(*self.records[name])
 def index(self):
  result={}
  def walk(lba,size,prefix=''):
   d=self.read(lba,size);i=0
   while i<len(d):
    n=d[i]
    if not n:i=(i//2048+1)*2048;continue
    r=d[i:i+n];i+=n
    if len(r)!=n or n<34:raise ValueError('bad ISO directory')
    name=r[33:33+r[32]]
    if name in (b'\0',b'\1'):continue
    path=prefix+name.decode('ascii').split(';')[0];l,s=struct.unpack_from('<I',r,2)[0],struct.unpack_from('<I',r,10)[0]
    if r[25]&2:walk(l,s,path+'/')
    else:result[path]=(l,s)
  pvd=self.read(16,2048)
  if pvd[:7]!=b'\x01CD001\x01':raise ValueError('bad ISO PVD')
  root=pvd[156:190];walk(struct.unpack_from('<I',root,2)[0],struct.unpack_from('<I',root,10)[0]);return result

def decode(data,profile_only=False):
 p=0;out=bytearray();words=0;maxmatch=maxblock=maxpage=cross=0;page=-1;pagewords=0
 def word():
  nonlocal p
  if p+2>len(data):raise ValueError('truncated compressed stream')
  v=struct.unpack_from('<H',data,p)[0];p+=2;return v
 while True:
  start=p
  if p//2048!=page:page=p//2048;pagewords=0
  control=word();block=0;done=False
  for _ in range(16):
   v=word()
   if control&0x8000:
    n=v>>11;dist=v&2047
    if n==0:n=word()
    if n==0 and dist==0:done=True;break
    if not profile_only:
     if dist==0:out.extend(bytes(n*2))
     else:
      if dist*2>len(out):raise ValueError('invalid back-reference')
      for _ in range(n):out.extend(out[-dist*2:][:2])
    maxmatch=max(maxmatch,n);block+=n
   else:
    if not profile_only:out.extend(v.to_bytes(2,'little'))
    block+=1
   control=(control<<1)&65535
  cross+=int(start//2048!=(p-1)//2048);maxblock=max(maxblock,block);pagewords+=block;maxpage=max(maxpage,pagewords);words+=block
  if done:
   profile=dict(stream_bytes=p,max_match=maxmatch,max_block=maxblock,max_page=maxpage,crossing_blocks=cross,decoded_bytes=words*2)
   return profile if profile_only else (bytes(out),profile)

def compress_python(data,maxmatch,blocklimit,prefix,pagelimit=0):
 w=struct.unpack('<'+'H'*(len(data)//2),data);positions=collections.defaultdict(collections.deque);out=bytearray();i=0;count=0;ext=blocks=pageout=0
 while i<len(w):
  if count==0:start=len(out);out.extend(b'\0\0');control=0;bout=0
  maximum=min(maxmatch,max(1,blocklimit-bout-(15-count)),len(w)-i,31 if ext>=4 else 65535,1 if i<prefix else 65535)
  if pagelimit:maximum=min(maximum,max(1,pagelimit-pageout-((2048-len(out)%2048+1)//2+15)))
  best=dist=0;q=positions[w[i]]
  while q and q[0]<i-2047:q.popleft()
  if i>=16:
   for at in reversed(q):
    if best and w[i+best]!=w[at+best]:continue
    n=1
    while n<maximum and w[i+n]==w[at+n]:n+=1
    if n>best:best=n;dist=i-at
    if best==maximum:break
  used=1
  if best>=2 or (best==1 and ext<4):
   used=best;control|=1<<(15-count)
   if best>31 or ext<4:out.extend(struct.pack('<HH',dist,best));ext+=1
   else:out.extend(struct.pack('<H',(best<<11)|dist))
  else:out.extend(struct.pack('<H',w[i]))
  for j in range(i,i+used):positions[w[j]].append(j)
  i+=used;bout+=used;pageout+=used;count+=1
  if count==16:
   struct.pack_into('<H',out,start,control);count=0;blocks+=1
   if blocks==60:
    if len(out)%2048 or ext!=4:raise ValueError('page schedule')
    ext=blocks=pageout=0
 if count==0:start=len(out);out.extend(b'\0\0');control=0
 control|=1<<(15-count);out.extend(b'\0\0\0\0');struct.pack_into('<H',out,start,control);return bytes(out)

def compress(data,source,accelerator=None):
 sp=decode(source,True);final=(sp['stream_bytes']-1)//2048*2048
 lib=None
 if accelerator:
  lib=ctypes.CDLL(str(Path(accelerator).resolve()));lib.practice_compress.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_int];lib.practice_compress.restype=ctypes.c_int
 def encode(prefix):
  if lib:
   inp=ctypes.create_string_buffer(data);buf=ctypes.create_string_buffer(len(data)*2+65536)
   n=lib.practice_compress(inp,len(data)//2,buf,len(buf),sp['max_match'],sp['max_block'],prefix,sp['max_page'])
   if n<0:raise ValueError(f'encoder error {n}')
   return buf.raw[:n]
  return compress_python(data,sp['max_match'],sp['max_block'],prefix,sp['max_page'])
 result=encode(0)
 if len(result)>len(source):raise ValueError('compressed output exceeds original slot')
 if len(result)<=final:
  lo,hi=16,len(data)//2;found=None
  while lo<=hi:
   mid=(lo+hi)//2;c=encode(mid)
   if len(c)<=final:lo=mid+1
   else:found=c;hi=mid-1
  if found is None:raise ValueError('cannot retain original final input page')
  result=found
 rp=decode(result,True)
 if not(final<len(result)<=len(source)):raise ValueError('source final page / slot mismatch')
 if rp['max_page']>sp['max_page'] or rp['crossing_blocks'] or rp['max_match']>sp['max_match'] or rp['max_block']>sp['max_block']:raise ValueError('decoder profile exceeded')
 if decode(result)[0]!=data:raise ValueError('compression readback mismatch')
 return result+bytes(len(source)-len(result)),dict(source=sp,rebuilt=rp)

F=[0]*256;B=[0]*256;EDC=[0]*256
for v in range(256):
 d=((v<<1)^(0x11d if v&128 else 0))&255;F[v]=d;B[v^d]=v;t=v
 for _ in range(8):t=(t>>1)^(0xd8018001 if t&1 else 0)
 EDC[v]=t

def ecc(source,major_count,minor_count,mult,inc):
 size=major_count*minor_count;out=bytearray(major_count*2)
 for major in range(major_count):
  index=(major>>1)*mult+(major&1);a=b=0
  for _ in range(minor_count):
   v=source[index];index=(index+inc)%size;a^=v;b^=v;a=F[a]
  a=B[F[a]^b];out[major]=a;out[major+major_count]=a^b
 return out

def regenerate(raw):
 s=bytearray(raw)
 if len(s)!=2352 or s[:12]!=b'\x00'+b'\xff'*10+b'\x00' or s[15]!=2 or s[16:20]!=s[20:24] or s[18]&32:raise ValueError('unsupported raw sector')
 e=0
 for v in s[16:2072]:e=(e>>8)^EDC[(e^v)&255]
 struct.pack_into('<I',s,2072,e);header=s[12:16];s[12:16]=b'\0'*4;s[2076:2248]=ecc(s[12:],86,24,2,86);s[2248:]=ecc(s[12:],52,43,86,88);s[12:16]=header;return bytes(s)
