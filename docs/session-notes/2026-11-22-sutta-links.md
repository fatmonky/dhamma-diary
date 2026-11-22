# Sutta links and excerpts in past entries (22 Nov 2026)

PJ marked up three phone screenshots. Spec 8.7.

1. **Tonight:** "Look back on this week" sat tight against the floating tab bar. There is now 32pt of space below it.
2. **This week:** the "AN 10.61 · Ignorance" line on each day is now a link (accent colour, ↗) to the sutta on SuttaCentral.
   - The rows were NavigationLinks, which would swallow taps on the link. Each row now opens its entry with a tap gesture and `navigationDestination(item:)`, with its own chevron.
3. **Journal entry:** the reference line is the same link, and the passage's excerpt (from the passage widget work) is shown in grey italic serif above the question.

The shared view is `DhammaDiary/Views/Diary/PassageRefLink.swift`. It looks up the URL by `passageID` in the bundled set, and shows plain text if the passage is no longer bundled.

New DEBUG launch arguments:
- `-debug.writeEntry save` saves a long draft.
- `-debug.openEntry YES`, used with `-debug.openWeek YES`, opens the latest entry from This week.

## Verification

- Build and all 97 tests pass.
- Simulator:
  - [This week](../session-artifacts/2026-11-22-sutta-links-01-week.png)
  - [Journal entry](../session-artifacts/2026-11-22-sutta-links-02-entry.png)
  - [Tonight, bottom](../session-artifacts/2026-11-22-sutta-links-03-tonight-bottom.png)
- Not checked: tapping. The simulator can't be tapped from the command line. On the phone, check that the link opens SuttaCentral, and that tapping elsewhere on a row opens the entry.

## Review on Sundays

PJ asked for the week's look-back in Review every Sunday.
- On Sundays (reflection day, so until 3am Monday), Review opens with a "Look back on this week" card above Mind today. It goes to the same This week screen.
- On those days the small "This week" link under the stats is hidden, so the link isn't shown twice.
- [Review on a Sunday](../session-artifacts/2026-11-22-review-sunday-01.png)

## Always dark

PJ: "light mode is too stimulating". `UIUserInterfaceStyle: Dark` was added to the app's Info.plist properties in `project.yml`, and the Info.plist was regenerated, keeping build number 3. Spec 8.8.
- Checked with the simulator set to light mode: the app still shows dark. [Today](../session-artifacts/2026-11-22-always-dark-01.png)
- The widgets are unchanged and still follow the phone.
