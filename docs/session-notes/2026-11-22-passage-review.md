# Passage review page for the full set (22 Nov 2026)

Trello: [Task] Dhamma Diary: PJ completes the passage set after the opening 13 (https://trello.com/c/AsxEdLVA).

## What changed

- **`scripts/passages/review/`** (new): a local web page for choosing the rest of the passage set, like the prototype review page from 8 Nov.
  - `build_candidates.py <bilara-data> [<vault>]` scans PJ's main Obsidian vault (Dropbox, "PJTeh Obsidian Vault") for SuttaCentral links and references such as "SN 56.11" (capitalised only; ranges like "SN 48.45-47" expand). It keeps those with a Sujato translation: **159 suttas**, including the 13 in the app. For each one it stores the full text by segment, the notes that mention it with their lines, and which segments look quoted in those notes (94 suttas have some). Output `candidates.json` is git-ignored because it quotes private notes.
  - `server.py [port]` serves the page on 127.0.0.1:8765 only. Choices save as you go to `selections.json` (previous version kept as `.bak`). The first run seeds it from `passages-source.json`, so the shipped 13 start as "In the set" in their order.
  - `index.html`: sutta list (filters: to look at, in the set, maybe, skipped; search by ref, title or note name), the full sutta with quoted lines marked ✎, click-first-then-last to pick passage ranges (several parts allowed) and the widget excerpt, "Selected words → highlight", question, passage ID (locked for shipped passages), a private note, a phone-style preview with word/character guides, and the vault lines. The Sequence tab orders the set (drag, arrows, or type a position) and flags anything not ready.
  - `export_source.py <bilara-data> [--check]` runs every included passage through the app's generator and writes `passages-source.json` only if all pass (AN 10.51 first, unique IDs, excerpt inside a range, verbatim highlight, a question). Then run `build_passages.py` as before.
- **`build_passages.py`**: ranges now select segments by file order between two exact segment IDs. The old comparison used only the first two numbers, which mis-selects in 17 candidate suttas with three-level IDs (MN 10, DN 16, …), IDs like `mn19:4-5.1`, and Dhammapada files that hold several verses (`dhp101:1`). The 13 shipped ranges all name exact segments, and regenerating gives identical passage text (only the bilara-data commit hash would change, so `passages.json` was left as committed).
- `.gitignore`: candidates.json, selections backups, `__pycache__`.
- AGENTS.md: points to the review folder.

## How PJ uses it

```bash
python3 -I scripts/passages/review/build_candidates.py <bilara-data>   # again whenever the vault changes
python3 -I scripts/passages/review/server.py                           # open http://127.0.0.1:8765
python3 -I scripts/passages/review/export_source.py <bilara-data>      # when the set is done
python3 -I scripts/passages/build_passages.py <bilara-data>
```

The bilara-data checkout used this session is in the session scratchpad and may be cleared; the clone command is at the top of `build_passages.py`.

## Verification

- Round trip: exporting the seeded 13 rewrites `passages-source.json` byte-for-byte unchanged.
- Headless Chrome (puppeteer-core, scratchpad only): picked a range, excerpt, highlight and question for SN 22.59, marked it In the set, and checked `selections.json`; `export_source.py --check` passed it. A broken entry (excerpt outside its range, AN 10.51 not first) was refused. The test entry was then removed; `selections.json` holds only the 13.
- Screenshots: [the passage in the set](../session-artifacts/2026-11-22-passage-review-01.png), [picking SN 22.59 (test entry)](../session-artifacts/2026-11-22-passage-review-02.png), [Sequence](../session-artifacts/2026-11-22-passage-review-03.png).
- Not done: the iOS app itself is unchanged, so no simulator run or Xcode tests. Claude in Chrome wasn't connected, so the page was checked headless rather than in PJ's browser.

## Known limits

- One passage per sutta.
- The export reports the first problem per passage, not all of them.
- Apple Notes and other vaults weren't scanned.
