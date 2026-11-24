"""Turn the review choices (selections.json) into passages-source.json.

Usage (from the repo root):

    python3 -I scripts/passages/review/export_source.py <bilara-data checkout> [--check]

Takes every sutta marked "In the set", in the Sequence order, and checks each one
with the app's generator (build_passages.py): ranges, excerpt inside a range,
highlight word-for-word, the widget lengths the app's tests allow, a question, unique IDs, AN 10.51 first. Nothing is
written unless every passage passes. With --check it only reports.

Then run build_passages.py as usual to regenerate the app's passages.json.
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(HERE))
import build_passages  # noqa: E402

SELECTIONS = os.path.join(HERE, "selections.json")
CANDIDATES = os.path.join(HERE, "candidates.json")
MAX_EXCERPT = 340    # PassageSetTests.testEveryExcerptIsShortAndFromItsPassage
MAX_HIGHLIGHT = 110  # PassageSetTests.testEveryHighlightIsOneShortLineFromItsPassage


def verse_ref(uid, ranges):
    """For a file holding several verses or suttas (dhp100-115), name the ones the passage
    actually uses: "Dhp 100", or "Dhp 100–101" across verses. None for ordinary suttas."""
    if not re.fullmatch(r"[a-z]+[\d.]*\d+-\d+", uid):
        return None
    numbers = sorted({r[k].split(":")[0] for r in ranges for k in ("start", "end") if ":" in r[k]},
                     key=lambda v: [int(n) for n in re.findall(r"\d+", v)])
    if not numbers:
        return None
    name = lambda v: re.sub(r"^([a-z]+)", lambda m: m.group(1).capitalize() + " ", v)
    first, last = name(numbers[0]), numbers[-1]
    return first if len(numbers) == 1 else f"{first}–{re.sub(r'^[a-z]+', '', last)}"


def main(argv):
    args = [a for a in argv[1:] if a != "--check"]
    check_only = "--check" in argv
    if len(args) != 1:
        print(__doc__, file=sys.stderr)
        return 2
    bilara = os.path.abspath(args[0])
    with open(SELECTIONS, encoding="utf-8") as f:
        selections = json.load(f)
    with open(build_passages.SOURCE, encoding="utf-8") as f:
        current = json.load(f)
    refs = {}
    if os.path.exists(CANDIDATES):
        with open(CANDIDATES, encoding="utf-8") as f:
            refs = {s["uid"]: s["ref"] for s in json.load(f)["suttas"]}
    refs.update({p["uid"]: p["ref"] for p in current["passages"]})

    passages, errors = [], []
    order = [u for u in selections["order"] if selections["suttas"].get(u, {}).get("status") == "include"]
    order += [u for u, s in selections["suttas"].items() if s.get("status") == "include" and u not in order]
    for uid in order:
        s = selections["suttas"][uid]
        passages.append({
            "id": s["id"].strip(),
            "ref": verse_ref(uid, s.get("ranges", [])) or refs.get(uid, uid),
            "uid": uid,
            "ranges": [{"start": r["start"], "end": r["end"]} for r in s.get("ranges", [])],
            "excerpt": s.get("excerpt"),
            "highlight": s.get("highlight", "").strip(),
            # Line breaks are added on screen (String.questionLines), so store one plain line.
            "question": " ".join(s.get("question", "").split()),
        })

    if not passages or passages[0]["uid"] != "an10.51":
        errors.append("AN 10.51 must be the first passage")
    shipped = {p["id"] for p in current["passages"]}
    dropped = shipped - {p["id"] for p in passages}
    for p in passages:
        try:
            built = build_passages.build(bilara, {"passages": [p]})[0]
        except build_passages.BuildError as error:
            errors.append(str(error))
            continue
        # The app's tests (PassageSetTests) hold the widgets to these lengths.
        excerpt = len(" ".join(built["excerpt"]))
        if excerpt > MAX_EXCERPT:
            errors.append(f"{p['id']}: widget excerpt is {excerpt} characters (the app allows {MAX_EXCERPT})")
        if len(built["highlight"]) > MAX_HIGHLIGHT:
            errors.append(f"{p['id']}: highlight is {len(built['highlight'])} characters (the app allows {MAX_HIGHLIGHT})")
    ids = [p["id"] for p in passages]
    errors += [f"duplicate id: {i}" for i in sorted({i for i in ids if ids.count(i) > 1})]

    print(f"{len(passages)} passages in the set")
    for d in sorted(dropped):
        print(f"note: {d} is in the app now but not in the set (its ID stays retired)")
    if errors:
        print(f"{len(errors)} to fix before export:", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        return 1
    if check_only:
        print("all passages pass; nothing written (--check)")
        return 0

    current["passages"] = passages
    with open(build_passages.SOURCE, "w", encoding="utf-8") as f:
        json.dump(current, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"wrote {os.path.relpath(build_passages.SOURCE, build_passages.REPO)}; now run build_passages.py")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
