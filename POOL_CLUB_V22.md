# Pool, club orientation, and daily menu English v22

Implementation checkpoint: validation is in progress. Do not treat v22 as built
or native-tested yet. Production input is actual v21 SHA-256
`f4a470836cded402c5ec5df041f0023693099761f1a25cd1045690d8bae005f0`.
Keep v21 and v20, the original disc, and the private recovery kit.

The user confirmed the v21 apology route reached the pool. They also confirmed
that the yellow O was probably the enrolled character name; no name patch is
planned. The remaining work is the daily action menu, Covered Walkway/Poolside
labels, and Taiyo selectors 0/1 entries 57–176, including pool introductions,
all eight club descriptions/choices, and the general training tutorial.

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
