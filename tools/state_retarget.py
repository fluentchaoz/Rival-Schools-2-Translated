"""Point a DuckStation save state at another disc image (task 010).

A state records the path of the disc it was made on, and loading it can switch the emulator back to THAT disc, so
`-state N <other build>` may silently run the old build. This rewrites the recorded path, which must have the SAME length
(v155 -> v156 does; for other paths pad the file name).
Usage: python tools/state_retarget.py <src.sav> <dst.sav> <old path> <new path>
"""
import sys


def main(src, dst, old, new):
    if len(old) != len(new):
        raise SystemExit('paths must have the same length (%d vs %d)' % (len(old), len(new)))
    b = open(src, 'rb').read()
    i = b.find(old.encode())
    if i < 0 or i > 0x400:
        raise SystemExit('old path not found in the state header')
    open(dst, 'wb').write(b[:i] + new.encode() + b[i + len(old):])
    print('wrote', dst)


if __name__ == '__main__':
    main(*sys.argv[1:])
