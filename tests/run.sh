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
    want=lockfile; [ "$preset" = react-vite ] && want=design_present,lockfile
    [ "$failed" = "$want" ] || fail "$preset/$level: unexpected doctor failures: $failed"

    # 6b. bytecode from the vendored Python tools never reaches a commit
    git -C "$d" check-ignore -q tools/__pycache__/x.pyc || miss "$preset/$level: tools/__pycache__ is not ignored"

    # 6c. sample config has no credential-shaped values: secret scanners would block the first commit
    if grep -qE '://[^/[:space:]]+:[^@[:space:]]+@' "$d/.env.example"; then miss "$preset/$level: .env.example has credentials in a URL"; fi

    echo "ok  $preset/$level"
  done
done

# 6d. Prettier must not rewrite the manifest: re-apply would then rewrite it unformatted
grep -qxF '.repo-setup.json' "$TMP/ts-node-starter/.prettierignore" || miss "ts-node: .prettierignore does not list .repo-setup.json"

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
echo "ok  autonomy tiers"

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
print(json.dumps(g.plan('o/r','main','@a',agents=$2)))" ); }
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
g2="$TMP/ai-tier-agent"
python3 -c "import json;d=json.load(open('$g2/.repo-setup.json'));assert 'mcp' in d['capabilities'],d['capabilities']" || miss "agent tier did not bring mcp"
( cd "$g2" && python3 tools/wiki_lint.py >/dev/null ) || miss "agent tier sample ontology fails wiki-lint"
[ ! -e "$TMP/ai-tier-call/ontology/actions.yaml" ] || miss "call tier got the sample ontology"
grep -q 'purgeNotes' "$g2/ontology/actions.yaml" 2>/dev/null || miss "agent tier lacks the sample ontology"
echo '{}' > "$g2/uv.lock"; git -C "$g2" add -A
python3 "$S/doctor.py" --target "$g2" --json | json '[r["id"] for r in d["failed"]]' | grep -q ai_agent_bounded && miss "doctor rejects an intact agent"
subst 's/MAX_ITERATIONS/MAX_TURNS/g' "$g2/src/t/agent.py" 2>/dev/null || true; git -C "$g2" add -A
python3 "$S/doctor.py" --target "$g2" --json | json '[r["id"] for r in d["failed"]]' | grep -q ai_agent_bounded || miss "doctor missed an agent without a turn limit"
python3 "$S/doctor.py" --target "$TMP/ai-tier-call" --json | json '[r["id"] for r in d["failed"]+d["passed"] if isinstance(r,dict)]+d["passed"]' | grep -q ai_agent_bounded && miss "call tier is checked for an agent limit"
echo "ok  ai capability (or misses reported above)"

# 25. blueprint: checked, mapped to apply.py, blocks unfinished work, drift only warns
B="$ROOT/tests/fixtures/blueprints"
bp="$S/blueprint.py"
python3 "$bp" check "$B/ok.yaml" >/dev/null 2>&1 || miss "blueprint: ok rejected"
if python3 "$bp" check "$B/bad-value.yaml" >/dev/null 2>&1; then miss "blueprint: bad value accepted"; fi
deps=$(python3 "$bp" dependents ai 2>/dev/null || true)
case " $deps " in *stack*domain*) ;; *) miss "blueprint: dependents of ai: $deps" ;; esac
x="$TMP/bp-ok"; mkdir -p "$x" && git -C "$x" init -q -b main
mapped=$(python3 "$S/apply.py" --target "$x" --from-blueprint "$B/ok.yaml" --json 2>/dev/null | json 'd["preset"]+"/"+d["level"]+"/"+",".join(d["capabilities"])' 2>/dev/null || true)
[ "$mapped" = python/starter/ai ] || miss "blueprint: wrong mapping: $mapped"
y2="$TMP/bp-pending"; mkdir -p "$y2"
if python3 "$S/apply.py" --target "$y2" --from-blueprint "$B/pending.yaml" >/dev/null 2>&1; then miss "blueprint: pending applied"; fi
[ -z "$(ls -A "$y2")" ] || miss "blueprint: pending wrote files"
python3 "$S/apply.py" --target "$y2" --from-blueprint "$B/ok-designing.yaml" --dry-run >/dev/null 2>&1 || miss "blueprint: designing dry-run refused"
if python3 "$S/apply.py" --target "$y2" --from-blueprint "$B/ok-designing.yaml" >/dev/null 2>&1; then miss "blueprint: designing applied"; fi
[ -z "$(ls -A "$y2")" ] || miss "blueprint: designing wrote files"
if python3 "$S/apply.py" --target "$y2" --from-blueprint "$B/ok.yaml" --preset fastapi >/dev/null 2>&1; then miss "blueprint: mixed with preset flags"; fi
if [ -f "$x/.repo-setup.json" ]; then
  cp "$B/ok.yaml" "$x/setup-blueprint.yaml"; git -C "$x" add -A
  drift=$(python3 "$S/doctor.py" --target "$x" --json | json 'd.get("blueprint_drift")')
  [ "$drift" = "[]" ] || miss "blueprint: false drift: $drift"
  python3 "$S/doctor.py" --target "$x" --json | json 'd["manual_steps"]' | grep -q 'Add a database' || miss "blueprint: manual steps not listed"
  before=$(python3 "$S/doctor.py" --target "$x" --json | json 'd["score"]')
  python3 - "$x/.repo-setup.json" <<'PY'
import json,sys
p=sys.argv[1]; d=json.load(open(p)); d["level"]="team"; json.dump(d,open(p,"w"))
PY
  python3 "$S/doctor.py" --target "$x" --json | json 'len(d["blueprint_drift"])' | grep -qv '^0$' || miss "blueprint: drift not reported"
  printf 'status: [' > "$x/setup-blueprint.yaml"
  python3 "$S/doctor.py" --target "$x" --json >/dev/null 2>&1 || miss "blueprint: broken file crashed doctor"
fi
echo "ok  blueprint (or misses reported above)"

# 26. new: layers, references, language rule, Vietnamese names, old Python
SK="$ROOT/plugins/repo-setup/skills/new"
for l in context repo architecture ai stack domain design quality delivery governance; do
  [ -f "$SK/references/layers/$l.md" ] || miss "layer file missing: $l"
  for w in "Framing" "automated" "Recommendation"; do grep -q "$w" "$SK/references/layers/$l.md" 2>/dev/null || miss "layer $l lacks: $w"; done
done
# 26a. the build step and docs describe the design layer
sed -n 's/^description: //p' "$SK/SKILL.md" | grep -q 'context, repo strategy, architecture, AI in the product, stack, domain, design, quality, delivery, agents' \
  || miss "new: description does not list the layers in layers.toml order"
grep -q 'design/terms.json' "$SK/SKILL.md" && grep -q 'docs_language' "$SK/SKILL.md" || miss "SKILL.md build step lacks design/terms.json and docs_language"
awk '/^## 6\./{f=1;next} /^## 7\./{f=0} f' "$SK/SKILL.md" | grep -q 'design/terms.json' || miss "SKILL.md step 6 lacks design/terms.json"
grep -q 'src/example' "$SK/references/tour.md" || miss "tour.md lacks src/example"
grep -q 'ten layers' "$ROOT/plugins/repo-setup/README.md" || miss "plugin README lacks: ten layers"
grep '`react-vite`' "$SK/references/layers/stack.md" | grep -q 'design' || miss "stack.md react-vite row lacks design"
# 26b. design layer: choices, colours, mapping to apply.py
python3 "$bp" check "$B/design.yaml" >/dev/null || miss "design.yaml should be valid"
args=$(python3 -c "
import sys; sys.path.insert(0, '$S'); import blueprint
from pathlib import Path
print(' '.join(blueprint.to_apply_args(blueprint.load(Path('$B/design.yaml')))))")
for w in "--with design" "design_surface=tool" "brand_primary=#0246ff" "locale=vi-VN" "currency=VND"; do
  case "$args" in *"$w"*) ;; *) miss "blueprint args lack: $w" ;; esac
done
python3 - "$S" <<'PY' || miss "colour rules"
import sys; sys.path.insert(0, sys.argv[1]); import blueprint as b
assert round(b.contrast_ratio("#0246ff", "#ffffff"), 2) == 6.32
assert b.readable_on("#0246ff") == "#ffffff" and b.readable_on("#ffba00") == "#0a0a0a"
assert b.brand_errors("#0246FF") == []
for bad in ("#ffba00", "#FFF", "blue", None, ""):
    assert b.brand_errors(bad), bad
PY
bad_design() { python3 - "$B/design.yaml" "$TMP/dv.yaml" "$1" "$2" <<'PY'
import sys
src, dst, old, new = sys.argv[1:]
t = open(src, encoding="utf-8").read()
assert old in t, old
open(dst, "w", encoding="utf-8").write(t.replace(old, new, 1))
PY
  if python3 "$bp" check "$TMP/dv.yaml" >/dev/null 2>&1; then miss "design: accepted $3"; fi
}
bad_design 'surface: tool' 'surface: magazine' "an unknown surface"
bad_design 'base: shadcn' 'base: bootstrap' "an unbuilt base marked automated"
bad_design 'preset: react-vite' 'preset: python' "a stack without a screen"
bad_design 'brand_primary: "#0246ff"' 'brand_primary: #0246ff' "an unquoted colour"
bad_design 'locale: vi-VN' 'locale: vietnamese' "an invalid locale"
bad_design 'currency: VND' 'currency: dong' "an invalid currency"
python3 - "$B/design.yaml" "$TMP/dna.yaml" <<'PY'
import sys
t = open(sys.argv[1], encoding="utf-8").read()
start = t.index("  design:\n"); end = t.index("  quality:\n")
open(sys.argv[2], "w", encoding="utf-8").write(t[:start] + "  design:\n    status: not_applicable\n" + t[end:])
PY
out=$(python3 "$bp" check "$TMP/dna.yaml" 2>&1) && miss "design: not_applicable accepted for a stack with a screen"
case "$out" in *"automation manual"*) ;; *) miss "design not_applicable: unclear message: $out" ;; esac
python3 - "$B/design.yaml" "$TMP/dman.yaml" <<'PY'
import sys
t = open(sys.argv[1], encoding="utf-8").read()
old = "    automation: automated\n    choice:\n      base: shadcn"
assert old in t
open(sys.argv[2], "w", encoding="utf-8").write(t.replace(old, "    automation: manual\n    choice:\n      base: company"))
PY
python3 "$bp" check "$TMP/dman.yaml" >/dev/null || miss "design: a manual base with a why should be valid"
args=$(python3 -c "
import sys; sys.path.insert(0, '$S'); import blueprint
from pathlib import Path
print(' '.join(blueprint.to_apply_args(blueprint.load(Path('$TMP/dman.yaml')))))")
case "$args" in *design*) miss "design: a manual base still gives --with design: $args" ;; esac
grep -E 'needs_review' "$SK/SKILL.md" | grep -q 'not_applicable' || miss "needs_review ignores not_applicable layers"
for f in "$ROOT"/plugins/repo-setup/skills/*/SKILL.md; do [ "$(wc -l < "$f")" -lt 500 ] || miss "too long: $f"; done
grep -q 'references/critic.md' "$SK/SKILL.md" && grep -q 'references/tour.md' "$SK/SKILL.md" && grep -q 'from-blueprint' "$SK/SKILL.md" || miss "new does not use its references"
grep -qi 'really need an agent' "$SK/references/layers/ai.md" 2>/dev/null || miss "ai layer does not ask whether an agent is needed"
if grep -q 'make every technical choice for them' "$SK/SKILL.md"; then miss "new still decides everything alone"; fi
v="$TMP/viet"; mkdir -p "$v"
slug=$(python3 "$S/apply.py" --target "$v" --preset python --var 'project_name=Quán Cà Phê Đông' --var description=x --var owner=a --dry-run --json | json '[c for c in d["created"] if c.startswith("src/")][0].split("/")[1]')
[ "$slug" = quan_ca_phe_dong ] || miss "Vietnamese project name gives package: $slug"
python3 - "$ROOT/plugins/repo-setup" <<'PY' || miss "Vietnamese text or non-ASCII path inside the plugin"
import pathlib, re, sys
vi = re.compile("[ăâđêôơưàáảãạằắẳẵặầấẩẫậèéẻẽẹềếểễệìíỉĩịòóỏõọồốổỗộờớởỡợùúủũụừứửữựỳýỷỹỵ]", re.I)
bad = []
for p in pathlib.Path(sys.argv[1]).rglob("*"):
    if p.is_file():
        if not str(p.relative_to(sys.argv[1])).isascii():
            bad.append(str(p))
        elif "__pycache__" not in p.parts and vi.search(p.read_text("utf-8", "ignore")):
            bad.append(str(p))
print(*bad, sep="\n")
sys.exit(1 if bad else 0)
PY
la="$TMP/lang"; mkdir -p "$la"
python3 "$S/apply.py" --target "$la" --preset python --var project_name=L --var description=x --var owner=a --var conversation_language=vi --var docs_language=en >/dev/null
grep -q '^## Language' "$la/AGENTS.md" && grep -q 'Conversation: vi' "$la/AGENTS.md" && grep -q 'Documents: en' "$la/AGENTS.md" || miss "AGENTS.md lacks the language rule"
grep -q 'Display name' "$la/ontology/glossary.md" || miss "glossary lacks a display name column"
git -C "$la" init -q -b main; git -C "$la" add -A
python3 "$S/doctor.py" --target "$la" --json | json '",".join(r["id"] for r in d["failed"])' | grep -q language_policy && miss "doctor rejects the language section"
old=/usr/bin/python3
if [ -x "$old" ] && ! "$old" -c 'import tomllib' 2>/dev/null; then
  for script in apply doctor; do
    msg=$("$old" "$S/$script.py" --help 2>&1 || true)
    case "$msg" in *"Python 3.11"*) ;; *) miss "old Python: unfriendly error from $script: $msg" ;; esac
  done
fi
echo "ok  new layers (or misses reported above)"

# 27. docs: real marketplace name, Vietnamese README, honest wording, plugin folder validated
if grep -q 'your-org/repo-standards' "$ROOT/README.md"; then miss "README still says your-org"; fi
grep -q 'phanlemanh/repo-standards' "$ROOT/README.md" || miss "README lacks the real marketplace"
[ -f "$ROOT/README.vi.md" ] || miss "README.vi.md missing"
grep -q 'README.vi.md' "$ROOT/README.md" || miss "README does not link the Vietnamese version"
E="$ROOT/plugins/repo-setup/skills/explain/SKILL.md"
for t in pyproject.toml .coveragerc .gitleaks.toml setup-blueprint.yaml evals/ START-HERE.md; do grep -q "$t" "$E" || miss "explain lacks: $t"; done
if grep -q 'hidden from logs and from AI agents automatically' "$E"; then miss "explain overclaims pii"; fi
if grep -qi 'real guardrails\|Rào chắn thật' "$ROOT/plugins/repo-setup/README.md"; then miss "plugin README overclaims guardrails"; fi
grep -q 'plugin validate plugins/repo-setup' "$ROOT/.github/workflows/test.yml" || miss "CI does not validate the plugin folder"
echo "ok  docs (or misses reported above)"

# 28. review findings: old team repos keep agents, blueprint values, labels, auto-merge
r1="$TMP/old-with-agents"; mkdir -p "$r1" && git -C "$r1" init -q -b main
python3 "$S/apply.py" --target "$r1" --preset python --level team --with github-agents --var project_name=R --var description=x --var owner=a >/dev/null
python3 - "$r1/.repo-setup.json" <<'PY'
import json,sys
p=sys.argv[1]; d=json.load(open(p)); d["capabilities"]=[]; json.dump(d,open(p,"w"))
PY
out=$(python3 "$S/apply.py" --target "$r1" --json)
echo "$out" | json '"\n".join(d["notes"])' | grep -q github-agents || miss "re-apply: no notice about kept agents"
grep -q '## AI-native SDLC' "$r1/AGENTS.md" || miss "re-apply dropped the agent rules while workflows remain"
python3 -c "import json;assert 'github-agents' in json.load(open('$r1/.repo-setup.json'))['capabilities']" || miss "re-apply did not record github-agents"
variant() { python3 - "$B/ok.yaml" "$TMP/variant.yaml" "$1" "$2" <<'PY'
import sys
src, dst, old, new = sys.argv[1:]
t = open(src, encoding="utf-8").read()
assert old in t, old
open(dst, "w", encoding="utf-8").write(t.replace(old, new, 1))
PY
}
variant '{ai_tier: call}' '{ai_tier: magic}'
if python3 "$bp" check "$TMP/variant.yaml" >/dev/null 2>&1; then miss "blueprint: unknown ai_tier accepted"; fi
variant '{ai_tier: call}' '{ai_tier: agent, agent_runtime: agent-sdk}'
if python3 "$bp" check "$TMP/variant.yaml" >/dev/null 2>&1; then miss "blueprint: agent-sdk marked automated"; fi
variant '{ai_tier: call}' '{ai_tier: agent, agent_runtime: tool-runner}'
python3 "$bp" check "$TMP/variant.yaml" >/dev/null 2>&1 || miss "blueprint: tool-runner rejected"
variant '    automation: automated
    choice: {level: starter}' '    choice: {level: starter}'
if python3 "$bp" check "$TMP/variant.yaml" >/dev/null 2>&1; then miss "blueprint: decided layer without automation accepted"; fi
grep -E 'coverage threshold' "$SK/references/layers/quality.md" | grep -q '`partial`' || miss "quality: mixed option must be partial"
grep -E '^\| Monorepo' "$SK/references/layers/repo.md" | grep -q '`partial`' || miss "repo: monorepo must be partial"
grep -E 'Custom tiers' "$SK/references/layers/governance.md" | grep -q '`partial`' || miss "governance: custom tiers must be partial"
grep -q 'tests' "$SK/SKILL.md" && grep -qi 'sample tests' "$SK/SKILL.md" || miss "new forgets the sample tests when replacing the ontology"
steps "$n" False | grep -q allow_auto_merge && miss "github_setup changes auto-merge without agents"
echo "ok  review findings (or misses reported above)"

# 29. setup only: the plugin stops at setup; generated repos own their procedures
PL="$ROOT/plugins/repo-setup"
actual=$(ls "$PL/skills" | sort | tr '\n' ' ')
[ "$actual" = "adopt doctor explain github new " ] || miss "plugin skills are not setup only: $actual"
for s in adopt doctor explain github new; do grep -q "^name: $s$" "$PL/skills/$s/SKILL.md" 2>/dev/null || miss "skill folder and name differ: $s"; done
old=$(grep -rIlE 'setup-(new|adopt|doctor|explain)|sdlc-github-setup' "$PL" "$ROOT/README.md" "$ROOT/README.vi.md" "$ROOT/tests/fixtures" || true)
[ -z "$old" ] || miss "old skill names remain: $old"
[ ! -e "$PL/hooks" ] || miss "plugin still ships hooks"
[ ! -e "$PL/agents" ] || miss "plugin still ships subagents"
ls "$PL"/scripts/hook_*.py >/dev/null 2>&1 && miss "plugin still ships hook scripts"
stale=$(grep -rIlE 'repo-setup:(sdlc-(run|spec|implement|review)|ontology-add|wiki-)|sdlc-(run|spec|implement|review)|code-reviewer|security-reviewer|hook_(stop|session|pretool)|Stop hook|PreToolUse|REPO_SETUP_(APPROVAL|MARKETPLACE|HOOKS)|plugin_marketplaces' "$PL" "$ROOT/README.md" "$ROOT/README.vi.md" || true)
[ -z "$stale" ] || miss "references to removed runtime: $stale"
v="$TMP/setup-only"; mkdir -p "$v" && git -C "$v" init -q -b main
python3 "$S/apply.py" --target "$v" --preset python --var project_name=V --var description=x --var owner=acme >/dev/null
for s in ontology-add wiki-ingest wiki-query wiki-health review-change; do
  grep -q "^name: $s$" "$v/.claude/skills/$s/SKILL.md" 2>/dev/null || miss "generated repo lacks the $s procedure"
done
for word in 'pii: true' 'gitleaks' 'pull_request_target' 'autonomy.py' 'Do not edit'; do
  grep -q "$word" "$v/.claude/skills/review-change/SKILL.md" 2>/dev/null || miss "review-change does not cover: $word"
done
grep -q '/review-change' "$v/CLAUDE.md" || miss "CLAUDE.md does not point to the generated procedures"
if grep -qi 'hook' "$v/CLAUDE.md"; then miss "CLAUDE.md still promises hooks"; fi
u="$TMP/setup-only-agents"; mkdir -p "$u" && git -C "$u" init -q -b main
python3 "$S/apply.py" --target "$u" --preset python --level team --with github-agents --var project_name=U --var description=x --var owner=acme >/dev/null
grep -q '.claude/skills/review-change/SKILL.md' "$u/.github/workflows/pr-pipeline.yml" || miss "pr-pipeline does not use the repo's review procedure"
if grep -qE '^ +plugins:' "$u"/.github/workflows/*.yml; then miss "agent workflows still install the plugin"; fi
grep -q 'page-types.yaml' "$u/AGENTS.md" || miss "AGENTS.md lost the spec format"
if python3 "$u/tools/github_setup.py" --help | grep -q marketplace; then miss "github_setup still sets a marketplace for CI"; fi
grep -q 'acceptance-gate-kit' "$ROOT/README.md" || miss "README does not say where the feature loop lives"
echo "ok  setup only (or misses reported above)"

# 30. PR pipeline: bots can be reviewed, review runs no PR code, the gate runs no PR code
g="$TMP/gate-repo"; mkdir -p "$g" && git -C "$g" init -q -b main
python3 "$S/apply.py" --target "$g" --preset python --level team --with github-agents --var project_name=G --var description=x --var owner=a >/dev/null
pipeline="$g/.github/workflows/pr-pipeline.yml"
review=$(sed -n '/^  review:$/,/^  automerge:$/p' "$pipeline")
echo "$review" | grep -q 'allowed_bots: "claude\[bot\]"' || miss "review rejects PRs opened by claude[bot]"
if grep -q "allowed_bots: *['\"]\*" "$pipeline"; then miss "pipeline allows every bot"; fi
if echo "$review" | grep -q 'setup-project'; then miss "review installs the PR's dependencies"; fi
if echo "$review" | grep -q 'Bash(make:'; then miss "review may run make from the PR"; fi
echo "$review" | grep -q -- '--strict-mcp-config' || miss "review may start MCP servers from the PR"
echo "$review" | grep -q 'Bash(gh pr checks:' || miss "review cannot read the CI result"
echo "$review" | grep -q 'checks: read' || miss "review lacks permission to read checks"
skill="$g/.claude/skills/review-change/SKILL.md"
grep -q 'In CI' "$skill" || miss "review-change does not say what to skip in CI"
git -C "$g" add -A && git -C "$g" -c user.name=t -c user.email=t@t -c core.hooksPath=/dev/null commit -qm base
git -C "$g" update-ref refs/remotes/origin/main main
git -C "$g" switch -qc pr
mkdir -p "$g/.gate"
printf 'import os\nopen(os.environ["TRAP"], "w").write("ran")\n' > "$g/.gate/yaml.py"
cp "$g/.gate/yaml.py" "$g/yaml.py"
cat "$g/.gate/yaml.py" "$g/tools/autonomy.py" > "$g/tools/autonomy.py.new" && mv "$g/tools/autonomy.py.new" "$g/tools/autonomy.py"
git -C "$g" add -A && git -C "$g" -c user.name=t -c user.email=t@t -c core.hooksPath=/dev/null commit -qm pr
steps_of() { python3 - "$pipeline" "$1" <<'PY_STEP'
import sys
lines = open(sys.argv[1], encoding="utf-8").read().splitlines()
start = next(i for i, l in enumerate(lines) if sys.argv[2] in l and "- name:" in l)
run = next(i for i in range(start, len(lines)) if lines[i].strip() == "run: |")
indent = len(lines[run]) - len(lines[run].lstrip()) + 2
for l in lines[run + 1:]:
    if l.strip() and len(l) - len(l.lstrip()) < indent:
        break
    print(l[indent:])
PY_STEP
}
gate_run() { # base-branch rules present or removed: $1 = output file
  ( cd "$g" && TRAP="$TMP/trap" RUNNER_TEMP="$TMP/runner" GITHUB_WORKSPACE="$g" GITHUB_OUTPUT="$1" \
    GITHUB_STEP_SUMMARY="$TMP/summary" BASE=main AUTHOR=someone UPDATE_TYPE="" \
    bash -e -c "$(steps_of 'Load the rules from the base branch'; steps_of 'Classify')" ) >/dev/null 2>&1
}
mkdir -p "$TMP/runner"; rm -f "$TMP/trap"
gate_run "$TMP/gate.out" || miss "gate failed on a pull request with a planted .gate/yaml.py"
[ ! -e "$TMP/trap" ] || miss "gate ran code from the pull request"
grep -q '^tier=high$' "$TMP/gate.out" 2>/dev/null || miss "gate did not judge a tools/ change as high"
[ ! -e "$g/.gate/autonomy.py" ] || miss "gate copied its rules into the checkout"
git -C "$g" update-ref refs/remotes/origin/bare "$(git -C "$g" -c user.name=t -c user.email=t@t commit-tree -m none "$(git -C "$g" mktree </dev/null)")"
rm -f "$TMP/gate2.out" "$TMP/trap"
( cd "$g" && TRAP="$TMP/trap" RUNNER_TEMP="$TMP/runner" GITHUB_WORKSPACE="$g" GITHUB_OUTPUT="$TMP/gate2.out" \
  GITHUB_STEP_SUMMARY="$TMP/summary" BASE=bare AUTHOR=someone UPDATE_TYPE="" \
  bash -e -c "$(steps_of 'Load the rules from the base branch'; steps_of 'Classify')" ) >/dev/null 2>&1 \
  || miss "gate failed when the base branch has no rules"
grep -q '^tier=high$' "$TMP/gate2.out" 2>/dev/null || miss "gate without base rules must be high"
[ ! -e "$TMP/trap" ] || miss "gate ran code from the pull request when the base has no rules"
echo "ok  pr pipeline (or misses reported above)"

# 31. design capability
for level in starter team; do
  d="$TMP/design-$level"; mkdir -p "$d"; git -C "$d" init -q -b main
  python3 "$S/apply.py" --target "$d" --preset react-vite --level "$level" --with design \
    --var 'project_name=Quán "Cà" \ Phê' --var description=x --var owner=acme \
    --var 'brand_primary=#0246ff' --var locale=vi-VN --var currency=VND --json >/dev/null \
    || miss "design: apply failed at $level"
  grep -q -- '--primary: #0246ff' "$d/src/index.css" || miss "design: brand block missing"
  [ "$(tail -6 "$d/src/index.css" | grep -c primary)" -ge 2 ] || miss "design: brand block must come last"
  grep -q 'lang="vi"' "$d/index.html" || miss "design: page language"
  # shadcn's destructive red fails 4.5:1 on its own 10% tint (badge, button); e2e pins it in the browser.
  grep -q -- '--destructive: oklch(0.48 0.2 27.325);' "$d/src/index.css" || miss "design: destructive token not darkened"
  grep -q '"vi-VN"' "$d/src/lib/format.ts" && grep -q '"VND"' "$d/src/lib/format.ts" || miss "design: locale"
  grep -q 'CHECK_TARGETS += design-guards ui-floor' "$d/mk/design.mk" || miss "design: not in the gate"
  [ -f "$d/.mcp.json" ] && miss "design: must not add .mcp.json"
  # The measurement protocol cuts the capability at these exact lines.
  grep -qx ' *// design-floor:start' "$d/eslint.config.js" && grep -qx ' *// design-floor:end' "$d/eslint.config.js" \
    || miss "design: eslint markers missing"
  grep -qx '## Design floor' "$d/AGENTS.md" || miss "design: AGENTS section heading"
  again=$(python3 "$S/apply.py" --target "$d" --json | json 'len(d["created"])+len(d["updated"])+len(d["conflict"])') || again=-1
  [ "$again" -eq 0 ] || miss "design/$level: second run changed $again files"
done
grep -q 'src/components/ui' "$TMP/design-team/vitest.config.ts" || miss "design: team coverage counts vendor code"
# The table patch: runs after `shadcn add` and before `make format`, is safe to run twice,
# and stops loudly when the component no longer looks like the pinned version.
python3 - "$S/../capabilities/design/preset.toml" <<'PY' || miss "design: patch_ui.mjs not run between shadcn add and make format"
import sys, tomllib
cmds = tomllib.load(open(sys.argv[1], "rb"))["starter"]["install"]
at = lambda word: next(i for i, c in enumerate(cmds) if word in c)
assert at("shadcn@4.23.0 add") < at("node tools/patch_ui.mjs") < at("make format"), cmds
PY
d="$TMP/design-team"; mkdir -p "$d/src/components/ui"
cat > "$d/src/components/ui/table.tsx" <<'TSX'
function Table({ className, ...props }: React.ComponentProps<"table">) {
  return (
    <div
      data-slot="table-container"
      className="relative w-full overflow-x-auto"
    >
TSX
( cd "$d" && node tools/patch_ui.mjs && cp src/components/ui/table.tsx "$TMP/table.once" && node tools/patch_ui.mjs ) \
  || miss "design: patch_ui.mjs failed on the shadcn table"
grep -q 'role="region" aria-label={label} tabIndex={0}' "$d/src/components/ui/table.tsx" && grep -q '"aria-label": string' "$d/src/components/ui/table.tsx" \
  || miss "design: table scroll region not focusable and named after the patch"
cmp -s "$TMP/table.once" "$d/src/components/ui/table.tsx" || miss "design: patch_ui.mjs is not idempotent"
echo 'export {};' > "$d/src/components/ui/table.tsx"
out=$(cd "$d" && node tools/patch_ui.mjs 2>&1) && miss "design: patch_ui.mjs accepted an unknown table"
case "$out" in *"no longer matches"*) ;; *) miss "design: patch_ui.mjs failed without saying why: $out" ;; esac
rm -r "$d/src/components"
d="$TMP/design-plain"; python3 "$S/apply.py" --target "$d" --preset react-vite --with design \
  --var project_name=P --var description=x --var owner=a >/dev/null || miss "design: no brand must work"
grep -q 'brand' "$d/src/index.css" && miss "design: brand block without a brand"
d="$TMP/design-content"; python3 "$S/apply.py" --target "$d" --preset react-vite --with design --var design_surface=content \
  --var project_name=P --var description=x --var owner=a >/dev/null || miss "design: content surface apply failed"
grep -q 'TableRow' "$d/src/example/ReferenceScreen.tsx" && miss "design: content surface got the table screen"
grep -q 'text-base' "$d/design/behaviors.md" || miss "design: content surface lacks its density"
grep -q 'text-sm' "$TMP/design-plain/design/behaviors.md" || miss "design: tool surface lacks its density"
if python3 "$S/apply.py" --target "$TMP/design-py" --preset fastapi --with design \
  --var project_name=P --var description=x --var owner=a >/dev/null 2>&1; then miss "design: stack without a screen accepted"; fi
if python3 "$S/apply.py" --target "$TMP/design-bad" --preset react-vite --with design --var 'brand_primary=red' \
  --var project_name=P --var description=x --var owner=a >/dev/null 2>&1; then miss "design: bad colour accepted"; fi
for bad in design_surface=magazine locale=vietnamese locale=vi_VN currency=dong currency=VN; do
  out=$(python3 "$S/apply.py" --target "$TMP/design-bad" --preset react-vite --with design --var "$bad" \
    --var project_name=P --var description=x --var owner=a 2>&1) && miss "design: --var $bad accepted"
  case "$out" in *"${bad%%=*} must"*) ;; *) miss "design: --var $bad refused without saying why: $out" ;; esac
done
[ ! -e "$TMP/design-bad/package.json" ] || miss "design: a bad --var still wrote files"
d="$TMP/design-starter"; git -C "$d" add -A
failed=$(python3 "$S/doctor.py" --target "$d" --level starter --json | json '",".join(sorted(r["id"] for r in d["failed"]))')
[ "$failed" = "design_guards_bite,lockfile" ] || miss "design doctor without install: $failed"
# 31a. dropping design from the manifest does not switch the checks off unseen
d="$TMP/design-plain"; git -C "$d" init -q -b main 2>/dev/null; git -C "$d" add -A
python3 - "$d/.repo-setup.json" <<'PY'
import json, sys
p = sys.argv[1]; m = json.load(open(p)); m["capabilities"].remove("design"); json.dump(m, open(p, "w"))
PY
detail=$(python3 "$S/doctor.py" --target "$d" --json | json '[r.get("detail","") for r in d["failed"] if r["id"]=="design_present"]')
case "$detail" in *"does not list design"*) ;; *) miss "doctor: design dropped from the manifest went unseen: $detail" ;; esac
# 31b. turning design on in an existing react-vite repo: the user's own stylesheet is kept, with a note
d="$TMP/design-later"; mkdir -p "$d/src"; git -C "$d" init -q -b main
python3 "$S/apply.py" --target "$d" --preset react-vite --var project_name=P --var description=x --var owner=a >/dev/null
echo 'body { margin: 0; }' > "$d/src/index.css"
notes=$(python3 "$S/apply.py" --target "$d" --with design --json | json '" ".join(d["notes"])+" kept="+",".join(d["kept"])')
case "$notes" in *"kept your own src/index.css"*"design tokens"*"by hand"*"kept=src/index.css"*) ;; *) miss "design later: no note about src/index.css: $notes" ;; esac
grep -q 'margin: 0' "$d/src/index.css" || miss "design later: own stylesheet overwritten"
d="$TMP/design-team"; echo "/* mine */" >> "$d/src/index.css"
notes=$(python3 "$S/apply.py" --target "$d" --json | json '" ".join(d["notes"])')
case "$notes" in *"src/index.css"*) miss "design: note for a stylesheet apply wrote itself: $notes" ;; esac
# 31c. adopt does not support design yet: apply refuses it, doctor does not score it
d="$TMP/design-adopt"; mkdir -p "$d"; git -C "$d" init -q -b main
out=$(python3 "$S/apply.py" --target "$d" --preset react-vite --adopt --with design \
  --var project_name=P --var description=x --var owner=a 2>&1) && miss "design: accepted under adopt"
case "$out" in *"adopt does not support the design capability yet"*) ;; *) miss "design under adopt: unclear refusal: $out" ;; esac
[ -z "$(ls -A "$d" | grep -v '^.git$' || true)" ] || miss "design under adopt: files written"
python3 "$S/apply.py" --target "$d" --preset react-vite --adopt --var project_name=P --var description=x --var owner=a >/dev/null \
  || miss "adopt react-vite without design failed"
if python3 "$S/apply.py" --target "$d" --with design >/dev/null 2>&1; then miss "design: added later to an adopted repo"; fi
git -C "$d" add -A
skip=$(python3 "$S/doctor.py" --target "$d" --json | json '[r.get("detail","") for r in d["skipped"] if r["id"]=="design_present"]')
case "$skip" in *"not applicable"*) ;; *) miss "doctor: design_present not skipped for an adopted repo: $skip" ;; esac
# 31d. doctor: the floor files must stay as apply wrote them
d="$TMP/design-starter"
floor() { python3 "$S/doctor.py" --target "$d" --level starter --json | json '[r.get("detail","")+" | "+r["fix"] for r in d["failed"] if r["id"]=="design_guards_bite"][0]'; }
case "$(floor)" in *"changed since apply"*) miss "design floor: fresh repo reported as changed" ;; esac
cp "$d/tests/e2e/floor.spec.ts" "$TMP/floor.bak"; echo "// weaker" >> "$d/tests/e2e/floor.spec.ts"
case "$(floor)" in *"changed since apply wrote them: tests/e2e/floor.spec.ts"*"Re-apply the design capability"*) ;;
  *) miss "design floor: edited floor.spec.ts not reported: $(floor)" ;; esac
cp "$TMP/floor.bak" "$d/tests/e2e/floor.spec.ts"
cp "$d/.repo-setup.json" "$TMP/manifest.bak"
python3 - "$d/.repo-setup.json" <<'PY'
import json, sys
p = sys.argv[1]; m = json.load(open(p)); del m["files"]["mk/design.mk"]; json.dump(m, open(p, "w"))
PY
case "$(floor)" in *"changed since apply"*) miss "design floor: no hash and the plugin copy reported as changed" ;; esac
cp "$d/mk/design.mk" "$TMP/mk.bak"; printf '\t-true\n' >> "$d/mk/design.mk"
case "$(floor)" in *"changed since apply wrote them: mk/design.mk"*) ;; *) miss "design floor: no hash, edit not caught against the plugin copy" ;; esac
python3 - "$d/.repo-setup.json" "$d/mk/design.mk" <<'PY'
import hashlib, json, sys
p, f = sys.argv[1:]; m = json.load(open(p))
m["files"]["mk/design.mk"] = hashlib.sha256(open(f, "rb").read()).hexdigest(); json.dump(m, open(p, "w"))
PY
case "$(floor)" in *"changed since apply"*) miss "design floor: compared with the plugin copy although a hash is recorded" ;; esac
cp "$TMP/mk.bak" "$d/mk/design.mk"; cp "$TMP/manifest.bak" "$d/.repo-setup.json"
# 31e. the gate check goes red when make could skip the guards or ignore their failure
d="$TMP/design-team"
( cd "$d" && node tools/design_guards.mjs --only gate >/dev/null 2>&1 ) || miss "design gate: red on a fresh repo"
gate_red() { # <file> <line to add, or "" to drop design-guards from the gate> <expected text>
  cp "$d/$1" "$TMP/gate.bak"
  if [ -n "$2" ]; then printf '%s\n' "$2" >> "$d/$1"; else subst 's/^CHECK_TARGETS += design-guards /CHECK_TARGETS += /' "$d/$1"; fi
  cmp -s "$TMP/gate.bak" "$d/$1" && miss "design gate: mutation '$2' did not change $1"
  out=$(cd "$d" && node tools/design_guards.mjs --only gate 2>&1) && miss "design gate: stayed green with '$2' in $1"
  case "$out" in *"$3"*) ;; *) miss "design gate: '$2' in $1 went red for another reason: $out" ;; esac
  cp "$TMP/gate.bak" "$d/$1"
}
gate_red mk/design.mk "" "make check does not run the design guards"
gate_red mk/design.mk ".IGNORE:" "mk/design.mk ignores errors with .IGNORE"
gate_red Makefile "MAKEFLAGS += -i" "Makefile ignores errors through MAKEFLAGS"
gate_red Makefile "MAKEFLAGS += --keep-going --ignore-errors" "Makefile ignores errors through MAKEFLAGS"
gate_red Makefile "export MAKEFLAGS += -i" "Makefile ignores errors through MAKEFLAGS"
printf '.PHONY: check\ncheck:\n\t@true\n' > "$d/GNUmakefile"
out=$(cd "$d" && node tools/design_guards.mjs --only gate 2>&1) && miss "design gate: stayed green with a GNUmakefile"
case "$out" in *"GNUmakefile exists: make reads it before Makefile"*) ;; *) miss "design gate: GNUmakefile went red for another reason: $out" ;; esac
rm -f "$d/GNUmakefile"
( cd "$d" && printf 'MAKEFLAGS += --no-print-directory\n' >> Makefile && node tools/design_guards.mjs --only gate >/dev/null 2>&1 ) \
  || miss "design gate: an unrelated MAKEFLAGS setting went red"
python3 - "$ROOT/plugins/repo-setup" <<'PY' || miss "design checks wired wrongly"
import sys, tomllib, pathlib
checks = {c["id"]: c for c in tomllib.loads((pathlib.Path(sys.argv[1]) / "checklists/top-tier.toml").read_text())["check"]}
for k, mode in (("design_guards_bite", "guards"), ("design_floor_in_gate", "gate"), ("design_reference", "reference")):
    assert checks[k]["type"] == "command" and checks[k]["capabilities"] == ["design"] and mode in checks[k]["command"], k
assert checks["design_present"]["presets"] == ["react-vite"] and checks["design_present"]["weight"] == 3
PY
echo "ok  design capability (or misses reported above)"

[ "$misses" -eq 0 ] || fail "$misses regression check(s) failed"
echo "All tests passed."
