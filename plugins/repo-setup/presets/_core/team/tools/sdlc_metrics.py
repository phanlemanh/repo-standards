#!/usr/bin/env python3
"""Delivery metrics for an AI-native SDLC, from GitHub (via gh). Standard library only.

  python3 tools/sdlc_metrics.py --days 7            # print a Markdown report
  python3 tools/sdlc_metrics.py --days 7 --write    # wiki/metrics/<year>-W<week>.md + index link

Reports DORA-style delivery numbers (deployments, lead time, change failure signals) and
agent numbers (share of agent PRs, acceptance rate, changes requested, tier mix). Use them to
decide when to widen or narrow agent autonomy in governance/autonomy.yaml.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import statistics
import subprocess
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))
from repo_ontology import find_repo_root

DEFAULT_AGENTS = "claude[bot] dependabot[bot]"


def gh_json(args: list[str]) -> Any:
    proc = subprocess.run(  # noqa: S603
        ["gh", *args],  # noqa: S607
        capture_output=True,
        text=True,
        timeout=60,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or "gh failed")
    return json.loads(proc.stdout or "null")


def parse_time(value: str) -> dt.datetime:
    return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))


def collect(days: int, agents: set[str]) -> dict[str, Any]:
    since = (dt.datetime.now(dt.UTC) - dt.timedelta(days=days)).date().isoformat()
    fields = "number,title,author,createdAt,mergedAt,closedAt,labels,reviews"
    merged = gh_json(
        [
            "pr",
            "list",
            "--state",
            "merged",
            "--search",
            f"merged:>={since}",
            "--limit",
            "300",
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
            "300",
            "--json",
            fields,
        ]
    )
    repo = gh_json(["repo", "view", "--json", "nameWithOwner"])["nameWithOwner"]
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
        "deployments": len(deploys),
        "lead_time_median_h": round(statistics.median(lead_hours), 1) if lead_hours else None,
        "reverts": len(reverts),
        "agent_merged": len(agent_merged),
        "agent_closed_unmerged": len(agent_closed),
        "agent_changes_requested": len(changes_requested),
        "tiers": tiers,
    }


def render(m: dict[str, Any], week: str) -> str:
    total = m["merged"] or 1
    attempts = m["agent_merged"] + m["agent_closed_unmerged"]
    acceptance = f"{round(100 * m['agent_merged'] / attempts)}%" if attempts else "n/a"
    failure = f"{round(100 * m['reverts'] / m['deployments'])}%" if m["deployments"] else "n/a"
    tiers = ", ".join(f"{k}: {v}" for k, v in sorted(m["tiers"].items())) or "none"
    lead = f"{m['lead_time_median_h']} h" if m["lead_time_median_h"] is not None else "n/a"
    return f"""---
type: metrics
title: Delivery metrics {week}
links: []
sources: [tools/sdlc_metrics.py, GitHub API since {m["since"]}]
---

# Delivery metrics {week}

## Summary

{m["merged"]} pull requests merged in the last {m["days"]} days, {m["agent_merged"]} by agents
({round(100 * m["agent_merged"] / total)}%). Agent acceptance rate {acceptance}.

## Delivery

| Metric | Value |
| --- | --- |
| Production deployments | {m["deployments"]} |
| Median PR lead time (open → merge) | {lead} |
| Reverts | {m["reverts"]} |
| Change failure signal (reverts / deployments) | {failure} |

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
"""


def link_in_index(root: Path, week: str) -> None:
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
