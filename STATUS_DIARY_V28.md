# Status and Diary English v28

Local validation passed. Actual Windows building and native gameplay remain pending.

Scope: 40 shared graphics labels, 19 character names, birthday layout, Diary options,
speed settings and practice titles; 57 item descriptions across 78 School Life banks.
Existing player names, stats, relationship faces, item effects and saved dates are preserved.
Custom current descriptions are retained rather than overwritten.

Two original-disc fixture tests passed (0 failures, 138.97s), along with five offline
wrapper checks. All 105 previews were reviewed. An independent layout check covered
372 date-width cases without overlap or header overflow. See validation/status-diary-v28.json.
The fixture uses a substitute font and lacks earlier English layers; it is not a native test.

Use the pinned builder and private input supplied in the translation conversation.
Keep v27. Fresh-boot the new CUE printed by the builder and load an in-game save.
Check both Status and Diary, available item descriptions, birthday spacing and prior English.
Save/load prompts, practice instructions and unique story dialogue remain outside this batch.
