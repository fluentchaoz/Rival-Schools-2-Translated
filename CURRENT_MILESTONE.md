# Current Known-Good Milestone

## School-choice UI v8 — live tested

Live-tested rebuilt-disc SHA-256:

`07b4dda156ab0eac7f149f66f7bcb9727a8e74fad4faa2d19d77cee362504d84`

Local working CUE (not tracked by Git):

`upstream\work\english-name-entry-school-choices-v8\build\justice-gakuen2-name-entry-school-choices-v8.cue`

### Confirmed behavior

Everything from v7 remains working:

- English enrollment form
- `HIRA / KATA / A-Z / DEL / NEXT / BACK / OK`
- native `0-9 / A-Z / a-z` keyboard
- NAME defaults to A-Z
- NICKNAME defaults to A-Z
- page cycling and cursor behavior remain functional

v8 additionally translates the five-school popup while preserving the crest icons and selection logic:

- `TAIYO HIGH`
- `GORIN HIGH`
- `PACIFIC HIGH`
- `GEDO HIGH`
- `JUSTICE HIGH`

School choice descriptor table:

- `MGENT + 0x15F8`
- 10 descriptors total
- text descriptors: `1, 3, 5, 7, 9`
- crest/icon descriptors remain untouched

### Current polish target

The opening three-line greeting currently renders all three lines in the native blue/lavender palette even though the intended localization design was:

- `SCHOOL LIFE 2` — native blue/lavender (`0x0009`)
- `WELCOME!` — normal white dialogue palette (`0x00ff`)
- `HAVE A GREAT YEAR!` — normal white dialogue palette (`0x00ff`)

Cause: an earlier size-neutral reflow converted the source body-palette control into a line-break control, and the later blue-title patch therefore left no white-palette switch for the body.

The next candidate rebuild should restore the white body palette and add a separate line break after the blue title, then transplant only `DAT2/MGK04.BIZ` onto v8 and live-test the greeting plus following dialogue.

After that polish, continue the enrollment subsystem: SEX, BIRTH DATE, BEST SUBJECT, FAVORITE WORD.

Do not promote a later build over v8 until it is live-tested.
