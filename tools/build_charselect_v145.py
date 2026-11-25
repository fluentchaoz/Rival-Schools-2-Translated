"""v145: English Solo Play character select, built on exact v144.

SELP1-5 (DAT2, LZ-packed) get pixel edits in named rectangles only; PLSEL1-5 (DAT1, plain overlays) get an
in-place rewrite of the 21-byte banner string. Everything else on the disc is preserved byte for byte, sector
checksums are regenerated and sector ownership is audited like the earlier image builds.
"""
import argparse, json, shutil, os
from pathlib import Path
from practice_disc_v30 import Disc, decode, compress, file_sha, sha, regenerate
from native_resource_catalog import audit_catalog, require_catalog
from build_practice_v30 import tim, replace_pixels
import charselect_v145 as cs

MASTER = os.environ.get('JG2_MASTER', 'c6d02c055debc809b296661eb47182b0e4d59291c818a863875582e6c50a3043')
TIM_OFFSET = 0x17800
VERSION = os.environ.get('JG2_VERSION', '145')  # 145 = first cut, 146 = restyled lettering (same master, v144)


def run(a):
    if a.master.stat().st_size != 663216960 or file_sha(a.master) != MASTER:
        raise ValueError('Expected exact v144 BIN')
    if a.output.exists():
        raise ValueError('Choose new output folder')
    source = Disc(a.master)
    require_catalog(source)
    a.output.mkdir(parents=True)
    replacements = {}
    reports = []
    reference_name = None
    for k in range(1, 6):
        name = f'DAT2/SELP{k}.BIZ'
        stored = source.record(name)
        before = decode(stored)[0]
        after = bytearray(before)
        t = tim(bytes(after), TIM_OFFSET)
        pix, rects = cs.patch_selp(t['pixels'].copy())
        replace_pixels(after, tim(bytes(after), TIM_OFFSET), pix, rects)
        encoded, pr = compress(bytes(after), stored, a.accelerator)
        replacements[name] = encoded
        reports.append(dict(path=name, tim_offset=hex(TIM_OFFSET), rectangles=rects, compression=pr,
                            input_sha256=sha(stored), output_sha256=sha(encoded)))
        print(name, 'ready', flush=True)
    for k in range(1, 6):
        name = f'DAT1/PLSEL{k}.BIN'
        before = source.record(name)
        missing = cs.check_name_table(before)
        after, claims = cs.patch_plsel(before)
        if not claims:
            reports.append(dict(path=name, banner_string=None, note='no player-select banner string; overlay unchanged',
                                name_cells_not_relabelled=missing))
            print(name, 'no banner string; unchanged', flush=True)
            continue
        lo = int(claims[0]['offset'], 16)
        if len(after) != len(before) or any(x != y and not (lo <= i < lo + len(cs.BANNER_OLD))
                                            for i, (x, y) in enumerate(zip(before, after))):
            raise ValueError('overlay write escaped the banner string: ' + name)
        replacements[name] = after
        reports.append(dict(path=name, banner_string=claims, name_cells_not_relabelled=missing,
                            executable_instructions_unchanged=True, input_sha256=sha(before), output_sha256=sha(after)))
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
    target = a.output / f'justice-gakuen2-v{VERSION}.bin'
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
    report = dict(kind=f'Solo Play character select v{VERSION}', master_sha256=MASTER, output_sha256=file_sha(target),
                  disc_bytes=target.stat().st_size, records=reports, catalog_rebindings=bindings, catalog_audit=cat,
                  changed_sector_count=len(changed), untargeted_records_preserved=len(source.records) - len(replacements),
                  checksums_and_sector_ownership_passed=True, native_gameplay='pending')
    (a.output / f'charselect-v{VERSION}-report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'V{VERSION} COMPLETE', report['output_sha256'], 'changed sectors', len(changed), flush=True)


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('master', type=Path)
    p.add_argument('output', type=Path)
    p.add_argument('--accelerator', required=True)
    run(p.parse_args())
