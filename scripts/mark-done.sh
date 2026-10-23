#!/usr/bin/env bash
# Mark a tracker item finished: scripts/mark-done.sh <id> [YYYY-MM-DD]
# Item ids are in site/progress.json (for example az-projects-1, az-labs-3).
# Also: scripts/mark-done.sh --current <id> sets the "in progress" item.
set -euo pipefail
FILE="$(cd "$(dirname "$0")/.." && pwd)/site/progress.json"
if [ "${1:-}" = "--current" ]; then MODE=current; ID="${2:?item id}"; DATE=""; else MODE=done; ID="${1:?item id}"; DATE="${2:-$(date +%F)}"; fi
python3 - "$FILE" "$MODE" "$ID" "$DATE" <<'PY'
import json, sys, datetime
f, mode, id_, date = sys.argv[1:5]
d = json.load(open(f))
hit = [i for i in d["items"] if i["id"] == id_]
if not hit:
    sys.exit(f"No item with id {id_}")
for i in d["items"]:
    if mode == "current":
        i["current"] = (i["id"] == id_)
if mode == "done":
    hit[0]["done"] = date
    hit[0]["current"] = False
d["updated"] = datetime.date.today().isoformat()
json.dump(d, open(f, "w"), indent=1)
print(f"{id_}: {mode} {date}".strip())
PY
