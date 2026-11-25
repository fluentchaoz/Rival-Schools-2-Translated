"""Dump the PS1 VRAM (1024x512 RGB555) from a DuckStation save state (.sav) as a PNG and raw file.

Needs Python 3.14 (stdlib compression.zstd) plus Pillow/numpy (use the project venv for the latter), e.g.
  C:\Python314\python.exe is fine for decompression; run the render with the venv python on state_payload.bin.
Usage: python tools/vram_from_state.py <state.sav> <out_prefix>
Found by experiment on 2026-11-24: the file is 'DUCC' + header + zstd frame at ~0x130; in the decompressed payload the
VRAM starts 0xFFA60 bytes before the 'GPUTextureCache' marker (0x232380 in the states checked). Verify visually.
To capture a state without touching the user's slots: run the game to the screen, close DuckStation normally (it writes
<serial>_resume.sav after a few seconds), copy that file, then restore the user's backed-up resume state.
"""
import sys
from compression import zstd


def main(path, prefix):
    b = open(path, 'rb').read()
    marker = bytes.fromhex('28b52ffd')
    i = b.find(marker)
    while i >= 0:
        try:
            payload = zstd.decompress(b[i:])
            break
        except Exception:
            i = b.find(marker, i + 1)
    else:
        raise SystemExit('no zstd frame found')
    cache = payload.find(b'GPUTextureCache')
    start = cache - 0xFFA60 - 1 + 1  # observed 0x232380 when marker at 0x331de0/1
    start = 0x232380 if abs((cache - 0xFFA60) - 0x232380) <= 2 else cache - 0xFFA60
    vram = payload[start:start + 0x100000]
    open(prefix + '.raw', 'wb').write(vram)
    try:
        import numpy as np
        from PIL import Image
        v = np.frombuffer(vram, dtype='<u2').reshape(512, 1024)
        r = ((v & 31) << 3).astype(np.uint8); g = (((v >> 5) & 31) << 3).astype(np.uint8); bl = (((v >> 10) & 31) << 3).astype(np.uint8)
        Image.fromarray(np.dstack([r, g, bl])).save(prefix + '.png')
    except ImportError:
        print('numpy/Pillow missing: wrote raw only')
    print('vram start', hex(start), 'payload', len(payload))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
