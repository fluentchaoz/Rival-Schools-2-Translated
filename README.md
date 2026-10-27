# Rival Schools 2 Translated

English fan-translation / reverse-engineering project for the Japanese PlayStation
release of **Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2** (`SLPS-02120`).

## Status

Work has progressed through the **English quiz to the post-quiz stat results**.
v18 has now built successfully on Windows. The next candidate translates the
CLASSROOM location banner from that exact v18 image.
See [CURRENT_MILESTONE.md](CURRENT_MILESTONE.md) for the distinction between
repository-recorded live milestones, recovered work, and untested candidates.

**Recovery completed on 2026-10-25.** The Windows rebuild passed all 22 recorded
output hashes and restored the exact v16 image. See
[recovery/VALIDATION.md](recovery/VALIDATION.md) for the transcript verification.

**v17h candidate built on Windows.** The actual restored v16 image produced a
verified candidate translating `QUESTION`, `CORRECT!`, `WRONG!`, and `EXAM OVER`.
Its SHA-256 is `2ff4d83cca04a22a217883ac9c29b3e2fa9c5c4796d9661db3f95d9acd92149a`.
The user subsequently reported successful play to the first remaining Japanese:
the stat-change message after the quiz. The screenshot shows the English date
and stat HUD. Individual quiz branches have not been separately enumerated.

**v18 built on Windows.** It translates 18 MGK04 increase/decrease messages,
preserving native arrows and the 100 quiz entries. Its build and final checks
passed; actual SHA-256: `d720ea2ae3c2c1c52981b0536642b836ec8e2151c6e94b658abdd1a49e094068`.
The stat-result live test is still pending. See [STAT_RESULTS_V18.md](STAT_RESULTS_V18.md).

**Next: CLASSROOM banner v19.** The user identified Japanese in the separate
location banner beneath the stat HUD. The new builder patches that graphic
while preserving the background, portraits, quiz UI, School Gate, and v18 text.
See [CLASSROOM_LABEL_V19.md](CLASSROOM_LABEL_V19.md). Keep v18, v17h, v16, and
the original recovery kit. Windows v19 execution and native testing remain pending.

### Confirmed English work so far

- Main mode-select graphics
- School Life `PLAY / LOAD` title UI
- English dialogue glyph support
- Batsu-route prototype work
- Status HUD (`ATK / DEF / STAM / GUTS / POT / INT`)
- MGK04 opening greeting
- `SCHOOL GATE` opening location
- Dynamic English date (`4/1 THU`)
- Full MGK04 tutorial/admissions dialogue layer
- Enrollment/application form
- Name-entry controls (`HIRA / KATA / A-Z / DEL / NEXT / BACK / OK`)
- Native `0-9 / A-Z / a-z` keyboard preserved and verified in-game

### Recovered later work

Twelve builders missing from the previous repository snapshot have been
recovered, covering v6–v17g: name/nickname A-Z defaults, school choices,
greeting palettes, sex/subject/favorite-word choices, enrollment completion,
face customization, and the MGK10/MGK04 quiz layers. Recovery preserves the
historical scripts; it does not certify every intermediate candidate.

`recovery_manifest.json` records their content hashes. The v15b/v16 translation
packets remain local because they also contain extracted Japanese text.
They are not needed to run v17h on an existing v16 master.

## Development philosophy

Changes are built as isolated, source-verified layers. Each successful build is
identified by SHA-256 and tested in-game before becoming the next working master.

## Upstream tooling

Reverse-engineering/build tooling is based on:

`mcpads/justice-gakuen2-kr-patch`

Pinned upstream commit:

`98ca12ddf082d6e2367b2963f76edf5a09242deb`

The local `upstream/` checkout is intentionally not committed here.

## Copyright / repository contents

This repository is for translation code, build/probe scripts, documentation,
checksums, and original project work.

**No ROM/disc image, BIOS, rebuilt BIN/CUE, or copyrighted game asset is included.**
You must supply your own legally obtained game data when using the tooling.
