#!/usr/bin/env python3
"""Configure the GitHub side of the AI-native SDLC with the gh CLI.

  python3 tools/github_setup.py              # show what would be done (dry run)
  python3 tools/github_setup.py --apply      # do it (needs admin rights on the repository)

Always: one merge method, the one governance/autonomy.yaml stores as merge_method (a policy
from before that key keeps the repository's merge settings, or takes --merge-method);
environments "staging"
and "production" (production requires a human reviewer); a ruleset on the default branch (pull
request + required checks; a code owner decides only where .github/CODEOWNERS names one, and
nobody else has to approve). Required: `check`, `secret-scan`, the commit-format checks
(`conventional-title`, `conventional-commits`) once the default branch defines them, the checks
governance/autonomy.yaml names under required_checks, and its proof (proof.check) when it names
one.
With agent workflows (--with github-agents at apply time): labels used by agents and the
autonomy gate, auto-merge, the "gate" required check, and GitHub Actions kept from approving
pull requests.
A ruleset this script made earlier is updated in place. It stops instead of dropping a required
check the policy does not name; --prune drops it.
It never prints or sets secret values: it only tells you which secrets are missing.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))
from autonomy import (
    AGENT_WORKFLOW,
    merge_method,
    merge_method_problems,
    own_checks,
    proof_check,
    required_checks,
)
from repo_ontology import find_repo_root, load_yaml_file

LABELS = [
    ("risk:low", "0e8a16", "Autonomy gate: merges itself when the checks pass"),
    ("risk:medium", "fbca04", "Autonomy gate: not proven by a machine, a person merges"),
    ("risk:high", "b60205", "Autonomy gate: changes the rules, a code owner decides"),
    ("intent", "5319e7", "A human intent for the agents"),
    ("agent:spec", "1d76db", "Agent writes the spec only"),
    ("agent:implement", "1d76db", "Agent writes spec + implementation + PR"),
    ("spec:needs-approval", "d93f0b", "Spec waits for a human decision"),
    ("spec:approved", "0e8a16", "Human approved the spec; agent implements"),
    ("agent-review:approved", "0e8a16", "Independent agent review found no blockers"),
    ("agent-review:changes", "d93f0b", "Independent agent review requested changes"),
]
RULESET_CHECKS = (
    '.rules[] | select(.type == "required_status_checks") '
    "| .parameters.required_status_checks[].context"
)
# Jobs that run behind `check`, the job that stands for every CI tier. GitHub counts a skipped
# required check as green, and these are skipped when the light tier fails or the PR is a draft.
BEHIND_CHECK = ("heavy", "e2e")
# The one way pull requests are merged: (title of the step, the setting that allows it).
MERGE_METHODS = {
    "squash": ("squash-only merges", "allow_squash_merge"),
    "merge": ("merge commits only", "allow_merge_commit"),
}
MERGE_SETTINGS = ("allow_squash_merge", "allow_merge_commit", "allow_rebase_merge")
KEEP_MERGE = (
    "merge method left as it is (governance/autonomy.yaml names no merge_method: add one to choose)"
)


def workflow_has(root: Path, pattern: str) -> bool:
    """A workflow file of this repository has a line that matches the pattern."""
    found = re.compile(pattern, re.MULTILINE)
    folder = root / ".github" / "workflows"
    return any(
        found.search(path.read_text(encoding="utf-8", errors="replace"))
        for path in sorted(folder.glob("*.y*ml"))
    )


def uses_release_please(root: Path) -> bool:
    """A workflow of this repository opens release pull requests, which needs a key of its own."""
    return workflow_has(root, r"^\s*(-\s*)?uses:\s*googleapis/release-please-action")


def has_secret_scan(root: Path) -> bool:
    """A workflow defines the job `secret-scan`: a required check nobody reports blocks every PR."""
    return workflow_has(root, r"^  secret-scan:\s*$")


# They run from the default branch (pull_request_target), whatever the pull request holds.
COMMIT_FORMAT_JOBS = ("conventional-title", "conventional-commits")
RAW = "Accept: application/vnd.github.raw"
RULESET_NAME = "repo-setup: protect default branch"


def job_pattern(name: str) -> str:
    return rf"^  {re.escape(name)}:\s*$"


def commit_format_checks(
    root: Path, repo: str, branch: str
) -> tuple[list[str], list[str], list[str]]:
    """The commit-format checks to require, a note for each one left out, and those not read.

    Such a job runs as the default branch defines it. A check it does not define there never
    reports, and a required check that never reports blocks every pull request, the upgrade that
    brings the job included.
    """
    folder = root / ".github" / "workflows"
    required: list[str] = []
    notes: list[str] = []
    unread: list[str] = []
    for name in COMMIT_FORMAT_JOBS:
        found = re.compile(job_pattern(name), re.MULTILINE)
        local = [
            path
            for path in sorted(folder.glob("*.y*ml"))
            if found.search(path.read_text(encoding="utf-8", errors="replace"))
        ]
        if not local:
            continue
        rel = local[0].relative_to(root).as_posix()
        ok, text = gh(["api", "-H", RAW, f"repos/{repo}/contents/{rel}?ref={branch}"])
        if ok and found.search(text):
            required.append(name)
        elif ok or "HTTP 404" in text:
            notes.append(
                f"{name} is not a required check yet: {rel} on {branch} does not define it (or "
                "the file is not there). Merge the upgrade, then run this again."
            )
        else:
            reason = (text.splitlines() or ["no answer"])[0]
            unread.append(name)
            notes.append(
                f"{name}: {rel} on {branch} could not be read ({reason}). A ruleset that requires "
                "it keeps it; it is not added."
            )
    return required, notes, unread


def kept_checks(repo: str, names: list[str]) -> list[str]:
    """The checks among these names that the ruleset of an earlier run requires today.

    A read that fails is not a reason to drop a wall: what the ruleset has, it keeps.
    """
    if not names:
        return []
    try:
        earlier = existing_ruleset(repo, RULESET_NAME)
    except LookupError:
        return []
    current = (earlier[1] if earlier else None) or []
    return [name for name in names if name in current]


def secret_names(repo: str) -> set[str] | None:
    """Names of the secrets this repository's workflows can read; None when not listable."""
    ok, out = gh(["secret", "list", "--json", "name", "--jq", ".[].name"])
    if not ok:
        return None
    names = set(out.split())
    # Secrets an organisation shares with this repository count too.
    ok, out = gh(["api", f"repos/{repo}/actions/organization-secrets", "--jq", ".secrets[].name"])
    return names | set(out.split()) if ok else names


def has_agents(root: Path) -> bool:
    """Agent workflows are on when the PR pipeline exists (also true for older repositories)."""
    return (root / AGENT_WORKFLOW).exists()


def gh(args: list[str], input_text: str | None = None) -> tuple[bool, str]:
    try:
        proc = subprocess.run(  # noqa: S603
            ["gh", *args],  # noqa: S607
            input=input_text,
            capture_output=True,
            text=True,
            timeout=60,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        return False, str(exc)
    return proc.returncode == 0, (proc.stdout if proc.returncode == 0 else proc.stderr).strip()


def reviewer_entity(handle: str) -> dict[str, Any] | None:
    """'@user' -> {type: User, id}, '@org/team' -> {type: Team, id}."""
    handle = handle.lstrip("@")
    if "/" in handle:
        org, slug = handle.split("/", 1)
        ok, out = gh(["api", f"orgs/{org}/teams/{slug}", "--jq", ".id"])
        return {"type": "Team", "id": int(out)} if ok and out.isdigit() else None
    ok, out = gh(["api", f"users/{handle}", "--jq", ".id"])
    return {"type": "User", "id": int(out)} if ok and out.isdigit() else None


def plan(
    repo: str,
    branch: str,
    reviewer: str,
    agents: bool,
    merge_method: str = "squash",
    proof: str = "",
    extra: tuple[str, ...] | list[str] = (),
    secret_scan: bool = True,
    commit_format: tuple[str, ...] | list[str] = (),
) -> list[dict[str, Any]]:
    # "" (a policy from before merge_method, and no option): the merge settings are left alone.
    merge_title, merge_allowed = MERGE_METHODS[merge_method] if merge_method else (KEEP_MERGE, "")
    merge_fields = [
        arg
        for setting in (MERGE_SETTINGS if merge_method else ())
        for arg in ("-F", f"{setting}={'true' if setting == merge_allowed else 'false'}")
    ]
    steps: list[dict[str, Any]] = []
    # The setup's own checks, then the ones the repository names, then the proof.
    checks = ["check", "gate"] if agents else ["check"]
    checks += ["secret-scan"] if secret_scan else []
    checks += [name for name in commit_format if name not in checks]
    checks += [name for name in extra if name not in checks and name != proof]
    if proof and proof not in checks:
        checks.append(proof)
    for name, color, desc in LABELS if agents else []:
        steps.append(
            {
                "what": f"label {name}",
                "args": [
                    "label",
                    "create",
                    name,
                    "--color",
                    color,
                    "--description",
                    desc,
                    "--force",
                ],
            }
        )
    steps.append(
        {
            "what": f"{merge_title}, delete merged branches" + (", auto-merge" if agents else ""),
            "args": [
                "api",
                "-X",
                "PATCH",
                f"repos/{repo}",
                *(["-F", "allow_auto_merge=true"] if agents else []),
                "-F",
                "delete_branch_on_merge=true",
                *merge_fields,
            ],
        }
    )
    if agents:
        steps.append(
            {
                "what": "GitHub Actions cannot approve PRs (no merge needs an approval from it)",
                "args": [
                    "api",
                    "-X",
                    "PUT",
                    f"repos/{repo}/actions/permissions/workflow",
                    "-f",
                    "default_workflow_permissions=read",
                    "-F",
                    "can_approve_pull_request_reviews=false",
                ],
            }
        )
    steps.append(
        {
            "what": "environment staging",
            "args": ["api", "-X", "PUT", f"repos/{repo}/environments/staging"],
        }
    )
    steps.append(
        {
            "what": f"environment production (human approval by {reviewer})",
            "reviewer": reviewer,
            "args": ["api", "-X", "PUT", f"repos/{repo}/environments/production", "--input", "-"],
        }
    )
    ruleset = {
        "name": RULESET_NAME,
        "target": "branch",
        "enforcement": "active",
        "conditions": {"ref_name": {"include": ["~DEFAULT_BRANCH"], "exclude": []}},
        "rules": [
            {"type": "deletion"},
            {"type": "non_fast_forward"},
            {
                "type": "pull_request",
                "parameters": {
                    # Nobody approves as a checker: the required checks are the proof. A
                    # person decides only where CODEOWNERS names an owner.
                    "required_approving_review_count": 0,
                    "require_code_owner_review": True,
                    "dismiss_stale_reviews_on_push": True,
                    "require_last_push_approval": False,
                    "required_review_thread_resolution": False,
                },
            },
            {
                "type": "required_status_checks",
                "parameters": {
                    "strict_required_status_checks_policy": False,
                    "required_status_checks": [{"context": c} for c in checks],
                },
            },
        ],
    }
    steps.append(
        {
            "what": f"ruleset on {branch}: PR + code owner where CODEOWNERS names one + checks "
            f"{', '.join(checks)}",
            "ruleset": ruleset,
            "args": ["api", "-X", "POST", f"repos/{repo}/rulesets", "--input", "-"],
        }
    )
    return steps


def existing_ruleset(repo: str, name: str) -> tuple[str, list[str] | None] | None:
    """(API path, required checks) of the ruleset an earlier run made; None when there is none.

    The checks are None when they could not be read. A list of rulesets that cannot be read
    raises LookupError: "unknown" must not be taken for "none", or a second ruleset is made.
    """
    query = f'.[] | select(.name == "{name}") | .id'
    found, ids = gh(["api", f"repos/{repo}/rulesets", "--paginate", "--jq", query])
    if not found:
        raise LookupError(ids[:200] or "gh could not list the rulesets")
    if not ids.split():
        return None
    target = f"repos/{repo}/rulesets/{ids.split()[0]}"
    ok, out = gh(["api", target, "--jq", RULESET_CHECKS])
    return target, ([line for line in out.splitlines() if line.strip()] if ok else None)


def wanted_checks(ruleset: dict[str, Any]) -> set[str]:
    """The checks a ruleset requires."""
    return {
        check["context"]
        for rule in ruleset["rules"]
        if rule["type"] == "required_status_checks"
        for check in rule["parameters"]["required_status_checks"]
    }


def dropped_checks(current: list[str] | None, ruleset: dict[str, Any]) -> list[str]:
    """Required checks the repository has today that the new ruleset would no longer require."""
    if current is None:
        return ["(the current required checks could not be read)"]
    wanted = wanted_checks(ruleset)
    return [name for name in current if name not in wanted]


def behind_check(ruleset: dict[str, Any], kept: list[str]) -> list[str]:
    """Required checks, wanted or kept from today's ruleset, that run behind `check`."""
    wanted = wanted_checks(ruleset)
    return [name for name in BEHIND_CHECK if name in wanted or name in kept]


BEHIND_HELP = (
    "can be skipped, and GitHub counts a skipped check as green: a job behind the light tier is "
    "skipped when that tier fails or the pull request is a draft, and only check stands for it. "
    "Nothing is dropped: to stop requiring it, take it out of required_checks and pass --prune"
)


DROP_HELP = (
    "governance/autonomy.yaml does not name them: add them under required_checks, "
    "or pass --prune to drop them"
)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("--apply", action="store_true", help="execute (default: dry run)")
    ap.add_argument(
        "--reviewer",
        help="production approver, e.g. @alice or @org/team "
        "(default: first high-tier owner in governance/autonomy.yaml)",
    )
    ap.add_argument(
        "--merge-method",
        choices=list(MERGE_METHODS),
        help="the one way pull requests are merged, for a policy that does not store it yet: "
        "squash puts one commit per pull request on the default branch; merge keeps the branch's "
        "commits and adds a merge commit. Where governance/autonomy.yaml names merge_method, that "
        "is the choice, and an option that differs is refused",
    )
    ap.add_argument(
        "--prune",
        action="store_true",
        help="drop required checks that the default branch has today and that "
        "governance/autonomy.yaml does not name (default: stop and say which)",
    )
    args = ap.parse_args(argv)

    if not shutil.which("gh"):
        print("gh CLI not found: https://cli.github.com", file=sys.stderr)
        return 1
    ok, out = gh(["repo", "view", "--json", "nameWithOwner,defaultBranchRef"])
    if not ok:
        print(f"Not a GitHub repository or not logged in (gh auth login): {out}", file=sys.stderr)
        return 1
    info = json.loads(out)
    repo, branch = info["nameWithOwner"], (info.get("defaultBranchRef") or {}).get("name", "main")

    root = find_repo_root()
    policy = load_yaml_file(root / "governance" / "autonomy.yaml") or {}
    owners = (policy.get("owners") or {}).get("high") or []
    reviewer = args.reviewer or (owners[0] if owners else "")

    stored, bad = merge_method(policy), merge_method_problems(policy)
    if bad:
        print(f"governance/autonomy.yaml: {bad[0]}. Nothing was changed.", file=sys.stderr)
        return 1
    if stored and args.merge_method and args.merge_method != stored:
        print(
            f"governance/autonomy.yaml says merge_method: {stored}, and --merge-method asks for "
            f"{args.merge_method}. The choice is stored in the policy: change merge_method in "
            "governance/autonomy.yaml (a change to the rules of the game) and run again.",
            file=sys.stderr,
        )
        return 2
    agents, own = has_agents(root), own_checks(root)
    commit_format, commit_format_notes, unread_format = commit_format_checks(root, repo, branch)
    commit_format += kept_checks(repo, unread_format)
    steps = plan(
        repo,
        branch,
        reviewer,
        agents,
        stored or args.merge_method or "",
        proof_check(policy, own),
        required_checks(policy, own),
        has_secret_scan(root),
        commit_format,
    )
    print(f"{'Applying' if args.apply else 'Dry run'} for {repo} (default branch {branch})\n")
    # What could not be read is a failure, also when nothing else went wrong.
    failures = len(unread_format)
    behind: list[str] = []
    for step in steps:
        gone: list[str] = []
        pruned: list[str] = []
        unread = ""
        if "ruleset" in step:
            # A ruleset from an earlier run is brought up to date, not left as it was. A required
            # check someone added by hand is never dropped in silence.
            try:
                earlier = existing_ruleset(repo, step["ruleset"]["name"])
            except LookupError as exc:
                earlier, unread = None, str(exc)
            if earlier:
                target, current = earlier
                step = {**step, "args": ["api", "-X", "PUT", target, "--input", "-"]}
                gone = dropped_checks(current, step["ruleset"])
                if args.prune:
                    gone, pruned = [], gone
            # What stays required after this step: what it asks for, and what it would not drop.
            behind = behind_check(step["ruleset"], gone)
        if not args.apply:
            print(f"  - {step['what']}\n      gh {' '.join(step['args'])}")
            if unread:
                print(
                    f"      ! the rulesets could not be read, so --apply will stop here: {unread}"
                )
            if gone:
                print(f"      ! would drop the required check(s) {', '.join(gone)}: {DROP_HELP}")
            if pruned:
                print(f"      ! --prune: drops the required check(s) {', '.join(pruned)}")
            continue
        body = None
        if "ruleset" in step:
            if unread:
                print(f"  ! {step['what']}: not changed, the rulesets could not be read: {unread}")
                failures += 1
                continue
            if pruned:
                print(f"  ! --prune: dropping the required check(s) {', '.join(pruned)}")
            if gone:
                print(
                    f"  ! {step['what']}: not changed, it would drop the required check(s) "
                    f"{', '.join(gone)}. {DROP_HELP[0].upper()}{DROP_HELP[1:]}."
                )
                failures += 1
                continue
            body = json.dumps(step["ruleset"])
        if "reviewer" in step:
            entity = reviewer_entity(step["reviewer"]) if step["reviewer"] else None
            if entity is None:
                print(f"  ! {step['what']}: cannot resolve reviewer '{step['reviewer']}'")
                failures += 1
                continue
            body = json.dumps({"reviewers": [entity], "deployment_branch_policy": None})
        ok, out = gh(step["args"], body)
        print(f"  {'+' if ok else '!'} {step['what']}" + ("" if ok else f": {out[:200]}"))
        failures += 0 if ok else 1

    if not has_secret_scan(root):
        print(
            "\n  ! secret-scan is not a required check: no workflow of this repository has a job "
            "with that name."
        )
    for note in commit_format_notes:
        print(f"\n  ! {note}")
    for name in behind:
        print(f"\n  ! {name} is a required check that {BEHIND_HELP}.")
    names = secret_names(repo)
    print("\nSecrets (values are never read):")
    if names is None:
        print("  - the secrets of this repository could not be listed: none was checked")
    else:
        if not agents:
            print(
                "  - agent workflows are off (apply.py --with github-agents): "
                "no agent secret needed"
            )
        elif names & {"ANTHROPIC_API_KEY", "CLAUDE_CODE_OAUTH_TOKEN"}:
            print("  + agent credential present")
        else:
            print(
                "  ! missing ANTHROPIC_API_KEY or CLAUDE_CODE_OAUTH_TOKEN.\n"
                "    Easiest: in Claude Code run /install-github-app, or `claude setup-token`\n"
                "    then `gh secret set CLAUDE_CODE_OAUTH_TOKEN`. Also install "
                "https://github.com/apps/claude"
            )
        if uses_release_please(root):
            if "RELEASE_PLEASE_TOKEN" in names:
                print("  + release key present")
            else:
                print(
                    "  ! RELEASE_PLEASE_TOKEN is missing: releases are off until it is set.\n"
                    "    GitHub Actions may not open pull requests with its own token: store a\n"
                    "    PAT or GitHub App token that may, with "
                    "`gh secret set RELEASE_PLEASE_TOKEN`."
                )
    if not args.apply:
        print("\nRun again with --apply to make these changes.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
