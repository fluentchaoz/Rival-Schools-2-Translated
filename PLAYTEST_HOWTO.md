# How to playtest a build (DuckStation + computer-use)

This is the method used to verify builds in game. It needs a legally owned disc image; none is stored in this repo.

## Setup
- DuckStation with the built `justice-gakuen2-vNNN.cue` (the .bin sits beside it).
- Keyboard bindings (added to the real `%LOCALAPPDATA%\DuckStation\settings.ini`, section `[Pad1]`; the controller type is AnalogController and the pad bindings are kept alongside):

  | PS1 button | Key |
  |---|---|
  | Start | Enter (`Keyboard/Return`) |
  | Select | Backspace |
  | Circle (confirm) | C |
  | Cross (cancel) | X |
  | Square | Z |
  | Triangle | V |
  | D-pad | Arrow keys |

  L1/L2/R1/R2 and the sticks are bound only to a gamepad, not the keyboard.
- DuckStation hotkeys (section `[Hotkeys]`): Space = pause, Tab = fast-forward, Esc = pause menu, F1/F2 = load/save state, F3/F4 = previous/next slot, F10 = screenshot, F11 = fullscreen.
- To reproduce on another machine, add these lines under `[Pad1]` (e.g. `Circle = Keyboard/C`) with DuckStation closed.
- Launch DuckStation once (`Start-Process`) with the cue. Do not launch a second copy.

## Driving it
- Launch once with `Start-Process "%LOCALAPPDATA%\Programs\DuckStation\duckstation-qt-x64-ReleaseLTCG.exe" '"<path>\justice-gakuen2-vNNN.cue"'`. Never use computer-use `open_application` on DuckStation (starts a second copy). Computer-use needs `request_access` for "DuckStation" once per session.
- DuckStation pauses when it loses focus, and key presses are refused while the desktop shell or Claude's own window has focus. Before each batch of clicks/keys run `work/fg2.ps1` (the reliable one; `tools/focus_duckstation.ps1` often fails to take the foreground), then click the black margin at the left of the game area. Focus drops again between tool calls, so refocus whenever a click/key is refused with "desktop shell is frontmost".
- **Keep DuckStation fullscreen (F11) while testing.** `work/fg2.ps1` now only restores a minimized window, so it no longer un-maximizes it (the old version flipped to a small window and moved the margin). Fullscreen: click the black margin at the left (about x=100,y=300); if a click is refused as landing on the desktop, the window is not fullscreen - press F11 first.
- Use `hold_key` for about 0.2 s. Plain key presses are often missed; Down then C pressed back to back confirmed the wrong item. Move the cursor, screenshot to check the highlight, then confirm.
- Skipping: Start skips the intro movie (press it 2-3 times; you may land on the attract-mode Score Ranking, press Start again). Title needs a **double Start**: two presses about 1 s apart, then wait about 6 s for Mode Select. Single presses fall back to attract mode.
- Alternative without computer-use: `work/keys.ps1 ENTER wait1500 ...` sends keys and `work/cap.ps1 out.png` captures only the DuckStation window. Use these rather than full-screen shots.
- Kill the emulator with `Stop-Process -Name duckstation* -Force` so the resume state is not overwritten.
- Take a screenshot after each step; save useful ones to `work/shots/`.

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
