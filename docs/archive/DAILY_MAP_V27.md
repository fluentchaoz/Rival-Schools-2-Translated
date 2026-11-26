# Daily map, help and name defaults v27

This batch addresses the Japanese school travel map reported after April21,
and the automatic Japanese name accepted during enrollment. It builds on the
actual v26 candidate; keep v26 until the new candidate passes gameplay checks.

## Scope

- 21 shared daily/menu/map help patterns at 1,638 source coordinates across
  all 78 School Life text banks. Existing custom help is retained byte-for-byte
  and counted separately. The six destination descriptions are included.
- Six destination label sprites in 11 matching map atlases: CLASS, FIELD,
  ROOF, GYM, INFIRMARY and CLUB BLDG. Full destination names appear in help.
  Thumbnails, bubbles, cursor, frames and all palettes are preserved.
- New-enrollment empty-field defaults: SEIGI / MAKOTO / MAKO. The nickname
  has a four-character native limit. Existing saved names are not renamed.

Unique story dialogue, the rest of the status/diary interface, and save/load
prompts are not completed by this batch. Some save prompts receive numbers at
fixed text positions and require separate consumer checks.

## Required inputs and recovery

Actual v26 master BIN SHA-256:
`1a1f3ec2f5ab6abf4730748fd68df9e30cc8db55e43bc85308593986932a1e45`.

Original BIN SHA-256:
`0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e`.

Download the private **JG2-Daily-Map-v27-Inputs.zip** supplied in the translation
conversation into Downloads and leave it zipped. It contains the exact
`daily_map_v27.json` with SHA-256:
`e131e16c003551b765c69336cfecb7877bc7ca1c1f9a132ca97a25be47f46c63`.
Keep that ZIP with the other private recovery inputs. GitHub contains the generic
builder, code, validation summaries and directions; it does not contain the
private packet, original disc, font or memory-card saves.

The builder also accepts `-PacketPath` with the ZIP or exact JSON, `-MasterBin`
with the verified v26 BIN, and the existing recovery path overrides. It defaults
to the recovery checkout and Windows Arial. Rust 1.98.0 must be available.

## Build

Run the downloaded, pinned `build_daily_map_english_v27.ps1` from the terminal
where recovery succeeded:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build_daily_map_english_v27.ps1
```

Add `-CheckOnly` for a read-only preflight. The builder verifies input hashes,
output ownership and free space before changing source, saves an exact source
backup and restores source/environment in `finally`. Existing candidates are
never overwritten. It prints the actual output CUE, BIN hash and report:

```text
C:\Users\Fluent\JG2-Recovery-v1\candidates\daily-map-v27-<new GUID>\build\justice-gakuen2-daily-map-v27.cue
```

Do not substitute an original-disc fixture hash for an actual v27 Windows hash.
The production builder requires the exact v26 master above.

## Gameplay checks

Fresh-boot the newly printed CUE in DuckStation and use an in-game memory-card
save. A save state may retain old loaded text or graphics.

1. Open the school travel map. Select all six destinations and check each label
   and its description, cursor and thumbnails.
2. Check CONTINUE / MOVE / STATUS / DIARY help and any available practice help.
3. Confirm the existing player name remains as saved and earlier English events
   still display correctly.
4. When convenient, test a separate new enrollment with empty name fields:
   SEIGI / MAKOTO / MAKO should be supplied. Do not overwrite the current save.

The current saved Japanese Makoto will remain Japanese. Continuing the map and
story test does not require starting over.

## Validation

Validation: both direct Rust tests passed (0 failures, 335.44s). The original-disc
fixture covered78 banks/1,638 help coordinates and11 map atlases/66 rectangles,
with fixed-slot compression, exact record/pointer readback, ownership and EDC/ECC
checks. All21 help previews and11 map strips were visually inspected. The bounded
native copier check passed all3 defaults, termination and neighbor canaries;
it is not a console test. Five offline wrapper checks passed; PowerShell was not
locally executed. Upstream source was restored exactly.
Fixture SHA-256:b191187378a647635b7c8dc62787ff9ffd0f10167b521cb808cc25e1d8d04e69
This fixture used the original as QA master and Nimbus Sans instead of Arial;
it is not the production v27 image. Actual Windows/native checks remain pending.

See `validation/daily-map-v27.json` for completed checks and their limits.
Original-disc fixtures use Nimbus Sans and lack the earlier English layers;
they establish source coverage and patch mechanics, not production output or
native gameplay. Actual v26 compression/preservation accounting is checked again
by the Windows builder. No v27 Windows output or native pass is claimed here.
