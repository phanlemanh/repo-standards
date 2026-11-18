#!/usr/bin/env python3
"""The one check that stands for every CI tier.

A workflow sets `env: NEEDS_JSON: ${{ toJSON(needs) }}` (through `env:`, never pasted into the
command) and runs this tool in a final job that needs every tier. The summary check is green only
when every tier ended `success`: a skipped, cancelled or failed tier is red, so a tier that did
not run can never pass for one that did.

  python3 tools/ci_verdict.py

Exit codes: 0 every tier succeeded, 1 otherwise (one line per tier that did not, as
`<tier>: <result> — <reason>`; an empty or unreadable NEEDS_JSON is red too).

Only the Python standard library is used.
"""

from __future__ import annotations

import json
import os
import sys

ENV_NEEDS = "NEEDS_JSON"
REASONS = {
    "skipped": "did not run: an earlier tier failed, or this pull request is a draft",
    "cancelled": "cancelled: a newer push replaces this run",
    "failure": "failed",
}


def read_needs(text: str) -> dict[str, object]:
    """The `needs` object, or ValueError when it is empty, not JSON or not an object."""
    try:
        needs = json.loads(text)
    except json.JSONDecodeError as err:
        raise ValueError(f"{ENV_NEEDS} is not JSON: {err}") from err
    if not isinstance(needs, dict) or not needs:
        raise ValueError(f"{ENV_NEEDS} has no tiers in it")
    return needs


def tier_result(tier: object) -> str:
    result = tier.get("result") if isinstance(tier, dict) else None
    return result if isinstance(result, str) else "unknown"


def verdict(needs: dict[str, object]) -> list[str]:
    """One line per tier whose result is not `success`."""
    lines = []
    for name, tier in needs.items():
        result = tier_result(tier)
        if result != "success":
            lines.append(f"{name}: {result} — {REASONS.get(result, 'no usable result')}")
    return lines


def main(argv: list[str]) -> int:
    if argv:
        print("usage: ci_verdict.py (reads NEEDS_JSON from the environment)", file=sys.stderr)
        return 2
    try:
        lines = verdict(read_needs(os.environ.get(ENV_NEEDS, "")))
    except ValueError as err:
        print(err, file=sys.stderr)
        return 1
    for line in lines:
        print(line)
    return 1 if lines else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
