#!/usr/bin/env bash
# Update the tracker: scripts/mark-done.sh <id> [built|video|posts] [YYYY-MM-DD]
#   mark-done.sh az-labs-1                 -> built today
#   mark-done.sh az-labs-1 video 2026-10-25
#   mark-done.sh az-labs-1 posts
#   mark-done.sh --skip az-labs-1 video    -> mark video or posts as not planned
#   mark-done.sh --plan az-labs-1 video    -> mark video or posts as planned again
#   mark-done.sh --current az-labs-1       -> set the in-progress item
# Item ids are in site/progress.json.
set -euo pipefail
FILE="$(cd "$(dirname "$0")/.." && pwd)/site/progress.json"
python3 - "$FILE" "$@" <<'PY'
import json, sys, datetime
f, args = sys.argv[1], sys.argv[2:]
d = json.load(open(f))
mode = "set"
if args and args[0] in ("--skip", "--plan", "--current"):
    mode, args = args[0][2:], args[1:]
if not args:
    sys.exit("usage: mark-done.sh [--skip|--plan|--current] <id> [built|video|posts] [date]")
item_id, rest = args[0], args[1:]
hit = [i for i in d["items"] if i["id"] == item_id]
if not hit:
    sys.exit(f"No item with id {item_id}")
it = hit[0]
today = datetime.date.today().isoformat()
if mode == "current":
    for i in d["items"]:
        i["current"] = (i["id"] == item_id)
    msg = f"{item_id}: in progress"
elif mode in ("skip", "plan"):
    part = rest[0] if rest else sys.exit("say video or posts")
    if part not in ("video", "posts"):
        sys.exit("only video or posts can be skipped or planned")
    it[part] = "skip" if mode == "skip" else "planned"
    msg = f"{item_id}: {part} {it[part]}"
else:
    part = rest[0] if rest and rest[0] in ("built", "video", "posts") else "built"
    date = rest[-1] if rest and rest[-1][:2] == "20" else today
    it[part] = date
    if part == "built":
        it["current"] = False
    msg = f"{item_id}: {part} {date}"
d["updated"] = today
json.dump(d, open(f, "w"), indent=1)
print(msg)
PY
