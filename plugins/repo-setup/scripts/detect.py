#!/usr/bin/env python3
"""Detect what kind of repository a directory is, and suggest a preset.

Prints JSON. Standard library only.
"""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

IGNORED = {".git", "node_modules", ".venv", "venv", "__pycache__", "dist", "build", ".idea", ".vscode"}


def run(cmd: list[str], cwd: Path) -> str | None:
    try:
        return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=10, check=True).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return None


def tool_version(name: str, flag: str = "--version") -> str | None:
    if not shutil.which(name):
        return None
    out = run([name, flag], Path.cwd())
    return (out or "").splitlines()[0] if out else "installed"


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--target", default=".")
    args = ap.parse_args(argv)
    root = Path(args.target).resolve()

    entries = [p for p in root.iterdir()] if root.exists() else []
    meaningful = [p for p in entries if p.name not in IGNORED and p.name not in {".repo-setup.json", ".DS_Store"}]

    signals: dict[str, bool] = {
        "node": (root / "package.json").exists(),
        "typescript": (root / "tsconfig.json").exists(),
        "python": any((root / f).exists() for f in ("pyproject.toml", "setup.py", "requirements.txt", "Pipfile")),
        "go": (root / "go.mod").exists(),
        "rust": (root / "Cargo.toml").exists(),
        "java": any((root / f).exists() for f in ("pom.xml", "build.gradle", "build.gradle.kts")),
    }

    def text(name: str) -> str:
        try:
            return (root / name).read_text(encoding="utf-8", errors="replace").lower()
        except OSError:
            return ""

    suggested = None
    if signals["node"] or signals["typescript"]:
        pkg = text("package.json")
        suggested = "react-vite" if '"react"' in pkg else "ts-api" if '"fastify"' in pkg else "ts-node"
    elif signals["python"]:
        deps = text("pyproject.toml") + text("requirements.txt")
        suggested = "fastapi" if "fastapi" in deps else "python"

    previous = None
    manifest = root / ".repo-setup.json"
    if manifest.exists():
        try:
            previous = json.loads(manifest.read_text())
            keys = ("preset", "level", "archetype", "deploy", "capabilities", "version", "vars")
            previous = {k: previous.get(k) for k in keys}
        except json.JSONDecodeError:
            previous = {"error": "unreadable .repo-setup.json"}

    git_remote = run(["git", "remote", "get-url", "origin"], root) if (root / ".git").exists() else None

    result = {
        "target": str(root),
        "exists": root.exists(),
        "is_empty": len(meaningful) == 0,
        "file_count_top_level": len(meaningful),
        "has_git": (root / ".git").exists(),
        "git_remote": git_remote,
        "signals": signals,
        "unsupported_stack": next((k for k in ("go", "rust", "java") if signals[k]), None),
        "suggested_preset": suggested,
        "previous_setup": previous,
        "tools": {
            "git": tool_version("git"),
            "python3": tool_version("python3"),
            "node": tool_version("node"),
            "npm": tool_version("npm"),
            "uv": tool_version("uv"),
            "pre-commit": tool_version("pre-commit"),
            "gh": tool_version("gh"),
        },
    }
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
