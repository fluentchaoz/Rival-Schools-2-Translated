"""v137: English lettering for baked image labels (shop/bonus menus), built on exact v132.

Each job names a record, a TIM offset and label rectangles. Only those rectangles may change
(replace_pixels enforces it); everything else on the disc is preserved byte for byte, with
sector checksums regenerated and sector ownership audited like the dialogue builds.
"""
import argparse, json, shutil
from pathlib import Path
import numpy as np
from practice_disc_v30 import Disc, decode, compress, file_sha, sha, regenerate
from native_resource_catalog import audit_catalog, require_catalog
from build_practice_v30 import tim, replace_pixels
from img_label import restyle

MASTER = '721919049b456b44153ee24b948a10170e7da3da20f11155937cde51feb69c7a'
FONT = "C:/Windows/Fonts/arialn.ttf"

# (record, tim_offset): list of (rect, text, restyle keyword args)
SHADOW = dict(outline_px=2, embolden=1, shadow=(2, 2, 3))
JOBS = {
    ('DAT2/KOUBAI0.TIZ', 0x3c800): [
        ((0, 0, 256, 34), 'GO TO STORE', dict(SHADOW, fit_w=144)),
        ((0, 40, 256, 34), 'BONUSES BOUGHT', dict(SHADOW, fit_w=238)),
        ((0, 80, 256, 34), 'BACK TO MODE MENU', dict(SHADOW, fit_w=238)),
        ((0, 144, 124, 42), 'STORE', dict(SHADOW, style_from=(0, 144, 124, 42))),
    ],
    ('DAT2/KOUBAI1.TIZ', 0): [
        ((0, 0, 244, 44), 'VIEW BONUSES', dict(outline_px=2, embolden=1, flat=True, outline_idx=7)),
        ((0, 48, 199, 20), 'CARDS', dict(outline_px=1)),
        ((0, 72, 199, 19), 'POSTERS', dict(outline_px=1)),
        ((0, 96, 140, 19), 'CD', dict(outline_px=1)),
        ((0, 120, 199, 20), 'VIDEOS', dict(outline_px=1)),
        ((0, 144, 199, 20), 'ARTWORK', dict(outline_px=1)),
        ((0, 168, 199, 20), 'POCKETSTATION', dict(outline_px=1)),
        ((143, 96, 38, 20), 'BACK', dict(outline_px=1)),
        ((256, 0, 196, 27), 'CARDS', dict(outline_px=2, embolden=1, flat=True, outline_idx=6)),
        ((256, 32, 196, 29), 'POSTERS', dict(outline_px=2, embolden=1, flat=True, outline_idx=6)),
        ((256, 65, 196, 27), 'CD', dict(outline_px=2, embolden=1, flat=True, outline_idx=6)),
        ((256, 96, 196, 28), 'VIDEOS', dict(outline_px=2, embolden=1, flat=True, outline_idx=6)),
        ((256, 128, 196, 27), 'ARTWORK', dict(outline_px=2, embolden=1, flat=True, outline_idx=6)),
        ((256, 160, 196, 29), 'POCKETSTATION', dict(outline_px=2, embolden=1, flat=True, outline_idx=6)),
    ],
}


def run(a):
    if a.master.stat().st_size != 663216960 or file_sha(a.master) != MASTER:
        raise ValueError('Expected exact v136 BIN')
    if a.output.exists():
        raise ValueError('Choose new output folder')
    source = Disc(a.master)
    require_catalog(source)
    a.output.mkdir(parents=True)
    replacements = {}
    reports = []
    by_record = {}
    for (name, off), jobs in JOBS.items():
        by_record.setdefault(name, []).append((off, jobs))
    for name, groups in by_record.items():
        stored = source.record(name)
        after = bytearray(decode(stored)[0])
        before = bytes(after)
        claims = []
        for off, jobs in groups:
            t = tim(before, off)
            pix = t['pixels'].copy()
            rects = []
            for rect, text, kw in jobs:
                pix = restyle(pix, rect, text, FONT, **kw)
                rects.append(rect)
            replace_pixels(after, tim(bytes(after), off), pix, rects)
            claims.append(dict(tim_offset=hex(off), rectangles=rects, texts=[j[1] for j in jobs]))
        encoded, pr = compress(bytes(after), stored, a.accelerator)
        replacements[name] = encoded
        reports.append(dict(path=name, claims=claims, compression=pr, input_sha256=sha(stored), output_sha256=sha(encoded)))
        print(name, 'ready', flush=True)
    bindings = audit_catalog(source, replacements)['mismatches']
    exe = bytearray(source.record('SLPS_021.20'))
    for row in bindings:
        if row['path'] not in replacements:
            raise ValueError('unexpected loader mismatch')
        p = row['signature_offset']
        exe[p:p + 4] = replacements[row['path']][:4]
    if bindings:
        replacements['SLPS_021.20'] = bytes(exe)
    require_catalog(source, replacements)
    target = a.output / 'justice-gakuen2-images-v137.bin'
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
    report = dict(kind='Baked image labels v137', master_sha256=MASTER, output_sha256=file_sha(target), disc_bytes=target.stat().st_size,
                  records=reports, catalog_rebindings=bindings, catalog_audit=cat, changed_sector_count=len(changed),
                  untargeted_records_preserved=len(source.records) - len(replacements), checksums_and_sector_ownership_passed=True,
                  native_gameplay='pending')
    (a.output / 'images-v137-report.json').write_text(json.dumps(report, indent=2) + '\n')
    print('V133 COMPLETE', report['output_sha256'], 'changed sectors', len(changed), flush=True)


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('master', type=Path)
    p.add_argument('output', type=Path)
    p.add_argument('--accelerator', required=True)
    run(p.parse_args())
