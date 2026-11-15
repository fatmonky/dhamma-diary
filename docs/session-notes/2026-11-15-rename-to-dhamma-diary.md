# 2026-11-15: Rename WhiteStone → DhammaDiary (build step 1)

Spec: `docs/spec/v1.md` §2 ("First build step") and §7 step 1. Branch: `build/v1`.

## What changed

- `project.yml`: project name, app target `DhammaDiary`, test target `DhammaDiaryTests`, scheme, sources, `DEVELOPMENT_ASSET_PATHS`.
- Bundle IDs: `com.whitestone.DhammaDiary` and `com.whitestone.DhammaDiaryTests`.
- `INFOPLIST_KEY_CFBundleDisplayName`: `Dhamma Diary`.
- Folders: `WhiteStone/` → `DhammaDiary/`, `WhiteStoneTests/` → `DhammaDiaryTests/` (`git mv`, history kept).
- `WhiteStoneApp` → `DhammaDiaryApp` (file and struct).
- Tests: `@testable import DhammaDiary`.
- `SplashView` and Today's toolbar title: "Dhamma Diary".
- Feedback email subject (About): "Dhamma Diary Feedback".
- `fastlane/Appfile` `app_identifier`; `fastlane/Fastfile` project, scheme and ipa names, which the release lanes need.
- Logger subsystem in `ModelContextHelpers` changed to `com.whitestone.DhammaDiary`, to match the bundle ID.
- `AGENTS.md`: intro, file paths and build commands.

Left alone, as the spec says or because a later step covers it:
- "White Stone" / "Black Stone" stone-type labels in `AddStoneSheet` and `StoneDetailView`.
- About body copy (step 7), the splash tagline "tracker of mental action" (not in the step 1 list), `WhiteStoneLogo` image set and app icon (step 8).
- `README.md` and `DEVELOPMENT.md` still describe White Stone. They are inherited history and are not in the step 1 list.

## Verification

- `xcodegen generate`: OK, creates `DhammaDiary.xcodeproj` (the old `WhiteStone.xcodeproj` was deleted; it is gitignored and generated).
- `xcodebuild … -scheme DhammaDiary -destination 'platform=iOS Simulator,name=iPhone 17' test`: **12 tests passed, 0 failures**.
- Installed and ran on the iPhone 17 simulator as `com.whitestone.DhammaDiary`. It installs next to White Stone and doesn't overwrite it.

Screenshots:
- [Splash](../session-artifacts/2026-11-15-rename-01-splash.png): "Dhamma Diary".
- [First-launch welcome](../session-artifacts/2026-11-15-rename-02-welcome.png): unchanged White Stone onboarding copy (step 7 rewrites it).

## Not verified

- **No screenshot of Today's toolbar title.** On a store with no stones, the welcome sheet covers Today, and there was no tap automation in this session. The change is the single `Text("Dhamma Diary")` in `TodayView`.

## Found along the way (not fixed)

- `ContentView.bootstrapOnboardingState()` resets `onboarding.step` from `completed` to `welcome` whenever there are no stones. That breaks the `AGENTS.md` rule "Completed onboarding must not restart if the user later deletes all stones". This is inherited from White Stone. Step 7 (onboarding) is the natural place to fix it.
