#!/usr/bin/env python3
"""SessionStart hook: in repos set up by repo-setup, tell Claude where the map is.

Silent (no output) in any other repository. Standard library only.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        payload = {}
    root = Path(os.environ.get("CLAUDE_PROJECT_DIR") or payload.get("cwd") or ".").resolve()
    manifest = root / ".repo-setup.json"
    if not manifest.exists() or os.environ.get("REPO_SETUP_HOOKS") == "off":
        return 0
    try:
        setup = json.loads(manifest.read_text())
    except json.JSONDecodeError:
        setup = {}

    lines = [
        f"This repository follows the repo-setup standard "
        f"(preset {setup.get('preset', '?')}, level {setup.get('level', '?')}).",
        "- Agent guide: AGENTS.md / CLAUDE.md. Verify work with `make check` before finishing.",
    ]
    if (root / "wiki" / "index.md").exists():
        lines.append("- Start from wiki/index.md for the why (decisions, incidents, entities).")
    if (root / "ontology" / "glossary.md").exists():
        lines.append(
            "- Business terms: ontology/glossary.md and ontology/entities/*.yaml are the source "
            "of truth; use their names. New/changed concepts: /repo-setup:ontology-add."
        )
    lines.append("- After a task: record the why with /repo-setup:wiki-ingest (at least wiki/log.md).")
    out = {"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "\n".join(lines)}}
    print(json.dumps(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
