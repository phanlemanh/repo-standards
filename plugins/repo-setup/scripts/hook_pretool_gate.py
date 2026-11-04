#!/usr/bin/env python3
"""PreToolUse hook: the human edge for high-tier files.

In a repo with governance/autonomy.yaml, an edit to a file whose tier is "high"
(ontology, auth, data, infra, CI, agent config...) is not done silently:
  * interactive session -> Claude Code asks the human to approve that edit;
  * headless / CI       -> "ask" means no, so the agent stops and asks for a spec approval.
A CI run that a human explicitly approved (label spec:approved added by a person) sets
REPO_SETUP_APPROVAL in the environment; then high-tier edits are allowed.
Paths that .claude/settings.json denies (workflows, governance) stay denied regardless.

The rules are read from the repository, the code that applies them is the plugin's own:
importing tools/ from the repository would run its code on the first edit. When the policy
cannot be read, the edit is treated as high-tier.

Silent outside repo-setup repositories or when REPO_SETUP_HOOKS=off. Standard library only.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

CORE = Path(__file__).resolve().parent.parent / "presets" / "_core"


def tier_of(root: Path, rel: str) -> str:
    sys.dont_write_bytecode = True
    sys.path[:0] = [str(CORE / "team" / "tools"), str(CORE / "starter" / "tools")]
    import autonomy  # type: ignore[import-not-found]

    policy = autonomy.load_policy(root)
    if not policy.get("high"):
        raise ValueError("no high-tier paths")
    result = autonomy.classify(policy, [{"path": rel, "status": "M", "added": 1, "deleted": 0}])
    return str(result["tier"])


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0
    if os.environ.get("REPO_SETUP_HOOKS") == "off":
        return 0
    root = Path(os.environ.get("CLAUDE_PROJECT_DIR") or payload.get("cwd") or ".").resolve()
    if not (root / ".repo-setup.json").exists() or not (root / "governance" / "autonomy.yaml").exists():
        return 0

    tool_input = payload.get("tool_input") or {}
    raw = tool_input.get("file_path") or tool_input.get("notebook_path")
    if not raw:
        return 0
    try:
        rel = Path(raw).resolve().relative_to(root).as_posix()
    except ValueError:
        return 0  # outside the repository

    why = "is a high-tier path in governance/autonomy.yaml (domain, data, security, infra or rules of the game)"
    try:
        tier = tier_of(root, rel)
    except (Exception, SystemExit) as exc:  # noqa: BLE001 - a broken gate must not open the gate
        tier, why = "high", f"cannot be classified because governance/autonomy.yaml is unusable ({exc})"
    if tier != "high":
        return 0

    approval = os.environ.get("REPO_SETUP_APPROVAL", "").strip()
    if approval:
        return 0

    reason = (
        f"'{rel}' {why}. A human must approve this change: approve this edit, "
        "or — in CI — post the spec on the issue, add the label spec:needs-approval and stop."
    )
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "ask",
                    "permissionDecisionReason": reason,
                }
            }
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
