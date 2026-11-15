# Onboarding: completed stays completed (v1 build step 7)

Spec: `docs/spec/v1.md` §4.4, §4.5. The About and onboarding wording was done in the text pass (`6309b45`), approved by PJ.

## What changed

- **Restart bug fixed (PJ's decision: completed stays completed).** `ContentView.bootstrapOnboardingState()` reset `completed` to `welcome` whenever there were no stones, so deleting every stone restarted onboarding. The rule now lives in `OnboardingStep.bootstrapped(from:hasStones:showingPostFirstEntry:)`:
  - completed stays completed, stones or not;
  - a fresh install with no stones starts at welcome;
  - an existing user with stones skips onboarding;
  - `firstLog`, `reviewTour` and `diaryTour` are preserved mid-flow.
- `OnboardingStep` moved out of `ContentView` (it was private) so it can be tested.
- The Diary tour overlay now also disables the "Passages" toolbar button, which sat outside the overlay and stayed tappable (AGENTS.md: tour overlays block the content underneath).

## Tests

58/58 pass. New: `OnboardingTests` (6), including "completed doesn't restart after all stones are deleted".

## Screenshots

Taken on a separate, freshly created iPhone 17 simulator (deleted afterwards), so PJ's simulator data was untouched. The first is a real fresh install; the others were opened by launching with `-onboarding.step <step>`.

- [Welcome](../session-artifacts/2026-11-15-onboarding-01-welcome.png)
- [Today coach](../session-artifacts/2026-11-15-onboarding-02-today-coach.png)
- [Review tour](../session-artifacts/2026-11-15-onboarding-03-review-tour.png)
- [Diary tour](../session-artifacts/2026-11-15-onboarding-04-diary-tour.png): over tonight's passage, which on a fresh install is passage 1, AN 10.51.

## Not verified

No tapping is possible from here, so the transitions between steps weren't walked by hand: Start Tour, the coach's Next, holding to log the first stone, the after-first-stone message, Continue to Diary, Finish Tour, and Skip at each point. Nor was "delete every stone, then relaunch" tried on screen; the unit test covers the rule.
