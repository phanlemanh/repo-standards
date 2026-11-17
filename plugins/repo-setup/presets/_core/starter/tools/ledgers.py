#!/usr/bin/env python3
"""Ledgers kept as fragments: one small file per entry, one drawn file for people to read.

A ledger (the wiki log, the wiki index, the ontology glossary, the code generated from the
ontology) can be kept in one of two shapes:

  one-file   the file at its old path is in git and is edited by hand, as before;
  fragments  the entries live in a folder, one file each, and the old path is drawn from them
             by `make derived` and kept out of git.

This module holds what every ledger shares: reading the shape, the stamp a drawn file opens
with, and the check that a drawn file does not sit in git.

  python3 tools/ledgers.py shape <log|index|glossary|gen> [--gen-out PATH]
  python3 tools/ledgers.py untracked [PATH ...]
  python3 tools/ledgers.py draw

Exit codes: 0 done, 1 refused (a drawn file is in git), 2 wrong usage.

Only the Python standard library is used.
"""

from __future__ import annotations

import argparse
import hashlib
import re
import subprocess
import sys
from pathlib import Path

LEDGERS = ("log", "index", "glossary", "gen")
ONE_FILE = "one-file"
FRAGMENTS = "fragments"

# The file a ledger had before it became fragments. `gen` takes its path from --gen-out: it
# differs by language.
OLD_PATHS = {
    "log": "wiki/log.md",
    "index": "wiki/index.md",
    "glossary": "ontology/glossary.md",
}

STAMP_RE = re.compile(
    r"^<!-- Drawn by tools/ledgers\.py from (?P<source>.+)\. "
    r"Edit the source, not this file\. sha256:(?P<hex>[0-9a-f]{64}) -->$"
)
HASH_MARK = "sha256:"


def _digest(body: str) -> str:
    return hashlib.sha256(body.encode("utf-8")).hexdigest()


def stamp(body: str, source: str) -> str:
    """`body` under the line that says where the file is drawn from, and the hash of `body`."""
    line = f"<!-- Drawn by tools/ledgers.py from {source}. Edit the source, not this file. sha256:{_digest(body)} -->"
    return f"{line}\n{body}"


def read_stamped(path: Path) -> tuple[str | None, bool]:
    """(body, hand-edited) of a drawn file; (None, False) when it is absent or carries no stamp."""
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return None, False
    first, _, body = text.partition("\n")
    match = STAMP_RE.match(first)
    if match is None:
        return None, False
    return body, _digest(body) != match.group("hex")


def _first_line(path: Path) -> str:
    try:
        with path.open(encoding="utf-8") as handle:
            return handle.readline().rstrip("\r\n")
    except (OSError, UnicodeDecodeError):
        return ""


def is_stamped(path: Path) -> bool:
    """The first line is a stamp: the full stamp line for a markdown ledger; for generated code
    (any other file) a comment line that carries a hash is enough."""
    first = _first_line(path)
    if path.suffix == ".md":
        return STAMP_RE.match(first) is not None
    return HASH_MARK in first


def _git(root: Path, *args: str) -> subprocess.CompletedProcess[str] | None:
    try:
        return subprocess.run(
            ["git", "-C", str(root), *args], capture_output=True, text=True, check=False
        )
    except OSError:
        return None


def in_git_repository(root: Path) -> bool:
    done = _git(root, "rev-parse", "--is-inside-work-tree")
    return done is not None and done.returncode == 0 and done.stdout.strip() == "true"


def is_tracked(root: Path, rel: str) -> bool:
    """The path is in the git index (it need not have been committed yet)."""
    done = _git(root, "ls-files", "--error-unmatch", "--", rel)
    return done is not None and done.returncode == 0


def shape_of(root: Path, ledger: str, gen_out: str | None = None) -> str:
    """`one-file` when the old-path file is in git and not a drawn file; otherwise `fragments`.

    Outside a git repository a file that is there and carries no stamp is the old one-file
    ledger. An absent file, an ignored one, one git does not know, and one that is drawn (it
    carries the stamp) all mean fragments.
    """
    rel = gen_out if ledger == "gen" else OLD_PATHS[ledger]
    if not rel:
        return FRAGMENTS
    path = root / rel
    if not path.is_file() or is_stamped(path):
        return FRAGMENTS
    if in_git_repository(root) and not is_tracked(root, rel):
        return FRAGMENTS
    return ONE_FILE


def tracked_and_drawn(root: Path, paths: list[str]) -> list[str]:
    """The paths that are in git although they carry a stamp: drawn files that must stay out."""
    if not in_git_repository(root):
        return []
    return [rel for rel in paths if (root / rel).is_file() and is_stamped(root / rel) and is_tracked(root, rel)]


def cmd_shape(args: argparse.Namespace) -> int:
    if args.ledger == "gen" and not args.gen_out:
        print("ledgers.py: shape gen needs --gen-out PATH", file=sys.stderr)
        return 2
    print(shape_of(Path(args.root), args.ledger, args.gen_out))
    return 0


def cmd_untracked(args: argparse.Namespace) -> int:
    paths = args.paths if args.paths else list(OLD_PATHS.values())
    found = tracked_and_drawn(Path(args.root), paths)
    for rel in found:
        print(f"{rel} is drawn by tools/ledgers.py and must stay out of git: git rm --cached {rel}", file=sys.stderr)
    return 1 if found else 0


def cmd_draw(args: argparse.Namespace) -> int:
    # No ledger is drawn yet: each one is added with the ledger it draws.
    print("nothing to draw")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="ledgers.py", description=__doc__.split("\n")[0])
    parser.add_argument("--root", default=".", help="repository root (default: the current folder)")
    sub = parser.add_subparsers(dest="command", required=True)

    shape = sub.add_parser("shape", help="print one-file or fragments")
    shape.add_argument("ledger", choices=LEDGERS)
    shape.add_argument("--gen-out", help="path of the generated code file (for the gen ledger)")
    shape.set_defaults(run=cmd_shape)

    untracked = sub.add_parser("untracked", help="fail when a drawn file is in git")
    untracked.add_argument("paths", nargs="*", help="the DERIVED_FILES of the repository")
    untracked.set_defaults(run=cmd_untracked)

    draw = sub.add_parser("draw", help="draw every ledger that is kept as fragments")
    draw.set_defaults(run=cmd_draw)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)  # wrong usage exits 2
    return args.run(args)


if __name__ == "__main__":
    sys.exit(main())
