"""Extract every story-record message that is still Japanese in a built disc, grouped by distinct text."""
import sys, glob, pickle, collections, hashlib, re
sys.path.insert(0, r'C:\Users\Fluent\JG2-Project\repo\tools')
from practice_disc_v30 import Disc, decode
import inspect_pool_club_v22 as I
S = r'C:\Users\Fluent\AppData\Local\Temp\claude\64d96de68a049de7\e3f69e87-1127-44ee-8609-cdd731c4a651\scratchpad'
built = sys.argv[1]; out = sys.argv[2]
hashes = pickle.load(open(S + r'\glyph_order.pkl', 'rb'))
chars = []
for f in sorted(glob.glob(r'C:\Users\Fluent\JG2-Project\repo\assets\glyphmap\gm_*.txt')):
    for line in open(f, encoding='utf-8').read().split('\n'):
        if line:
            chars.extend(list(line))
cmap = dict(zip(hashes, chars))
o = Disc(glob.glob(r'C:\Users\Fluent\JG2-Project\1-KEEP\original-disc\*.bin')[0]); n = Disc(built)
corpus = {}
for k in o.records:
    if not k.startswith('DAT2/MG') or not k.endswith('.BIZ'):
        continue
    try:
        bo = decode(o.record(k))[0]; bn = decode(n.record(k))[0]
    except Exception:
        continue
    if len(bo) < 0x31020:
        continue
    try:
        ko = {(s, i): w for s, i, w in I.banks(bo)}; kn = {(s, i): w for s, i, w in I.banks(bn)}
    except Exception:
        continue
    cc = {}
    def ch(c):
        v = cc.get(c)
        if v is None:
            v = cc[c] = cmap.get(hashlib.md5(bo[384 + c * 200:384 + (c + 1) * 200]).hexdigest(), None)
        return v
    for (s, i), w in ko.items():
        if tuple(kn.get((s, i), ())) != tuple(w):
            continue                      # already changed on the built disc
        w = list(w); res = []; j = 0; jp = False
        while j < len(w):
            c = w[j]; j += 1
            if c == 0x3001: break
            if c == 0x3000: res.append('\n')
            elif c >= 0x2000:
                if c in (0x3002, 0x3003) or 0x2003 <= c <= 0x2009:
                    res.append('{%x:%d}' % (c, w[j])); j += 1
                else: res.append('{%x}' % c)
            else:
                g = ch(c)
                if g is None: res.append('?'); jp = True
                else:
                    res.append(g)
                    if re.search(r'[\u3040-\u30ff\u4e00-\u9fff]', g): jp = True
        if not jp: continue
        text = ''.join(res)
        corpus.setdefault(text, []).append((k, s, i))
items = sorted(corpus.items(), key=lambda kv: (-len(kv[1]), kv[0]))
pickle.dump(items, open(out + '.pkl', 'wb'))
with open(out + '.txt', 'w', encoding='utf-8') as f:
    for idx, (t, locs) in enumerate(items):
        sels = sorted({x[1] for x in locs})
        f.write('%d|%d|%s|%s|%s\n' % (idx, len(locs), t.replace('\n', ' / '), ','.join(map(str, sels)), ','.join(sorted({x[0].split('/')[-1][:-4] for x in locs})[:3])))
print(len(items), 'distinct remaining texts,', sum(len(v) for _, v in items), 'slots')
