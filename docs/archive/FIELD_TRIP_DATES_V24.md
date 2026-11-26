# Taiyo field trip and event dates v24

Run `build_field_trip_dates_english_v24.ps1` against actual v23 SHA-256
`9329e5a8ed0c1270fa090f015a4a833ee4b00f120ec884b3f079d67d619fd4f1`.
The script finds this input in the recovery candidates, checks the original disc,
font and free space, creates a unique output, and backs up/restores the exact
Rust source. Keep v23. It prints the new CUE after final verification.

Scope:

- Taiyo April selectors 0/1 entries 348–562:430 field-trip messages, both player variants and all choices/endings.
- Taiyo selectors 3/4 entry34: English spring-field-trip opening with dynamic date.
- 1550 month/day message formats in25 MGG event banks across five school variants and five event archives. Dates become month/day; Japanese prose accompanying other dates is preserved.
- 19 unique event/exam title cards,48 inventoried copies. Existing English April8 cards are preserved. These include April16 Field Trip, later festivals/holidays and exams.

The June12 title is Taiyo vs Pacific; the event opening also mentions Gorin vs Gedo.
The title artwork uses rainbow English lettering with white outlines and flat,
source-colored clearing areas behind headings. Art outside those rectangles and
palettes are preserved. This does not translate every menu, location or story.
Other schools' conversations and later story events remain outside scope.

The date sweep updates standalone school records AND their loaded five-member
MGG bundles. Native pointer aliasing is retained, scripts stay unchanged, and
all replacements stay within existing record/member slots. The full builder
checks record readback, changed-sector ownership and native EDC/ECC.

Native test: fresh boot the new CUE, reach April16, check APRIL16/FIELD TRIP and
the opening dialogue date, then test the complete amusement-park event. Check
Ran's accept/refuse choices, destination columns, queue dispute, Akira helmet
choice, haunted house, arcade and Hyo branches as practical. The other player
variant and later cards/dates also need native tests. Retain v23 until tested.

Validation is direct Rust on a full original-disc fixture with locally rebuilt
v21/v22/v23 Taiyo text, using Nimbus Sans instead of Windows Arial. The fixture
lacks other earlier English layers. Only local expected master/text hash guards
are bypassed; production retains actual v23/original guards. Actual Windows and
native v24 results are pending. Local PowerShell is not rerun after the earlier
automatic-review telemetry block; wrapper consistency is checked statically.
