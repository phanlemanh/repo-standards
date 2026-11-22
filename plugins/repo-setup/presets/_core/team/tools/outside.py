#!/usr/bin/env python3
"""Work outside the repository: what is in place, what the machine applies, what is yours.

  python3 tools/outside.py [--root DIR] status [--json] [--draft]

The ledger is two files (see tools/outside_ledger.py): governance/outside.toml, the kinds of
work the machine may do, and ops/outside.toml, each piece of work. `status` reads both from the
default branch of the remote (origin/HEAD), never from the working tree: a command runs only
after the pull request that brings it is merged. A row only the working tree has is listed as
not merged, and its check does not run. `--draft` prints the commands the working tree would
run, and runs none. A repository without a remote reads its working tree, and says so.

Each check answers within OUTSIDE_TIMEOUT seconds (default 30). A check that cannot run, or
whose answer cannot be read, is unknown: never in place.

Exit codes: 0 nothing is left to do; 1 work is left (the machine's, yours, unknown or refused);
2 a wrong call, a file that is not valid TOML, or no governance/outside.toml.

The value of a key is never read, printed or passed as an argument. Only the Python standard
library is used (Python 3.11 or later).
"""

from __future__ import annotations

import argparse
import json
import os
import shlex
import subprocess
import sys
from collections.abc import Mapping
from dataclasses import asdict, dataclass
from pathlib import Path

if sys.version_info < (3, 11):  # noqa: UP036 - tomllib, read by outside_ledger
    print("tools/outside.py needs Python 3.11 or later.", file=sys.stderr)
    sys.exit(2)

import outside_ledger as ledger

LISTS = ("ok", "apply", "yours", "decisions", "unknown", "unmerged", "refused")
LEFT = ("apply", "yours", "unknown", "refused")
DEFAULT_TIMEOUT = 30.0
NO_REMOTE = "no default branch on a remote: reading the working tree"


class CallError(RuntimeError):
    """A wrong call or a state this tool cannot work from: exit code 2."""


@dataclass(frozen=True)
class Row:
    id: str
    kind: str
    where: str
    why: str
    how: str


def _say(text: str) -> None:
    print(text, file=sys.stderr)


def _timeout() -> float:
    raw = os.environ.get("OUTSIDE_TIMEOUT", "")
    if not raw:
        return DEFAULT_TIMEOUT
    try:
        value = float(raw)
    except ValueError:
        value = 0.0
    if value <= 0:
        raise CallError(f"OUTSIDE_TIMEOUT must be a number of seconds above 0, not {raw!r}")
    return value


def _git(root: Path, *args: str, timeout: float | None = None) -> subprocess.CompletedProcess[str]:
    env = {**os.environ, "GIT_TERMINAL_PROMPT": "0"}
    try:
        return subprocess.run(  # noqa: S603
            ["git", *args],  # noqa: S607
            cwd=root,
            capture_output=True,
            text=True,
            stdin=subprocess.DEVNULL,
            timeout=timeout,
            env=env,
            check=False,
        )
    except subprocess.TimeoutExpired:
        return subprocess.CompletedProcess(["git", *args], 124, "", "no answer in time")


def repo_root(start: Path) -> Path:
    done = _git(start, "rev-parse", "--show-toplevel")
    if done.returncode != 0:
        raise CallError(f"{start} is not inside a git repository")
    return Path(done.stdout.strip())


def base_ref(root: Path) -> str | None:
    """origin/<default branch>, or None when the repository has no remote named origin."""
    if "origin" not in _git(root, "remote").stdout.split():
        return None
    known = _git(root, "symbolic-ref", "-q", "--short", "refs/remotes/origin/HEAD")
    if known.returncode == 0 and known.stdout.strip():
        return known.stdout.strip()
    asked = _git(root, "ls-remote", "--symref", "origin", "HEAD", timeout=_timeout())
    for line in asked.stdout.splitlines():
        head, _, name = line.partition("\t")
        if name == "HEAD" and head.startswith("ref: refs/heads/"):
            return "origin/" + head[len("ref: refs/heads/") :]
    raise CallError(
        "origin has a default branch this tool cannot read: "
        "run `git remote set-head origin --auto`, then again"
    )


def _fetch(root: Path, ref: str) -> None:
    branch = ref.split("/", 1)[1]
    fetched = _git(root, "fetch", "-q", "origin", branch, timeout=_timeout())
    if fetched.returncode != 0:
        _say(f"could not fetch {ref}: using the copy from the last fetch")
    if _git(root, "rev-parse", "-q", "--verify", ref + "^{commit}").returncode != 0:
        raise CallError(f"{ref} is not here: fetch it first")


def read_ledger(root: Path, ref: str | None) -> tuple[str, str]:
    """The text of the recipes file and of the items file, at `ref` or in the working tree."""

    def one(path: str) -> str:
        if ref is None:
            file = root / path
            return file.read_text(encoding="utf-8") if file.is_file() else ""
        shown = _git(root, "show", f"{ref}:{path}")
        return shown.stdout if shown.returncode == 0 else ""

    return one(ledger.RECIPES_PATH), one(ledger.ITEMS_PATH)


def _run(argv: list[str], root: Path, timeout: float) -> tuple[int | None, str, str]:
    """(exit code or None, output, why it could not run)."""
    try:
        done = subprocess.run(  # noqa: S603
            argv,
            cwd=root,
            capture_output=True,
            text=True,
            stdin=subprocess.DEVNULL,
            timeout=timeout,
            check=False,
        )
    except FileNotFoundError:
        return None, "", f"command not found: {argv[0]}"
    except subprocess.TimeoutExpired:
        return None, "", f"no answer in {timeout:g} s: {shlex.join(argv)}"
    except OSError as exc:
        return None, "", f"cannot run {argv[0]}: {exc}"
    return done.returncode, done.stdout, ""


def _check_one(
    recipe: ledger.Recipe, fields: Mapping[str, str], root: Path, timeout: float
) -> tuple[str, str]:
    """("ok" | "missing" | "unknown", why) for one recipe of one row."""
    argv = ledger.render(recipe.check, fields)
    code, out, failed = _run(argv, root, timeout)
    if code is None:
        return "unknown", failed
    if recipe.missing_exit is not None and code == recipe.missing_exit:
        return "missing", "not in place"
    if code != 0:
        return "unknown", f"the check exited {code}: {shlex.join(argv)}"
    if recipe.expect:
        hit = out.strip() == ledger.render_text(recipe.expect, fields)
    elif recipe.expect_line:
        want = ledger.render_text(recipe.expect_line, fields)
        hit = want in (line.strip() for line in out.splitlines())
    else:
        hit = True
    return ("ok", "checked: in place") if hit else ("missing", "not in place")


def assess(
    item: ledger.Item, recipes: Mapping[str, ledger.Recipe], root: Path, timeout: float
) -> tuple[str, str]:
    """("ok" | "missing" | "partial" | "unknown", why) of a row that is not a decision."""
    if not item.recipes:
        if item.done:
            return "ok", f"recorded by hand on {item.done}, not checked"
        return "missing", "not done yet"
    states = [(n, *_check_one(recipes[n], item.fields, root, timeout)) for n in item.recipes]
    unknown = [why for _, state, why in states if state == "unknown"]
    if unknown:
        return "unknown", unknown[0]
    present = [recipes[n].where for n, state, _ in states if state == "ok"]
    if len(present) == len(states):
        return "ok", "checked: in place"
    if not present:
        return "missing", "not in place"
    return "partial", f"in {', '.join(present)} only"


def check_item(
    item: ledger.Item, recipes: Mapping[str, ledger.Recipe], root: Path | None = None
) -> str:
    """ "ok", "missing", "partial" or "unknown"."""
    return assess(item, recipes, root or Path.cwd(), _timeout())[0]


def _where(item: ledger.Item, recipes: Mapping[str, ledger.Recipe]) -> str:
    return ", ".join(recipes[n].where for n in item.recipes)


def _place(
    item: ledger.Item, state: str, why: str, recipes: Mapping[str, ledger.Recipe]
) -> tuple[str, str]:
    """(list, why) for a row whose state is known."""
    if state in ("ok", "unknown"):
        return state, why
    if item.kind == "setting":
        if all(recipes[n].apply for n in item.recipes):
            return "apply", "not in place: the machine applies it"
        return "yours", "not in place, and the machine may only check it"
    if item.kind == "secret" and state == "partial":
        return "yours", f"{why}: a new value would replace the one in use, so you decide"
    if item.kind == "secret" and item.source == "generated":
        return "apply", "missing: the machine generates it and stores it"
    if item.kind == "secret":
        return "yours", "missing: a machine cannot create it"
    return "yours", f"{why}: a person does it once"


def classify(
    items: list[ledger.Item], recipes: Mapping[str, ledger.Recipe], root: Path, timeout: float
) -> dict[str, list[Row]]:
    lists: dict[str, list[Row]] = {name: [] for name in LISTS}
    for item in items:
        if item.kind == "decision":
            lists["decisions"].append(Row(item.id, item.kind, "", item.when or "always yours", ""))
            continue
        state, why = assess(item, recipes, root, timeout)
        name, reason = _place(item, state, why, recipes)
        lists[name].append(Row(item.id, item.kind, _where(item, recipes), reason, item.how))
    return lists


def _refused_rows(refused: list[str]) -> list[Row]:
    rows = []
    for line in refused:
        label, _, why = line.partition(": ")
        rows.append(Row(label, "", "", why, ""))
    return rows


def _parse(texts: tuple[str, str], what: str) -> tuple[dict[str, ledger.Recipe], list, list[str]]:
    recipes_text, items_text = texts
    if not recipes_text.strip():
        raise CallError(f"{ledger.RECIPES_PATH} is not on {what}: there is nothing to check")
    try:
        recipes = ledger.parse_recipes(recipes_text)
        items, refused = ledger.parse_items(items_text, recipes)
    except ledger.LedgerError as exc:
        raise CallError(f"{what}: {exc}") from exc
    return recipes, items, refused


def _unmerged(root: Path, base_ids: set[str]) -> list[Row]:
    """Rows only the working tree has. Their checks do not run."""
    try:
        recipes, items, _ = _parse(read_ledger(root, None), "the working tree")
    except CallError as exc:
        _say(f"the ledger of the working tree cannot be read: {exc}")
        return []
    why = "only in the working tree: it runs once its pull request is merged"
    return [
        Row(i.id, i.kind, _where(i, recipes), why, i.how) for i in items if i.id not in base_ids
    ]


def status(root: Path) -> tuple[str | None, dict[str, list[Row]]]:
    timeout = _timeout()
    ref = base_ref(root)
    if ref is None:
        _say(NO_REMOTE)
    else:
        _fetch(root, ref)
    recipes, items, refused = _parse(read_ledger(root, ref), ref or "the working tree")
    lists = classify(items, recipes, root, timeout)
    lists["refused"] = _refused_rows(refused)
    if ref is not None:
        lists["unmerged"] = _unmerged(root, {i.id for i in items})
    return ref, lists


TITLES = {
    "ok": "In place",
    "apply": "The machine will apply",
    "yours": "Yours",
    "decisions": "Decisions, always yours",
    "unknown": "Unknown",
    "unmerged": "Not merged yet",
    "refused": "Refused rows",
}
NEXT = {
    "apply": "python3 tools/outside.py apply",
    "yours": "keys: python3 tools/outside.py secrets, in a terminal of your own",
}


def print_text(ref: str | None, lists: dict[str, list[Row]]) -> None:
    print(f"Ledger read from {ref or 'the working tree'}.")
    for name in LISTS:
        rows = lists[name]
        if not rows:
            continue
        hint = f"   -> {NEXT[name]}" if name in NEXT else ""
        print(f"\n{TITLES[name]} ({len(rows)}){hint}")
        for row in rows:
            print(f"  - {row.id}" + (f"  [{row.where}]" if row.where else ""))
            if name != "ok" or "not checked" in row.why:
                print(f"      why: {row.why}")
            if row.how and name != "ok":
                print(f"      how: {row.how}")
    counts = {name: len(lists[name]) for name in LEFT}
    if not any(counts.values()):
        print("\nNothing left to do.")
        return
    print(
        f"\nLeft: {counts['apply']} for the machine, {counts['yours']} for you, "
        f"{counts['unknown']} unknown, {counts['refused']} refused."
    )


def draft(root: Path) -> tuple[list[str], list[list[str]], list[tuple[str, list[list[str]]]]]:
    """(ids, commands, commands by row) of the working tree. Nothing runs."""
    recipes, items, refused = _parse(read_ledger(root, None), "the working tree")
    for line in refused:
        _say(f"refused: {line}")
    by_row: list[tuple[str, list[list[str]]]] = []
    for item in items:
        commands = [
            ledger.render(argv, item.fields)
            for name in item.recipes
            for argv in (recipes[name].check, recipes[name].apply, recipes[name].store)
            if argv
        ]
        by_row.append((item.id, commands))
    return [i.id for i in items], [c for _, cs in by_row for c in cs], by_row


def _status_command(root: Path, as_json: bool, show_draft: bool) -> int:
    if show_draft:
        ids, commands, by_row = draft(root)
        if as_json:
            print(json.dumps({"all": ids, "commands": commands}, indent=2))
            return 0
        for ident, row_commands in by_row:
            print(f"# {ident}")
            for argv in row_commands:
                print(shlex.join(argv))
        return 0
    ref, lists = status(root)
    if as_json:
        out = {"base": ref, **{name: [asdict(r) for r in lists[name]] for name in LISTS}}
        print(json.dumps(out, indent=2))
    else:
        print_text(ref, lists)
    return 1 if any(lists[name] for name in LEFT) else 0


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="outside.py",
        description=__doc__.split("\n")[0] if __doc__ else None,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--root", default=None, help="the repository (default: the current one)")
    sub = parser.add_subparsers(dest="command")
    st = sub.add_parser("status", help="what is in place, the machine's work and yours")
    st.add_argument("--json", action="store_true", help="print JSON")
    st.add_argument("--draft", action="store_true", help="print the working tree's commands")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        root = repo_root(Path(args.root) if args.root else Path.cwd())
        return _status_command(root, getattr(args, "json", False), getattr(args, "draft", False))
    except CallError as exc:
        _say(str(exc))
        return 2


if __name__ == "__main__":
    sys.exit(main())
