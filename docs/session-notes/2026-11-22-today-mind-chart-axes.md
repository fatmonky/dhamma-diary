# Today's mind line gets axes

PJ marked up a Today screenshot: "The chart needs a y and x axis so the user can visually reference whether the chart is good or bad."

## What changed

- `MindSparkline` (`DhammaDiary/Views/Mind/MindReviewSection.swift`) was a bare Canvas line, 200 × 30pt. It's now a small Swift Charts chart, 280 × 90pt:
  - y axis: "Noisy" at the top and "Still" at the bottom as labelled grid lines, and a dashed, unlabelled midline for in between;
  - x axis: hours every four hours, over the same 7am–11pm span as Review's chart (`MindDayChart.domain`);
  - the line stays the brown, 2pt, with no dots; a single check-in shows one dot.
- The drawing is split into `MindSparklineChart(checks:day:)` so it can be rendered without a SwiftData query.
- Spec 9.6 ("Today's mind line") has a note on the axes.

## Screenshots

Rendered on their own with seeded check-ins:

- Many check-ins: [01](../session-artifacts/2026-11-22-today-mind-chart-axes-01.png)
- One check-in: [02](../session-artifacts/2026-11-22-today-mind-chart-axes-02.png)

## Verification

- Build and all 100 tests pass.
- The app runs in the "DD Onboarding" simulator with seeded check-ins. The chart sits below the fold on Today, and the simulator can't be scrolled from here, so the in-place screenshot shows it only partly; the layouts above were rendered with ImageRenderer.
- Not checked on a phone.
