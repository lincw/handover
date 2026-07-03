#!/usr/bin/env python3
"""Rebuild the SQLite index from handover markdown files.

Usage: reindex.py <handovers_dir> <db_path>

The markdown files are the source of truth; this index is a disposable
per-machine cache used for listing and full-text search.
"""
import os
import sqlite3
import sys

FRONT_KEYS = [
    "schema_version", "created_at", "session_type", "status", "project",
    "agent", "device", "account", "branch", "working_dir", "test_status",
]


def parse(path):
    with open(path, encoding="utf-8") as f:
        text = f.read()
    meta, body = {}, text
    if text.startswith("---"):
        end = text.find("\n---", 3)
        if end != -1:
            for line in text[4:end].splitlines():
                if ":" in line:
                    k, v = line.split(":", 1)
                    meta[k.strip()] = v.strip().strip('"')
            body = text[end + 4:].lstrip("\n")
    topic = ""
    for line in body.splitlines():
        if line.startswith("# "):
            topic = line[2:].strip()
            break
    return meta, topic, body


def main():
    handovers_dir, db_path = sys.argv[1], sys.argv[2]
    tmp = db_path + ".tmp"
    if os.path.exists(tmp):
        os.remove(tmp)
    con = sqlite3.connect(tmp)
    con.execute(
        "CREATE TABLE handovers (id TEXT PRIMARY KEY, path TEXT, topic TEXT, "
        + ", ".join(f"{k} TEXT" for k in FRONT_KEYS) + ")"
    )
    con.execute(
        "CREATE VIRTUAL TABLE handovers_fts USING fts5(id, project, topic, body)"
    )
    n = 0
    for name in sorted(os.listdir(handovers_dir)):
        if not name.endswith(".md"):
            continue
        path = os.path.join(handovers_dir, name)
        try:
            meta, topic, body = parse(path)
        except Exception as e:
            print(f"skip {name}: {e}", file=sys.stderr)
            continue
        rid = name[:-3]
        con.execute(
            "INSERT INTO handovers VALUES (?, ?, ?, "
            + ", ".join("?" for _ in FRONT_KEYS) + ")",
            [rid, path, topic] + [meta.get(k, "") for k in FRONT_KEYS],
        )
        con.execute(
            "INSERT INTO handovers_fts VALUES (?, ?, ?, ?)",
            [rid, meta.get("project", ""), topic, body],
        )
        n += 1
    con.commit()
    con.close()
    os.replace(tmp, db_path)
    print(f"indexed {n} handovers -> {db_path}")


if __name__ == "__main__":
    main()
