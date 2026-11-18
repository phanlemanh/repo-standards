#!/usr/bin/env python3
"""A key for what the heavy CI tier reads.

The heavy tier is a function of the files it reads. This tool hashes those files, so a workflow
can ask "has anything the heavy tier reads changed since a green run?" without a person deciding.

  python3 tools/ci_inputs.py key [--rev REV] [--not-inputs "<pattern> ..."] [--root DIR]
  python3 tools/ci_inputs.py matches <path> [--not-inputs "<pattern> ..."]

`key` prints `sha256:<hex>`, computed from `git ls-tree -r -z --full-tree REV`: the whole tree,
with paths from the repository root whichever folder the tool runs in. It hashes the path, the
mode and type and the blob id of every file that no pattern matches, sorted by path. `matches`
exits 0 when the file is an input and 1 when it is not.

The patterns are the files that are NOT inputs, separated by spaces. Without --not-inputs they
come from the environment variable HEAVY_NOT_INPUTS, and without that from DEFAULT_NOT_INPUTS.

  - A pattern without `/` matches a file at the root only: `*.md` is `README.md`, not `docs/x.md`.
  - A pattern with `/` matches the full path; `**` matches any number of directory levels.

Exit codes: 0 done, 2 wrong call (a revision that does not resolve, not a repository, bad
arguments), 1 git could not be run.

Only the Python standard library is used.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import re
import subprocess
import sys
from pathlib import Path

DEFAULT_NOT_INPUTS = "docs/** wiki/** *.md _acceptance/**"
ENV_NOT_INPUTS = "HEAVY_NOT_INPUTS"


def _glob_to_regex(pattern: str) -> re.Pattern[str]:
    """Turn a glob into a regex: `**` crosses directories, `*` and `?` stay in one part."""
    out: list[str] = []
    i = 0
    while i < len(pattern):
        if pattern.startswith("**/", i):
            out.append("(?:.*/)?")
            i += 3
        elif pattern.startswith("**", i):
            out.append(".*")
            i += 2
        elif pattern[i] == "*":
            out.append("[^/]*")
            i += 1
        elif pattern[i] == "?":
            out.append("[^/]")
            i += 1
        else:
            out.append(re.escape(pattern[i]))
            i += 1
    return re.compile("".join(out) + r"\Z")


def is_not_input(path: str, patterns: list[str]) -> bool:
    """True when a pattern matches the path under the root-only / full-path rule."""
    for pattern in patterns:
        if "/" not in pattern:
            if "/" not in path and _glob_to_regex(pattern).match(path):
                return True
        elif _glob_to_regex(pattern).match(path):
            return True
    return False


def split_patterns(text: str) -> list[str]:
    return text.split()


def list_tree(root: Path, rev: str) -> list[tuple[str, str, str]]:
    """(path, "mode type", blob id) of every file at REV; paths come NUL-separated, never quoted."""
    done = subprocess.run(  # noqa: S603
        ["git", "ls-tree", "-r", "-z", "--full-tree", rev],  # noqa: S607
        cwd=root,
        capture_output=True,
        check=False,
    )
    if done.returncode != 0:
        detail = done.stderr.decode("utf-8", "replace").strip()
        raise RuntimeError(f"git ls-tree -r -z --full-tree {rev} failed: {detail}")
    entries: list[tuple[str, str, str]] = []
    for record in done.stdout.split(b"\0"):
        if not record:
            continue
        meta, _, raw_path = record.partition(b"\t")
        mode, kind, blob = meta.decode("ascii").split()
        entries.append((raw_path.decode("utf-8", "surrogateescape"), f"{mode} {kind}", blob))
    return entries


def input_key(root: Path, rev: str, not_inputs: list[str]) -> str:
    """sha256 over the path, mode/type and blob id of every file that is an input."""
    kept = [e for e in list_tree(root, rev) if not is_not_input(e[0], not_inputs)]
    digest = hashlib.sha256()
    for path, kind, blob in sorted(kept, key=lambda e: e[0].encode("utf-8", "surrogateescape")):
        digest.update(path.encode("utf-8", "surrogateescape"))
        digest.update(f"\0{kind}\0{blob}\n".encode("ascii"))
    return f"sha256:{digest.hexdigest()}"


def _patterns_from(args: argparse.Namespace) -> list[str]:
    if args.not_inputs is not None:
        return split_patterns(args.not_inputs)
    return split_patterns(os.environ.get(ENV_NOT_INPUTS, DEFAULT_NOT_INPUTS))


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="ci_inputs.py", description=__doc__.split("\n")[0])
    sub = parser.add_subparsers(dest="command", required=True)
    key = sub.add_parser("key", help="print the key of what the heavy tier reads")
    key.add_argument("--rev", default="HEAD")
    key.add_argument("--root", default=".", help="the repository (default: the current folder)")
    matches = sub.add_parser("matches", help="exit 0 when PATH is an input, 1 when it is not")
    matches.add_argument("path")
    for p in (key, matches):
        p.add_argument(
            "--not-inputs",
            help=f"space-separated patterns (default: ${ENV_NOT_INPUTS})",
        )
    return parser


def main(argv: list[str]) -> int:
    try:
        args = _parser().parse_args(argv)
    except SystemExit as stop:
        return 2 if stop.code else 0
    patterns = _patterns_from(args)
    if args.command == "matches":
        return 1 if is_not_input(args.path, patterns) else 0
    try:
        print(input_key(Path(args.root), args.rev, patterns))
    except RuntimeError as err:
        print(err, file=sys.stderr)
        return 2
    except OSError as err:
        print(err, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
