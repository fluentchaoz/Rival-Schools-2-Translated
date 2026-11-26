# Playtest list (v130, DuckStation)

Keys (added to DuckStation): Enter = Start, C = Circle (confirm), X = Cross (cancel), arrows = D-pad.
Tip: click the game window before each key press; hold keys ~0.2 s.

## Checked and fine
- Boot, intro movie, title, Mode Select, PLAY/LOAD: OK
- Class president tutorial text, 4-line boxes: fit, no overflow
- Two-column help menu (GOAL/CONTROLS/SETUP/FLOW/GROWTH/ABOUT/SKIP): aligned
- Controls help page, colored button names (O/SQ/TRI/L1, X/L2): OK
- Enrollment form, school picker, favorite words: original baked English, OK
- Entrance exam quiz: questions and 4 answer options render correctly
- Exam result scene and "INT DECREASED!!" stat screen: OK

- April 8 entrance ceremony title card, command menu CONTINUE/STATUS/DIARY with description line ("START THE EVENT"): OK

## FIXED in v131 (verified in game)
- Gorin High April 8 entrance ceremony scene now fully English ("TODAY IS GORIN HIGH'S CEREMONY...", "PHEW... EARLY RISING FEELS GOOD. SOMEONE'S HERE FIRST... IT'S SHOMA.", "SHOMA, YOU'RE OVERDOING IT. WARM UP FIRST.", "OH, EVERYONE. YOU'RE FIRED UP."), player name token works ("HEY, SEIGI!"), speaker faces/boxes fine.
- Fix = patched school scripts now also written into DAT2/MGG04/06/08/09/11.BZZ bundles (25 members). Build report: 38,597/38,597 entries applied, 0 skipped, 1917 changed sectors.

## FIXED in v132
- Item 4 (name-token clipping): the wrapper only reserved space for name tokens 2000/2001, but codes 2003-2009 (about 1,500 uses) also insert the player's name. Wrapper and validator now count all of them at 7 cells; 103 lines that no longer fit were shortened by hand (tr_dlg_110/111.txt). Example: id 3553 is now "HEY, {0}! I'M A / HIGH SCHOOL BASEBALL / PLAYER NOW! NO TIME / TO LAZE AROUND!". Build: 38,597/38,597 applied, 0 skipped, all 25 bundle slots identical to their scripts.
- Checked and dropped: "A BIG GUY'S HEAT TAKES TIME" is NOT a mistranslation (the source is a joke on the proverb using 熱 "heat").
- Static audit: of 862 other disc files scanned, only the five MGG04/06/08/09/11 bundles hold story script copies.

## REMAINING GAME MESSAGES (v136/v137)
Re-audit of v135 (tools: repo/tools/extract_remaining.py) found the dialogue system already ~100% English; what was left was 63 distinct messages: 49 practice descriptions (what each training does, "{0}NAME{1}" + stat names), 2 mini-game practice notices (Doki-Waku Dance, Roberto's PK), YES/NO prompt, gender prompt, and event/club/school/day/month menus. All translated as ids 20000+ (tr_dlg_112/113.txt). Digits are now allowed in the bitmap text (original atlas cells 1..10).
Build: 39,653/39,653 entries applied, 0 skipped. v137 = v136 dialogue + v135 image labels. Boots, School Life opens normally.
NOT yet seen in game: the practice descriptions (need to reach the practice menu in School Life).
Left Japanese on purpose: debug-style "who will it be" character grid (7 distinct texts, 88 slots) and five debug menus (event/club/school/day/month) in MGK04 and MGT00 only (those two records have no spare text space).
Other text systems still Japanese: Solo Play story/episode screens (e.g. 20世紀末..., 第一話), character select (キャラクターセレクト, 主役, 相棒), "かかって来なさい!" banner, ending epilogues (EDB/ED), option help (OPTINFO), move lists (EDITCM), cards, credits.

## BAKED IMAGES (v133-v135)
New tool: repo/tools/img_label.py (learns a label's fill gradient/outline/shadow from the Japanese glyphs and redraws English with the same palette indices) + repo/tools/build_images_v135.py (only named rectangles may change; sector/ownership audit).
Done and verified in game (v135): Bonus menu labels GO TO STORE / BONUSES BOUGHT / BACK TO MODE MENU, store title STORE (KOUBAI0.TIZ); bonus list VIEW BONUSES, CARDS, POSTERS, CD, VIDEOS, ARTWORK, POCKETSTATION, BACK (KOUBAI1.TIZ).
Lesson: the game crops each label sprite to the width of the original Japanese text (row 1 was only 146 px), so English must fit that width (fit_w).
Still Japanese:
- Bonus screen rainbow title おまけ (KOUBAI0 #1 art).
- Bonus list panel (所持 / カードをみる / カードをあげる) and footer hint (<方向キー:選択 ○ボタン:決定 ×ボタン:戻る>): not baked pictures; drawn from a glyph-atlas text table (different technique, needs the string table located).
- Second 戻る and カードを見る in the KOUBAI1 sheet (card viewer screen).
- HERE.TIZ vertical flame "ちょっと待った!" (artistic lettering).
- OPTINFO.TIZ option-help paragraphs (5 images).
- Ending epilogues EDB01-EDB25 (33 text images, 4-bit 512x256 / 256x256, white on black, ~10 lines each) and ED01-ED24 narration pages: need the on-screen display geometry before re-lettering (display region unknown; reaching an ending in game or finding the draw code is the blocker).
- EDITCM01-24 move lists, CARD (39 images), TOROFY, KOUKA, credits/OP01.
- Main menu strip: "SOLO PLAY" and "SKILL 99" are cut off at the right edge of the Mode Select list (older art).

## New small items from the v131 replay
4. (FIXED in v132, see above) Possible right-edge clipping near the player name.
5. Commas look like small dots in the bitmap font ("OH, EVERYONE, YOU'RE") - cosmetic, glyph is what it is.
6. Only checked Gorin (MGG04O) and Taiyo (MGG04T) April 8; Justice/Pacific/Gedo April 8 and the other bundle months (June, Aug, Sep, Nov) not yet viewed.

## Issues to fix (history)
0. (FIXED in v131, see above) **MAJOR: April 8 entrance-ceremony story scene is entirely in JAPANESE** (several consecutive dialogue boxes, quoted lines omitted here) Tutorial/quiz/teacher text is English, so the scene's text is not covered by the dialogue spec (different text bank/record or not extracted). Need to find where it lives.
1. Enrollment confirm dialog shows leftover Japanese "か?" after "IS EVERYTHING CORRECT?" - baked image, needs picture edit.
2. Tutorial line "USE TRI-SKIP TO CHOICE" is awkward - reword (source near ids 4703/4704 area).
3. Quiz intro "ANSWER QUICKLY: THE BIGGER THE TIME BONUS. ANSWER QUICKLY!" repeats itself - find source line, reword.

- Confirmed over ~12 consecutive boxes (Gorin entrance ceremony: Batsu/Shoma/Natsu/Roberto-style cast) that the whole scene is Japanese, so this is systematic for story scenes, not a single bad line.

### Notes on issue 0 (investigation)
- v130 build report says DAT2/MGG04O.BIZ got 1148/1148 entries, and the disc readback matches, incl. id 10270 (EARLY RISING...). Yet the game shows the Japanese line for 10270 on screen.
- The disc also has DAT2/MGG04.BZZ (1.1 MB bundle, byte-identical to v46, never patched) and DAT2/MGG04T.BIZ (no spec entry, unpatched). The scene may be read from the .BZZ bundle instead of (or before) the .BIZ.
- Spec covers only 76 records; corpus has 215 record-sets (many shared/comma lists, 92 lines only in MGG04T).
- Next step: confirm which file the game loads for this scene (DuckStation CD read log) and extend patching to it.

### ROOT CAUSE of issue 0 (found)
- The game loads the April/June/Aug/Sep/Nov story scenes from the bundles DAT2/MGG04.BZZ, MGG06, MGG08, MGG09, MGG11 (each holds 5 members = the 5 school scripts, byte-identical to the loose MGG04x.BIZ files on the original disc). CD read log at the April 8 scene shows MGG04.BZZ being read and no MGG04x.BIZ.
- My v47..v130 dialogue patch and the v46 shared strings only changed the loose .BIZ files, so the bundles still have Japanese for the Gorin/Justice/Pacific/Gedo schools. Taiyo (MGG04T) was already patched in the bundle by older hand-translation work, which is why the Taiyo April 8 scene is English.
- Verified: bundle member + shared_v46 spec == v46 loose .BIZ, byte for byte (all 5 for MGG04). So the fix is to write the patched script into the matching bundle slot (same compressed size).
- Other direct .BIZ reads seen working: MGK04.BIZ (class president tutorial).

## Not tested yet
- Club menu, stat-training menus, first school days, battles, later story

## v144 in-game survey of Solo Play (2026-11-24)
Verified: v144 Solo Play route works. Screenshots in `work/shots/` (solo_charselect, solo_episode1, solo_fight1, returnmodeselect_prompt).
Still Japanese, found on the Solo Play route:
- Character select (キャラクターセレクト): red title banner; 主役 (Lead) and 相棒 (Partner) headers; top-right blinking prompt スタートボタンを押して！ / ちょっと待って！; name captions under the two portraits (バツ, ひなた) — likely a glyph or baked name atlas.
- Episode card 第一話 (white serif on black) before the first fight, plus the top-right banner かかって来なさい！ which stays on screen through the fight.
- Fight HUD: 第一戦 (Match 1) announcer text, 準備OK!! (both corners, Ready OK), red vertical name labels バツ / さくら beside the health bars.
- "Return to Mode Select?" confirm (モードセレクト画面に戻りますか？ はい / いいえ), reached by pressing X on the School Life 2 PLAY/LOAD screen. Not yet scheduled.
Not seen: story/episode text between fights, results, ending. Loading screen shows English NOW LOADING.
Driving note: window flips between maximized and small after refocus; screenshot to find the left black margin before clicking, use hold_key 0.2 s, and title needs double Start.

## v145 (2026-11-24): character select
Verified in game: PLAYER SELECT banner, LEAD, PARTNER, BATSU caption. Not yet seen: the other 23 name captions, "2" variants, PLSEL3/4 league/tournament select screens (their titles still use the original Japanese cells, intentionally), the other four schools' atlases. Still Japanese on this screen: top-right スタートボタンを押して！ / ちょっと待って！ and かかって来なさい！. PARTNER header is small (7 letters in 40 px); revisit if it is hard to read at fullscreen.

## v146 (2026-11-24): character select restyle
v145 lettering looked garbled at 1080p fullscreen (striped banner, uneven PL AYER spacing, mushy LEAD/PARTNER). v146 fixes the styling; verified in game fullscreen: PLAYER SELECT, LEAD, PARTNER, BATSU now clean. Captions still to eyeball: DAIGO, HAYATO, "2" variants.

## v147 (2026-11-24): shared overlay prompts
Verified in game fullscreen: PRESS START! and COME ON! alternate top-right at character select; COME ON! also over the Solo Play opening narration. Not yet seen: HOLD ON! (after the lead is picked, timing), ADD n COINS!, STREAK! RIVAL, and the fight screen.

## v148 (2026-11-24): Mode Select clipping fixed
Verified in game: SOLO PLAY / TRAINING / SKILL 99 list labels and card tabs display in full. TOURNAMENT is in a tiny font (legible, a bit crushed). Not rechecked: VERSUS/LEAGUE/CO-OP/EDIT/BONUS/RECORDS/OPTIONS tabs (unchanged, were fine in v147).

## v149 (2026-11-24): Mode Select list centred
Verified in game: all 12 list labels centred in the green panel (VERSUS .. OPTIONS), highlight bars and card tabs unchanged.

## v150 (2026-11-26): fight HUD announcer art (CEFT1)
Verified in game fullscreen: READY!! in both lower corners of the fight HUD; "ROUND 2" banner (yellow); HOLD ON! seen top-right between narration and fight (v147 item, now confirmed). Not yet seen: ROUND 1, 3, 4, 5; FIN AL (final fight); FIN ISH (KO banner). Check that nothing is clipped or has a seam. Still Japanese in the fight: 開始!, 制圧!, 時間切れ, 主役交代?/相棒交代?, 完全夢想アタック / 根性カウンター popups, vertical red name labels.

## v151-v154 (2026-11-26): rest of the fight HUD
Verified in game fullscreen: ROUND 1 and ROUND 2, FIGHT! (one word since v152), TIME UP, FIN ISH, PERFECT! (reads correctly since v153/v154), DREAM ATTACK, READY!!. Not yet seen: FIN AL (final fight), ROUND 3/4/5 and numerals 3-5, DRAW, GUTS COUNTER, SUPER! (shown when 制圧! would be). Check for clipping and seams. See `queue/002`.

