# English translation conventions

These are working defaults for review, not a claim that every existing patch
already complies.

- Translate from the Japanese source and surrounding branch context. Preserve
  intent, jokes, relationships and character voice; do not invent plot details.
- Keep the original Japanese voice audio. English text should remain readable
  without requiring knowledge of Japanese honorifics.
- School names: Taiyo, Pacific, Gorin, Gedo, Justice. Confirm source ownership
  instead of guessing the school from a filename letter.
- Character names use established English franchise spellings when verified.
  Maintain a glossary with source/context evidence before standardizing new names.
- Preserve enrolled player names and native relationship-based family/given/
  nickname selection. O is the user's actual name, not a broken placeholder.
  v25 omits kun/san/chan in 25 MGG banks; do not claim all banks already do so.
- Preserve both player variants. Review differing source payloads rather than
  blindly copying one variant over the other.
- Dates use runtime MONTH/DAY in ordinary text, matching the existing HUD.
  Event cards can use APRIL 16 / FIELD TRIP. Do not change gameplay dates.
- Use "term" for school academic terms, "year-end exams" for end-of-year
  written exams and "advancement exam" for promotion exams unless game context
  establishes a more specific system term. "Closing ceremony" is not graduation.
- Draft natural English first; store fitted text separately. Existing dialogue
  uses uppercase bitmap text and constrained cells. Check runtime names,
  punctuation, line count and choice columns against the actual renderer.
- Source control codes and arguments, number/name/date insertions and style
  changes are functional data. Preserve and validate them explicitly.
- Record ambiguities and deliberate localization decisions. Do not disguise
  uncertain reading, a layout compromise or unreviewed reuse as final work.
