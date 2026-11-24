"""Build candidates.json for the passage review page from PJ's Obsidian vault.

Usage (from the repo root):

    python3 -I scripts/passages/review/build_candidates.py <bilara-data checkout> [<vault>]

The bilara-data checkout is the same one build_passages.py uses (see the top of
that script). The vault defaults to PJ's main vault in Dropbox.

For every sutta the vault mentions (SuttaCentral links, or references such as
"MN 19" or "SN 56.11") that has a Sujato translation, it writes the full
translation by segment, the notes that mention it, and which segments look
quoted in those notes. candidates.json is generated and git-ignored: it holds
lines from private notes. Run it again whenever the vault changes; your
choices live in selections.json and are kept.
"""
import glob
import json
import os
import re
import subprocess
import sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
OUTPUT = os.path.join(HERE, "candidates.json")
SOURCE = os.path.join(os.path.dirname(HERE), "passages-source.json")
DEFAULT_VAULT = os.path.expanduser("~/Library/CloudStorage/Dropbox/Obsidian Vault/PJTeh Obsidian Vault")

# Links: suttacentral.net/mn19/en/sujato, suttacentral.net/sn48.45-47 …
LINK = re.compile(r"suttacentral\.net/([a-z]+)(\d+(?:\.\d+)?(?:-\d+)?)", re.I)
# Text references, capitalised only, so "an 8 week course" doesn't count.
TEXT = re.compile(r"\b(MN|SN|AN|DN|Dhp|Snp|Ud|Iti|Thag|Thig|Kp)\s?\.?\s?(\d+(?:\.\d+)?(?:\s?[-–]\s?\d+)?)\b")
PREFIX_NAMES = {"mn": "MN", "sn": "SN", "an": "AN", "dn": "DN", "dhp": "Dhp", "snp": "Snp", "ud": "Ud",
                "iti": "Iti", "thag": "Thag", "thig": "Thig", "kp": "Kp"}
SKIP_DIRS = {".obsidian", ".trash", "Templates"}


def words(s):
    return re.findall(r"[a-zāīūṁṃṅñṭḍṇḷ]+", s.lower())


def expand(prefix, number):
    """'sn', '48.45-47' -> ['sn48.45', 'sn48.46', 'sn48.47']; 'mn', '10' -> ['mn10']."""
    prefix = prefix.lower()
    number = re.sub(r"\s", "", number).replace("–", "-")
    m = re.fullmatch(r"(?:(\d+)\.)?(\d+)(?:-(\d+))?", number)
    if not m:
        return []
    book, first, last = m.group(1), int(m.group(2)), int(m.group(3) or m.group(2))
    if last < first or last - first > 20:
        last = first
    head = f"{prefix}{book}." if book else prefix
    return [f"{head}{n}" for n in range(first, last + 1)]


class Library:
    """Finds the Sujato translation file for a sutta, including range files like dhp1-20 or an1.1-10."""

    def __init__(self, bilara):
        self.files = {}
        self.ranges = defaultdict(list)
        pattern = os.path.join(bilara, "translation", "en", "sujato", "sutta", "**", "*_translation-en-sujato.json")
        for path in glob.glob(pattern, recursive=True):
            uid = os.path.basename(path).split("_")[0]
            self.files[uid] = path
            m = re.fullmatch(r"([a-z]+(?:\d+\.)?)(\d+)-(\d+)", uid)
            if m:
                self.ranges[m.group(1)].append((int(m.group(2)), int(m.group(3)), uid))

    def resolve(self, ref):
        if ref in self.files:
            return ref
        m = re.fullmatch(r"([a-z]+(?:\d+\.)?)(\d+)", ref)
        if m:
            n = int(m.group(2))
            for a, b, uid in self.ranges.get(m.group(1), []):
                if a <= n <= b:
                    return uid
        return None


def display_ref(uid):
    m = re.fullmatch(r"([a-z]+)(.*)", uid)
    return f"{PREFIX_NAMES.get(m.group(1), m.group(1).upper())} {m.group(2).replace('-', '–')}"


def title_of(text):
    titles = [v.strip() for k, v in text.items() if re.search(r":0\.\d+$", k) and v.strip()]
    return titles[-1] if titles else ""


def scan_vault(vault, library):
    """uid -> {note path -> [matching lines]}"""
    found = defaultdict(lambda: defaultdict(list))
    note_text = {}
    for root, dirs, files in os.walk(vault):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in files:
            if not name.endswith(".md"):
                continue
            path = os.path.join(root, name)
            rel = os.path.relpath(path, vault)
            try:
                with open(path, encoding="utf-8") as f:
                    lines = f.read().splitlines()
            except (OSError, UnicodeDecodeError):
                continue
            note_text[rel] = "\n".join(lines)
            for i, line in enumerate(lines):
                refs = [r for m in LINK.finditer(line) for r in expand(m.group(1), m.group(2))]
                refs += [r for m in TEXT.finditer(line) for r in expand(m.group(1), m.group(2))]
                for ref in refs:
                    uid = library.resolve(ref)
                    if not uid:
                        continue
                    # The line plus its neighbours, without long URLs.
                    context = " ".join(l.strip() for l in lines[max(0, i - 1): i + 2] if l.strip())
                    context = re.sub(r"https?://\S+", "[link]", context)
                    if len(context) > 320:
                        context = context[:317] + "…"
                    if context not in found[uid][rel]:
                        found[uid][rel].append(context)
    return found, note_text


def quoted_segments(segments, notes):
    """Segment IDs whose wording mostly appears in the notes that mention the sutta (5-word shingles)."""
    shingles = set()
    for text in notes:
        w = words(text)
        shingles.update(tuple(w[i:i + 5]) for i in range(len(w) - 4))
    quoted = []
    for seg_id, text in segments:
        w = words(text)
        if len(w) < 6:
            continue
        mine = [tuple(w[i:i + 5]) for i in range(len(w) - 4)]
        if sum(s in shingles for s in mine) >= 0.6 * len(mine):
            quoted.append(seg_id)
    return quoted


def git_commit(bilara):
    try:
        return subprocess.run(["git", "-C", bilara, "rev-parse", "HEAD"], check=True,
                              capture_output=True, text=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return ""


def main(argv):
    if len(argv) not in (2, 3):
        print(__doc__, file=sys.stderr)
        return 2
    bilara = os.path.abspath(argv[1])
    vault = os.path.abspath(argv[2]) if len(argv) == 3 else DEFAULT_VAULT
    library = Library(bilara)
    if not library.files:
        print(f"error: no Sujato translations under {bilara}", file=sys.stderr)
        return 1
    found, note_text = scan_vault(vault, library)

    with open(SOURCE, encoding="utf-8") as f:
        in_set = {p["uid"] for p in json.load(f)["passages"]}
    for uid in in_set:  # the current set is always reviewable, mentioned or not
        found.setdefault(uid, defaultdict(list))

    suttas = []
    for uid, notes in found.items():
        with open(library.files[uid], encoding="utf-8") as f:
            text = json.load(f)
        # Named as passages-source.json ranges name them (build_passages.segment_ids).
        segments = [[k.split(":")[1] if k.split(":")[0] == uid else k, v.strip()] for k, v in text.items()
                    if v.strip() and not k.split(":")[1].startswith("0.")]
        suttas.append({
            "uid": uid,
            "ref": display_ref(uid),
            "title": title_of(text),
            "url": f"https://suttacentral.net/{uid}/en/sujato",
            "words": sum(len(s.split()) for _, s in segments),
            "segments": segments,
            "mentions": [{"note": note, "lines": lines[:4]} for note, lines in sorted(notes.items())],
            "quoted": quoted_segments(segments, [note_text[n] for n in notes]),
            "inSet": uid in in_set,
        })
    suttas.sort(key=lambda s: (not s["inSet"], -len(s["mentions"]), s["uid"]))

    with open(OUTPUT, "w", encoding="utf-8") as f:
        json.dump({"bilaraCommit": git_commit(bilara), "vault": vault, "suttas": suttas}, f, ensure_ascii=False)
    print(f"wrote {os.path.relpath(OUTPUT, REPO)}: {len(suttas)} suttas "
          f"({sum(s['inSet'] for s in suttas)} already in the set, "
          f"{sum(bool(s['quoted']) for s in suttas)} with lines quoted in the vault)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
