#!/usr/bin/env bash
# Fast offline tests for the repo-setup scripts (no dependency installs).
# Full end-to-end verification (real installs + make check + pre-commit): tests/e2e.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
S="$ROOT/plugins/repo-setup/scripts"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
json() { python3 -c "import json,sys; d=json.load(sys.stdin); print($1)"; }
# Portable in-place edit: `sed -i` differs between GNU and BSD (macOS).
subst() { sed "$1" "$2" > "$2.tmp" && mv "$2.tmp" "$2"; }
# Regression checks report every miss before the run fails.
misses=0
miss() { echo "FAIL: $*" >&2; misses=$((misses + 1)); }

PRESETS=$(python3 "$S/apply.py" --list-presets --json | python3 -c "import json,sys; print(' '.join(json.load(sys.stdin)))")
for preset in $PRESETS; do
  for level in starter team; do
    d="$TMP/$preset-$level"
    mkdir -p "$d" && git -C "$d" init -q -b main

    # 1. dry run writes nothing
    python3 "$S/apply.py" --target "$d" --preset "$preset" --level "$level" \
      --var 'project_name=Coffee "Shop"' --var 'description=Orders \ loyalty' --var owner=acme --dry-run --json >/dev/null
    [ -z "$(ls -A "$d" | grep -v '^.git$' || true)" ] || fail "$preset/$level: dry run wrote files"

    # 2. apply creates files, no unrendered placeholders
    created=$(python3 "$S/apply.py" --target "$d" --preset "$preset" --level "$level" \
      --var 'project_name=Coffee "Shop"' --var 'description=Orders \ loyalty' --var owner=acme --json | json 'len(d["created"])')
    [ "$created" -gt 20 ] || fail "$preset/$level: only $created files created"
    if grep -rIlE --exclude-dir=.git --exclude-dir=workflows '\{\{ *[a-z_]+ *\}\}' "$d" ; then fail "$preset/$level: unrendered placeholder"; fi

    # 3. generated JSON/TOML stay valid even with quotes and backslashes in vars
    python3 - "$d" <<'PY'
import json, sys, tomllib, pathlib
root = pathlib.Path(sys.argv[1])
for p in root.rglob("*.json"):
    json.loads(p.read_text())
for p in root.rglob("*.toml"):
    tomllib.loads(p.read_text())
PY

    # 4. second run is a no-op
    again=$(python3 "$S/apply.py" --target "$d" --json | json 'len(d["created"])+len(d["updated"])+len(d["conflict"])')
    [ "$again" -eq 0 ] || fail "$preset/$level: second run changed $again files"

    # 5. user edits are never overwritten
    echo "my note" >> "$d/README.md"
    conflict=$(python3 "$S/apply.py" --target "$d" --json | json '"README.md" in d["conflict"]')
    [ "$conflict" = "True" ] || fail "$preset/$level: edited README not reported as conflict"
    grep -q "my note" "$d/README.md" || fail "$preset/$level: README was overwritten"

    # 6. doctor: everything except the lockfile (needs an install) passes
    git -C "$d" add -A
    failed=$(python3 "$S/doctor.py" --target "$d" --level "$level" --json | json '",".join(sorted(r["id"] for r in d["failed"]))')
    [ "$failed" = "lockfile" ] || fail "$preset/$level: unexpected doctor failures: $failed"

    # 6b. bytecode from the vendored Python tools never reaches a commit
    git -C "$d" check-ignore -q tools/__pycache__/x.pyc || miss "$preset/$level: tools/__pycache__ is not ignored"

    # 6c. sample config has no credential-shaped values: secret scanners would block the first commit
    if grep -qE '://[^/[:space:]]+:[^@[:space:]]+@' "$d/.env.example"; then miss "$preset/$level: .env.example has credentials in a URL"; fi

    echo "ok  $preset/$level"
  done
done

# 7. starter -> team upgrade adds team files only
d="$TMP/upgrade"; mkdir -p "$d"
python3 "$S/apply.py" --target "$d" --preset python --var project_name=Up --var description=x --var owner=acme >/dev/null
added=$(python3 "$S/apply.py" --target "$d" --level team --json | json 'len(d["created"])')
[ "$added" -ge 10 ] || fail "upgrade added only $added files"
level=$(python3 -c "import json;print(json.load(open('$d/.repo-setup.json'))['level'])")
[ "$level" = "team" ] || fail "manifest level not upgraded"
echo "ok  upgrade starter -> team"

# 8. doctor on an empty folder scores 0 and --min-score fails
e="$TMP/empty"; mkdir -p "$e"
if python3 "$S/doctor.py" --target "$e" --min-score 50 >/dev/null; then fail "min-score did not fail"; fi
echo "ok  doctor --min-score"

# 9. adopt mode on an existing codebase
a="$TMP/legacy"; mkdir -p "$a/src" "$a/.github/workflows" && git -C "$a" init -q -b main
printf '{"name":"legacy","scripts":{"test":"jest"}}\n' > "$a/package.json"
printf '{"extends":"eslint:recommended"}\n' > "$a/.eslintrc.json"
printf '# Legacy\n' > "$a/README.md"
printf 'node_modules/\n' > "$a/.gitignore"
printf 'export const a = 1;\n' > "$a/src/app.ts"
printf 'name: test\n' > "$a/.github/workflows/test.yml"
out=$(python3 "$S/apply.py" --target "$a" --preset ts-node --level team --adopt \
  --var project_name=Legacy --var description=x --var owner=acme --json)
check() { python3 -c "import json,sys; d=json.loads(sys.argv[1]); assert $2, sys.argv[2]" "$out" "$1" || fail "adopt: $1"; }
check "'eslint.config.js' in d['skipped']" "'eslint.config.js' in d['skipped']"
check "'.github/workflows/ci.yml' in d['skipped']" "'.github/workflows/ci.yml' in d['skipped']"
check "'src/greet.ts' in d['skipped']" "'src/greet.ts' in d['skipped']"
check "'README.md' in d['conflict']" "'README.md' in d['conflict']"
check "'.gitignore' in d['merged']" "'.gitignore' in d['merged']"
check "'package.json' in d['kept']" "'package.json' in d['kept']"
check "'AGENTS.md' in d['created'] and 'ontology/glossary.md' in d['created']" "'AGENTS.md' in d['created'] and 'ontology/glossary.md' in d['created']"
grep -q '^node_modules/$' "$a/.gitignore" && grep -q '^\.env$' "$a/.gitignore" || fail "adopt: .gitignore not merged"
[ "$(grep -c '^\.env$' "$a/.gitignore")" = 1 ] || fail "adopt: duplicate lines"
again=$(python3 "$S/apply.py" --target "$a" --json | json 'len(d["created"])+len(d["merged"])')
[ "$again" -eq 0 ] || fail "adopt: second run changed $again files"
[ ! -e "$a/src/greet.ts" ] || fail "adopt: sample code added"
echo "ok  adopt mode"

# 10. license variants
for lic in MIT Apache-2.0 Proprietary; do
  l="$TMP/lic-$lic"; mkdir -p "$l"
  python3 "$S/apply.py" --target "$l" --preset ts-node --var project_name=L --var description=x --var owner=acme --var license=$lic >/dev/null
  case $lic in
    MIT) grep -q "MIT License" "$l/LICENSE" && grep -q '"license": "MIT"' "$l/package.json" ;;
    Apache-2.0) grep -q "Apache License" "$l/LICENSE" && grep -q '"license": "Apache-2.0"' "$l/package.json" ;;
    Proprietary) grep -q "All rights reserved" "$l/LICENSE" && grep -q '"license": "UNLICENSED"' "$l/package.json" ;;
  esac || fail "license $lic"
  [ "$(ls "$l" | grep -c '^\[')" = 0 ] || fail "license $lic: condition folder leaked"
done
if python3 "$S/apply.py" --target "$TMP/lic-bad" --preset python --var project_name=L --var description=x --var owner=acme --var license=GPL >/dev/null 2>&1; then fail "bad license accepted"; fi
echo "ok  license variants"

# 11. ontology tools: wiki-lint + codegen on a sample domain (no installs needed)
o="$TMP/onto"; mkdir -p "$o" && git -C "$o" init -q -b main
python3 "$S/apply.py" --target "$o" --preset ts-node --var project_name=Onto --var description=x --var owner=acme >/dev/null
python3 "$ROOT/tests/apply_fixture.py" coffee "$o" >/dev/null
( cd "$o" && python3 tools/wiki_lint.py >/dev/null ) || fail "wiki-lint failed on fixture"
( cd "$o" && python3 tools/ontology_codegen.py --lang ts --out src/generated/ontology.ts >/dev/null \
  && python3 tools/ontology_codegen.py --lang python --out gen/ontology_types.py >/dev/null )
grep -q 'export function isVIPCustomer(e: Customer): boolean' "$o/src/generated/ontology.ts" || fail "codegen ts predicate"
grep -q 'e.points >= 100 && e.status === "active"' "$o/src/generated/ontology.ts" || fail "codegen ts rule"
grep -q 'def is_vip_customer(e: Customer) -> bool:' "$o/gen/ontology_types.py" || fail "codegen py predicate"
grep -q 'predicate not generated (property .phone. is optional)' "$o/gen/ontology_types.py" || fail "codegen optional guard"
python3 -c "import ast,sys; ast.parse(open('$o/gen/ontology_types.py').read())" || fail "codegen py syntax"
( cd "$o" && python3 tools/ontology_codegen.py --lang ts --out src/generated/ontology.ts --check >/dev/null ) || fail "codegen --check fresh"
subst 's/points >= 100/points >= 150/' "$o/ontology/entities/Customer.yaml"
if ( cd "$o" && python3 tools/ontology_codegen.py --lang ts --out src/generated/ontology.ts --check >/dev/null 2>&1 ); then fail "codegen drift not detected"; fi
subst 's/target: Customer/target: Client/' "$o/ontology/entities/Order.yaml"
if ( cd "$o" && python3 tools/wiki_lint.py >/dev/null ); then fail "wiki-lint missed unknown ref"; fi
subst 's/target: Client/target: Customer/' "$o/ontology/entities/Order.yaml"
printf -- '---\ntype: decision\ntitle: Bad\n---\n# x\n' > "$o/wiki/decisions/bad.md"
errs=$( cd "$o" && { python3 tools/wiki_lint.py --json || true; } | json 'len(d["errors"])' )
[ "$errs" -ge 3 ] || fail "wiki-lint: bad decision page gave only $errs errors"
echo "ok  ontology tools (wiki-lint, codegen)"

# 12. hooks: silent outside repo-setup repos; SessionStart adds context inside
H="$ROOT/plugins/repo-setup/scripts"
[ -z "$(echo '{"cwd":"'"$TMP"'"}' | python3 "$H/hook_stop.py")" ] || fail "stop hook not silent outside"
[ -z "$(echo '{"cwd":"'"$TMP"'"}' | python3 "$H/hook_session_start.py")" ] || fail "session hook not silent outside"
echo '{"cwd":"'"$o"'"}' | python3 "$H/hook_session_start.py" | json '"wiki/index.md" in d["hookSpecificOutput"]["additionalContext"]' | grep -q True || fail "session context"
python3 -c "import json; json.load(open('$ROOT/plugins/repo-setup/hooks/hooks.json'))" || fail "hooks.json"
echo "ok  hooks"

# 13. archetype / deploy / capability combinations (offline: generate code with the tools)
for combo in "ts-api:service-api:container" "fastapi:service-api:container" "python:modular-monolith:none" "ts-node:modular-monolith:none:mcp" "python:none:none:mcp"; do
  IFS=: read -r stack arch dep cap <<<"$combo"
  c="$TMP/combo-${stack}-${arch}-${dep}-${cap:-x}"; mkdir -p "$c" && git -C "$c" init -q -b main
  python3 "$S/apply.py" --target "$c" --preset "$stack" --archetype "$arch" --deploy "$dep" --with "github-agents${cap:+,$cap}" --level team \
    --var project_name=Combo --var description=x --var owner=acme/platform >/dev/null || fail "$combo: apply"
  ( cd "$c"
    lang=$(python3 -c "import json; print(json.load(open('.repo-setup.json'))['preset'])")
    case "$stack" in ts-*|react-*) python3 tools/ontology_codegen.py --lang ts --out src/generated/ontology.ts >/dev/null ;;
      *) python3 tools/ontology_codegen.py --lang python --out src/combo/ontology_types.py >/dev/null ;; esac
    [ -f tools/openapi_gen.py ] && python3 tools/openapi_gen.py >/dev/null
    git add -A ) || fail "$combo: generate"
  failed=$(python3 "$S/doctor.py" --target "$c" --json | json '",".join(sorted(r["id"] for r in d["failed"]))')
  [ "$failed" = "lockfile" ] || fail "$combo: unexpected doctor failures: $failed"
  grep -q "## AI-native SDLC" "$c/AGENTS.md" || fail "$combo: SDLC section missing from AGENTS.md"
  case "$arch" in
    service-api) grep -q "## Architecture: Service API" "$c/AGENTS.md" && [ -f "$c/contracts/openapi.json" ] || fail "$combo: service-api parts" ;;
    modular-monolith) grep -q "## Architecture: modular monolith" "$c/AGENTS.md" && [ -f "$c/architecture/modules.yaml" ] || fail "$combo: monolith parts" ;;
  esac
  if [ "$dep" = container ]; then grep -q "^USER " "$c/Dockerfile" && grep -q "ghcr.io/acme" "$c/mk/deploy.mk" || fail "$combo: container"; fi
  if [ "$arch" = service-api ] || [ "$cap" = mcp ]; then [ -f "$c/.mcp.json" ] || fail "$combo: .mcp.json"; fi
  echo "ok  combo $combo"
done
if python3 "$S/apply.py" --target "$TMP/bad-combo" --preset react-vite --archetype service-api --var project_name=B --var description=x --var owner=a >/dev/null 2>&1; then fail "incompatible combo accepted"; fi
echo "ok  incompatible combination rejected"

# 14. module boundaries catch violations
b="$TMP/combo-python-modular-monolith-none-x"
printf 'from coffee_bad import x\nfrom ..loyalty import points_for\n' >> "$b/src/combo/modules/sales/pricing.py"
if ( cd "$b" && python3 tools/boundaries.py >/dev/null ); then fail "boundaries missed a forbidden dependency"; fi
echo "ok  module boundaries"

# 15. API breaking-change detection
a="$TMP/combo-fastapi-service-api-container-x"
cp "$a/contracts/openapi.json" "$TMP/old.json"
python3 - "$TMP/old.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["paths"]["/v1/actions/gone"] = {"post": {"operationId": "gone", "responses": {"200": {"description": "ok"}}}}
json.dump(d, open(p, "w"))
PY
if python3 "$a/tools/api_compat.py" --base "$TMP/old.json" --head "$a/contracts/openapi.json" >/dev/null 2>&1; then fail "api-compat missed a removed operation"; fi
python3 "$a/tools/api_compat.py" --base "$a/contracts/openapi.json" --head "$a/contracts/openapi.json" >/dev/null || fail "api-compat false positive"
echo "ok  api breaking-change detection"

# 16. autonomy tiers and the PreToolUse gate
g="$TMP/combo-ts-api-service-api-container-x"
tier=$(cd "$g" && python3 tools/autonomy.py --files wiki/log.md src/app.ts ontology/actions.yaml | json 'd["tier"]')
[ "$tier" = high ] || fail "autonomy tier: $tier"
low=$(cd "$g" && python3 tools/autonomy.py --files wiki/log.md docs/x.md | json 'd["tier"]')
[ "$low" = low ] || fail "autonomy low tier: $low"
( cd "$g" && python3 tools/autonomy.py --check-codeowners >/dev/null ) || fail "codeowners out of sync"
gate() { echo "{\"cwd\":\"$g\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$g/$1\"}}" | python3 "$H/hook_pretool_gate.py"; }
gate ontology/actions.yaml | grep -q '"permissionDecision": "ask"' || fail "gate did not ask for a high-tier file"
[ -z "$(gate src/app.ts)" ] || fail "gate asked for a medium-tier file"
approved=$(REPO_SETUP_APPROVAL=issue-1 gate ontology/actions.yaml)
[ -z "$approved" ] || fail "gate ignored approval"
echo "ok  autonomy tiers and edit gate"

# 17. tiers on real git history: renames, weakened tests, agent config, non-ASCII names
r="$TMP/tiers"; mkdir -p "$r/ontology" "$r/src" "$r/tests/a" "$r/wiki" "$r/docs"
git -C "$r" init -q -b main
seq 1 30 > "$r/ontology/x.yaml"
seq 1 30 > "$r/ontology/đơn.yaml"
seq 1 30 > "$r/src/app.ts"
seq 1 30 > "$r/tests/a/test_x.py"
seq 1 30 > "$r/tests/a/app.test.ts"
commit() { git -C "$r" add -A && git -C "$r" -c user.name=t -c user.email=t@example.com commit -qm "$1"; }
commit init
start() { git -C "$r" checkout -q -B "$1" main; }
expect_tier() {
  actual=$(python3 "$g/tools/autonomy.py" --root "$r" --policy "$g/governance/autonomy.yaml" --base main --head HEAD | json 'd["tier"]')
  [ "$actual" = "$2" ] || miss "tier of '$1': got $actual, want $2"
}
start c1; git -C "$r" mv ontology/x.yaml wiki/x.yaml; commit c1
expect_tier "high-tier file renamed into wiki/" high
start c2; git -C "$r" mv src/app.ts docs/app.ts; commit c2
expect_tier "source file renamed into docs/" medium
start c3; mkdir -p "$r/tests/b"; git -C "$r" mv tests/a/test_x.py tests/b/test_x.py; subst '$d' "$r/tests/b/test_x.py"; commit c3
expect_tier "test moved with a line removed" medium
start c4; printf 'describe.skip("off", () => {});\n' >> "$r/tests/a/app.test.ts"; commit c4
expect_tier "describe.skip added" medium
start c5; printf '@pytest.mark.skip\ndef test_y(): ...\n' >> "$r/tests/a/test_x.py"; commit c5
expect_tier "pytest skip marker added" medium
start c6; echo 'collect_ignore_glob = ["*"]' > "$r/tests/conftest.py"; commit c6
expect_tier "conftest.py added" high
start c7; mkdir -p "$r/docs"; echo x > "$r/docs/CLAUDE.md"; commit c7
expect_tier "nested CLAUDE.md" high
start c8; echo '{}' > "$r/tests/.mcp.json"; commit c8
expect_tier "nested .mcp.json" high
start c9; echo 31 >> "$r/ontology/đơn.yaml"; commit c9
expect_tier "non-ASCII high-tier path" high
start c10; mkdir -p "$r/docs"; echo x > "$r/docs/new.md"; printf 'def test_new(): ...\n' >> "$r/tests/a/test_x.py"; commit c10
expect_tier "plain docs and an added test" low
echo "ok  tiers on git history (or misses reported above)"

# 18. PreToolUse gate: fails closed, only in repo-setup repos, never runs the repo's code
expect_ask() { gate ontology/actions.yaml 2>/dev/null | grep -q '"permissionDecision": "ask"' || miss "gate did not ask: $1"; }
cp "$g/governance/autonomy.yaml" "$TMP/policy.bak"
printf ': : : [\n' > "$g/governance/autonomy.yaml"; expect_ask "malformed policy"
: > "$g/governance/autonomy.yaml"; expect_ask "empty policy"
printf 'version: 1\n' > "$g/governance/autonomy.yaml"; expect_ask "policy without high paths"
cp "$TMP/policy.bak" "$g/governance/autonomy.yaml"
planted() {  # a repo whose tools/autonomy.py leaves a marker when it is executed
  mkdir -p "$1/governance" "$1/tools"
  cp "$g/governance/autonomy.yaml" "$1/governance/autonomy.yaml"
  printf 'open("%s","w").write("ran")\n' "$1/RAN" > "$1/tools/autonomy.py"
}
p1="$TMP/planted-no-manifest"; planted "$p1"
out=$(g="$p1" gate ontology/x.yaml)
[ -z "$out" ] || miss "gate spoke outside a repo-setup repo"
[ ! -e "$p1/RAN" ] || miss "gate ran tools/autonomy.py of a repo without .repo-setup.json"
p2="$TMP/planted-manifest"; planted "$p2"; echo '{}' > "$p2/.repo-setup.json"
out=$(g="$p2" gate ontology/x.yaml)
[ ! -e "$p2/RAN" ] || miss "gate ran tools/autonomy.py from the repository"
echo "$out" | grep -q '"permissionDecision": "ask"' || miss "gate did not classify with the plugin's own code"
echo "ok  edit gate safety (or misses reported above)"

# 19. Stop hook blocks on a red `make check`, also in a linked git worktree
w="$TMP/stop"; mkdir -p "$w/src"; git -C "$w" init -q -b main
echo '{}' > "$w/.repo-setup.json"; printf 'check:\n\t@echo boom; exit 1\n' > "$w/Makefile"; echo a > "$w/src/a.ts"
git -C "$w" add -A; git -C "$w" -c user.name=t -c user.email=t@example.com commit -qm init
git -C "$w" worktree add -q "$TMP/stop-wt" -b wt
stop_blocks() {
  echo x > "$1/src/new.ts"
  echo "{\"cwd\":\"$1\"}" | CLAUDE_PROJECT_DIR="$1" python3 "$H/hook_stop.py" 2>/dev/null | grep -q '"decision": "block"' || miss "stop hook did not block: $2"
}
stop_blocks "$w" "normal checkout"
stop_blocks "$TMP/stop-wt" "linked worktree"
echo "ok  stop hook (or misses reported above)"

# 20. `agent: forbidden` holds in can() itself, so every entry point honours it; lint rejects the mix
f="$TMP/forbidden"; mkdir -p "$f" && git -C "$f" init -q -b main
python3 "$S/apply.py" --target "$f" --preset python --var project_name=F --var description=x --var owner=acme >/dev/null
python3 "$ROOT/tests/apply_fixture.py" coffee "$f" >/dev/null
cat >> "$f/ontology/actions.yaml" <<'YAML'
  - name: wipeLoyalty
    description: Must never be run by an agent.
    entity: Customer
    kind: delete
    input:
      id: { type: uuid, required: true }
    roles: [manager, agent]
    agent: forbidden
YAML
if ( cd "$f" && python3 tools/wiki_lint.py >/dev/null 2>&1 ); then miss "wiki-lint accepted agent: forbidden with role agent"; fi
( cd "$f" && python3 tools/ontology_codegen.py --lang python --out gen/ontology_types.py >/dev/null \
  && python3 tools/ontology_codegen.py --lang ts --out src/generated/ontology.ts >/dev/null )
verdict=$(cd "$f/gen" && python3 -B -c "
import ontology_types as o
a = next(x for x in o.ACTIONS if x.name == 'wipeLoyalty')
print(o.can('agent', a), o.can('manager', a))")
[ "$verdict" = "False True" ] || miss "python can(): agent, manager on a forbidden action gave '$verdict'"
grep -q '=== "agent" && action.agent === "forbidden"' "$f/src/generated/ontology.ts" || miss "ts can() ignores agent: forbidden"
echo "ok  agent: forbidden (or misses reported above)"

# 21. doctor: a hollow policy or pipeline does not score, and a local score says it is local
h="$TMP/python-team-agents"; mkdir -p "$h" && git -C "$h" init -q -b main
python3 "$S/apply.py" --target "$h" --preset python --level team --with github-agents --var project_name=H --var description=x --var owner=acme >/dev/null
git -C "$h" add -A
local_only=$(python3 "$S/doctor.py" --target "$h" --json | json 'd.get("local_only")')
[ "$local_only" = True ] || miss "doctor does not flag a score without GitHub checks: $local_only"
python3 "$S/doctor.py" --target "$h" | grep -q 'GitHub protection was not checked' || miss "doctor text does not warn about local-only score"
printf 'high:\n  - nothing\n' > "$h/governance/autonomy.yaml"
printf 'on: push\n# claude-code-action test check\n' > "$h/.github/workflows/pr-pipeline.yml"
( cd "$h" && python3 tools/autonomy.py --write-codeowners >/dev/null; git add -A )
failed=$(python3 "$S/doctor.py" --target "$h" --json | json '",".join(sorted(r["id"] for r in d["failed"]))')
case ",$failed," in *,autonomy_policy,*) ;; *) miss "doctor accepted a hollow autonomy policy: $failed" ;; esac
case ",$failed," in *,agent_workflows,*) ;; *) miss "doctor accepted a hollow PR pipeline: $failed" ;; esac
echo "ok  doctor honesty (or misses reported above)"

# 22. gitleaks: manifest file hashes are allowed, narrowly; the config itself is high-tier
leak_cfg() {
  python3 - "$1/.gitleaks.toml" <<'PY'
import re, sys, tomllib
cfg = tomllib.load(open(sys.argv[1], "rb"))
assert cfg["extend"]["useDefault"] is True, "default rules must stay on"
[rule] = cfg["allowlists"]
assert rule["condition"] == "AND", "path and value must both match"
assert any(re.search(p, ".repo-setup.json") for p in rule["paths"])
assert not any(re.search(p, "src/.repo-setup.json") or re.search(p, "config.json") for p in rule["paths"])
good, bad = "5aa89fea883d6eb806a0008bafafd84b27481aac169c51ae78e1ce81e57de9e3", "sk_live_" + "a" * 40
assert any(re.search(p, good) for p in rule["regexes"])
assert not any(re.search(p, bad) or re.search(p, good + "x") for p in rule["regexes"])
PY
}
leak_cfg "$TMP/fastapi-team" 2>/dev/null || miss "team repo has no narrow gitleaks allowlist for manifest hashes"
[ ! -e "$TMP/fastapi-starter/.gitleaks.toml" ] || miss "starter repo got .gitleaks.toml without a gitleaks hook"
tier=$(cd "$g" && python3 tools/autonomy.py --files .gitleaks.toml | json 'd["tier"]')
[ "$tier" = high ] || miss "tier of .gitleaks.toml: $tier"
echo "ok  gitleaks allowlist (or misses reported above)"

# 23. github-agents: team alone has no agent workflows; the capability adds them
n="$TMP/team-no-agents"; mkdir -p "$n" && git -C "$n" init -q -b main
python3 "$S/apply.py" --target "$n" --preset python --level team --var project_name=N --var description=x --var owner=acme >/dev/null
[ ! -e "$n/.github/workflows/pr-pipeline.yml" ] || miss "team without agents got pr-pipeline.yml"
[ ! -e "$n/.github/ISSUE_TEMPLATE/intent.yml" ] || miss "team without agents got intent.yml"
[ -e "$n/governance/autonomy.yaml" ] || miss "team lost the autonomy policy"
git -C "$n" add -A
failed=$(python3 "$S/doctor.py" --target "$n" --json | json '",".join(sorted(r["id"] for r in d["failed"]))')
[ "$failed" = lockfile ] || miss "team without agents: doctor failures: $failed"
y="$TMP/team-agents"; mkdir -p "$y" && git -C "$y" init -q -b main
python3 "$S/apply.py" --target "$y" --preset python --level team --with github-agents --var project_name=Y --var description=x --var owner=acme >/dev/null
[ -e "$y/.github/workflows/pr-pipeline.yml" ] || miss "github-agents did not add pr-pipeline.yml"
rm -f "$y/.github/workflows/agent-implement.yml" "$y/.github/workflows/pr-pipeline.yml"; git -C "$y" add -A
failed=$(python3 "$S/doctor.py" --target "$y" --json | json '",".join(sorted(r["id"] for r in d["failed"]))')
case ",$failed," in *,agent_workflows,*) ;; *) miss "doctor did not notice missing agent workflows: $failed" ;; esac
if python3 "$S/apply.py" --target "$TMP/bad-agents" --preset python --level starter --with github-agents --var project_name=B --var description=x --var owner=a >/dev/null 2>&1; then miss "github-agents accepted at starter"; fi
o2="$TMP/old-team"; mkdir -p "$o2/.github/workflows" && git -C "$o2" init -q -b main
printf 'name: PR pipeline\n' > "$o2/.github/workflows/pr-pipeline.yml"
python3 "$S/apply.py" --target "$o2" --preset python --level team --var project_name=O --var description=x --var owner=a >/dev/null
[ -e "$o2/.github/workflows/pr-pipeline.yml" ] || miss "apply removed an existing pr-pipeline.yml"
steps() { ( cd "$1" && python3 -B -c "
import json,sys; sys.path.insert(0,'tools')
import github_setup as g
print(json.dumps(g.plan('o/r','main','@a','m',agents=$2)))" ); }
steps "$n" False | python3 -c "import json,sys; d=json.load(sys.stdin); w=[x['what'] for x in d]; r=[x for x in d if 'ruleset' in x][0]; c=[k['context'] for k in r['ruleset']['rules'][-1]['parameters']['required_status_checks']]; assert c==['check'],c; assert not any('label' in a for a in w),w; assert not any('approve' in a for a in w),w; assert not any('REPO_SETUP_MARKETPLACE' in a for a in w),w" || miss "github_setup without agents"
steps "$n" True | python3 -c "import json,sys; d=json.load(sys.stdin); r=[x for x in d if 'ruleset' in x][0]; c=[k['context'] for k in r['ruleset']['rules'][-1]['parameters']['required_status_checks']]; assert c==['check','gate'],c" || miss "github_setup with agents"
( cd "$o2" && python3 -B -c "import sys; sys.path.insert(0,'tools'); import github_setup as g, pathlib; assert g.has_agents(pathlib.Path('.'))" ) || miss "old team repo not detected as having agents"
( cd "$n" && python3 -B -c "import sys; sys.path.insert(0,'tools'); import github_setup as g, pathlib; assert not g.has_agents(pathlib.Path('.'))" ) || miss "team repo wrongly detected as having agents"
echo "ok  github-agents (or misses reported above)"

# 24. capability ai: env keys, evals outside make check, valid tiers, no browser stacks
for stack in python ts-node; do
  a="$TMP/ai-$stack"; mkdir -p "$a" && git -C "$a" init -q -b main
  python3 "$S/apply.py" --target "$a" --preset "$stack" --with ai --var project_name=Ai --var description=x --var owner=acme >/dev/null 2>&1 || miss "ai: apply failed on $stack"
  grep -q '^CLAUDE_MODEL=' "$a/.env.example" 2>/dev/null && grep -q '^ANTHROPIC_API_KEY=$' "$a/.env.example" && grep -q '^APP_ENV=' "$a/.env.example" || miss "ai: .env.example on $stack"
  [ -f "$a/evals/tasks.json" ] && grep -q '^eval:' "$a/mk/ai.mk" 2>/dev/null || miss "ai: eval parts on $stack"
  if grep -qE '^CHECK_TARGETS.*eval' "$a/mk/ai.mk" 2>/dev/null; then miss "ai: eval joined make check on $stack"; fi
  [ "$(python3 -c "import json;print(len(json.load(open('$a/evals/tasks.json'))))" 2>/dev/null || echo 0)" -ge 5 ] || miss "ai: fewer than 5 eval tasks on $stack"
done
if python3 "$S/apply.py" --target "$TMP/bad-tier" --preset python --with ai --var ai_tier=magic --var project_name=B --var description=x --var owner=a >/dev/null 2>&1; then miss "bad ai_tier accepted"; fi
if python3 "$S/apply.py" --target "$TMP/ai-browser" --preset react-vite --with ai --var project_name=B --var description=x --var owner=a >/dev/null 2>&1; then miss "ai accepted on a browser stack"; fi
for tier in call workflow agent; do
  t="$TMP/ai-tier-$tier"; mkdir -p "$t" && git -C "$t" init -q -b main
  python3 "$S/apply.py" --target "$t" --preset python --with ai --var ai_tier=$tier --var project_name=T --var description=x --var owner=acme >/dev/null || miss "ai: tier $tier failed"
  if [ "$tier" = call ]; then [ ! -e "$t/src/t/triage.py" ] || miss "tier call got triage.py"; else [ -e "$t/src/t/triage.py" ] || miss "tier $tier lacks triage.py"; fi
done
echo "ok  ai capability (or misses reported above)"

[ "$misses" -eq 0 ] || fail "$misses regression check(s) failed"
echo "All tests passed."
