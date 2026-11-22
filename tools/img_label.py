"""Re-letter an outlined/gradient label inside an indexed TIM, reusing the label's own palette indices.

The original Japanese glyphs tell us the look: per-row fill index (vertical gradient) and the outline index.
`restyle` draws English text with the same fill rows/outline, so every CLUT that recolours the image still works.
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import binary_erosion, binary_dilation


def _mode(values, default):
    if values.size == 0:
        return default
    return int(np.bincount(values.astype(np.int64)).argmax())


def learn_style(orig, bg=0):
    """Return (row_fill, outline) from the original label pixels (orig is a 2-D index array)."""
    M = orig != bg
    inner = binary_erosion(M, iterations=2)
    if inner.sum() < 20:
        inner = binary_erosion(M, iterations=1)
    if inner.sum() < 20:
        inner = M
    edge = M & ~binary_erosion(M, iterations=1)
    if edge.sum() < 20:
        edge = M
    def per_row(mask, default):
        vals = []
        for r in range(orig.shape[0]):
            sel = orig[r][mask[r]]
            vals.append(_mode(sel, -1) if sel.size else -1)
        known = [i for i, f in enumerate(vals) if f >= 0]
        if not known:
            return [default] * len(vals)
        return [vals[min(known, key=lambda k: abs(k - r))] for r in range(len(vals))]
    return per_row(inner, 1), per_row(edge, 1)


def text_mask(text, w, h, font_path, pad=2, align='left', max_size=64):
    """Largest font that fits (w-2*pad, h-2*pad); returns a boolean mask of shape (h, w)."""
    best = None
    for size in range(max_size, 5, -1):
        font = ImageFont.truetype(font_path, size)
        l, t, r, b = font.getbbox(text)
        if r - l <= w - 2 * pad and b - t <= h - 2 * pad:
            best = (font, l, t, r, b)
            break
    if best is None:
        raise ValueError('text does not fit: %r in %dx%d' % (text, w, h))
    font, l, t, r, b = best
    im = Image.new('L', (w, h), 0)
    d = ImageDraw.Draw(im)
    x = pad - l if align == 'left' else (w - (r - l)) // 2 - l
    y = (h - (b - t)) // 2 - t
    d.text((x, y), text, fill=255, font=font)
    return np.array(im) >= 128


def restyle(px, rect, text, font_path, bg=0, outline_px=2, align='left', max_size=64, style_from=None, shadow=None, embolden=0, flat=False, outline_idx=None, fit_w=None):
    """Replace the label inside rect=(x,y,w,h) of the pixel array `px` with English text. Returns a new array.

    style_from: optional rect to learn the style from (defaults to rect itself)."""
    x, y, w, h = rect
    sx, sy, sw, sh = style_from or rect
    row_fill, row_outline = learn_style(px[sy:sy + sh, sx:sx + sw], bg)
    if flat:
        row_fill = [_mode(np.array(row_fill), 1)] * len(row_fill)
        row_outline = [_mode(np.array(row_outline), 1)] * len(row_outline)
    if outline_idx is not None:
        row_outline = [outline_idx] * len(row_outline)
    if len(row_fill) != h:
        idx = np.linspace(0, len(row_fill) - 1, h).round().astype(int)
        row_fill = [row_fill[i] for i in idx]
        row_outline = [row_outline[i] for i in idx]
    core = text_mask(text, fit_w or w, h, font_path, pad=1 + outline_px + embolden, align=align, max_size=max_size)
    if fit_w and fit_w < w:
        core = np.concatenate([core, np.zeros((h, w - fit_w), dtype=bool)], axis=1)
    if embolden:
        core = binary_dilation(core, iterations=embolden)
    edge = binary_dilation(core, iterations=outline_px) & ~core
    out = px.copy()
    cell = np.full((h, w), bg, dtype=np.uint8)
    if shadow is not None:
        dx, dy, sidx = shadow
        body = core | edge
        sh = np.zeros_like(body)
        sh[dy:, dx:] = body[:h - dy, :w - dx]
        cell[sh & ~body] = sidx
    for r in range(h):
        cell[r][edge[r]] = row_outline[r]
        cell[r][core[r]] = row_fill[r]
    out[y:y + h, x:x + w] = cell
    return out
