# Status and Diary English v28

The actual Windows build passed: two tests, zero failures (99.93s), followed by final verification.
The user reports that Status and Diary menus work in DuckStation. Individual item descriptions,
all birthday combinations and all practice entries are not independently certified.
See validation/status-diary-v28-windows.json. Keep v27 as fallback.

Scope: 40 shared graphics labels, 19 character names, birthday layout, Diary options,
speed settings and practice titles; 57 item descriptions across 78 School Life banks.
The actual run translated 4,388 coordinates and retained 58 custom current payloads.
The console does not identify those retained payloads; the detailed report is needed to classify them.
Existing player names, stats, relationship faces, item effects and saved dates are preserved.

The public builder and private input supplied in the conversation remain the recovery inputs.
Fresh-boot the printed CUE and load an in-game save. A save state can retain old loaded graphics.

Next builder: BOOT_NOTICE_V29.md. Practical-exam instruction graphics, other save/load prompts
and unique story dialogue remain outside v28.
