import sys, glob, pickle, collections, hashlib, json
sys.path.insert(0, r'C:\Users\Fluent\JG2-Project\repo\tools')
from practice_disc_v30 import Disc, decode
import inspect_pool_club_v22 as I
S = r'C:\Users\Fluent\AppData\Local\Temp\claude\64d96de68a049de7\e3f69e87-1127-44ee-8609-cdd731c4a651\scratchpad'
hashes = pickle.load(open(S + r'\glyph_order.pkl', 'rb'))
chars = []
for f in sorted(glob.glob(r'C:\Users\Fluent\JG2-Project\repo\assets\glyphmap\gm_*.txt')):
    for line in open(f, encoding='utf-8').read().split('\n'):
        if line:
            chars.extend(list(line))
cmap = dict(zip(hashes, chars))
o = Disc(glob.glob(r'C:\Users\Fluent\JG2-Project\1-KEEP\original-disc\*.bin')[0])
corpus = {}
nrec = 0
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
    nrec += 1
    cc = {}
    def ch(c):
        v = cc.get(c)
        if v is None:
            raw = b[384 + c * 200:384 + (c + 1) * 200]
            v = cc[c] = cmap.get(hashlib.md5(raw).hexdigest(), '?')
        return v
    for s, i, w in bk:
        if s not in (0, 1):
            continue
        out = []
        j = 0
        w = list(w)
        while j < len(w):
            c = w[j]; j += 1
            if c == 0x3001:
                break
            if c == 0x3000:
                out.append('\n')
            elif c >= 0x2000:
                if c in (0x3002, 0x3003) or 0x2003 <= c <= 0x2009:
                    out.append('{%x:%d}' % (c, w[j])); j += 1
                else:
                    out.append('{%x}' % c)
            else:
                out.append(ch(c))
        text = ''.join(out)
        for a_, b_ in (('願問','顧問'),('寮内','案内'),('総赫','総括'),('上鼻','上昇'),('間く','聞く'),('ヅ','ゴ')):
            text = text.replace(a_, b_)
        e = corpus.setdefault(text, [])
        e.append((k, s, i))
print(nrec, 'records', len(corpus), 'distinct texts')
pickle.dump(corpus, open(S + r'\corpus.pkl', 'wb'))
occ = collections.Counter(len(v) for v in corpus.values())
print(sorted(occ.items())[:12])
tot = sum(len(t) for t in corpus)
print('total chars in distinct texts', tot, 'unknown glyph count', sum(t.count('?') for t in corpus), sum(t.count('□') for t in corpus))
