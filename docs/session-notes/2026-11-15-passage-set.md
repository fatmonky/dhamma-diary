# 2026-11-15: Passage generator, passages.json and the daily sequence (build step 4)

Spec: `docs/spec/v1.md` §3.3, §3.4, §5 and §7 step 4. Branch: `build/v1`.

## What changed

**Generator**: `scripts/passages/build_passages.py`, promoted from `prototypes/passage-set/build.py` on `prototype/passage-set`.
- Input: `scripts/passages/passages-source.json` (id, ref, uid, ranges, question; in sequence order) and a local bilara-data `published` checkout. A sparse checkout of `translation/en/sujato/sutta` is enough; the clone commands are in the script's docstring.
- Segment selection and titles work as in the prototype: the title is the last non-empty `:0.x` segment, `0.x` headers and empty segments are skipped, and whitespace is trimmed.
- It removes an unpaired `“ ” ‘ ’` only at the excerpt's very first or last character. A `’` inside a word (an apostrophe) is not counted as a closing quote. This removed the opening `“` from 7 excerpts and changed no words.
- It fails on a duplicate ID, a range that matches no segments, or an empty question. All three were checked by hand.
- It writes the bilara-data commit SHA and prints each passage's word count.

**Source**: `passages-source.json` holds the opening 13 from spec §5, with IDs, ranges and questions as signed off. The questions are copied from the prototype's `questions.json`, and the ranges were checked against the §5 table.

**Output**: `DhammaDiary/Resources/passages.json`, built from bilara-data `published` @ `baa73bb`. Word counts match the signed-off record (154, 62, 82, 99, 113, 146, 77, 174, 109, 54, 163, 102, 143).

**App**
- `Models/Passage.swift`: `Passage` and `PassageSet` are plain `Codable` structs, not SwiftData. `PassageSet.bundled` loads once; if the file is missing it logs the error and returns an empty set instead of crashing. `Passage.journalCopy` gives what a `JournalEntry` keeps.
- `Utilities/PassageSequence.swift`:
  - `recordFirstDayIfNeeded()` stores `sequence.firstDay` ("yyyy-MM-dd" of the reflection day) once. `DhammaDiaryApp.init` calls it.
  - `index(firstDay:currentDay:passageCount:)` counts whole calendar days with `dateComponents([.day])`; a negative count gives 0.
  - `passage(for:)` returns tonight's passage.
- `.github/workflows/ci.yml` still built `WhiteStone.xcodeproj` / the `WhiteStone` scheme, missed in step 1. It now uses DhammaDiary.

Nothing on screen uses passages yet; step 5 builds the Diary tab's Tonight and Passages modes on top of this.

## Verification

- Build and tests on iPhone 17: **47 passed, 0 failures, no warnings**.
  - `PassageSetTests` (6): the file decodes with source details; there are 13 passages; IDs are unique; every passage has text, blocks matching ranges, a question, a title and a suttacentral.net URL; the first is `an10.51-mirror`; `journalCopy`; `bundled` matches the file.
  - `PassageSequenceTests` (8): day 0 → passage 1, day 12 → 13, day 13 → 1, negative → 1; other passage counts; the count across the 25-hour DST day; first day stored once, as the reflection day (01:00 on the 15th stores the 14th); first night shows AN 10.51 and the next night MN 19.
- The generator runs cleanly against a fresh sparse clone.
- Simulator: after reinstalling and launching, the app's preferences show `sequence.firstDay = 2026-11-15`.

## Not verified

- CI hasn't run: it triggers on `main` and pull requests, and only `build/v1` has been pushed.
- No screenshots: nothing visible changed in this step.
