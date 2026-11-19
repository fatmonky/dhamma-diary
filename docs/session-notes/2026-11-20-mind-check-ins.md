# Mind check-ins (spec section 9)

PJ asked for a second interaction beside the stones: a few times a day, the phone asks "How noisy is your mind now?", you slide between noisy and still, and at the end of the day a chart shows how the mind was. PJ's choices: 3 a day between 9am and 9pm; a smooth 0–100 slider with words only; ask during onboarding; the chart on a new tab plus a line on Tonight.

## What changed

- **Spec section 9** written first; section 1's "no notifications" now makes this one exception.
- **Model:** `MindCheck` (`timestamp`, reflection-day `dayKey`, `noise` 0 = still … 100 = noisy, `prompted`). `SchemaV2` adds it, with a lightweight V1 → V2 stage.
- **Mind tab** (`Views/Mind/MindView.swift`), between Diary and About: the question in serif, a tall vertical slider (Noisy at the top, Still at the bottom, a word such as "Fairly still" beside it, no numbers), Record. The check-in sits outside the scrolling list, so dragging the slider can't scroll the page. Below: today's chart (points across the day, y axis only "Still" and "Noisy"), the summary line, today's check-ins (swipe to delete) and the on/off control.
- **Summary line** (`MindDaySummary`): "3 check-ins today. Stillest at 2:10 PM, noisiest at 9:40 AM." Also on Tonight, under the stones, as a link to the Mind tab.
- **Notifications** (`MindCheckSchedule`, `MindCheckNotifications`): one at a random minute in each of 9–13, 13–17, 17–21, at least an hour apart. The next 7 days are kept scheduled and topped up whenever the app becomes active. The identifier comes from the time, so scheduling twice never doubles up. Tapping a notification opens the Mind tab (`AppDelegate` → `MindCheckRouter` → ContentView), also from a cold launch.
- **Onboarding:** new step `mindInvite` after the Diary tour, a sheet with "Turn On Check-ins" / "Not Now". The Mind tab always has "Start check-ins" / "Stop check-ins", and "Open Settings" if iOS notifications are off.
- **Privacy policy** and **AGENTS.md** updated.

## Data-safety fix found on the way

On PJ's simulator the V2 migration landed in a store inside the **App Group container**, not the app's own one. Since the widget commit (9f88d59) added the App Group, SwiftData's default configuration (`groupContainer: .automatic`) has been opening its store there. A phone updated from a pre-widget build would have opened an empty store and looked as if everything was gone.

The fix: `DhammaDiaryStore` opens an explicit URL in the app's own container, and `settleStoreLocation()` runs once before that. It moves a group-container store across; a store with no records never wins over one with records; when both have records the more recently written one wins. The other copy is renamed `default-before-<time>.store`, never deleted. Five tests use fake files; one uses real SwiftData stores (an empty, newer group store vs. older data).

On PJ's simulator both stores held the same 2 stones and 1 entry; the app's own store was kept, migrated to V2, and the group copy was renamed to `default-before-20261120-072840.store`.

## Tests

85/85 pass (was 66). New: schedule (500 seeds: windows, gaps, same day), plan (first week skips passed times; top-up adds only new days), summary text, reflection-day fetch, noise clamping, V1 → V2 migration on an on-disk store, store location (6), onboarding `mindInvite` preserved.

## Screenshots

- Mind tab, no check-ins yet: [2026-11-20-mind-01-empty.png](../session-artifacts/2026-11-20-mind-01-empty.png)
- Mind tab with three check-ins (throwaway simulator, `-debug.seedMind YES`): [2026-11-20-mind-02-chart.png](../session-artifacts/2026-11-20-mind-02-chart.png)
- Tonight's mind line: [2026-11-20-mind-03-tonight-line.png](../session-artifacts/2026-11-20-mind-03-tonight-line.png)
- Onboarding invite: [2026-11-20-mind-04-onboarding-invite.png](../session-artifacts/2026-11-20-mind-04-onboarding-invite.png)
- Today on PJ's simulator after the upgrade: [2026-11-20-mind-00-today-after-upgrade.png](../session-artifacts/2026-11-20-mind-00-today-after-upgrade.png)

## Not verified

- Dragging the slider and tapping Record, Start/Stop, and the invite buttons: the simulator can't be tapped from here.
- The permission prompt, notifications arriving, and tapping one to open the Mind tab. Needs a phone.
- The store move on a real phone with pre-widget data. Covered by tests, not run on a device.
