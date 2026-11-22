#!/usr/bin/env python3
"""The ledger of work outside the repository, read and checked. It runs nothing.

Two files say what has to be true outside the repository (GitHub settings, variables, keys, a
deploy platform):

  governance/outside.toml   the kinds of work the machine may do: one command template each
                            ("recipe"). Changing one changes the rules of the game.
  ops/outside.toml          each piece of work ("item"): a row that names a recipe, a decision
                            that is always a person's, or an action a person takes once.

A recipe has `where`, `kind` (setting, secret or action) and `check`, a command that answers
"is it in place?". A setting may have `apply`; one without it is only checked. A secret has
`store`, a command that takes the value on standard input, and never `apply`. `expect` (the whole
output) or `expect_line` (one line of it) says what the check has to print; `missing_exit` names
the exit code that means "not in place".

Commands are lists of arguments: no shell reads them. `{key}` in an argument is replaced by the
row's own key of that name, once; the value put in is never read again.

Only the Python standard library is used (tomllib: Python 3.11 or later).
"""

from __future__ import annotations

import re
import tomllib
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from types import MappingProxyType
from typing import Any

KINDS = ("setting", "secret", "decision", "action")
RECIPES_PATH = "governance/outside.toml"
ITEMS_PATH = "ops/outside.toml"
SOURCES = ("person", "generated")
RESERVED = ("recipe", "decision", "action", "source", "how", "when", "done")
COMMANDS = ("check", "apply", "store")
_PLACEHOLDER = re.compile(r"\{([A-Za-z_][A-Za-z0-9_]*)\}")


class LedgerError(ValueError):
    """A file that cannot be read as TOML, or a recipe that breaks the rules above."""


@dataclass(frozen=True)
class Recipe:
    name: str
    where: str
    kind: str
    check: tuple[str, ...]
    expect: str
    expect_line: str
    missing_exit: int | None
    apply: tuple[str, ...]
    store: tuple[str, ...]


@dataclass(frozen=True)
class Item:
    id: str
    kind: str
    recipes: tuple[str, ...]
    fields: Mapping[str, str]
    source: str
    how: str
    when: str
    done: str


def _toml(text: str, what: str) -> dict[str, Any]:
    try:
        return tomllib.loads(text)
    except tomllib.TOMLDecodeError as exc:
        raise LedgerError(f"{what} is not valid TOML: {exc}") from exc


def _command(table: Mapping[str, Any], key: str, recipe: str) -> tuple[str, ...]:
    value = table.get(key, [])
    if not isinstance(value, list) or not all(isinstance(a, str) and a for a in value):
        raise LedgerError(f"recipe {recipe}: {key} must be a list of arguments, each a string")
    return tuple(value)


def _text(table: Mapping[str, Any], key: str, recipe: str) -> str:
    value = table.get(key, "")
    if not isinstance(value, str):
        raise LedgerError(f"recipe {recipe}: {key} must be a string")
    return value


def _recipe(name: str, table: Any) -> Recipe:
    if not isinstance(table, dict):
        raise LedgerError(f"recipe {name}: must be a table")
    kind = table.get("kind")
    if kind not in KINDS:
        raise LedgerError(f"recipe {name}: kind must be one of {', '.join(KINDS)}")
    if kind == "decision":
        raise LedgerError(f"recipe {name}: a decision has no command, so it has no recipe")
    check, apply, store = (_command(table, key, name) for key in COMMANDS)
    if not check:
        raise LedgerError(
            f"recipe {name}: a {kind} needs check, the command that says it is in place"
        )
    if kind == "secret" and not store:
        raise LedgerError(f"recipe {name}: a secret needs store, the command that takes the value")
    if kind == "secret" and apply:
        raise LedgerError(f"recipe {name}: a secret has no apply: its value goes through store")
    if kind != "secret" and store:
        raise LedgerError(f"recipe {name}: only a secret has store")
    missing_exit = table.get("missing_exit")
    if missing_exit is not None and (
        isinstance(missing_exit, bool) or not isinstance(missing_exit, int)
    ):
        raise LedgerError(f"recipe {name}: missing_exit must be a whole number")
    where = _text(table, "where", name)
    if not where:
        raise LedgerError(f"recipe {name}: where names the service, and is missing")
    return Recipe(
        name=name,
        where=where,
        kind=kind,
        check=check,
        expect=_text(table, "expect", name),
        expect_line=_text(table, "expect_line", name),
        missing_exit=missing_exit,
        apply=apply,
        store=store,
    )


def parse_recipes(text: str) -> dict[str, Recipe]:
    """The recipes of governance/outside.toml, by name. A bad one raises LedgerError."""
    tables = _toml(text, RECIPES_PATH).get("recipe", {})
    if not isinstance(tables, dict):
        raise LedgerError(f"{RECIPES_PATH}: recipe must be a table of recipes")
    return {name: _recipe(name, table) for name, table in tables.items()}


def placeholders(recipe: Recipe) -> set[str]:
    """Every {key} the commands and expectations of a recipe use."""
    texts = [*recipe.check, *recipe.apply, *recipe.store, recipe.expect, recipe.expect_line]
    return {name for text in texts for name in _PLACEHOLDER.findall(text)}


def render_text(text: str, fields: Mapping[str, str]) -> str:
    """`text` with each {key} replaced once by the row's key; the value is not read again."""

    def value(match: re.Match[str]) -> str:
        key = match.group(1)
        if key not in fields:
            raise LedgerError(f"a command uses the key {key} and the row does not have it")
        return fields[key]

    return _PLACEHOLDER.sub(value, text)


def render(argv: Sequence[str], fields: Mapping[str, str]) -> list[str]:
    """The arguments of a command for one row. Each stays one argument, whatever its value."""
    return [render_text(arg, fields) for arg in argv]


def _no_flags(recipe: Recipe, fields: Mapping[str, str]) -> None:
    """A value put in a command never becomes one of its flags (`name = "--env-file=.env"`).

    An argument the recipe writes as a placeholder may start with "-" only right after an option
    of the recipe's own, which takes it as its value (`--body {value}` with value "-1").
    """
    for argv in (recipe.check, recipe.apply, recipe.store):
        for i, arg in enumerate(argv):
            out = render_text(arg, fields)
            if arg.startswith("-") or not out.startswith("-"):
                continue
            if i > 0 and argv[i - 1].startswith("-"):
                continue
            raise LedgerError(
                f"recipe {recipe.name}: the value {out!r} would become a flag of the command"
            )


def _label(row: Mapping[str, Any], number: int) -> str:
    for key in ("name", "decision", "action"):
        if isinstance(row.get(key), str) and row[key]:
            return f"row {number} ({row[key]})"
    return f"row {number}"


def _row_recipes(row: Mapping[str, Any], recipes: Mapping[str, Recipe]) -> tuple[str, ...]:
    named = row.get("recipe", [])
    names = [named] if isinstance(named, str) else named
    if not isinstance(names, list) or not all(isinstance(n, str) for n in names):
        raise LedgerError("recipe must be a name or a list of names")
    for name in names:
        if name not in recipes:
            raise LedgerError(f"no recipe named {name} in {RECIPES_PATH}")
    if len(names) > 1 and any(recipes[n].kind != "secret" for n in names):
        raise LedgerError("several recipes are allowed only when each is a secret")
    return tuple(names)


def _item(row: Mapping[str, Any], recipes: Mapping[str, Recipe]) -> Item:
    """One row as an Item; LedgerError says why the row is refused."""
    names = _row_recipes(row, recipes)
    fields = {k: v for k, v in row.items() if k not in RESERVED}
    odd = sorted(k for k, v in fields.items() if not isinstance(v, str))
    if odd:
        raise LedgerError(f"{', '.join(odd)} must be a string")
    notes = {key: row.get(key, "") for key in ("how", "when", "done")}
    if not all(isinstance(v, str) for v in notes.values()):
        raise LedgerError("how, when and done must be strings")
    source = ""
    if isinstance(row.get("decision"), str) and row["decision"]:
        if names:
            raise LedgerError("a decision has no recipe")
        kind, ident = "decision", f"decision:{row['decision']}"
    elif isinstance(row.get("action"), str) and row["action"]:
        if any(recipes[n].kind != "action" for n in names):
            raise LedgerError("an action can only name a recipe of kind action")
        kind, ident = "action", f"action:{row['action']}"
    else:
        if not names:
            raise LedgerError("names no recipe, decision or action")
        kind = recipes[names[0]].kind
        if kind == "action":
            raise LedgerError('a recipe of kind action belongs to a row with action = "..."')
        if not fields.get("name"):
            raise LedgerError("needs name")
        ident = f"{names[0]}:{fields['name']}" + (f"@{fields['env']}" if fields.get("env") else "")
        if kind == "secret":
            source = row.get("source", "person")
            if source not in SOURCES:
                raise LedgerError(f"source must be one of {', '.join(SOURCES)}")
    for name in names:
        lacking = sorted(placeholders(recipes[name]) - set(fields))
        if lacking:
            raise LedgerError(
                f"recipe {name} uses the key {lacking[0]} and the row does not have it"
            )
    for name in names:
        _no_flags(recipes[name], fields)
    return Item(
        id=ident,
        kind=kind,
        recipes=names,
        fields=MappingProxyType(fields),
        source=source,
        **notes,
    )


def parse_items(text: str, recipes: Mapping[str, Recipe]) -> tuple[list[Item], list[str]]:
    """The rows of ops/outside.toml, and one sentence for each row that is refused.

    A refused row stops nothing else: the other rows are still used.
    """
    rows = _toml(text, ITEMS_PATH).get("item", [])
    if not isinstance(rows, list):
        raise LedgerError(f"{ITEMS_PATH}: item must be a list of rows ([[item]])")
    items: list[Item] = []
    refused: list[str] = []
    seen: set[str] = set()
    for number, row in enumerate(rows, start=1):
        if not isinstance(row, dict):
            refused.append(f"row {number}: must be a table")
            continue
        try:
            item = _item(row, recipes)
        except LedgerError as exc:
            refused.append(f"{_label(row, number)}: {exc}")
            continue
        if item.id in seen:
            refused.append(f"{_label(row, number)}: {item.id} is already a row above")
            continue
        seen.add(item.id)
        items.append(item)
    return items, refused
