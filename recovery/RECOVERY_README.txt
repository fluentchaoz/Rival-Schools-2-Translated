Justice Gakuen English quiz recovery kit v1

WHY THIS KIT
The recovered v8 CUE is only a track descriptor. It contains no game data and
does not replace its companion BIN. This kit needs the original Japanese BIN.

Your Downloads scan found the verified original Japanese disc, SHA-256
0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e,
but did not find the translated v16 image. v17h requires v16. Renaming the
Japanese image or changing the hash check cannot supply the missing layers.

This kit includes the recovered Batsu workspace, both quiz translation files,
the earlier builders, and a new runner. It builds 22 steps from the original
through v16 and then runs the v17h candidate builder. It compares every
pre-v17h output with the hash recorded by its successor.

RUN
Extract this ZIP into a short folder, for example Downloads\JG2-Recovery-Kit.
Open Windows PowerShell in the extracted folder. First check the prerequisites:

powershell -NoProfile -ExecutionPolicy Bypass -File .\rebuild_quiz_from_original.ps1 -CheckOnly

Once that passes, start the rebuild:

powershell -NoProfile -ExecutionPolicy Bypass -File .\rebuild_quiz_from_original.ps1

Defaults: original disc in your Downloads game folder; new build folder at
%USERPROFILE%\JG2-Recovery-v1. Your existing translation project is not used.
The first run requires approximately 24 GiB free on the recovery drive.
Git, Cargo and rustup must already be on PATH, with the Windows C++ build tools
used for your previous Rust builds. The runner installs/reuses Rust 1.98.0
without changing your default toolchain. Internet is needed for source and
compiler dependencies. The installed C:\Windows\Fonts\arial.ttf is required.

OTHER DRIVE / SOURCE
powershell -NoProfile -ExecutionPolicy Bypass -File .\rebuild_quiz_from_original.ps1 -BuildRoot D:\JG2-Recovery

Use -SourceBin "full path to your original.bin" if the source was moved.
Use -CheckOnly to verify local prerequisites without creating files.
Use -StopAtV16 to stop before the v17h candidate.

AFTER AN ERROR
Keep the new recovery folder. It contains logs and source checkpoints.
Fix the reported problem, then repeat the SAME command with -Resume added.
Use the same -BuildRoot and -SourceBin values if you supplied them.
Resume verifies the kit, font, last completed image and saved source. It
restores a failed step's source checkpoint only inside its own recovery folder.
Do not edit generated source there while a recovery is in progress.

If a build hash differs, stop and share its stage log from the logs folder.
Do not bypass the hash check. A different Arial version or an unrecorded
historical source edit may need investigation.

OUTPUTS
The runner prints the full v16 CUE path when the exact image is restored.
It prints a separate v17h CUE path when the graphics candidate succeeds.
Open the CUE in DuckStation. Retain v16 while checking v17h's QUESTION,
CORRECT!, WRONG!, and EXAM OVER graphics and normal quiz progression.

VALIDATION / LIMITS
This is a recovery candidate, not an already-built translated disc. The new
runner passed seven synthetic tests, including interrupted-step resume;
the v17h wrapper passed five more. All packaged PowerShell scripts passed
syntax parsing under PowerShell 7.4.13. These checks do not execute the complete
Windows/Arial rebuild, which must still pass all 22 output hashes on your PC.
The original disc and Windows font are not included. No existing project or
original disc is overwritten. Prior builds are kept inside the recovery folder.
The nested v9b build deliberately regenerates its own earlier tutorial output.

Do not upload this private workspace kit to a public repository. Its saved
workspace and quiz packets contain source-bound Japanese text. Public source
and recovery scripts live on the codex/resume-english-quiz branch of:
https://github.com/fluentchaoz/Rival-Schools-2-Translated
