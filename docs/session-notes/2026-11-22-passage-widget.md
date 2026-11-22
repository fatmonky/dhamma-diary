# Passage widget (22 Nov 2026)

PJ asked for a widget that shows a short excerpt of tonight's sutta passage, not just the question. Spec 8.6.

## What changed

- **Excerpts:** each passage in `scripts/passages/passages-source.json` now names an `excerpt` range: the heart of the passage, usually its simile, about 200 characters.
- **Generator:** `build_passages.py` checks that the excerpt lies inside the passage's ranges and copies the text verbatim, using the same quote rule as the passage. `passages.json` was regenerated against the same bilara-data commit (`baa73bb`). Nothing else in the file changed; I checked this by comparing the old and new files.
- **App:** `Passage.excerpt: [String]`. A new test checks that every excerpt is non-empty, at most 340 characters, and taken from its passage.
- **Widget:** `DhammaDiaryWidget/PassageWidget.swift`, "Tonight's passage", in two sizes:
  - **Medium:** the reference above the excerpt.
  - **Large:** the excerpt, then the question.

## The excerpts

| Passage | Excerpt |
|---|---|
| AN 10.51 | The mirror simile ("Suppose there was a woman or man…") |
| MN 19 | "Whatever a mendicant frequently thinks about…" |
| MN 20 | The finer peg |
| AN 5.162 | The rag by the road |
| MN 54 | The dog and the skeleton (15.1–15.2) |
| AN 10.61 | The rain filling the ocean. The longest, at 326 characters; the medium widget cuts it off with "…" |
| AN 10.44 | The five "I will speak…" lines |
| AN 4.14 | "When a mendicant sees a sight…" |
| MN 21 | The saw |
| AN 4.18 | The verse about the waxing moon |
| MN 61 | "After you have acted with the body…" (11.1–11.3) |
| SN 46.55 | The dyed water |
| SN 47.6 | "Don't roam out of your own territory…" |

## Verification

- Build and all 97 tests pass.
- A widget can't be added to the simulator's Home Screen from the command line, so the layout was rendered for all 13 passages with a throwaway test, deleted afterwards:
  - [Medium](../session-artifacts/2026-11-22-passage-widget-01-medium.png)
  - [Large](../session-artifacts/2026-11-22-passage-widget-02-large.png)
  - [Medium, longest excerpt](../session-artifacts/2026-11-22-passage-widget-03-medium-longest.png)
- Still to do on the phone: add it (long-press the Home Screen → Edit → Add Widget → Dhamma Diary → Tonight's passage).
