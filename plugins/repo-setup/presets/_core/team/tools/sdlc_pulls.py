"""How a merged pull request spent its time, for tools/sdlc_metrics.py. Standard library only.

Read from GitHub and git only: the timeline of the pull request (ready for review), the checks
that the rules of the default branch require, the check runs of its last head, its commits, and
the workflow runs of the window. Files of the feature loop are not read: its own gate marks are
its own to measure.
"""

from __future__ import annotations

import datetime as dt
import functools
from typing import Any

from sdlc_gh import each, gh_rows, median, parse_time

COMMIT_FIELDS = ".[] | {sha, parents: [.parents[].sha], date: .commit.committer.date}"
READY_FIELDS = (
    '.[] | select(.event == "ready_for_review" or .event == "convert_to_draft")'
    " | {event, created_at}"
)
# An object, never a bare string: gh --jq prints a string without its quotes.
REQUIRED_FIELDS = (
    '.[] | select(.type == "required_status_checks") | .parameters.required_status_checks[]'
    " | {context}"
)
CHECK_FIELDS = ".check_runs[] | {name, conclusion, completed_at}"


@functools.cache
def pr_commits(repo: str, number: int) -> tuple[dict[str, Any], ...]:
    """The commits GitHub lists for a pull request: at most 250, so a longer one loses some."""
    return tuple(gh_rows(f"repos/{repo}/pulls/{number}/commits", COMMIT_FIELDS))


def merges_of_default_in(commits: tuple[dict[str, Any], ...]) -> list[dict[str, Any]]:
    """The commits that merge a commit the pull request does not own: the default branch."""
    own = {c["sha"] for c in commits}
    return [c for c in commits if len(c["parents"]) == 2 and not set(c["parents"]) <= own]


def required_checks(repo: str, branch: str) -> list[str]:
    rows = gh_rows(f"repos/{repo}/rules/branches/{branch}", REQUIRED_FIELDS)
    names = sorted({row["context"] for row in rows})
    if not names:
        raise RuntimeError(f"the rules of {branch} require no check, so no time to green")
    return names


def last_ready(pull: dict[str, Any], events: list[dict[str, Any]]) -> dt.datetime:
    """The last time it was marked ready for review; opened ready when it never was a draft."""
    ready = [parse_time(e["created_at"]) for e in events if e.get("event") == "ready_for_review"]
    return max(ready, default=parse_time(pull["createdAt"]))


def green_at(runs: list[dict[str, Any]], required: list[str], merged: dt.datetime) -> Any:
    """When the last required check turned green on the last head, before the merge. None: never."""
    times = []
    for name in required:
        green = [
            parse_time(r["completed_at"])
            for r in runs
            if r.get("name") == name and r.get("conclusion") == "success" and r.get("completed_at")
        ]
        before = [at for at in green if at <= merged]
        if not before:
            return None
        times.append(max(before))
    return max(times)


def hours(values: list[float]) -> dict[str, Any]:
    return {
        "n": len(values),
        "median_h": median(values, 2),
        "max_h": round(max(values), 2) if values else None,
    }


def counts(values: list[int]) -> dict[str, Any]:
    return {
        "n": len(values),
        "total": sum(values),
        "median": median([float(v) for v in values]),
        "max": max(values) if values else None,
    }


def pushes_after(
    pull: dict[str, Any], runs: list[dict[str, Any]], ready: dt.datetime, merged: dt.datetime
) -> int:
    """The new heads CI ran on for this branch between ready and merged: one per push."""
    return len(
        {
            r["head_sha"]
            for r in runs
            if str(r.get("event", "")).startswith("pull_request")
            and r.get("head_branch") == pull.get("headRefName")
            and r.get("created_at")
            and ready <= parse_time(r["created_at"]) <= merged
        }
    )


def pull_times(
    repo: str,
    merged: list[dict[str, Any]],
    default_branch: str,
    runs: list[dict[str, Any]] | str,
    start: dt.datetime,
) -> dict[str, Any]:
    """Opened → ready → last required check green → merged, and what came after ready.

    `runs` is the list of workflow runs of the window, or the reason it could not be read. A pull
    request last ready before the window started has runs outside it: its pushes are not counted.
    """
    required = required_checks(repo, default_branch)
    pulls = [p for p in merged if p.get("mergedAt")]
    timelines = each(
        lambda p: gh_rows(f"repos/{repo}/issues/{p['number']}/timeline", READY_FIELDS), pulls
    )
    check_path = "repos/{}/commits/{}/check-runs"
    checks = each(
        lambda p: gh_rows(
            check_path.format(repo, p["headRefOid"]), CHECK_FIELDS, "-f", "filter=all"
        ),
        pulls,
    )
    commits = each(lambda p: pr_commits(repo, p["number"]), pulls)
    to_ready, to_green, to_merged, merges, pushes = [], [], [], [], []
    no_green = before_window = 0
    for pull, events, of_head, of_pull in zip(pulls, timelines, checks, commits, strict=True):
        opened, done = parse_time(pull["createdAt"]), parse_time(pull["mergedAt"])
        ready = last_ready(pull, events)
        to_ready.append((ready - opened).total_seconds() / 3600)
        green = green_at(of_head, required, done)
        if green is None:
            no_green += 1
        else:
            to_green.append(max((green - ready).total_seconds(), 0) / 3600)
            to_merged.append((done - max(green, ready)).total_seconds() / 3600)
        merges.append(
            sum(
                1
                for c in merges_of_default_in(of_pull)
                if c.get("date") and ready <= parse_time(c["date"]) <= done
            )
        )
        if ready < start:
            before_window += 1
        elif not isinstance(runs, str):
            pushes.append(pushes_after(pull, runs, ready, done))
    return {
        "pull_requests": len(pulls),
        "required_checks": required,
        "to_ready": hours(to_ready),
        "to_green": hours(to_green),
        "to_merged": hours(to_merged),
        "no_green_head": no_green,
        "pushes_after_ready": {"unread": runs} if isinstance(runs, str) else counts(pushes),
        "ready_before_window": before_window,
        "merges_after_ready": counts(merges),
    }
