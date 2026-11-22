#!/usr/bin/env python3
"""`python3 tools/github_setup.py --check`: would a run with --apply change anything?

Each step of the plan is compared with what GitHub has today, with reads only:

  = <step>   already as the step would make it
  ~ <step>   a run with --apply would change it (also: a step this tool cannot compare)
  ? <step>   GitHub could not be read for it

Exit code: 0 every step is "=", 1 at least one "~", 2 at least one "?". Nothing is written.
Only the Python standard library is used.
"""

from __future__ import annotations

import json
from collections.abc import Callable, Mapping
from itertools import pairwise
from typing import Any

import github_setup as setup

SAME, CHANGE, UNREAD = "=", "~", "?"
Reader = Callable[[str], tuple[str, Any]]


def read(path: str) -> tuple[str, Any]:
    """("ok", the JSON GitHub gives), ("absent", None) on 404, or ("unread", why)."""
    ok, out = setup.gh(["api", path])
    if ok:
        try:
            return "ok", json.loads(out) if out else {}
        except json.JSONDecodeError:
            return "unread", "the answer is not JSON"
    if "HTTP 404" in out:
        return "absent", None
    return "unread", (out.splitlines() or ["no answer"])[0]


def fields(args: list[str]) -> dict[str, Any]:
    """The -F and -f pairs of a gh api call, with true and false as booleans."""
    pairs: dict[str, Any] = {}
    for flag, value in pairwise(args):
        if flag in ("-F", "-f") and "=" in value:
            key, raw = value.split("=", 1)
            pairs[key] = {"true": True, "false": False}.get(raw, raw) if flag == "-F" else raw
    return pairs


def _pairs_match(path: str, args: list[str]) -> tuple[str, str]:
    state, now = read(path)
    if state != "ok":
        return UNREAD if state == "unread" else CHANGE, str(now or "not there")
    differ = [k for k, v in fields(args).items() if now.get(k) != v]
    return (CHANGE, "differs: " + ", ".join(differ)) if differ else (SAME, "")


def _environment(repo: str, step: Mapping[str, Any]) -> tuple[str, str]:
    name = step["args"][3].rsplit("/", 1)[1]
    state, env = read(f"repos/{repo}/environments/{name}")
    if state != "ok":
        return UNREAD if state == "unread" else CHANGE, str(env or "not there")
    if "reviewer" not in step:
        return SAME, ""
    entity = setup.reviewer_entity(step["reviewer"]) if step["reviewer"] else None
    if entity is None:
        return UNREAD, f"cannot resolve reviewer '{step['reviewer']}'"
    reviewers = [
        (r.get("type"), (r.get("reviewer") or {}).get("id"))
        for rule in env.get("protection_rules") or []
        if rule.get("type") == "required_reviewers"
        for r in rule.get("reviewers") or []
    ]
    if set(reviewers) != {(entity["type"], entity["id"])}:
        return CHANGE, "the required reviewers differ"
    if env.get("deployment_branch_policy") is not None:
        return CHANGE, "a deployment branch policy is set"
    return SAME, ""


def _rules(ruleset: Mapping[str, Any]) -> dict[str, Any]:
    """type -> parameters, with the required checks as a set."""
    out: dict[str, Any] = {}
    for rule in ruleset.get("rules") or []:
        params = dict(rule.get("parameters") or {})
        if rule.get("type") == "required_status_checks":
            checks = params.pop("required_status_checks", [])
            params["checks"] = sorted(c.get("context") for c in checks)
        out[rule.get("type")] = params
    return out


def _ruleset(repo: str, step: Mapping[str, Any]) -> tuple[str, str]:
    want = step["ruleset"]
    try:
        earlier = setup.existing_ruleset(repo, want["name"])
    except LookupError as exc:
        return UNREAD, f"the rulesets could not be read: {exc}"
    if earlier is None:
        return CHANGE, "there is no ruleset yet"
    state, now = read(earlier[0])
    if state != "ok":
        return UNREAD if state == "unread" else CHANGE, str(now or "not there")
    have, need = _rules(now), _rules(want)
    differ = [
        kind
        for kind, params in need.items()
        if kind not in have or any(have[kind].get(k) != v for k, v in params.items())
    ]
    differ += [
        key for key in ("enforcement", "target", "conditions") if now.get(key) != want.get(key)
    ]
    differ += [kind for kind in have if kind not in need]
    return (CHANGE, "differs: " + ", ".join(differ)) if differ else (SAME, "")


def _labels() -> dict[str, tuple[str, str]] | None:
    """name -> (colour, description) of the repository's labels; None when not listed."""
    ok, out = setup.gh(["label", "list", "--limit", "500", "--json", "name,color,description"])
    if not ok:
        return None
    try:
        rows = json.loads(out or "[]")
    except json.JSONDecodeError:
        return None
    return {r.get("name", ""): (r.get("color") or "", r.get("description") or "") for r in rows}


def _label(args: list[str], labels: Mapping[str, tuple[str, str]]) -> tuple[str, str]:
    name = args[2]
    if name not in labels:
        return CHANGE, "missing"
    want = dict(zip(args[3::2], args[4::2], strict=False))
    colour, description = labels[name]
    if colour.lower() != want.get("--color", colour).lower():
        return CHANGE, "another colour"
    if description != want.get("--description", description):
        return CHANGE, "another description"
    return SAME, ""


def compare(
    repo: str, step: Mapping[str, Any], labels: Mapping[str, tuple[str, str]] | None
) -> tuple[str, str]:
    """(mark, why) for one step of github_setup.plan()."""
    args = step["args"]
    if "ruleset" in step:
        return _ruleset(repo, step)
    if args[0] == "label":
        if labels is None:
            return UNREAD, "the labels could not be listed"
        return _label(args, labels)
    target = args[3] if len(args) > 3 and args[0] == "api" else ""
    if target.startswith(f"repos/{repo}/environments/"):
        return _environment(repo, step)
    if target in (f"repos/{repo}", f"repos/{repo}/actions/permissions/workflow"):
        return _pairs_match(target, args)
    return CHANGE, "this step cannot be compared, so it counts as a change"


def check(repo: str, steps: list[dict[str, Any]], unread: list[str]) -> int:
    """Prints one line per step and returns the exit code."""
    print(f"Check for {repo}: would --apply change anything?\n")
    labels = _labels() if any(s["args"][0] == "label" for s in steps) else {}
    marks = [UNREAD for _ in unread]
    for name in unread:
        print(
            f"{UNREAD} commit-format check {name}: its workflow on the default branch was not read"
        )
    for step in steps:
        mark, why = compare(repo, step, labels)
        marks.append(mark)
        print(f"{mark} {step['what']}" + (f"  ({why})" if why and mark != SAME else ""))
    if UNREAD in marks:
        return 2
    return 1 if CHANGE in marks else 0
