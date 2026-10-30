"""Original-disc QA fixture only; production always requires the actual v25 hash."""
import argparse,hashlib,os,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
PRODUCTION='5f31d90f089f520d6824add5c5368e10be2607955ad3b9e5c24b73b9aa010453'
ORIGINAL='0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e'
def main():
 p=argparse.ArgumentParser();p.add_argument('upstream',type=Path);p.add_argument('original',type=Path);p.add_argument('font',type=Path);p.add_argument('packet',type=Path);p.add_argument('output',type=Path);p.add_argument('--preservation-only',action='store_true');a=p.parse_args()
 up=a.upstream.resolve();target=up/'src/dialogue_audit/name_entry_input_tests.rs';before=target.read_bytes();module=(ROOT/'patches/shared_dates_v26.rs').read_text();assert module.count(PRODUCTION)==1;assert b'ENGLISH_PROJECT_SHARED_DATES_V26' not in before;assert not a.output.exists()
 with a.original.open('rb') as f:assert hashlib.file_digest(f,'sha256').hexdigest()==ORIGINAL,'original fixture identity'
 env=os.environ.copy();env.update(JG2_V26_MASTER=str(a.original.resolve()),JG2_V26_SOURCE=str(a.original.resolve()),JG2_V26_FONT=str(a.font.resolve()),JG2_V26_PACKET=str(a.packet.resolve()),JG2_V26_OUTPUT=str(a.output.resolve()),JG2_V26_QA_DUMP='1',CARGO_BUILD_JOBS='1',CARGO_PROFILE_DEV_DEBUG='0',CARGO_INCREMENTAL='0')
 try:
  target.write_bytes(before+b'\n'+module.replace(PRODUCTION,ORIGINAL).encode())
  name='english_project_shared_dates_v26_preservation' if a.preservation_only else 'english_project_shared_dates_v26'
  subprocess.run(['cargo','test','--locked','--lib',name,'--','--nocapture'],cwd=up,env=env,check=True)
 finally:
  target.write_bytes(before);assert target.read_bytes()==before
if __name__=='__main__':main()
