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
  python3 tools/ledgers.py draw-gen --gen-out PATH --gen-lang <ts|python> [--quiet]
  python3 tools/ledgers.py check
  python3 tools/ledgers.py add-log <text> [--date YYYY-MM-DD]
  python3 tools/ledgers.py add-term <Term> --definition <s> [--display <s>]
                                    [--not-confused-with <s>]
  python3 tools/ledgers.py split <log|index|glossary|gen> [--dry-run] [--verify-against FILE]
                                 [--gen-out PATH --gen-lang <ts|python>]

`split` lives in tools/ledgers_split.py.

Exit codes: 0 done, 1 refused (a drawn file is in git, a drawn file edited by hand, a fragment
that is wrong, two sources for one ledger, a split that would lose an entry), 2 wrong usage.

Only the Python standard library is used.
"""

from __future__ import annotations

import argparse
import datetime
import hashlib
import importlib
import re
import subprocess
import sys
import types
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
    line = (
        f"<!-- Drawn by tools/ledgers.py from {source}. Edit the source, not this file. "
        f"sha256:{_digest(body)} -->"
    )
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
        return subprocess.run(  # noqa: S603
            ["git", "-C", str(root), *args],  # noqa: S607
            capture_output=True,
            text=True,
            check=False,
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
    return [
        rel
        for rel in paths
        if (root / rel).is_file() and is_stamped(root / rel) and is_tracked(root, rel)
    ]


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
        print(
            f"{rel} is drawn by tools/ledgers.py and must stay out of git: git rm --cached {rel}",
            file=sys.stderr,
        )
    return 1 if found else 0


# ---------------------------------------------------------------------------------------------
# The log: wiki/log/YYYY-MM-DD-NN-<slug>.md, one entry each; wiki/log.md is drawn from them.
# ---------------------------------------------------------------------------------------------

LOG_DIR = "wiki/log"
LOG_HEAD = "wiki/log.head.md"
LOG_FILE = "wiki/log.md"
LOG_SOURCE = f"{LOG_DIR}/"
LOG_NAME_RE = re.compile(
    r"^(?P<date>\d{4}-\d{2}-\d{2})-(?P<nn>\d{2})-(?P<slug>[a-z0-9]+(?:-[a-z0-9]+)*)\.md$"
)
SLUG_MAX = 40
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
LOG_HOW = 'make log m="<text>"'
DEFAULT_LOG_HEAD = """---
type: log
title: Change log of the wiki and notable code changes
---

# Log

Newest first. One line each: `YYYY-MM-DD — what changed — link`.
"""


def log_entries(root: Path) -> list[Path]:
    """The files in wiki/log/ that are entries: not a hidden file (.gitkeep, .DS_Store), not a
    *.head.md, not a folder."""
    folder = root / LOG_DIR
    if not folder.is_dir():
        return []
    return sorted(
        (
            p
            for p in folder.iterdir()
            if p.is_file() and not p.name.startswith(".") and not p.name.endswith(".head.md")
        ),
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


def lines_not_in(current: str, body: str) -> list[str]:
    """The lines of `current` that `body` does not have (whitespace runs read as one space)."""
    expected = {one_line(line) for line in body.splitlines()}
    return [
        line for line in current.splitlines() if line.strip() and one_line(line) not in expected
    ]


def _sibling(name: str) -> types.ModuleType | None:
    """tools/<name>.py, which imports this module by name; None where the repository has none."""
    sys.modules.setdefault("ledgers", sys.modules[__name__])
    try:
        return importlib.import_module(name)
    except ImportError:
        return None


def hand_edit_refusal(
    rel: str, source: str, added: list[str], how: str, ledger: str | None = None
) -> str:
    """An entry-shaped line goes in with `how`; any other log or glossary line, to its head."""
    read = _sibling("ledgers_split_read")
    heads = read.head_lines(ledger, added) if read and ledger else []
    entries = [line for line in added if line not in heads]
    way = f"move each one: {how} (a changed line: edit its file in {source})"
    lines = read.listing(rel, ledger, entries, heads, way) if read else f"{added}: {way}\n"
    return (
        f"{rel} was edited by hand; it is drawn from {source}, so nothing was written.\n"
        f"{lines}Then delete {rel} and run make derived."
    )


def unstamped_refusal(
    root: Path, rel: str, source: str, ledger: str | None, has_entries: bool, how: str
) -> str:
    """Why an unstamped file that git does not track at a drawn path is not drawn over."""
    both = f" and {source} has entries: two sources for the ledger" if has_entries else ""
    text = (
        f"{rel} is not a drawn file, git does not track it{both}: move {rel} aside, or delete "
        f"{rel} once nothing in it is missing from {source}, then run make derived."
    )
    read = _sibling("ledgers_split_read") if ledger else None
    if read is None:
        return text
    return f"{text}\n{read.unmoved_note(root, ledger, rel, source, how)}"


def draw_ledger(
    root: Path, rel: str, source: str, ledger: str | None, body: str, how: str, quiet: bool
) -> int:
    """Draw one markdown ledger at `rel` from `body`. 0 done, 1 refused. An unstamped file there
    (git does not know it) is refused, never overwritten. A drawn file edited by hand is drawn over
    when every line the edit added is in `body`, else refused with those lines and the way back."""
    target = root / rel
    current, edited = read_stamped(target)
    if target.is_file() and current is None:
        has_entries = bool(ledger and (log_entries if ledger == "log" else glossary_files)(root))
        print(unstamped_refusal(root, rel, source, ledger, has_entries, how), file=sys.stderr)
        return 1
    if edited and current is not None:
        added = lines_not_in(current, body)
        if added:
            print(hand_edit_refusal(rel, source, added, how, ledger), file=sys.stderr)
            return 1
        if not quiet:
            print(f"{rel} was edited by hand; every line the edit added is in {source}: drawn over")
    text = stamp(body, source)
    if not target.is_file() or target.read_text(encoding="utf-8") != text:
        target.write_text(text, encoding="utf-8")
        if not quiet:
            print(f"drew {rel}")
    return 0


def draw_log(root: Path, quiet: bool) -> int | None:
    """Draw wiki/log.md. None when the log is not kept as fragments (nothing was drawn)."""
    if not (root / "wiki").is_dir() or shape_of(root, "log") != FRAGMENTS:
        return None
    return draw_ledger(root, LOG_FILE, LOG_SOURCE, "log", log_body(root), LOG_HOW, quiet)


def cmd_draw(args: argparse.Namespace) -> int:
    root = Path(args.root)
    results = [draw(root, args.quiet) for draw in (draw_log, draw_index, draw_glossary)]
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
            f"{LOG_FILE} is kept by hand and {LOG_DIR}/ has entries: two sources for the log. "
            + two_sources_way(root, "log", LOG_FILE, LOG_DIR, LOG_HOW)
        )
    return problems


def two_sources_way(root: Path, ledger: str, rel: str, folder: str, how: str) -> str:
    """The way out of a tracked hand-kept file beside fragments (tools/ledgers_split_read.py)."""
    read = _sibling("ledgers_split_read")
    if read is None:
        return f"Once every entry of {rel} is in {folder}/: git rm {rel}, then make derived."
    return read.two_sources_way(root, ledger, rel, folder, how)


def cmd_check(args: argparse.Namespace) -> int:
    root = Path(args.root)
    problems = check_log(root) + check_index(root) + check_glossary(root)
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


# ---------------------------------------------------------------------------------------------
# The index: wiki/index.head.md and the wiki pages themselves; wiki/index.md is drawn from them.
# ---------------------------------------------------------------------------------------------

INDEX_HEAD = "wiki/index.head.md"
INDEX_FILE = "wiki/index.md"
INDEX_SOURCE = "wiki/"
PAGE_TYPES_FILE = "ontology/page-types.yaml"
DEFAULT_INDEX_HEAD = """---
type: index
title: Wiki
---

# Wiki

Short, linked pages about the _why_ of this project. Agents read this page
first; keep it under ~60 lines. Page formats: `ontology/page-types.yaml`.
"""
INDEX_LOG_SECTION = "## Log\n\nSee [log.md](log.md) for a chronological list of changes.\n"
TOP_LEVEL_KEY_RE = re.compile(r"^([A-Za-z0-9_][A-Za-z0-9_-]*):")


def page_type_names(root: Path) -> list[str]:
    """The top-level keys of ontology/page-types.yaml, in file order ([] when absent)."""
    try:
        lines = (root / PAGE_TYPES_FILE).read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeDecodeError):
        return []
    names = [m.group(1) for m in (TOP_LEVEL_KEY_RE.match(line) for line in lines) if m]
    return list(dict.fromkeys(names))


def pluralise(name: str) -> str:
    """`metrics` -> Metrics, `entity` -> Entities, `decision` -> Decisions."""
    if name.endswith("s"):
        plural = name
    elif len(name) > 1 and name.endswith("y") and name[-2] not in "aeiou":
        plural = name[:-1] + "ies"
    else:
        plural = name + "s"
    return plural[:1].upper() + plural[1:]


def _unquote(value: str) -> str:
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        return value[1:-1]
    return value


class Page:
    """One wiki page as the index reads it: type, title and the optional summary."""

    def __init__(self, root: Path, path: Path) -> None:
        self.rel = path.relative_to(root / "wiki").as_posix()
        fields, _ = read_fragment(path)
        self.type = _unquote(fields.get("type", ""))
        self.title = one_line(_unquote(fields.get("title", "")))
        self.summary = one_line(_unquote(fields.get("summary", "")))
        self.problem = None
        if not self.type or not self.title:
            self.problem = (
                f"wiki/{self.rel}: page has no type or title "
                "(front matter with type: and title: between --- lines)"
            )

    def line(self) -> str:
        suffix = f" — {self.summary}" if self.summary else ""
        return f"- [{self.title}]({self.rel}){suffix}"


def wiki_pages(root: Path) -> list[Page]:
    """Every page of the wiki the index lists: not the two drawn files, not a *.head.md, not an
    entry of wiki/log/, not a hidden file or anything inside a hidden folder."""
    folder = root / "wiki"
    if not folder.is_dir():
        return []
    pages = []
    for path in sorted(folder.rglob("*.md")):
        parts = path.relative_to(folder).parts
        if (
            not path.is_file()
            or any(part.startswith(".") for part in parts)
            or parts in (("index.md",), ("log.md",))
            or parts[0] == "log"
            or path.name.endswith(".head.md")
        ):
            continue
        pages.append(Page(root, path))
    return pages


def index_body(root: Path) -> str:
    head_path = root / INDEX_HEAD
    head = head_path.read_text(encoding="utf-8") if head_path.is_file() else DEFAULT_INDEX_HEAD
    by_type: dict[str, list[Page]] = {}
    for page in wiki_pages(root):
        if page.problem is None:
            by_type.setdefault(page.type, []).append(page)
    known = page_type_names(root)
    order = known + sorted(t for t in by_type if t not in known)
    sections = []
    for name in order:
        pages = sorted(by_type.get(name, []), key=lambda p: (p.title, p.rel))
        if pages:
            sections.append(f"## {pluralise(name)}\n\n" + "".join(f"{p.line()}\n" for p in pages))
    sections.append(INDEX_LOG_SECTION)
    return head.rstrip("\n") + "\n\n" + "\n".join(sections)


def draw_index(root: Path, quiet: bool) -> int | None:
    """Draw wiki/index.md. None when the index is not kept as fragments (nothing was drawn).

    A page with no type or title is left out and named on stderr; it does not stop the others.
    The index has no fragment folder, so it is never two sources: an unstamped wiki/index.md that
    is not in git (a new repository before its first commit) is left as it is, and so is a head
    file beside a hand-kept one. The head file is no entry.
    """
    if not (root / "wiki").is_dir() or shape_of(root, "index") != FRAGMENTS:
        return None
    if not quiet:
        for page in wiki_pages(root):
            if page.problem:
                print(f"skipped {page.problem}", file=sys.stderr)
    return draw_ledger(
        root,
        INDEX_FILE,
        INDEX_SOURCE,
        None,
        index_body(root),
        f"put it in a page (type, title, summary), or in {INDEX_HEAD} for the part above the "
        "sections",
        quiet,
    )


def check_index(root: Path) -> list[str]:
    """Page problems, in the fragments shape only: a hand-kept index keeps every old rule."""
    if not (root / "wiki").is_dir() or shape_of(root, "index") == ONE_FILE:
        return []
    return [page.problem for page in wiki_pages(root) if page.problem]


# ---------------------------------------------------------------------------------------------
# The glossary: ontology/glossary/<Term>.md, one term each; ontology/glossary.md is drawn from them.
# ---------------------------------------------------------------------------------------------

GLOSSARY_DIR = "ontology/glossary"
GLOSSARY_HEAD = "ontology/glossary.head.md"
GLOSSARY_FILE = "ontology/glossary.md"
GLOSSARY_SOURCE = f"{GLOSSARY_DIR}/"
GLOSSARY_COLUMNS = ("Term (code name)", "Definition", "Not to be confused with", "Display name")
GLOSSARY_COMMENT = "<!-- Add your terms above"
DEFAULT_GLOSSARY_HEAD = """# Glossary

One line per business term. If two people could understand a word differently,
it belongs here. Code, docs and agents must use these exact names.
"""
ADD_TERM_HOW = 'python3 tools/ledgers.py add-term <Term> --definition "<text>"'


class Term:
    """One glossary fragment as read from disk; `problems` is empty when it is well formed."""

    def __init__(self, path: Path) -> None:
        self.path = path
        self.problems: list[str] = []
        fields, self.definition = read_fragment(path)
        self.term = fields.get("term", "")
        self.display = fields.get("display", "")
        self.not_confused_with = fields.get("not_confused_with", "")
        rel = f"{GLOSSARY_DIR}/{path.name}"
        if fields.get("__broken__"):
            self.problems.append(
                f"{rel}: no front matter (lines term:, display:, not_confused_with: between --- "
                "lines)"
            )
            return
        if not self.term:
            self.problems.append(f"{rel}: term is missing")
        elif path.name != f"{self.term}.md":
            self.problems.append(
                f"{rel}: the file name is not the term '{self.term}' ({self.term}.md)"
            )
        if not self.display:
            self.problems.append(f"{rel}: display is missing")
        if not self.definition:
            self.problems.append(
                f"{rel}: the definition (the text after the front matter) is missing"
            )


def read_fragment(path: Path) -> tuple[dict[str, str], str]:
    """(front matter lines `key: value`, body as one line). Front matter is read as wiki_lint reads
    page front matter: between two `---` lines, the standard library only."""
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeDecodeError):
        return {"__broken__": "1"}, ""
    if not lines or lines[0].strip() != "---":
        return {"__broken__": "1"}, ""
    fields: dict[str, str] = {}
    for index in range(1, len(lines)):
        if lines[index].strip() == "---":
            return fields, one_line(" ".join(lines[index + 1 :]))
        key, sep, value = lines[index].partition(":")
        if sep:
            fields[key.strip()] = value.strip()
    return {"__broken__": "1"}, ""


def glossary_files(root: Path) -> list[Path]:
    folder = root / GLOSSARY_DIR
    if not folder.is_dir():
        return []
    return sorted(p for p in folder.iterdir() if p.is_file() and not p.name.startswith("."))


def escape_cell(text: str) -> str:
    return text.replace("|", "\\|")


def glossary_row(term: Term) -> str:
    cells = (f"`{term.term}`", term.definition, term.not_confused_with, term.display)
    return "| " + " | ".join(escape_cell(c) for c in cells) + " |"


def glossary_body(root: Path) -> str:
    head_path = root / GLOSSARY_HEAD
    head = head_path.read_text(encoding="utf-8") if head_path.is_file() else DEFAULT_GLOSSARY_HEAD
    terms = sorted((t for t in map(Term, glossary_files(root)) if t.term), key=lambda t: t.term)
    table = [
        "| " + " | ".join(GLOSSARY_COLUMNS) + " |",
        "| " + " | ".join("---" for _ in GLOSSARY_COLUMNS) + " |",
    ]
    table += [glossary_row(t) for t in terms]
    return head.rstrip("\n") + "\n\n" + "\n".join(table) + "\n"


def draw_glossary(root: Path, quiet: bool) -> int | None:
    """Draw ontology/glossary.md, even with no term (wiki_lint reads it). None if not fragments."""
    if not (root / "ontology").is_dir() or shape_of(root, "glossary") != FRAGMENTS:
        return None
    return draw_ledger(
        root,
        GLOSSARY_FILE,
        GLOSSARY_SOURCE,
        "glossary",
        glossary_body(root),
        ADD_TERM_HOW,
        quiet,
    )


def check_glossary(root: Path) -> list[str]:
    problems: list[str] = []
    files = glossary_files(root)
    for path in files:
        if path.suffix != ".md":
            problems.append(
                f"{GLOSSARY_DIR}/{path.name}: a term is a .md file named after the term"
            )
        else:
            problems += Term(path).problems
    if files and shape_of(root, "glossary") == ONE_FILE:
        problems.append(
            f"{GLOSSARY_FILE} is kept by hand and {GLOSSARY_DIR}/ has terms: two sources for the "
            "glossary. "
            + two_sources_way(root, "glossary", GLOSSARY_FILE, GLOSSARY_DIR, ADD_TERM_HOW)
        )
    return problems


# ---------------------------------------------------------------------------------------------
# The code generated from ontology/: drawn by `make derived`, kept out of git.
# ---------------------------------------------------------------------------------------------

GEN_LANGS = ("ts", "python")


def _ontology():
    """tools/ledgers_ontology.py (add-term, the generated code); it imports this module by name."""
    sys.modules.setdefault("ledgers", sys.modules[__name__])
    import ledgers_ontology

    return ledgers_ontology


def cmd_add_term(args: argparse.Namespace) -> int:
    return _ontology().cmd_add_term(args)


def cmd_draw_gen(args: argparse.Namespace) -> int:
    return _ontology().cmd_draw_gen(args)


def cmd_split(args: argparse.Namespace) -> int:
    ledgers_split = _sibling("ledgers_split")
    if ledgers_split is None:
        print(
            "ledgers.py: tools/ledgers_split.py is missing: this repository keeps no ledger to "
            "split",
            file=sys.stderr,
        )
        return 2
    return ledgers_split.run(args)


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

    draw_gen = sub.add_parser(
        "draw-gen", help="draw the code generated from ontology/ when it is kept as a drawn file"
    )
    draw_gen.add_argument("--gen-out", required=True, help="path of the generated code file")
    draw_gen.add_argument(
        "--gen-lang", required=True, choices=GEN_LANGS, help="language of the generated code"
    )
    draw_gen.add_argument(
        "--quiet", action="store_true", help="print nothing unless a file is refused"
    )
    draw_gen.set_defaults(run=cmd_draw_gen)

    check = sub.add_parser("check", help="fail on a wrong fragment or two sources for a ledger")
    check.set_defaults(run=cmd_check)

    add_log = sub.add_parser("add-log", help="add one entry to the wiki log")
    add_log.add_argument("text")
    add_log.add_argument("--date", help="YYYY-MM-DD (default: today)")
    add_log.set_defaults(run=cmd_add_log)

    add_term = sub.add_parser("add-term", help="add one term to the glossary")
    add_term.add_argument("term")
    add_term.add_argument("--definition", required=True, help="one sentence")
    add_term.add_argument("--display", help="display name (default: the term)")
    add_term.add_argument(
        "--not-confused-with", dest="not_confused_with", help="what the term is not"
    )
    add_term.set_defaults(run=cmd_add_term)

    split = sub.add_parser(
        "split", help="move a one-file ledger into fragments without losing an entry"
    )
    split.add_argument("ledger", choices=LEDGERS)
    split.add_argument(
        "--dry-run", action="store_true", help="print what would be written; write nothing"
    )
    split.add_argument(
        "--verify-against",
        metavar="FILE",
        help="compare the entries of FILE (a copy of the old file) with what the fragments draw; "
        "write nothing",
    )
    split.add_argument("--gen-out", help="path of the generated code file (for the gen ledger)")
    split.add_argument(
        "--gen-lang", choices=GEN_LANGS, help="language of the generated code (for the gen ledger)"
    )
    split.set_defaults(run=cmd_split)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)  # wrong usage exits 2
    return args.run(args)


if __name__ == "__main__":
    sys.exit(main())
