# Current Known-Good Milestone

## Name-entry UI v5

Live-tested rebuilt-disc SHA-256:

`
2fe51561d025cc2ffdface62d1a7e7222a40937bb3b5a97ebc019f8338d43977
`

Local working CUE (not tracked by Git):

`
upstream\work\english-name-entry-ui-v5\build\justice-gakuen2-name-entry-ui-v5.cue
`

### Confirmed behavior

- English enrollment form renders correctly in-game.
- Native name-entry controls render as HIRA / KATA / A-Z / DEL / NEXT / BACK / OK.
- Original control colors remain correct.
- A-Z page displays 0-9 / A-Z / a-z correctly.
- Keyboard navigation and cursor highlighting work.
- MGENT.BIN was unchanged by v5.
- Only MA_ENT.BIZ fixed graphics/control sprites were changed for v5.

### Next target

Patch only the name-entry page initialization behavior so the native A-Z page
opens by default for English name entry.

Do not promote a later build over this milestone until it is verified in-game.
