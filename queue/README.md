# Work queue (any assistant can take a task)

One file per task. **The folder a file is in is its status** - there is no index to keep in sync.

| Folder | Meaning |
|---|---|
| `open/` | not started |
| `in-progress/` | someone has it (see the `Claimed by` line) |
| `done/` | finished and verified; the `Result` section says how |

## Taking a task
1. Pick a file in `open/` whose **Needs** you can satisfy (e.g. `emulator` = you can drive DuckStation per `PLAYTEST_HOWTO.md`; `image-generation` = needs real art work; `none` = can be done from the repo alone).
2. `git mv queue/open/NNN-name.md queue/in-progress/` and fill in `Claimed by: <assistant>, <date>`. Commit/push only when the user says so (see `AGENTS.md`).
3. Do the work. Follow `AGENTS.md` for builds and testing. Add findings to the file, not to the handoff.
4. Finish: fill in **Result** (build version, files/tools changed, what was verified in game and what was NOT), then `git mv` the file to `done/`.
5. If you cannot finish, move it back to `open/` and write what you learned under **Notes** so the next assistant does not start from zero.

## Adding a task
Copy `TEMPLATE.md` to `open/NNN-short-name.md` (next free number). Keep it short: what is wrong, where it was seen, where the source probably is, why it is hard. Do not queue something you can simply do now.

## Status at a glance
`python tools/queue_status.py`
