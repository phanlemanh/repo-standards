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

# pre-commit refuses to install while a global core.hooksPath is set. Leave that setting alone:
# skip the install and run the commit-msg stage directly.
HOOKS_PATH="$(git config core.hooksPath || true)"
if ! command -v pre-commit >/dev/null; then
  mkdir -p "$TMP/bin"
  printf '#!/bin/sh\nexec uvx pre-commit "$@"\n' > "$TMP/bin/pre-commit"; chmod +x "$TMP/bin/pre-commit"
  PATH="$TMP/bin:$PATH"
fi

ALL=$(python3 "$S/apply.py" --list-presets --json | python3 -c "import json,sys; print(' '.join(json.load(sys.stdin)))")
# Combinations: stack:archetype:deploy:capabilities:ai_tier
COMBOS="ts-api:service-api:container:github-agents fastapi:service-api:container ts-node:modular-monolith:none:mcp python:modular-monolith:none:mcp python:none:none:github-agents python:none:none:ai:call ts-node:none:none:ai:call"
for spec in ${PRESETS:-$ALL $COMBOS}; do
  IFS=: read -r preset arch dep cap tier <<<"$spec"
  extra=(--archetype "${arch:-none}" --deploy "${dep:-none}")
  [ -n "$cap" ] && extra+=(--with "$cap")
  [ -n "$tier" ] && extra+=(--var "ai_tier=$tier")
  d="$TMP/${spec//:/-}"; mkdir -p "$d"; cd "$d"; git init -q -b main
  out=$(python3 "$S/apply.py" --preset "$preset" "${extra[@]}" --level team \
        --var "project_name=Coffee Shop" --var "description=E2E test" --var owner=acme --json)
  install=$(python3 -c 'import json,sys;[print(c) for c in json.load(sys.stdin)["next_commands"]["install"]]' <<<"$out")
  verify=$(python3 -c 'import json,sys;[print(c) for c in json.load(sys.stdin)["next_commands"]["verify"]]' <<<"$out")
  while IFS= read -r c; do
    case "$c" in "") continue ;; *"pre-commit install"*) [ -z "$HOOKS_PATH" ] || continue ;; esac
    echo "[$spec] \$ $c"; bash -c "$c" >/dev/null </dev/null
  done <<<"$install"
  git add -A
  while IFS= read -r c; do [ -z "$c" ] || { echo "[$spec] \$ $c"; bash -c "$c" </dev/null; }; done <<<"$verify"
  python3 "$S/doctor.py" --min-score 100
  case ",$cap," in *,ai,*)
    env -u ANTHROPIC_API_KEY make check >/dev/null || { echo "FAIL: make check needs an API key"; exit 1; }
    if env -u ANTHROPIC_API_KEY make eval >/dev/null 2>&1; then echo "FAIL: make eval ran without a key"; exit 1; fi
    ;;
  esac
  # commit-msg hook: bad message rejected, conventional message accepted
  if [ -n "$HOOKS_PATH" ]; then
    echo "initial setup" > "$TMP/msg"
    if pre-commit run --hook-stage commit-msg --commit-msg-filename "$TMP/msg" >/dev/null 2>&1; then
      echo "FAIL: non-conventional commit message was accepted"; exit 1
    fi
    echo "chore: initial setup" > "$TMP/msg"
    pre-commit run --hook-stage commit-msg --commit-msg-filename "$TMP/msg" >/dev/null
  elif git -c user.name=e2e -c user.email=e2e@example.com commit -qm "initial setup" >/dev/null 2>&1; then
    echo "FAIL: non-conventional commit message was accepted"; exit 1
  fi
  git -c user.name=e2e -c user.email=e2e@example.com commit -qm "chore: initial setup" >/dev/null
  echo "ok  $spec"
done
echo "E2E passed."
