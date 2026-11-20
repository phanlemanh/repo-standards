"""Which targets a template file joins to `make check`, and which of them a repository lacks.

A layer joins the gate from its mk/ file, by setting one of the gate's lists: `CHECK_TARGETS +=
name`, `HEAVY_TARGETS += name`, `DERIVED_TARGETS += name`, or, to come first, `CHECK_TARGETS :=
name $(CHECK_TARGETS)`. Where the repository already has a file of its own at that path, apply.py
leaves that file alone, and the targets never run unless the repository joins them itself. A
check that is installed and never runs is no check, so the run says which targets are left out
and does not end well.

Only files under mk/ are read this way: a Makefile of the repository's own is another matter.

Only the Python standard library is used (Python 3.11+).
"""

from __future__ import annotations

import re
from pathlib import Path

FOLDER = "mk"
SETS_A_LIST = re.compile(
    rb"^(?:CHECK_TARGETS|HEAVY_TARGETS|DERIVED_TARGETS)[ \t]*(?:\+|\?|::?)?=[ \t]*(.*)$",
    re.MULTILINE,
)


def joined_targets(content: bytes) -> list[str]:
    """The targets the file puts in the gate's lists, in the order written, each once.

    A line may go on after a backslash; a word that is a variable (`$(CHECK_TARGETS)`) is the
    list itself, not a target.
    """
    text = content.replace(b"\\\r\n", b" ").replace(b"\\\n", b" ")
    words = [
        word.decode("utf-8", "replace")
        for line in SETS_A_LIST.findall(text)
        for word in line.split(b"#")[0].split()
        if not word.startswith(b"$")
    ]
    return list(dict.fromkeys(words))


def _joined_in(root: Path) -> frozenset[str]:
    """Every target the repository's own Makefile and mk/ files join."""
    names: set[str] = set()
    for path in (root / "Makefile", *sorted((root / FOLDER).glob("*.mk"))):
        try:
            names.update(joined_targets(path.read_bytes()))
        except OSError:
            # A file that cannot be read joins nothing: its targets count as left out, which is
            # the loud answer.
            continue
    return frozenset(names)


def left_out(path: str, template: bytes, root: Path) -> list[str]:
    """The targets the template at `path` joins and no file of the repository at `root` does."""
    if not path.startswith(f"{FOLDER}/"):
        return []
    have = _joined_in(root)
    return [name for name in joined_targets(template) if name not in have]


def advice(path: str, targets: list[str]) -> str:
    """What to tell the owner of a repository whose own file sits at `path`."""
    names = ", ".join(targets)
    return (
        f"{path} is this repository's own file, so make check does not run what the setup puts "
        f"there: {names}. Give your file another name in the same folder (every mk/*.mk is "
        "read), then run this again."
    )
