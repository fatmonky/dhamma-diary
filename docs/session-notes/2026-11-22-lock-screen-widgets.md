# Lock Screen widgets and the passage's line (22 Nov 2026)

Branch `lock-screen-widgets`. Spec 8.9.

PJ asked why only Tonight's question appeared when adding Lock Screen widgets: it was the only widget with a Lock Screen size. PJ then asked for:
- the mind check-in on the Lock Screen;
- a small Log a stone widget;
- a one-line highlight per passage, for a small widget.

## What changed

- **Mind check-in:** adds `accessoryRectangular`. It shows "Noisy mind?" and the time of today's last check-in, above three outlined buttons (Noisy / Between / Still).
- **Log a stone** (new, `LogStone`):
  - Home Screen small: "Log stone?", the two stones and a "Noted at" line.
  - Lock Screen circular: a ring for white and a filled disc for black, because the Lock Screen draws in one tint.
  - The stone button and "Noted" line are now shared views (`StoneButton`, `NotedLine`) in `CheckInWidget.swift`.
- **Tonight's line** (new, `PassageHighlight`): the highlight on a Home Screen small widget and a Lock Screen rectangular one.
- **Highlights:**
  - Hand-picked in `passages-source.json`. The generator checks that each is verbatim from one segment.
  - `Passage.highlightText` adds "…" where the sentence is cut.
  - New tests check the length, the source and the "…".
  - AN 5.162 was first given a longer line about ignoring impure behaviour and focusing on pure, but it didn't fit the Lock Screen. It is now "…focus on their pure behavior by way of speech."

## The highlights

| Passage | Line |
|---|---|
| AN 10.51 | …checking is very helpful for a mendicant’s skillful qualities. |
| MN 19 | Whatever a mendicant frequently thinks about and considers becomes their heart’s inclination. |
| MN 20 | That mendicant should focus on some other subject connected with the skillful. |
| AN 5.162 | …focus on their pure behavior by way of speech. |
| MN 54 | …sensual pleasures give little gratification and much suffering and distress… |
| AN 10.61 | When the seven awakening factors are fulfilled, they fulfill knowledge and freedom. |
| AN 10.44 | I will speak lovingly, not from secret hate. |
| AN 4.14 | …they don’t get caught up in the features and details. |
| MN 21 | We will remain full of sympathy, with a heart of love and no secret hate. |
| AN 4.18 | Making decisions unprejudiced by favoritism, hostility, stupidity, and cowardice. |
| MN 61 | After you have acted with the body, you should check on that same act… |
| SN 46.55 | …you don’t truly know or see what is good for yourself, good for another, or good for both. |
| SN 47.6 | …don’t roam out of your own territory into the domain of others. |

## Verification

- Build and all 99 tests pass.
- Widgets can't be added to the simulator from the command line, so the layouts were rendered with a throwaway test, deleted afterwards. The Lock Screen ones are approximated as white on a tinted background:
  - [Mind, Lock Screen](../session-artifacts/2026-11-22-lock-screen-01-mind.png)
  - [Stone, Lock Screen](../session-artifacts/2026-11-22-lock-screen-02-stone-circular.png)
  - [Stone, small](../session-artifacts/2026-11-22-lock-screen-03-stone-small.png)
  - [Tonight's line](../session-artifacts/2026-11-22-lock-screen-04-highlight.png)
- Still to check on the phone: the real Lock Screen tint, whether the round widget's two buttons are easy enough to hit, and that the taps log.
