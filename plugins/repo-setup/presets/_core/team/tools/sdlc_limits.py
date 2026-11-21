"""Thresholds of the flow measure, for tools/sdlc_metrics.py. Standard library only.

Each line of the report says whether a number is over its threshold: over, within, too few to
tell, or not read. Nothing else follows from it: a number over its threshold never changes the
exit code of the tool, and no check goes red (the owner, 2026-11-21).

The values are starting values. The machine suggested them on 2026-11-16, and nothing has derived
them from data yet: change them here when the numbers say so.
"""

from __future__ import annotations

from typing import Any

# Late red: of the heads where the gate passed, the share that had a job end red afterwards.
LATE_RED_MAX = 0.20
# Red on the default branch, per workflow: the share of finished runs that were red.
DEFAULT_RED_MAX = 1 / 20
# One file in the conflicting merges of the default branch into a pull request branch.
ONE_FILE_MAX = 0.5
# Below this many cases a share says too little: 1 in 20 cannot be told from fewer than 20.
MIN_SAMPLE = 20

LATE_RED = "late red"
DEFAULT_RED = "default branch red"
ONE_FILE = "one file in the conflicting merges"
OVER, WITHIN, TOO_FEW, NOT_READ = "over", "within", "too few to tell", "not read"


def verdict(count: int, sample: int, limit: float) -> str:
    if sample < MIN_SAMPLE:
        return TOO_FEW
    return OVER if count / sample > limit else WITHIN


def row(measure: str, count: int, sample: int, limit: float, subject: str = "") -> dict[str, Any]:
    return {
        "measure": measure,
        "subject": subject,
        "count": count,
        "sample": sample,
        "limit": limit,
        "verdict": verdict(count, sample, limit),
    }


def unread(measure: str, reason: str) -> dict[str, Any]:
    return {"measure": measure, "subject": "", "verdict": NOT_READ, "reason": reason}


def thresholds(m: dict[str, Any]) -> list[dict[str, Any]]:
    """One line per measure; red on the default branch has one per workflow. A part that could not
    be read gives a line that says so, never a verdict."""
    ci, merges = m["ci"], m["back_merges"]
    lines: list[dict[str, Any]] = []
    if "unread" in ci:
        lines += [unread(LATE_RED, ci["unread"]), unread(DEFAULT_RED, ci["unread"])]
    else:
        red, passed = ci["late_red"]
        lines.append(row(LATE_RED, red, passed, LATE_RED_MAX))
        for name, (reds, runs) in sorted(ci["default_branch"].items()):
            lines.append(row(DEFAULT_RED, reds, runs, DEFAULT_RED_MAX, name))
    if "unread" in merges:
        lines.append(unread(ONE_FILE, merges["unread"]))
    elif merges["files"]:
        # the file in conflict most often comes first
        name, count = next(iter(merges["files"].items()))
        lines.append(row(ONE_FILE, count, merges["conflicting"], ONE_FILE_MAX, name))
    return lines


def limit_text(measure: str) -> str:
    if measure == LATE_RED:
        return f"more than {round(LATE_RED_MAX * 100)}%"
    if measure == DEFAULT_RED:
        return f"more than 1 in {round(1 / DEFAULT_RED_MAX)}"
    return "more than half" if ONE_FILE_MAX == 0.5 else f"more than {round(ONE_FILE_MAX * 100)}%"
