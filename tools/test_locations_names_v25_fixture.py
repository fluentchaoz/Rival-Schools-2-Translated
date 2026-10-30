"""Run v25 against the verified original as a QA fixture, never a production build."""
import argparse,os,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
PRODUCTION='c21d3d0a6ffdfc3d4a666251f450edbc5b68f16b90716101143d2c69e2415e4f'
ORIGINAL='0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e'
def main():
 p=argparse.ArgumentParser();p.add_argument('upstream',type=Path);p.add_argument('original',type=Path);p.add_argument('font',type=Path);p.add_argument('output',type=Path);a=p.parse_args();up=a.upstream.resolve();target=up/'src/dialogue_audit/name_entry_input_tests.rs';before=target.read_bytes();module=(ROOT/'patches/locations_names_v25.rs').read_text();assert module.count(PRODUCTION)==1;assert b'ENGLISH_PROJECT_LOCATIONS_NAMES_V25'not in before;assert not a.output.exists();env=os.environ.copy();env.update(JG2_V25_MASTER=str(a.original.resolve()),JG2_V25_SOURCE=str(a.original.resolve()),JG2_V25_FONT=str(a.font.resolve()),JG2_V25_OUTPUT=str(a.output.resolve()),CARGO_BUILD_JOBS='1',CARGO_PROFILE_DEV_DEBUG='0',CARGO_INCREMENTAL='0')
 try:
  target.write_bytes(before+b'\n'+module.replace(PRODUCTION,ORIGINAL).encode());subprocess.run(['cargo','test','--locked','--lib','english_project_locations_names_v25','--','--nocapture'],cwd=up,env=env,check=True)
 finally:
  target.write_bytes(before);assert target.read_bytes()==before
if __name__=='__main__':main()
