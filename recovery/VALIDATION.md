# Windows recovery validation — 2026-10-25

The user supplied the completed Windows PowerShell transcript for:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\rebuild_quiz_from_original.ps1 -StopAtV16
```

All 22 stages completed. The 22 `Verified saved build SHA-256` values were
compared programmatically, in order, with the saved recovery plan; all matched.
The transcript ends with `V16 RESTORED`, and contains no `RECOVERY STOPPED`.

The reported final BIN SHA-256 is:

`67ad4b9d628d0141493a42b456dfd8ce7631d3e9fdd7b2d387ceb84362127a51`

This is the historical translated v16 hash. The check validates exact image
reproduction based on the supplied transcript, not an independent read of the
user's Windows filesystem. No post-recovery gameplay or v17h build was included.

Observed build environment:

- Rust 1.98.0, x86_64-pc-windows-msvc.
- Pinned upstream `98ca12ddf082d6e2367b2963f76edf5a09242deb`.
- Original BIN verified as
  `0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e`.
- Installed Arial used by the saved builders.
- Compiler warnings and PowerShell stderr wrapper entries did not stop the run.

The original recovery kit and plan must remain unchanged when using `-Resume`.
A subsequent resume run built the separate v17h candidate, recorded below.
The subsequent user playthrough is recorded below. See
[RESUME_QUIZ.md](../RESUME_QUIZ.md) for the remaining regression checklist.

## Verified stage outputs

| Stage | Builder | BIN SHA-256 |
| --- | --- | --- |
| 1 | `run_batsu_playable_scene1_prototype_v7.ps1` | `d9b1a57313e3714980f4c618aeffb975bb00286bdcdcab1a4a9a0fb24ab850f2` |
| 2 | `run_quick_translate_mode_select_v4.ps1` | `a8f2c7d4ebc025376a36ba84930dee75e6044632e04677ba1eff8cf6d70f0564` |
| 3 | `run_translate_school_life_start_menu_v3.ps1` | `fb47236ead2e2052f22c92148613f3de942ed32818ff98236391e742aa85133a` |
| 4 | `run_road_to_batsu_mgk04_opening_v5.ps1` | `09165121e7141830c8c3027ca2de8c08e82cd624627092d4efde2b8d5fcd453b` |
| 5 | `run_road_to_batsu_status_hud.ps1` | `167524792e2b3abbb497335637ed3efb75df3e035a173b8cbf0de450c5c22365` |
| 6 | `run_road_to_batsu_welcome_reflow_v2.ps1` | `75fce33f40e105d7e58026830d92ec1758230996f8a46dbe79b8ba76f166436d` |
| 7 | `run_road_to_batsu_blue_title.ps1` | `ad068a54820b62bd246538e49776291512b88cab6447127fdd93ee6d4392dec4` |
| 8 | `build_opening_school_gate_v4_fit.ps1` | `a2e1587b828d5508a5dc99e4e64020d0a16fb4a8d0a569d3e8ddffccff0d98d1` |
| 9 | `build_dynamic_english_date_pretty_v2.ps1` | `6479176dc1788f64deb933d1a08569c87e677f5d1ba0f3e001567158dc80c91d` |
| 10 | `build_mgk04_full_tutorial_v3.ps1` | `30cdcc7cdbc1a21818b65272ac50e7baebc245f0505c83d03dfb2c00db713ac4` |
| 11 | `build_name_entry_ui_english_v5.ps1` | `2fe51561d025cc2ffdface62d1a7e7222a40937bb3b5a97ebc019f8338d43977` |
| 12 | `build_name_entry_default_az_v6.ps1` | `e3808a7bef6c6529e45b29963895a6e45a26dd7c30b031be928fcdb4fa98a09f` |
| 13 | `build_name_entry_nickname_default_az_v7.ps1` | `c9eb6cc1c15eb3b65f1aa9e02cee102fbb1bc502483e88950175139720ca48f5` |
| 14 | `build_name_entry_school_choices_english_v8.ps1` | `07b4dda156ab0eac7f149f66f7bcb9727a8e74fad4faa2d19d77cee362504d84` |
| 15 | `build_mgk04_welcome_hybrid_palette_v9b.ps1` | `403fe83463e714d2621fd404d1556a31021ff2332c5bb9ea5b3d6a59af330371` |
| 16 | `build_name_entry_sex_choices_english_v10.ps1` | `16667311e8d4561cc0d5600c59717539d4c07ccd569700c5d2ed6966a557d2d2` |
| 17 | `build_name_entry_best_subject_english_v11.ps1` | `c282ecaf026a2c09aac8c63307853cd811f313a581904d4ac932828c86071ca0` |
| 18 | `build_name_entry_favorite_words_english_v12.ps1` | `bcc411d59f5f6a45f6aa8e0c20869ef1d4c4e3f22705f17fc66630b45a7da74b` |
| 19 | `build_enrollment_completion_sweep_v13.ps1` | `5010cd27250d4a78651f4e481cb8cb648806fbc3e174f83e219e0c48ecb959f2` |
| 20 | `build_face_customization_sweep_v14.ps1` | `e88b4bdc6faf4aaebb35709efbe5324bb875a2272ec9a3d40b8285ac25041d67` |
| 21 | `build_mgk10_quiz_english_v15b.ps1` | `4c43c6a02e15bd5d470a649ab17b9ff4905c0c8b63ad77e91ea57afcb38e42c5` |
| 22 | `build_live_mgk04_quiz_english_v16.ps1` | `67ad4b9d628d0141493a42b456dfd8ce7631d3e9fdd7b2d387ceb84362127a51` |

## Actual v17h Windows candidate — 2026-10-25

The subsequent user-supplied resume output reports a successful build from the
exact restored v16 image. The build test passed (1 passed, 0 failed) and the
wrapper completed final-output verification, ending with `V17H CANDIDATE`.

- Output BIN SHA-256: `2ff4d83cca04a22a217883ac9c29b3e2fa9c5c4796d9661db3f95d9acd92149a`.
- Patched MGBGK04 SHA-256: `f418235d0a1d714ae1d63e88d254ffe42d034db9e3eb54e64892f261b92c5277`.
- Changed raw sectors: 26.
- Changed indexed pixels: 35,761.
- Member 2 compressed size: 86,044 / 86,620 bytes; 576 bytes spare.
- Current CUE: `C:\Users\Fluent\JG2-Recovery-v1\project\upstream\work\english-quiz-fixed-ui-v17h-e380163248384b70a99130d1193c7368\build\justice-gakuen2-quiz-fixed-ui-v17h.cue`.

Reported palette indices:

| Graphic | Clear | Fill | Outline |
| --- | --- | --- | --- |
| CORRECT! | 0 | 1 | None reported |
| WRONG! | 0 | 2 | None reported |
| QUESTION | 0 | 14 | 11 |
| EXAM OVER | 0 | 1 | 15 |

This build evidence comes from the supplied Windows output, not direct access
to the user's filesystem. The subsequent live report is recorded below.

## User playthrough to post-quiz stat results — 2026-10-25

After the v17h build, the user reported that it worked and that they reached
the classroom stat-result screen before encountering Japanese. Their screenshot
shows the English date and `ATK / DEF / STAM / GUTS / POT / INT` HUD with the
untranslated intelligence-decrease message and native down-arrow.

This supports successful live progression through the visited quiz route to
that result screen. It does not independently establish every QUESTION,
correct/wrong, EXAM OVER, timer, and School Gate check or all other routes.
Continue from v17h while retaining v16 as the recovery fallback.

The standalone read-only probe subsequently completed on the user's Windows PC.
Its 0.85 MiB private ZIP was received, and all eight extracted records matched
their manifest hashes. The v18 stat-message record patch and a complete disc
fixture now pass; the actual Windows v18 build and live test remain pending.
See [STAT_RESULTS_V18.md](../STAT_RESULTS_V18.md). The original recovery kit and
its hash-bound plan were not modified for this continuation.
