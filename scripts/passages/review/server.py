"""Local review page for choosing the passage set.

Usage (from the repo root, after build_candidates.py):

    python3 -I scripts/passages/review/server.py [port]

Then open http://127.0.0.1:8765 (or the port given). Only this computer can reach it.

Your choices save as you go to selections.json next to this script (the previous
version is kept as selections.json.bak). On the first run it starts from the
current passages-source.json, so the shipped passages appear as included, in order.
When you're done, export_source.py turns selections.json into passages-source.json.
"""
import json
import os
import re
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCE = os.path.join(os.path.dirname(HERE), "passages-source.json")
CANDIDATES = os.path.join(HERE, "candidates.json")
SELECTIONS = os.path.join(HERE, "selections.json")
PAGE = os.path.join(HERE, "index.html")


def seed_selections():
    with open(SOURCE, encoding="utf-8") as f:
        passages = json.load(f)["passages"]
    return {
        "version": 1,
        "order": [p["uid"] for p in passages],
        "suttas": {
            p["uid"]: {
                "status": "include",
                "id": p["id"],
                "shipped": True,
                "ranges": p["ranges"],
                "excerpt": p.get("excerpt"),
                "highlight": p.get("highlight", ""),
                "question": p.get("question", ""),
                "note": "",
            }
            for p in passages
        },
    }


def load_selections():
    if not os.path.exists(SELECTIONS):
        write_selections(seed_selections())
    with open(SELECTIONS, encoding="utf-8") as f:
        return json.load(f)


def write_selections(data):
    if os.path.exists(SELECTIONS):
        os.replace(SELECTIONS, SELECTIONS + ".bak")
    tmp = SELECTIONS + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    os.replace(tmp, SELECTIONS)


def valid(data):
    return (isinstance(data, dict) and isinstance(data.get("order"), list)
            and isinstance(data.get("suttas"), dict)
            and all(isinstance(v, dict) for v in data["suttas"].values()))


class Handler(BaseHTTPRequestHandler):
    def send(self, status, body, kind="application/json"):
        data = body if isinstance(body, bytes) else body.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", kind + "; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path in ("/", "/index.html"):
            with open(PAGE, "rb") as f:
                self.send(200, f.read(), "text/html")
        elif self.path == "/api/candidates":
            if not os.path.exists(CANDIDATES):
                self.send(404, json.dumps({"error": "Run build_candidates.py first."}))
                return
            with open(CANDIDATES, "rb") as f:
                self.send(200, f.read())
        elif self.path == "/api/selections":
            self.send(200, json.dumps(load_selections(), ensure_ascii=False))
        else:
            self.send(404, json.dumps({"error": "not found"}))

    def do_PUT(self):
        if self.path != "/api/selections":
            self.send(404, json.dumps({"error": "not found"}))
            return
        # Only accept saves from the page itself.
        origin = self.headers.get("Origin", "")
        if origin and not re.fullmatch(r"http://(127\.0\.0\.1|localhost):\d+", origin):
            self.send(403, json.dumps({"error": "forbidden"}))
            return
        try:
            data = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))))
        except ValueError:
            self.send(400, json.dumps({"error": "bad JSON"}))
            return
        if not valid(data):
            self.send(400, json.dumps({"error": "unexpected shape"}))
            return
        write_selections(data)
        self.send(200, json.dumps({"ok": True}))

    def log_message(self, fmt, *args):
        if not self.path.startswith("/api/selections"):
            super().log_message(fmt, *args)


def main(argv):
    port = int(argv[1]) if len(argv) > 1 else 8765
    load_selections()
    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    print(f"Passage review: http://127.0.0.1:{port}  (Ctrl-C to stop)", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
