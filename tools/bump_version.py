#!/usr/bin/env python3
"""Bump a plugin's version everywhere it is recorded.

  python3 tools/bump_version.py 0.3.0 [--plugin repo-setup]
  python3 tools/bump_version.py minor          # patch | minor | major

Updates plugins/<plugin>/.claude-plugin/plugin.json, the plugin's entry in
.claude-plugin/marketplace.json, and adds a "## <version> — <date>" section to CHANGELOG.md
(if it is not there yet). Then commit and tag: git tag <plugin>-v<version>.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SEMVER = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")


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


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("version", help="new version, or patch | minor | major")
    ap.add_argument("--plugin", default="repo-setup")
    args = ap.parse_args()

    plugin_file = ROOT / "plugins" / args.plugin / ".claude-plugin" / "plugin.json"
    market_file = ROOT / ".claude-plugin" / "marketplace.json"
    plugin = json.loads(plugin_file.read_text())
    current = plugin.get("version", "0.0.0")
    new = next_version(current, args.version) if args.version in ("patch", "minor", "major") else args.version
    if not SEMVER.match(new):
        raise SystemExit(f"{new!r} is not MAJOR.MINOR.PATCH")

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
    if f"## {new}" not in text:
        head, sep, rest = text.partition("\n## ")
        section = f"\n## {new} — {dt.date.today().isoformat()}\n\n- \n"
        text = head.rstrip("\n") + "\n" + section + (("\n## " + rest) if sep else "")
        changelog.write_text(text)

    print(f"{args.plugin}: {current} -> {new}")
    print(f"Next: fill in CHANGELOG.md, commit, then: git tag {args.plugin}-v{new}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
