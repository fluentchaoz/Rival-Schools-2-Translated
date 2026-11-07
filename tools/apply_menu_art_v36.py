"""Apply the private v36 menu art and Backup update to the exact v35 image, without overwrite."""
import argparse,hashlib,json,shutil,struct
from pathlib import Path
SUPPORTED={'c25207ba7f18dd73e56f5569d3df7dcdf3d9f92cc605dbbf17692b28a6e9cf8c'}
def digest(p):
 with p.open('rb')as f:return hashlib.file_digest(f,'sha256').hexdigest()
def apply(master,packet,output):
 manifest=json.loads((packet/'manifest.json').read_text());h=digest(master);options=[s for s in manifest['inputs']if s['master_sha256']==h]
 if master.stat().st_size!=663216960 or h not in SUPPORTED or len(options)!=1:raise ValueError('Select the exact v35 BIN. Source unchanged.')
 spec=options[0]
 if spec['patch_file']not in ('from-v35.patch',):raise ValueError('invalid patch name')
 patch=packet/spec['patch_file']
 if digest(patch)!=spec['patch_sha256']:raise ValueError('patch checksum mismatch')
 if output.exists():raise ValueError('output directory already exists')
 with patch.open('rb')as f:
  if f.read(8)!=b'JG2V36\0\0':raise ValueError('patch header')
  count=struct.unpack('<I',f.read(4))[0];entries=[];last=-1
  if count!=spec['changed_sector_count']:raise ValueError('patch count')
  for _ in range(count):
   lba=struct.unpack('<I',f.read(4))[0];raw=f.read(2352)
   if lba<=last or (lba+1)*2352>663216960 or len(raw)!=2352:raise ValueError('invalid patch entry')
   entries.append((lba,raw));last=lba
  if f.read(1):raise ValueError('trailing patch bytes')
 output.mkdir(parents=True);target=output/'justice-gakuen2-menu-art-v36.bin'
 with master.open('rb')as src,target.open('xb')as dst:shutil.copyfileobj(src,dst,1024*1024)
 with target.open('r+b')as f:
  for lba,raw in entries:f.seek(lba*2352);f.write(raw)
 if digest(target)!=manifest['output_sha256']:raise ValueError('Output verification failed; do not boot this output')
 cue=target.with_suffix('.cue');cue.write_bytes(f'FILE "{target.name}" BINARY\r\n  TRACK 01 MODE2/2352\r\n    INDEX 01 00:00:00\r\n'.encode());print('V36 VERIFIED:',cue)
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('master',type=Path);p.add_argument('--packet',type=Path,default=Path(__file__).resolve().parent);p.add_argument('--output',type=Path,default=Path('menu-art-v36'));a=p.parse_args();apply(a.master,a.packet,a.output)
