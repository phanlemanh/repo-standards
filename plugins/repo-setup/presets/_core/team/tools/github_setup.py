#!/usr/bin/env python3
"""Configure the GitHub side of the AI-native SDLC with the gh CLI.

  python3 tools/github_setup.py              # show what would be done (dry run)
  python3 tools/github_setup.py --apply      # do it (needs admin rights on the repository)

Always: squash-only merges; environments "staging" and "production" (production requires a
human reviewer); a ruleset on the default branch (pull request + code-owner review + required
checks).
With agent workflows (--with github-agents at apply time): labels used by agents and the
autonomy gate, auto-merge, GitHub Actions allowed to approve low-tier pull requests, the "gate"
required check, and repository variables.
It never prints or sets secret values: it only tells you which secrets are missing.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))
from repo_ontology import find_repo_root, load_yaml_file

LABELS = [
    ("risk:low", "0e8a16", "Autonomy gate: agents may merge"),
    ("risk:medium", "fbca04", "Autonomy gate: a human approves"),
    ("risk:high", "b60205", "Autonomy gate: a code owner approves"),
    ("intent", "5319e7", "A human intent for the agents"),
    ("agent:spec", "1d76db", "Agent writes the spec only"),
    ("agent:implement", "1d76db", "Agent writes spec + implementation + PR"),
    ("spec:needs-approval", "d93f0b", "Spec waits for a human decision"),
    ("spec:approved", "0e8a16", "Human approved the spec; agent implements"),
    ("agent-review:approved", "0e8a16", "Independent agent review found no blockers"),
    ("agent-review:changes", "d93f0b", "Independent agent review requested changes"),
]
AGENT_WORKFLOW = ".github/workflows/pr-pipeline.yml"


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
    repo: str, branch: str, reviewer: str, marketplace: str, agents: bool
) -> list[dict[str, Any]]:
    steps: list[dict[str, Any]] = []
    required_checks = ["check", "gate"] if agents else ["check"]
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
            "what": "squash-only merges, delete merged branches"
            + (", auto-merge" if agents else ""),
            "args": [
                "api",
                "-X",
                "PATCH",
                f"repos/{repo}",
                "-F",
                f"allow_auto_merge={'true' if agents else 'false'}",
                "-F",
                "delete_branch_on_merge=true",
                "-F",
                "allow_squash_merge=true",
                "-F",
                "allow_merge_commit=false",
                "-F",
                "allow_rebase_merge=false",
            ],
        }
    )
    if agents:
        steps.append(
            {
                "what": "GitHub Actions may approve PRs (needed for low-tier auto-merge)",
                "args": [
                    "api",
                    "-X",
                    "PUT",
                    f"repos/{repo}/actions/permissions/workflow",
                    "-f",
                    "default_workflow_permissions=read",
                    "-F",
                    "can_approve_pull_request_reviews=true",
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
        "name": "repo-setup: protect default branch",
        "target": "branch",
        "enforcement": "active",
        "conditions": {"ref_name": {"include": ["~DEFAULT_BRANCH"], "exclude": []}},
        "rules": [
            {"type": "deletion"},
            {"type": "non_fast_forward"},
            {
                "type": "pull_request",
                "parameters": {
                    "required_approving_review_count": 1,
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
                    "required_status_checks": [{"context": c} for c in required_checks],
                },
            },
        ],
    }
    steps.append(
        {
            "what": f"ruleset on {branch}: PR + code-owner review + checks "
            f"{', '.join(required_checks)}",
            "ruleset": ruleset,
            "args": ["api", "-X", "POST", f"repos/{repo}/rulesets", "--input", "-"],
        }
    )
    if agents and marketplace:
        steps.append(
            {
                "what": "variable REPO_SETUP_MARKETPLACE (agents install repo-setup in CI)",
                "args": ["variable", "set", "REPO_SETUP_MARKETPLACE", "--body", marketplace],
            }
        )
    return steps


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
    ap.add_argument("--marketplace", default="", help="git URL of the repo-standards marketplace")
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

    agents = has_agents(root)
    steps = plan(repo, branch, reviewer, args.marketplace, agents)
    print(f"{'Applying' if args.apply else 'Dry run'} for {repo} (default branch {branch})\n")
    failures = 0
    for step in steps:
        if not args.apply:
            print(f"  - {step['what']}\n      gh {' '.join(step['args'])}")
            continue
        body = None
        if "ruleset" in step:
            ok, existing = gh(["api", f"repos/{repo}/rulesets", "--jq", ".[].name"])
            if ok and step["ruleset"]["name"] in existing.splitlines():
                print(f"  = {step['what']} (already exists)")
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

    ok, out = gh(["secret", "list", "--json", "name", "--jq", ".[].name"])
    names = set(out.splitlines()) if ok else set()
    print("\nSecrets (values are never read):")
    if not agents:
        print("  - agent workflows are off (apply.py --with github-agents): no agent secret needed")
    elif names & {"ANTHROPIC_API_KEY", "CLAUDE_CODE_OAUTH_TOKEN"}:
        print("  + agent credential present")
    else:
        print(
            "  ! missing ANTHROPIC_API_KEY or CLAUDE_CODE_OAUTH_TOKEN.\n"
            "    Easiest: in Claude Code run /install-github-app, or `claude setup-token` then\n"
            "    `gh secret set CLAUDE_CODE_OAUTH_TOKEN`. Also install https://github.com/apps/claude"
        )
    if "RELEASE_PLEASE_TOKEN" not in names:
        print("  - optional RELEASE_PLEASE_TOKEN (PAT/App token) so CI runs on release PRs")
    if not args.apply:
        print("\nRun again with --apply to make these changes.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
