#!/usr/bin/env bash
# End-to-end: apply each preset at team level, run its real install + verify commands,
# and require doctor = 100. Needs network, node/npm, uv and pre-commit. Run before a release.
#   bash tests/e2e.sh            # all presets
#   SKIP=gitleaks bash tests/e2e.sh   # if the gitleaks hook cannot be built offline
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
S="$ROOT/plugins/repo-setup/scripts"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ALL=$(python3 "$S/apply.py" --list-presets --json | python3 -c "import json,sys; print(' '.join(json.load(sys.stdin)))")
# Combinations: stack:archetype:deploy:capabilities
COMBOS="ts-api:service-api:container fastapi:service-api:container ts-node:modular-monolith:none:mcp python:modular-monolith:none:mcp"
for spec in ${PRESETS:-$ALL $COMBOS}; do
  IFS=: read -r preset arch dep cap <<<"$spec"
  extra=(--archetype "${arch:-none}" --deploy "${dep:-none}")
  [ -n "$cap" ] && extra+=(--with "$cap")
  d="$TMP/${spec//:/-}"; mkdir -p "$d"; cd "$d"; git init -q -b main
  out=$(python3 "$S/apply.py" --preset "$preset" "${extra[@]}" --level team \
        --var "project_name=Coffee Shop" --var "description=E2E test" --var owner=acme --json)
  install=$(python3 -c 'import json,sys;[print(c) for c in json.load(sys.stdin)["next_commands"]["install"]]' <<<"$out")
  verify=$(python3 -c 'import json,sys;[print(c) for c in json.load(sys.stdin)["next_commands"]["verify"]]' <<<"$out")
  while IFS= read -r c; do [ -z "$c" ] || { echo "[$spec] \$ $c"; bash -c "$c" >/dev/null </dev/null; }; done <<<"$install"
  git add -A
  while IFS= read -r c; do [ -z "$c" ] || { echo "[$spec] \$ $c"; bash -c "$c" </dev/null; }; done <<<"$verify"
  python3 "$S/doctor.py" --min-score 100
  # commit-msg hook: bad message rejected, conventional message accepted
  if git -c user.name=e2e -c user.email=e2e@example.com commit -qm "initial setup" >/dev/null 2>&1; then
    echo "FAIL: non-conventional commit message was accepted"; exit 1
  fi
  git -c user.name=e2e -c user.email=e2e@example.com commit -qm "chore: initial setup" >/dev/null
  echo "ok  $spec"
done
echo "E2E passed."
