"""Apply the private v29-to-v30 sector patch, verifying both disc identities."""
import argparse,hashlib,json,shutil,struct
from pathlib import Path
MASTER='f4f974c40220dd82925d4b17d6a31b3f95218a6017783666851204ea3040c67f'
def digest(p):
 with p.open('rb')as f:return hashlib.file_digest(f,'sha256').hexdigest()
def apply(master,packet,output):
 manifest=json.loads((packet/'manifest.json').read_text());patch=packet/'practice-v30.patch'
 if manifest['master_sha256']!=MASTER or master.stat().st_size!=663216960 or digest(master)!=MASTER:raise ValueError('Select the exact recovered v29 BIN. Source was not changed.')
 if digest(patch)!=manifest['patch_sha256']:raise ValueError('Patch checksum mismatch')
 if output.exists():raise ValueError('Output directory exists; choose a new output directory')
 # Parse and validate the complete patch before creating output.
 with patch.open('rb')as f:
  if f.read(8)!=b'JG2V30\0\0':raise ValueError('patch header')
  count=struct.unpack('<I',f.read(4))[0];entries=[];last=-1
  if count!=manifest['changed_sector_count']:raise ValueError('patch count')
  for _ in range(count):
   lba=struct.unpack('<I',f.read(4))[0];raw=f.read(2352)
   if lba<=last or (lba+1)*2352>663216960 or len(raw)!=2352:raise ValueError('invalid patch entry')
   entries.append((lba,raw));last=lba
  if f.read(1):raise ValueError('trailing patch bytes')
 output.mkdir(parents=True);target=output/'justice-gakuen2-practice-v30.bin'
 with master.open('rb')as src,target.open('xb')as dst:shutil.copyfileobj(src,dst,1024*1024)
 with target.open('r+b')as f:
  for lba,raw in entries:f.seek(lba*2352);f.write(raw)
 if digest(target)!=manifest['output_sha256']:raise ValueError('Output verification failed; do not boot the output')
 cue=target.with_suffix('.cue');cue.write_bytes(f'FILE "{target.name}" BINARY\r\n  TRACK 01 MODE2/2352\r\n    INDEX 01 00:00:00\r\n'.encode());print('Verified v30 CUE:',cue)
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('master',type=Path);p.add_argument('--packet',type=Path,default=Path(__file__).resolve().parent);p.add_argument('--output',type=Path,default=Path('practice-v30'));a=p.parse_args();apply(a.master,a.packet,a.output)
