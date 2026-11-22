"""v138: English lettering for baked image labels (shop/bonus menus), built on exact v132.

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

MASTER = '165bdaf306ede28548ce1627ac2525df5389b94071d989fd47249b20c4bf4c68'
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
        raise ValueError('Expected exact v137 BIN')
    if a.output.exists():
        raise ValueError('Choose new output folder')
    source = Disc(a.master)
    require_catalog(source)
    a.output.mkdir(parents=True)
    replacements = {}
    reports = []
    # v138: make the "SCHOOL LIFE 2" heading in the opening tutorial message bright yellow (color code 0) instead of dim blue (9)
    from backup_text_v36 import banks
    from compress_tail_v36 import compress_tail
    name = 'DAT2/MGK04.BIZ'
    stored = source.record(name)
    before = decode(stored)[0]
    bs = banks(before)
    after = bytearray(before)
    edits = []
    for sel in (0, 1):
        pay = bs[sel][0]
        if pay[:4] != bytes([0x03, 0x30, 0x09, 0x00]):
            raise ValueError('heading shape')
        at = before.find(pay)
        while at >= 0:
            after[at + 2] = 0
            edits.append(at)
            at = before.find(pay, at + 1)
    if not edits:
        raise ValueError('heading not found')
    try:
        encoded, pr = compress_tail(bytes(after), stored, a.tail_accelerator)
    except ValueError:
        encoded, pr = compress(bytes(after), stored, a.accelerator)
    replacements[name] = encoded
    reports.append(dict(path=name, heading_color_edits=sorted(set(edits)), compression=pr, input_sha256=sha(stored), output_sha256=sha(encoded)))
    print(name, 'ready', sorted(set(edits)), flush=True)
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
    target = a.output / 'justice-gakuen2-images-v138.bin'
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
    report = dict(kind='Tutorial heading colour v138', master_sha256=MASTER, output_sha256=file_sha(target), disc_bytes=target.stat().st_size,
                  records=reports, catalog_rebindings=bindings, catalog_audit=cat, changed_sector_count=len(changed),
                  untargeted_records_preserved=len(source.records) - len(replacements), checksums_and_sector_ownership_passed=True,
                  native_gameplay='pending')
    (a.output / 'images-v138-report.json').write_text(json.dumps(report, indent=2) + '\n')
    print('V133 COMPLETE', report['output_sha256'], 'changed sectors', len(changed), flush=True)


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('master', type=Path)
    p.add_argument('output', type=Path)
    p.add_argument('--accelerator', required=True)
    p.add_argument('--tail-accelerator', required=True)
    run(p.parse_args())
