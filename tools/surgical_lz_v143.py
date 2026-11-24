"""v143: surgical LZ patcher for records whose original stream layout the global encoder cannot reproduce (DAT2/OP01.BIZ).

The original stream is parsed into tokens (literal / match / zero-fill / terminator) using exactly the decoder in
practice_disc_v30.decode. Tokens whose replay already yields the patched data are kept verbatim (so the stream start,
and therefore the native catalog signature, is untouched). Only runs of tokens that disagree with the patched data are
re-encoded with a greedy matcher. Tokens are then regrouped into 16-token blocks (control word + 16 words), as in the original.
"""
import struct


def parse(data):
    """Return (tokens, end_pos). token = ('L', word) | ('M', dist, n, ext) where dist==0 means zero-fill | ('T',) terminator."""
    p = 0
    toks = []

    def word():
        nonlocal p
        v = struct.unpack_from('<H', data, p)[0]
        p += 2
        return v

    while True:
        control = word()
        done = False
        for _ in range(16):
            v = word()
            if control & 0x8000:
                n = v >> 11
                dist = v & 2047
                ext = False
                if n == 0:
                    n = word()
                    ext = True
                if n == 0 and dist == 0:
                    toks.append(('T',))
                    done = True
                    break
                toks.append(('M', dist, n, ext))
            else:
                toks.append(('L', v))
            control = (control << 1) & 65535
        if done:
            return toks, p


def emit(toks):
    out = bytearray()
    i = 0
    while i < len(toks):
        chunk = toks[i:i + 16]
        control = 0
        body = bytearray()
        for k, t in enumerate(chunk):
            if t[0] == 'L':
                body += struct.pack('<H', t[1])
            elif t[0] == 'M':
                _, dist, n, ext = t
                control |= 1 << (15 - k)
                if ext or n > 31:
                    body += struct.pack('<HH', dist, n)
                else:
                    body += struct.pack('<H', (n << 11) | dist)
            else:
                control |= 1 << (15 - k)
                body += b'\0\0\0\0'
        out += struct.pack('<H', control) + body
        i += 16
    return bytes(out)


def replay_len(t):
    return 1 if t[0] == 'L' else (t[2] if t[0] == 'M' else 0)


def words_of(data):
    return struct.unpack('<' + 'H' * (len(data) // 2), data)


def encode_span(target, start, end, window=2047, maxchain=600):
    """Greedy-encode target[start:end] (word list) given target[:start] already emitted. Returns tokens."""
    toks = []
    pos = collections_default()
    # index recent positions by word value (only those within window of any position we will query)
    lo = max(0, start - window)
    for j in range(lo, start):
        pos[target[j]].append(j)
    i = start
    while i < end:
        w = target[i]
        # zero fill run
        if w == 0:
            n = 0
            while i + n < end and target[i + n] == 0 and n < 65535:
                n += 1
            if n >= 2:
                toks.append(('M', 0, n, n > 31))
                for j in range(i, i + n):
                    pos[0].append(j)
                i += n
                continue
        best = bd = 0
        cands = pos[w]
        # drop out-of-window
        while cands and cands[0] < i - window:
            cands.popleft()
        tried = 0
        for at in reversed(cands):
            if tried >= maxchain:
                break
            tried += 1
            n = 1
            lim = min(end - i, 65535)
            while n < lim and target[i + n] == target[at + n]:
                n += 1
            if n > best:
                best, bd = n, i - at
                if best == lim:
                    break
        if best >= 2:
            toks.append(('M', bd, best, best > 31))
            for j in range(i, i + best):
                pos[target[j]].append(j)
            i += best
        else:
            toks.append(('L', w))
            pos[w].append(i)
            i += 1
    return toks


def collections_default():
    import collections
    return collections.defaultdict(collections.deque)


def surgical_patch(original_stream, new_decoded):
    """original_stream: bytes (compressed, padded ok). new_decoded: patched decoded bytes (same length as original decoded).
    Returns (new_stream_bytes_unpadded, stats)."""
    toks, _end = parse(original_stream)
    target = words_of(new_decoded)
    out = []          # replayed output words so far (== target when consistent)
    new_toks = []
    pending = None    # (start_word) of a bad run being collected
    kept = reenc = 0
    wpos = 0          # words of target consumed by the walk over ORIGINAL tokens
    # walk original tokens; decide keep/bad by replaying against target using the TARGET history (which is what will exist)
    bad_start = None
    for t in toks:
        if t[0] == 'T':
            break
        n = replay_len(t)
        ok = True
        if t[0] == 'L':
            ok = (target[wpos] == t[1])
        else:
            _, dist, nn, _e = t
            if dist == 0:
                ok = all(target[wpos + k] == 0 for k in range(nn))
            else:
                if wpos - dist < 0:
                    ok = False
                else:
                    ok = True
                    for k in range(nn):
                        if target[wpos + k] != target[wpos - dist + k]:
                            ok = False
                            break
        if ok and bad_start is None:
            new_toks.append(t)
            kept += 1
        elif ok:
            # close bad run: encode target[bad_start:wpos]
            new_toks.extend(encode_span(target, bad_start, wpos))
            reenc += 1
            bad_start = None
            new_toks.append(t)
            kept += 1
        else:
            if bad_start is None:
                bad_start = wpos
        wpos += n
    if bad_start is not None:
        new_toks.extend(encode_span(target, bad_start, wpos))
        reenc += 1
    if wpos != len(target):
        raise ValueError('target length %d != replayed %d' % (len(target), wpos))
    new_toks.append(('T',))
    stream = emit(new_toks)
    return stream, dict(tokens_original=len(toks), tokens_new=len(new_toks), kept=kept, reencoded_runs=reenc,
                        stream_bytes=len(stream))
