"""v140: English title cards + rules pages for the regular (non-practice) minigame records MINITTL0-4, 9, A.

Reuses the practice-mode rules text (build_practice_v30.GAMES) because the Japanese rules pages carry the same
content. Landing pages keep their artwork: only the old title banner and the speech-bubble text are replaced.
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import binary_closing, binary_fill_holes, label
from build_practice_v30 import (GAMES, tim, rgb_image, rgb_palette, replace_pixels, paint_text, quantize, rules_panel)

TITLE_FONT = 'C:/Windows/Fonts/arialbd.ttf'
TEXT_FONT = 'C:/Windows/Fonts/arialbd.ttf'

# key: (title or None, bubble seed point inside the bubble face, tagline lines, practice-GAMES key for the rules pages)
PAGES = {
    '0': dict(title='GORIN FESTIVAL', bubble=None, lines=None, game=None),
    '1': dict(title="SHOMA'S HOME RUN CONTEST", seed=(284, 140), lines=['Find your sweet spot and', 'go for Home Run King!'], game='5'),
    '2': dict(title="ROBERTO'S PK SHOOTOUT", seed=(80, 145), lines=["Read your opponent's mind", 'and put it in the net!'], game='6'),
    '3': dict(title="ROBERTO'S EXPLOSIVE SHOT", seed=(70, 130), lines=['Take down 4 panels in one!', 'Go for a perfect score!'], game='7'),
    '4': dict(title='SUMMER SERVICE ACE', seed=(292, 130), lines=['Memorize the high-score panels', 'and nail every serve!'], game='8'),
    '9': dict(title='SHOWDOWN! FIERY SPRINT', seed=(285, 124), lines=["Don't just mash the button!", 'Time your acceleration!'], game='B'),
    'A': dict(title=None, seed=(262, 140), lines=['Use rhythm and memory', 'to win her heart!'], game='C'),
}


def _font(path, size):
    return ImageFont.truetype(path, size)


def bubble_region(arr, seed, tol=34):
    """Flat-colour face of the speech bubble (text holes filled)."""
    fill = arr[seed[1], seed[0]].astype(int)
    near = (np.abs(arr.astype(int) - fill).sum(axis=2) <= tol)
    lab, _ = label(near)
    comp = lab == lab[seed[1], seed[0]]
    comp = binary_closing(comp, iterations=4)
    comp = binary_fill_holes(comp)
    return comp, tuple(int(v) for v in fill)


def patch_landing(data, p, fontpath):
    t = tim(data, 0x18800)
    if (t['width'], t['height'], t['mode']) != (512, 480, 1):
        raise ValueError('landing geometry')
    pal = rgb_palette(t)
    im = rgb_image(t)
    arr = np.array(im)
    owned = []
    d = ImageDraw.Draw(im)
    if p['title']:
        d.rounded_rectangle((16, 12, 496, 94), radius=8, fill=(25, 18, 25), outline=(255, 222, 90), width=2)
        paint_text(im, (24, 20, 464, 66), p['title'], TITLE_FONT, (255, 235, 130), (0, 0, 0), 40)
        owned.append((16, 12, 481, 83))
    if p['lines']:
        comp, fill = bubble_region(arr, p['seed'])
        ys, xs = np.where(comp)
        x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
        ink = arr[comp]
        far = ink[np.abs(ink.astype(int) - np.array(fill)).sum(axis=1) > 120]
        col = tuple(int(v) for v in np.median(far, axis=0)) if len(far) > 30 else (90, 20, 90)
        col = tuple(int(c * 0.55) for c in col)
        layer = Image.new('RGB', im.size, fill)
        cd = ImageDraw.Draw(layer)
        # blank the whole face, then letter English inside it
        face = Image.fromarray((comp * 255).astype('uint8'))
        im.paste(layer, (0, 0), face)
        d = ImageDraw.Draw(im)
        cx = (x0 + x1) // 2
        # use the middle rows' span so slanted edges don't clip the text
        my0, my1 = y0 + (y1 - y0) // 4, y1 - (y1 - y0) // 4
        span_l = max(xs[(ys >= my0) & (ys <= my1)].min(), x0)
        span_r = xs[(ys >= my0) & (ys <= my1)].max()
        cx = (span_l + span_r) // 2
        w = int(span_r - span_l - 40)
        size = 16
        while size > 8:
            f = _font(TEXT_FONT, size)
            if max(d.textlength(l, font=f) for l in p['lines']) <= w:
                break
            size -= 1
        f = _font(TEXT_FONT, size)
        lh = size + 4
        top = (y0 + y1) // 2 - lh * len(p['lines']) // 2
        for i, line in enumerate(p['lines']):
            tw = d.textlength(line, font=f)
            d.text((cx - tw / 2, top + i * lh), line, font=f, fill=col)
        owned.append((int(x0), int(y0), int(x1 - x0 + 1), int(y1 - y0 + 1)))
    q = quantize(im, pal)
    pix = t['pixels'].copy()
    for x, y, w, h in owned:
        pix[y:y + h, x:x + w] = q[y:y + h, x:x + w]
    replace_pixels(data, t, pix, owned)
    return owned


def patch_record(data, key, fontpath):
    p = PAGES[key]
    claims = [(0x18800, patch_landing(data, p, fontpath))]
    if p['game']:
        g = GAMES[p['game']]
        for page in range(len(g['rules']) if key == '2' else 1):
            at = 0x55000 if page == 0 else 0x91800
            claims.append((at, rules_panel(data, g, page, fontpath)))
    return claims
