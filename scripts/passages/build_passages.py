"""Generate DhammaDiary/Resources/passages.json from passages-source.json.

Usage (from the repo root):

    python3 -I scripts/passages/build_passages.py <bilara-data checkout>

The checkout must be bilara-data's `published` branch; a sparse checkout of
`translation/en/sujato/sutta` is enough:

    git clone --depth 1 --branch published --filter=blob:none --sparse \
        https://github.com/suttacentral/bilara-data.git
    git -C bilara-data sparse-checkout set translation/en/sujato/sutta

Text is copied verbatim from Bhikkhu Sujato's translation, by segment ID.
The only change: an unpaired quotation mark at the very first or very last
character of an excerpt is removed. See docs/spec/v1.md section 3.3.

Each passage also names a short `excerpt` range, inside its ranges, for the
passage widget (spec 8.6), and a one-line `highlight`, the passage's essence,
for the small widgets (spec 8.9). The highlight is a verbatim piece of one
segment; keep it under about 100 characters.
"""
import glob
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
SOURCE = os.path.join(HERE, "passages-source.json")
OUTPUT = os.path.join(REPO, "DhammaDiary", "Resources", "passages.json")


class BuildError(Exception):
    pass


def load_translation(bilara, uid):
    pattern = os.path.join(bilara, "translation", "en", "sujato", "sutta", "**", f"{uid}_translation-en-sujato.json")
    matches = glob.glob(pattern, recursive=True)
    if len(matches) != 1:
        raise BuildError(f"{uid}: expected one translation file, found {len(matches)}")
    with open(matches[0], encoding="utf-8") as f:
        return json.load(f)


def title_of(uid, text):
    titles = [v.strip() for k, v in text.items() if re.search(r":0\.\d+$", k) and v.strip()]
    if not titles:
        raise BuildError(f"{uid}: no title segment")
    return titles[-1]


def segment_ids(uid, text):
    """Body segment IDs in file order, as ranges name them: the part after the colon
    ("3.2", "4-5.1"), or the full ID ("dhp101:1") in files that hold several suttas or verses."""
    return [
        (k.split(":")[1] if k.split(":")[0] == uid else k, k)
        for k, v in text.items()
        if v.strip() and not k.split(":")[1].startswith("0.")
    ]


def segment_slice(passage, text, r):
    """The segments from r["start"] to r["end"], inclusive, in file order."""
    ids = segment_ids(passage["uid"], text)
    names = [name for name, _ in ids]
    for key in ("start", "end"):
        if r[key] not in names:
            raise BuildError(f"{passage['id']}: segment {r[key]} not found")
    a, b = names.index(r["start"]), names.index(r["end"])
    if a > b:
        raise BuildError(f"{passage['id']}: range {r['start']}–{r['end']} runs backwards")
    return a, b, [text[full].strip() for _, full in ids[a: b + 1]]


def block_for(passage, text, r):
    return segment_slice(passage, text, r)[2]


def closing_single_quotes(s):
    """Count ’ used as a closing quote, not as an apostrophe inside a word."""
    return len(re.findall(r"’(?!\w)", s))


def strip_unpaired_edge_quotes(blocks):
    """Remove an unpaired “ ” ‘ ’ only at the excerpt's first or last character."""
    joined = "\n".join(s for block in blocks for s in block)
    first, last = blocks[0][0], blocks[-1][-1]
    if first.startswith("“") and joined.count("“") > joined.count("”"):
        blocks[0][0] = first = first[1:]
    elif first.startswith("‘") and joined.count("‘") > closing_single_quotes(joined):
        blocks[0][0] = first = first[1:]
    joined = "\n".join(s for block in blocks for s in block)
    if last.endswith("”") and joined.count("”") > joined.count("“"):
        blocks[-1][-1] = last[:-1]
    elif last.endswith("’") and closing_single_quotes(joined) > joined.count("‘"):
        blocks[-1][-1] = last[:-1]
    return blocks


def excerpt_for(passage, text):
    """The widget's short excerpt: one range that lies inside one of the passage's ranges."""
    r = passage.get("excerpt")
    if not r:
        raise BuildError(f"{passage['id']}: no excerpt")
    a, b, _ = segment_slice(passage, text, r)
    if not any(
        oa <= a and b <= ob for oa, ob, _ in (segment_slice(passage, text, outer) for outer in passage["ranges"])
    ):
        raise BuildError(f"{passage['id']}: excerpt {r['start']}–{r['end']} is not inside one of its ranges")
    return strip_unpaired_edge_quotes([block_for(passage, text, r)])[0]


def highlight_for(passage, blocks):
    """The one-line essence: text copied exactly from a single segment of the passage."""
    highlight = passage.get("highlight", "").strip()
    if not highlight:
        raise BuildError(f"{passage['id']}: no highlight")
    if not any(highlight in segment for block in blocks for segment in block):
        raise BuildError(f"{passage['id']}: highlight is not verbatim from one segment: {highlight}")
    return highlight


def git_commit(bilara):
    try:
        return subprocess.run(
            ["git", "-C", bilara, "rev-parse", "HEAD"], check=True, capture_output=True, text=True
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError) as error:
        raise BuildError(f"could not read the bilara-data commit: {error}")


def build(bilara, source):
    seen = set()
    passages = []
    for p in source["passages"]:
        if p["id"] in seen:
            raise BuildError(f"duplicate id: {p['id']}")
        seen.add(p["id"])
        if not p.get("question", "").strip():
            raise BuildError(f"{p['id']}: empty question")
        if not p.get("ranges"):
            raise BuildError(f"{p['id']}: no ranges")
        text = load_translation(bilara, p["uid"])
        blocks = strip_unpaired_edge_quotes([block_for(p, text, r) for r in p["ranges"]])
        excerpt = excerpt_for(p, text)
        highlight = highlight_for(p, blocks)
        passages.append({
            "id": p["id"],
            "ref": p["ref"],
            "title": title_of(p["uid"], text),
            "uid": p["uid"],
            "ranges": [{"start": r["start"], "end": r["end"]} for r in p["ranges"]],
            "blocks": blocks,
            "excerpt": excerpt,
            "highlight": highlight,
            "question": p["question"].strip(),
            "url": f"https://suttacentral.net/{p['uid']}/en/sujato",
        })
    return passages


def main(argv):
    if len(argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    bilara = os.path.abspath(argv[1])
    with open(SOURCE, encoding="utf-8") as f:
        source = json.load(f)
    try:
        passages = build(bilara, source)
        commit = git_commit(bilara)
    except BuildError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    document = {
        "formatVersion": 1,
        "source": {
            "repo": "suttacentral/bilara-data",
            "branch": "published",
            "commit": commit,
            "translator": "sujato",
        },
        "passages": passages,
    }
    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    with open(OUTPUT, "w", encoding="utf-8") as f:
        json.dump(document, f, ensure_ascii=False, indent=2)
        f.write("\n")

    for i, p in enumerate(passages, 1):
        words = sum(len(s.split()) for block in p["blocks"] for s in block)
        excerpt = len(" ".join(p["excerpt"]))
        print(f"{i:>3}. {p['id']:<24} {p['ref']:<10} {words:>4} words  excerpt {excerpt:>3}  highlight {len(p['highlight']):>3} chars  {p['title']}")
    print(f"wrote {os.path.relpath(OUTPUT, REPO)}: {len(passages)} passages, bilara-data {commit[:7]}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
