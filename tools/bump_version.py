#!/usr/bin/env python3
"""Bump a plugin's version everywhere it is recorded.

  python3 tools/bump_version.py 0.3.0 [--plugin repo-setup]
  python3 tools/bump_version.py minor          # patch | minor | major
  python3 tools/bump_version.py dev            # right after a release: 0.10.2 -> 0.10.3.dev0

Updates plugins/<plugin>/.claude-plugin/plugin.json and the plugin's entry in
.claude-plugin/marketplace.json. A release adds a "## <version> — <date>" section to CHANGELOG.md
(if it is not there yet); then commit and tag: git tag <plugin>-v<version>.

A build between two tags carries X.Y.Z.devN, the release it leads to: `dev` sets it right after
a release (and counts N up after that), so a repository set up from the default branch never
names a release that does not hold what it got. From a dev version, `patch` releases X.Y.Z
itself; `minor` and `major` count from it. A dev version gets no changelog section and no tag.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SEMVER = re.compile(r"^(\d+)\.(\d+)\.(\d+)(?:\.dev(\d+))?$")
PARTS = ("patch", "minor", "major", "dev")


def next_version(current: str, part: str) -> str:
    m = SEMVER.match(current)
    if not m:
        raise SystemExit(f"current version {current!r} is not MAJOR.MINOR.PATCH[.devN]")
    major, minor, patch = map(int, m.groups()[:3])
    dev = m.group(4)
    if part == "dev":
        # after a release: the next patch, first build; between tags: the next build
        if dev:
            return f"{major}.{minor}.{patch}.dev{int(dev) + 1}"
        return f"{major}.{minor}.{patch + 1}.dev0"
    if part == "major":
        return f"{major + 1}.0.0"
    if part == "minor":
        return f"{major}.{minor + 1}.0"
    # a dev build leads to its own X.Y.Z
    return f"{major}.{minor}.{patch}" if dev else f"{major}.{minor}.{patch + 1}"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("version", help="new version, or patch | minor | major | dev")
    ap.add_argument("--plugin", default="repo-setup")
    args = ap.parse_args()

    plugin_file = ROOT / "plugins" / args.plugin / ".claude-plugin" / "plugin.json"
    market_file = ROOT / ".claude-plugin" / "marketplace.json"
    plugin = json.loads(plugin_file.read_text())
    current = plugin.get("version", "0.0.0")
    new = next_version(current, args.version) if args.version in PARTS else args.version
    if not SEMVER.match(new):
        raise SystemExit(f"{new!r} is not MAJOR.MINOR.PATCH[.devN]")
    release = SEMVER.match(new).group(4) is None

    plugin["version"] = new
    plugin_file.write_text(json.dumps(plugin, indent=2, ensure_ascii=False) + "\n")

    market = json.loads(market_file.read_text())
    entries = [p for p in market.get("plugins", []) if p.get("name") == args.plugin]
    if not entries:
        raise SystemExit(f"plugin {args.plugin!r} not found in marketplace.json")
    for entry in entries:
        entry["version"] = new
    market_file.write_text(json.dumps(market, indent=2, ensure_ascii=False) + "\n")

    changelog = ROOT / "CHANGELOG.md"
    text = changelog.read_text() if changelog.exists() else "# Changelog\n"
    if release and f"## {new}" not in text:
        head, sep, rest = text.partition("\n## ")
        section = f"\n## {new} — {dt.date.today().isoformat()}\n\n- \n"
        text = head.rstrip("\n") + "\n" + section + (("\n## " + rest) if sep else "")
        changelog.write_text(text)

    print(f"{args.plugin}: {current} -> {new}")
    if release:
        print(f"Next: fill in CHANGELOG.md, commit, then: git tag {args.plugin}-v{new}")
    else:
        print("A build between two tags: no changelog section and no tag.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
