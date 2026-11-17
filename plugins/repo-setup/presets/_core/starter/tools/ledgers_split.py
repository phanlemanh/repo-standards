"""`ledgers.py split <ledger>`: move a one-file ledger into fragments without losing an entry.

Run once per ledger, in a pull request of its own. Everything is worked out in memory first: the
old file is read into entries and the part that is no entry (the head); the fragments, the head
file and any page edit are written into a scratch copy of wiki/ and ontology/; the real drawer of
tools/ledgers.py draws the ledger there; the drawn text is read back into entries. The split goes
ahead only when the entries before and after are the same, each word for word. The order may
change: every entry that moved is printed. Then, and only then, the files are written, the old
file leaves git (`git rm --cached`), its path goes into .gitignore and the drawn file takes its
place. The parsers and the plan live in tools/ledgers_split_read.py.

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
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
from collections.abc import Callable
from pathlib import Path

import ledgers as led
import ledgers_ontology as ont
from ledgers_split_read import (
    Plan,
    compare_index,
    drawn_glossary_entries,
    drawn_log_entries,
    entry_text,
    merge_links,
    moved,
    parse_glossary,
    parse_index,
    parse_log,
    plan_glossary,
    plan_index,
    plan_log,
)

MANIFEST = ".repo-setup.json"

FIX_HINTS = {
    "log": "take the deletion first on that branch: git rm wiki/log.md (git diff "
    "MERGE_HEAD...HEAD -- wiki/log.md shows the lines it added); then add each of them: "
    'make log m="<text>"',
    "glossary": "take the deletion first on that branch: git rm ontology/glossary.md (git diff "
    "MERGE_HEAD...HEAD -- ontology/glossary.md shows the rows it added or changed); then add "
    'each of them: python3 tools/ledgers.py add-term <Term> --definition "<text>" (a changed '
    "term: edit ontology/glossary/<Term>.md)",
    "index": "take the deletion on that branch: a new page needs only a type and a title (and a "
    "summary) to be listed",
    "gen": "take the deletion on that branch (git rm --cached the file); make derived draws it",
}


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
