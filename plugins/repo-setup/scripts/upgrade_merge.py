"""Merge a file the repository edited with the plugin's new template, three ways.

`git merge-file --diff3` does the merge. Where the two sides meet, the file gets conflict markers
labelled so the reader knows which side is which; `tools/upgrade_markers.py` keeps `make check`
red until they are gone. An empty base is a two-way merge: everything that differs is marked.

Only the Python standard library and git are used (Python 3.11+).
"""

from __future__ import annotations

import subprocess
import tempfile
from pathlib import Path

OURS_LABEL = "this repository"
NO_BASE_LABEL = "repo-setup: no matching base"
MERGE_TIMEOUT = 60  # seconds


class MergeUnavailable(Exception):
    """git is missing, or refused the merge (a binary file, for instance)."""


def release_label(version: str) -> str:
    return f"repo-setup {version}"


def three_way(
    current: bytes, base: bytes, new: bytes, base_label: str, new_label: str
) -> tuple[bytes, bool]:
    """(merged content, True when no conflict markers were needed)."""
    if any(b"\x00" in part for part in (current, base, new)):
        raise MergeUnavailable("binary file: git merge-file does not merge it")
    with tempfile.TemporaryDirectory() as tmp:
        paths = []
        for name, data in (("current", current), ("base", base), ("new", new)):
            path = Path(tmp) / name
            path.write_bytes(data)
            paths.append(str(path))
        cmd = ["git", "merge-file", "-p", "--diff3",
               "-L", OURS_LABEL, "-L", base_label, "-L", new_label, *paths]
        try:
            proc = subprocess.run(cmd, capture_output=True, timeout=MERGE_TIMEOUT)
        except (OSError, subprocess.SubprocessError) as exc:
            raise MergeUnavailable(f"cannot run git merge-file: {exc}") from exc
    # git merge-file exits with the number of conflicts, or a negative value on error
    # (seen as 128 and above by a shell).
    if proc.returncode < 0 or proc.returncode >= 128:
        detail = proc.stderr.decode("utf-8", "replace").strip()
        raise MergeUnavailable(f"git merge-file failed: {detail or proc.returncode}")
    return proc.stdout, proc.returncode == 0
