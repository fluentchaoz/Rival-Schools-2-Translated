"""v158: English ending dialogue pages (DAT2/ED*.BIZ, text TIM 0x4000), built on exact v157 (queue task 011).

Each page is patched surgically against its ORIGINAL stream (surgical_lz_v143) so the stream layout the game expects is kept;
everything else on the disc is preserved byte for byte.
"""
import argparse, json, shutil, os
from pathlib import Path
from practice_disc_v30 import Disc, decode, file_sha, sha, regenerate
from native_resource_catalog import audit_catalog, require_catalog
from endings_v156 import load_translations, patch_page, ED_TIM
import surgical_lz_v143 as S

MASTER = os.environ.get('JG2_MASTER', '')
VERSION = os.environ.get('JG2_VERSION', '158')
PAGE_CEILING = 1453743   # largest per-page output among the original disc's files (DAT2/PL01M.BIZ)


def run(a):
    if a.master.stat().st_size != 663216960 or file_sha(a.master) != MASTER:
        raise ValueError('Expected exact previous BIN (set JG2_MASTER)')
    if a.output.exists():
        raise ValueError('Choose new output folder')
    source = Disc(a.master)
    orig = Disc(a.original)       # v140 (known-good OP01 stream and executable)
    a.output.mkdir(parents=True)
    replacements = {}
    reports = []
    tr = load_translations(str(Path(__file__).resolve().parents[1] / 'translations' / 'endings_ed_en.json'))
    for short in sorted(tr):
        name = 'DAT2/%s.BIZ' % short
        stored = orig.record(name)
        if source.record(name) != stored:
            raise ValueError('record already differs from the original: ' + name)
        slot = len(source.record(name))
        if len(stored) != slot:
            raise ValueError('slot size differs: ' + name)
        before, prof = decode(stored)
        after = bytearray(before)
        size, claims = patch_page(after, short, offset=ED_TIM, translations=tr)
        stream, stats = S.surgical_patch(stored, bytes(after), equalize_size=True)
        if len(stream) > len(stored):
            raise ValueError('patched stream larger than original: %d > %d' % (len(stream), len(stored)))
        if stream[:4] != stored[:4]:
            raise ValueError('stream signature changed')
        dd, newprof = decode(stream + bytes(8))
        if dd != bytes(after):
            raise ValueError('surgical readback mismatch')
        for k in ('max_match', 'max_block'):
            if newprof[k] > prof[k]:
                raise ValueError('decoder profile exceeded: ' + k)
        # Per-page output is not a decoder limit: shipped files decode pages of over a million words (DAT2/PL01M.BIZ).
        if newprof['max_page'] > max(prof['max_page'], PAGE_CEILING):
            raise ValueError('decoder profile exceeded: max_page')
        # Originals already have 84-108 page-crossing blocks, so this count is informational only.
        print('  crossing blocks: original %d, new %d' % (prof['crossing_blocks'], newprof['crossing_blocks']))
        encoded = stream + bytes(slot - len(stream))
        replacements[name] = encoded
        reports.append(dict(path=name, claims=[dict(tim_offset=hex(o), rectangles=r) for o, r in claims],
                            surgical=stats, source_profile=prof, new_profile=newprof,
                            input_sha256=sha(stored), output_sha256=sha(encoded)))
        print(name, 'ready', stats, flush=True)
    require_catalog(source, replacements)
    target = a.output / ('justice-gakuen2-v%s.bin' % VERSION)
    shutil.copyfile(a.master, target)
    changed = {}
    with target.open('r+b') as f:
        for rec, new in replacements.items():
            lba, size = source.records[rec]
            if len(new) != size:
                raise ValueError('ISO extent changed')
            for off in range(0, size, 2048):
                sector = lba + off // 2048
                f.seek(sector * 2352)
                raw = f.read(2352)
                s = bytearray(raw)
                part = new[off:off + 2048]
                s[24:24 + len(part)] = part
                if s != raw:
                    if regenerate(raw) != raw:
                        raise ValueError('source sector checksum')
                    s = regenerate(s)
                    f.seek(sector * 2352)
                    f.write(s)
                    changed[sector] = s
    verify = Disc(target)
    for rec in source.records:
        if verify.record(rec) != replacements.get(rec, source.record(rec)):
            raise ValueError('record readback ' + rec)
    actual = []
    with a.master.open('rb') as left, target.open('rb') as right:
        lba = 0
        while True:
            x = left.read(2352 * 1024)
            y = right.read(2352 * 1024)
            if len(x) != len(y):
                raise ValueError('disc size changed')
            if not x:
                break
            for i in range(0, len(x), 2352):
                if x[i:i + 2352] != y[i:i + 2352]:
                    n = lba + i // 2352
                    actual.append(n)
                    if n not in changed or regenerate(y[i:i + 2352]) != y[i:i + 2352]:
                        raise ValueError('sector ownership/checksum')
            lba += len(x) // 2352
    if actual != sorted(changed):
        raise ValueError('sector accounting')
    cat = require_catalog(verify)
    if file_sha(a.master) != MASTER:
        raise ValueError('input modified')
    target.with_suffix('.cue').write_bytes(f'FILE "{target.name}" BINARY\r\n  TRACK 01 MODE2/2352\r\n    INDEX 01 00:00:00\r\n'.encode())
    report = dict(kind='ED ending dialogue v' + VERSION, master_sha256=MASTER, output_sha256=file_sha(target), disc_bytes=target.stat().st_size,
                  records=reports, catalog_audit=cat, changed_sector_count=len(changed),
                  untargeted_records_preserved=len(source.records) - len(replacements), checksums_and_sector_ownership_passed=True,
                  native_gameplay='pending')
    (a.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print('V%s COMPLETE' % VERSION, report['output_sha256'], 'changed sectors', len(changed), flush=True)


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('master', type=Path, help='exact previous BIN')
    p.add_argument('output', type=Path)
    p.add_argument('--original', type=Path, required=True, help='original disc BIN (source streams)')
    run(p.parse_args())
