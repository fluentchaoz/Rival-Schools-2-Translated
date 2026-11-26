# Boot notice English v29

A finished v29 image was recovered and inspected on 2026-11-06. Its BIN SHA-256 is
`f4f974c40220dd82925d4b17d6a31b3f95218a6017783666851204ea3040c67f`.
Archive extraction, CUE identity and all four notice slots passed; see
`validation/boot-notice-v29-recovered.json`. Fresh-boot that CUE for the pending
native test. The original Windows build report/log was not recovered.

The instructions below describe rebuilding from actual v28 if necessary.
No additional translation ZIP or font is needed.

The two messages become NO FILE and LOAD SKIPPED. Their shared Records copies are updated too.
Only four bounded string slots change in the resident executable and Records overlay. The game uses
its existing English glyphs. Code, font data, pointers, save behavior and other bytes are preserved.

Run the pinned build_boot_notice_english_v29.ps1 supplied in the conversation. Defaults use the
recovery checkout and discover the verified v28 candidate. Optional -RecoveryRoot, -MasterBin,
-SourceBin, -UpstreamRoot and -WorkRoot override paths. -CheckOnly performs read-only preflight.
The builder checks disc hashes, length, free space and output ownership; makes an exact source
backup; restores source and environment in finally; and prints the actual new CUE and output hash.
Keep v28 and fresh-boot the new CUE. Test the notice without changing or deleting memory-card data.

Two original-disc fixture tests passed, including custom-target rejection and unrelated-byte
preservation. Three offline wrapper checks passed. Native gameplay remains pending. A finished image is now recovered, but the actual
Windows build log/report remains unavailable. Validation: validation/boot-notice-v29.json.

The user reports v28 Status and Diary menus work. Actual v28 Windows evidence is recorded in
validation/status-diary-v28-windows.json. The 58 retained custom item entries have not been individually
classified from the console; no claim is made that all are English.

## Exam instructions: pending

The screenshot's practical-exam instruction artwork is identified as TESTMJ member 30.
Members 31 and 32 contain the other term introductions. Their native tile presentation still
needs verification before translation is installed. A DuckStation save state frozen on the
instruction bubble will supply the runtime packet layout. Keep that private; do not commit it.
Other practice instruction cards and remaining save/load prompts remain outside v29.
