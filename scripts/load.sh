#!/bin/bash
# Print a handover card for pickup, with a staleness header.
#
# Usage: load.sh [--project <name>] [--id <id>] [--layer1-only] [--any-status]
#
# Default: the most recent handover with status=open (optionally scoped to a
# project). --layer1-only prints only the universal body — use when handing
# over to a different agent/environment (e.g. Gemini). --any-status includes
# done/superseded cards.
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

PROJECT="" ID="" LAYER1=0 ANY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2 ;;
    --id) ID="$2"; shift 2 ;;
    --layer1-only) LAYER1=1; shift ;;
    --any-status) ANY=1; shift ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

ensure_index

if [ -n "$ID" ]; then
  WHERE="id = '$(echo "$ID" | sed "s/'/''/g")'"
else
  WHERE="1=1"
  [ "$ANY" = 0 ] && WHERE="$WHERE AND status = 'open'"
  [ -n "$PROJECT" ] && WHERE="$WHERE AND project = '$(echo "$PROJECT" | sed "s/'/''/g")'"
fi

# \x1f as separator: unlike tab, it's not IFS whitespace, so empty
# columns (e.g. no branch) don't collapse and shift the fields.
ROW=$(sqlite3 -separator $'\x1f' "$DB" \
  "SELECT id, path, created_at, device, branch, status, agent
   FROM handovers WHERE $WHERE ORDER BY created_at DESC LIMIT 1;")

if [ -z "$ROW" ]; then
  echo "no matching handover found." >&2
  echo "try: list.sh --all" >&2
  exit 1
fi

IFS=$'\x1f' read -r RID RPATH RCREATED RDEVICE RBRANCH RSTATUS RAGENT <<< "$ROW"

AGE=$(python3 - "$RCREATED" <<'PY'
import datetime, sys
try:
    t = datetime.datetime.fromisoformat(sys.argv[1].replace("Z", "+00:00"))
    d = datetime.datetime.now(datetime.timezone.utc) - t
    h = d.total_seconds() / 3600
    print(f"{h:.1f} 小時前" if h < 48 else f"{h/24:.0f} 天前")
except Exception:
    print("unknown age")
PY
)

echo "═══ 交班單 ${RID} ═══"
echo "寫於 ${AGE}｜裝置 ${RDEVICE:-?}｜branch ${RBRANCH:-無}｜status ${RSTATUS}｜agent ${RAGENT:-?}"
echo "⚠ 接手前先驗證現況：branch 可能已 merge、檔案可能已被改動。"
echo ""

if [ "$LAYER1" = 1 ]; then
  # Strip frontmatter: universal layer only.
  awk 'BEGIN{n=0} /^---$/{n++; next} n>=2 || n==0' "$RPATH"
else
  cat "$RPATH"
fi
