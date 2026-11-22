"""Generate assets/infirmary_labels_v43.json: every background TIM whose label strip is the Japanese infirmary label.
Usage: python make_infirmary_labels_v43.py <v42.bin> <output.json>"""
import json,struct,sys
from pathlib import Path
from practice_disc_v30 import Disc,decode,sha
from build_practice_v30 import tim
REF=('DAT2/MGBGM04.BZZ',4)
def region(stored,i):
    off,n=struct.unpack_from('<II',stored,i*8);t=tim(decode(stored[off:off+n])[0],0);return t['pixels'][220:244,:128].tobytes()
d=Disc(Path(sys.argv[1]));ref=sha(region(d.record(REF[0]),REF[1]));rows=[]
for k in d.records:
    if not(k.startswith('DAT2/MGBG')and k.endswith('.BZZ')):continue
    st=d.record(k);i=0
    while i*8+8<=len(st):
        off,n=struct.unpack_from('<II',st,i*8)
        if n==0 or off==0 or off+n>len(st) or off<i*8:break
        try:
            t=tim(decode(st[off:off+n])[0],0)
            if t['height']>=244 and t['width']>=128 and sha(t['pixels'][220:244,:128].tobytes())==ref:rows.append(dict(path=k,member=i,tim_offset=0,pixel_sha256=ref))
        except Exception:pass
        i+=1
Path(sys.argv[2]).write_text(json.dumps(rows,indent=2)+'\n');print(len(rows),'label copies in',len({r['path'] for r in rows}),'archives')
