#!/usr/bin/env python3
"""The combinations of tests/e2e.sh that a change reaches.

Reads the files a change touches (git, from --base to --head) and prints one line, the value the
CI gives tests/e2e.sh (docs/superpowers/specs/2026-11-17-tiered-ci-design.md, section 6):

  none    only docs/** and Markdown files at the root changed: e2e.sh is not run
  all     run every combination, and the upgrade case (e2e.sh with PRESETS unset)
  <list>  run these entries of ALL and COMBOS, space separated, as PRESETS

  python3 tests/e2e_select.py --base <rev> [--head <rev>] [--e2e <path to e2e.sh>]

How a file is placed:
  docs/**, *.md at the root            nothing (a change of only these prints none)
  plugins/repo-setup/presets/<p>/**    every entry whose stack is p or extends p (preset.toml)
  plugins/repo-setup/capabilities/<c>/** every entry whose capabilities hold c
  anything else                        all (scripts, presets/_core, skills, tests, .github, ...)

When unsure, everything runs: a file no row places, a preset or capability no entry reaches, a
change git cannot list, an e2e.sh with no COMBOS line, any error. Why goes to stderr. Exit codes:
0 with a line printed, 2 on a wrong call. Only the Python standard library is used.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tomllib
from collections.abc import Iterable
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PLUGIN = ROOT / "plugins" / "repo-setup"
PRESETS_DIR = "plugins/repo-setup/presets/"
CAPABILITIES_DIR = "plugins/repo-setup/capabilities/"
NONE, ALL = "none", "all"

# The lines of tests/e2e.sh this reads: the COMBOS list, and the presets taken out of ALL.
COMBOS_LINE = re.compile(r'^COMBOS="([^"]*)"\s*$', re.MULTILINE)
ALL_DROP = re.compile(r'ALL="\$\{ALL/ ([\w.-]+) / \}"')


class Unsure(Exception):
    """Something this cannot read or place: everything runs, and the message says why."""


def changed_files(base: str, head: str) -> list[str]:
    """The paths the head changes since it left the base. A move counts for both its ends."""
    try:
        done = subprocess.run(
            ["git", "diff", "--name-only", "--no-renames", "-z", f"{base}...{head}", "--"],
            capture_output=True, text=True, check=False,
        )
    except OSError as err:
        raise Unsure(f"git cannot run: {err}") from err
    if done.returncode != 0:
        raise Unsure(f"git cannot list the changes from {base} to {head}: {done.stderr.strip()}")
    files = [f for f in done.stdout.split("\0") if f]
    if not files:
        # Nothing to place is no proof that nothing changed.
        raise Unsure(f"git lists no changed file from {base} to {head}")
    return files


def read_entries(e2e: Path) -> list[str]:
    """ALL then COMBOS, as tests/e2e.sh builds them.

    ALL comes from the same command e2e.sh runs (apply.py --list-presets --json), less the
    presets e2e.sh drops with ALL="${ALL/ <p> / }"; COMBOS is its COMBOS="..." line. Reading
    e2e.sh itself keeps the two from drifting apart.
    """
    try:
        text = e2e.read_text(encoding="utf-8")
    except OSError as err:
        raise Unsure(f"cannot read {e2e}: {err}") from err
    combos = COMBOS_LINE.search(text)
    if combos is None:
        raise Unsure(f'{e2e} has no COMBOS="..." line')
    listed = subprocess.run(
        [sys.executable, str(PLUGIN / "scripts" / "apply.py"), "--list-presets", "--json"],
        capture_output=True, text=True, check=False,
    )
    if listed.returncode != 0:
        raise Unsure(f"apply.py --list-presets failed: {listed.stderr.strip()}")
    dropped = set(ALL_DROP.findall(text))
    bare = [name for name in json.loads(listed.stdout) if name not in dropped]
    return bare + combos.group(1).split()


def stack_of(entry: str) -> str:
    return entry.split(":")[0]


def capabilities_of(entry: str) -> set[str]:
    fields = entry.split(":")
    return {c for c in fields[3].split(",") if c} if len(fields) > 3 else set()


def lineage(preset: str) -> list[str]:
    """The preset, then every preset it extends, read from each preset.toml."""
    chain: list[str] = []
    while preset and preset not in chain:
        chain.append(preset)
        toml = PLUGIN / "presets" / preset / "preset.toml"
        if not toml.is_file():
            break
        with toml.open("rb") as fh:
            preset = str(tomllib.load(fh).get("extends", ""))
    return chain


def is_doc(path: str) -> bool:
    return path.startswith("docs/") or ("/" not in path and path.endswith(".md"))


def folder_in(path: str, prefix: str) -> str | None:
    """The first folder under prefix that holds the path, or None when the path is not in one."""
    if not path.startswith(prefix):
        return None
    rest = path[len(prefix):].split("/")
    return rest[0] if len(rest) > 1 and rest[0] else None


def reached(path: str, entries: list[str]) -> list[str]:
    """The entries one non-docs file reaches; Unsure when the file has no row or reaches none."""
    preset = folder_in(path, PRESETS_DIR)
    capability = folder_in(path, CAPABILITIES_DIR)
    if preset is not None and preset != "_core":
        hits = [e for e in entries if preset in lineage(stack_of(e))]
    elif capability is not None:
        hits = [e for e in entries if capability in capabilities_of(e)]
    else:
        raise Unsure(f"{path} is outside every preset and capability folder")
    if not hits:
        # A preset or capability no entry uses: when unknown, run everything.
        raise Unsure(f"{path} reaches no combination of tests/e2e.sh")
    return hits


def select(files: Iterable[str], entries: list[str]) -> tuple[str, str]:
    """The line to print and why."""
    chosen: set[str] = set()
    for path in files:
        if not is_doc(path):
            chosen.update(reached(path, entries))
    if not chosen:
        return NONE, "only docs/ and Markdown files at the root changed"
    return " ".join(e for e in entries if e in chosen), "the presets and capabilities this change touches"


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="Print the combinations of tests/e2e.sh a change reaches.")
    ap.add_argument("--base", required=True, help="the commit the change is measured from")
    ap.add_argument("--head", default="HEAD", help="the commit of the change (default HEAD)")
    ap.add_argument("--e2e", type=Path, default=ROOT / "tests" / "e2e.sh", help="the e2e.sh to read")
    args = ap.parse_args(argv)
    try:
        line, why = select(changed_files(args.base, args.head), read_entries(args.e2e))
    except Unsure as err:
        line, why = ALL, str(err)
    except Exception as err:  # noqa: BLE001 - any error runs everything, and says so
        line, why = ALL, f"{type(err).__name__}: {err}"
    print(line)
    print(f"e2e_select: {line if line in (NONE, ALL) else 'these combinations'}: {why}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
