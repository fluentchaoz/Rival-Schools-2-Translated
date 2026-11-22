"""v41: English text for the Mode Select description cards (DAT2/MENU.BIZ, 176x112 4bpp TIMs without CLUT,
first at 0x4b800 with stride 0x2800). Panel 6 (School Life 2) is already English and is left untouched."""
import struct
import numpy as np
from PIL import Image, ImageDraw, ImageFont

FIRST, STRIDE, W, H, INK = 0x4b800, 0x2800, 176, 112, 1
FONT_FILE = r'C:\Windows\Fonts\arialbd.ttf'
TEXT = {
 0: ["A standard solo mode.", "Of course, rivals can jump", "in and fight you, too!"],
 1: ["A mode made just for", "two-player versus battles."],
 2: ["Practice the practical exams", "from Youth Diary 2.", "Review the basics and learn", "core techniques too!!"],
 3: ["Freely change the button", "settings, difficulty and", "game rules."],
 4: ["Save and load your data", "on the memory card."],
 5: ["Play games and earn points!", "Buy all sorts of extras at", "the school store!", "Download Pocket Justice", "right here!"],
 7: ["Team up to beat the enemy.", "The synergy check reads", "your chemistry! Up to 4", "players can join in at once."],
 8: ["Pick 2 to 4 characters", "for a team battle where", "fighters swap after each", "match."],
 9: ["Hold a tournament with", "up to 8 players."],
 10: ["Pick 2 to 6 characters", "for a round-robin", "league."],
 11: ["Practice the mini-games", "from Youth Diary 2."],
 12: ["Register EDIT characters", "from Youth Diary 2 save data", "and use them in the game.", "New features too: password", "entry, CPU tactic settings!!"],
 13: ["Train combos and special", "moves. EDIT characters", "can be used too!"],
}
def offset(k): return FIRST + k * STRIDE
def read(b, k):
    o = offset(k)
    if b[o:o + 4] != b'\x10\0\0\0' or struct.unpack_from('<IIHHHH', b, o + 4) != (0, 9868, 832, 256, 44, 112):
        raise ValueError('description TIM identity %d' % k)
    a = np.frombuffer(b, np.uint8, count=88 * H, offset=o + 20).reshape(H, 88)
    px = np.empty((H, W), np.uint8); px[:, 0::2] = a & 15; px[:, 1::2] = a >> 4
    return px
def write(buf, k, px):
    raw = px.ravel(); raw = raw[::2] | (raw[1::2] << 4)
    o = offset(k) + 20; buf[o:o + raw.size] = raw.tobytes()
def render(lines, size):
    font = ImageFont.truetype(FONT_FILE, size)
    pitch = size + 3; width = 0; pieces = []
    for line in lines:
        im = Image.new('L', (W * 2, size * 2), 0); d = ImageDraw.Draw(im); d.fontmode = '1'
        d.text((0, 0), line, fill=255, font=font)
        a = np.array(im) > 127; cols = np.nonzero(a.any(0))[0]
        pieces.append(a); width = max(width, int(cols.max()) + 1)
    return pieces, width, pitch
def layout(k, lines):
    for size in range(14, 7, -1):
        pieces, width, pitch = render(lines, size)
        if width <= 160 and pitch * len(lines) <= 104: return pieces, width, pitch, size
    raise ValueError('text does not fit %d' % k)
def compose(old, k, lines):
    pieces, width, pitch, size = layout(k, lines)
    ys = np.nonzero((old != 0).any(1))[0]; centre = (int(ys.min()) + int(ys.max())) // 2
    top = max(1, min(H - pitch * len(lines) - 1, centre - pitch * len(lines) // 2))
    new = np.zeros_like(old)
    for n, a in enumerate(pieces):
        rows = np.nonzero(a.any(1))[0]; r0 = int(rows.min())
        # align each line by the font's shared baseline: use the full-size cell, not per-line trimming
        cell = a[:size + 3]; h = min(cell.shape[0], H - (top + n * pitch)); w = min(cell.shape[1], W - 4)
        sub = new[top + n * pitch: top + n * pitch + h, 4:4 + w]; sub[cell[:h, :w]] = INK
    return new, (4, top, width, pitch * len(lines)), size
def patch_all(before, tim=None, replace_pixels=None):
    after = bytearray(before); claims = []; sizes = {}
    for k, lines in TEXT.items():
        old = read(before, k); new, rect, size = compose(old, k, lines)
        write(after, k, new); sizes[k] = size; claims.append(dict(tim_offset=hex(offset(k)), rectangles=[(0, 0, W, H)]))
    patch_all.sizes = sizes
    return bytes(after), claims
def assert_desc(before, after):
    if len(before) != len(after): raise ValueError('decoded extent changed')
    allowed = np.zeros(len(before), bool)
    for k in TEXT: allowed[offset(k) + 20: offset(k) + 20 + 88 * H] = True
    old = np.frombuffer(before, np.uint8); new = np.frombuffer(after, np.uint8)
    if np.any((old != new) & ~allowed): raise ValueError('write escaped description pixels')
    if 6 in TEXT: raise ValueError('panel 6 must stay untouched')
