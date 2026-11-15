# 2026-11-15: Versioned schema and JournalEntry (build step 2)

Spec: `docs/spec/v1.md` §3.2 and §7 step 2. Branch: `build/v1`.

## What changed

**Data**
- `Models/Schema.swift`: `SchemaV1: VersionedSchema` (version 1.0.0, models `Stone` and `JournalEntry`), `DhammaDiaryMigrationPlan` with `[SchemaV1]` and no stages, and `DhammaDiaryStore.makeContainer(inMemory:)`.
- `App/DhammaDiaryApp.swift` now creates its container from the migration plan.
- `Models/JournalEntry.swift`: new `@Model` with the fields in spec §3.2 (`day`, `dayKey`, `passageID`, `passageRef`, `passageTitle`, `question`, `responseText`, `createdAt`, `updatedAt`).
- `Utilities/JournalStore.swift` holds the saving rules, so views no longer write entries directly:
  - one entry per day; saving again replaces the text and `updatedAt`;
  - the passage copies are written once and never overwritten;
  - blank text deletes the entry;
  - a new entry can only be created for the current day, so a missed day can't be filled in. Past entries stay editable.
- Removed `Reflection`, `ReflectionQuestions`, `ReflectionQuestionsTests` and `AttributionText`. `ReflectionDateFormatters` moved to its own file.
- `Stone` is unchanged.

**Views (kept working until steps 4–6 rebuild them)**
- Reflections tab, history mode (`ByQuestionView`): now lists journal entries grouped by passage, newest first. Each group shows reference and title; each entry shows day, question copy and text. Its toolbar label is now "Passages".
- Entry detail (`ReflectionDetailView`): edits a `JournalEntry` through `JournalStore`. Previous/next moves between entries for the same passage. Blank text deletes. A guard stops the old double-delete when the view disappears after a delete.
- Reflections tab, today mode (`ReflectionTodayView`): **temporary placeholder** ("Tonight's passage and question will appear here."). There is no passage to save against until step 4; step 5 builds "Tonight".
- Review: the calendar markers and the selected-day card now read `JournalEntry` (ref · title, question, text). `DayCell.hasReflection` → `hasEntry`.
- About: the AN 10.51 "Reflections" credit is replaced by the "Passages" credit text from spec §4.4 item 3. The rest of About is step 7.

**Docs**: `AGENTS.md` important-files list now points at `JournalEntry`, `Schema` and `JournalStore`.

## Day boundary

`JournalEntry.day` is currently the calendar start of day. Step 3 adds `reflectionDay(for:)` (the 3am rule). Callers will then pass reflection days into `JournalStore`; the store itself doesn't need to change.

## Verification

- `xcodegen generate`; build and test on the iPhone 17 simulator: **19 tests passed, 0 failures, no warnings**.
  - New `JournalStoreTests` (8): schema contents and version; create with copies; re-save replaces text and keeps copies and `createdAt`; blank deletes; blank with no entry does nothing; missed day refused; past entry editable; entries by passage match by ID, oldest first.
  - `PatternEngineTests` (8) and `StoneTagTests` (3) unchanged.
- The app was reinstalled and launched in the simulator. The simulator is still open.

## Not verified

- **No screenshots of the changed screens.** A fresh store always opens on the welcome screen (see the onboarding bug in the step 1 notes). This terminal has no macOS Accessibility permission, so neither `osascript` nor `cliclick` can tap past it. To let a later session drive the simulator, grant Accessibility to the terminal app in System Settings → Privacy & Security → Accessibility.
- Not tested by hand: saving, editing or deleting from the detail view, and the Review entry card. No UI writes entries until step 5, so these paths only get real data then.
