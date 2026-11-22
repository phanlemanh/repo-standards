#!/usr/bin/env python3
"""The autonomy card: when a person is called, what they do, why, and the switch to be called less.

  python3 tools/autonomy_card.py [--root DIR] [--json] [--keys]

The card has up to four parts, in this order: when you are called (one row each), what the machine
does alone, what agents are not allowed to do, and the next level. A part with nothing in it is left
out. Every row is the same six keys: when, you_do, why, switch, keys, known. A row that could not be
checked has `known: false` and says why: the card never calls an unchecked row done.

This file is the starter level's source: it reads the repository (`.repo-setup.json`,
`.claude/settings.json`, `.github/workflows/ci.yml`, `ontology/actions.yaml`) and imports nothing
from tools/ that a starter repository does not ship. Reading the team level's sources is added in
`_level_sources`, one place. Nothing is written: no file, no cache.

Exit codes: 0 the card was printed (also with a row that could not be checked), 2 not inside a git
repository or a wrong call.

Only the Python standard library is used.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import textwrap
from pathlib import Path
from typing import Any

MANIFEST = ".repo-setup.json"
POLICY = "governance/autonomy.yaml"
SETTINGS = ".claude/settings.json"
CI_WORKFLOW = ".github/workflows/ci.yml"
ONTOLOGY_ACTIONS = "ontology/actions.yaml"

LEVEL_STARTER = "starter"
LEVEL_TEAM = "team"
TEAM_SWITCH = "the team level: re-run repo-setup with --level team"

# Text layout: one fixed column per key, a long cell wraps inside its column.
COLUMNS = (("when", 28), ("you_do", 20), ("why", 32), ("switch", 34))
GAP = "  "
INDENT = "  "

# The next level, as three items (what: the thing it adds, keys: where it lives).
NEXT_LEVEL = [
    {
        "what": "docs and tests check themselves (wiki and ledger lint, the product tests in CI)",
        "keys": "make check",
    },
    {
        "what": "a ledger of the work outside the repository (secrets, settings, one-time steps)",
        "keys": "ops/outside.toml, python3 tools/outside.py status",
    },
    {
        "what": "the machine drafts a change to the rules, a person approves it",
        "keys": "governance/autonomy.yaml",
    },
]


class CardError(Exception):
    """The card cannot be drawn: not a git repository."""


def row(
    when: str, you_do: str, why: str, switch: str, keys: str, known: bool = True
) -> dict[str, Any]:
    """One row of the card: always the same six keys."""
    return {
        "when": when,
        "you_do": you_do,
        "why": why,
        "switch": switch,
        "keys": keys,
        "known": known,
    }


def machine_item(what: str, keys: str) -> dict[str, str]:
    """One thing the machine does alone."""
    return {"what": what, "keys": keys}


def find_root(start: Path) -> Path:
    """The top of the git repository that holds `start`; CardError when there is none."""
    try:
        done = subprocess.run(  # noqa: S603
            ["git", "-C", str(start), "rev-parse", "--show-toplevel"],  # noqa: S607
            capture_output=True,
            text=True,
            stdin=subprocess.DEVNULL,
            check=False,
        )
    except OSError as err:
        raise CardError(f"cannot run git: {err}") from err
    if done.returncode != 0 or not done.stdout.strip():
        raise CardError(f"{start} is not inside a git repository")
    return Path(done.stdout.strip())


def detect_level(root: Path) -> tuple[str, bool]:
    """(level, guessed): the level `.repo-setup.json` records, else a guess from the files."""
    try:
        data = json.loads((root / MANIFEST).read_text(encoding="utf-8"))
        level = data.get("level") if isinstance(data, dict) else None
        if level in (LEVEL_STARTER, LEVEL_TEAM):
            return level, False
    except (OSError, ValueError):
        pass
    return (LEVEL_TEAM if (root / POLICY).is_file() else LEVEL_STARTER), True


def _read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def _edit_walls(root: Path) -> tuple[list[str], str | None]:
    """(paths, problem): the paths of the `Edit(...)` lines in the settings' deny list."""
    path = root / SETTINGS
    if not path.is_file():
        return [], None
    try:
        deny = _read_json(path).get("permissions", {}).get("deny", [])
    except (OSError, ValueError, AttributeError) as err:
        return [], f"{SETTINGS} cannot be read ({err})"
    walls = []
    for entry in deny if isinstance(deny, list) else []:
        if isinstance(entry, str) and entry.startswith("Edit(") and entry.endswith(")"):
            target = entry[len("Edit(") : -1]
            target = target[2:] if target.startswith("./") else target
            walls.append(target[:-2] if target.endswith("**") else target)
    return walls, None


def starter_called(root: Path) -> list[dict[str, Any]]:
    """The rows of the starter level: no policy, so every merge is yours."""
    rows = [
        row(
            "Any change merges",
            "merge",
            "no policy at the starter level: every merge is yours",
            TEAM_SWITCH,
            f"{MANIFEST}: level",
        )
    ]
    walls, problem = _edit_walls(root)
    if walls:
        rows.append(
            row(
                "A change to " + ", ".join(walls),
                "you edit it",
                f"the session may not edit it ({SETTINGS})",
                TEAM_SWITCH,
                f"{SETTINGS}: permissions.deny",
            )
        )
    if problem:
        rows.append(
            row(
                "A change to the files the session may not edit",
                "you edit it",
                "unknown: " + problem,
                "-",
                f"{SETTINGS}: permissions.deny",
                known=False,
            )
        )
    return rows


def starter_machine(root: Path) -> list[dict[str, str]]:
    items = []
    if (root / CI_WORKFLOW).is_file():
        items.append(machine_item("ci.yml runs make check on every pull request", CI_WORKFLOW))
    return items


def ontology_parts(root: Path) -> tuple[list[dict[str, Any]], list[dict[str, str]]]:
    """(called rows, not-allowed items) from ontology/actions.yaml; nothing when it is absent or
    this repository does not ship the reader (a claude-plugin repository)."""
    if not (root / ONTOLOGY_ACTIONS).is_file():
        return [], []
    sys.dont_write_bytecode = True  # a run writes nothing, not even a cache
    here = str(Path(__file__).resolve().parent)
    if here not in sys.path:
        sys.path.insert(0, here)
    try:
        import ontology_actions
    except ImportError:
        return [], []
    try:
        actions = ontology_actions.load_actions(root)
    except Exception as err:  # a damaged file must not stop the card: say it is unknown
        return [
            row(
                "An agent runs a product action",
                "confirm it when it asks",
                f"unknown: {ONTOLOGY_ACTIONS} cannot be read ({err})",
                "-",
                ONTOLOGY_ACTIONS,
                known=False,
            )
        ], []
    # `agent` missing is `forbidden`, as ontology_actions reads it.
    modes = [str(a.get("agent", "forbidden")) for a in actions]
    confirm, forbidden = modes.count("confirm"), modes.count("forbidden")
    called, not_allowed = [], []
    if confirm:
        called.append(
            row(
                f"An agent runs one of {confirm} product actions marked confirm",
                "confirm it when it asks",
                "the action is marked confirm",
                "agent: allowed on that action",
                f"{ONTOLOGY_ACTIONS}: agent",
            )
        )
    if forbidden:
        not_allowed.append(
            machine_item(
                f"run {forbidden} product actions: agent is forbidden (or not set)",
                f"{ONTOLOGY_ACTIONS}: agent",
            )
        )
    return called, not_allowed


def _level_sources(root: Path, level: str) -> dict[str, Any]:
    """The parts a level draws from its own tools. Starter has none beyond the files read above;
    the team level adds its gate and its ledger here."""
    if level == LEVEL_STARTER:
        return {
            "called": starter_called(root),
            "machine": starter_machine(root),
            "next_level": list(NEXT_LEVEL),
        }
    return {"called": [], "machine": [], "next_level": []}


def build(root: Path) -> dict[str, Any]:
    """The card of the repository at `root`: level, called, machine, not_allowed, next_level."""
    level, guessed = detect_level(root)
    parts = _level_sources(root, level)
    called, machine = list(parts["called"]), list(parts["machine"])
    if guessed:
        machine.append(
            machine_item(
                f"the level was guessed from the files ({MANIFEST} is missing or unreadable)",
                MANIFEST,
            )
        )
    more_called, not_allowed = ontology_parts(root)
    card: dict[str, Any] = {"level": level, "called": called + more_called, "machine": machine}
    if not_allowed:
        card["not_allowed"] = not_allowed
    if parts["next_level"]:
        card["next_level"] = parts["next_level"]
    return card


def _cells(text: str, width: int) -> list[str]:
    return textwrap.wrap(text, width=width, break_long_words=True) or [""]


def _table(rows: list[dict[str, Any]], keys: bool) -> list[str]:
    head = GAP.join(name.replace("_", " ").upper().ljust(width) for name, width in COLUMNS)
    lines = [INDENT + head.rstrip()]
    for item in rows:
        shown = dict(item)
        if item.get("known") is False and not str(item["why"]).startswith("unknown: "):
            shown["why"] = "unknown: " + str(item["why"])
        columns = [_cells(str(shown[name]), width) for name, width in COLUMNS]
        for i in range(max(len(c) for c in columns)):
            parts = [
                (columns[n][i] if i < len(columns[n]) else "").ljust(COLUMNS[n][1])
                for n in range(len(COLUMNS))
            ]
            lines.append(INDENT + GAP.join(parts).rstrip())
        if keys:
            lines.append(f"{INDENT}  keys: {item['keys']}")
    return lines


def _list(items: list[dict[str, str]], keys: bool) -> list[str]:
    lines = []
    for item in items:
        lines.extend(
            textwrap.wrap(
                item["what"],
                width=100,
                initial_indent=INDENT + "- ",
                subsequent_indent=INDENT + "  ",
            )
        )
        if keys:
            lines.append(f"{INDENT}  keys: {item['keys']}")
    return lines


def render(card: dict[str, Any], keys: bool = False) -> str:
    """The card as text: four parts in order, an empty part left out."""
    lines = [f"Autonomy card (level: {card['level']})"]
    if card.get("called"):
        lines += ["", "You are called when", *_table(card["called"], keys)]
    if card.get("machine"):
        lines += ["", "The machine does alone", *_list(card["machine"], keys)]
    if card.get("not_allowed"):
        lines += ["", "Agents are not allowed to", *_list(card["not_allowed"], keys)]
    if card.get("next_level"):
        lines += ["", "Next level", *_list(card["next_level"], keys)]
    return "\n".join(lines) + "\n"


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="autonomy_card.py", description=__doc__.split("\n")[0])
    parser.add_argument("--root", default=".", help="the repository (default: the current folder)")
    parser.add_argument("--json", action="store_true", help="print the card as JSON")
    parser.add_argument("--keys", action="store_true", help="show where each row is set")
    return parser


def main(argv: list[str] | None = None) -> int:
    try:
        args = _parser().parse_args(argv)
    except SystemExit as stop:
        return 2 if stop.code else 0
    try:
        card = build(find_root(Path(args.root)))
    except CardError as err:
        print(err, file=sys.stderr)
        return 2
    if args.json:
        print(json.dumps(card, indent=2))
    else:
        print(render(card, keys=args.keys), end="")
    return 0


if __name__ == "__main__":
    sys.exit(main())
