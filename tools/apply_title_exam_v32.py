"""Apply the private cumulative v32 patch from exact v29, v30 or v31, without overwrite."""
import argparse,hashlib,json,shutil,struct
from pathlib import Path
SUPPORTED={'f9a3d199c9f535188258203b3a4ddea159755fe35b52e88a8c0c273871b7e7f2','f4f974c40220dd82925d4b17d6a31b3f95218a6017783666851204ea3040c67f','c9fdc6a749084fdf972b4debb36dda6b77cb44e0b34f4161d27573130dc44815'}
def digest(p):
 with p.open('rb')as f:return hashlib.file_digest(f,'sha256').hexdigest()
def apply(master,packet,output):
 manifest=json.loads((packet/'manifest.json').read_text());h=digest(master);options=[s for s in manifest['inputs']if s['master_sha256']==h]
 if master.stat().st_size!=663216960 or h not in SUPPORTED or len(options)!=1:raise ValueError('Select the exact recovered v29, v30 or v31 BIN. Source unchanged.')
 spec=options[0]
 if spec['patch_file']not in ('from-v29.patch','from-v30.patch','from-v31.patch'):raise ValueError('invalid patch name')
 patch=packet/spec['patch_file']
 if digest(patch)!=spec['patch_sha256']:raise ValueError('patch checksum mismatch')
 if output.exists():raise ValueError('output directory already exists')
 with patch.open('rb')as f:
  if f.read(8)!=b'JG2V32\0\0':raise ValueError('patch header')
  count=struct.unpack('<I',f.read(4))[0];entries=[];last=-1
  if count!=spec['changed_sector_count']:raise ValueError('patch count')
  for _ in range(count):
   lba=struct.unpack('<I',f.read(4))[0];raw=f.read(2352)
   if lba<=last or (lba+1)*2352>663216960 or len(raw)!=2352:raise ValueError('invalid patch entry')
   entries.append((lba,raw));last=lba
  if f.read(1):raise ValueError('trailing patch bytes')
 output.mkdir(parents=True);target=output/'justice-gakuen2-title-exam-v32.bin'
 with master.open('rb')as src,target.open('xb')as dst:shutil.copyfileobj(src,dst,1024*1024)
 with target.open('r+b')as f:
  for lba,raw in entries:f.seek(lba*2352);f.write(raw)
 if digest(target)!=manifest['output_sha256']:raise ValueError('Output verification failed; do not boot this output')
 cue=target.with_suffix('.cue');cue.write_bytes(f'FILE "{target.name}" BINARY\r\n  TRACK 01 MODE2/2352\r\n    INDEX 01 00:00:00\r\n'.encode());print('V32 VERIFIED:',cue)
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('master',type=Path);p.add_argument('--packet',type=Path,default=Path(__file__).resolve().parent);p.add_argument('--output',type=Path,default=Path('title-exam-v32'));a=p.parse_args();apply(a.master,a.packet,a.output)
