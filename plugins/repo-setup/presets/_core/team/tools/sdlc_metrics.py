#!/usr/bin/env python3
"""Delivery metrics for an AI-native SDLC, from GitHub (via gh). Standard library only.

  python3 tools/sdlc_metrics.py --days 7                      # print a Markdown report
  python3 tools/sdlc_metrics.py --days 7 --write              # wiki/metrics/<year>-W<week>.md
  python3 tools/sdlc_metrics.py --days 14 --split 2026-11-18  # before and from a date or a tag

Reports DORA-style delivery numbers (deployments, lead time, change failure signals) and
agent numbers (share of agent PRs, acceptance rate, changes requested, tier mix). Use them to
decide when to widen or narrow agent autonomy in governance/autonomy.yaml.

It also reports whether parallel work queues: how often merging the default branch into a pull
request branch conflicts and in which files (each such merge is replayed with git, in a full
clone), CI machine minutes per merged pull request, jobs that fail on a head where `gate` had
passed, red runs on the default branch, one row per CI job, the steps that were red on two or
more branches, and how a merged pull request spent its time (opened, ready for review, last
required check green, merged). A part that cannot be read says so: it is never reported as zero.

--split cuts the window at a moment: a pull request goes to the side of its merge (or close), an
open one to the later side, a workflow run to the side it was created on.
"""

from __future__ import annotations

import argparse
import collections
import datetime as dt
import json
import os
import statistics
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))
from repo_ontology import find_repo_root
from sdlc_gh import PR_LIMIT, each, first_line, gh_json, gh_rows, git, parse_time, read_or_say
from sdlc_jobs import ci_numbers, mark_waiting
from sdlc_limits import thresholds
from sdlc_pulls import merges_of_default_in, pr_commits, pull_times
from sdlc_report import render, render_split

try:  # an older repository may not have the tool: its index is then kept by hand
    import ledgers
except ImportError:
    ledgers = None

DEFAULT_AGENTS = "claude[bot] dependabot[bot]"
RUN_FIELDS = (
    ".total_count as $total | .workflow_runs[]"
    " | {total: $total, id, name, event, head_branch, head_sha, conclusion, created_at}"
)
JOB_FIELDS = (
    ".jobs[] | {name, conclusion, started_at, completed_at, run_attempt,"
    " steps: [.steps[]? | {name, conclusion}]}"
)
PR_FIELDS = (
    "number,title,author,createdAt,mergedAt,closedAt,labels,reviews,baseRefName,"
    "headRefName,headRefOid"
)
# A part of the window: [from, to). None is open on that side.
Part = tuple[dt.datetime | None, dt.datetime | None]
WHOLE: Part = (None, None)


def capped(lists: dict[str, list[Any]], limit: int = PR_LIMIT) -> list[str]:
    """The lists that stop at the limit of the query: the page then covers part of the window."""
    return sorted(name for name, rows in lists.items() if len(rows) >= limit)


def in_part(moment: str | None, part: Part) -> bool:
    """Is the moment in the part? No moment (still open) belongs to the part that runs to now."""
    lo, hi = part
    if not moment:
        return hi is None
    at = parse_time(moment)
    return (lo is None or at >= lo) and (hi is None or at < hi)


def merges_of_default(repo: str, pulls: list[int]) -> list[tuple[str, str]]:
    """The two parents of each merge of the default branch into a pull request branch.

    Such a merge is a commit of the pull request with two parents, one of which the pull request
    does not own. GitHub lists at most 250 commits of a pull request: a longer one loses merges.
    """
    listed = each(lambda n: pr_commits(repo, n), pulls)
    return [
        (c["parents"][0], c["parents"][1]) for of_pr in listed for c in merges_of_default_in(of_pr)
    ]


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


def runs_with_jobs(
    repo: str, since: str
) -> tuple[list[dict[str, Any]], list[list[dict[str, Any]]]]:
    """The runs of the window and the jobs of each, every attempt, marked by `mark_waiting`."""
    runs = runs_since(repo, since)
    jobs_of = f"repos/{repo}/actions/runs/{{}}/jobs"
    jobs = each(
        lambda run: mark_waiting(
            run["id"], gh_rows(jobs_of.format(run["id"]), JOB_FIELDS, "-f", "filter=all")
        ),
        runs,
    )
    return runs, jobs


def pr_list(state: str, search: str | None, fields: str) -> list[dict[str, Any]]:
    query = ["pr", "list", "--state", state]
    if search:
        query += ["--search", search]
    return gh_json([*query, "--limit", str(PR_LIMIT), "--json", fields])


def fetch(days: int) -> dict[str, Any]:
    """Everything the report reads from GitHub, once. The parts are computed from it."""
    since = (dt.datetime.now(dt.UTC) - dt.timedelta(days=days)).date().isoformat()
    about = gh_json(["repo", "view", "--json", "nameWithOwner,defaultBranchRef"])
    repo = about["nameWithOwner"]
    try:
        deployments = gh_json(
            ["api", f"repos/{repo}/deployments?environment=production&per_page=100"]
        )
    except RuntimeError:
        deployments = []
    try:
        runs: Any = runs_with_jobs(repo, since)
    except (RuntimeError, OSError, ValueError, KeyError, TypeError) as exc:
        runs = first_line(str(exc), type(exc).__name__)
    return {
        "since": since,
        "days": days,
        "repo": repo,
        "default_branch": (about.get("defaultBranchRef") or {}).get("name") or "main",
        "merged": pr_list("merged", f"merged:>={since}", PR_FIELDS),
        "closed": pr_list("closed", f"closed:>={since} is:unmerged", PR_FIELDS),
        "opened": pr_list("open", None, "number,baseRefName"),
        "deployments": [d for d in deployments or [] if d.get("created_at", "") >= since],
        "runs": runs,
    }


def is_agent(pr: dict[str, Any], agents: set[str]) -> bool:
    author = pr.get("author") or {}
    login = str(author.get("login", ""))
    name = login.removeprefix("app/")
    return bool(author.get("is_bot")) or login in agents or f"{name}[bot]" in agents


def tier(pr: dict[str, Any]) -> str:
    names = [lb["name"] for lb in pr.get("labels") or []]
    return next((n.split(":", 1)[1] for n in names if n.startswith("risk:")), "unknown")


def ci_part(raw: dict[str, Any], part: Part, merged: int) -> dict[str, Any]:
    if isinstance(raw["runs"], str):
        raise RuntimeError(raw["runs"])
    pairs = [
        (r, j) for r, j in zip(*raw["runs"], strict=True) if in_part(r.get("created_at"), part)
    ]
    runs, jobs = [r for r, _ in pairs], [j for _, j in pairs]
    return ci_numbers(runs, jobs, raw["default_branch"], merged)


def metrics(raw: dict[str, Any], part: Part, agents: set[str]) -> dict[str, Any]:
    """The numbers of one part of the window."""
    merged = [p for p in raw["merged"] if in_part(p.get("mergedAt"), part)]
    closed = [p for p in raw["closed"] if in_part(p.get("closedAt"), part)]
    opened = [p for p in raw["opened"] if in_part(None, part)]
    default_branch, repo = raw["default_branch"], raw["repo"]
    # A pull request into another branch merges that branch, not the default one.
    pulls = sorted(
        {p["number"] for p in [*merged, *closed, *opened] if p.get("baseRefName") == default_branch}
    )
    lead_hours = [
        (parse_time(p["mergedAt"]) - parse_time(p["createdAt"])).total_seconds() / 3600
        for p in merged
        if p.get("mergedAt")
    ]
    agent_merged = [p for p in merged if is_agent(p, agents)]
    changes_requested = [
        p
        for p in agent_merged
        if any(r.get("state") == "CHANGES_REQUESTED" for r in p.get("reviews") or [])
        or any(lb["name"] == "agent-review:changes" for lb in p.get("labels") or [])
    ]
    runs = raw["runs"] if isinstance(raw["runs"], str) else raw["runs"][0]
    start = parse_time(raw["since"] + "T00:00:00Z")
    part_metrics = {
        "since": raw["since"],
        "days": raw["days"],
        "merged": len(merged),
        "capped": capped(
            {"merged": raw["merged"], "closed without merge": raw["closed"], "open": raw["opened"]}
        ),
        "deployments": sum(in_part(d.get("created_at"), part) for d in raw["deployments"]),
        "lead_time_median_h": round(statistics.median(lead_hours), 1) if lead_hours else None,
        "lead_time_max_h": round(max(lead_hours), 1) if lead_hours else None,
        "back_merges": read_or_say(lambda: back_merges(repo, pulls, find_repo_root())),
        "ci": read_or_say(lambda: ci_part(raw, part, len(merged))),
        "pulls": read_or_say(lambda: pull_times(repo, merged, default_branch, runs, start)),
        "reverts": sum(p["title"].lower().startswith("revert") for p in merged),
        "agent_merged": len(agent_merged),
        "agent_closed_unmerged": sum(is_agent(p, agents) for p in closed),
        "agent_changes_requested": len(changes_requested),
        "tiers": dict(collections.Counter(tier(p) for p in merged)),
    }
    return {**part_metrics, "thresholds": thresholds(part_metrics)}


def split_moment(value: str, root: Path) -> dt.datetime:
    """A date (midnight UTC), an ISO time, or a tag or commit of this clone (its commit time)."""
    try:
        at = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        proc = git(root, "log", "-1", "--format=%cI", value + "^{commit}", "--")
        if proc.returncode != 0 or not proc.stdout.strip():
            raise ValueError(
                f"--split {value}: neither a date (YYYY-MM-DD, or an ISO time) nor a tag or"
                " commit of this clone"
            ) from None
        at = dt.datetime.fromisoformat(proc.stdout.strip())
    return at if at.tzinfo else at.replace(tzinfo=dt.UTC)


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
    ap.add_argument("--split", metavar="DATE|TAG", help="report before and from this moment")
    args = ap.parse_args(argv)
    agents = set((os.environ.get("AGENT_AUTHORS") or DEFAULT_AGENTS).split())
    try:
        at = split_moment(args.split, find_repo_root()) if args.split else None
    except ValueError as exc:
        print(exc, file=sys.stderr)
        return 2
    try:
        raw = fetch(args.days)
    except (RuntimeError, OSError, json.JSONDecodeError) as exc:
        print(f"Cannot read GitHub data (is gh installed and logged in?): {exc}", file=sys.stderr)
        return 1
    year, weeknum, _ = dt.date.today().isocalendar()
    week = f"{year}-W{weeknum:02d}"
    if at is None:
        whole = metrics(raw, WHOLE, agents)
        out: dict[str, Any] = whole
        page = render(whole, week)
    else:
        before, after = metrics(raw, (None, at), agents), metrics(raw, (at, None), agents)
        out = {"split": {"by": args.split, "at": at.isoformat()}, "before": before, "after": after}
        page = render_split(before, after, at.isoformat(), week)
    if args.json:
        print(json.dumps(out, indent=2))
        return 0
    if args.write:
        root = find_repo_root()
        path = root / "wiki" / "metrics" / f"{week}.md"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(page, encoding="utf-8")
        link_in_index(root, week)
        print(f"wrote wiki/metrics/{week}.md")
    else:
        print(page)
    return 0


if __name__ == "__main__":
    sys.exit(main())
