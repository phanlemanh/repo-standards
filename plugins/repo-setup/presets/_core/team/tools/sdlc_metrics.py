#!/usr/bin/env python3
"""Delivery metrics for an AI-native SDLC, from GitHub (via gh). Standard library only.

  python3 tools/sdlc_metrics.py --days 7            # print a Markdown report
  python3 tools/sdlc_metrics.py --days 7 --write    # wiki/metrics/<year>-W<week>.md + index link

Reports DORA-style delivery numbers (deployments, lead time, change failure signals) and
agent numbers (share of agent PRs, acceptance rate, changes requested, tier mix). Use them to
decide when to widen or narrow agent autonomy in governance/autonomy.yaml.

It also reports whether parallel work queues: how often merging the default branch into a pull
request branch conflicts and in which files (each such merge is replayed with git, in a full
clone), CI machine minutes per merged pull request, jobs that fail on a head where `gate` had
passed, and red runs on the default branch. A part that cannot be read says so: it is never
reported as zero.
"""

from __future__ import annotations

import argparse
import collections
import concurrent.futures
import datetime as dt
import json
import os
import statistics
import subprocess
import sys
import time
from collections.abc import Callable
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))
from repo_ontology import find_repo_root

try:  # an older repository may not have the tool: its index is then kept by hand
    import ledgers
except ImportError:
    ledgers = None

DEFAULT_AGENTS = "claude[bot] dependabot[bot]"
# The job that says a pull request may merge (.github/workflows/pr-pipeline.yml).
GATE_JOB = "gate"
RED = {"failure", "timed_out", "startup_failure"}
TOP_FILES = 8
PR_LIMIT = 300
GH_TIMEOUT = 120
GH_TRIES = 3
GH_PAUSE = 2
GH_WORKERS = 8
GIT_TIMEOUT = 300
COMMIT_FIELDS = ".[] | {sha, parents: [.parents[].sha]}"
RUN_FIELDS = (
    ".total_count as $total | .workflow_runs[]"
    " | {total: $total, id, name, event, head_branch, head_sha, conclusion}"
)
JOB_FIELDS = ".jobs[] | {name, conclusion, started_at, completed_at}"


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


def gh_rows(path: str, fields: str, *params: str) -> list[dict[str, Any]]:
    """Every page of a list from the REST API, one JSON object per line."""
    query = ["-X", "GET", path, *params, "-F", "per_page=100"]
    out = gh(["api", "--paginate", *query, "--jq", fields])
    return [json.loads(line) for line in out.splitlines() if line.strip()]


def each(read: Callable[[Any], list[dict[str, Any]]], items: list[Any]) -> list[Any]:
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


def capped(lists: dict[str, list[Any]], limit: int = PR_LIMIT) -> list[str]:
    """The lists that stop at the limit of the query: the page then covers part of the window."""
    return sorted(name for name, rows in lists.items() if len(rows) >= limit)


def merges_of_default(repo: str, pulls: list[int]) -> list[tuple[str, str]]:
    """The two parents of each merge of the default branch into a pull request branch.

    Such a merge is a commit of the pull request with two parents, one of which the pull request
    does not own. GitHub lists at most 250 commits of a pull request: a longer one loses merges.
    """
    listed = each(lambda n: gh_rows(f"repos/{repo}/pulls/{n}/commits", COMMIT_FIELDS), pulls)
    merges: list[tuple[str, str]] = []
    for commits in listed:
        own = {c["sha"] for c in commits}
        merges += [
            (c["parents"][0], c["parents"][1])
            for c in commits
            if len(c["parents"]) == 2 and not set(c["parents"]) <= own
        ]
    return merges


def has_commit(root: Path, sha: str) -> bool:
    return git(root, "cat-file", "-e", sha + "^{commit}").returncode == 0


def replay(root: Path, ours: str, theirs: str) -> list[str] | None:
    """The files in conflict when the two commits are merged again. None: the merge is clean."""
    if not (has_commit(root, ours) and has_commit(root, theirs)):
        raise RuntimeError("the commits are not in this clone")
    proc = git(
        root, "merge-tree", "--write-tree", "--name-only", "--no-messages", "-z", ours, theirs
    )
    if proc.returncode == 0:
        return None
    if proc.returncode == 1:
        return [name for name in proc.stdout.split("\0")[1:] if name]
    raise RuntimeError("git merge-tree (needs git 2.38): " + first_line(proc.stderr, "failed"))


def back_merges(repo: str, pulls: list[int], root: Path) -> dict[str, Any]:
    """Replay each merge of the default branch into a pull request branch: does it conflict, where.

    The replay uses the merge rules of this checkout (.gitattributes), so it answers "would these
    merges conflict under the rules of today".
    """
    shallow = git(root, "rev-parse", "--is-shallow-repository")
    if shallow.returncode != 0:
        raise RuntimeError("git did not answer here: " + first_line(shallow.stderr, "no reason"))
    if shallow.stdout.strip() != "false":
        raise RuntimeError("shallow clone: merges cannot be replayed without the full history")
    merges = merges_of_default(repo, pulls)
    why: list[str] = []
    if not all(has_commit(root, sha) for pair in merges for sha in pair):
        # GitHub keeps the head of every pull request, also after its branch is deleted.
        fetched = git(root, "fetch", "--quiet", "origin", *[f"refs/pull/{n}/head" for n in pulls])
        if fetched.returncode != 0:
            why.append("git fetch: " + first_line(fetched.stderr, "failed"))
    files: collections.Counter[str] = collections.Counter()
    replayed = conflicting = 0
    for ours, theirs in merges:
        try:
            conflict = replay(root, ours, theirs)
        except RuntimeError as exc:
            why.append(str(exc))
            continue
        replayed += 1
        conflicting += conflict is not None
        files.update(conflict or [])
    if merges and not replayed:
        raise RuntimeError(f"none of {len(merges)} merges could be replayed: {why[0]}")
    return {
        "pull_requests": len(pulls),
        "found": len(merges),
        "replayed": replayed,
        "conflicting": conflicting,
        "not_replayed": len(merges) - replayed,
        "not_replayed_because": why[0] if len(merges) > replayed else "",
        "files": dict(sorted(files.items(), key=lambda item: (-item[1], item[0]))),
    }


def job_minutes(job: dict[str, Any]) -> float:
    if not (job.get("started_at") and job.get("completed_at")):
        return 0.0
    seconds = (parse_time(job["completed_at"]) - parse_time(job["started_at"])).total_seconds()
    return max(seconds, 0.0) / 60


def is_gate(job: dict[str, Any]) -> bool:
    name = str(job.get("name", ""))
    return name == GATE_JOB or name.endswith(f"/ {GATE_JOB}")


def is_late_red(jobs: list[dict[str, Any]]) -> bool | None:
    """Did a job end red after the gate job that passed had started? None: gate never passed.

    The jobs are those of one head, every attempt of every run: a run made green by running it
    again still counts.
    """
    passed = [
        parse_time(j["started_at"])
        for j in jobs
        if is_gate(j) and j.get("conclusion") == "success" and j.get("started_at")
    ]
    if not passed:
        return None
    ended_red = [
        parse_time(j["completed_at"])
        for j in jobs
        if j.get("conclusion") in RED and not is_gate(j) and j.get("completed_at")
    ]
    return any(at > min(passed) for at in ended_red)


def default_branch_red(
    runs: list[dict[str, Any]], jobs: list[list[dict[str, Any]]], default_branch: str
) -> dict[str, list[int]]:
    """Per workflow: [red runs, finished runs] among the pushes to the default branch.

    A run is red when it ended red or when any attempt of it had a red job.
    """
    counts: dict[str, list[int]] = {}
    for run, of_run in zip(runs, jobs, strict=True):
        if run.get("event") != "push" or run.get("head_branch") != default_branch:
            continue
        red = run.get("conclusion") in RED or any(j.get("conclusion") in RED for j in of_run)
        if red or run.get("conclusion") == "success":
            name = str(run.get("name") or "unnamed")
            reds, total = counts.get(name, [0, 0])
            counts[name] = [reds + red, total + 1]
    return dict(sorted(counts.items()))


def runs_since(repo: str, since: str) -> list[dict[str, Any]]:
    """The workflow runs created since that day, asked for one day at a time.

    GitHub returns at most 1,000 runs for a list filtered by date. A day with more is not read.
    """
    day, today = dt.date.fromisoformat(since), dt.datetime.now(dt.UTC).date()
    runs: dict[int, dict[str, Any]] = {}
    while day <= today:
        listed = gh_rows(f"repos/{repo}/actions/runs", RUN_FIELDS, "-f", f"created={day}")
        total = max((int(run["total"]) for run in listed), default=0)
        if len(listed) < total:
            raise RuntimeError(f"GitHub lists {len(listed)} of {total} workflow runs of {day}")
        runs.update({run["id"]: run for run in listed})
        day += dt.timedelta(days=1)
    return list(runs.values())


def ci_flow(repo: str, since: str, default_branch: str, merged: int) -> dict[str, Any]:
    """Machine minutes, late red and red on the default branch, from the workflow runs."""
    runs = runs_since(repo, since)
    jobs_of = f"repos/{repo}/actions/runs/{{}}/jobs"
    jobs = each(
        lambda run: gh_rows(jobs_of.format(run["id"]), JOB_FIELDS, "-f", "filter=all"), runs
    )
    by_head: dict[str, list[dict[str, Any]]] = {}
    for run, of_run in zip(runs, jobs, strict=True):
        if str(run.get("event", "")).startswith("pull_request"):
            by_head.setdefault(run["head_sha"], []).extend(of_run)
    late = [verdict for verdict in map(is_late_red, by_head.values()) if verdict is not None]
    minutes = sum(job_minutes(job) for of_run in jobs for job in of_run)
    return {
        "runs": len(runs),
        "machine_minutes": round(minutes, 1),
        "machine_minutes_per_merged_pr": round(minutes / merged, 1) if merged else None,
        "late_red": [sum(late), len(late)],
        "default_branch": default_branch_red(runs, jobs, default_branch),
    }


def parse_time(value: str) -> dt.datetime:
    return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))


def collect(days: int, agents: set[str]) -> dict[str, Any]:
    since = (dt.datetime.now(dt.UTC) - dt.timedelta(days=days)).date().isoformat()
    fields = "number,title,author,createdAt,mergedAt,closedAt,labels,reviews,baseRefName"
    merged = gh_json(
        [
            "pr",
            "list",
            "--state",
            "merged",
            "--search",
            f"merged:>={since}",
            "--limit",
            str(PR_LIMIT),
            "--json",
            fields,
        ]
    )
    closed = gh_json(
        [
            "pr",
            "list",
            "--state",
            "closed",
            "--search",
            f"closed:>={since} is:unmerged",
            "--limit",
            str(PR_LIMIT),
            "--json",
            fields,
        ]
    )
    opened = gh_json(
        ["pr", "list", "--state", "open", "--limit", str(PR_LIMIT), "--json", "number,baseRefName"]
    )
    about = gh_json(["repo", "view", "--json", "nameWithOwner,defaultBranchRef"])
    repo = about["nameWithOwner"]
    default_branch = (about.get("defaultBranchRef") or {}).get("name") or "main"
    # A pull request into another branch merges that branch, not the default one.
    pulls = sorted(
        {p["number"] for p in [*merged, *closed, *opened] if p.get("baseRefName") == default_branch}
    )
    try:
        deployments = gh_json(
            ["api", f"repos/{repo}/deployments?environment=production&per_page=100"]
        )
    except RuntimeError:
        deployments = []
    deploys = [d for d in deployments or [] if d.get("created_at", "") >= since]

    def is_agent(pr: dict[str, Any]) -> bool:
        author = pr.get("author") or {}
        login = str(author.get("login", ""))
        name = login.removeprefix("app/")
        return bool(author.get("is_bot")) or login in agents or f"{name}[bot]" in agents

    def tier(pr: dict[str, Any]) -> str:
        names = [lb["name"] for lb in pr.get("labels") or []]
        return next((n.split(":", 1)[1] for n in names if n.startswith("risk:")), "unknown")

    lead_hours = [
        (parse_time(p["mergedAt"]) - parse_time(p["createdAt"])).total_seconds() / 3600
        for p in merged
        if p.get("mergedAt")
    ]
    agent_merged = [p for p in merged if is_agent(p)]
    agent_closed = [p for p in closed if is_agent(p)]
    changes_requested = [
        p
        for p in agent_merged
        if any(r.get("state") == "CHANGES_REQUESTED" for r in p.get("reviews") or [])
        or any(lb["name"] == "agent-review:changes" for lb in p.get("labels") or [])
    ]
    reverts = [p for p in merged if p["title"].lower().startswith("revert")]
    tiers: dict[str, int] = {}
    for p in merged:
        tiers[tier(p)] = tiers.get(tier(p), 0) + 1
    return {
        "since": since,
        "days": days,
        "merged": len(merged),
        "capped": capped({"merged": merged, "closed without merge": closed, "open": opened}),
        "deployments": len(deploys),
        "lead_time_median_h": round(statistics.median(lead_hours), 1) if lead_hours else None,
        "lead_time_max_h": round(max(lead_hours), 1) if lead_hours else None,
        "back_merges": read_or_say(lambda: back_merges(repo, pulls, find_repo_root())),
        "ci": read_or_say(lambda: ci_flow(repo, since, default_branch, len(merged))),
        "reverts": len(reverts),
        "agent_merged": len(agent_merged),
        "agent_closed_unmerged": len(agent_closed),
        "agent_changes_requested": len(changes_requested),
        "tiers": tiers,
    }


def flow_rows(m: dict[str, Any]) -> str:
    """The rows that say whether parallel work queues."""

    def unread(part: dict[str, Any]) -> str:
        return f"not read: {part['unread']}"

    merges, ci = m["back_merges"], m["ci"]
    rows: list[tuple[str, str]] = []
    if "unread" in merges:
        rows.append(("Merges of the default branch into a pull request branch", unread(merges)))
    else:
        top = list(merges["files"].items())[:TOP_FILES]
        why = f" ({merges['not_replayed_because']})" if merges["not_replayed"] else ""
        rows += [
            (
                "Merges of the default branch into a pull request branch",
                f"{merges['found']} on {merges['pull_requests']} pull requests",
            ),
            ("… that conflict when replayed", f"{merges['conflicting']} of {merges['replayed']}"),
            ("… that could not be replayed", f"{merges['not_replayed']}{why}"),
            ("Files in conflict most often", ", ".join(f"`{f}` {n}" for f, n in top) or "none"),
        ]
    if "unread" in ci:
        rows.append(("CI machine minutes", unread(ci)))
    else:
        per_merged = ci["machine_minutes_per_merged_pr"]
        red, passed = ci["late_red"]
        default = ", ".join(f"{name} {r} of {n}" for name, (r, n) in ci["default_branch"].items())
        rows += [
            ("CI machine minutes", f"{ci['machine_minutes']} in {ci['runs']} runs"),
            (
                "CI machine minutes per merged pull request (every run in the window)",
                "n/a" if per_merged is None else str(per_merged),
            ),
            (
                f"Late red (a job ended red on a head after `{GATE_JOB}` passed)",
                f"{red} of {passed}" if passed else f"n/a (no `{GATE_JOB}` job passed)",
            ),
            ("Red on the default branch, per workflow", default or "no finished run"),
        ]
    return "\n".join(f"| {name} | {value.replace('|', '/')} |" for name, value in rows)


def render(m: dict[str, Any], week: str) -> str:
    partial = ""
    if m["capped"]:
        partial = (
            f"\n\nThe list of {', '.join(m['capped'])} pull requests stops at {PR_LIMIT}:"
            " the numbers on this page cover part of the window. Use fewer `--days`."
        )
    total = m["merged"] or 1
    attempts = m["agent_merged"] + m["agent_closed_unmerged"]
    acceptance = f"{round(100 * m['agent_merged'] / attempts)}%" if attempts else "n/a"
    failure = f"{round(100 * m['reverts'] / m['deployments'])}%" if m["deployments"] else "n/a"
    tiers = ", ".join(f"{k}: {v}" for k, v in sorted(m["tiers"].items())) or "none"
    lead = "n/a"
    if m["lead_time_median_h"] is not None:
        lead = f"{m['lead_time_median_h']} h, longest {m['lead_time_max_h']} h"
    return f"""---
type: metrics
title: Delivery metrics {week}
links: []
sources: [tools/sdlc_metrics.py, GitHub API since {m["since"]}]
---

# Delivery metrics {week}

## Summary

{m["merged"]} pull requests merged in the last {m["days"]} days, {m["agent_merged"]} by agents
({round(100 * m["agent_merged"] / total)}%). Agent acceptance rate {acceptance}.{partial}

## Delivery

| Metric | Value |
| --- | --- |
| Production deployments | {m["deployments"]} |
| Median PR lead time (open → merge) | {lead} |
| Reverts | {m["reverts"]} |
| Change failure signal (reverts / deployments) | {failure} |

## Flow

| Metric | Value |
| --- | --- |
{flow_rows(m)}

## Agents

| Metric | Value |
| --- | --- |
| Agent PRs merged | {m["agent_merged"]} |
| Agent PRs closed without merge | {m["agent_closed_unmerged"]} |
| Merged agent PRs that needed changes | {m["agent_changes_requested"]} |
| Autonomy tier mix (merged) | {tiers} |

## Notes

Widen autonomy (more paths in `low`) only when acceptance stays high and failures stay at
zero for several weeks; narrow it after an incident caused by an agent change.

Flow says whether parallel work queues. A file that leads "Files in conflict most often" is
written by many pull requests at once: give it one writer, or generate it instead of committing
it. The replay uses the merge rules of the checkout it ran in. Late red and red on the default
branch count every attempt of a run: a run made green by running it again still counts.
"""


def link_in_index(root: Path, week: str) -> None:
    """Add the week to a hand-kept wiki/index.md. A drawn index lists the page by itself."""
    if ledgers is not None and ledgers.shape_of(root, "index") == ledgers.FRAGMENTS:
        return
    index = root / "wiki" / "index.md"
    if not index.exists():
        return
    text = index.read_text(encoding="utf-8")
    entry = f"- [{week}](metrics/{week}.md)"
    if entry in text:
        return
    if "## Metrics" not in text:
        text = text.rstrip("\n") + "\n\n## Metrics\n"
    head, _, rest = text.partition("## Metrics\n")
    text = head + "## Metrics\n\n" + entry + "\n" + rest.lstrip("\n")
    index.write_text(text, encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("--days", type=int, default=7)
    ap.add_argument("--write", action="store_true", help="write the wiki page and index link")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)
    agents = set((os.environ.get("AGENT_AUTHORS") or DEFAULT_AGENTS).split())
    try:
        metrics = collect(args.days, agents)
    except (RuntimeError, OSError, json.JSONDecodeError) as exc:
        print(f"Cannot read GitHub data (is gh installed and logged in?): {exc}", file=sys.stderr)
        return 1
    year, weeknum, _ = dt.date.today().isocalendar()
    week = f"{year}-W{weeknum:02d}"
    if args.json:
        print(json.dumps(metrics, indent=2))
        return 0
    page = render(metrics, week)
    if args.write:
        root = find_repo_root()
        out = root / "wiki" / "metrics" / f"{week}.md"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(page, encoding="utf-8")
        link_in_index(root, week)
        print(f"wrote wiki/metrics/{week}.md")
    else:
        print(page)
    return 0


if __name__ == "__main__":
    sys.exit(main())
