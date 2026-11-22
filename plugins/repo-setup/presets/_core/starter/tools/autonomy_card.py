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
import os
import shutil
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
OUTSIDE_TOOL = "tools/outside.py"
DEPENDABOT = ".github/dependabot.yml"
DEPLOY_WORKFLOW = ".github/workflows/deploy.yml"
OUTSIDE_CARD_TIMEOUT = 120  # seconds the ledger may take to answer
AGENT_MODES = ("allowed", "confirm", "forbidden")

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


def _agent_mode(action: Any) -> str:
    """The `agent` mode of one action; ValueError when it is not an action or not a known mode."""
    if not isinstance(action, dict):
        raise ValueError(f"an action is not a mapping: {action!r}")
    mode = action.get("agent", "forbidden")
    if mode not in AGENT_MODES:
        raise ValueError(f"agent: {mode!r} is not one of {', '.join(AGENT_MODES)}")
    return str(mode)


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
        # `agent` missing is `forbidden`, as ontology_actions reads it; any other value that is not
        # one of the three modes (`agent: null`, a typo) cannot be counted: it is unknown.
        modes = [_agent_mode(a) for a in ontology_actions.load_actions(root)]
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


def _import_autonomy() -> Any:
    """The team level's gate, imported here only: a starter repository does not ship it."""
    sys.dont_write_bytecode = True  # a run writes nothing, not even a cache
    here = str(Path(__file__).resolve().parent)
    if here not in sys.path:
        sys.path.insert(0, here)
    import autonomy

    return autonomy


def _policy_unknown(why: str) -> dict[str, Any]:
    return row(
        "Who decides a merge",
        "merge, or approve",
        "unknown: " + why,
        "-",
        f"{POLICY}:",
        known=False,
    )


def _policy_pairs(policy: dict[str, Any], autonomy: Any, own: tuple[str, ...], root: Path):
    """The (tier, reason, keys) pairs the policy can give a change (ruling 4)."""
    rules = policy.get("rules") if isinstance(policy.get("rules"), dict) else {}
    pairs = [
        ("high", "protected path", "high"),
        (autonomy.default_tier(policy, own), "default", "default"),
        (
            str(rules.get("test_deletions_raise_to", "medium")),
            "removes, rewrites or disables test code",
            "rules.test_deletions_raise_to",
        ),
        (
            str(rules.get("agent_guard_removals_raise_to", "high")),
            "loosens what agents may do",
            "rules.agent_guard_removals_raise_to",
        ),
    ]
    updates = rules.get("dependency_updates")
    if (root / DEPENDABOT).is_file() and isinstance(updates, dict):
        pairs += [
            (str(tier), f"dependency update ({level})", f"rules.dependency_updates.{level}")
            for level, tier in updates.items()
        ]
    return pairs


def _machine_words(reason: str, policy: dict[str, Any], autonomy: Any, own: tuple[str, ...]) -> str:
    """What the machine does alone when `reason` lands on the low tier."""
    if reason == "default":
        proof = autonomy.proof_check(policy, own)
        return f"product code merges once the checks and the proof ({proof}) are green"
    if reason == "removes, rewrites or disables test code":
        return (
            "a change that removes, rewrites or disables test code merges once the checks are green"
        )
    if reason == "loosens what agents may do":
        return "a change that lets agents do more in the product merges once the checks are green"
    level = reason[reason.index("(") + 1 : -1]
    return f"a dependency update ({level}) merges once the checks are green"


def team_policy(root: Path) -> tuple[list[dict[str, Any]], list[dict[str, str]]]:
    """(called rows, machine items) from the merge policy, through autonomy.card_row."""
    try:
        autonomy = _import_autonomy()
        policy = autonomy.load_policy(root)
        own = autonomy.own_checks(root)
        pairs = _policy_pairs(policy, autonomy, own, root)
        called: list[dict[str, Any]] = []
        machine: list[dict[str, str]] = []
        for tier, reason, key in pairs:
            if tier not in autonomy.TIERS:
                called.append(_policy_unknown(f"{key} is {tier!r}, not one of low, medium, high"))
                continue
            found = autonomy.card_row(policy, tier, reason, own)
            if found is not None:
                called.append(found)
            elif reason != "protected path":
                machine.append(
                    machine_item(_machine_words(reason, policy, autonomy, own), f"{POLICY}: {key}")
                )
        low = policy.get("low")
        if isinstance(low, list) and low:
            machine.insert(
                0,
                machine_item(
                    "changes to " + ", ".join(map(str, low)) + " merge once the checks are green",
                    f"{POLICY}: low",
                ),
            )
        return called, machine
    except (Exception, SystemExit) as err:  # a damaged or missing policy: unknown, not silence
        return [_policy_unknown(f"{POLICY} cannot be read ({err})")], []


def _ledger_unknown(why: str) -> dict[str, Any]:
    return row(
        "Work outside the repository",
        "find out why",
        "unknown: " + why,
        f"python3 {OUTSIDE_TOOL} status",
        "ops/outside.toml",
        known=False,
    )


def team_ledger(root: Path) -> tuple[list[dict[str, Any]], list[dict[str, str]], list[str] | None]:
    """(called rows, machine items, ids in place) from `tools/outside.py status --json`; the ids
    are None when the ledger could not be read."""
    if not (root / OUTSIDE_TOOL).is_file():
        return [_ledger_unknown(f"{OUTSIDE_TOOL} is missing")], [], None
    env = {**os.environ, "PYTHONDONTWRITEBYTECODE": "1"}  # the child writes no cache either
    try:
        done = subprocess.run(  # noqa: S603
            [sys.executable, OUTSIDE_TOOL, "status", "--json"],
            cwd=root,
            capture_output=True,
            text=True,
            stdin=subprocess.DEVNULL,
            env=env,
            timeout=OUTSIDE_CARD_TIMEOUT,
            check=False,
        )
    except subprocess.TimeoutExpired:
        why = f"{OUTSIDE_TOOL} did not answer within {OUTSIDE_CARD_TIMEOUT} seconds"
        return [_ledger_unknown(why)], [], None
    except OSError as err:
        return [_ledger_unknown(f"{OUTSIDE_TOOL} cannot run ({err})")], [], None
    # Exit 1 means work is left, and still prints the JSON; anything else is no answer.
    try:
        data = json.loads(done.stdout) if done.returncode in (0, 1) else None
        part = data["card"]
        called, machine = list(part["called"]), list(part["machine"])
        ok_ids = [str(r.get("id", "")) for r in data.get("ok", [])]
    except (ValueError, KeyError, TypeError, AttributeError):
        lines = [ln for ln in done.stderr.strip().splitlines() if ln.strip()]
        reason = lines[-1] if lines else f"exit {done.returncode}, no JSON on standard output"
        return [_ledger_unknown(f"{OUTSIDE_TOOL} status gave no card ({reason})")], [], None
    if shutil.which("gh") is None:
        # The ledger's own row names only the first reason it could not answer; say this one too.
        called.append(
            row(
                "Work on GitHub",
                "find out why",
                "unknown: gh is not installed or not on PATH, so GitHub cannot be asked",
                "install gh and sign in: gh auth login",
                "ops/outside.toml",
                known=False,
            )
        )
    return called, machine, ok_ids


def team_layers(root: Path, ok_ids: list[str] | None) -> list[dict[str, str]]:
    """What the layers that are on do alone (ruling 10). The deploy statement needs the ledger:
    when it could not be read (`ok_ids` is None) the ledger's own unknown row stands for it."""
    items = []
    try:
        caps = _read_json(root / MANIFEST).get("capabilities", [])
    except (OSError, ValueError, AttributeError):
        caps = []
    if isinstance(caps, list) and "github-agents" in caps:
        items.append(
            machine_item(
                "an agent on GitHub works on issues and pull requests; "
                "its merges follow the same tiers",
                f"{MANIFEST}: capabilities",
            )
        )
    if (root / DEPLOY_WORKFLOW).is_file() and ok_ids is not None:
        if any("DEPLOY_ENABLED" in ident for ident in ok_ids):
            items.append(machine_item("deploys to staging after each merge", DEPLOY_WORKFLOW))
        else:
            items.append(
                machine_item(
                    "staging deploys are off: add a DEPLOY_ENABLED row to ops/outside.toml "
                    "once make deploy works",
                    DEPLOY_WORKFLOW,
                )
            )
    return items


def team_sources(root: Path) -> dict[str, Any]:
    """The team level's parts: the policy, the ledger and the layers."""
    policy_called, policy_machine = team_policy(root)
    ledger_called, ledger_machine, ok_ids = team_ledger(root)
    return {
        "called": policy_called + ledger_called,
        "machine": policy_machine + team_layers(root, ok_ids) + ledger_machine,
        "next_level": [],
    }


def _level_sources(root: Path, level: str) -> dict[str, Any]:
    """The parts a level draws from its own tools. Starter has none beyond the files read above;
    the team level adds its gate, its ledger and its layers (`team_sources`)."""
    if level == LEVEL_STARTER:
        return {
            "called": starter_called(root),
            "machine": starter_machine(root),
            "next_level": list(NEXT_LEVEL),
        }
    return team_sources(root)


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
