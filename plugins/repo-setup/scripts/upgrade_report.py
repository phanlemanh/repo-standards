"""Which files of a repository drift from the plugin, read from .repo-setup.json and the files.

Used by doctor.py. Nothing is downloaded: the manifest records, per file, the hash of what the
plugin wrote and the release it came from.

Only the Python standard library is used (Python 3.11+).
"""

from __future__ import annotations

import hashlib
from dataclasses import dataclass, field
from pathlib import Path

from upgrade_base import version_key
from upgrade_merge import OURS_LABEL, release_label

OPENING = f"<<<<<<< {OURS_LABEL}"
CLOSING = f">>>>>>> {release_label('')}"
WALL = "mk/upgrade.mk"
INCLUDES = ("-include mk/*.mk", "include mk/*.mk", "-include mk/upgrade.mk", "include mk/upgrade.mk")


@dataclass(frozen=True)
class UpgradeReport:
    edited: list[str] = field(default_factory=list)
    behind: list[tuple[str, str]] = field(default_factory=list)
    removed: list[str] = field(default_factory=list)
    marked: list[tuple[str, int]] = field(default_factory=list)
    plugin_version: str = ""

    def as_dict(self) -> dict:
        return {
            "edited": self.edited,
            "behind": [list(b) for b in self.behind],
            "removed": self.removed,
            "marked": [list(m) for m in self.marked],
            "plugin_version": self.plugin_version,
        }


def _marker_lines(path: Path) -> list[int]:
    text = path.read_text(encoding="utf-8", errors="replace")
    return [n for n, line in enumerate(text.splitlines(), start=1)
            if line.startswith(OPENING) or line.startswith(CLOSING)]


def report(root: Path, setup: dict) -> UpgradeReport:
    """Edited in place, behind the last release that ran, deleted, and still marked."""
    files: dict[str, str] = setup.get("files") or {}
    versions: dict[str, str] = setup.get("file_versions") or {}
    last = str(setup.get("version", ""))
    edited, behind, removed, marked = [], [], [], []
    for rel in sorted(files):
        path = root / rel
        if not path.is_file():
            removed.append(rel)
            continue
        data = path.read_bytes()
        if hashlib.sha256(data).hexdigest() != files[rel]:
            edited.append(rel)
            marked += [(rel, n) for n in _marker_lines(path)]
        version = versions.get(rel, last)
        mine, theirs = version_key(version), version_key(last)
        if mine is not None and theirs is not None and mine < theirs:
            behind.append((rel, version))
    return UpgradeReport(edited, behind, removed, marked, last)


def wall_present(root: Path) -> bool:
    """mk/upgrade.mk exists and the Makefile includes it."""
    makefile = root / "Makefile"
    if not (root / WALL).is_file() or not makefile.is_file():
        return False
    text = makefile.read_text(encoding="utf-8", errors="replace")
    return any(line.strip() in INCLUDES for line in text.splitlines())
