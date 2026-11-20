"""How tools/sdlc_metrics.py reads GitHub (through gh) and git. Standard library only.

A part of the report that cannot be read says why: `read_or_say` turns the error into a reason,
never into a zero.
"""

from __future__ import annotations

import concurrent.futures
import datetime as dt
import json
import statistics
import subprocess
import time
from collections.abc import Callable, Iterable
from pathlib import Path
from typing import Any

# The most pull requests one list asks for: a longer list covers part of the window.
PR_LIMIT = 300
GH_TIMEOUT = 120
GH_TRIES = 3
GH_PAUSE = 2
GH_WORKERS = 8
GIT_TIMEOUT = 300


def gh(args: list[str]) -> str:
    """Run gh. A call that fails is tried again unless GitHub refused it (HTTP 4xx)."""
    reason = "gh failed"
    for attempt in range(GH_TRIES):
        if attempt:
            time.sleep(GH_PAUSE)
        try:
            proc = subprocess.run(  # noqa: S603
                ["gh", *args],  # noqa: S607
                capture_output=True,
                text=True,
                timeout=GH_TIMEOUT,
            )
        except subprocess.TimeoutExpired:
            reason = f"gh did not answer in {GH_TIMEOUT} s: gh {' '.join(args[:3])}"
            continue
        if proc.returncode == 0:
            return proc.stdout
        reason = proc.stderr.strip() or "gh failed"
        if "HTTP 4" in reason:
            break
    raise RuntimeError(reason)


def gh_json(args: list[str]) -> Any:
    return json.loads(gh(args) or "null")


def gh_rows(path: str, fields: str, *params: str) -> list[Any]:
    """Every page of a list from the REST API, one JSON value per line."""
    query = ["-X", "GET", path, *params, "-F", "per_page=100"]
    out = gh(["api", "--paginate", *query, "--jq", fields])
    return [json.loads(line) for line in out.splitlines() if line.strip()]


def each(read: Callable[[Any], Any], items: Iterable[Any]) -> list[Any]:
    """One read per item, a few at a time. The first read that fails fails the whole part."""
    with concurrent.futures.ThreadPoolExecutor(max_workers=GH_WORKERS) as pool:
        return list(pool.map(read, items))


def git(root: Path, *args: str) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(  # noqa: S603
            ["git", "-C", str(root), *args],  # noqa: S607
            capture_output=True,
            text=True,
            timeout=GIT_TIMEOUT,
        )
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError(f"git did not answer in {GIT_TIMEOUT} s: git {args[0]}") from exc


def first_line(text: str, otherwise: str) -> str:
    return (text.strip().splitlines() or [otherwise])[0]


def read_or_say(part: Callable[[], dict[str, Any]]) -> dict[str, Any]:
    """A part that cannot be read says why. It is never reported as zero."""
    try:
        return part()
    except (RuntimeError, OSError, ValueError, KeyError, TypeError) as exc:
        return {"unread": first_line(str(exc), type(exc).__name__)}


def parse_time(value: str) -> dt.datetime:
    return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))


def median(values: list[float], digits: int = 1) -> float | None:
    return round(statistics.median(values), digits) if values else None
