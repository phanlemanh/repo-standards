"""`ledgers.py split <ledger>`: move a one-file ledger into fragments without losing an entry.

Run once per ledger, in a pull request of its own. Everything is worked out in memory first: the
old file is read into entries and the part that is no entry (the head); the fragments, the head
file and any page edit are written into a scratch copy of wiki/ and ontology/; the real drawer of
tools/ledgers.py draws the ledger there; the drawn text is read back into entries. The split goes
ahead only when the entries before and after are the same, each word for word. The order may
change: every entry that moved is printed. Then, and only then, the files are written, the old
file leaves git (`git rm --cached`), its path goes into .gitignore and the drawn file takes its
place.

  log       an entry is a line `- YYYY-MM-DD — <text>`; the rest goes to wiki/log.head.md
  glossary  an entry is a row of the four-column table; the rest goes to ontology/glossary.head.md
  index     an entry is a line `- [title](page)` (plus ` — <description>`) that points to a page;
            the description moves to the `summary` key of that page, the rest to wiki/index.head.md
  gen       no fragments: the generated file leaves git and is drawn, stamped

A head file that is already there is overwritten only while it is as repo-setup wrote it (its
sha256 is the one .repo-setup.json records for it). Once split rewrites it, it is taken out of
.repo-setup.json: the head file is the repository's own, and a later repo-setup run keeps it.
"""

from __future__ import annotations

import argparse
import collections
import difflib
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from collections.abc import Callable
from dataclasses import dataclass, field
from pathlib import Path

import ledgers as led
import ledgers_ontology as ont

MANIFEST = ".repo-setup.json"
LOG_ENTRY_RE = re.compile(r"^- (?P<date>\d{4}-\d{2}-\d{2}) — (?P<text>.*\S)\s*$")
LOG_LIKE_RE = re.compile(r"^\s*[-*+] \d{4}-\d{2}-\d{2}\b")
LINK_RE = re.compile(
    r"^(?P<indent>\s*)(?P<bullet>[-*+]) \[(?P<title>[^\]]*)\]\((?P<target>[^)\s]+)\)(?P<rest>.*)$"
)
HEADING_RE = re.compile(r"^## (?P<name>.+?)\s*$")
SEPARATOR_RE = re.compile(r"^\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)*\|?\s*$")
CELL_SPLIT_RE = re.compile(r"(?<!\\)\|")
EXAMPLE_MARK = "_Example:_"
LOG_SENTENCE = led.INDEX_LOG_SECTION.splitlines()[-1]
MAX_PER_DAY = 99
FIX_HINTS = {
    "log": 'run make log m="<text>" again on that branch',
    "glossary": "run python3 tools/ledgers.py add-term again on that branch",
    "index": "take the deletion on that branch: a new page needs only a type and a title (and a "
    "summary) to be listed",
    "gen": "take the deletion on that branch (git rm --cached the file); make derived draws it",
}


@dataclass
class Plan:
    """What a split writes, and what the comparison finds. Nothing here has touched the disk."""

    ledger: str
    old: str
    head: str = ""
    writes: dict[str, str] = field(default_factory=dict)
    edited_pages: list[str] = field(default_factory=list)
    notes: list[str] = field(default_factory=list)
    problems: list[str] = field(default_factory=list)
    entries: list[str] = field(default_factory=list)


# ---------------------------------------------------------------------------------------------
# Shared reading helpers
# ---------------------------------------------------------------------------------------------


def comment_flags(lines: list[str]) -> list[bool]:
    """For each line, whether it sits inside an HTML comment that spans several lines."""
    flags, inside = [], False
    for line in lines:
        stripped = line.strip()
        opens = stripped.startswith("<!--")
        flags.append(inside or (opens and "-->" not in stripped))
        if inside and "-->" in stripped:
            inside = False
        elif opens and "-->" not in stripped:
            inside = True
    return flags


def assemble_head(lines: list[str], kept: list[bool]) -> tuple[str, list[str]]:
    """The head from the lines that stay (`kept`): the lines above the first one that leaves, as
    they are, then each later block of kept lines, one blank line apart. Also the first line of
    each later block: it now sits above the entries."""
    first_gone = next((i for i, keep in enumerate(kept) if not keep), len(lines))
    head = lines[:first_gone]
    while head and not head[-1].strip():
        head.pop()
    blocks, block = [], []
    for line, keep in zip(lines[first_gone:], kept[first_gone:], strict=False):
        if keep and line.strip():
            block.append(line)
        elif block:
            blocks.append(block)
            block = []
    if block:
        blocks.append(block)
    for b in blocks:
        head += ([""] if head else []) + b
    return "\n".join(head) + "\n" if head else "", [b[0] for b in blocks]


def moved(before: list[str], after: list[str]) -> list[str]:
    """The entries of `before` that do not keep their place in `after`."""
    matcher = difflib.SequenceMatcher(None, before, after, autojunk=False)
    kept = {i for a, _, n in matcher.get_matching_blocks() for i in range(a, a + n)}
    present = set(after)
    return [entry for i, entry in enumerate(before) if i not in kept and entry in present]


def entries_word(count: int) -> str:
    return f"{count} {'entry' if count == 1 else 'entries'}"


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def manifest_hash(root: Path, rel: str) -> str | None:
    try:
        data = json.loads((root / MANIFEST).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    files = data.get("files") if isinstance(data, dict) else None
    return files.get(rel) if isinstance(files, dict) else None


def manifest_without(root: Path, rels: list[str]) -> str | None:
    """The text of .repo-setup.json without the entries for `rels` (`files` and `file_versions`);
    None when there is no manifest to read or it records none of them. A head file that split
    rewrites is the repository's own from then on: a later repo-setup run keeps it."""
    try:
        data = json.loads((root / MANIFEST).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    if not isinstance(data, dict):
        return None
    found = False
    for key in ("files", "file_versions"):
        section = data.get(key)
        if isinstance(section, dict):
            for rel in rels:
                found = section.pop(rel, None) is not None or found
    return json.dumps(data, indent=2, ensure_ascii=False) + "\n" if found else None


# ---------------------------------------------------------------------------------------------
# The log
# ---------------------------------------------------------------------------------------------


def parse_log(text: str) -> tuple[list[tuple[str, str]], str, list[str], list[str]]:
    """(entries as (date, text) top to bottom, head, notes, problems). The text is in the form
    add-log writes and the drawer draws: every run of whitespace one space."""
    lines = text.splitlines()
    entries, kept, problems, collapsed = [], [], [], []
    for number, (line, in_comment) in enumerate(
        zip(lines, comment_flags(lines), strict=True), start=1
    ):
        match = None if in_comment else LOG_ENTRY_RE.match(line)
        if match:
            flat = led.one_line(match.group("text"))
            entries.append((match.group("date"), flat))
            if flat != match.group("text"):
                collapsed.append(f"whitespace collapsed: {match.group('date')} — {flat}")
        elif not in_comment and LOG_LIKE_RE.match(line):
            problems.append(
                f"line {number} looks like a log entry but is not '- YYYY-MM-DD — <text>': {line}"
            )
        kept.append(match is None)
    head, raised = assemble_head(lines, kept)
    notes = collapsed + [f"moved to {led.LOG_HEAD}, above the entries: {first}" for first in raised]
    return entries, head, notes, problems


def plan_log(root: Path, text: str) -> Plan:
    plan = Plan("log", led.LOG_FILE)
    if led.log_entries(root):
        plan.problems.append(
            f"{led.LOG_FILE} is kept by hand and {led.LOG_DIR}/ has entries: two sources for the "
            "log; move the entries into one of them by hand, then split"
        )
    entries, plan.head, plan.notes, problems = parse_log(text)
    plan.problems += problems
    per_day = collections.Counter(date for date, _ in entries)
    for date, count in sorted(per_day.items()):
        if count > MAX_PER_DAY:
            plan.problems.append(
                f"{date} has {count} entries; a fragment name holds at most {MAX_PER_DAY} a day "
                "(NN is two digits)"
            )
    seen: collections.Counter[str] = collections.Counter()
    for date, entry in entries:
        seen[date] += 1
        number = (
            per_day[date] - seen[date] + 1
        )  # the top line of a day is its newest: the highest NN
        name = f"{date}-{number:02d}-{led.slugify(entry)}.md"
        plan.writes[f"{led.LOG_DIR}/{name}"] = entry + "\n"
        plan.entries.append(f"{date} — {entry}")
    plan.writes[led.LOG_HEAD] = plan.head
    return plan


def drawn_log_entries(body: str) -> list[str]:
    return [f"{d} — {t}" for d, t in parse_log(body)[0]]


# ---------------------------------------------------------------------------------------------
# The glossary
# ---------------------------------------------------------------------------------------------


def split_cells(line: str) -> list[str]:
    inner = line.strip()
    inner = inner[1:] if inner.startswith("|") else inner
    inner = inner[:-1] if inner.endswith("|") and not inner.endswith("\\|") else inner
    return [cell.strip().replace("\\|", "|") for cell in CELL_SPLIT_RE.split(inner)]


def find_table(lines: list[str]) -> int | None:
    """The index of the header row of the glossary table, or None."""
    for i, line in enumerate(lines):
        is_header = (
            line.lstrip().startswith("|") and tuple(split_cells(line)) == led.GLOSSARY_COLUMNS
        )
        if is_header and i + 1 < len(lines) and SEPARATOR_RE.match(lines[i + 1].strip()):
            return i
    return None


def row_entry(cells: list[str]) -> tuple[tuple[str, str, str, str], list[str]]:
    """A row in the form add-term writes: every run of whitespace in a cell one space, the display
    name the term when the cell is empty. Also a notice for each such change."""
    term = cells[0]
    if len(term) >= 2 and term.startswith("`") and term.endswith("`"):
        term = term[1:-1].strip()
    definition, not_confused_with, display = (led.one_line(cell) for cell in cells[1:])
    notes = []
    if (definition, not_confused_with, display) != tuple(cells[1:]):
        notes.append(
            "whitespace collapsed: "
            f"{entry_text((term, definition, not_confused_with, display or term))}"
        )
    if not display and term:
        display = term
        notes.append(f"display set to term: {term}")
    return (term, definition, not_confused_with, display), notes


def entry_text(entry: tuple[str, str, str, str]) -> str:
    """A row as one line, a pipe inside a cell escaped as the table writes it."""
    return "`{}` | {} | {} | {}".format(*(led.escape_cell(cell) for cell in entry))


def parse_glossary(text: str) -> tuple[list[tuple[str, str, str, str]], str, list[str], list[str]]:
    """(rows as (term, definition, not confused with, display), head, notes, problems)."""
    lines = text.splitlines()
    start = find_table(lines)
    end = start + 2 if start is not None else 0
    while start is not None and end < len(lines) and lines[end].lstrip().startswith("|"):
        end += 1
    rows, kept, notes, problems = [], [True] * len(lines), [], []
    for i, line in enumerate(lines):
        in_table = start is not None and start <= i < end
        if in_table:
            kept[i] = False
            if i >= start + 2:
                cells = split_cells(line)
                if len(cells) != len(led.GLOSSARY_COLUMNS):
                    problems.append(
                        f"line {i + 1} is a row of {len(cells)} cells, not "
                        f"{len(led.GLOSSARY_COLUMNS)}: {line}"
                    )
                elif cells[0].startswith(EXAMPLE_MARK):
                    notes.append(
                        f"dropped the template's example row ({EXAMPLE_MARK}): {line.strip()}"
                    )
                else:
                    row, row_notes = row_entry(cells)
                    rows.append(row)
                    notes += row_notes
        elif line.lstrip().startswith("|"):
            problems.append(
                f"line {i + 1} is a table row outside the glossary table "
                f"(| {' | '.join(led.GLOSSARY_COLUMNS)} |): {line}"
            )
        elif line.startswith(led.GLOSSARY_COMMENT):
            kept[i] = False
            notes.append(f"dropped the template's comment: {line.strip()}")
    head, raised = assemble_head(lines, kept)
    notes += [f"moved to {led.GLOSSARY_HEAD}, above the table: {first}" for first in raised]
    return rows, head, notes, problems


def term_problems(rows: list[tuple[str, str, str, str]]) -> list[str]:
    problems, seen = [], {}
    for term, definition, _, _ in rows:
        bad = ont.bad_term_character(term) if term else None
        if not term:
            problems.append(f"a row has no term (definition: {definition})")
        elif bad is not None:
            problems.append(
                f"the term '{term}' cannot be a file name "
                f"({'a leading dot' if bad == '.' else repr(bad)}); rename it in the table"
            )
        elif term.casefold() in seen:
            problems.append(
                f"the terms '{seen[term.casefold()]}' and '{term}' would be one file name "
                f"({term}.md)"
            )
        else:
            seen[term.casefold()] = term
        if term and not definition:
            problems.append(f"the term '{term}' has no definition; a fragment needs one")
    return problems


def plan_glossary(root: Path, text: str) -> Plan:
    plan = Plan("glossary", led.GLOSSARY_FILE)
    if led.glossary_files(root):
        plan.problems.append(
            f"{led.GLOSSARY_FILE} is kept by hand and {led.GLOSSARY_DIR}/ has terms: two sources "
            "for the "
            "glossary; move the terms into one of them by hand, then split"
        )
    rows, plan.head, plan.notes, problems = parse_glossary(text)
    plan.problems += problems + term_problems(rows)
    if find_table(text.splitlines()) is None and not rows:
        plan.notes.append(
            f"{led.GLOSSARY_FILE} has no table with the header "
            f"| {' | '.join(led.GLOSSARY_COLUMNS)} |: "
            "no term to move"
        )
    for term, definition, not_confused_with, display in rows:
        plan.writes[f"{led.GLOSSARY_DIR}/{term}.md"] = ont.term_fragment(
            term, display, not_confused_with, definition
        )
        plan.entries.append(entry_text((term, definition, not_confused_with, display)))
    plan.writes[led.GLOSSARY_HEAD] = plan.head
    return plan


def drawn_glossary_entries(body: str) -> list[str]:
    return [entry_text(row) for row in parse_glossary(body)[0]]


# ---------------------------------------------------------------------------------------------
# The index
# ---------------------------------------------------------------------------------------------


@dataclass(frozen=True)
class Link:
    rel: str
    title: str
    description: str
    line: int


def page_rel(root: Path, target: str) -> str | None:
    """The path of `target` relative to wiki/, when it is a relative link into wiki/; else None."""
    target = target.split("#", 1)[0]
    if not target or "://" in target or target.startswith(("/", "mailto:")):
        return None
    wiki = (root / "wiki").resolve()
    try:
        return (wiki / target).resolve().relative_to(wiki).as_posix()
    except ValueError:
        return None


def drawn_headings(root: Path, pages: dict[str, led.Page]) -> set[str]:
    """The `## ` headings the drawn index has, or will have once a page of that type exists."""
    types = set(led.page_type_names(root)) | {p.type for p in pages.values() if p.type}
    return {led.pluralise(t) for t in types} | {"Log"}


def parse_index(
    root: Path, text: str, pages: dict[str, led.Page], strict: bool
) -> tuple[list[Link], str, list[str], list[str]]:
    """(links to pages, head, notes, problems). With `strict`, a link to a wiki .md file that is no
    page any more is still an entry (it is lost), as the comparison needs."""
    lines = text.splitlines()
    headings = drawn_headings(root, pages)
    links, kept, problems, collapsed = [], [], [], []
    for number, (line, in_comment) in enumerate(
        zip(lines, comment_flags(lines), strict=True), start=1
    ):
        keep = True
        heading = None if in_comment else HEADING_RE.match(line)
        match = None if in_comment else LINK_RE.match(line)
        rel = page_rel(root, match.group("target")) if match else None
        is_page = rel is not None and (
            rel in pages or (strict and rel.endswith(".md") and rel not in ("index.md", "log.md"))
        )
        if (heading and heading.group("name") in headings) or line.strip() == LOG_SENTENCE:
            keep = False
        elif match and is_page:
            keep = False
            rest = match.group("rest")
            if (
                match.group("indent")
                or match.group("bullet") != "-"
                or not (rest.strip() in ("", "—") or rest.startswith(" — "))
            ):
                problems.append(
                    f"line {number} links the page {rel} but is not '- "
                    f"[title]({match.group('target')}) — <description>'; "
                    f"write it so, then split: {line}"
                )
            raw = rest[3:].strip() if rest.startswith(" — ") else ""
            description = led.one_line(raw)
            if description != raw:
                collapsed.append(f"whitespace collapsed: wiki/{rel} — {description}")
            links.append(Link(rel, match.group("title"), description, number))
        kept.append(keep)
    head, raised = assemble_head(lines, kept)
    notes = collapsed + [
        f"kept in {led.INDEX_HEAD}, above the sections: {first}" for first in raised
    ]
    return links, head, notes, problems


def merge_links(links: list[Link]) -> tuple[dict[str, Link], list[str], list[str]]:
    """One link per page. A page linked twice keeps its description; two descriptions is refused."""
    by_rel: dict[str, Link] = {}
    notes, problems = [], []
    for link in links:
        first = by_rel.get(link.rel)
        if first is None:
            by_rel[link.rel] = link
            continue
        notes.append(
            f"wiki/{link.rel} is linked again on line {link.line}; the drawn index lists it once"
        )
        if link.description and first.description and link.description != first.description:
            problems.append(
                f"wiki/{link.rel} is linked on lines {first.line} and {link.line} with two "
                "descriptions; keep one, then split"
            )
        elif link.description and not first.description:
            by_rel[link.rel] = link
    return by_rel, notes, problems


def summary_value(text: str) -> str:
    """The text as a front matter value that reads back the same (ledgers.py strips one pair
    of quotes)."""
    if len(text) >= 2 and text[0] == text[-1] and text[0] in "\"'":
        quote = "'" if text[0] == '"' else '"'
        return f"{quote}{text}{quote}"
    return text


def with_summary(text: str, summary: str) -> str:
    """The page with `summary:` set in its front matter; every other byte of it as it was."""
    lines = text.splitlines(keepends=True)
    end = next(i for i in range(1, len(lines)) if lines[i].strip() == "---")
    newline = "\r\n" if lines[0].endswith("\r\n") else "\n"
    new = f"summary: {summary_value(summary)}{newline}"
    found = [
        i
        for i in range(1, end)
        if ":" in lines[i] and lines[i].partition(":")[0].strip() == "summary"
    ]
    if not found:
        return "".join([*lines[:end], new, *lines[end:]])
    lines[found[0]] = new
    return "".join(line for i, line in enumerate(lines) if i not in found[1:])


def plan_index(root: Path, text: str) -> Plan:
    plan = Plan("index", led.INDEX_FILE)
    pages = {page.rel: page for page in led.wiki_pages(root)}
    links, plan.head, plan.notes, plan.problems = parse_index(root, text, pages, strict=False)
    by_rel, notes, problems = merge_links(links)
    plan.notes += notes
    plan.problems += problems
    for rel, link in by_rel.items():
        page = pages[rel]
        if page.problem:
            plan.problems.append(
                f"{page.problem}: the index links it, and the drawn index would leave it out"
            )
            continue
        if link.title != page.title:
            plan.notes.append(
                f"wiki/{rel}: the drawn line shows the page title '{page.title}', not "
                f"'{link.title}'"
            )
        if link.description and link.description != page.summary:
            path = root / "wiki" / rel
            plan.writes[f"wiki/{rel}"] = with_summary(
                path.read_text(encoding="utf-8"), link.description
            )
            plan.edited_pages.append(f"wiki/{rel}")
            if page.summary:
                plan.notes.append(
                    f"wiki/{rel}: summary '{page.summary}' replaced by the description of the index"
                )
    for rel, page in sorted(pages.items()):
        if rel not in by_rel and page.problem is None:
            plan.notes.append(
                f"added: wiki/{rel} (no line of the old index linked it; the drawn index lists "
                "every page)"
            )
    plan.entries = [f"{rel} — {link.description}" for rel, link in by_rel.items()]
    plan.writes[led.INDEX_HEAD] = plan.head
    return plan


def compare_index(
    root: Path, before_text: str, drawn: str, scratch: Path, strict: bool
) -> tuple[list[str], list[str], list[str]]:
    """(notes, problems, moved) for the index: every page linked before is linked after, with the
    same description. Pages the old index did not link may be added. With `strict` (a check after
    the split) a link to a wiki .md file that is no page any more counts as an entry, and is
    lost."""
    old_pages = {page.rel: page for page in led.wiki_pages(root)}
    new_pages = {page.rel: page for page in led.wiki_pages(scratch)}
    before, _, _, _ = parse_index(root, before_text, old_pages, strict=strict)
    after, _, _, _ = parse_index(scratch, drawn, new_pages, strict=False)
    old, _, _ = merge_links(before)
    new = {link.rel: link for link in after}
    notes, problems = [], []
    for rel, link in old.items():
        if rel not in new:
            problems.append(
                "lost: - "
                f"[{link.title}]({rel}){' — ' + link.description if link.description else ''}"
            )
        elif link.description and new[rel].description != link.description:
            problems.append(
                f"changed: wiki/{rel}: '{link.description}' is drawn as '{new[rel].description}'"
            )
        elif not link.description and new[rel].description:
            notes.append(
                f"wiki/{rel}: the drawn line shows the summary the page already had: "
                f"{new[rel].description}"
            )
    order_after = [link.rel for link in after if link.rel in old]
    return notes, problems, [f"wiki/{rel}" for rel in moved(list(old), order_after)]


# ---------------------------------------------------------------------------------------------
# Drawing in a scratch copy, and the comparison
# ---------------------------------------------------------------------------------------------

BODIES: dict[str, Callable[[Path], str]] = {
    "log": led.log_body,
    "index": led.index_body,
    "glossary": led.glossary_body,
}
SOURCES = {"log": led.LOG_SOURCE, "index": led.INDEX_SOURCE, "glossary": led.GLOSSARY_SOURCE}
PLANNERS: dict[str, Callable[[Path, str], Plan]] = {
    "log": plan_log,
    "index": plan_index,
    "glossary": plan_glossary,
}
DRAWN_ENTRIES: dict[str, Callable[[str], list[str]]] = {
    "log": drawn_log_entries,
    "glossary": drawn_glossary_entries,
}


def draw_in_scratch(root: Path, writes: dict[str, str], scratch: Path) -> None:
    """A copy of wiki/ and ontology/ under `scratch`, with the planned files written into it."""
    for folder in ("wiki", "ontology"):
        if (root / folder).is_dir():
            shutil.copytree(root / folder, scratch / folder, symlinks=True)
    for rel, text in writes.items():
        (scratch / rel).parent.mkdir(parents=True, exist_ok=True)
        (scratch / rel).write_text(text, encoding="utf-8")


def compare(
    ledger: str, root: Path, before_text: str, before: list[str], drawn: str, scratch: Path
) -> tuple[list[str], list[str], list[str]]:
    """(notes, problems, moved) of the entries `before` against the ones read back from `drawn`."""
    if ledger == "index":
        return compare_index(root, before_text, drawn, scratch, strict=False)
    after = DRAWN_ENTRIES[ledger](drawn)
    lost = collections.Counter(before) - collections.Counter(after)
    extra = collections.Counter(after) - collections.Counter(before)
    problems = [f"lost: {entry}" for entry in lost.elements()] + [
        f"extra: {entry}" for entry in extra.elements()
    ]
    return [], problems, moved(before, after)


def check_heads(root: Path, plan: Plan) -> list[str]:
    """A head file that is there is overwritten only while it is as repo-setup wrote it."""
    rel = next((r for r in plan.writes if r.endswith(".head.md")), None)
    path = root / rel if rel else None
    if path is None or not path.is_file() or path.read_text(encoding="utf-8") == plan.writes[rel]:
        return []
    if manifest_hash(root, rel) == sha256_file(path):
        plan.notes.append(f"{rel} is as repo-setup wrote it: it is overwritten")
        return []
    return [
        f"{rel} is there and was changed since repo-setup wrote it (or repo-setup did not write "
        "it); "
        f"split would overwrite it. Put what it says into the head of {plan.old}, delete {rel}, "
        "then split"
    ]


# ---------------------------------------------------------------------------------------------
# Printing and writing
# ---------------------------------------------------------------------------------------------


def print_plan(plan: Plan, dry: bool) -> None:
    would = "would " if dry else ""
    print(
        f"split {plan.ledger}: {plan.old} has "
        f"{entries_word(len(plan.entries))}{' (dry run: nothing is written)' if dry else ''}"
    )
    for rel in sorted(plan.writes):
        what = "edit" if rel in plan.edited_pages else "write"
        print(f"  {would}{what} {rel}{' (summary)' if what == 'edit' else ''}")
    print(
        f"  {would}remove {plan.old} from git (git rm --cached), add {plan.old} to .gitignore, and "
        "draw it"
    )


def print_comparison(count: int, notes: list[str], moved_entries: list[str]) -> None:
    print(f"compare: {entries_word(count)} before and after, each word for word")
    for entry in moved_entries:
        print(f"  moved: {entry}")
    for note in notes:
        print(f"  {note}")


def refuse(ledger: str, problems: list[str], what: str = "refused, nothing was written") -> int:
    print(f"split {ledger}: {what}:", file=sys.stderr)
    for problem in problems:
        print(f"  {problem}", file=sys.stderr)
    return 1


def leave_git(root: Path, rel: str) -> tuple[bool, str | None]:
    """`git rm --cached` of `rel` when git tracks it: (whether it left git, the error or None)."""
    if not (led.in_git_repository(root) and led.is_tracked(root, rel)):
        return False, None
    done = subprocess.run(  # noqa: S603
        ["git", "-C", str(root), "rm", "--cached", "-q", "--", rel],  # noqa: S607
        capture_output=True,
        text=True,
        check=False,
    )
    if done.returncode == 0:
        return True, None
    return False, done.stderr.strip() or f"git rm --cached {rel} failed"


def ignored_text(root: Path, rel: str) -> str | None:
    """The new text of .gitignore with a line for `rel`, or None when it has the line already."""
    path = root / ".gitignore"
    text = path.read_text(encoding="utf-8") if path.exists() else ""
    if {rel, "/" + rel} & {line.strip() for line in text.splitlines()}:
        return None
    return text + ("" if not text or text.endswith("\n") else "\n") + rel + "\n"


def target_problem(root: Path, rel: str) -> str | None:
    """Why `rel` cannot be written, or None."""
    path = root / rel
    if path.exists():
        if not path.is_file():
            return f"{rel} is there and is not a file"
        return (
            None if os.access(path, os.W_OK) else f"{rel} cannot be written (no write permission)"
        )
    parent = path.parent
    while not parent.exists():
        parent = parent.parent
    if not parent.is_dir() or not os.access(parent, os.W_OK | os.X_OK):
        where = parent.relative_to(root).as_posix() or "."
        return f"{rel} cannot be created ({where} cannot be written)"
    return None


def prepare(
    root: Path, old: str, writes: dict[str, str], drawn: str
) -> tuple[dict[str, str], list[str]]:
    """Every file the split writes, with its whole new text (the fragments, the head, the pages,
    .gitignore, and last the drawn file at the old path), and why any of them cannot be written."""
    files = dict(writes)
    try:
        gitignore = ignored_text(root, old)
    except (OSError, UnicodeDecodeError) as error:
        return files, [f".gitignore cannot be read: {error}"]
    if gitignore is not None:
        files[".gitignore"] = gitignore
    manifest = manifest_without(root, [rel for rel in writes if rel.endswith(".head.md")])
    if manifest is not None:
        files[MANIFEST] = manifest
    files[old] = drawn
    return files, [problem for rel in files if (problem := target_problem(root, rel))]


def write_file(path: Path, text: str, created: list[Path]) -> None:
    """Write `path`, noting in `created` each folder made for it, so that undo can remove them."""
    missing = []
    parent = path.parent
    while not parent.exists():
        missing.append(parent)
        parent = parent.parent
    for folder in reversed(missing):
        folder.mkdir()
        created.append(folder)
    path.write_text(text, encoding="utf-8")


def undo(
    root: Path, old: str, left_git: bool, originals: dict[str, bytes | None], created: list[Path]
) -> list[str]:
    """Put back every file as it was before `finish`, and the old file in git. What could not
    be put back."""
    failed = []
    for rel, data in originals.items():
        path = root / rel
        try:
            if data is None:
                path.unlink(missing_ok=True)
            else:
                path.write_bytes(data)
        except OSError as error:
            failed.append(f"{rel}: {error}")
    for folder in reversed(created):
        try:
            folder.rmdir()
        except OSError as error:
            failed.append(f"{folder.relative_to(root).as_posix()}: {error}")
    if left_git:
        done = subprocess.run(  # noqa: S603
            ["git", "-C", str(root), "reset", "-q", "--", old],  # noqa: S607
            capture_output=True,
            text=True,
            check=False,
        )
        if done.returncode != 0:
            failed.append(f"git reset -q -- {old}: {done.stderr.strip()}")
    return failed


def reminder(ledger: str, old: str) -> None:
    print(
        f"Open pull requests that changed {old} get one conflict when they merge main back in: "
        f"deleted here, modified there. To fix it, {FIX_HINTS[ledger]}."
    )


def finish(root: Path, ledger: str, old: str, files: dict[str, str]) -> int:
    """The only step that writes: git first, then the files, in the order of `files`. Any error
    puts everything back as it was, the old file in git included."""
    originals = {
        rel: (root / rel).read_bytes() if (root / rel).is_file() else None for rel in files
    }
    left_git, error = leave_git(root, old)
    if error:
        return refuse(ledger, [error])
    created: list[Path] = []
    try:
        for rel, text in files.items():
            write_file(root / rel, text, created)
    except OSError as error:
        failed = undo(root, old, left_git, originals, created)
        problems = [f"writing failed: {error}"]
        if failed:
            return refuse(
                ledger,
                [*problems, "and these could not be put back, fix them by hand:", *failed],
                "stopped half way",
            )
        return refuse(ledger, [*problems, "every file and the git index are back as they were"])
    print(f"split {ledger}: done. Commit it in a pull request of its own.")
    reminder(ledger, old)
    return 0


# ---------------------------------------------------------------------------------------------
# The commands
# ---------------------------------------------------------------------------------------------


def split_markdown(root: Path, ledger: str, dry: bool) -> int:
    old = led.OLD_PATHS[ledger]
    before_text = (root / old).read_text(encoding="utf-8")
    plan = PLANNERS[ledger](root, before_text)
    plan.problems += check_heads(root, plan)
    if plan.problems:
        return refuse(ledger, plan.problems)
    with tempfile.TemporaryDirectory() as tmp:
        scratch = Path(tmp)
        draw_in_scratch(root, plan.writes, scratch)
        drawn = BODIES[ledger](scratch)
        notes, problems, moved_entries = compare(
            ledger, root, before_text, plan.entries, drawn, scratch
        )
    print_plan(plan, dry)
    if problems:
        return refuse(ledger, problems)
    print_comparison(len(plan.entries), plan.notes + notes, moved_entries)
    files, problems = prepare(root, old, plan.writes, led.stamp(drawn, SOURCES[ledger]))
    if problems:
        return refuse(ledger, problems)
    return 0 if dry else finish(root, ledger, old, files)


def split_gen(root: Path, gen_out: str, lang: str, dry: bool) -> int:
    code = ont.run_codegen(root, lang)
    if code is None:
        return refuse("gen", ["tools/ontology_codegen.py failed; fix ontology/ first"])
    if (root / gen_out).read_text(encoding="utf-8") != code:
        return refuse(
            "gen",
            [
                f"{gen_out} is not what tools/ontology_codegen.py writes now (edited by hand, or "
                "ontology/ "
                "changed since): run make gen, commit it, then split"
            ],
        )
    would = "would " if dry else ""
    print(
        f"split gen: {gen_out} is the generated "
        f"code{' (dry run: nothing is written)' if dry else ''}"
    )
    print(
        f"  {would}remove {gen_out} from git (git rm --cached), add {gen_out} to .gitignore, and "
        "draw it stamped"
    )
    print("compare: the drawn file is the committed one, byte for byte, under a stamped first line")
    files, problems = prepare(root, gen_out, {}, ont.stamp_generated(code))
    if problems:
        return refuse("gen", problems)
    return 0 if dry else finish(root, "gen", gen_out, files)


def verify(root: Path, ledger: str, against: Path, gen_out: str | None, lang: str | None) -> int:
    """The comparison alone: the entries of `against` (a copy of the old file) and the ones the
    sources on disk draw today. Writes nothing."""
    before_text = against.read_text(encoding="utf-8")
    if ledger == "gen":
        code = ont.run_codegen(root, lang or "")
        if code is None or code != before_text:
            return refuse(
                "gen",
                [f"{gen_out}: what ontology/ draws today is not {against}"],
                "the comparison fails",
            )
        print(f"compare: {against} is what ontology/ draws today")
        return 0
    if ledger == "index":
        notes, problems, moved_entries = compare_index(
            root, before_text, led.index_body(root), root, strict=True
        )
        count = len(merge_links(parse_index(root, before_text, {}, strict=True)[0])[0])
    else:
        entries = (
            [f"{d} — {t}" for d, t in parse_log(before_text)[0]]
            if ledger == "log"
            else [entry_text(row) for row in parse_glossary(before_text)[0]]
        )
        notes, problems, moved_entries = compare(
            ledger, root, before_text, entries, BODIES[ledger](root), root
        )
        count = len(entries)
    if problems:
        return refuse(ledger, problems, f"the comparison with {against} fails")
    print_comparison(count, notes, moved_entries)
    return 0


def run(args: argparse.Namespace) -> int:
    root = Path(args.root)
    ledger = args.ledger
    if ledger == "gen" and not (args.gen_out and args.gen_lang):
        print(
            "ledgers.py: split gen needs --gen-out PATH and --gen-lang <ts|python> (make split "
            "L=gen passes them)",
            file=sys.stderr,
        )
        return 2
    if args.verify_against:
        return verify(root, ledger, Path(args.verify_against), args.gen_out, args.gen_lang)
    old = args.gen_out if ledger == "gen" else led.OLD_PATHS[ledger]
    if led.shape_of(root, ledger, args.gen_out) == led.FRAGMENTS:
        print(f"{old}: the {ledger} ledger is already split (fragments shape); nothing to do")
        return 0
    if ledger == "gen":
        return split_gen(root, args.gen_out, args.gen_lang, args.dry_run)
    return split_markdown(root, ledger, args.dry_run)
