"""The ontology side of tools/ledgers.py: add-term, and the generated code drawn from ontology/.

Split out of ledgers.py to keep each file short. It imports ledgers by name; ledgers.py makes
that name work when it runs as a script. Only the Python standard library is used.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
import tempfile
from pathlib import Path

import ledgers as led


def term_fragment(term: str, display: str, not_confused_with: str, definition: str) -> str:
    """The text of ontology/glossary/<term>.md, as add-term and split write it."""
    return (
        f"---\nterm: {term}\ndisplay: {display}\nnot_confused_with: {not_confused_with}\n"
        f"---\n{definition}\n"
    )


def bad_term_character(term: str) -> str | None:
    """The first character a term cannot have in a file name, or None."""
    if term.startswith("."):
        return "."
    for char in term:
        if char in "/\\" or ord(char) < 32:
            return char
    return None


def add_term_row(root: Path, term: led.Term) -> int:
    """One-file shape: the row goes under the last row of the table, above the closing comment."""
    path = root / led.GLOSSARY_FILE
    lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
    if any(ln.startswith(f"| `{term.term}` |") for ln in lines):
        print(f"ledgers.py: {led.GLOSSARY_FILE} already has the term {term.term}", file=sys.stderr)
        return 1
    row = led.glossary_row(term) + "\n"
    at = next((i for i, ln in enumerate(lines) if ln.startswith(led.GLOSSARY_COMMENT)), None)
    if at is None:
        rows = [i for i, ln in enumerate(lines) if ln.startswith("|")]
        at = rows[-1] + 1 if rows else len(lines)
    if at and not lines[at - 1].endswith("\n"):
        lines[at - 1] += "\n"
    lines.insert(at, row)
    path.write_text("".join(lines), encoding="utf-8")
    print(f"added to {led.GLOSSARY_FILE}")
    return 0


def cmd_add_term(args: argparse.Namespace) -> int:
    root = Path(args.root)
    name = args.term.strip()
    definition = led.one_line(args.definition)
    if not name or not definition:
        print("ledgers.py: add-term needs a term and a --definition", file=sys.stderr)
        return 2
    bad = bad_term_character(name)
    if bad is not None:
        shown = "a leading dot" if bad == "." else repr(bad) if ord(bad) < 32 else f"'{bad}'"
        print(
            f"ledgers.py: the term '{name}' cannot be a file name: {shown} is not allowed",
            file=sys.stderr,
        )
        return 2
    term = led.Term.__new__(led.Term)
    term.term, term.definition = name, definition
    term.display = led.one_line(args.display) if args.display else name
    term.not_confused_with = led.one_line(args.not_confused_with or "")
    if led.shape_of(root, "glossary") == led.ONE_FILE:
        return add_term_row(root, term)
    path = root / led.GLOSSARY_DIR / f"{name}.md"
    if path.exists():
        print(
            f"ledgers.py: {led.GLOSSARY_DIR}/{path.name} already exists: {name} is defined",
            file=sys.stderr,
        )
        return 1
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        term_fragment(name, term.display, term.not_confused_with, definition), encoding="utf-8"
    )
    print(f"wrote {led.GLOSSARY_DIR}/{path.name}")
    return 0


GEN_HASH_RE = re.compile(r" sha256:(?P<hex>[0-9a-f]{64})")
GEN_HINT = "Edit ontology/ and run: make derived"


def stamp_generated(code: str) -> str:
    """The generated code with ` sha256:<hex>` at the end of its first comment line, where <hex>
    is the hash of everything after that line. A docstring line keeps its closing quotes last."""
    first, newline, body = code.partition("\n")
    mark = f" {led.HASH_MARK}{led._digest(body)}"
    if first.endswith('"""'):
        first = first[:-3] + mark + '"""'
    else:
        first += mark
    return first + newline + body


def read_generated(path: Path) -> tuple[str | None, bool]:
    """(body, hand-edited) of a drawn generated file; (None, False) when absent or not stamped."""
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return None, False
    first, _, body = text.partition("\n")
    match = GEN_HASH_RE.search(first)
    if match is None:
        return None, False
    return body, led._digest(body) != match.group("hex")


def run_codegen(root: Path, lang: str) -> str | None:
    """What tools/ontology_codegen.py writes for `lang`, read back from a temporary file."""
    tool = Path(__file__).resolve().parent / "ontology_codegen.py"
    with tempfile.TemporaryDirectory() as scratch:
        out = Path(scratch) / "generated"
        done = subprocess.run(  # noqa: S603
            [sys.executable, str(tool), "--lang", lang, "--out", str(out), "--root", str(root)],
            capture_output=True,
            text=True,
            check=False,
        )
        if done.returncode != 0 or not out.is_file():
            sys.stderr.write(done.stderr or done.stdout)
            return None
        return out.read_text(encoding="utf-8")


def draw_generated(root: Path, rel: str, lang: str, quiet: bool) -> int | None:
    """Draw the generated code at `rel`. None when it is kept as one file (nothing is drawn: the
    repository commits it and `make ontology` compares it), 0 done, 1 refused."""
    if led.shape_of(root, "gen", rel) != led.FRAGMENTS:
        return None
    target = root / rel
    current, edited = read_generated(target)
    if target.is_file() and current is None:
        return 0  # a file this tool did not draw, and git does not know it: leave it alone
    code = run_codegen(root, lang)
    if code is None:
        return 1
    text = stamp_generated(code)
    if edited and current is not None:
        expected = set(text.partition("\n")[2].splitlines())
        added = [ln for ln in current.splitlines() if ln and ln not in expected]
        print(
            f"{rel} was edited by hand; it is drawn from ontology/ and a hand edit is lost.",
            file=sys.stderr,
        )
        for ln in added:
            print(f"  + {ln}", file=sys.stderr)
        print(GEN_HINT, file=sys.stderr)
        return 1
    if target.is_file() and target.read_text(encoding="utf-8") == text:
        return 0
    target.parent.mkdir(parents=True, exist_ok=True)
    scratch = target.with_name(target.name + ".tmp")
    scratch.write_text(text, encoding="utf-8")
    scratch.replace(target)
    if not quiet:
        print(f"drew {rel}")
    return 0


def cmd_draw_gen(args: argparse.Namespace) -> int:
    result = draw_generated(Path(args.root), args.gen_out, args.gen_lang, args.quiet)
    return result or 0
