"""The design ledgers design-assembly writes, as doctor reads them from a repository.

design-assembly is the one writer of a repository's design ledgers; this setup only calls it
(docs/three-repo-boundaries.md). Doctor reads two things the plugin leaves in a repository, and runs
nothing of it:

- the ledgers a repository has from birth, the ones the plugin marks `with-the-floor` in its
  contract (docs/seam-contracts.md, section 6);
- the tool stamp, `design/tool-stamp.json`, which says which version of the plugin wrote the
  repository's copy of its tool.

The version of the installed plugin is given by the caller (`--design-assembly-version`): this
script does not look for plugins on the machine. The notice is never scored.

Only the Python standard library is used (Python 3.11+).
"""

from __future__ import annotations

import json
import re
from pathlib import Path

# Read from design-assembly 0.35.0 (tests/fixtures/design-assembly/seam.json).
BIRTH_LEDGERS = (
    "design/decisions.yaml",
    "design/tokens.json",
    "design/component-registry.json",
    "design/column-types.json",
    "design/states.json",
    "design/screen-sizes.json",
    "design/screens.yaml",
)
TOOL_STAMP = "design/tool-stamp.json"
LAY = "/design-assembly:adopt"
UPGRADE = "/design-assembly:upgrade"


def applies(root: Path, caps: set[str]) -> bool:
    """A repository with the design floor, or one design-assembly already wrote its tool into."""
    return "design" in caps or (root / TOOL_STAMP).is_file()


def _version(text: str | None) -> tuple[int, ...] | None:
    match = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)", text or "")
    return tuple(int(n) for n in match.groups()) if match else None


def stamp_version(root: Path) -> str | None:
    """The version the tool stamp names, or None when there is no stamp or it cannot be read."""
    try:
        version = json.loads((root / TOOL_STAMP).read_text(encoding="utf-8")).get("version")
    except (OSError, ValueError, AttributeError):
        return None
    return str(version) if version else None


def report(root: Path, installed: str | None) -> dict:
    """Missing birth ledgers, the stamp, and whether it is behind the installed plugin. `behind` is
    None when either version is unknown: nothing is guessed. `next` is the plugin's command that
    brings the tool up, only when the stamp is behind."""
    stamp = stamp_version(root)
    have, want = _version(stamp), _version(installed)
    behind = None if have is None or want is None else have < want
    return {
        "missing": [p for p in BIRTH_LEDGERS if not (root / p).exists()],
        "stamp": stamp,
        "installed": installed,
        "behind": behind,
        "next": UPGRADE if behind else None,
    }


def lines(found: dict) -> list[str]:
    """The notice as doctor prints it, or nothing when there is nothing to say."""
    out = []
    if found["missing"]:
        out.append(f"birth ledgers missing ({len(found['missing'])}): {', '.join(found['missing'])}; "
                   f"design-assembly lays them ({LAY})")
    if found["behind"]:
        out.append(f"tool stamp {found['stamp']} is behind the installed plugin "
                   f"{found['installed']}: {UPGRADE}")
    return out
