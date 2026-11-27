# Daily Review (28 Nov 2026)

From the Trello card "Dhamma Diary: Daily Review (stones dropped into your hand, then the day so far)". Built on branch `daily-review`. Spec: section 10 of `docs/spec/v1.md`.

## What it does

- **Review › Daily Review** (in the stats line, above "This week"; on Sundays it stays there on its own) opens a screen for the current reflection day.
- **The stones fall** one by one in logging order: white from the top-left corner into the left heap, black from the top-right into the right heap, with an invisible full-height wall between (PJ asked for two piles mid-build after one mixed heap of 40 looked a mess).
- **Composite stones** (PJ, mid-build): a landed stone leaves gravity and is drawn towards its heap's centre with an oval pull, so each heap gathers into the outline of one large stone made of pebbles, sized to the count.
- **Sound and haptics** per contact, scaled by impact: a soft tap for the first stone onto each empty palm, a heavier, duller thud onto the pile, a light clack between stones afterwards. Core Haptics transient taps; sounds in the `.ambient` session.
- **Then the day so far** fades in: "n white · n black", the mind chart and summary line (or "No mind check-ins yet today."), and today's diary entry with its passage (or "No diary entry yet.").
- Zero stones: no animation. Tap during the fall: the rest drop silently and the summary shows. Reduce Motion: stones are placed in their ovals, gather out of sight and fade in, silently. Big days: drops speed up so the fall stays about 4 seconds; stones shrink so each heap fits its half.

## Files

- `DhammaDiary/Utilities/DailyReview.swift`: the day's stones (in order), check-ins and entry for a reflection day; drop timing.
- `DhammaDiary/Views/Review/DailyReviewView.swift`: the screen.
- `DhammaDiary/Views/Review/StoneDropScene.swift`: SpriteKit physics, the two hollows and wall, the oval gathering, contact sounds.
- `DhammaDiary/Views/Review/StoneDropFeedback.swift`: sounds and haptics.
- `scripts/sounds/make_stone_sounds.py` → `DhammaDiary/Resources/Sounds/stone-{palm,pile,clack}.wav`: synthesised from sine partials and filtered noise with a fixed seed, so there is no third-party audio or licence. Change the script, not the WAVs.
- `ReviewView.swift`: the link, and a DEBUG `-debug.openDailyReview YES`. `-debug.dropCount N` (DEBUG) drops N stones instead of the day's; `-debug.logContacts YES` prints contact strengths.
- Tests: `DhammaDiaryTests/DailyReviewTests.swift` (order and the 3am boundary for stones, check-ins and entry; drop timing). All tests pass.

## Screenshots

12, 40 and 70 stones after settling:

![Composite heaps at 12, 40 and 70 stones](../session-artifacts/2026-11-28-daily-review-01.png)

40 stones with the day so far, and mid-fall:

![Daily Review, 40 stones](../session-artifacts/2026-11-28-daily-review-02.png)
![Falling](../session-artifacts/2026-11-28-daily-review-03-falling.png)

## Not verified

- **Sound and haptics:** not heard or felt. The simulator has no haptics, and the sounds were only checked to be in the app. The loudness and haptic scaling (impact strength / 700) came from logged contact strengths, not from listening.
- **Tap to skip:** the simulator can't be tapped from here.
- **On a phone:** the fall's feel, how fast stones gather, and how the composite looks on a smaller screen.
- With Reduce Motion, one run of 20 had a single white stone at the edge when the screenshot was taken; it may still have been gathering.
- Not merged into `main`, pushed or uploaded.
