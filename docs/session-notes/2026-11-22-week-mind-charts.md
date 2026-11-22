# Mind charts in This week; Today spacing

PJ marked up two screenshots:

- Today: "Add a bit more space here between the instructions vs. the count/mind noise chart; this should be closer to 'today's stones' below."
- This week: "Can we add the day's mind noise chart here, in the same style as Today screen? The stone count can be above this."

## What changed

- `TodayView`: the counts and chart now have 28pt above them (was 10) and 16pt below (was 40).
- `MindSparkline(day:size:)` takes a size. Below 200pt wide, `MindSparklineChart` is compact: three hour labels (8am, 2pm, 8pm; "8a 2p 8p" in 12-hour time, "08 14 20" in 24-hour) instead of one every four hours.
- `WeekLookBackView.DayRow`: the weekday, passage reference and first line on the left, and on the right the stone counts with the day's chart (128 × 56pt) under them, then the chevron. The passage reference is held to one line so the chart doesn't wrap it.
- Spec 9.6 (Today's mind line, spacing) and 8.x This week (mind line per day).

## Screenshots

- This week with charts: [01](../session-artifacts/2026-11-22-week-mind-charts-01.png). The Saturday vertical line is two test check-ins a minute apart.

## Verification

- Build and all 100 tests pass; This week checked in the "DD Onboarding" simulator.
- Today's new spacing wasn't seen in place: the chart is below the fold and the simulator can't be scrolled from here.
- Not checked on a phone.
