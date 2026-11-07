"""Create a private sector updater from an exact v36/v37 pair. Never package a full disc."""
import argparse,json,struct,shutil,zipfile
from pathlib import Path
from practice_disc_v30 import file_sha
from build_practice_roof_v37 import MASTER,ROOT

def run(a):
 report=json.loads((a.build/'practice-roof-v37-report.json').read_text());target=a.build/'justice-gakuen2-practice-roof-v37.bin'
 if file_sha(a.master)!=MASTER or file_sha(target)!=report['output_sha256']:raise ValueError('disc identity mismatch')
 if a.packet.exists():raise ValueError('packet output already exists')
 a.packet.mkdir(parents=True);count=0
 with a.master.open('rb')as left,target.open('rb')as right,(a.packet/'from-v36.patch').open('wb')as out:
  out.write(b'JG2V37\0\0'+bytes(4));lba=0
  while True:
   x=left.read(2352);y=right.read(2352)
   if len(x)!=len(y):raise ValueError('disc size mismatch')
   if not x:break
   if x!=y:out.write(struct.pack('<I',lba)+y);count+=1
   lba+=1
  out.seek(8);out.write(struct.pack('<I',count))
 if count!=report['changed_sector_count']:raise ValueError('sector accounting')
 manifest=dict(kind='Private v36 to v37 practice and rooftop update',output_sha256=report['output_sha256'],inputs=[dict(master_sha256=MASTER,patch_file='from-v36.patch',patch_sha256=file_sha(a.packet/'from-v36.patch'),changed_sector_count=count)])
 (a.packet/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 for src in [ROOT/'Apply-Practice-Roof-v37.ps1',ROOT/'tools/apply_practice_roof_v37.py',ROOT/'PRACTICE_ROOF_V37.md',ROOT/'validation/practice-roof-v37.json',a.build/'practice-roof-v37-report.json']:shutil.copyfile(src,a.packet/src.name)
 (a.packet/'README.txt').write_text('''JUSTICE GAKUEN 2 — V37 PRIVATE UPDATE

Apply to exact justice-gakuen2-menu-art-v36.bin. Keep the original disc and cards.
Extract all files from this ZIP together. If you put them in the same
exam-dance-v35 folder used for v36, open PowerShell there and run:

powershell -NoProfile -ExecutionPolicy Bypass -File .\\Apply-Practice-Roof-v37.ps1 -MasterBin ".\\menu-art-v36\\justice-gakuen2-menu-art-v36.bin"

If you put this packet beside the v36 BIN instead, run the same command with
-MasterBin ".\\justice-gakuen2-menu-art-v36.bin".

The script verifies hashes and creates a new practice-roof-v37 folder.
Requires 700 MB free. Refuses to overwrite any existing output folder.
Fresh-boot practice-roof-v37/justice-gakuen2-practice-roof-v37.cue.
Use an in-game save; old emulator states can restore old resources.

Includes the approved Kyosuke card, PK Shootout GUTS caption, shared pause
menus, sixteen ROOFTOP labels and 53 dialogue entries for each player variant
in the Edge/Daigo rooftop encounter, including the reviewed choices/outcomes.
Other rooftop events and other loading illustrations are not fully translated.

Offline validation passed; native gameplay remains pending. The PowerShell
wrapper was reviewed, not executed here. The equivalent Python updater is
verified separately. Report any clipping, behavior changes or remaining pages.
''')
 print(a.packet,flush=True)
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('master',type=Path);p.add_argument('build',type=Path);p.add_argument('packet',type=Path);run(p.parse_args())
