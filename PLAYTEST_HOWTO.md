# How to playtest a build (DuckStation + computer-use)

This is the method used to verify builds in game. It needs a legally owned disc image; none is stored in this repo.
Rules that cost time when ignored are marked **RULE**.

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
- DuckStation hotkeys (section `[Hotkeys]`): Space = pause, Tab = fast-forward (hold), Esc = pause menu, F1/F2 = load/save state, F3/F4 = previous/next slot, F10 = screenshot, F11 = fullscreen.
- To reproduce on another machine, add these lines under `[Pad1]` (e.g. `Circle = Keyboard/C`) with DuckStation closed.

## Fast route (use this first)
Load a savestate at launch instead of booting: `-state N` (see `docs/SAVESTATES.md` for the scenes and slots). For round-end banners load slot 9 (timer already 1): TIME UP, win/lose banner and the swap prompt appear within about 10 s. CAUTION: a state made after the fight HUD loaded (slots 4+) keeps the old HUD art, so it cannot show NEW fight art; for that, load slot 3 (Mode Select, retargeted to the new build with `tools/state_retarget.py`) and walk to the fight (about 80 s). Boot from scratch only when no state fits. Close DuckStation when the test is done.

## Launching
- Launch DuckStation **once**: `Start-Process "$env:LOCALAPPDATA\Programs\DuckStation\duckstation-qt-x64-ReleaseLTCG.exe" -ArgumentList @('-batch', ('"' + $cuePath + '"'))`. `-batch` makes it start the game instead of showing the game list (a plain launch sometimes lands on the list; if you see an empty or one-row game list, kill it and relaunch with `-batch`).
- **RULE:** never use computer-use `open_application` on DuckStation (starts a second copy). Computer-use needs `request_access` for "DuckStation" once per session.
- A DuckStation "Update Available" dialog can appear at launch. Click **Remind Me Later** (never Download).
- Kill the emulator with `Stop-Process -Name duckstation* -Force` so the resume state is not overwritten.

## Driving it: focus, keys, fullscreen
- DuckStation pauses when it loses focus, and key presses are refused while the desktop shell or Claude's own window has focus ("desktop shell is frontmost" / "Claude's own window still has keyboard focus"). Fix: run `work/fg2.ps1` (the reliable one), click the black margin at the left of the game area (about x=60..100, y=300), then send keys. Focus drops again between tool calls, so repeat whenever a key or click is refused.
- **Keep DuckStation fullscreen (F11).** Press F11 once after launch (after the click on the margin). `work/fg2.ps1` only restores a minimized window, so it never un-maximizes.
- Use `hold_key` for about 0.2 s. Plain presses are often missed. After moving a cursor, screenshot to check the highlight before confirming.
- **RULE:** drive with computer-use `hold_key` as above. The old `work/keys.ps1` sends blind sequences, refocuses with the old `fg.ps1` and never clicks the margin, so most presses are lost. Do not use it for testing.
- Take a screenshot after each step (scale 0.3 is enough).

## Tab (fast-forward): use sparingly
- Tab fast-forwards only while held, and it is **not free**: holding it for long (more than a few seconds) has repeatedly knocked keyboard focus off the emulator, so the next key press was refused and the batch stopped.
- Use it only in short bursts (about 3 s) for something like a long NOW LOADING screen, then re-run `work/fg2.ps1`, click the margin, and continue. The route below works at normal speed and is the default.
- Do not use Tab while recording banners: the game runs faster, so one-second banners yield fewer frames.

## Boot to Mode Select (three different Starts)
The word "Start" means three different things on the way in. Go by the screen, not by a press count.

1. **Intro skipping (variable number of presses).** After the logos and the `NO FILE / LOAD SKIPPED` memory-card screen (no input needed) the intro movie plays for about 1.5 minutes. Each Start skips one segment. Press Start about every 2 s and screenshot every 2-3 presses. It took 4 presses in one run and 7 in another. Stop as soon as you see the title: the logo with **PRESS START BUTTON** at the bottom. If you land on the attract-mode Score Ranking or a demo instead, that is the same loop; keep pressing Start.
2. **Title: the double Start.** Only on the title screen: two Starts about 1 s apart, then wait about 7 s. Expect **Mode Select**. A single Start at the title falls back to attract mode.
3. **Character select: one Start.** Later, after the lead and partner are confirmed (see the route), a single Start begins the story.

Checkpoints: (a) title with PRESS START BUTTON, (b) Mode Select with SCHOOL LIFE 2 highlighted at the top.

## Route to Solo Play and the first fight
From Mode Select (the cursor starts on SCHOOL LIFE; Start there enters School Life, not Solo Play): Down (screenshot: SOLO PLAY highlighted), C (Solo Play), C (lead, default BATSU), C (partner, default HINATA), then **Start held 0.6 s** (0.2 s was ignored; if nothing happens click the margin, press C once and hold Start again), then:
- about 10 s: English opening narration over the background art (8 lines over 2 pages, none clipped). A black screen with audio means the OP01 stream is bad.
- about 40-60 s after the Start (disc loading, NOW LOADING card): the first fight. The ROUND n banner, then FIGHT!, appear in the first 3 s. READY!! shows in both lower corners for the whole fight.
- A round lasts 99 s. Time-up or a KO ends it; the end-of-round banners (TIME UP, FIN ISH, PERFECT!/SUPER!) show for about 1-2 s. Losing the fight leads to CONTINUE? (10 s countdown), GAME OVER, then attract mode.

## Recording brief banners
`work/loopcap2.ps1 <seconds> <delay_ms>` grabs the screen every `delay_ms` into a **new** timestamped folder `work/shots/run-HHMMSS` (path in `work/shots/last_run.txt`); it never overwrites an earlier run. Start it just before the character-select Start; 300 s at 300 ms covers loading plus a round. Find banner frames by looking for the saturated yellow or cyan text in the middle band, then crop and view them. (`work/loopcap.ps1` is the old one that overwrote its own frames; do not use it.)

## What to check on every build
1. Boots, intro movie, title.
2. Mode Select is English.
3. Solo Play start does not black-screen.
4. Any screen touched by that version's image or dialogue jobs. Keep unchecked items in `PLAYTEST_LIST.md`.

## Notes
- Baked text is cropped by the game to the width of the original Japanese ink in each row; see the notes in `tools/band_text_v141.py`.
- Records whose original LZ stream does not follow the encoder's page schedule must be patched with `tools/surgical_lz_v143.py`.
- Work scripts (`work/fg2.ps1`, `work/loopcap2.ps1`, `work/cap.ps1`) live outside the repo in `C:\Users\Fluent\JG2-Project\work`.
