#!/usr/bin/env python3
"""Fail while a file repo-setup manages still holds the conflict markers an upgrade wrote.

When the plugin's new template and an edit made here change the same lines, `apply.py` writes
both into the file between markers. This check keeps `make check` red until they are gone. It
reads only the files listed in .repo-setup.json, so a document that shows a conflict as an
example is not reported.

Only the Python standard library is used.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

MANIFEST = ".repo-setup.json"
OPENING = "<<<<<<< this repository"
CLOSING = ">>>>>>> repo-setup "


def markers(root: Path) -> list[tuple[str, int]]:
    """(path, line number) of each marker line in the files the manifest lists."""
    manifest = root / MANIFEST
    if not manifest.is_file():
        return []
    try:
        files = json.loads(manifest.read_text(encoding="utf-8")).get("files", {})
    except (OSError, json.JSONDecodeError):
        return []
    found = []
    for rel in sorted(files):
        path = root / rel
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for number, line in enumerate(text.splitlines(), start=1):
            # A formatter may indent a marker (a Markdown list goes on): it still counts.
            if line.lstrip(" \t\\").startswith((OPENING, CLOSING)):
                found.append((rel, number))
    return found


def main() -> int:
    found = markers(Path.cwd())
    if not found:
        print("upgrade: no conflict markers")
        return 0
    for rel, number in found:
        print(f"{rel}:{number}: conflict marker from a repo-setup upgrade")
    print(
        "Merge each marked part by hand (keep what this repository needs and what the new "
        "template brings), delete the marker lines, then run make check again.",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
