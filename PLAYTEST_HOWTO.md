# How to playtest a build (DuckStation + computer-use)

This is the method used to verify builds in game. It needs a legally owned disc image; none is stored in this repo.

## Setup
- DuckStation with the built `justice-gakuen2-vNNN.cue` (the .bin sits beside it).
- Keyboard bindings in DuckStation's `settings.ini`: Enter = Start, C = Circle (confirm), X = Cross (cancel), arrow keys = D-pad.
- Launch DuckStation once (`Start-Process`) with the cue. Do not launch a second copy.

## Driving it
- DuckStation pauses when it loses focus. Before sending keys, run `tools/focus_duckstation.ps1`, then click the black margin at the left of the game window (about x=100, y=300).
- Hold each key about 0.2 s; shorter taps are often missed. Take a screenshot after each step.
- Press Enter 2-3 times during the intro movie to reach the title. On the title, press Start twice with a pause between.

## Route to Solo Play (checks the OP01 narration)
Start, Start, Down, C (Solo Play), C (character), C (partner), Start, then wait about 10 s. Expect the English narration over the background art (8 lines over 2 pages, none clipped). A black screen with audio means the OP01 stream is bad.

## What to check on every build
1. Boots, intro movie, title.
2. Mode Select is English.
3. Solo Play start does not black-screen.
4. Any screen touched by that version's image or dialogue jobs. Keep unchecked items in `PLAYTEST_LIST.md`.

## Notes
- Baked text is cropped by the game to the width of the original Japanese ink in each row; see the notes in `tools/band_text_v141.py`.
- Records whose original LZ stream does not follow the encoder's page schedule must be patched with `tools/surgical_lz_v143.py`.
