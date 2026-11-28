"""v159: English move-list sheets (DAT2/EDITCM01-24.BIZ: TIM 0 and the shared name list at 0x13000), built on exact v158 (queue 013)."""
import argparse, json, shutil, os
from pathlib import Path
from practice_disc_v30 import Disc, decode, compress, file_sha, sha, regenerate
from native_resource_catalog import audit_catalog, require_catalog
from build_practice_v30 import tim, replace_pixels
import editcm_v159 as M
from build_practice_v30 import rgb_palette

MASTER = os.environ.get('JG2_MASTER', '')  # SHA-256 of the exact v151 play BIN
TIM_OFFSET = 0x10800
VERSION = os.environ.get('JG2_VERSION', '159')


def run(a):
    if a.master.stat().st_size != 663216960 or file_sha(a.master) != MASTER:
        raise ValueError('Expected exact v151 BIN (set JG2_MASTER to its SHA-256)')
    if a.output.exists():
        raise ValueError('Choose new output folder')
    source = Disc(a.master)
    require_catalog(source)
    a.output.mkdir(parents=True)
    replacements = {}
    reports = []
    orig = Disc(a.original)
    names = M.load_names()
    for key in sorted(names):
        name = 'DAT2/EDITCM%s.BIZ' % key
        stored = source.record(name)
        if stored != orig.record(name):
            raise ValueError('record already differs from the original: ' + name)
        after = bytearray(decode(stored)[0])
        odata = decode(orig.record(name))[0]
        t0 = tim(odata, 0)
        pix0 = M.patch_sheet(t0['pixels'], key, rgb_palette(t0, 0), names)
        replace_pixels(after, tim(bytes(after), 0), pix0, [(0, 0, t0['width'], t0['height'])])
        t1 = tim(odata, M.LIST_TIM)
        pix1 = M.patch_list(t1['pixels'], rgb_palette(t1, 0))
        replace_pixels(after, tim(bytes(after), M.LIST_TIM), pix1, [(0, 0, t1['width'], t1['height'])])
        encoded, pr = compress(bytes(after), stored, a.accelerator)
        replacements[name] = encoded
        reports.append(dict(path=name, compression=pr, input_sha256=sha(stored), output_sha256=sha(encoded)))
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
    report = dict(kind=f'Fight HUD announcer art v{VERSION}', master_sha256=MASTER, output_sha256=file_sha(target),
                  disc_bytes=target.stat().st_size, records=reports, catalog_rebindings=bindings, catalog_audit=cat,
                  changed_sector_count=len(changed), untargeted_records_preserved=len(source.records) - len(replacements),
                  checksums_and_sector_ownership_passed=True, native_gameplay='pending')
    (a.output / f'hud-v{VERSION}-report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'V{VERSION} COMPLETE', report['output_sha256'], 'changed sectors', len(changed), flush=True)


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('master', type=Path)
    p.add_argument('output', type=Path)
    p.add_argument('--accelerator', required=True)
    p.add_argument('--original', type=Path, required=True, help='original disc BIN: styles are learnt from its unedited sprites')
    run(p.parse_args())
