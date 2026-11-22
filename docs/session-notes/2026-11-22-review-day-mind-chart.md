# Review: the selected day's mind chart

PJ: "can we add the summary chart in the Review tab for each day's mind noise? so at least this is visible with that day's stones."

## What changed

- `ReviewView.selectedDayStonesSection`: `MindSparkline(day: selectedDay)` between the day's stone counts and its "Stones" list, at Today's size (280 × 90pt), centred. It shows for any day picked in the calendar that has check-ins, including days with no stones.
- Spec 9.6 note ("In Review").

## Screenshot

- [01](../session-artifacts/2026-11-22-review-day-mind-chart-01.png): taken from a temporary build with the sections above the calendar hidden, because the simulator can't be scrolled from here. Day 22 has check-ins and no stones, so the chart sits above the journal entry card.

## Verification

- Build and all 100 tests pass.
- Not checked on a phone, or on a day with both stones and check-ins.
