# Club joining English v23

Build from actual v22 SHA-256 `b21934066fc21a217ce5c37772abd53b81e881706d685bd10dc349cc0f8be95e` with `build_club_join_english_v23.ps1`. It automatically finds the verified v22 candidate in the recovery folder, makes a fresh candidate directory, backs up and restores the exact Rust source, and prints its new CUE. Keep v22.

Scope: Taiyo selectors 0/1 entries 177–347 (342 messages), including all eight clubs and go-home, the remaining regular/special practice tutorials, skip/repeat choices, and farewells. This completes the club-orientation dialogue following v22. Source names and renderer controls are preserved; English is bounded to four 20-cell rows including a six-cell inserted name.

The screenshot's baseball farewell is entry 179. Its preceding page 178 describes May special practice and regular activities. The missed Club Building banner is a secondary TIM in MGBGG04 member 3 at 0xf800; its first TIM was already translated in v22. Nine shared HUD club labels become BASEBALL, VOLLEYBALL, SOCCER, SUMO, ART, BAND, DRAMA, CHEMISTRY, GO HOME. Their native cells are 64x20, with source-bound consumer checks. Four disc records are owned: MGG04T, MGG04, MGBGG04, MGCOCK. MGAME is verified and preserved.

Native testing: boot the new CUE fresh, reach the club building, check its location label, select baseball, check the HUD label, and read the remaining tutorial including repeat/skip choices. Other clubs and the second player variant also need native checks. Later field-trip scenes and other schools remain untranslated.

Validation uses direct Rust execution and a private full-disc fixture reconstructed from the original disc, v21/v22 translation modules, and the user's actual saved shared records. Nimbus Sans substitutes for Windows Arial. QA bypasses only expected master/text hashes for this fixture; production retains actual v22 guards. No actual Windows v23 image or native gameplay pass is claimed. Local PowerShell execution is not rerun after the earlier automatic-review block over telemetry; the wrapper is assembled from v22's successful Windows wrapper and checked statically.
