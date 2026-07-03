# Handover — Work Continuation System

A tool for cross-device, cross-agent, cross-account work continuation in Claude Code. End a session by creating a structured handover note (markdown synced via Google Drive, SQLite indexed locally), then pick it up on any machine or with any agent.

[繁體中文](README_tw.md)

## Core Design

**Markdown is truth, SQLite is just an index**. Handover notes are individual `.md` files (this folder syncs to all devices via Google Drive); the SQLite FTS5 index lives locally at `~/.cache/handover/index.db` and can be rebuilt anytime. We deliberately keep it off Drive—binary databases over cloud sync risk corruption (WAL sidecar files, partial syncs), while losing the index is harmless.

## Structure

```
handover/
├── SKILL.md          # Claude Code skill definition (triggers & workflow)
├── README.md
├── docs/
│   ├── usage.md      # Complete reference: workflows, commands, format spec, troubleshooting
│   └── design.md     # Design rationale and tradeoffs
├── handovers/        # Handover notes (one .md per note, single source of truth)
└── scripts/
    ├── save.sh       # Save a handover note (from draft file)
    ├── load.sh       # Load a handover note (--layer1-only for cross-agent use)
    ├── list.sh       # List handover notes
    ├── search.sh     # FTS5 full-text search
    ├── mark.sh       # Change status: open/done/superseded
    └── reindex.py    # Rebuild index from md files
```

## Quick Start

```bash
# Hand over (Claude usually handles this: write draft then call)
scripts/save.sh --file draft.md

# Take over
scripts/load.sh --project gmail-billing-scan

# Hand over to another agent (output generic layer only)
scripts/load.sh --project gmail-billing-scan --layer1-only

# List and search
scripts/list.sh
scripts/search.sh "parser"
```

Full reference: [docs/usage.md](docs/usage.md)

## New Device Setup

1. Install Google Drive desktop and wait for this folder to sync. In Drive preferences, set it to **Mirror files** (avoid online-only).
2. Link the skill to Claude Code:

```bash
ln -s "$HOME/Library/CloudStorage/GoogleDrive-<your-email>/My Drive/handover" \
      "$HOME/.claude/skills/handover"
```

3. (Optional) Local git history; see next section.

## Git Version History

This folder is a git worktree, but the git directory lives outside Drive at `~/Git_repo/handover.git` (`.git` is just a pointer file). This is because `.git` contains thousands of small object files—poor fit for cloud sync.

Git's role here is **local version history and recovery**, not sync—Google Drive handles sync. Each machine has independent git history. To enable version history on another machine:

```bash
cd "$HOME/Library/CloudStorage/GoogleDrive-<your-email>/My Drive/handover"
rm .git   # Remove pointer file from other machine (will sync back via Drive, expected)
git init --separate-git-dir "$HOME/Git_repo/handover.git"
git add -A && git commit -m "init on this machine"
```

Note: the `.git` pointer file will sync via Drive. It points to `/Users/<username>/Git_repo/handover.git`—works on any machine if usernames and paths match. On machines where that path doesn't exist, git commands will error, but scripts work fine.

## Important Notes

- Handover notes get pasted into other agents' prompts: **Never write tokens, passwords, or credentials in a note**.
- Drive sync has latency: after switching devices, confirm Drive's sync icon shows complete before `load`, or you'll read stale notes.
- If Drive creates conflict copies (e.g., `xxx (1).md`), both get indexed. Manually pick one to keep—one-file-per-note design means conflicts affect only that one note.

## License

[MIT](LICENSE)
