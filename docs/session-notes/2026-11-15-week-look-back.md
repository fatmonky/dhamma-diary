# The week's look-back (spec 8.3; build step 10)

## What changed

- `Utilities/WeekLookBack.swift`: the week (Monday to Sunday in reflection days, containing the current day), with per-day white/black counts and entry, the week's totals, and roots by frequency (ties keep first-seen order). Stones are fetched by reflection-day interval and grouped by their timestamp's reflection day; entries by calendar date.
- `Views/Week/WeekLookBackView.swift`, titled "This week": the date range ("9–15 November"), "2 white · 0 black" and the roots, then one row per day from Monday to today. A row shows the day, its stone counts if any, and, if there's an entry, the passage reference and title and the entry's first line. Tapping an entry opens it. Days with nothing are just their name.
- **Links:** on Sundays, "Look back on this week ›" below Save on Tonight; in Review, "This week ›" under the stats line, any day.
- DEBUG-only `-debug.openWeek YES` (with `-debug.selectedTab 1`) opens the page for screenshots.

## Tests

64/64 pass. New `WeekLookBackTests` (4): Monday of the week and Sunday check; days run Monday to today; a 01:00 stone counts for the previous day and last week's stones are excluded; roots by frequency; the range text within and across months.

## Screenshots

- [Sunday link on Tonight](../session-artifacts/2026-11-15-week-01-sunday-link.png)
- [This week](../session-artifacts/2026-11-15-week-02-this-week.png): PJ's two white stones and test entry on Sunday
- [Review's "This week" link](../session-artifacts/2026-11-15-week-03-review-link.png)

## Not verified

Tapping the links and an entry row (no tap automation here). A week that crosses a month boundary was checked in tests only.
