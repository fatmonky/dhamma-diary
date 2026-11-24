# AGENTS.md

## Project

Dhamma Diary is a native iOS app: a daily sutta-reflection journal with optional white and black stones for wholesome and unwholesome thoughts/actions. It is a fork of White Stone. The build spec is `docs/spec/v1.md`. Keep the app quiet, local-first, and contemplative. Do not add analytics, telemetry, badges, achievements, streak milestones, notifications, or gamified copy unless explicitly requested. The one exception PJ asked for is the mind check-in notifications (spec section 9): opt-in, local only, 1–6 a day (three by default). Don't add other notifications.

## Stack

- SwiftUI, iOS 17+
- SwiftData for local storage
- Swift Charts
- XcodeGen via `project.yml`
- No third-party app dependencies
- Fastlane is present for App Store/TestFlight release work

## Important Files

- App entry: `DhammaDiary/App/DhammaDiaryApp.swift`
- Main tabs and onboarding: `DhammaDiary/Views/ContentView.swift`
- Today flow: `DhammaDiary/Views/Today/TodayView.swift`
- Add stone sheet: `DhammaDiary/Views/AddStone/AddStoneSheet.swift`
- Review tab: `DhammaDiary/Views/Review/ReviewView.swift`
- Pattern observations: `DhammaDiary/Utilities/PatternEngine.swift`
- Diary tab (Tonight and Passages, entry detail): `DhammaDiary/Views/Diary/`
- Models: `DhammaDiary/Models/Stone.swift`, `DhammaDiary/Models/JournalEntry.swift`
- SwiftData schema and migration plan: `DhammaDiary/Models/Schema.swift` (add a new `SchemaVn` and a migration stage for any model change)
- Journal entry saving rules: `DhammaDiary/Utilities/JournalStore.swift`
- Passages: `DhammaDiary/Resources/passages.json` (generated, never edit by hand), loaded by `DhammaDiary/Models/Passage.swift`; tonight's passage from `DhammaDiary/Utilities/PassageSequence.swift`
- Passage generator: `scripts/passages/build_passages.py` with input `scripts/passages/passages-source.json`. Add or reword passages in the source file, then regenerate (instructions at the top of the script). Passage IDs are permanent: never reuse or rename one. Ranges name exact segments and select by file order (full IDs like `dhp101:1` in multi-verse files).
- Passage review (choosing the full set from PJ's Obsidian vault): `scripts/passages/review/`. `build_candidates.py` writes `candidates.json` (git-ignored: it quotes private notes), `server.py` serves the review page at http://127.0.0.1:8765 and saves PJ's choices to `selections.json`, and `export_source.py` checks them and writes `passages-source.json`. PJ picks passages; Claude drafts empty questions for PJ to edit.
- Widget (tonight's question, Home and Lock Screen): `DhammaDiaryWidget/TonightWidget.swift`. It compiles `Passage.swift`, `PassageSequence.swift`, `DateHelpers.swift` and `passages.json` from the app, so keep those free of SwiftData and UIKit. The first day lives in the App Group `group.com.whitestone.DhammaDiary` (`PassageSequence.sharedDefaults`).
- Passage widget (spec 8.6, medium and large): `DhammaDiaryWidget/PassageWidget.swift`. It shows each passage's `excerpt`, which is picked by hand in `passages-source.json` and generated like the rest of the passage.
- Tonight's line widget (spec 8.9, small and Lock Screen rectangular) is in `PassageWidget.swift` too, showing `Passage.highlightText`. The Log a stone widget (small and Lock Screen circular) is in `CheckInWidget.swift`.
- Check-in widget (spec 9.8): `DhammaDiaryWidget/CheckInWidget.swift`. It also has a Lock Screen rectangular size. There is no Control Center control (removed 21 Nov 2026). Its buttons run intents in `DhammaDiary/Intents/WidgetIntents.swift`, which append to `WidgetLogQueue` (`DhammaDiary/Utilities/WidgetLogQueue.swift`, App Group defaults); the app imports the queue with `WidgetLogImporter` on launch and on becoming active. The widget can't open the SwiftData store, so never read or write models from widget code.
- Siri phrases (spec 9.11): `DhammaDiary/Intents/VoiceIntents.swift` (App Shortcuts; app target only). Widgets switch to a larger, simpler layout when `levelOfDetail` is simplified (`DhammaDiaryWidget/LevelOfDetail.swift`), an experiment for CarPlay.
- Mind check-ins (spec 9, 9.6): taken on Today by pressing the stone and sliding up/down (`TodayView` `stoneGesture`, backdrop `DhammaDiary/Views/Today/NoiseBackdrop.swift`); shown in Review by `DhammaDiary/Views/Mind/MindReviewSection.swift` (also the chart, sparkline and row views). Model `DhammaDiary/Models/MindCheck.swift`, schedule `DhammaDiary/Utilities/MindCheckSchedule.swift`, notifications `DhammaDiary/Utilities/MindCheckNotifications.swift`, day line and slide mapping `DhammaDiary/Utilities/MindDaySummary.swift`. Notification taps arrive in `DhammaDiary/App/AppDelegate.swift` and open Today. There is no Mind tab.
- SwiftData store location: `DhammaDiaryStore.appStoreURL`, the app's own container. Never use SwiftData's default configuration: with the App Group in the entitlements it would open a different, empty store in the group container. `settleStoreLocation()` moves a group-container store back once.
- Week look-back: `DhammaDiary/Utilities/WeekLookBack.swift`, `DhammaDiary/Views/Week/WeekLookBackView.swift`
- App icon: `scripts/icon/make_icon.py` draws `AppIcon.png`; change the script, not the PNG.
- Privacy policy: `docs/privacy-policy.md` (published on inquivision.com).
- Tests: `DhammaDiaryTests/`

## Build And Test

Regenerate the Xcode project after changing `project.yml`:

```bash
xcodegen generate
```

Build:

```bash
xcodebuild -project DhammaDiary.xcodeproj -scheme DhammaDiary -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Run tests:

```bash
xcodebuild -project DhammaDiary.xcodeproj -scheme DhammaDiary -destination 'platform=iOS Simulator,name=iPhone 17' test
```

If `iPhone 17` is unavailable, list simulators and use the closest available iPhone simulator.

## Implementation Rules

- Follow existing SwiftUI patterns; do not introduce a ViewModel layer unless the change clearly needs it.
- Prefer targeted SwiftData fetches and date intervals over broad full-table filtering.
- Do not rely on stored `dayKey` for view grouping when timestamp intervals are safer.
- Keep `Stone.timestamp` and `dayKey` in sync.
- Keep stone root tags constrained by stone color.
- Keep pattern observations local-only, low-emphasis, and capped.
- Prefer first-party Apple frameworks already used in the repo.

## Onboarding Rules

The current onboarding flow is:

```text
welcome -> todayCoach -> firstLog -> reviewTour -> diaryTour -> mindInvite -> completed
```

Rules:

- Onboarding state is stored in `@AppStorage("onboarding.step")`.
- Fresh users with no stones start at `welcome`.
- Existing users with stones should not see onboarding.
- Completed onboarding must not restart if the user later deletes all stones.
- Preserve mid-flow states: `firstLog`, `reviewTour`, `diaryTour`, `mindInvite`.
- `mindInvite` is a sheet after the Diary tour asking to turn on mind check-in reminders and how many a day. Skipping at any point (welcome, Today coach, first-stone sheet, Review or Diary tour) still leads to `mindInvite`, after any open sheet has closed.
- Sync `reviewTour` to the Review tab and `diaryTour` to the Diary tab.
- Today coach sub-step is local UI state and should reset when re-shown.
- Tour overlays should block underlying content interaction.
- Keep onboarding copy calm and practical.

## UI Tone

- The app is always dark (`UIUserInterfaceStyle: Dark` in `project.yml`, PJ 22 Nov 2026): light mode is too stimulating. Design for dark; light-mode colours are never shown in the app.
- Use the existing white/black/brown visual language. The brown is the robe brown #894E26 (`ColorHelpers.accent`, the `AccentColor` asset); don't add other browns.
- Avoid green/red judgment framing except where already used for system confirmation.
- Avoid flashy celebration language.
- Keep copy plain, reflective, and non-coercive.

## Completion Workflow

After implementing any plan or completing a goal:

- Run the relevant build and tests.
- Run the app in the iOS Simulator.
- Leave the simulator open so the human can inspect the revised app.
- Navigate the simulator to the changed area when practical.
- Capture screenshots of the changed flow or screens and save them under `docs/session-artifacts/` or another clearly named repo-local folder.
- Document the work in a markdown file under `docs/session-notes/`.
- Write a draft blog entry in a markdown file under `docs/blog-drafts/`.
- Include links or relative paths to the screenshots in both markdown files when screenshots are relevant.
- Mention any verification steps that could not be completed.

Suggested filenames:

```text
docs/session-notes/YYYY-MM-DD-short-description.md
docs/blog-drafts/YYYY-MM-DD-short-description.md
docs/session-artifacts/YYYY-MM-DD-short-description-01.png
```

## Release Notes

Fastlane lanes live in `fastlane/Fastfile`.

- `bundle exec fastlane ios upload_only` builds and uploads to TestFlight.
- `bundle exec fastlane ios release` builds, uploads, and submits for review.
- Release lanes require `ASC_KEY_PATH`.

## Git Workflow

Before committing:

```bash
git status --short
git diff --stat
```

Stage only files in scope. If commit signing fails with a 1Password buffer error, retry with:

```bash
git -c commit.gpgsign=false commit -m "message"
```

Only push when explicitly requested.
