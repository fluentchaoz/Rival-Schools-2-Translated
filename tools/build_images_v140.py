"""v140: English minigame title cards and rules pages (regular, non-practice versions), built on exact v139.

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
from minigame_pages_v140 import PAGES, patch_record

import os
MASTER = os.environ.get('JG2_MASTER', 'ef2b241959e11f5e2261cfa03516aab44627fda24a63d2670f3731b56570d189')
FONT = "C:/Windows/Fonts/arialn.ttf"


def run(a):
    if a.master.stat().st_size != 663216960 or file_sha(a.master) != MASTER:
        raise ValueError('Expected exact v139 BIN')
    if a.output.exists():
        raise ValueError('Choose new output folder')
    source = Disc(a.master)
    require_catalog(source)
    a.output.mkdir(parents=True)
    replacements = {}
    reports = []
    for key in PAGES:
        name = f'DAT2/MINITTL{key}.BIZ'
        stored = source.record(name)
        before = decode(stored)[0]
        after = bytearray(before)
        claims = patch_record(after, key, FONT)
        encoded, pr = compress(bytes(after), stored, a.accelerator)
        replacements[name] = encoded
        reports.append(dict(path=name, claims=[dict(tim_offset=hex(o), rectangles=r) for o, r in claims], compression=pr, input_sha256=sha(stored), output_sha256=sha(encoded)))
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
    target = a.output / 'justice-gakuen2-images-v140.bin'
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
    report = dict(kind='Baked image labels v140', master_sha256=MASTER, output_sha256=file_sha(target), disc_bytes=target.stat().st_size,
                  records=reports, catalog_rebindings=bindings, catalog_audit=cat, changed_sector_count=len(changed),
                  untargeted_records_preserved=len(source.records) - len(replacements), checksums_and_sector_ownership_passed=True,
                  native_gameplay='pending')
    (a.output / 'images-v140-report.json').write_text(json.dumps(report, indent=2) + '\n')
    print('V140 COMPLETE', report['output_sha256'], 'changed sectors', len(changed), flush=True)


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('master', type=Path)
    p.add_argument('output', type=Path)
    p.add_argument('--accelerator', required=True)
    run(p.parse_args())
