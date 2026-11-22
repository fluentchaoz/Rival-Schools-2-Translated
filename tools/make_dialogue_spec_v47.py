"""Generate assets/dialogue_spec.json from assets/dialogue/tr_dlg_*.txt (corpus id|English).
Each distinct Japanese text (corpus.txt / corpus_items.pkl) is translated once and applied to every slot that still
holds the original payload. Usage:
  python make_dialogue_spec_v47.py <original.bin> <current.bin> <output.json>"""
import glob, json, pickle, re, sys
from pathlib import Path
from practice_disc_v30 import Disc, decode, sha
from backup_text_v36 import banks

ROOT = Path(__file__).resolve().parents[1]
ALLOWED = set("ABCDEFGHIJKLMNOPQRSTUVWXYZ !',-./?0123456789")

def load(folder):
    tr = {}
    for f in sorted(glob.glob(str(Path(folder) / 'tr_dlg_*.txt'))):
        for line in open(f, encoding='utf-8').read().split('\n'):
            if '|' in line:
                n, t = line.split('|', 1)
                tr[int(n)] = t.replace('\\n', '\n')
    return tr

SQUEEZE = [("FOR THE RECORD, ", ""), ("OH, RIGHT, ", ""), ("OH RIGHT, ", ""), ("UM, ", ""), ("WELL, ", ""), ("NOW THEN, ", ""), ("NOW, ", ""),
           ("ALL RIGHT, ", ""), ("OKAY, ", ""), ("GOOD, GOOD. ", ""), ("HM HM, ", ""), ("I SEE, I SEE. ", ""), ("SEE YOU NEXT MONTH", "SEE YOU"),
           ("HERE YOU ARE", "HI"), ("YEAR-END EXAMS AND THE ADVANCEMENT EXAM", "YEAR-END AND ADVANCEMENT EXAMS"), ("THERE ARE ", ""),
           ("AS I SAID BEFORE, ", ""), ("AS I SAID, ", ""), ("I SAID BEFORE, ", ""), ("REALLY, ", ""), (" VERY", ""),
           (" REALLY", ""), ("PLEASE ", ""), ("ALMOST ", ""), ("THIS MONTH'S ", ""), ("AT THE START OF EACH MONTH", "MONTHLY"), ("DO YOUR BEST", "TRY HARD"),
           ("THIS MONTH IS THE ", "IT'S THE "), ("THIS MONTH IS ", "IT'S "), ("THIS MONTH HAS ", "THERE'S "), ("YOU CAN CHANGE CLUBS AT SECOND TERM'S START", "CLUBS CAN CHANGE IN SECOND TERM"),
           ("YOU CAN CHANGE CLUBS IN THIRD TERM", "CLUBS CAN CHANGE IN THIRD TERM"), ("NEXT IS SPECIAL TRAINING. ", ""), ("GOOD WORK. ", ""), ("OKAY, GOOD WORK. ", ""),
           (" OF COURSE", ""), ("I'D RATHER YOU DIDN'T, BUT ", ""), (" IT'S YOUR CHOICE", ""), (" JUST", "")]

SMALL_ARENA = ('DAT2/MGK04.BIZ', 'DAT2/MGT00.BIZ')
NAME_CODES = ('2000', '2001', '2003', '2004', '2005', '2006', '2007', '2008', '2009')   # player-name insertions, up to ~7 cells

def line_width(jp, w):
    codes = re.findall(r'\{([0-9a-f]+)(?::\d+)?\}', jp); t = 0
    for m in re.finditer(r'\{(\d+)\}', w):
        k = int(m.group(1))
        if k < len(codes) and codes[k] in NAME_CODES: t += 7
    return len(re.sub(r'\{\d+\}', '', w)) + t

def fit(jp, en):
    def width(w): return line_width(jp, w)
    lines = en.split('\n')
    if all(width(l) <= 20 for l in lines) and len(lines) <= 4:
        return en
    def wrap(text):
        out = []; cur = ''
        for w in text.split(' '):
            trial = (cur + ' ' + w) if cur else w
            if width(trial) <= 20: cur = trial
            else:
                if cur: out.append(cur)
                cur = w
        if cur: out.append(cur)
        return out
    text = ' '.join(lines)
    out = wrap(text)
    for a, b in SQUEEZE:
        if len(out) <= 4: break
        pat = r"(?<![A-Z'])" + re.escape(a) + (r"(?![A-Z'])" if a[-1].isalpha() else "")
        if re.search(pat, text):
            text = re.sub(pat, b, text); out = wrap(text)
    return '\n'.join(out)

def problems(i, jp, en):
    out = []
    body = re.sub(r'\{\d+\}', '', en)
    bad = set(body.replace('\n', '')) - ALLOWED
    if bad:
        out.append('%d chars %r' % (i, sorted(bad)))
    lines = body.split('\n')
    if len(lines) > 4:
        out.append('%d has %d lines' % (i, len(lines)))
    for l in lines:
        if line_width(jp, l) > (22 if i >= 20000 else 20):
            out.append('%d line too long (%d): %s' % (i, line_width(jp, l), l))
    nj = len(re.findall(r'\{[0-9a-f]+(?::\d+)?\}', jp)); ne = len(re.findall(r'\{\d+\}', en))
    if nj != ne:
        out.append('%d controls %d vs placeholders %d' % (i, nj, ne))
    nums = [int(x) for x in re.findall(r'\{(\d+)\}', en)]
    if nums != list(range(len(nums))):
        out.append('%d placeholder order %r' % (i, nums))
    return out

def main(orig, cur, out):
    items = pickle.load(open(ROOT / 'assets/dialogue/corpus_items.pkl', 'rb'))
    extra = ROOT / 'assets/dialogue/remaining_items.pkl'           # ids 20000+: messages outside the main corpus (selector 2/6 etc.)
    if extra.exists():
        items = dict(enumerate(items)); items.update({20000 + k: v for k, v in enumerate(pickle.load(open(extra, 'rb')))})
    tr = load(ROOT / 'assets/dialogue')
    errs = []; good = {}
    for i, en in tr.items():
        jp = items[i][0]
        if i >= 20000 and len(en.split(chr(10))) <= 4 and all(line_width(jp, l) <= 22 for l in en.split(chr(10))):
            pass                    # hand-laid-out menu grids (rows up to 22 cells) must not be re-wrapped
        else:
            en = fit(jp, en)
        p = problems(i, jp, en)
        if p: errs.extend(p)
        else: good[i] = en
    Path(str(out) + '.problems.txt').write_text('\n'.join(errs) + '\n', encoding='utf-8')
    print(len(tr), 'translations', len(good), 'valid', len(errs), 'problems')
    o = Disc(Path(orig)); n = Disc(Path(cur))
    by_rec = {}
    for i, en in good.items():
        for rec, s, idx in items[i][1]:
            by_rec.setdefault(rec, []).append((i, s, idx, en))
    spec = {}; total = 0
    for rec, lst in sorted(by_rec.items()):
        bo = decode(o.record(rec))[0]; bn = decode(n.record(rec))[0]
        so = banks(bo); sn = banks(bn); entries = []
        for i, s, idx, en in sorted(lst):
            if rec in SMALL_ARENA and 20002 <= i <= 20012:
                continue            # these two records have almost no spare text space; skip the debug-style menus there
            if sn[s][idx] != so[s][idx]:
                continue          # already changed by an earlier patch
            entries.append(dict(id=i, selector=s, index=idx, source_payload_sha256=sha(sn[s][idx]), text=en))
        if entries:
            spec[rec] = dict(source_decoded_sha256=sha(bn), entries=entries); total += len(entries)
    Path(out).write_text(json.dumps(spec, indent=1) + '\n')
    print(len(spec), 'records', total, 'entries')

if __name__ == '__main__':
    main(*sys.argv[1:])
