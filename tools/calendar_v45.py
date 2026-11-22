"""v45: English month calendar screens (DAT2/MGBETA.TZZ members 0-11, 512x480 8bpp TIMs).
Japanese lettering is found by palette index (indices that never occur in known-clean background areas),
erased with copies of nearby background texture, and replaced by English drawn with palette colours that the
original lettering already used."""
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage as ndi
from build_practice_v30 import tim, rgb_palette, replace_pixels

HEAD_FONT = r'C:\Windows\Fonts\ariblk.ttf'
LIST_FONT = r'C:\Windows\Fonts\arialbd.ttf'
# member -> (heading, heading fill RGB, [(date, event)])
MONTHS = {
 0: ('JANUARY', (150, 250, 205), [('1', "NEW YEAR'S DAY")]),
 1: ('FEBRUARY', (250, 175, 215), [('14', "VALENTINE'S DAY")]),
 2: ('MARCH', (255, 255, 170), [('6', 'YEAR-END EXAMS'), ('14', 'WHITE DAY'), ('21', 'PROMOTION EXAM'), ('24', 'CLOSING CEREMONY')]),
 3: ('MAY', (0, 255, 255), [('24', '1ST TERM MIDTERMS')]),
 4: ('MAY', (0, 255, 255), [('24', '1ST TERM MIDTERMS')]),
 5: ('JUNE', (110, 250, 190), [('12', 'TAIYO VS PACIFIC')]),
 6: ('JULY', (255, 140, 20), [('12', '1ST TERM FINALS'), ('31', 'POOL')]),
 7: ('AUGUST', (0, 255, 255), [('13-14', 'SEASIDE CAMP'), ('28', 'SUMMER FESTIVAL')]),
 8: ('SEPTEMBER', (255, 30, 150), [('25', 'SCHOOL FESTIVAL')]),
 9: ('OCTOBER', (255, 255, 0), [('25', '2ND TERM MIDTERMS')]),
 10: ('NOVEMBER', (250, 210, 150), [('27', 'GORIN FESTIVAL')]),
 11: ('DECEMBER', (250, 190, 150), [('6', '2ND TERM FINALS'), ('24', 'CHRISTMAS')]),
}
DARK = (24, 24, 56)
SHADOW = (90, 60, 240)
WHITE = (255, 255, 255)
DATE = (255, 255, 110)

def text_mask(p):
    clean = np.zeros(p.shape, bool)
    clean[8:130, 430:505] = True; clean[175:262, :] = True; clean[470:480, :] = True
    bg = np.unique(p[clean])
    return ~np.isin(p, bg), set(bg.tolist())

def big_parts(mask,n=60):
    lab,k=ndi.label(ndi.binary_dilation(mask,iterations=3));sizes=ndi.sum(mask,lab,range(1,k+1))
    keep=np.zeros(k+1,bool);keep[1:]=sizes>=n;return mask&keep[lab]

def bands(mask,gap=6):
    rows = np.nonzero(mask.any(1))[0]; out = []; start = prev = rows[0]
    for r in rows[1:]:
        if r - prev > gap: out.append((start, prev)); start = r
        prev = r
    out.append((start, prev)); return out

def inpaint(p, todo, blocked):
    out = p.copy(); todo = todo.copy(); H, W = p.shape
    for w in (10, 14, 18, 24, 30, 40, 52, 64, 80, 100, 130):
        for dy, dx in ((0, -w), (0, w), (-w, 0), (w, 0), (-w, -w), (w, w)):
            ys, xs = np.nonzero(todo)
            sy, sx = ys + dy, xs + dx
            ok = (sy >= 0) & (sy < H) & (sx >= 0) & (sx < W)
            ys, xs, sy, sx = ys[ok], xs[ok], sy[ok], sx[ok]
            ok = ~blocked[sy, sx] & ~todo[sy, sx]
            out[ys[ok], xs[ok]] = p[sy[ok], sx[ok]]; todo[ys[ok], xs[ok]] = False
        if not todo.any(): break
    if todo.any():
        idx = ndi.distance_transform_edt(blocked | todo, return_distances=False, return_indices=True)
        ys, xs = np.nonzero(todo); out[ys, xs] = p[idx[0][ys, xs], idx[1][ys, xs]]
    return out

def nearest(pal, allowed, rgb):
    a = np.array(sorted(allowed)); d = ((pal[a].astype(int) - np.array(rgb)) ** 2).sum(1); return int(a[int(np.argmin(d))])

def render(text, fontfile, size, scale=3):
    font = ImageFont.truetype(fontfile, size * scale)
    box = font.getbbox(text); w = box[2] + 4 * scale; h = box[3] + 4 * scale
    im = Image.new('L', (w, h), 0); ImageDraw.Draw(im).text((0, 0), text, fill=255, font=font)
    im = im.resize((max(1, w // scale), max(1, h // scale)), Image.Resampling.BOX)
    a = np.array(im) > 110
    ys, xs = np.nonzero(a); return a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]

def stamp(canvas, a, x, y, fill, outline_idx=None, shadow_idx=None, fill_idx=None, o=2, s=3):
    """canvas: uint8 index image (written in place). Draw shadow, outline, fill for bool bitmap a with top-left (x,y)."""
    H, W = canvas.shape
    pad = o + s + 1; big = np.zeros((a.shape[0] + 2 * pad, a.shape[1] + 2 * pad), bool); big[pad:-pad, pad:-pad] = a
    ol = ndi.binary_dilation(big, structure=np.ones((3, 3), bool), iterations=o)
    sh = np.roll(np.roll(ol, s, 0), s, 1)
    def put(m, idx):
        ys, xs = np.nonzero(m); ys = ys + y - pad; xs = xs + x - pad
        ok = (ys >= 0) & (ys < H) & (xs >= 0) & (xs < W); canvas[ys[ok], xs[ok]] = idx
    put(sh & ~ol, shadow_idx); put(ol & ~big, outline_idx); put(big, fill_idx)

def patch_month(before, member):
    head, hfill, lines = MONTHS[member]
    t = tim(before, 0); p = t['pixels']; pal = rgb_palette(t)
    mask, bgset = text_mask(p); text_idx = set(np.unique(p[mask]).tolist()) - bgset
    full = ndi.binary_dilation(mask, iterations=2); mask = big_parts(mask)
    region = np.zeros(p.shape, bool); region[0:215, 0:490] = True; region[262:450, :] = True
    todo = full & region
    out = inpaint(p, todo, full)
    allowed = text_idx
    fill_h = nearest(pal, allowed, hfill); dark = nearest(pal, allowed, DARK); shad = nearest(pal, allowed, SHADOW); white = nearest(pal, allowed, WHITE); datec = nearest(pal, allowed, DATE)
    # heading
    hm = mask[0:215]; ys, xs = np.nonzero(hm); x0, y0, y1 = int(xs.min()), int(ys.min()), int(ys.max())
    for size in range(110, 30, -2):
        a = render(head, HEAD_FONT, size)
        if a.shape[1] <= 440 - x0 + 40 and a.shape[0] <= 96: break
    hy = (y0 + y1) // 2 - a.shape[0] // 2
    stamp(out, a, max(30, x0 - 6), max(6, hy), None, dark, shad, fill_h, o=3, s=4)
    # list
    lm = mask[262:450]
    for gap in (6, 4, 3, 2, 1, 0):
        bs = [(a_ + 262, b_ + 262) for a_, b_ in bands(lm, gap)]
        if len(bs) >= len(lines): break
    if len(bs) != len(lines): raise ValueError('member %d: %d text bands for %d lines' % (member, len(bs), len(lines)))
    xs_all = np.nonzero(lm.any(0))[0]; centre = (int(xs_all.min()) + int(xs_all.max())) // 2
    dsz = 30
    dates = [render(d, LIST_FONT, dsz) for d, _ in lines]; evs = [render(e, LIST_FONT, dsz) for _, e in lines]
    while True:
        dw = max(a_.shape[1] for a_ in dates); total = dw + 22 + max(a_.shape[1] for a_ in evs)
        if total <= 470 or dsz <= 20: break
        dsz -= 2; dates = [render(d, LIST_FONT, dsz) for d, _ in lines]; evs = [render(e, LIST_FONT, dsz) for _, e in lines]
    left = max(14, min(512 - 14 - total, centre - total // 2))
    for (b0, b1), da, ev in zip(bs, dates, evs):
        cy = (b0 + b1) // 2
        stamp(out, da, left + dw - da.shape[1], cy - da.shape[0] // 2, None, dark, shad, datec, o=2, s=2)
        stamp(out, ev, left + dw + 22, cy - ev.shape[0] // 2, None, dark, shad, white, o=2, s=2)
    ch = np.nonzero((out != p).any(1))[0]
    rects = []
    for lo, hi in ((0, 262), (262, 480)):
        sel = (out != p)[lo:hi]
        if sel.any():
            yy, xx = np.nonzero(sel); rects.append((int(xx.min()), int(yy.min()) + lo, int(xx.max() - xx.min() + 1), int(yy.max() - yy.min() + 1)))
    after = bytearray(before); replace_pixels(after, t, out, rects)
    return bytes(after), [dict(tim_offset='0x0', rectangles=rects)]
