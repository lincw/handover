# Design Rationale and Tradeoffs

[繁體中文說明](design_tw.md)

Documents why the system is designed this way, so future changes don't unknowingly overturn decisions that had good reasons.

## Problem Statement

Cross-device, cross-agent, cross-account work continuation. Claude Code's `--resume` and auto-memory work only on a single machine with a single agent; `/compact` is lossy and uncontrolled. When context fills up, two empirical problems emerge: context rot (more tokens → less attention on early text) and context anxiety (model takes shortcuts and wraps up early when sensing space pressure). Strategy: **write out what matters (handover), then restart with clean context**, rather than carrying 80k tokens of aging context forward.

## Core Decisions

### Markdown is Truth, SQLite is Index

Notes live as individual md files in `handovers/`; SQLite only provides listing and FTS5 search, stored locally at `~/.cache/handover/`, and can rebuild anytime. Why:

- Binary databases over cloud sync risk corruption (WAL sidecar files, partial syncs). Plain text doesn't.
- Drive conflicts affect one note per note—readable, easy to arbitrate by eye.
- Main note readers are LLMs and humans; markdown is native for both. JSON's "easier for machines" has no consumer here.
- Scale is personal use (~hundreds per year); grep and FTS5 are plenty; no need for a real database.

### Two-Layer Schema

- **Layer 1 (body)**: Pure text, generic layer readable by any agent. Cross-agent handover uses only this (`load.sh --layer1-only`).
- **Layer 2 (frontmatter)**: Environment metadata (device, branch, working_dir, account, test_status), useful only returning to the same environment.

### Centralized Storage, Not Scattered per Project

Use a `project` field rather than scattering notes across project repos. Reason: half of sessions (discussion, coaching, admin) have no repo. "List all my open notes" (first action when switching devices) needs to span projects.

### Sync via Google Drive, Git for Local History Only

User's explicit choice: single person, multiple devices, concurrent writes almost never happen, Drive convenience wins over explicit git sync. Known tradeoff (accepted): silent staleness during sync—so load.sh prints a staleness header and README reminds about checking sync before switching. Git dir lives outside Drive (`~/Git_repo/handover.git`) because `.git`'s many small files aren't cloud-sync-friendly; git's role is recovery and history, not sync.

### session_type Determines Summary Depth

Four types: sdd / debug / discussion / admin. Key insight: debug's most valuable field is attempted_approaches—"tried this, here's why it failed" matters more than the final solution. sdd has design docs; the note just records progress and deviations.

### No Hibernate

Considered a "save large context, come back later" hibernate command, then rejected. Cache miss just costs money, not data. But keeping large context incurs rot. Hibernate would save (conversation_summary, lessons_learned, attempted_approaches)—all already in Layer 1. Handover + clean restart is never worse than hibernation.

### State Machine: open → done / superseded

"Stale open notes are more dangerous than no notes"—the agent taking over executes stale next steps with full confidence. So taking over requires marking old notes (mark.sh); load defaults to open only.

## Boundaries with Other Mechanisms

| Mechanism | Records | Lifespan |
|---|---|---|
| handover | State (where you got to, next step) | Expires; mark done when used |
| memory / CLAUDE.md | Facts, preferences, project conventions | Long-lived |
| session transcript | Word-by-word process | Local only, not portable |

Lessons learned bridges both: find long-term-applicable lessons in a note, upgrade to memory, remove from note.

## Intentionally Not Implemented

- **SessionStart hook auto-injection**: Easy to pull the wrong note, lightweight sessions don't need it. If needed later, only inject one-liner "you have N open notes", load stays manual.
- **SessionEnd auto-handover**: Forced summaries have poor quality, garbage notes pollute the index. The decision of what's worth remembering belongs to humans.
- **Encryption / Access Control**: Scoped as personal tool; security model is "never write secrets at source" not "protect after the fact".
