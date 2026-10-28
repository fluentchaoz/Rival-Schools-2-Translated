# Pool, club orientation, and daily menu English v22

Candidate prepared: direct Rust disc tests and offline consistency checks passed.
Windows/native v22 execution remains pending. Production input is actual v21 SHA-256
`f4a470836cded402c5ec5df041f0023693099761f1a25cd1045690d8bae005f0`.
Keep v21 and v20, the original disc, and the private recovery kit.

The user confirmed the v21 apology route reached the pool. They also confirmed
that the yellow O was probably the enrolled character name; no name patch is
planned. The remaining work is the daily action menu, Covered Walkway/Poolside
labels, and Taiyo selectors 0/1 entries 57–176, including pool introductions,
all eight club descriptions/choices and the go-home option, and the general training tutorial.

The reviewed English packet is `translations/pool_club_v22.json`. It includes
palette/name placeholders and the source two-column club menu positions.
The native menu graphics come from MGCOCK.TIZ; Taiyo help text is selector 2
entries 52–55. Shared labels are global; help text and story scope are Taiyo.

The current message arena has little spare room. The planned builder shares
identical message payloads through native pointers and validates every selector
and entry against its expected payload. Native MGAME +0xcaa4 loads an indexed
message pointer; +0xd630/+0xd974 read halfwords, and +0xd634/+0xd978 compare them
with 0x3001 to terminate traversal. No next-pointer length is supplied by the
compact message handler. Source identities/instructions must be verified before
using aliases. Upstream's strict contiguous-bank parser is suitable for reading
v21 input; a pointer-aware reader is needed after compaction and for later patches.

The private inspection helper `tools/inspect_pool_club_v22.py` accepts the
original BIN and a private output folder. Its extracted records/previews must
stay outside public GitHub. Full validation/build instructions will be added
when the candidate is ready.

## Builder design

`build_pool_club_english_v22.ps1` is generated from the Rust template and English
packet by `tools/assemble_pool_club_v22.py`. It discovers the exact v21 candidate,
uses the staged original and installed Arial, checks headroom, writes to a new
candidate directory, and retains/restores exact source bytes. Only this PS1 is
needed on the user's PC; the reviewed template and packet remain recoverable.

The patch owns five records: MGG04T.BIZ, its member-0 copy in MGG04.BZZ,
MGBGG04.BZZ, MGCOCK.TIZ, and a 72-byte text-spacing block in MGAME.BIN. The text
patch targets selector 0/1 entries 57–176 (240 entries) plus selector 2 entries
52–55 (four daily-menu help messages). It preserves native name insertions and
palette/style controls through ordered placeholders. Earlier ceremony messages,
all untargeted payloads, and every script byte stay exact.

Identical message payloads share storage. Each selector retains the same entry
population and terminator. The builder checks the original contiguous-bank
parser against the pointer reader on v21 input, then validates every output
payload by native pointer traversal. It binds the main reader's indexed-load
and 0x3001-termination instructions against source MGAME. It does not change the
native message reader. Future patches must use `pointer_banks` for this output;
the upstream strict contiguous-bank parser intentionally rejects aliases.

The two-column club choice pages preserve the native second-column start at
cell 10 and their three rows. Yes/no and tutorial choices preserve two rows.
Names are measured using the native six-cell bound; every line fits 20 cells
and every message fits four rows. Existing v21 glyphs remain untouched. New
characters use only trailing slots that are blank and unreferenced.

Four action labels (CONTINUE / MOVE / STATUS / DIARY) replace their exact source
cells in MGCOCK. Native selected/unselected palettes are unchanged. The action
spacing program is the source-bound upstream compositor: adjacent 24px slices,
with the original menu background extents preserved. Its 72 bytes and descriptor
rows are guarded; all other MGAME bytes stay exact.

Location patches update exact matching source graphics for Walkway, Poolside,
Club Building, Field, Sumo Room, Gym, and Classroom types used by the sequence.
Only the left location strip changes. Earlier v21 titles/labels, palette words,
headers, backgrounds, portraits, unrelated TIMs, archive table/padding, and other
school dialogue members stay exact. Graphics recompression retains the source
prefix, final page, and maximum match/control-block limits. All fixed record
lengths, readback, image sector scope, and changed-sector EDC/ECC are checked.

## Validation limitation

Automatic approval review blocked a local PowerShell fixture run because the
host attempted to contact a Visual Studio telemetry endpoint. That run is not
counted as a passed wrapper test. Testing continues through direct Rust execution
and offline wrapper inspection; no further local PowerShell execution is used.
Windows/native v22 checks remain pending. Final local results will be added to
`validation/pool-club-v22.json` before the candidate is handed over.

## Shared-record evidence

The user's earlier private stat export was recovered and all eight record hashes
were verified. Its actual MGAME and MGCOCK records remain unchanged by v18–v21,
whose scopes affect other records. They are now additional production guards:

- MGAME: `e8885452773fcf91bef4b85b2363a37d07547ab3c04b463c92c658d66cc1492f`
- MGCOCK: `91e79bd579837c032e0284c15683c076c27a86f0c26299f00ad0539410ca6e9b`

Their native pointer reader, menu spacing source, and descriptor bytes match the
original source anchors. The final local fixture incorporates these actual
shared records alongside locally reconstructed v21 ceremony records. It still
does not represent a complete actual Windows v21 image; the fixture master and
text-record identities are substituted only in a temporary QA copy.

## Build and playtest

Download `build_pool_club_english_v22.ps1` from the same commit as this document.
Run it from Windows PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build_pool_club_english_v22.ps1
```

It finds the SHA-verified v21 BIN under `JG2-Recovery-v1/candidates`, uses the
staged original and installed Arial, and prints a fresh `CUE TO TEST` under
`candidates/pool-club-v22-<unique-id>/build`. It needs roughly 4.65 GiB headroom
on a single drive. The original kit, plan, state, input images, and earlier
candidates remain available. No extra JSON/Rust download is needed on Windows.

Use `-CheckOnly` for read-only preflight. Alternate `-RecoveryRoot`, `-MasterBin`,
`-SourceBin`, `-UpstreamRoot`, `-FontPath`, and a fresh `-WorkRoot` are supported.
The wrapper inherits v21's exact-byte backup/restoration and environment logic.
Its backup is `name_entry_input_tests.pre-v22.rs.bak`, and its log is
`build-v22.log`. If an external interruption leaves the v22 injection, restore
that exact backup before retrying; do not bypass identity checks.

Keep v21. Boot the new CUE fresh; older emulator save states can retain loaded
Japanese resources. Test:

1. CONTINUE / STATUS / DIARY, including the selected highlight and Taiyo help text.
2. English pool dialogue and WALKWAY / POOLSIDE labels, then the club-building scene.
3. Both club-choice pages (SPORTS / CULTURE): three rows, two columns, correct cursor alignment.
4. Several club descriptions and NO / YES prompts. NO should return to the choices.
5. A chosen club, the general training tutorial, and its skip/repeat choices.
6. Player-name insertions and earlier English ceremony/quiz behavior.

MOVE is also translated for days where that action replaces CONTINUE. Shared
label graphics are global, while the help and new story text are Taiyo-specific.
Later April scenes and other school dialogue remain outside this candidate.
Report the club/branch tested and the next Japanese or any display issue.

## Final local results

The final direct Rust run passed both the complete disc build and the shared-
pointer/invalid-pointer regression (two passed, zero failed). Its fixture used
the verified original, reconstructed v21 ceremony records, and the user's
actual saved MGAME/MGCOCK records (all eight private export records verified).
Only expected master/text identities were substituted in the QA module.
Production source and shared-record guards remain unchanged.

The build changed 1,232 sectors inside the five owned records and passed all
record-readback, input-hash, fixed-length and EDC/ECC checks. It shared 502
message references, using 69,896 / 102,368 arena bytes; an unshared layout would
need 109,400 bytes. Dialogue compression is 225,304 / 225,706 bytes; header
compression is 75,818 / 77,342 bytes. New glyphs are colon, right angle bracket,
and X in slots 927–929. Local test source was manually restored byte-for-byte.

Preview review covered white/yellow menu states, location strips, the native
two-column choice geometry, six-cell name insertions, and menu-help layout.
These font-dependent numbers use Liberation Sans Regular; they are not claimed
to be Windows Arial output identities. Full evidence and the fixture output
hash are in `validation/pool-club-v22.json`. The PowerShell runtime-test limit
above remains; the wrapper's embedded-source and offline consistency checks
passed. No actual Windows v22 or native playtest is claimed.
