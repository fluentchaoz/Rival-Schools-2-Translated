# Rival Schools 2 Translated

English fan-translation / reverse-engineering project for the Japanese PlayStation
release of **Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2** (`SLPS-02120`).

## Status

Current live-tested working milestone: **Name-entry UI v5**

Known-good rebuilt-disc SHA-256:

`2fe51561d025cc2ffdface62d1a7e7222a40937bb3b5a97ebc019f8338d43977`

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
