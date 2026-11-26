# Locations and English name insertions v25

Input: actual v24 SHA-256
`c21d3d0a6ffdfc3d4a666251f450edbc5b68f16b90716101143d2c69e2415e4f`.
Use build_locations_names_english_v25.ps1. It finds the verified input, creates
a fresh candidate, backs up/restores the exact Rust source, and prints a CUE.
Keep v24 until native testing passes.

The native relationship controls choose family/given/nickname and then read
honorific strings from selector2 entries5–8. Upstream runtime_insertions.rs and
runtime_insertion_messages.rs identify these as kun (kanji), kun (katakana), san,
and chan. v25 replaces all four with valid empty end-terminated messages in25
MGG event banks, including loaded school bundles. English dialogue addresses
people by name without Japanese honorifics. Enrolled names, relationship-based
name selection, story payloads, scripts, fonts, HUD and date graphics are preserved.
The native MGAME message consumer is source-checked and unchanged.

The graphic pass checks48 MGBG background archives for exact source-label pixel
matches derived from Taiyo's April backgrounds. It covers matching School Gate,
Plaza, Ride Entrance, Pond, Arcade, Neighborhood, Rooftop, Classroom, Gym, Field,
Walkway, Poolside, Club Building and Sumo Room strips. Existing English strips
are preserved. Only128x24 label cells change; palettes and pixels outside them
are checked unchanged. Unmatched labels elsewhere are outside this patch.

Validation: direct Rust on the verified original disc as a full QA fixture,
using Nimbus Sans instead of Windows Arial. Only the QA master identity is
substituted. This fixture lacks the prior English layers; production retains
the exact v24 guard and patches current record bytes. Fixed slots, native
compression, record readback, sector ownership, EDC/ECC and input identities
are checked. This does not establish actual Windows or native gameplay success.
The Windows wrapper is derived from the successful v24 wrapper and checked
statically; local PowerShell remains unexecuted after the earlier telemetry block.

Native checks: fresh-boot the new CUE, replay the April16 opening, check School
Gate and Plaza, then Hinata and Ran saying O without Japanese suffixes. Check
other park labels and that following text still appears after inserted names.
Also check a longer name and relationship tiers when practical. Other schools'
story dialogue and unmatched labels remain Japanese.

The final fixture passed in886.39 seconds, translated394 source-label copies in43 archives, and changed28886 raw sectors. Actual v24 already has English strips, so production should patch fewer copies. Allow several minutes for this broader sweep. Actual Windows and native results remain pending. See validation/locations-names-v25.json.
