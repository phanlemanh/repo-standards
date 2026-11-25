"""What holds each rule of the generated AGENTS.md: a machine, or a word.

Every list item in a `+AGENTS.md/` fragment ends with a kind, `<!-- kept: <code> -->`:

    word     a rule no machine is proven to catch
    none     not a rule (a command, a map of folders, a fact, a step of a procedure)
    <code>   a machine listed in rule-checks.toml catches a miss, and a test of this repository,
             tagged `# rule-check: <code>`, proves it

`check` reads the fragments and the registry and says what is wrong; with nothing wrong it prints
how many rules each kind holds.

`finish` is what apply.py does to the composed AGENTS.md: the kinds come off, and a section at
the end names the machines this repository has. Every word of that section comes from
rule-checks.toml, and templates without that file are left exactly as they are, so a later release
of the plugin still rebuilds, byte for byte, the AGENTS.md an earlier release wrote (the base of
an upgrade, see upgrade_base.py). For the same reason the section depends on the templates and the
choices only, never on what is on disk.

Only the Python standard library is used (Python 3.11+).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import tomllib
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

REGISTRY_NAME = "rule-checks.toml"
FRAGMENT_DIR = "+AGENTS.md"
MARKER = re.compile(r"[ \t]*<!-- kept: ([a-z][a-z0-9-]*) -->")
# A kind written on a line of its own: the line goes with it, or a blank line would stay behind.
MARKER_LINE = re.compile(r"^[ \t]*<!-- kept: [a-z][a-z0-9-]* -->[ \t]*\n", re.MULTILINE)
KINDS = ("red", "refuses", "raises-tier")
WORD = "word"
NONE = "none"
SUMMARY_FIELDS = ("heading", "intro", "closing", "closing_alone")
CHECK_FIELDS = ("catches", "reaction", "kind", "present_when")
ITEM_START = re.compile(r"^[ \t]*(?:[-*+]|\d+[.)])[ \t]+\S")
FENCE = re.compile(r"^[ \t]*(?:```|~~~)")
TAG = re.compile(r"^[ \t]*# rule-check: ([a-z][a-z0-9-]*)[ \t]*$", re.MULTILINE)
PLUGIN_ROOT = Path(__file__).resolve().parent.parent


@dataclass(frozen=True)
class Item:
    """One list item: the line it starts on, its text, and the kinds written on it."""

    line: int
    text: str
    kinds: tuple[str, ...]


def scan(text: str) -> tuple[list[Item], list[int]]:
    """The list items of a markdown text, and the lines that carry a kind outside any item.

    An item starts at a bullet or a number and runs to the next item, a blank line, a heading or
    the end. Lines inside a fenced block are text, never items."""
    items: list[Item] = []
    stray: list[int] = []
    start = 0
    lines: list[str] = []
    in_fence = False

    def close() -> None:
        nonlocal lines
        if lines:
            body = "\n".join(lines)
            items.append(Item(start, body, tuple(MARKER.findall(body))))
        lines = []

    for number, line in enumerate(text.splitlines(), start=1):
        if FENCE.match(line):
            close()
            in_fence = not in_fence
        elif in_fence:
            continue
        elif ITEM_START.match(line):
            close()
            start = number
            lines = [line]
        elif not line.strip() or line.lstrip().startswith("#"):
            close()
        elif lines:
            lines.append(line)
        elif MARKER.search(line):
            stray.append(number)
    close()
    return items, stray


def list_items(text: str) -> list[Item]:
    return scan(text)[0]


def fragments(root: Path) -> dict[str, str]:
    """Every file under a `+AGENTS.md` folder of the plugin, by its path from `root`."""
    found: dict[str, str] = {}
    for path in sorted(root.rglob("*")):
        rel = path.relative_to(root)
        if path.is_file() and FRAGMENT_DIR in rel.parts[:-1] and path.name != ".DS_Store":
            found[rel.as_posix()] = path.read_text(encoding="utf-8")
    return found


def load_registry(root: Path) -> dict | None:
    """The machines that may hold a rule and the words of the section; None without the file."""
    path = root / REGISTRY_NAME
    if not path.is_file():
        return None
    with path.open("rb") as fh:
        data = tomllib.load(fh)
    return {"summary": data.get("summary", {}), "checks": data.get("checks", {})}


def registry_problems(registry: dict) -> list[str]:
    problems = [
        f"{REGISTRY_NAME}: summary lacks {field}"
        for field in SUMMARY_FIELDS
        if not registry["summary"].get(field)
    ]
    for code, entry in registry["checks"].items():
        if code in (WORD, NONE):
            problems.append(f"{REGISTRY_NAME}: '{code}' is a kind, not a name for a check")
        problems.extend(
            f"{REGISTRY_NAME}: check '{code}' lacks {field}"
            for field in CHECK_FIELDS
            if not entry.get(field)
        )
        if entry.get("kind") and entry["kind"] not in KINDS:
            problems.append(
                f"{REGISTRY_NAME}: check '{code}': kind must be red, refuses or raises-tier"
            )
    return problems


def tagged(tests_dir: Path) -> set[str]:
    """The checks a test of this repository says it proves (`# rule-check: <code>`)."""
    found: set[str] = set()
    for path in sorted(tests_dir.rglob("*.sh")):
        found.update(TAG.findall(path.read_text(encoding="utf-8")))
    return found


def check(root: Path, tests_dir: Path | None = None) -> list[str]:
    """Everything wrong with the kinds in the fragments under `root`, one line each."""
    registry = load_registry(root)
    problems = [f"{REGISTRY_NAME} is missing"] if registry is None else registry_problems(registry)
    checks = {} if registry is None else registry["checks"]
    used: set[str] = set()
    for rel, text in fragments(root).items():
        items, stray = scan(text)
        for item in items:
            if not item.kinds:
                problems.append(f"{rel}:{item.line}: list item has no kind")
            elif len(item.kinds) > 1:
                problems.append(f"{rel}:{item.line}: list item has two kinds")
            elif item.kinds[0] in (WORD, NONE):
                continue
            elif item.kinds[0] in checks:
                used.add(item.kinds[0])
            else:
                problems.append(f"{rel}:{item.line}: unknown check '{item.kinds[0]}'")
        problems.extend(f"{rel}:{line}: marker outside a list item" for line in stray)
    problems.extend(
        f"{REGISTRY_NAME}: check '{code}' is not used by any rule"
        for code in checks
        if code not in used
    )
    if tests_dir is not None:
        proven = tagged(tests_dir)
        problems.extend(
            f"{REGISTRY_NAME}: check '{code}' has no test tagged '# rule-check: {code}'"
            for code in checks
            if code not in proven
        )
    return problems


def count(root: Path) -> dict[str, dict[str, int]]:
    """Per fragment: rules a machine holds, rules kept by word, items that are not rules."""
    counts: dict[str, dict[str, int]] = {}
    for rel, text in fragments(root).items():
        kinds = [item.kinds[0] for item in list_items(text) if len(item.kinds) == 1]
        counts[rel] = {
            "machine": sum(1 for kind in kinds if kind not in (WORD, NONE)),
            "word": kinds.count(WORD),
            "none": kinds.count(NONE),
        }
    return counts


def held(text: str, registry: dict, present: Callable[[str], bool]) -> list[dict]:
    """The registered machines the rules of `text` name, in the order they first appear, that this
    repository has. A code the registry does not know, or knows half of, holds nothing here:
    `check` is where that is red."""
    checks = registry["checks"]
    seen: list[str] = []
    for item in list_items(text):
        for code in item.kinds:
            if code not in seen and code in checks:
                seen.append(code)
    return [
        checks[code]
        for code in seen
        if all(checks[code].get(field) for field in CHECK_FIELDS)
        and present(str(checks[code]["present_when"]))
    ]


def summary(text: str, registry: dict, present: Callable[[str], bool]) -> str:
    """The section "What holds these rules" for a repository; raises KeyError when the registry
    lacks one of its sentences."""
    words = {field: str(registry["summary"][field]).strip("\n") for field in SUMMARY_FIELDS}
    lines = [f"- {entry['catches']}: {entry['reaction']}" for entry in held(text, registry, present)]
    if not lines:
        return "\n".join([words["heading"], "", words["closing_alone"]])
    return "\n".join([words["heading"], "", words["intro"], "", *lines, "", words["closing"]])


def finish(content: bytes, root: Path, present: Callable[[str], bool], adopt: bool) -> bytes:
    """AGENTS.md as a repository gets it: without the kinds and, unless it was set up with
    --adopt, with the section that says what holds its rules. `present(path)` says whether the
    templates give this repository that file. Templates without a registry are not touched."""
    registry = load_registry(root)
    if registry is None:
        return content
    text = content.decode("utf-8")
    stripped = MARKER.sub("", MARKER_LINE.sub("", text))
    if adopt:
        return stripped.encode("utf-8")
    section = summary(text, registry, present)
    body = stripped.rstrip("\n")
    return f"{body}\n\n{section}\n".encode("utf-8")


def section_heading(root: Path) -> bytes | None:
    """The line the section starts with, as it stands in AGENTS.md; None when the templates have no
    registry, or one without that line."""
    registry = load_registry(root)
    heading = str((registry or {}).get("summary", {}).get("heading", "")).strip("\n")
    return heading.encode("utf-8") or None


def total(counts: dict[str, dict[str, int]]) -> dict[str, int]:
    return {key: sum(c[key] for c in counts.values()) for key in ("machine", "word", "none")}


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Check and count the kinds of the AGENTS.md rules.")
    sub = ap.add_subparsers(dest="command", required=True)
    chk = sub.add_parser("check", help="every list item has a kind; every machine is proven")
    chk.add_argument("--root", default=str(PLUGIN_ROOT), help="plugin folder (default: this one)")
    chk.add_argument("--tests", help="folder of the tests that carry the `# rule-check:` tags")
    chk.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)

    root = Path(args.root)
    problems = check(root, Path(args.tests) if args.tests else None)
    counts = count(root)
    sums = total(counts)
    if args.json:
        print(json.dumps({"ok": not problems, "problems": problems, "counts": counts, "total": sums}))
        return 1 if problems else 0
    if problems:
        print("\n".join(problems), file=sys.stderr)
        return 1
    print("machine  word  none  fragment")
    for rel, c in counts.items():
        print(f"{c['machine']:7d} {c['word']:5d} {c['none']:5d}  {rel}")
    print(
        f"rule kinds: {sums['machine']} held by a machine, {sums['word']} kept by word, "
        f"{sums['none']} not rules"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
