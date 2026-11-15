# 2026-11-15: The 3am reflection day (build step 3)

Spec: `docs/spec/v1.md` §3.1 and §7 step 3. Branch: `build/v1`.

## What changed

**`DateHelpers`** (all take an optional `calendar`, default `.current`):
- `reflectionDay(for:)`: the calendar date an instant belongs to.
- `reflectionDayStart(ofDay:)`: 03:00 local time on a calendar date.
- `reflectionDayInterval(for:)` takes an instant. `reflectionDayInterval(forDay:)` takes a calendar date: a calendar cell, a chart day or `JournalEntry.day`.
- `reflectionInterval(fromDay:days:)` and `reflectionMonthInterval(for:)`.
- `reflectionDayKey(for:)` and `dayKey(forDay:calendar:)`. The latter is built from date components, so tests can use any time zone.
- `currentReflectionDay`. `todayKey` and `dayKeysForPastWeeks` now use it.

**Spec deviation, recorded in §3.1:** `reflectionDay(for:)` compares against 03:00 local on the same date. It does not subtract three hours. `Calendar.date(byAdding: .hour, value: -3)` subtracts elapsed time, so on a spring-forward morning 03:30 would land on the previous day. A test covers this.

The two kinds of day value never mix:
- instants (stone timestamps, `.now`) go through `reflectionDay(for:)`;
- calendar dates (calendar cells, chart days, `JournalEntry.day`) go through `…(forDay:)`.

Passing a midnight calendar date to `reflectionDay(for:)` would wrongly give the day before. That's why the `forDay` variants exist.

**Switched to reflection days:**
- `Stone.dayKey`.
- **Today:** the stone list and balance, plus the date shown. A `.task` moves Today to the next day at 03:00 while the screen is open. Before, it only reacted to `NSCalendarDayChanged`, which fires at midnight.
- **Review:**
  - calendar ratios and the month fetch (03:00 on the 1st to 03:00 on the next 1st);
  - selected-day stones;
  - 14-day bars and the selected bar's stones;
  - all-time chart month grouping;
  - "total days" and the streak, which now counts back from the current reflection day;
  - the "Today" button and chart limits.
- `PatternEngine`: the 14-day window, day keys and "days since last entry".
- The Diary placeholder's date.

`JournalEntry` and `JournalStore` needed no change. They already take a calendar date; step 5 will pass `currentReflectionDay`.

**Pre-existing bug fixed:** `Stone.timestamp` had a `didSet` to keep `dayKey` in sync. It never ran, because `@Model` turns stored properties into computed ones, so editing a stone's time left `dayKey` stale. The new `Stone.setTimestamp(_:)` updates both. `timestamp` is now `private(set)`, and `StoneDetailView` uses the new method. The new `testStoneDayKeyUsesReflectionDay` caught it.

## Verification

- Build and tests on iPhone 17: **33 passed, 0 failures, no warnings**.
- New `ReflectionDayTests` (14), all using `America/New_York`:
  - 02:59 belongs to the previous day; 03:00 and midnight behave as expected;
  - a stone at 01:00 on the 15th is in the 14th's interval, with dayKey 14th;
  - the spring-forward day is 23h and the fall-back day 25h;
  - 03:30 on spring-forward morning is the new day;
  - both 01:30s on fall-back morning belong to the previous day;
  - the month interval runs 03:00 to 03:00;
  - two PatternEngine cases: late-night stones group with the previous evening, and tonight counts before 03:00.
- Reinstalled in the simulator; Today still shows PJ's 3:01 PM stone under 15 November. [Screenshot](../session-artifacts/2026-11-15-reflection-day-01-today.png)

## Not verified

- The spec's hand check "at 02:30, Today and Diary still show the previous day" needs the clock set to 02:30. The unit tests cover the logic; the screen check stays on the build card's item 9.
- The 03:00 rollover `.task` on Today hasn't been watched live.
- Stones saved before this step keep their old midnight-based `dayKey`. Only simulator data is affected, since nothing has been released. No view groups by the stored `dayKey`.
