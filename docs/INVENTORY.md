# Inventory: what is still Japanese (image side), measured on v155

Method: `python tools/inventory_sweep.py <disc BIN> <out dir>` finds every indexed TIM on the disc (about 780 hits; a few dozen false positives such as the 20-px-wide slivers in MGC/MGG/MGK/MGM/MGT/MGE/MGF/PLMON/ALOAD32, now filtered by aspect ratio) and renders contact sheets per file. Re-run it on each new build; whatever is still Japanese on the sheets is the remaining work. Script/dialogue text is tracked separately (`REMAINING_JAPANESE_AUDIT.md`, `PLAYTEST_LIST.md`). Output stays outside the repo.

Coverage (image side, by file family, judged from the sheets): English, or only the shared dialogue-font Japanese: CAPCOM, CONT, DANCE, SPRINT, TITLE, HERE, OVER, MINITTL*, AISYOU, MA_ENT, MA_TIT, CEFT4-6, EDSR, MGSTAT, MGBG*, CST* (stage textures), CEFT1 (mostly), MENU (main labels). Still Japanese: the 11 rows below.

| # | Source files | What | Seen when | Priority | Technique / who | Queue |
|---|---|---|---|---|---|---|
| 1 | `DAT2/ED01-ED24.BIZ` (512x256 text pages at 0x4000; ED24 256x168) | ending narration text | every ending | high | band text as OP01 (`tools/band_text_v141.py`); needs the translation | 011 |
| 2 | `DAT2/EDB01-EDB25.BIZ` (512x256 at 0x5f800) | epilogue narration text | every ending | high | same | 011 |
| 3 | `DAT2/CEFT1.BIZ` TIM 0x10800 | the win banner (辛勝!/勝), N勝 counter, 愛と友情のプラトン and フィニッシュ strips, red vertical name labels (24) | every fight | high | sprite painter (`hud_v150`/`hud_v155`) | 003, 008 |
| 4 | `DAT2/PL010-PL410.BIZ` (+`PLE*`), TIM 0x6800 | 回復 sprite beside GUTS UP / LIFE UP (same rect in every file) | recovery items in fights | medium | sprite painter, all files in one build | 012 |
| 5 | `DAT2/EDITCM01-24.BIZ` (412x369 move table, 512x256 super names) | per-character move lists: headers and move names | move list screens | medium-high | painter or image generation; 24 files | 013 |
| 6 | `DAT2/SIKEN1/2/10/20.BIZ` | exam question text sheet, results card (table headers, 達成率) | exams in School Life | medium-high | painter + band text | 014 |
| 7 | `DAT2/KOUBAI.TIZ`, `KOUBAI0.TIZ`, `KOUBAI1.TIZ` | shop labels, おまけ title, 戻る | shop / bonuses | medium | painter | 014 |
| 8 | `DAT2/OPTINFO.TIZ` (4+ images 256x256), `MENU.BIZ` TIM 0x0, `MOJI2.TIZ` | option descriptions and option list labels | Options screen | medium | band text / painter | 014 |
| 9 | `DAT2/EDITMOJI.TIZ`, `SELP1-5.BIZ` | Edit mode captions, yes/no, one emblem | Edit mode, team select | low-medium | painter | 014 |
| 10 | `DAT2/TOROFY.BIZ` | award certificate (vertical calligraphy) | winning a tournament | low | image generation | 015 |
| 11 | `DAT2/KOUKA00-04.BIZ` | school-song lyric images (320x256) | school song screens | low | band text / image generation | 015 |

Not located as images (script or font driven): the episode card and return-to-Mode-Select prompt (queue 006), the loading-card credit (queue 005), the TOURNAMENT label font (queue 007).
