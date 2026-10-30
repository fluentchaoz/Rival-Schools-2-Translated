# Status and Diary English v28

Status: final validation in progress. Do not promote an untested image.

This candidate builds on actual Windows v27
`3f5b7630fd3115804c892e75c37213fbfff148b28ed657d0424ecba0614dc34e`.
Original disc SHA-256:
`0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e`.

## Scope

- 40 shared graphics labels: Status / Items / Friendship, 19 character names,
  M/F and birthday, Diary choices, speed settings and Japanese practice titles.
- 57 item descriptions at 4,446 source coordinates across all 78 School Life
  text banks. Existing custom descriptions are retained and separately counted.
- BIRTHDAY MM/DD layout, changing only six screen-position values. Native saved
  dates and leading-zero suppression remain unchanged.

Player names, portraits, relationship faces, item icons/effects, native palettes,
scripts and earlier English are preserved. The name list includes Daigo, not
Raizo. Existing Roman Doki-Waku-Dance artwork is retained.

Save/load confirmation and error prompts, practice instructions and unique
story dialogue remain outside this batch. Save/load is the next shared interface
work item; its numeric and selection consumers need dedicated validation.

## Private input and recovery

Download JG2-Status-Diary-v28-Inputs.zip supplied in the translation conversation
into Downloads; leave it zipped. Its exact root member status_diary_v28.json has
SHA-256 `1ab4acbf72a23100756e6e1a689169b01da7448032aa0bad8a0a4da81f99e3b7`.
The public builder loads this private input at runtime and checks the hash.
The packet is not embedded in public source or downloaded from a public server.
Keep this ZIP with earlier private packets, original disc, font and saves.
GitHub contains generic code and recovery directions, not all private inputs.

The recovery checkout, Rust 1.98.0 and Windows Arial are used by default. The
builder accepts -PacketPath, -MasterBin, -SourceBin, -UpstreamRoot, -WorkRoot and
-FontPath. Add -CheckOnly for read-only preflight. It verifies identities, output
ownership and free space before source changes, saves an exact source backup,
and restores source/environment in finally. Existing candidates are not replaced.

When final validation is complete, run the pinned build_status_diary_english_v28.ps1
supplied in the conversation. The console prints the actual BIN hash, report,
previews and CUE:

```text
C:\Users\Fluent\JG2-Recovery-v1\candidates\status-diary-v28-<new GUID>\build\justice-gakuen2-status-diary-v28.cue
```

## Native test

Keep v27. Fresh-boot the new CUE and use an in-game memory-card save; a save state
may retain old loaded text and graphics.

1. Check Status headings, all 19 names, M/F, birthday, and unchanged player name,
   stats and relationship faces.
2. If items are owned, check their English descriptions and bonuses.
3. Check all five Diary choices, speed settings and available practice names.
4. Check earlier English and the v27 travel map when convenient.

The original-disc fixture uses Nimbus Sans instead of Arial and lacks earlier
English layers. Its hash is not a production v28 hash. Actual v27-to-v28 Windows
building and native gameplay remain required.
