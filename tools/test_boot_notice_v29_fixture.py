"""Local original-disc fixture; production requires actual v28. Run from repository parent with prepared JG2_V29 paths."""
from pathlib import Path
import subprocess,os
up=Path(os.environ['JG2_V29_UPSTREAM']).resolve();p=up/'src/dialogue_audit/name_entry_input_tests.rs';before=p.read_bytes();module=Path(__file__).resolve().parents[1].joinpath('patches/boot_notice_v29.rs').read_text();module=module.replace('47ed14e1936a0072be400dcdd41296be264ab8bdc1ddcff0e4e7be3bfdc4902b','0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e');env=os.environ.copy();env.update(JG2_V29_MASTER=env['JG2_V29_SOURCE'],CARGO_BUILD_JOBS='1',CARGO_PROFILE_DEV_DEBUG='0',CARGO_INCREMENTAL='0')
try:
 p.write_bytes(before+b'\n'+module.encode());subprocess.run(['cargo','test','--locked','--lib','english_project_boot_notice_v29','--','--nocapture'],cwd=up,env=env,check=True)
finally:p.write_bytes(before);assert p.read_bytes()==before
