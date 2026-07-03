#!/bin/bash
# List handover cards, most recent first.
#
# Usage: list.sh [--project <name>] [--all] [--days <N>]
#
# Default: open cards from the last 30 days. --all includes every status
# with no date limit.
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

PROJECT="" ALL=0 DAYS=30
while [ $# -gt 0 ]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2 ;;
    --all) ALL=1; shift ;;
    --days) DAYS="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

ensure_index

WHERE="1=1"
if [ "$ALL" = 0 ]; then
  WHERE="status = 'open' AND created_at >= datetime('now', '-$DAYS days')"
fi
[ -n "$PROJECT" ] && WHERE="$WHERE AND project = '$(echo "$PROJECT" | sed "s/'/''/g")'"

sqlite3 -column -header "$DB" \
  "SELECT id, session_type AS type, status, project,
          substr(topic, 1, 40) AS topic
   FROM handovers WHERE $WHERE ORDER BY created_at DESC LIMIT 50;"
