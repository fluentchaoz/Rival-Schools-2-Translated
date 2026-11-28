# How the ending scenes draw text (from the overlay disassembly, 2026-11-28)

Source: `DAT1/END01.BIN` overlay (loaded at 0x800a2000; a disassembly was made in `work/END01.asm`), routine around 0x800a3200-0x800a34c0.

- The scene walks a **stream of u16 words**; control words (0xFFFF = end, others = newline / skip) and counts, then draws **one GPU sprite per character**: 16 px wide, 24 px tall, with a 17 px pitch on screen (`x = col*17 + 64`, `y = row*36 + 324`).
- Character number `n` (a running counter) selects a **cell in the baked text image**: u = (n mod 16)*16, v = ((n mod 160) div 16)*24, texture page = n div 160 (+ a base that differs by mode). So the image is read as 16-px cells, 16 cells per 24-px band, 10 bands per 256-px column, one VRAM page per column.
- Therefore a line on screen is a run of consecutive cells; English text can be pixel-composited into the same cells (a cell is just a 16x24 slice; the 1 px gap every 16 px is the 17 px pitch). Text is cropped to the number of cells drawn, i.e. the original ink width.
- **EDB (epilogue) pages**: continuous character stream, 32 chars per on-screen line = a band pair in a 256-px column, read column 0 then column 1. Matches the pair-of-bands layout used for OP01 and built in v156.
- **ED (ending dialogue) pages**: each band reads left half then right half as ONE line (32 chars on a 512-px page, 48 on 768, 64 on 1024); lines are separate speech lines, often cut at the page width on purpose (interruptions). So translate band by band; the limit per line is its original ink width.
- Not yet read: the command stream (where newlines and counts come from); the two branches selected by the byte at 0x801f64e5 (page base 8 vs 14) probably correspond to the ED vs EDB modes. Confirm in game.
