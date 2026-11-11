#!/usr/bin/env bash
# Offline tests for this plugin repository. `make test` and CI run them.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

# 1. The marketplace and every plugin manifest are valid and agree with each other.
python3 "$ROOT/tools/plugin_lint.py" --root "$ROOT" >/dev/null || fail "plugin manifests (see: make lint)"
echo "ok  manifests"

# 2. Every skill has front matter with a description and a name that matches its folder.
count=0
for skill in "$ROOT"/plugins/*/skills/*/SKILL.md; do
  [ -f "$skill" ] || continue
  folder="$(basename "$(dirname "$skill")")"
  [ "$(head -1 "$skill")" = "---" ] || fail "$skill: no front matter"
  front="$(sed -n '2,/^---$/p' "$skill")"
  echo "$front" | grep -q "^name: $folder\$" || fail "$skill: name must be '$folder'"
  echo "$front" | grep -q '^description: .' || fail "$skill: no description"
  count=$((count + 1))
done
[ "$count" -gt 0 ] || fail "no skills found under plugins/*/skills/"
echo "ok  $count skill(s)"

# 3. A version bump updates every manifest and the changelog (tried on a copy).
cp -R "$ROOT/.claude-plugin" "$ROOT/plugins" "$ROOT/tools" "$ROOT/CHANGELOG.md" "$TMP/"
python3 "$TMP/tools/bump_version.py" 99.0.0 >/dev/null || fail "version bump"
python3 "$TMP/tools/plugin_lint.py" >/dev/null || fail "manifests disagree after a version bump"
grep -q '^## 99\.0\.0 ' "$TMP/CHANGELOG.md" || fail "version bump did not update CHANGELOG.md"
echo "ok  version bump"

echo "All tests passed."
