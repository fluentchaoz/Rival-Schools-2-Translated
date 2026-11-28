"""Patch bytes inside a DuckStation save state and write it to another slot (task 010).

Usage: python state_patch.py <src.sav> <dst.sav> <data_offset>=<byte> [...]
File layout (version 66): header | zstd frame 1 = screenshot | zstd frame 2 = machine data. Header carries, as six
consecutive u32: screenshot_compressed_size, screenshot_offset, screenshot_compression, data_compressed_size,
data_uncompressed_size, data_offset. Offsets given here are into the DATA frame (screenshot excluded); PS1 RAM starts
at data offset 0x2000, so PS1 address = 0x80000000 + (data_offset - 0x2000).
Known (SLPM-86750 fight, found by diffing three states): round timer byte at data offset 0x9ecff = PS1 0x8009CCFF.
Needs Python 3.14 (compression.zstd).
"""
import struct, sys
from compression import zstd


def main(src, dst, *patches):
    b = open(src, 'rb').read()
    fields = None
    for p in range(0, 0x200, 4):
        v = struct.unpack_from('<6I', b, p)
        if v[3] + v[5] == len(b) and v[1] < v[5] and v[2] == 2:
            fields, at = v, p
            break
    if not fields:
        raise SystemExit('header fields not found')
    ss_comp, ss_off, _, d_comp, d_unc, d_off = fields
    data = bytearray(zstd.decompress(b[d_off:d_off + d_comp]))
    assert len(data) == d_unc
    for item in patches:
        off, val = item.split('=')
        data[int(off, 0)] = int(val, 0)
    frame = zstd.compress(bytes(data))
    head = bytearray(b[:d_off])
    struct.pack_into('<I', head, at + 12, len(frame))  # data_compressed_size
    open(dst, 'wb').write(bytes(head) + frame)
    print('wrote', dst, 'data frame', d_comp, '->', len(frame))


if __name__ == '__main__':
    main(*sys.argv[1:])
