"""What the CI jobs of a window say, for tools/sdlc_metrics.py. Standard library only.

Every function here reads runs and jobs as GitHub lists them and asks GitHub nothing itself. A job
of a run carries `run_id` and `waiting` (see `mark_waiting`) once `mark_waiting` has seen it.

A step that runs checks is a `make` step: the generated CI runs every check through a make target,
so GitHub names the step `Run make <target>`. Which test failed inside it is not read: that needs
the log and the output format of a test runner.
"""

from __future__ import annotations

import collections
from typing import Any

from sdlc_gh import median, parse_time

# The job that says a pull request may merge (.github/workflows/pr-pipeline.yml).
GATE_JOB = "gate"
RED = {"failure", "timed_out", "startup_failure"}
# The step of the summary job `check` (tools/ci_verdict.py): red when a tier did not succeed.
SUMMARY_STEP = "Every tier is green"
CHECK_STEP = "Run make "


def job_minutes(job: dict[str, Any]) -> float:
    if not (job.get("started_at") and job.get("completed_at")):
        return 0.0
    seconds = (parse_time(job["completed_at"]) - parse_time(job["started_at"])).total_seconds()
    return max(seconds, 0.0) / 60


def is_gate(job: dict[str, Any]) -> bool:
    name = str(job.get("name", ""))
    return name == GATE_JOB or name.endswith(f"/ {GATE_JOB}")


def is_red(job: dict[str, Any]) -> bool:
    return job.get("conclusion") in RED


def failed_step(job: dict[str, Any]) -> str | None:
    """The name of the step the job ended red at, or None when no step says so."""
    for step in job.get("steps") or []:
        if step.get("conclusion") in RED:
            return str(step.get("name") or "")
    return None


def step_kind(job: dict[str, Any]) -> str:
    """Where a red job ended: checks (a make step), summary, other, or not_read."""
    step = failed_step(job)
    if step is None:
        return "not_read"
    if step == SUMMARY_STEP:
        return "summary"
    return "checks" if step.startswith(CHECK_STEP) else "other"


def mark_waiting(run_id: Any, jobs: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Copies of the jobs of one run, each with its run and whether it only waited.

    A job waited when it is the summary job red at its summary step, in an attempt where another
    job was skipped and no other job was red: the heavy tier of a draft has not run yet. It says
    "not its turn", not "failed".
    """
    attempts: dict[Any, list[dict[str, Any]]] = collections.defaultdict(list)
    for job in jobs:
        attempts[job.get("run_attempt")].append(job)

    def waited(job: dict[str, Any]) -> bool:
        if not (is_red(job) and step_kind(job) == "summary"):
            return False
        others = [j for j in attempts[job.get("run_attempt")] if j is not job]
        skipped = any(j.get("conclusion") == "skipped" for j in others)
        return skipped and not any(is_red(j) for j in others)

    return [{**job, "run_id": run_id, "waiting": waited(job)} for job in jobs]


def is_late_red(jobs: list[dict[str, Any]]) -> bool | None:
    """Did a job end red after the gate job that passed had started? None: gate never passed.

    The jobs are those of one head, every attempt of every run: a run made green by running it
    again still counts. A job that only waited (see `mark_waiting`) is no late red.
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
        if is_red(j) and not is_gate(j) and not j.get("waiting") and j.get("completed_at")
    ]
    return any(at > min(passed) for at in ended_red)


def job_table(jobs: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    """One row per job name: attempts, outcomes, median minutes, machine hours, reds at a check."""
    by_name: dict[str, list[dict[str, Any]]] = collections.defaultdict(list)
    for job in jobs:
        by_name[str(job.get("name") or "unnamed")].append(job)
    rows = {}
    for name, of_name in by_name.items():
        ended = [job_minutes(j) for j in of_name if j.get("conclusion") == "success" or is_red(j)]
        rows[name] = {
            "runs": len(of_name),
            "green": sum(j.get("conclusion") == "success" for j in of_name),
            "red": sum(is_red(j) for j in of_name),
            "cancelled": sum(j.get("conclusion") == "cancelled" for j in of_name),
            "median_minutes": median(ended),
            "machine_hours": round(sum(job_minutes(j) for j in of_name) / 60, 2),
            "red_at_check_step": sum(is_red(j) and step_kind(j) == "checks" for j in of_name),
        }
    order = sorted(rows, key=lambda name: (-rows[name]["machine_hours"], name))
    return {name: rows[name] for name in order}


def red_steps(jobs: list[dict[str, Any]]) -> dict[str, int]:
    kinds = collections.Counter(step_kind(j) for j in jobs if is_red(j))
    return {kind: kinds[kind] for kind in ("checks", "summary", "other", "not_read")}


def red_across_branches(
    runs: list[dict[str, Any]], jobs: list[list[dict[str, Any]]]
) -> list[dict[str, Any]]:
    """The job and step that ended red on two or more branches: a red that is not one PR's.

    Gate jobs are left out (they wait for a proof), and so are reds at the summary step (they
    repeat the red of a tier) and reds whose step is not known.
    """
    branches: dict[tuple[str, str], set[str]] = collections.defaultdict(set)
    for run, of_run in zip(runs, jobs, strict=True):
        for job in of_run:
            if is_red(job) and not is_gate(job) and step_kind(job) in ("checks", "other"):
                key = (str(job.get("name") or "unnamed"), failed_step(job) or "")
                branches[key].add(str(run.get("head_branch") or "?"))
    rows = [
        {"job": job, "step": step, "branches": sorted(names)}
        for (job, step), names in branches.items()
        if len(names) > 1
    ]
    return sorted(rows, key=lambda row: (-len(row["branches"]), row["job"], row["step"]))


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
        red = run.get("conclusion") in RED or any(is_red(j) for j in of_run)
        if red or run.get("conclusion") == "success":
            name = str(run.get("name") or "unnamed")
            reds, total = counts.get(name, [0, 0])
            counts[name] = [reds + red, total + 1]
    return dict(sorted(counts.items()))


def ci_numbers(
    runs: list[dict[str, Any]], jobs: list[list[dict[str, Any]]], default_branch: str, merged: int
) -> dict[str, Any]:
    """Machine minutes, late red, red on the default branch and the jobs table, from marked jobs."""
    by_head: dict[str, list[dict[str, Any]]] = {}
    for run, of_run in zip(runs, jobs, strict=True):
        if str(run.get("event", "")).startswith("pull_request"):
            by_head.setdefault(run["head_sha"], []).extend(of_run)
    late = [verdict for verdict in map(is_late_red, by_head.values()) if verdict is not None]
    every = [job for of_run in jobs for job in of_run]
    minutes = sum(job_minutes(job) for job in every)
    return {
        "runs": len(runs),
        "machine_minutes": round(minutes, 1),
        "machine_minutes_per_merged_pr": round(minutes / merged, 1) if merged else None,
        "late_red": [sum(late), len(late)],
        "waiting_red": sum(bool(job.get("waiting")) for job in every),
        "default_branch": default_branch_red(runs, jobs, default_branch),
        "jobs": job_table(every),
        "red_steps": red_steps(every),
        "red_across_branches": red_across_branches(runs, jobs),
    }
