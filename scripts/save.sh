#!/bin/bash
# Save a handover card from a draft markdown file.
#
# Usage: save.sh --file <draft.md>
#
# The draft must contain YAML frontmatter with at least `project` and
# `session_type`, and a `# <topic>` title. Missing bookkeeping fields
# (created_at, device, status, agent, schema_version, working_dir, branch)
# are filled in automatically. The file is copied into handovers/ under a
# timestamped name and the index is rebuilt.
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

DRAFT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --file) DRAFT="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done
[ -z "$DRAFT" ] && { echo "usage: save.sh --file <draft.md>" >&2; exit 1; }
[ -f "$DRAFT" ] || { echo "no such file: $DRAFT" >&2; exit 1; }

DEST=$(python3 - "$DRAFT" "$HANDOVERS_DIR" <<'PY'
import datetime, os, re, socket, subprocess, sys

draft, handovers_dir = sys.argv[1], sys.argv[2]
text = open(draft, encoding="utf-8").read()

if not text.startswith("---"):
    sys.exit("draft has no YAML frontmatter (must start with ---)")
end = text.find("\n---", 3)
if end == -1:
    sys.exit("frontmatter is not closed with ---")
meta = {}
for line in text[4:end].splitlines():
    if ":" in line:
        k, v = line.split(":", 1)
        meta[k.strip()] = v.strip().strip('"')
body = text[end + 4:].lstrip("\n")

for key in ("project", "session_type"):
    if not meta.get(key):
        sys.exit(f"frontmatter is missing required field: {key}")
if meta["session_type"] not in ("sdd", "debug", "discussion", "admin"):
    sys.exit("session_type must be one of: sdd debug discussion admin")
if not re.search(r"^# \S", body, re.M):
    sys.exit("draft has no '# <topic>' title")
if meta.get("status", "open") == "open" and "## Next steps" not in body:
    print("warning: open handover without a '## Next steps' section",
          file=sys.stderr)

now = datetime.datetime.now(datetime.timezone.utc)
meta.setdefault("schema_version", "1")
meta.setdefault("created_at", now.strftime("%Y-%m-%dT%H:%M:%SZ"))
meta.setdefault("status", "open")
meta.setdefault("agent", "claude-code")
meta.setdefault("device", socket.gethostname().split(".")[0])
if not meta.get("working_dir"):
    meta["working_dir"] = os.environ.get("PWD", os.getcwd())
if not meta.get("branch"):
    try:
        meta["branch"] = subprocess.run(
            ["git", "branch", "--show-current"], capture_output=True,
            text=True, timeout=5).stdout.strip()
    except Exception:
        pass

order = ["schema_version", "created_at", "session_type", "status", "project",
         "agent", "device", "account", "branch", "working_dir", "test_status"]
keys = [k for k in order if meta.get(k)] + \
       [k for k in meta if k not in order and meta.get(k)]
fm = "\n".join(f"{k}: {meta[k]}" for k in keys)

slug = re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", meta["project"].lower())).strip("-")
local = now.astimezone()
stem = f"{local.strftime('%Y-%m-%d-%H%M')}-{slug}"
dest = os.path.join(handovers_dir, stem + ".md")
n = 2
while os.path.exists(dest):
    dest = os.path.join(handovers_dir, f"{stem}-{n}.md")
    n += 1

with open(dest, "w", encoding="utf-8") as f:
    f.write(f"---\n{fm}\n---\n\n{body}")
print(dest)
PY
)

python3 "$SCRIPT_DIR/reindex.py" "$HANDOVERS_DIR" "$DB" >/dev/null
echo "saved: $DEST"
echo "id: $(basename "$DEST" .md)"
