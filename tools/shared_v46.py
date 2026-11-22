"""v46: shared UI/item/practice/quiz strings applied to every story record.
Translations live in assets/shared/tr_*.txt as 'pattern|text' lines. A pattern is a distinct glyph/control signature
found in the original disc; every record slot with that signature (and still unchanged) gets the English text.
'{D}' expands to the native month/day insertion: 0x3003,1 / 0x200a / '/' glyph / 0x200b / 0x3003,255."""
import glob, hashlib, re, struct
from pathlib import Path
from practice_disc_v30 import sha
from build_practice_v30 import tim
from backup_text_v36 import banks, tokens, compact, ARENA, LIMIT

ALLOWED = set("ABCDEFGHIJKLMNOPQRSTUVWXYZ !',-./?")

def load_translations(folder):
    tr = {}
    for f in sorted(glob.glob(str(Path(folder) / 'tr_*.txt'))):
        for line in open(f, encoding='utf-8').read().split('\n'):
            if '|' in line:
                n, t = line.split('|', 1); tr[int(n)] = t.replace('\\n', '\n')
    errs = []
    for n, t in tr.items():
        body = t.replace('{D}', '')
        bad = set(body.replace('\n', '')) - ALLOWED
        if bad: errs.append('pattern %d chars %r' % (n, bad))
        for line in body.split('\n'):
            if len(line) > 20: errs.append('pattern %d line too long: %s' % (n, line))
        if len(t.split('\n')) > 5: errs.append('pattern %d too many lines' % n)
    if errs: raise ValueError('\n'.join(errs))
    return tr

def signature(bo, w):
    return hashlib.md5(repr([('c', c) if c >= 0x2000 else hashlib.md5(bo[384 + c * 200:384 + (c + 1) * 200]).hexdigest() for c in w]).encode()).hexdigest()

def patch_shared(before, reference, spec, gap=0):
    if sha(before) != spec['source_decoded_sha256']: raise ValueError('shared preimage')
    bs = banks(before); desired = {s: ms.copy() for s, ms in bs.items()}; t = tim(before, 0); rt = tim(reference, 0); slots = (ARENA - t['offset']) // 200
    canonical = {c: 707 + i for i, c in enumerate('ABCDEFGHIJKLMNOPRSTUVWXYQZ')}
    canonical.update({'!': 701, "'": 702, ',': 703, '-': 704, '.': 705, '/': 706, '?': 66})
    canonical.update({d: i for i, d in enumerate('1234567890', 1)})   # digits keep the original atlas cells 1..10
    chars = set(re.sub(r'\{\d+\}|\{D\}', '/', ''.join(e['text'] for e in spec['entries'])).replace('\n', '')) | {'/'}; codes = {}
    for c in sorted(chars):
        raw = bytes(200) if c == ' ' else reference[rt['offset'] + canonical[c] * 200:rt['offset'] + (canonical[c] + 1) * 200]
        found = next((i for i in range(slots) if before[t['offset'] + i * 200:t['offset'] + (i + 1) * 200] == raw), None)
        if found is None: raise ValueError('missing existing English glyph ' + c)
        codes[c] = found
    targets = set(); skipped = []
    for e in spec['entries']:
        s, i = e['selector'], e['index']; old = bs[s][i]; targets.add((s, i))
        if sha(old) != e['source_payload_sha256']: raise ValueError('message preimage')
        controls = [(c, a) for c, a in tokens(old) if c >= 0x2000 and c not in (0x3000, 0x3001)]
        words = []
        text = e['text']
        if text.startswith('{D}'):
            if [c for c, a in controls] != [0x3003, 0x200a, 0x200b, 0x3003]: raise ValueError('date header shape')
            words += [0x3003, controls[0][1][0], 0x200a, codes['/'], 0x200b, 0x3003, controls[3][1][0]]; text = text[3:]
            used = 4
        elif re.search(r'\{\d+\}', text):
            used = -1
        elif not controls:
            used = 0
        elif len(controls) == 2 and controls[0][0] == 0x3003 and controls[1] == (0x3003, (255,)) and next(iter(tokens(old)))[0] == 0x3003:
            words += [0x3003, controls[0][1][0]]; used = 2; wrap = True
        else:
            skipped.append((s, i)); targets.discard((s, i)); continue
        if used == -1:
            nextc = 0
            for part in re.split(r'(\{\d+\})', text):
                if not part: continue
                if part.startswith('{'):
                    assert int(part[1:-1]) == nextc; c, a = controls[nextc]; words.extend([c, *a]); nextc += 1
                else:
                    words.extend(0x3000 if ch == '\n' else codes[ch] for ch in part)
            assert nextc == len(controls)
        else:
            for ch in text:
                words.append(0x3000 if ch == '\n' else codes[ch])
        if used == 2 and not text.startswith('\n') and controls and controls[0][0] == 0x3003 and len(controls) == 2: words += [0x3003, 255]
        words.append(0x3001)
        if len(words) % 2: words.append(0)
        desired[s][i] = struct.pack('<' + 'H' * len(words), *words)
    after, usedspace = compact(before, desired, gap)
    if after[:ARENA] != before[:ARENA] or after[LIMIT:] != before[LIMIT:]: raise ValueError('escaped text arena')
    actual = banks(after)
    for s, ms in bs.items():
        for i, m in enumerate(ms):
            if (s, i) not in targets and actual[s][i] != m: raise ValueError('untargeted message changed')
    return bytes(after), dict(translated_coordinates=len(targets), arena_gap=gap, arena_used=usedspace, english_codes=codes, skipped_unsupported_controls=skipped)
