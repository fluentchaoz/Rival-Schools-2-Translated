import pickle
import numpy as np
from PIL import Image, ImageDraw
S = r'C:\Users\Fluent\AppData\Local\Temp\claude\64d96de68a049de7\e3f69e87-1127-44ee-8609-cdd731c4a651\scratchpad'
cells = pickle.load(open(S + r'\cells.pkl', 'rb'))
hashes = sorted(cells, key=lambda h: -cells[h][1])
pickle.dump(hashes, open(S + r'\glyph_order.pkl', 'wb'))
def bitmap(raw):
    a = np.frombuffer(raw, np.uint8)
    px = np.empty(400, np.uint8)
    px[0::2] = a & 15
    px[1::2] = a >> 4
    return px.reshape(20, 20)
pal = np.array([(i * 17, i * 17, i * 17) for i in range(16)], np.uint8)
COLS, ROWS, Z = 16, 10, 3
CW = 20 * Z + 6
PER = COLS * ROWS
for pg in range((len(hashes) + PER - 1) // PER):
    part = hashes[pg * PER:(pg + 1) * PER]
    rows = (len(part) + COLS - 1) // COLS
    sh = Image.new('RGB', (30 + COLS * CW, 14 + rows * CW), '#101018')
    dr = ImageDraw.Draw(sh)
    for c in range(COLS):
        dr.text((30 + c * CW + 18, 1), str(c), fill='yellow')
    for r in range(rows):
        dr.text((2, 14 + r * CW + 22), 'r%d' % r, fill='cyan')
    for k, h in enumerate(part):
        r, c = divmod(k, COLS)
        im = Image.fromarray(pal[bitmap(cells[h][0])]).resize((20 * Z, 20 * Z), Image.NEAREST)
        x = 30 + c * CW; y = 14 + r * CW
        bg = '#23233a' if (c // 4) % 2 == 0 else '#3a2323'
        dr.rectangle([x - 2, y - 2, x + 20 * Z + 1, y + 20 * Z + 1], fill=bg)
        sh.paste(im, (x, y))
    sh.save(S + r'\gp_%02d.png' % pg)
print(len(hashes), (len(hashes) + PER - 1) // PER, 'pages')
