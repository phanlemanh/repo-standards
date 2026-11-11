#!/usr/bin/env python3
"""Score a repository against the top-tier checklist.

Usage:
  doctor.py [--target DIR] [--level starter|team] [--json] [--min-score N]
            [--checklist FILE] [--preset NAME]

The repository is scored as its kind: the preset in .repo-setup.json, or `claude-plugin` when it
has Claude Code plugin manifests. Checks that do not fit that kind are listed as not applicable,
with the reason, and are not scored.

Exit code is 1 when --min-score is given and the score is below it (useful in CI).
Standard library only (Python 3.11+).
"""
from __future__ import annotations

import sys

if sys.version_info < (3, 11):
    print(f"repo-setup needs Python 3.11 or newer; this is {sys.version.split()[0]}.", file=sys.stderr)
    sys.exit(2)

import argparse
import json
import os
import re
import shutil
import subprocess
import tomllib
from pathlib import Path

PLUGIN_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CHECKLIST = PLUGIN_ROOT / "checklists" / "top-tier.toml"
PRESETS_DIR = PLUGIN_ROOT / "presets"
# The manifest checks are the ones a claude-plugin repository runs itself (tools/plugin_lint.py).
PLUGIN_TOOLS = PRESETS_DIR / "claude-plugin" / "starter" / "tools"
LEVELS = ["starter", "team"]
PRUNE = {".git", "node_modules", ".venv", "venv", "__pycache__", "dist", "build",
         ".mypy_cache", ".ruff_cache", ".pytest_cache", "coverage", ".next", ".turbo"}


def glob_to_regex(pattern: str) -> re.Pattern[str]:
    i, out = 0, []
    while i < len(pattern):
        if pattern.startswith("**/", i):
            out.append("(?:.*/)?")
            i += 3
        elif pattern.startswith("**", i):
            out.append(".*")
            i += 2
        elif pattern[i] == "*":
            out.append("[^/]*")
            i += 1
        elif pattern[i] == "?":
            out.append("[^/]")
            i += 1
        else:
            out.append(re.escape(pattern[i]))
            i += 1
    return re.compile("^" + "".join(out) + "$")


class Repo:
    def __init__(self, root: Path):
        self.root = root
        self._files: list[str] | None = None

    @property
    def files(self) -> list[str]:
        if self._files is None:
            found: list[str] = []
            for dirpath, dirnames, filenames in os.walk(self.root):
                dirnames[:] = [d for d in dirnames if d not in PRUNE]
                rel_dir = Path(dirpath).relative_to(self.root).as_posix()
                for f in filenames:
                    found.append(f if rel_dir == "." else f"{rel_dir}/{f}")
            self._files = found
        return self._files

    def match(self, patterns: list[str]) -> list[str]:
        regs = [glob_to_regex(p) for p in patterns]
        return [f for f in self.files if any(r.match(f) for r in regs)]

    def read(self, rel: str) -> str:
        try:
            return (self.root / rel).read_text(encoding="utf-8", errors="replace")
        except OSError:
            return ""

    def is_git(self) -> bool:
        return (self.root / ".git").exists()

    def git_tracked(self, patterns: list[str]) -> list[str]:
        try:
            out = subprocess.run(["git", "ls-files", "--", *patterns], cwd=self.root,
                                 capture_output=True, text=True, timeout=20, check=True).stdout
        except (OSError, subprocess.SubprocessError):
            return []
        return [line for line in out.splitlines() if line.strip()]


def plugin_lint():  # type: ignore[no-untyped-def]
    if str(PLUGIN_TOOLS) not in sys.path:
        sys.path.insert(0, str(PLUGIN_TOOLS))
    import plugin_lint as module

    return module


def preset_chain(preset: str | None) -> set[str]:
    """The preset and the presets it extends."""
    chain: set[str] = set()
    current = preset
    while current and current not in chain:
        chain.add(current)
        try:
            with (PRESETS_DIR / current / "preset.toml").open("rb") as fh:
                current = tomllib.load(fh).get("extends")
        except (OSError, tomllib.TOMLDecodeError):
            break
    return chain


def repo_kind(root: Path, setup: dict, forced: str | None = None) -> tuple[str | None, str | None]:
    """(preset, how we know): --preset, then .repo-setup.json, then what the files show."""
    if forced:
        return forced, "--preset"
    if setup.get("preset"):
        return str(setup["preset"]), ".repo-setup.json"
    if plugin_lint().is_plugin_repo(root):
        return "claude-plugin", "detected: Claude Code plugin manifests"
    return None, None


def not_applicable(repo: Repo, check: dict, chain: set[str]) -> str | None:
    """The reason a check does not fit this kind of repository, or None when it applies.
    `unless` lists files whose presence makes the check apply after all."""
    for preset, rule in (check.get("not_applicable") or {}).items():
        if preset not in chain:
            continue
        if isinstance(rule, str):
            return rule
        if not repo.match(rule.get("unless", [])):
            return str(rule.get("reason", ""))
    return None


def summarise(problems: list[str], limit: int = 3) -> str:
    more = len(problems) - limit
    return "; ".join(problems[:limit]) + (f" (and {more} more)" if more > 0 else "")


def eval_alternative(repo: Repo, alt: dict) -> tuple[bool, list[str]]:
    matched = repo.match(alt.get("paths", []))
    if not matched:
        return False, []
    pattern = alt.get("pattern")
    min_lines = alt.get("min_lines")
    good = []
    for f in matched:
        text = repo.read(f) if (pattern or min_lines) else ""
        if pattern and not re.search(pattern, text):
            continue
        if min_lines and len([ln for ln in text.splitlines() if ln.strip()]) < min_lines:
            continue
        good.append(f)
    return bool(good), good


class Remote:
    """GitHub facts through the gh CLI. Every probe returns (status, detail)."""

    def __init__(self, root: Path):
        self.root = root
        self.info: dict | None = None
        self.error = ""
        if not shutil.which("gh"):
            self.error = "gh CLI not installed"
            return
        ok, out = self._gh(["repo", "view", "--json", "nameWithOwner,defaultBranchRef"])
        if not ok:
            self.error = "no GitHub remote or gh not authenticated (gh auth login)"
            return
        data = json.loads(out)
        self.info = {
            "repo": data["nameWithOwner"],
            "branch": (data.get("defaultBranchRef") or {}).get("name") or "main",
        }

    def _gh(self, args: list[str]) -> tuple[bool, str]:
        try:
            p = subprocess.run(["gh", *args], cwd=self.root, capture_output=True, text=True,
                               timeout=30)
        except (OSError, subprocess.SubprocessError) as exc:
            return False, str(exc)
        return p.returncode == 0, p.stdout if p.returncode == 0 else p.stderr

    def branch_protection(self) -> tuple[str, str]:
        assert self.info
        repo, branch = self.info["repo"], self.info["branch"]
        ok, out = self._gh(["api", f"repos/{repo}/branches/{branch}/protection"])
        if ok:
            data = json.loads(out)
            reviews = (data.get("required_pull_request_reviews") or {}).get(
                "required_approving_review_count", 0)
            checks = bool(data.get("required_status_checks"))
            if reviews >= 1 and checks:
                return "pass", f"{branch}: {reviews} approval(s) + required checks"
            return "fail", f"{branch} protected but approvals={reviews}, required checks={checks}"
        if "403" in out:
            return "skipped", "needs admin permission on the repository to read protection"
        ok, out = self._gh(["api", f"repos/{repo}/rules/branches/{branch}"])
        rules = json.loads(out) if ok else []
        if rules:
            reviews = max((r.get("parameters", {}).get("required_approving_review_count", 0)
                           for r in rules if r.get("type") == "pull_request"), default=0)
            checks = any(r.get("type") == "required_status_checks" for r in rules)
            if reviews >= 1 and checks:
                return "pass", f"{branch}: ruleset with {reviews} approval(s) + required checks"
            return "fail", f"{branch}: rules found but approvals={reviews}, required checks={checks}"
        return "fail", f"{branch} has no branch protection or ruleset"

    def ci_green(self) -> tuple[str, str]:
        assert self.info
        ok, out = self._gh(["run", "list", "--branch", self.info["branch"], "--limit", "30",
                            "--json", "workflowName,status,conclusion"])
        if not ok:
            return "skipped", "cannot list workflow runs"
        latest: dict[str, str] = {}
        for run in json.loads(out):
            if run.get("status") == "completed" and run["workflowName"] not in latest:
                latest[run["workflowName"]] = run.get("conclusion") or ""
        if not latest:
            return "fail", "no completed CI runs on the default branch yet"
        bad = {k: v for k, v in latest.items() if v not in ("success", "skipped", "neutral")}
        if bad:
            return "fail", ", ".join(f"{k}: {v}" for k, v in bad.items())
        return "pass", ", ".join(sorted(latest))

    def releases_for_tags(self) -> tuple[str, str]:
        """Version tags are published as GitHub Releases (the newest tag is the one checked)."""
        try:
            out = subprocess.run(["git", "tag", "--sort=-creatordate"], cwd=self.root,
                                 capture_output=True, text=True, timeout=20, check=True).stdout
        except (OSError, subprocess.SubprocessError):
            return "skipped", "cannot list git tags"
        tags = [line.strip() for line in out.splitlines() if line.strip()]
        if not tags:
            return "pass", "no tags yet"
        ok, out = self._gh(["release", "list", "--limit", "100", "--json", "tagName"])
        if not ok:
            return "skipped", "cannot list GitHub Releases"
        released = {r.get("tagName") for r in json.loads(out)}
        if not released:
            return "fail", f"{len(tags)} tag(s) and no GitHub Release"
        if tags[0] not in released:
            return "fail", f"the newest tag {tags[0]} has no GitHub Release"
        return "pass", f"{tags[0]} is released"


def blueprint_report(root: Path, setup: dict) -> dict[str, list[str]]:
    """Warnings from setup-blueprint.yaml. They never change the score."""
    path = root / "setup-blueprint.yaml"
    if not path.exists():
        return {"blueprint_drift": [], "manual_steps": []}
    import blueprint

    try:
        bp = blueprint.load(path)
    except Exception as exc:  # noqa: BLE001 - a broken blueprint must not stop the health report
        return {"blueprint_drift": [f"setup-blueprint.yaml cannot be read: {exc}"], "manual_steps": []}
    return {"blueprint_drift": blueprint.drift(bp, setup), "manual_steps": blueprint.manual_steps(bp)}


def run_check(repo: Repo, check: dict, remote: Remote | None = None,
              chain: set[str] | None = None) -> dict:
    ctype = check.get("type", "exists")
    res = {k: check.get(k) for k in ("id", "level", "title", "why", "fix")}
    res["weight"] = check.get("weight", 1)
    res["type"] = ctype
    if ctype == "manual" or (ctype == "remote" and remote is None):
        res["status"] = "manual"
        return res
    if ctype == "remote":
        assert remote is not None
        if remote.info is None:
            res["status"], res["detail"] = "skipped", remote.error
            return res
        probe = getattr(remote, str(check.get("probe")))
        res["status"], res["detail"] = probe()
        return res
    if ctype == "plugin":
        lint = plugin_lint()
        probe = lint.PROBES[str(check.get("probe"))]
        ok, problems = probe(lint.Marketplace(repo.root), **(check.get("params") or {}))
        res["status"] = "skipped" if ok is None else "pass" if ok else "fail"
        if problems:
            res["detail"] = summarise(problems)
            res["evidence"] = problems[:10]
        return res
    if ctype == "command":
        required = check.get("requires")
        if required and not (repo.root / required).exists():
            res["status"] = "fail"
            res["detail"] = f"{required} not found"
            return res
        cmd = [sys.executable if part == "{python}" else part for part in check.get("command", [])]
        try:
            proc = subprocess.run(cmd, cwd=repo.root, capture_output=True, text=True, timeout=120)
        except (OSError, subprocess.SubprocessError) as exc:
            res["status"] = "fail"
            res["detail"] = str(exc)
            return res
        res["status"] = "pass" if proc.returncode == 0 else "fail"
        res["evidence"] = (proc.stdout + proc.stderr).strip().splitlines()[-5:]
        return res
    if ctype == "not_committed":
        if not repo.is_git():
            res["status"] = "skipped"
            res["detail"] = "not a git repository"
            return res
        patterns = [p for alt in check.get("any", []) for p in alt.get("paths", [])]
        tracked = repo.git_tracked(patterns)
        res["status"] = "fail" if tracked else "pass"
        res["evidence"] = tracked
        return res
    for alt in check.get("any", []):
        # An alternative can be limited to some kinds of repository.
        if "presets" in alt and not (chain or set()) & set(alt["presets"]):
            continue
        ok, evidence = eval_alternative(repo, alt)
        if ok:
            res["status"] = "pass"
            res["evidence"] = evidence[:3]
            return res
    res["status"] = "fail"
    return res


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--target", default=".")
    ap.add_argument("--level", choices=LEVELS, default=None,
                    help="Level to score against (default: level in .repo-setup.json, else starter)")
    ap.add_argument("--checklist", default=str(DEFAULT_CHECKLIST))
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--min-score", type=int, default=None)
    ap.add_argument("--remote", action="store_true",
                    help="Also check GitHub (branch protection, CI status) with the gh CLI")
    ap.add_argument("--preset", default=None,
                    help="Score as this kind of repository (default: .repo-setup.json, else detected)")
    args = ap.parse_args(argv)

    root = Path(args.target).resolve()
    level = args.level
    if level is None:
        try:
            level = json.loads((root / ".repo-setup.json").read_text()).get("level", "starter")
        except (OSError, json.JSONDecodeError):
            level = "starter"

    with open(args.checklist, "rb") as fh:
        checklist = tomllib.load(fh)
    allowed = LEVELS[: LEVELS.index(level) + 1]
    try:
        setup = json.loads((root / ".repo-setup.json").read_text())
    except (OSError, json.JSONDecodeError):
        setup = {}
    archetype = setup.get("archetype", "none")
    deploy = setup.get("deploy", "none")
    caps = set(setup.get("capabilities") or [])
    setup_vars = setup.get("vars") or {}
    if archetype == "service-api":
        caps.add("mcp")
    preset, preset_source = repo_kind(root, setup, args.preset)
    chain = preset_chain(preset)
    repo = Repo(root)

    def applies(c: dict) -> bool:
        if c.get("level", "starter") not in allowed:
            return False
        if "archetypes" in c and archetype not in c["archetypes"]:
            return False
        if "capabilities" in c and not caps & set(c["capabilities"]):
            return False
        if "presets" in c and not chain & set(c["presets"]):
            return False
        if any(setup_vars.get(k) != v for k, v in (c.get("vars") or {}).items()):
            return False
        return not ("deploy" in c and deploy not in c["deploy"])

    checks, set_aside = [], []
    for c in checklist.get("check", []):
        if not applies(c):
            continue
        reason = not_applicable(repo, c, chain)
        if reason is None:
            checks.append(c)
        else:
            set_aside.append({"id": c.get("id"), "title": c.get("title"), "reason": reason})

    remote = Remote(root) if args.remote else None
    results = [run_check(repo, c, remote, chain) for c in checks]
    scored = [r for r in results if r["status"] in ("pass", "fail")]
    total = sum(r["weight"] for r in scored)
    got = sum(r["weight"] for r in scored if r["status"] == "pass")
    score = round(100 * got / total) if total else 100

    report = {
        "target": str(root),
        "level": level,
        "preset": preset,
        "preset_source": preset_source,
        "score": score,
        # True when GitHub protection applies but was not verified: the score covers local files.
        "local_only": any(c.get("type") == "remote" for c in checks)
        and (remote is None or remote.info is None),
        "passed": [r["id"] for r in results if r["status"] == "pass"],
        "failed": sorted([r for r in results if r["status"] == "fail"], key=lambda r: -r["weight"]),
        "manual": [r for r in results if r["status"] == "manual"],
        "skipped": [r for r in results if r["status"] == "skipped"],
        # Checks that do not fit this kind of repository: listed with the reason, never scored.
        "not_applicable": set_aside,
        **blueprint_report(root, setup),
    }

    if args.json:
        print(json.dumps(report, indent=2, ensure_ascii=False))
    else:
        bar = "#" * (score // 5) + "-" * (20 - score // 5)
        print(f"Repo health ({level}): {score}/100  [{bar}]")
        print(f"Passed {len(report['passed'])}/{len(scored)} scored checks")
        if preset and (set_aside or preset_source != ".repo-setup.json"):
            print(f"Scored as: {preset} ({preset_source})")
        print()
        if report["local_only"]:
            print("GitHub protection was not checked: this score covers local files only, and "
                  "the agent rules are only enforced by GitHub. Verify with --remote.\n")
        if report["failed"]:
            print("To fix (most important first):")
            for r in report["failed"]:
                print(f"  [{'!' * r['weight']:<3}] {r['title']}")
                print(f"         why: {r['why']}")
                print(f"         fix: {r['fix']}")
                if r.get("detail"):
                    print(f"         now: {r['detail']}")
        if report["manual"]:
            print("\nCheck manually (or run with --remote):")
            for r in report["manual"]:
                print(f"  [ ] {r['title']}  ({r['fix']})")
        if report["blueprint_drift"]:
            print("\nDiffers from setup-blueprint.yaml (not scored):")
            for line in report["blueprint_drift"]:
                print(f"  - {line}")
        if report["manual_steps"]:
            print("\nManual steps from setup-blueprint.yaml (not scored):")
            for line in report["manual_steps"]:
                print(f"  [ ] {line}")
        if set_aside:
            print(f"\nNot applicable to a {preset} repository (not scored):")
            for item in set_aside:
                print(f"  - {item['title']}: {item['reason']}")
        if report["skipped"]:
            print("\nSkipped: " + ", ".join(f"{r['id']} ({r.get('detail', '')})" for r in report["skipped"]))

    if args.min_score is not None and score < args.min_score:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
