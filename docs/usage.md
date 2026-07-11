# Usage Guide

[繁體中文說明](usage_tw.md)

This is the complete reference. Day-to-day, you won't touch scripts directly—say "handover" or "take over" to Claude and the skill handles it. This documents the underlying behavior for debugging and manual operation.

Examples below use `$H` for this folder (wherever your sync service puts it):

```bash
H="<path-to-your-synced-handover-folder>"
# e.g. Google Drive: "$HOME/Library/CloudStorage/GoogleDrive-<email>/My Drive/handover"
#      Dropbox:      "$HOME/Dropbox/handover"
```

## Contents

1. [Daily Workflows](#daily-workflows)
2. [Command Reference](#command-reference)
3. [Handover Note Format Spec](#handover-note-format-spec)
4. [session_type and Summary Depth](#session_type-and-summary-depth)
5. [Troubleshooting](#troubleshooting)

---

## Daily Workflows

### Handing Over (before session end)

Tell Claude "handover" or "save progress". Claude will:

1. Determine session_type (asks you once if unsure)
2. Write a handover draft to a temp file
3. Execute `save.sh --file <draft>`, report the note id
4. Suggest `/clear`—clean context beats bloated context with rot

### Taking Over (new session start)

Tell Claude "take over <project>" or "where did I leave off". Claude will:

1. Execute `load.sh --project <project>` to load the newest open note
2. Validate current state (does branch still exist, have files changed?), trust current state if there's a mismatch
3. Mark the taken-over note `superseded` (if saving a new note later) or `done`

### Handing Over to Another Agent (Gemini, ChatGPT, etc.)

```bash
"$H/scripts/load.sh" --project <project> --layer1-only
```

Output contains only the generic layer (frontmatter environment metadata removed). Paste the whole thing directly to the other agent as opening context. They don't need to understand any of this system's format.

### Switching Devices

1. Old device: hand over (wait for your sync client to show sync complete before leaving)
2. New device: confirm sync has completed, then take over

---

## Command Reference

### save.sh — Save a Handover Note

```bash
"$H/scripts/save.sh" --file <draft.md>
```

- Draft must include frontmatter (at least `project`, `session_type`) and a `# Title` line.
- Auto-filled: `created_at` (UTC), `device` (hostname), `status: open`, `agent: claude-code`, `schema_version`, `working_dir` (cwd when called), `branch` (if cwd is inside a git repo).
- Filename auto-generated: `YYYY-MM-DD-HHMM-<project-slug>.md` (local time), suffix `-2` on collision.
- If status is open but draft lacks `## Next steps`, prints warning (doesn't block).
- Missing required fields, invalid session_type, or no title → errors and exits.

### load.sh — Load a Handover Note

```bash
"$H/scripts/load.sh" [--project <name>] [--id <id>] [--layer1-only] [--any-status]
```

| Parameter | Behavior |
|---|---|
| (no args) | Newest `open` note across all projects |
| `--project` | Limit to project |
| `--id` | Load specific note (ignores status) |
| `--layer1-only` | Strip frontmatter, output only generic text |
| `--any-status` | Include done/superseded in selection |

Output begins with a staleness header: `Written N hours ago｜device｜branch｜status｜agent`, plus reminder to validate current state before acting.

### list.sh — List Handover Notes

```bash
"$H/scripts/list.sh" [--project <name>] [--all] [--days <N>]
```

Default: open notes from last 30 days. `--all` shows all statuses across all time (limit 50).

### search.sh — Full-Text Search

```bash
"$H/scripts/search.sh" "keyword" [--project <name>]
```

SQLite FTS5 syntax supported: `parser AND timeout`, `"exact phrase"`, `fail*`. Chinese text searchable (FTS5 treats it character-by-character by default; for multi-character terms, just paste the whole term). Typical use: when you hit a bug that seems familiar, search attempted approaches—"what have I tried and why didn't it work".

### mark.sh — Change Status

```bash
"$H/scripts/mark.sh" <id> <open|done|superseded>
```

- `done`: this work is complete.
- `superseded`: replaced by a newer note (mark old note before saving a new one after taking over).
- Principle: **Stale open notes are more dangerous than no notes**—the agent taking over will confidently execute outdated next steps.

### reindex.py — Rebuild Index

```bash
python3 "$H/scripts/reindex.py" "$H/handovers" ~/.cache/handover/index.db
```

Normally run automatically: every script rebuilds when the index is missing, any md is newer than the index, or file counts don't match. If the index gets corrupted, just delete `~/.cache/handover/index.db`; it rebuilds automatically.

---

## Handover Note Format Spec

```markdown
---
schema_version: 1
created_at: 2026-07-03T13:20:35Z
session_type: debug
status: open
project: gmail-billing-scan
agent: claude-code
device: mac-mini
account: personal
branch: fix/parser
working_dir: /Users/me/Git_repo/gmail-billing-scan
test_status: 3 failing in parser_test
---

# One sentence: what does this note do

## Done
## Decisions
## Blocked
## Next steps
## Attempted approaches
## Lessons learned
```

### Frontmatter (Layer 2: Environment Metadata, useful only in same environment)

| Field | Required | Description |
|---|---|---|
| `project` | ✓ | Project identifier; used by list/load to filter |
| `session_type` | ✓ | `sdd` / `debug` / `discussion` / `admin` |
| `status` | auto | `open` / `done` / `superseded`; defaults to open |
| `created_at` | auto | UTC ISO 8601 |
| `device` / `agent` / `branch` / `working_dir` | auto | Environment snapshot at handover time |
| `account` | recommended | Subscription account identifier (personal/team); store only the alias |
| `test_status` | recommended | Test status at handover time; first thing to re-run when taking over |
| `schema_version` | auto | Format version; currently 1 |

### Body (Layer 1: Generic Layer, readable by anyone and any agent)

| Section | Description |
|---|---|
| `# Title` | Required. One sentence: what does this note do |
| `## Done` | What was accomplished, specific to files and functions |
| `## Decisions` | Decisions and rationale; for discussion, record "argument → consensus/disagreement" |
| `## Blocked` | Where you're stuck (omit if none) |
| `## Next steps` | Each item executable without asking; must include file paths; required for open notes |
| `## Attempted approaches` | Format: "approach → result → why ruled out"; especially valuable for debug |
| `## Lessons learned` | Long-term applicable lessons; good candidates for upgrade to memory/CLAUDE.md once removed from note |

### Quality Rules

- Write for **someone who never saw this conversation**: avoid pronouns and local shorthand.
- Next steps: no vague language like "keep debugging"—every item must be actionable.
- **Never include tokens, passwords, credentials**: handover notes get pasted into other agents' prompts (i.e., they leave this machine).

---

## session_type and Summary Depth

| Type | Use Case | Focus |
|---|---|---|
| `sdd` | Design-driven development | Record progress and "decisions deviating from design docs"; design details → reference paths, don't repeat |
| `debug` | Debugging | Attempted approaches is the main body; write liberally; final solution is secondary |
| `discussion` | Discussion, coaching, analysis | Arguments, consensus, disagreement; skip the conversation itself |
| `admin` | Miscellaneous | Just Next steps and Decisions |

---

## Troubleshooting

**load returns a stale note** — Sync hasn't finished. Wait for your sync client to show complete; confirm the handover folder is kept locally (mirrored/offline), not online-only.

**Script reports `no such file` or reads empty file** — Files were evicted to online-only by your sync client. Set the handover folder to be kept locally (Google Drive: Mirror files; Dropbox: Make available offline; OneDrive: Always keep on this device).

**Index looks wrong (missing notes in list, search can't find things)** — Delete `~/.cache/handover/index.db`; any script will auto-rebuild it next run. Index is always disposable.

**Conflict copy appears (`xxx (1).md`, `xxx (conflicted copy).md`—naming varies by service)** — Two machines edited the same file before sync completed (usually both tried to mark the same note). Both get indexed; `cat` both and keep one, delete the other.

**`sqlite3` or `python3` not found** — Both are built into macOS; if you use a minimal shell with custom PATH, confirm `/usr/bin` is in PATH. No third-party packages needed (no PyYAML—frontmatter is hand-parsed).

**git commands error in this folder (on other machines)** — The `.git` pointer file references a path that doesn't exist on this machine. Scripts don't care; to enable version history here, see README's "Git Version History" section.
