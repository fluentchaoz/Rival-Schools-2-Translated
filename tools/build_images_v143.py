"""v143: fix the v141/v142 Solo Play black screen. Built on exact v142.

v141 recompressed DAT2/OP01.BIZ with the global encoder, whose page schedule does not match OP01's original stream layout
(huge zero runs, blocks crossing pages); the game could not load it. Here OP01's ORIGINAL stream (taken from the v140 disc) is
patched surgically (surgical_lz_v143): unchanged tokens stay byte-identical, only tokens covering the re-lettered text are
re-encoded. The stream start is unchanged, so the executable's catalog signature is restored to the original (no rebinding).
Everything else on the disc (including the v142 label jobs) is preserved byte for byte.
"""
import argparse, json, shutil, os
from pathlib import Path
from practice_disc_v30 import Disc, decode, file_sha, sha, regenerate
from native_resource_catalog import audit_catalog, require_catalog
from band_text_v141 import JOBS, patch_record
import surgical_lz_v143 as S

MASTER = os.environ.get('JG2_MASTER', '7b2d1ebd004754444b7227c04656b553c3f39103e820a650e0afa1854eed8fa1')


def run(a):
    if a.master.stat().st_size != 663216960 or file_sha(a.master) != MASTER:
        raise ValueError('Expected exact v142 BIN')
    if a.output.exists():
        raise ValueError('Choose new output folder')
    source = Disc(a.master)
    orig = Disc(a.original)       # v140 (known-good OP01 stream and executable)
    a.output.mkdir(parents=True)
    replacements = {}
    reports = []
    for name in JOBS:
        stored = orig.record(name)
        slot = len(source.record(name))
        if len(stored) != slot:
            raise ValueError('slot size differs: ' + name)
        before, prof = decode(stored)
        after = bytearray(before)
        claims = patch_record(after, name)
        stream, stats = S.surgical_patch(stored, bytes(after))
        if len(stream) > len(stored):
            raise ValueError('patched stream larger than original: %d > %d' % (len(stream), len(stored)))
        if stream[:4] != stored[:4]:
            raise ValueError('stream signature changed')
        dd, newprof = decode(stream + bytes(8))
        if dd != bytes(after):
            raise ValueError('surgical readback mismatch')
        for k in ('max_match', 'max_block', 'max_page'):
            if newprof[k] > prof[k]:
                raise ValueError('decoder profile exceeded: ' + k)
        encoded = stream + bytes(slot - len(stream))
        replacements[name] = encoded
        reports.append(dict(path=name, claims=[dict(tim_offset=hex(o), rectangles=r) for o, r in claims],
                            surgical=stats, source_profile=prof, new_profile=newprof,
                            input_sha256=sha(stored), output_sha256=sha(encoded)))
        print(name, 'ready', stats, flush=True)
    # v142 exe carries the v141 rebinding of OP01's signature; restore the original executable.
    cur_exe = source.record('SLPS_021.20')
    orig_exe = orig.record('SLPS_021.20')
    if len(cur_exe) != len(orig_exe):
        raise ValueError('exe size differs')
    diff = [i for i in range(len(cur_exe)) if cur_exe[i] != orig_exe[i]]
    if diff and not (min(diff) >= 494196 and max(diff) < 494200):
        raise ValueError('unexpected exe differences: %s' % diff[:10])
    if diff:
        replacements['SLPS_021.20'] = orig_exe
    require_catalog(source, replacements)
    target = a.output / 'justice-gakuen2-v143.bin'
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
    report = dict(kind='OP01 surgical fix v143', master_sha256=MASTER, output_sha256=file_sha(target), disc_bytes=target.stat().st_size,
                  records=reports, exe_restored=bool(diff), catalog_audit=cat, changed_sector_count=len(changed),
                  untargeted_records_preserved=len(source.records) - len(replacements), checksums_and_sector_ownership_passed=True,
                  native_gameplay='pending')
    (a.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print('V143 COMPLETE', report['output_sha256'], 'changed sectors', len(changed), flush=True)


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('master', type=Path, help='exact v142 BIN')
    p.add_argument('output', type=Path)
    p.add_argument('--original', type=Path, required=True, help='v140 BIN (known-good OP01 stream and executable)')
    run(p.parse_args())
