# Diary: Entries by date, and every passage in Passages

PJ marked up the Diary's Passages screen ([request](../session-artifacts/2026-11-25-diary-entries-passages-request.png)):

- "Instead of organizing the diary entries by sutta passage, I would like it organized by chronological order, with the date entry clickable, and the sutta also viewable by dropdown."
- "Can we insert another tab, that allows the user to view all the selected passages and questions?"

## What changed

- `DiaryView`: the Tonight/Passages toolbar button is replaced by a segmented control under the title: **Tonight · Entries · Passages**. `-debug.diaryMode entries|passages` picks one.
- `EntriesView` (new): every entry, newest first. The date and the start of the text open the entry; the passage line below ("SN 47.6 · A Hawk") drops down to the passage and the question asked that day.
- `PassagesView` (rewritten): every bundled passage in sequence order, "Night n · ref", title, question (three lines until opened), entry count, and "Tonight" beside tonight's. Opening one shows its text and links to its entries. Review's "All entries for this passage" and Tonight's earlier-entries link still land here, at that passage.
- `PassageView` gets `showsTitle` so the opened rows don't repeat the title.
- `-debug.expandFirst YES` opens the first dropdown in either mode, for screenshots.
- Spec 4.2 and the Diary tour copy updated.

## Screenshots

[Entries, an opened sutta, an opened passage](../session-artifacts/2026-11-25-diary-entries-passages-01.png) (demo data on the "DD Screens" simulator).

## Verification

- Build and all tests pass.
- The dropdowns were opened with the debug flag, not by tapping; taps on the phone not checked.
- The App Store screenshot of the Diary still shows the old layout (Tonight only, so it's unaffected).
