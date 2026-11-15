# Morning question and stone line (spec 8.1, 8.2; build step 9)

PJ chose four "presence without noise" ideas (spec section 8, added this session): 1 widget, 2 morning question, 6 start from stones, 9 Sunday look-back. This note covers 2 and 6.

## What changed

- **Morning question (8.1):** a card at the top of Today, "Carry this through the day" and tonight's question in serif, up to three lines. It shows the entry's stored question if one is written, otherwise the sequence's. Tapping it opens Diary → Tonight.
- **Stone line (8.2):** on Tonight, above the journal box: "You had 2 white stones and 1 black stone today. What was happening?" (PJ's wording). A colour with no stones is left out, singular and plural follow the count, and it's hidden on a day with no stones. Display only.
- Diary navigation from elsewhere is now one environment action, `openDiary(DiaryDestination)`, with `.tonight` and `.passage(id)` (replaces `openPassageInDiary`). The widget will use `.tonight` too.
- DEBUG-only `-debug.scroll bottom` launch argument scrolls Tonight to the editor for screenshots.

## Tests

60/60 pass. New `StonePromptTests` (2).

## Screenshots

- [Today with the morning question](../session-artifacts/2026-11-15-morning-01-today.png)
- [Tonight with the stone line](../session-artifacts/2026-11-15-morning-02-tonight-stone-line.png): also shows PJ's own test entry, so saving works in the simulator.

## Not verified

Tapping the morning card through to Tonight (no tap automation here).
