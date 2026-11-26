# Each further question on its own line; drafted questions for the new passages (24 Nov 2026)

## Question lines

PJ asked for the second question of a reflection question to sit on its own line.

- `DhammaDiary/Utilities/QuestionText.swift`: `String.questionLines` breaks the line after a "?" that is followed by a capital letter. A leading statement ("Think of a small wrong you did today.") stays with the first question.
- Used on the full-size screens: Tonight (`TonightView`), an entry's detail (`JournalEntryDetailView`), Review's day entry (`ReviewView`) and Passages history (`PassagesView`). It's done at display time, so it applies to the shipped 13, the new passages and past entries alike, and `passages.json` is unchanged.
- Left as one flow: the Today card (three lines), the widgets (tight space) and Siri's spoken question.
- The review page's phone preview (`scripts/passages/review/index.html`) breaks lines the same way.
- Tests: `QuestionLinesTests` in `DhammaDiaryTests/PassageTests.swift` (3 cases). Full suite: 103 tests pass on the iPhone 17 simulator.
- Screenshot: [Tonight with AN 4.18](../session-artifacts/2026-11-24-question-lines-01.png).

## Passage set progress

- PJ marked 41 passages in the review page (the 13 shipped + 28 new); MN 81 is Maybe.
- Claude drafted the 28 empty questions into `scripts/passages/review/selections.json` for PJ to edit. `export_source.py --check` passes for all 41. Nothing exported yet.
- When it is exported, `PassageSetTests.testBundledFileDecodes` (expects 13 passages) needs its count updated.

## Not done

- Widgets and the Today card weren't changed, so not re-checked.

## Export: the set is now 41 passages (later the same day)

- First export attempt failed the app's tests: 11 widget excerpts over 340 characters and 13 highlights over 110 (`PassageSetTests`). The app files were rolled back; `export_source.py` and the review page now enforce both limits, and the export stores each question as one plain line (the app adds the breaks) and names Dhammapada passages by verse ("Dhp 100", "Dhp 55").
- PJ trimmed the excerpts and highlights in the page. Claude restored two letters lost when selecting highlights: SN 56.11 "extinguishmen" → "extinguishment", MN 41 "ay these…" → "May these…".
- Exported: `scripts/passages/passages-source.json` and `DhammaDiary/Resources/passages.json` now hold 41 passages (13 + 28 new, order as in the Sequence tab). Of the original 13, only AN 4.18 changed, by PJ: widget excerpt 2.1–2.4 → 1.1–1.3, question "in your life so far" → "today so far". Its ID is unchanged; past entries keep their question.
- `PassageSetTests.testBundledFileDecodes` now expects 41. All 103 tests pass on the iPhone 17 simulator.
- Screenshots: [tonight (AN 4.18)](../session-artifacts/2026-11-24-passage-set-41-01.png), [its question](../session-artifacts/2026-11-24-passage-set-41-02.png).
- Accepted side effect (spec 3.4): anyone past day 13 of the old loop jumps to a different passage, because the index is now taken mod 41.
- Not checked by eye: the new passages on screen and in the widgets (the simulator's sequence is on day 10). Tests cover decoding, lengths and verbatim text.
- Still open for PJ: the Dhammapada IDs `dhp100-115-8-thousands` and `dhp44-59-4-flowers` become permanent once a build with them reaches other people. MN 81 is still Maybe.

## Several passages from one sutta (later the same day)

PJ often wants more than one passage from a sutta, each on a different night. The review page now has **Duplicate sutta**: it adds a row such as "MN 10 · 2" under the sutta, with the usual layout for picking its passage, excerpt, highlight and question. Segments used by the other copies are dashed and labelled ("· 1"). **Remove this copy** deletes a copy (not allowed for passages already in the app).

- Storage: copies live in `selections.json` under keys `uid~2`, `uid~3` … with a `uid` field; the original stays under its uid, so the existing file needed no conversion. Default IDs end `-2`, `-3`.
- `export_source.py` treats each copy as its own passage (same ref and title as the sutta).
- Checked headless against PJ's running server: duplicated MN 10, picked a passage, excerpt, highlight and question in the copy, marked it In the set; the list, dashed segments and Sequence row were right, and `export_source.py --check` accepted the copy. The test copy was then removed, restoring `selections.json` exactly. Screenshot: [duplicating MN 10 (test entry)](../session-artifacts/2026-11-24-duplicate-sutta-01.png).
