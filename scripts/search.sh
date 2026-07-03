#!/bin/bash
# Full-text search across all handover cards (FTS5).
#
# Usage: search.sh <query> [--project <name>]
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

QUERY="" PROJECT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2 ;;
    *) QUERY="$1"; shift ;;
  esac
done
[ -z "$QUERY" ] && { echo "usage: search.sh <query> [--project <name>]" >&2; exit 1; }

ensure_index

Q=$(echo "$QUERY" | sed "s/'/''/g")
FILTER=""
[ -n "$PROJECT" ] && FILTER="AND h.project = '$(echo "$PROJECT" | sed "s/'/''/g")'"

sqlite3 -separator $'\n' "$DB" \
  "SELECT '── ' || f.id || '  [' || h.status || ', ' || h.session_type || ', ' || h.project || ']',
          snippet(handovers_fts, 3, '>>', '<<', ' … ', 20), ''
   FROM handovers_fts f JOIN handovers h ON h.id = f.id
   WHERE handovers_fts MATCH '$Q' $FILTER
   ORDER BY rank LIMIT 10;"
