#!/bin/bash
# Shared setup for handover scripts. Source, don't execute.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HANDOVER_HOME="$(dirname "$SCRIPT_DIR")"
HANDOVERS_DIR="$HANDOVER_HOME/handovers"
# Index is a per-machine cache, rebuilt from markdown. Never sync it.
DB_DIR="${HANDOVER_DB_DIR:-$HOME/.cache/handover}"
DB="$DB_DIR/index.db"
mkdir -p "$DB_DIR" "$HANDOVERS_DIR"

# Rebuild index when any md is newer than the db, or file count drifts
# (covers deletions, which -newer can't see).
ensure_index() {
  local need=0
  if [ ! -f "$DB" ]; then
    need=1
  elif [ -n "$(find "$HANDOVERS_DIR" -name '*.md' -newer "$DB" -print -quit 2>/dev/null)" ]; then
    need=1
  else
    local db_count fs_count
    db_count=$(sqlite3 "$DB" "SELECT count(*) FROM handovers;" 2>/dev/null || echo -1)
    fs_count=$(find "$HANDOVERS_DIR" -name '*.md' | wc -l | tr -d ' ')
    [ "$db_count" != "$fs_count" ] && need=1
  fi
  if [ "$need" = 1 ]; then
    python3 "$SCRIPT_DIR/reindex.py" "$HANDOVERS_DIR" "$DB"
  fi
  return 0
}
