# Mind check-ins folded into Today (spec 9.6)

Branch `mind-on-today`, from `main` after `build/v1` was merged into it (fast-forward to 5bf9c46). PJ used the Mind tab for a day on the phone, then marked up five screenshots in red.

## PJ's notes, and what changed

| PJ's note | Change |
|---|---|
| AN 10.61's question is wrong: the passage is about what fills you up ("the factor of faith … rational application of mind …"), not who you spent time with | Reworded in `passages-source.json` and regenerated against the same bilara-data commit (baa73bb). Only the question changed in `passages.json`. |
| Mind slider: try a small white stone slid up and down; centre it; fold it into Today instead of a Mind tab | The Today stone is the slider. Mind tab removed. |
| Today: long-press and slide up → whole-screen noisy particles and "Noisy Mind" (≤ 50% opaque); slide down → particles fade, "Still" appears; stone moves a little and returns; subtle up/down arrows; a hint line | `stoneGesture` in `TodayView` (hold 0.2s, then slide; 0.8s still still logs a stone; quick swipes still flip). `NoiseBackdrop` draws the particles. The rest of Today fades back while sliding so the words read clearly. Release records, with a few seconds of "Noted at …: … Undo". |
| Move the counts down and put the outline of the noisy–still chart next to them | Counts sit under the hint lines, with `MindSparkline` beside them; tapping it opens Review. |
| The chart and the list go to Review, near the top, above Daily Stones | `MindReviewSection` at the top of Review: chart, summary, list (touch and hold to delete), reminders switch. |
| Tonight's mind line doesn't fit | Removed. |

Also: notifications now open Today; the onboarding invite describes the stone and Review; the privacy policy points to Review for stopping reminders. The old vertical-swipe flip animation on the stone is gone (vertical slides are now check-ins).

## Tests

86/86 pass. New: the slide mapping (`MindDaySummary.noise(forSlide:range:)`).

## Screenshots (throwaway simulator; `-debug.mindSlide` freezes a slide, `-debug.seedMind` adds three check-ins)

- Today at rest, dark: [01](../session-artifacts/2026-11-20-today-mind-01-today.png)
- Sliding to noisy, dark: [02](../session-artifacts/2026-11-20-today-mind-02-noisy.png); light: [07](../session-artifacts/2026-11-20-today-mind-07-noisy-light.png)
- In between: [03](../session-artifacts/2026-11-20-today-mind-03-middle.png)
- Sliding to still: [04](../session-artifacts/2026-11-20-today-mind-04-still.png)
- Review, "Mind today": [05](../session-artifacts/2026-11-20-today-mind-05-review.png)
- Tonight without the mind line: [06](../session-artifacts/2026-11-20-today-mind-06-tonight.png)

## Not verified

- The gesture by touch: hold-then-slide vs. hold-to-log vs. swipe-to-flip, and that the page doesn't scroll while sliding. The screenshots use a frozen slide. This needs PJ's phone.
- The particle animation's smoothness on a device.
- Haptics.

## Round 2: PJ's notes from an evening's use (spec 9.7)

- Upward flick on the stone didn't scroll Today: the flip `DragGesture` was attached with `.exclusively`, which claimed vertical drags. It's now a `simultaneousGesture` that only flips on a clearly sideways swipe, and ignores the end of a press.
- The stone barely moved (±44pt). It now follows the finger one to one: up to the date line (27% of screen height) for fully noisy, down over the counts (14%) for fully still. The words moved into the space the stone leaves, and the up/down arrows hide while sliding.
- Haptics: `NoiseHaptics` plays a continuous Core Haptics buzz whose intensity follows the slide (0.45 at noisy → 0 at still).
- Review chart: pinch to zoom the time axis, drag sideways once zoomed, double-tap to reset.

Screenshots: [08 noisy, full travel](../session-artifacts/2026-11-20-today-mind-08-noisy-travel.png), [09 still, full travel](../session-artifacts/2026-11-20-today-mind-09-still-travel.png), [10 Review with the zoom hint](../session-artifacts/2026-11-20-today-mind-10-review-zoom-hint.png).

Tests: 87/87 (new: asymmetric slide mapping, buzz intensity).

Not verified (needs a phone): the flick scrolls while a held press doesn't; the buzz (simulators have no haptics); pinch and drag on the chart.
