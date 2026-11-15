# Review: journal entries in place of reflections (v1 build step 6)

Spec: `docs/spec/v1.md` §4.3.

## Already in place from earlier steps

- Step 2: the calendar marks days with an entry (`DayCell.hasEntry`), and the selected day shows its stones then its entry (reference and title, the stored question, the text). Tapping it opens the entry.
- Step 3: the stats line, 14-day bars, all-time chart, streak and pattern notes group by reflection day and count stones only.
- Text pass: the Review tour button reads "Continue to Diary".

## What changed in this step

- **Way through to Passages.** An entry opened from Review now has an "All entries for this passage" link. It saves any edit, switches to the Diary tab and opens Passages with that passage expanded.
  - `Views/Diary/OpenPassageAction.swift`: an environment action set by `ContentView`.
  - `DiaryView` takes a `passageRequest` binding and switches to Passages when it's set.
  - `JournalEntryDetailView(showsPassageLink:)`: on from Review, off inside Passages (where it would loop).
- The question in Review's entry card uses the same serif as the Diary.
- Checked: the month's entries are fetched by calendar month on `JournalEntry.day` (start of the calendar date), so the 1st's entry isn't lost to the 03:00 month boundary that stones use.

## Tests

52/52 pass. No new unit tests: the change is navigation only.

## Screenshots

- [Review](../session-artifacts/2026-11-15-review-01.png): stats, bars and calendar unchanged.

## Not verified

No journal entries exist in the simulator and I can't type into it from here, so these are unchecked by hand:

- the calendar mark and entry card for a day with an entry;
- opening an entry from Review and following "All entries for this passage" to the Diary tab;
- if Passages is already showing when the link is followed, the list expands the passage but doesn't scroll to it.
