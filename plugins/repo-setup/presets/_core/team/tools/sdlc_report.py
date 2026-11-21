"""The Markdown page of tools/sdlc_metrics.py. Standard library only.

Every number comes from the metrics of one part of the window. A part that could not be read
prints `not read: <reason>`, never a zero.
"""

from __future__ import annotations

from typing import Any

import sdlc_limits as limits
from sdlc_gh import PR_LIMIT
from sdlc_jobs import GATE_JOB

TOP_FILES = 8
TOP_STEPS = 8
TOP_BRANCHES = 6
NOT_READ_TESTS = (
    "Test names are not read: telling which test failed needs the job log and the output format"
    " of a test runner. The step says which make target was red."
)


def unread(part: dict[str, Any]) -> str:
    return f"not read: {part['unread']}"


def table(rows: list[tuple[str, str]]) -> str:
    return "\n".join(f"| {name} | {value.replace('|', '/')} |" for name, value in rows)


def merge_rows(merges: dict[str, Any]) -> list[tuple[str, str]]:
    if "unread" in merges:
        return [("Merges of the default branch into a pull request branch", unread(merges))]
    top = list(merges["files"].items())[:TOP_FILES]
    why = f" ({merges['not_replayed_because']})" if merges["not_replayed"] else ""
    return [
        (
            "Merges of the default branch into a pull request branch",
            f"{merges['found']} on {merges['pull_requests']} pull requests",
        ),
        ("… that conflict when replayed", f"{merges['conflicting']} of {merges['replayed']}"),
        ("… that could not be replayed", f"{merges['not_replayed']}{why}"),
        ("Files in conflict most often", ", ".join(f"`{f}` {n}" for f, n in top) or "none"),
    ]


def ci_rows(ci: dict[str, Any]) -> list[tuple[str, str]]:
    if "unread" in ci:
        return [("CI machine minutes", unread(ci))]
    per_merged = ci["machine_minutes_per_merged_pr"]
    red, passed = ci["late_red"]
    default = ", ".join(f"{name} {r} of {n}" for name, (r, n) in ci["default_branch"].items())
    return [
        ("CI machine minutes", f"{ci['machine_minutes']} in {ci['runs']} runs"),
        (
            "CI machine minutes per merged pull request (every run in the window)",
            "n/a" if per_merged is None else str(per_merged),
        ),
        (
            f"Late red (a job ended red on a head after `{GATE_JOB}` passed)",
            f"{red} of {passed}" if passed else f"n/a (no `{GATE_JOB}` job passed)",
        ),
        (
            "Not late red: a draft's summary job, red as it only says"
            " the heavy tier has not run yet",
            str(ci["waiting_red"]),
        ),
        ("Red on the default branch, per workflow", default or "no finished run"),
    ]


def flow_rows(m: dict[str, Any]) -> str:
    """The rows that say whether parallel work queues."""
    return table(merge_rows(m["back_merges"]) + ci_rows(m["ci"]))


def jobs_section(ci: dict[str, Any], mark: str) -> str:
    if "unread" in ci:
        return f"{mark} Jobs\n\nJobs: {unread(ci)}\n"
    head = (
        "| Job | Runs | Green | Red | Cancelled | Median minutes | Machine hours"
        " | Red at a check step |\n| --- | --- | --- | --- | --- | --- | --- | --- |"
    )
    rows = [
        f"| `{name}` | {r['runs']} | {r['green']} | {r['red']} | {r['cancelled']} | "
        f"{'n/a' if r['median_minutes'] is None else r['median_minutes']} | "
        f"{r['machine_hours']} | {r['red_at_check_step']} |"
        for name, r in ci["jobs"].items()
    ]
    steps = ci["red_steps"]
    reds = sum(steps.values())
    where = (
        f"Red jobs: {reds}; at a step that runs checks (a `make` step) {steps['checks']}, at the"
        f" summary step {steps['summary']}, at another step {steps['other']}, step not read"
        f" {steps['not_read']}."
    )
    across = [
        f"| `{row['job']}` at `{row['step']}` | {len(row['branches'])} branches: "
        + ", ".join(row["branches"][:TOP_BRANCHES])
        + (", …" if len(row["branches"]) > TOP_BRANCHES else "")
        + " |"
        for row in ci["red_across_branches"][:TOP_STEPS]
    ] or ["| none | |"]
    return "\n".join(
        [
            f"{mark} Jobs",
            "",
            "Every attempt of every run in the window counts.",
            "",
            head,
            *rows,
            "",
            where,
            "",
            f"{mark}# Red at the same step on two or more branches",
            "",
            "A red that is not specific to one pull request. Gate jobs and the summary step are"
            " left out.",
            "",
            "| Job and step | Branches |",
            "| --- | --- |",
            *across,
            "",
            NOT_READ_TESTS,
            "",
        ]
    )


THRESHOLD_NAMES = {
    limits.LATE_RED: "Late red",
    limits.DEFAULT_RED: "Red on the default branch",
    limits.ONE_FILE: "One file in the conflicting merges",
}


def threshold_row(t: dict[str, Any]) -> str:
    name = THRESHOLD_NAMES[t["measure"]] + (f": `{t['subject']}`" if t.get("subject") else "")
    limit = limits.limit_text(t["measure"])
    if t["verdict"] == limits.NOT_READ:
        return f"| {name} | not read: {t['reason'].replace('|', '/')} | {limit} | not read |"
    share = f" ({round(100 * t['count'] / t['sample'])}%)" if t["sample"] else ""
    said = t["verdict"]
    if said == limits.TOO_FEW:
        said = f"{limits.TOO_FEW} (fewer than {limits.MIN_SAMPLE})"
    return f"| {name} | {t['count']} of {t['sample']}{share} | {limit} | {said} |"


def thresholds_section(rows: list[dict[str, Any]], mark: str) -> str:
    lines = [threshold_row(t) for t in rows] or ["| No conflicting merge, no finished run | | | |"]
    return "\n".join(
        [
            f"{mark} Thresholds",
            "",
            "| Measure | Value | Threshold | Verdict |",
            "| --- | --- | --- | --- |",
            *lines,
            "",
            "The thresholds are starting values: the machine suggested them on 2026-11-16, and"
            " nothing has derived them from data yet (`tools/sdlc_limits.py`). Below"
            f" {limits.MIN_SAMPLE} cases a share is too few to tell. A number over its threshold"
            " changes nothing else: the exit code stays 0, and no check goes red. Nothing runs this"
            " tool by itself: run it when you want the numbers, for example"
            " `python3 tools/sdlc_metrics.py --days 14 --write`, which writes"
            " `wiki/metrics/<year>-W<week>.md`.",
            "",
        ]
    )


def spread(part: dict[str, Any]) -> str:
    if part["n"] == 0:
        return "n/a (no pull request)"
    return f"median {part['median_h']} h, longest {part['max_h']} h ({part['n']} pull requests)"


def tally(part: dict[str, Any]) -> str:
    if "unread" in part:
        return unread(part)
    if part["n"] == 0:
        return "n/a (no pull request)"
    return (
        f"{part['total']}, median {part['median']}, most {part['max']} ({part['n']} pull requests)"
    )


def pulls_section(p: dict[str, Any], mark: str) -> str:
    title = f"{mark} Time of a merged pull request\n\n| Step | Value |\n| --- | --- |\n"
    if "unread" in p:
        return title + table([("Opened to ready for review", unread(p))]) + "\n"
    rows = [
        ("Opened to ready for review", spread(p["to_ready"])),
        ("Ready to the last required check green", spread(p["to_green"])),
        ("Last required check green to merged", spread(p["to_merged"])),
        ("Pushes after it was last ready (new heads CI ran on)", tally(p["pushes_after_ready"])),
        ("Merges of the default branch after it was last ready", tally(p["merges_after_ready"])),
    ]
    notes = [
        "Required checks, from the rules of the default branch: "
        + ", ".join(f"`{name}`" for name in p["required_checks"])
        + "."
    ]
    if p["no_green_head"]:
        notes.append(
            f"{p['no_green_head']} merged without every required check green on its last head:"
            " left out of the two times to and from green."
        )
    if p["ready_before_window"]:
        notes.append(
            f"{p['ready_before_window']} were last ready before the window: their pushes are"
            " not counted."
        )
    return title + table(rows) + "\n\n" + " ".join(notes) + "\n"


def sections(m: dict[str, Any], mark: str) -> str:
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
    return f"""{mark} Summary

{m["merged"]} pull requests merged, {m["agent_merged"]} by agents
({round(100 * m["agent_merged"] / total)}%). Agent acceptance rate {acceptance}.{partial}

{mark} Delivery

| Metric | Value |
| --- | --- |
| Production deployments | {m["deployments"]} |
| Median PR lead time (open → merge) | {lead} |
| Reverts | {m["reverts"]} |
| Change failure signal (reverts / deployments) | {failure} |

{mark} Flow

| Metric | Value |
| --- | --- |
{flow_rows(m)}

{thresholds_section(m["thresholds"], mark)}
{pulls_section(m["pulls"], mark)}
{jobs_section(m["ci"], mark)}
{mark} Agents

| Metric | Value |
| --- | --- |
| Agent PRs merged | {m["agent_merged"]} |
| Agent PRs closed without merge | {m["agent_closed_unmerged"]} |
| Merged agent PRs that needed changes | {m["agent_changes_requested"]} |
| Autonomy tier mix (merged) | {tiers} |
"""


NOTES = """## Notes

Widen autonomy (more paths in `low`) only when acceptance stays high and failures stay at
zero for several weeks; narrow it after an incident caused by an agent change.

Flow says whether parallel work queues. A file that leads "Files in conflict most often" is
written by many pull requests at once: give it one writer, or generate it instead of committing
it. The replay uses the merge rules of the checkout it ran in. Late red and red on the default
branch count every attempt of a run: a run made green by running it again still counts. A
summary job that is red only because the heavy tier of a draft was skipped is no late red.
"""


def front(week: str, since: str, title: str) -> str:
    return f"""---
type: metrics
title: Delivery metrics {week}
links: []
sources: [tools/sdlc_metrics.py, GitHub API since {since}]
---

# Delivery metrics {week}

{title}

"""


def render(m: dict[str, Any], week: str) -> str:
    title = f"The last {m['days']} days, from {m['since']}."
    return front(week, m["since"], title) + sections(m, "##") + "\n" + NOTES


def render_split(before: dict[str, Any], after: dict[str, Any], at: str, week: str) -> str:
    title = (
        f"The last {before['days']} days, from {before['since']}, split at {at}: a pull request"
        " is on the side of its merge, an open one on the later side, a run on the side it was"
        " created."
    )
    return (
        front(week, before["since"], title)
        + f"## Before {at}\n\n"
        + sections(before, "###")
        + f"\n## From {at}\n\n"
        + sections(after, "###")
        + "\n"
        + NOTES
    )
