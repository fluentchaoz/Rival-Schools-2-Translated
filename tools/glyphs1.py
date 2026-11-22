import sys, glob, pickle, collections, hashlib
sys.path.insert(0, r'C:\Users\Fluent\JG2-Project\repo\tools')
from practice_disc_v30 import Disc, decode
import inspect_pool_club_v22 as I
import numpy as np
S = r'C:\Users\Fluent\AppData\Local\Temp\claude\64d96de68a049de7\e3f69e87-1127-44ee-8609-cdd731c4a651\scratchpad'
o = Disc(glob.glob(r'C:\Users\Fluent\JG2-Project\1-KEEP\original-disc\*.bin')[0])
cells = {}      # hash -> (bytes, count)
for k in o.records:
    if not k.startswith('DAT2/MG') or not k.endswith('.BIZ'):
        continue
    try:
        b = decode(o.record(k))[0]
    except Exception:
        continue
    if len(b) < 0x31020:
        continue
    try:
        bk = I.banks(b)
    except Exception:
        continue
    used = set()
    for s, i, w in bk:
        for c in w:
            if c < 0x2000:
                used.add(c)
    for c in used:
        raw = b[384 + c * 200:384 + (c + 1) * 200]
        if len(raw) < 200:
            continue
        h = hashlib.md5(raw).hexdigest()
        e = cells.get(h)
        if e is None:
            cells[h] = [raw, 1]
        else:
            e[1] += 1
print(len(cells), 'unique cells')
pickle.dump(cells, open(S + r'\cells.pkl', 'wb'))
def bitmap(raw):
    a = np.frombuffer(raw, np.uint8)
    px = np.empty(400, np.uint8)
    px[0::2] = a & 15
    px[1::2] = a >> 4
    return px.reshape(20, 20)
cnt = collections.Counter(v[1] for v in cells.values())
print(sorted(cnt.items())[:10], max(cnt))
print(np.unique(bitmap(list(cells.values())[5][0])))
