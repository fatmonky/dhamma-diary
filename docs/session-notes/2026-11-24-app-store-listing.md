# App Store listing: metadata and screenshots

PJ: "push and upload build 6. can you also upload all the screenshots and metadata for the app store connect profile of the app?"

## Done

- `main` pushed (86b0b63); TestFlight build 6 uploaded (6a5459c).
- App Store Connect, version 1.0 (was empty apart from the name):
  - name "Dhamma Diary", subtitle "Daily sutta reflection journal" (spec 6)
  - description: spec 6's draft, updated for mind check-ins, widgets, Siri, the Sunday look-back and the dark theme
  - keywords, promotional text, copyright "2026 PJ Teh"
  - categories Lifestyle and Health & Fitness (spec 6)
  - privacy URL `https://inquivision.com/apps/dhamma-diary/privacy/`, support URL `https://inquivision.com/apps/dhamma-diary/support/`
  - five 6.9-inch screenshots: Diary, Today, mind check-in, Review, journal entry ([contact sheet](../session-artifacts/2026-11-24-app-store-listing-01.png))
- The listing is in `fastlane/metadata/`; upload it with `bundle exec fastlane ios listing` (ASC_KEY_PATH set). Screenshots go in `fastlane/screenshots/en-US/` (gitignored); the lane stops if there are none, so it can't wipe the uploaded ones.
- Screenshot data: `DhammaDiary/Utilities/DemoData.swift` (DEBUG only). On an empty 6.9-inch simulator, launch with `-debug.demoData YES -onboarding.step completed` for two weeks of invented stones, check-ins and entries, with tonight back on AN 10.51. Then `-debug.selectedTab`, `-debug.openWeek`, `-debug.openEntry` and `-debug.mindSlide` reach each screen. Simulator: "DD Screens" (iPhone 17 Pro Max, iOS 26.2).
- `docs/privacy-policy.md`: Siri and the widgets.
- Blog repo (not committed or pushed): `content/en/dhamma-diary-privacy.md` and `content/en/dhamma-diary-support.md`, at the URLs above. They build with Hugo.

## Not done (App Store Connect needs these before submission)

- Publish the privacy and support pages (push the blog repo). Until then both URLs are 404.
- App Privacy: "Data Not Collected". Fastlane can't set this with the API key; set it in App Store Connect.
- Age rating questionnaire, App Review contact details, and the build to attach to 1.0.
- No This week screenshot: on a Tuesday the demo week has only two days.

## iPhone only (build 7)

Adding the version for review failed: "You must upload a screenshot for 13-inch iPad displays." The app had been built for iPad as well, because `project.yml` never set a device family and XcodeGen's default is iPhone and iPad. The spec says iPhone only, so PJ chose to make it iPhone only rather than add iPad screenshots.

- `project.yml`: `TARGETED_DEVICE_FAMILY: "1"` on the app, widget and test targets (a project-level setting is overridden by XcodeGen's per-target default); the iPad orientations line is gone.
- Build 7 uploaded; its Info.plist has `UIDeviceFamily` = [1].
- PJ: select build 7 for version 1.0. The iPad screenshot requirement should then go away. PJ is setting Content Rights.
