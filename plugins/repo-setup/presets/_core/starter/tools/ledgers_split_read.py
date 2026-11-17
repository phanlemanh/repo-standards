"""What `ledgers.py split` reads: the parsers of the three one-file ledgers and the plan of what
a split would write. Nothing here touches the disk; tools/ledgers_split.py (which imports this
module) compares, writes and undoes.

  log       an entry is a line `- YYYY-MM-DD — <text>`; the rest goes to wiki/log.head.md
  glossary  an entry is a row of the four-column table; the rest goes to ontology/glossary.head.md
  index     an entry is a line `- [title](page)` (plus ` — <description>`) that points to a page;
            the description moves to the `summary` key of that page, the rest to wiki/index.head.md
"""

from __future__ import annotations

import collections
import difflib
import re
from dataclasses import dataclass, field
from pathlib import Path

import ledgers as led
import ledgers_ontology as ont

LOG_ENTRY_RE = re.compile(r"^- (?P<date>\d{4}-\d{2}-\d{2}) — (?P<text>.*\S)\s*$")
LOG_LIKE_RE = re.compile(r"^\s*[-*+] \d{4}-\d{2}-\d{2}\b")
LINK_RE = re.compile(
    r"^(?P<indent>\s*)(?P<bullet>[-*+]) \[(?P<title>[^\]]*)\]\((?P<target>[^)\s]+)\)(?P<rest>.*)$"
)
HEADING_RE = re.compile(r"^## (?P<name>.+?)\s*$")
SEPARATOR_RE = re.compile(r"^\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)*\|?\s*$")
CELL_SPLIT_RE = re.compile(r"(?<!\\)\|")
EXAMPLE_MARK = "_Example:_"
# The example row and the closing comment of the glossary the template gave, word for word (the
# example had three columns before 0.4). Only these are dropped; an edited one is the team's.
TEMPLATE_EXAMPLE = (
    "_Example:_ `Customer`",
    "A person who has bought at least once.",
    "`Visitor` (has not bought)",
    "Customer",
)
TEMPLATE_COMMENT = "<!-- Add your terms above. Keep definitions to one sentence. -->"
LOG_SENTENCE = led.INDEX_LOG_SECTION.splitlines()[-1]
MAX_PER_DAY = 99


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


def is_template_example(cells: list[str]) -> bool:
    flat = tuple(led.one_line(cell) for cell in cells)
    return flat in (TEMPLATE_EXAMPLE, TEMPLATE_EXAMPLE[:3])


def is_template_comment(line: str) -> bool:
    return led.one_line(line) == TEMPLATE_COMMENT


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
                if is_template_example(cells):
                    notes.append(
                        f"dropped the template's example row ({EXAMPLE_MARK}): {line.strip()}"
                    )
                elif len(cells) != len(led.GLOSSARY_COLUMNS):
                    problems.append(
                        f"line {i + 1} is a row of {len(cells)} cells, not "
                        f"{len(led.GLOSSARY_COLUMNS)}: {line}"
                    )
                elif cells[0].startswith(EXAMPLE_MARK):
                    problems.append(
                        f"line {i + 1} is an example row ({EXAMPLE_MARK}) that is not the "
                        "template's: make it a row of its own (the term in backticks) or delete "
                        f"it, then split: {line}"
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
        elif is_template_comment(line):
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
# What a hand-kept file holds that no fragment does (tools/ledgers.py names it before a deletion)
# ---------------------------------------------------------------------------------------------


HEAD_FILES = {"log": led.LOG_HEAD, "glossary": led.GLOSSARY_HEAD}


def is_entry_line(ledger: str, line: str) -> bool:
    """The line has the shape of an entry (a log line with a date, a table row); anything else
    belongs to the head file."""
    return bool(LOG_LIKE_RE.match(line)) if ledger == "log" else line.lstrip().startswith("|")


def head_lines(ledger: str, lines: list[str]) -> list[str]:
    return [line for line in lines if not is_entry_line(ledger, line)]


def held_row(line: str, held: set[str]) -> bool:
    """A table row a split leaves out on purpose (header, separator, the template's own example
    row, word for word) or one a fragment holds, whatever its padding."""
    cells = split_cells(line)
    if tuple(cells) == led.GLOSSARY_COLUMNS or SEPARATOR_RE.match(line.strip()):
        return True
    if is_template_example(cells):
        return True
    if len(cells) != len(led.GLOSSARY_COLUMNS):
        return False
    return entry_text(row_entry(cells)[0]) in held


def unmoved(root: Path, ledger: str, text: str) -> tuple[list[str], list[str]]:
    """(entry lines, head lines) of a hand-kept log or glossary (`text`) that no source holds:
    every line that the drawn body lacks counts, a malformed entry line and a head line too."""
    body = led.log_body(root) if ledger == "log" else led.glossary_body(root)
    missing = led.lines_not_in(text, body)
    if ledger == "glossary":
        terms = (t for t in map(led.Term, led.glossary_files(root)) if t.term)
        held = {entry_text((t.term, t.definition, t.not_confused_with, t.display)) for t in terms}
        missing = [
            line
            for line in missing
            if not is_template_comment(line)
            and not (line.lstrip().startswith("|") and held_row(line, held))
        ]
    heads = head_lines(ledger, missing)
    return [line for line in missing if line not in heads], heads


def unmoved_in(root: Path, ledger: str, rel: str) -> tuple[list[str], list[str]]:
    """unmoved() of the file at `rel`; nothing when it cannot be read."""
    try:
        return unmoved(root, ledger, (root / rel).read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError):
        return [], []


def listed(lines: list[str]) -> str:
    return "".join(f"\n  + {line}" for line in lines)


def listing(rel: str, ledger: str | None, entries: list[str], heads: list[str], way: str) -> str:
    """One header for every line of `rel` that no source holds, then where each group goes: the
    entries `way`, the other lines into the head file."""
    if not entries and not heads:
        return ""
    text = f"These lines of {rel} are in no source yet:"
    if entries:
        text += f"{listed(entries)}\n  -> {way}"
    if heads:
        text += f"{listed(heads)}\n  -> move them into {HEAD_FILES[ledger]}"
    return text + "\n"


def unmoved_note(root: Path, ledger: str, rel: str, source: str, how: str) -> str:
    """For an untracked hand-kept file: what of it no source holds and where each part goes; the
    command alone when nothing is listed."""
    entries, heads = unmoved_in(root, ledger, rel)
    text = listing(rel, ledger, entries, heads, f"add each one: {how}")
    return text.rstrip("\n") or f"A line goes into {source} with: {how}."


def two_sources_way(root: Path, ledger: str, rel: str, folder: str, how: str) -> str:
    """The way out of a tracked hand-kept file beside fragments, losing nothing: every line of the
    file that no source holds is listed first. `how` writes into the hand-kept file while it is in
    git, so the deletion comes before the entries are added."""
    entries, heads = unmoved_in(root, ledger, rel)
    if not entries and not heads:
        return (
            f"Every line of {rel} is in {folder}/ or its head file, so it is safe to delete: "
            f"git rm {rel}."
        )
    way = f"copy them, git rm {rel}, then add each one: {how}"
    end = "Then run make derived." if entries else f"Then git rm {rel} and run make derived."
    return listing(rel, ledger, entries, heads, way) + end
