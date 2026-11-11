#!/usr/bin/env python3
"""Bump plugin versions everywhere they are recorded.

  python3 tools/bump_version.py minor                # patch | minor | major: every plugin together
  python3 tools/bump_version.py 1.4.0                # an explicit version
  python3 tools/bump_version.py patch --plugin NAME  # one plugin (independent versioning)
  python3 tools/bump_version.py minor --dry-run      # show what would change
  python3 tools/bump_version.py --notes 1.4.0        # print that version's CHANGELOG section

Updates each plugin's .claude-plugin/plugin.json and its entry in .claude-plugin/marketplace.json
(the entry only where it already states a version, or the plugin has no plugin.json), and turns
"## Unreleased" in CHANGELOG.md into "## <version> — <date>". Then commit and tag: git tag v<version>.

Standard library only (Python 3.8+).
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

MARKETPLACE = ".claude-plugin/marketplace.json"
MANIFEST = ".claude-plugin/plugin.json"
SEMVER = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")
PARTS = ("patch", "minor", "major")
UNRELEASED = "## Unreleased"


def next_version(current: str, part: str) -> str:
    m = SEMVER.match(current)
    if not m:
        raise SystemExit(f"current version {current!r} is not MAJOR.MINOR.PATCH")
    major, minor, patch = map(int, m.groups())
    if part == "major":
        return f"{major + 1}.0.0"
    if part == "minor":
        return f"{major}.{minor + 1}.0"
    return f"{major}.{minor}.{patch + 1}"


def load(path: Path) -> Dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise SystemExit(f"{path}: {exc}")
    if not isinstance(data, dict):
        raise SystemExit(f"{path}: must be a JSON object")
    return data


def dump(path: Path, data: Dict[str, Any]) -> None:
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def independent(root: Path) -> bool:
    try:
        setup = json.loads((root / ".repo-setup.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return False
    return ((setup.get("vars") or {}) if isinstance(setup, dict) else {}).get("plugin_versioning") == "independent"


def notes(changelog: Path, version: str) -> str:
    """The body of the "## <version>" section, or of "## <plugin> <version>"."""
    text = changelog.read_text(encoding="utf-8") if changelog.exists() else ""
    heading = re.compile(rf"^## (?:\S+ )?{re.escape(version)}(?:\s|$)")
    body: Optional[List[str]] = None
    for line in text.splitlines():
        if line.startswith("## "):
            if body is not None:
                break
            if heading.match(line):
                body = []
        elif body is not None:
            body.append(line)
    if body is None:
        raise SystemExit(f"CHANGELOG.md has no section for {version}")
    return "\n".join(body).strip() + "\n"


def release_changelog(changelog: Path, title: str, today: str) -> str:
    """Turn the Unreleased section into this release; add an empty section if there is none."""
    text = changelog.read_text(encoding="utf-8") if changelog.exists() else "# Changelog\n"
    heading = f"## {title} — {today}"
    if f"## {title}" in text:
        return text
    lines = text.splitlines()
    if UNRELEASED in lines:
        at = lines.index(UNRELEASED)
        lines[at:at + 1] = [UNRELEASED, "", heading]
        return "\n".join(lines) + "\n"
    head, sep, rest = text.partition("\n## ")
    return head.rstrip("\n") + f"\n\n{heading}\n\n- \n" + (("\n## " + rest) if sep else "")


def main(argv: Optional[List[str]] = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("version", nargs="?", help="new version, or patch | minor | major")
    ap.add_argument("--plugin", default=None, help="bump only this plugin")
    ap.add_argument("--notes", metavar="VERSION", help="print the CHANGELOG section of VERSION and exit")
    ap.add_argument("--dry-run", action="store_true", help="show the changes, write nothing")
    ap.add_argument("--root", default=str(Path(__file__).resolve().parent.parent),
                    help="repository root (default: the folder above tools/)")
    args = ap.parse_args(argv)
    root = Path(args.root).resolve()
    changelog = root / "CHANGELOG.md"

    if args.notes:
        sys.stdout.write(notes(changelog, args.notes))
        return 0
    if not args.version:
        ap.error("give a version, or patch | minor | major")

    market_file = root / MARKETPLACE
    market = load(market_file)
    # (marketplace entry, plugin.json path or None, plugin.json data or None)
    found: List[Tuple[Dict[str, Any], Optional[Path], Optional[Dict[str, Any]]]] = []
    metadata = market.get("metadata")
    plugin_root = metadata.get("pluginRoot") if isinstance(metadata, dict) else None
    base = root / plugin_root if isinstance(plugin_root, str) else root
    for entry in market.get("plugins") or []:
        if not isinstance(entry, dict) or not isinstance(entry.get("source"), str):
            continue  # hosted elsewhere: its version lives in its own repository
        manifest = (base / entry["source"] / MANIFEST).resolve()
        found.append((entry, manifest, load(manifest)) if manifest.is_file() else (entry, None, None))
    if args.plugin:
        targets = [t for t in found if t[0].get("name") == args.plugin]
        if not targets:
            raise SystemExit(f"plugin {args.plugin!r} is not a local plugin in {MARKETPLACE}")
    else:
        targets = found
        if not targets:
            raise SystemExit(f"{MARKETPLACE} lists no local plugins")
        if len(targets) > 1 and independent(root):
            raise SystemExit("this repository versions its plugins independently: pass --plugin NAME")

    def current(entry: Dict[str, Any], data: Optional[Dict[str, Any]]) -> str:
        return str((data or {}).get("version") or entry.get("version") or "0.0.0")

    versions = {str(entry.get("name")): current(entry, data) for entry, _, data in targets}
    if args.version in PARTS:
        if len(set(versions.values())) > 1:
            listing = ", ".join(f"{name} {version}" for name, version in sorted(versions.items()))
            raise SystemExit(f"plugins are at different versions ({listing}): "
                             "pass an explicit version, or --plugin NAME")
        new = next_version(next(iter(versions.values())), args.version)
    else:
        new = args.version
    if not SEMVER.match(new):
        raise SystemExit(f"{new!r} is not MAJOR.MINOR.PATCH")

    for entry, manifest, data in targets:
        print(f"{entry.get('name')}: {current(entry, data)} -> {new}")
        if data is not None and manifest is not None:
            data["version"] = new
            if not args.dry_run:
                dump(manifest, data)
        if "version" in entry or data is None:
            entry["version"] = new
    single = args.plugin and len(found) > 1
    title = f"{args.plugin} {new}" if single else new
    tag = f"{args.plugin}-v{new}" if single else f"v{new}"
    if args.dry_run:
        print("Dry run: nothing written.")
        return 0
    dump(market_file, market)
    changelog.write_text(release_changelog(changelog, title, dt.date.today().isoformat()), encoding="utf-8")
    print(f"Next: check CHANGELOG.md, commit, then: git tag {tag}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
