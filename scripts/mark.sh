#!/bin/bash
# Change a handover card's status.
#
# Usage: mark.sh <id> <open|done|superseded>
#
# Mark a card superseded as soon as you pick it up and save a newer one, so
# stale next_steps never get injected into a future session.
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

ID="${1:-}" STATUS="${2:-}"
case "$STATUS" in
  open|done|superseded) ;;
  *) echo "usage: mark.sh <id> <open|done|superseded>" >&2; exit 1 ;;
esac

FILE="$HANDOVERS_DIR/$ID.md"
[ -f "$FILE" ] || { echo "no such handover: $ID" >&2; exit 1; }

python3 - "$FILE" "$STATUS" <<'PY'
import sys
path, status = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()
end = text.find("\n---", 3)
if not text.startswith("---") or end == -1:
    sys.exit("file has no frontmatter")
fm = text[4:end]
lines = [l for l in fm.splitlines() if not l.startswith("status:")]
lines.append(f"status: {status}")
open(path, "w", encoding="utf-8").write(
    "---\n" + "\n".join(lines) + text[end:])
PY

python3 "$SCRIPT_DIR/reindex.py" "$HANDOVERS_DIR" "$DB" >/dev/null
echo "$ID -> $STATUS"
