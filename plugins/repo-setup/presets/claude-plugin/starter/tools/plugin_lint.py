#!/usr/bin/env python3
"""Check the Claude Code plugin manifests of this repository.

  python3 tools/plugin_lint.py [--root DIR] [--json] [--max-description N]

Reads .claude-plugin/marketplace.json and the plugin.json of every plugin it lists, and reports:

  manifests     every manifest is valid JSON, every listed plugin exists, and the names agree
  versions      the marketplace and plugin.json state the same version, and all plugins share one
                version unless .repo-setup.json says "plugin_versioning": "independent" under "vars"
  sources       no plugin uses the repository root as its source
  descriptions  descriptions stay at or under 1024 characters

Exit code 1 when a problem is found. Standard library only (Python 3.8+). `make lint` and CI run
it; repo-setup's doctor scores a repository with the same functions.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional, Tuple

MARKETPLACE = ".claude-plugin/marketplace.json"
MANIFEST = ".claude-plugin/plugin.json"
SETUP = ".repo-setup.json"
# The cap Claude Code puts on a skill description. Plugin descriptions are shown in the same
# pickers, and all but one of the 317 entries in the official marketplace fit (2026-11).
MAX_DESCRIPTION = 1024

# (passed, problems). passed is None when the check could not be evaluated at all.
Result = Tuple[Optional[bool], List[str]]


def is_plugin_repo(root: Path) -> bool:
    """A marketplace manifest, a plugin manifest at the root, or plugins/<name>/ manifests."""
    if (root / MARKETPLACE).is_file() or (root / MANIFEST).is_file():
        return True
    return any((root / "plugins").glob("*/" + MANIFEST))


def read_json(path: Path) -> Tuple[Optional[Dict[str, Any]], str]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except OSError as exc:
        return None, f"cannot be read ({exc.strerror or exc})"
    except json.JSONDecodeError as exc:
        return None, f"is not valid JSON (line {exc.lineno}: {exc.msg})"
    if not isinstance(data, dict):
        return None, "must be a JSON object"
    return data, ""


def versioning_policy(root: Path) -> str:
    """"lockstep" (default: one version for every plugin) or "independent"."""
    setup, _ = read_json(root / SETUP)
    policy = ((setup or {}).get("vars") or {}).get("plugin_versioning")
    return policy if policy == "independent" else "lockstep"


class Plugin:
    """One entry of the marketplace. `path` is None when the source is not a folder in the repo."""

    def __init__(self, root: Path, base: Path, entry: Dict[str, Any]):
        self.entry = entry
        self.name = str(entry.get("name") or "")
        self.source = entry.get("source")
        self.local = isinstance(self.source, str)
        self.path: Optional[Path] = None
        self.rel = ""
        self.manifest: Optional[Dict[str, Any]] = None
        self.manifest_problem = ""
        if not self.local:
            return
        path = (base / str(self.source)).resolve()
        try:
            self.rel = path.relative_to(root).as_posix()
        except ValueError:
            return
        self.path = path
        if (path / MANIFEST).is_file():
            self.manifest, self.manifest_problem = read_json(path / MANIFEST)

    @property
    def manifest_rel(self) -> str:
        return MANIFEST if self.rel in ("", ".") else f"{self.rel}/{MANIFEST}"


class Marketplace:
    def __init__(self, root: Path):
        self.root = Path(root).resolve()
        self.plugins: List[Plugin] = []
        self.entry_problems: List[str] = []
        if not (self.root / MARKETPLACE).is_file():
            self.data, self.problem = None, "not found"
            return
        self.data, self.problem = read_json(self.root / MARKETPLACE)
        if self.data is None:
            return
        metadata = self.data.get("metadata")
        plugin_root = metadata.get("pluginRoot") if isinstance(metadata, dict) else None
        base = self.root / plugin_root if isinstance(plugin_root, str) else self.root
        entries = self.data.get("plugins")
        seen: set = set()
        for index, entry in enumerate(entries if isinstance(entries, list) else []):
            if not isinstance(entry, dict) or not entry.get("name"):
                self.entry_problems.append(f"{MARKETPLACE}: plugin #{index + 1} has no name")
                continue
            if entry["name"] in seen:
                self.entry_problems.append(f"{MARKETPLACE} lists '{entry['name']}' more than once")
                continue
            seen.add(entry["name"])
            if not entry.get("source") and entry.get("source") != "":
                self.entry_problems.append(f"{MARKETPLACE}: plugin '{entry['name']}' has no source")
                continue
            self.plugins.append(Plugin(self.root, base, entry))

    @property
    def local(self) -> List[Plugin]:
        return [p for p in self.plugins if p.path is not None]

    def unreadable(self) -> List[str]:
        return [f"{MARKETPLACE} {self.problem}"]


def check_manifests(m: Marketplace) -> Result:
    if m.data is None:
        return False, m.unreadable()
    problems: List[str] = []
    if not isinstance(m.data.get("name"), str) or not m.data["name"].strip():
        problems.append(f"{MARKETPLACE} has no name")
    if not m.plugins and not m.entry_problems:
        problems.append(f"{MARKETPLACE} lists no plugins")
    problems += m.entry_problems
    for p in m.local:
        assert p.path is not None
        if not p.path.is_dir():
            problems.append(f"plugin '{p.name}': source folder {p.rel}/ does not exist")
        elif p.manifest_problem:
            problems.append(f"{p.manifest_rel} {p.manifest_problem}")
        elif p.manifest is None:
            # Without a plugin.json the marketplace entry must be the whole definition.
            if p.entry.get("strict") is not False:
                problems.append(f"plugin '{p.name}': {p.manifest_rel} not found")
        elif p.manifest.get("name") != p.name:
            problems.append(
                f"{p.manifest_rel} says '{p.manifest.get('name')}' "
                f"but the marketplace lists it as '{p.name}'"
            )
    listed = {p.path for p in m.local}
    for manifest in sorted((m.root / "plugins").glob("*/" + MANIFEST)):
        folder = manifest.parent.parent
        if folder.resolve() not in listed:
            problems.append(f"plugins/{folder.name} has a plugin.json but is not listed in {MARKETPLACE}")
    return not problems, problems


def check_versions(m: Marketplace, policy: Optional[str] = None) -> Result:
    if m.data is None:
        return None, m.unreadable()
    problems: List[str] = []
    effective: Dict[str, str] = {}
    for p in m.local:
        listed = p.entry.get("version")
        own = (p.manifest or {}).get("version")
        if listed is None and own is None:
            problems.append(f"plugin '{p.name}' states no version")
            continue
        if listed is not None and own is not None and listed != own:
            problems.append(f"plugin '{p.name}': the marketplace says {listed} but plugin.json says {own}")
        # Claude Code uses plugin.json when both are present.
        effective[p.name] = str(own if own is not None else listed)
    if (policy or versioning_policy(m.root)) != "independent" and len(set(effective.values())) > 1:
        listing = ", ".join(f"{name} {version}" for name, version in sorted(effective.items()))
        problems.append(
            f"plugins are at different versions ({listing}) and no independent versioning is declared"
        )
    return not problems, problems


def check_sources(m: Marketplace) -> Result:
    if m.data is None:
        return None, m.unreadable()
    problems: List[str] = []
    for p in m.plugins:
        if not p.local:
            continue
        if p.path is None:
            problems.append(f"plugin '{p.name}': source {p.source!r} points outside the repository")
        elif p.path == m.root:
            problems.append(
                f"plugin '{p.name}' uses the repository root as its source ({p.source!r}): "
                "every install copies the whole repository"
            )
    return not problems, problems


def check_descriptions(m: Marketplace, max_chars: int = MAX_DESCRIPTION) -> Result:
    if m.data is None:
        return None, m.unreadable()
    metadata = m.data.get("metadata")
    own = m.data.get("description") or (metadata.get("description") if isinstance(metadata, dict) else None)
    texts: List[Tuple[str, Any]] = [(MARKETPLACE, own)]
    for p in m.plugins:
        texts.append((f"marketplace entry '{p.name}'", p.entry.get("description")))
        if p.manifest:
            texts.append((p.manifest_rel, p.manifest.get("description")))
    problems = [
        f"{where}: description is {len(text):,} characters (limit {max_chars:,})"
        for where, text in texts
        if isinstance(text, str) and len(text) > max_chars
    ]
    return not problems, problems


PROBES: Dict[str, Callable[..., Result]] = {
    "manifests": check_manifests,
    "versions": check_versions,
    "sources": check_sources,
    "descriptions": check_descriptions,
}


def main(argv: Optional[List[str]] = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", default=str(Path(__file__).resolve().parent.parent),
                    help="Repository root (default: the folder above tools/)")
    ap.add_argument("--max-description", type=int, default=MAX_DESCRIPTION, metavar="N")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)

    m = Marketplace(Path(args.root))
    results: Dict[str, Result] = {}
    for name, probe in PROBES.items():
        results[name] = probe(m, max_chars=args.max_description) if name == "descriptions" else probe(m)
    failed = {name: problems for name, (ok, problems) in results.items() if ok is False}

    if args.json:
        print(json.dumps({
            "ok": not failed,
            "plugins": [p.name for p in m.plugins],
            "checks": {name: {"ok": ok, "problems": problems} for name, (ok, problems) in results.items()},
        }, indent=2, ensure_ascii=False))
    elif failed:
        count = sum(len(problems) for problems in failed.values())
        print(f"plugin-lint: {count} problem(s)", file=sys.stderr)
        for name, problems in failed.items():
            for problem in problems:
                print(f"  [{name}] {problem}", file=sys.stderr)
    else:
        print(f"plugin-lint: OK ({len(m.plugins)} plugin(s))")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
