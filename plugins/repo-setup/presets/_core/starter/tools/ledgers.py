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
  python3 tools/ledgers.py draw [--quiet]
  python3 tools/ledgers.py check
  python3 tools/ledgers.py add-log <text> [--date YYYY-MM-DD]

Exit codes: 0 done, 1 refused (a drawn file is in git, a drawn file edited by hand, a fragment
that is wrong, two sources for one ledger), 2 wrong usage.

Only the Python standard library is used.
"""

from __future__ import annotations

import argparse
import datetime
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


# ---------------------------------------------------------------------------------------------
# The log: wiki/log/YYYY-MM-DD-NN-<slug>.md, one entry each; wiki/log.md is drawn from them.
# ---------------------------------------------------------------------------------------------

LOG_DIR = "wiki/log"
LOG_HEAD = "wiki/log.head.md"
LOG_FILE = "wiki/log.md"
LOG_NAME_RE = re.compile(r"^(?P<date>\d{4}-\d{2}-\d{2})-(?P<nn>\d{2})-(?P<slug>[a-z0-9]+(?:-[a-z0-9]+)*)\.md$")
SLUG_MAX = 40
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
DEFAULT_LOG_HEAD = """---
type: log
title: Change log of the wiki and notable code changes
---

# Log

Newest first. One line each: `YYYY-MM-DD — what changed — link`.
"""


def log_entries(root: Path) -> list[Path]:
    """The files in wiki/log/ that are entries: not .gitkeep, not a *.head.md, not a folder."""
    folder = root / LOG_DIR
    if not folder.is_dir():
        return []
    return sorted(
        (p for p in folder.iterdir() if p.is_file() and p.name != ".gitkeep" and not p.name.endswith(".head.md")),
        key=lambda p: p.name,
    )


def slugify(text: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")[:SLUG_MAX].strip("-")
    return slug or "entry"


def one_line(text: str) -> str:
    return " ".join(text.split())


def next_log_name(root: Path, date: str, text: str) -> str:
    """`<date>-NN-<slug>.md`: NN is one more than the largest NN of that day, two digits."""
    taken = [
        int(m.group("nn"))
        for m in (LOG_NAME_RE.match(p.name) for p in log_entries(root))
        if m and m.group("date") == date
    ]
    return f"{date}-{max(taken, default=0) + 1:02d}-{slugify(text)}.md"


def log_line(path: Path) -> str | None:
    """The drawn line of an entry: `- <date from the file name> — <text>`; None for a wrong name."""
    match = LOG_NAME_RE.match(path.name)
    if match is None:
        return None
    text = one_line(path.read_text(encoding="utf-8"))
    return f"- {match.group('date')} — {text}"


def log_body(root: Path) -> str:
    head_path = root / LOG_HEAD
    head = head_path.read_text(encoding="utf-8") if head_path.is_file() else DEFAULT_LOG_HEAD
    lines = [ln for ln in (log_line(p) for p in reversed(log_entries(root))) if ln is not None]
    return head.rstrip("\n") + "\n\n" + "".join(f"{ln}\n" for ln in lines)


def draw_log(root: Path, quiet: bool) -> int | None:
    """Draw wiki/log.md. None when the log is not kept as fragments (nothing was drawn)."""
    if not (root / "wiki").is_dir() or shape_of(root, "log") != FRAGMENTS:
        return None
    target = root / LOG_FILE
    body = log_body(root)
    current, edited = read_stamped(target)
    if target.is_file() and current is None:
        print(f"{LOG_FILE} is not a drawn file; move it aside (or `git rm --cached {LOG_FILE}` and delete it) "
              f"and run make derived again", file=sys.stderr)
        return 1
    if edited and current is not None:
        # read_stamped gave the body as written; show what was added by hand
        expected = set(body.splitlines())
        added = [ln for ln in current.splitlines() if ln and ln not in expected]
        print(f"{LOG_FILE} was edited by hand; it is drawn from {LOG_DIR}/ and a hand edit is lost.", file=sys.stderr)
        for ln in added:
            print(f"  + {ln}", file=sys.stderr)
        print('Put it in an entry instead: make log m="<text>"', file=sys.stderr)
        return 1
    text = stamp(body, f"{LOG_DIR}/")
    if not target.is_file() or target.read_text(encoding="utf-8") != text:
        target.write_text(text, encoding="utf-8")
        if not quiet:
            print(f"drew {LOG_FILE}")
    return 0


def cmd_draw(args: argparse.Namespace) -> int:
    root = Path(args.root)
    results = [draw_log(root, args.quiet)]
    drawn = [r for r in results if r is not None]
    if not drawn and not args.quiet:
        print("nothing to draw")
    return 1 if any(drawn) else 0


def check_log(root: Path) -> list[str]:
    problems: list[str] = []
    entries = log_entries(root)
    for path in entries:
        if LOG_NAME_RE.match(path.name) is None:
            problems.append(f"{LOG_DIR}/{path.name}: the name is not YYYY-MM-DD-NN-<slug>.md")
    if entries and shape_of(root, "log") == ONE_FILE:
        problems.append(
            f"{LOG_FILE} is kept by hand and {LOG_DIR}/ has entries: two sources for the log; "
            f"git rm --cached {LOG_FILE} and delete it, or move the entries out"
        )
    return problems


def cmd_check(args: argparse.Namespace) -> int:
    problems = check_log(Path(args.root))
    for line in problems:
        print(line, file=sys.stderr)
    return 1 if problems else 0


def add_log_line(root: Path, date: str, text: str) -> None:
    """One-file shape: the new line goes above the newest one, as the hand-kept log is written."""
    path = root / LOG_FILE
    lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
    new = f"- {date} — {text}\n"
    for index, line in enumerate(lines):
        if line.startswith("- "):
            lines.insert(index, new)
            break
    else:
        if lines and not lines[-1].endswith("\n"):
            lines[-1] += "\n"
        if lines and lines[-1].strip():
            lines.append("\n")
        lines.append(new)
    path.write_text("".join(lines), encoding="utf-8")


def cmd_add_log(args: argparse.Namespace) -> int:
    root = Path(args.root)
    text = one_line(args.text)
    date = args.date or datetime.date.today().isoformat()
    if not text:
        print('ledgers.py: add-log needs a text: make log m="<text>"', file=sys.stderr)
        return 2
    if not DATE_RE.match(date):
        print("ledgers.py: --date is YYYY-MM-DD", file=sys.stderr)
        return 2
    if shape_of(root, "log") == ONE_FILE:
        add_log_line(root, date, text)
        print(f"added to {LOG_FILE}")
        return 0
    name = next_log_name(root, date, text)
    (root / LOG_DIR).mkdir(parents=True, exist_ok=True)
    (root / LOG_DIR / name).write_text(text + "\n", encoding="utf-8")
    print(f"wrote {LOG_DIR}/{name}")
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
    draw.add_argument("--quiet", action="store_true", help="print nothing unless a file is refused")
    draw.set_defaults(run=cmd_draw)

    check = sub.add_parser("check", help="fail on a wrong fragment or two sources for a ledger")
    check.set_defaults(run=cmd_check)

    add_log = sub.add_parser("add-log", help="add one entry to the wiki log")
    add_log.add_argument("text")
    add_log.add_argument("--date", help="YYYY-MM-DD (default: today)")
    add_log.set_defaults(run=cmd_add_log)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)  # wrong usage exits 2
    return args.run(args)


if __name__ == "__main__":
    sys.exit(main())
