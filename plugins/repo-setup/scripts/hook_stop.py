#!/usr/bin/env python3
"""Stop hook: before Claude finishes in a repo-setup repository,
  1. run `make check` if code changed since the last green check, and keep Claude working
     while it fails (at most MAX_BLOCKS times in a row, then let it stop with a warning);
  2. once per change set, remind Claude to record the change in wiki/ if it did not.

Does nothing outside repo-setup repositories, outside git, or when there are no changes.
Turn off per repo in .repo-setup.json: {"hooks": {"stop_check": false, "wiki_reminder": false}}
or for a session with REPO_SETUP_HOOKS=off. Standard library only.
"""
from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

MAX_BLOCKS = 3
CHECK_TIMEOUT = 540


def git(root: Path, *args: str) -> str:
    return subprocess.run(["git", *args], cwd=root, capture_output=True, text=True,
                          timeout=30, check=True).stdout


def fingerprint(root: Path, status: str) -> str:
    h = hashlib.sha256(status.encode())
    h.update(git(root, "diff", "HEAD", "--no-color").encode() if has_head(root) else b"")
    for line in status.splitlines():
        if line.startswith("??"):
            p = root / line[3:].strip().strip('"')
            if p.is_file():
                st = p.stat()
                h.update(f"{p}:{st.st_size}:{st.st_mtime_ns}".encode())
    return h.hexdigest()


def has_head(root: Path) -> bool:
    try:
        git(root, "rev-parse", "--verify", "HEAD")
        return True
    except subprocess.CalledProcessError:
        return False


def changed_paths(status: str) -> list[str]:
    paths = []
    for line in status.splitlines():
        path = line[3:].strip().strip('"')
        if " -> " in path:
            path = path.split(" -> ", 1)[1]
        paths.append(path)
    return paths


def is_code(path: str) -> bool:
    if path.startswith("wiki/") or path == ".repo-setup.json":
        return False
    return not path.endswith((".md", ".txt"))


def has_check_target(root: Path) -> bool:
    mk = root / "Makefile"
    return mk.exists() and shutil.which("make") is not None and "\ncheck:" in "\n" + mk.read_text()


def block(reason: str) -> None:
    print(json.dumps({"decision": "block", "reason": reason}))


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        payload = {}
    root = Path(os.environ.get("CLAUDE_PROJECT_DIR") or payload.get("cwd") or ".").resolve()
    manifest = root / ".repo-setup.json"
    if not manifest.exists() or not (root / ".git").exists() or os.environ.get("REPO_SETUP_HOOKS") == "off":
        return 0
    try:
        settings = json.loads(manifest.read_text()).get("hooks", {})
    except json.JSONDecodeError:
        settings = {}

    # In a linked worktree .git is a file: ask git where this worktree keeps its state.
    try:
        state_file = root / git(root, "rev-parse", "--git-path", "repo-setup-hook.json").strip()
    except (OSError, subprocess.SubprocessError):
        return 0
    try:
        state = json.loads(state_file.read_text())
    except (OSError, json.JSONDecodeError):
        state = {}

    try:
        status = git(root, "status", "--porcelain", "--untracked-files=all")
    except (OSError, subprocess.SubprocessError):
        return 0
    if not status.strip():
        state["blocks"] = 0
        state_file.write_text(json.dumps(state))
        return 0

    paths = changed_paths(status)
    code_changed = any(is_code(p) for p in paths)
    wiki_changed = any(p.startswith("wiki/") for p in paths)
    fp = fingerprint(root, status)

    # 1. make check
    if settings.get("stop_check", True) and code_changed and has_check_target(root) \
            and state.get("green") != fp:
        if payload.get("stop_hook_active") and state.get("blocks", 0) >= MAX_BLOCKS:
            state["blocks"] = 0
            state_file.write_text(json.dumps(state))
            print(json.dumps({"systemMessage": f"repo-setup: `make check` still fails after "
                              f"{MAX_BLOCKS} attempts — stopping; please review."}))
            return 0
        try:
            proc = subprocess.run(["make", "check"], cwd=root, capture_output=True, text=True,
                                  timeout=CHECK_TIMEOUT)
            ok, output = proc.returncode == 0, proc.stdout + proc.stderr
        except subprocess.TimeoutExpired:
            ok, output = True, ""  # too slow to enforce here; CI will catch it
        if not ok:
            state["blocks"] = state.get("blocks", 0) + 1
            state_file.write_text(json.dumps(state))
            tail = "\n".join(output.strip().splitlines()[-40:])
            block("`make check` fails after your changes. Fix the problems (run `make format` "
                  "first if it is only formatting), re-run `make check`, then finish.\n\n"
                  f"Last lines of output:\n{tail}")
            return 0
        state["green"] = fp
        state["blocks"] = 0

    # 2. wiki reminder (once per change set)
    if settings.get("wiki_reminder", True) and code_changed and not wiki_changed \
            and (root / "wiki").is_dir() and state.get("reminded") != fp:
        state["reminded"] = fp
        state_file.write_text(json.dumps(state))
        block("Code changed but wiki/ was not updated. Per the agent guide: add one line to "
              "wiki/log.md, plus a decision/incident/entity page if this change has a lasting "
              "'why' (see /repo-setup:wiki-ingest). If it truly needs nothing, say so in one "
              "sentence and finish.")
        return 0

    state_file.write_text(json.dumps(state))
    return 0


if __name__ == "__main__":
    sys.exit(main())
