# 49. tiered CI (docs/superpowers/specs/2026-11-17-tiered-ci-design.md): the key of what the heavy
#     tier reads, and the one check that stands for every tier. Sourced by tests/run.sh; uses its
#     ROOT, TMP and miss.

ci_tools="$ROOT/plugins/repo-setup/presets/_core/starter/tools"

# a throwaway repository with its own identity; prints its path
ci_repo() {
  local dir="$TMP/tci-$1"
  mkdir -p "$dir" && git -C "$dir" init -q -b main
  git -C "$dir" config user.name t && git -C "$dir" config user.email t@example.com
  printf '%s' "$dir"
}
ci_commit() { git -C "$1" add -A && git -C "$1" commit -q -m "${2:-c}"; }
ci_key() { local d="$1"; shift; ( cd "$d" && python3 "$ci_tools/ci_inputs.py" key "$@" 2>&1 ); }
ci_put() { mkdir -p "$(dirname "$1/$2")" && printf '%s\n' "${3:-x}" > "$1/$2"; }
# exit code of `ci_inputs.py <args>` run in a repository
ci_rc() { local d="$1" rc=0; shift; ( cd "$d" && python3 "$ci_tools/ci_inputs.py" "$@" ) >/dev/null 2>&1 || rc=$?; printf '%s' "$rc"; }

# 49a. what is not an input leaves the key alone; what is an input changes it
ci_a=$(ci_repo a)
for f in docs/a.md wiki/x.md README.md _acceptance/v/evidence.md src/a.ts package-lock.json docs.ts sub/README.md; do
  ci_put "$ci_a" "$f" one
done
ci_commit "$ci_a" base
ci_k0=$(ci_key "$ci_a")
case "$ci_k0" in
  sha256:????????????????????????????????????????????????????????????????) ;;
  *) miss "ci_inputs: key does not print sha256:<64 hex> ($ci_k0)" ;;
esac
for f in docs/a.md wiki/x.md README.md _acceptance/v/evidence.md; do
  ci_put "$ci_a" "$f" two; ci_commit "$ci_a" "edit $f"
  [ "$(ci_key "$ci_a")" = "$ci_k0" ] || miss "ci_inputs: editing $f (not an input) changes the key"
done
ci_prev=$ci_k0
for f in src/a.ts package-lock.json docs.ts sub/README.md; do
  ci_put "$ci_a" "$f" two; ci_commit "$ci_a" "edit $f"
  ci_now=$(ci_key "$ci_a")
  [ "$ci_now" != "$ci_prev" ] || miss "ci_inputs: editing $f (an input) leaves the key unchanged"
  ci_prev=$ci_now
done
[ "$(ci_key "$ci_a" --rev HEAD~4)" = "$ci_k0" ] || miss "ci_inputs: --rev HEAD~4 does not give the key of that commit"
[ "$(ci_key "$ci_a" --not-inputs "docs/** wiki/** *.md _acceptance/** src/**")" != "$ci_prev" ] || miss "ci_inputs: --not-inputs does not change what is read"
[ "$(ci_rc "$ci_a" matches src/a.ts)" = 0 ] || miss "ci_inputs: matches src/a.ts is not 0 (an input)"
for f in README.md docs/deep/x.md _acceptance/v/e.md wiki/a.md; do
  [ "$(ci_rc "$ci_a" matches "$f")" = 1 ] || miss "ci_inputs: matches $f is not 1 (not an input)"
done
for f in sub/README.md docs.ts; do
  [ "$(ci_rc "$ci_a" matches "$f")" = 0 ] || miss "ci_inputs: matches $f is not 0 (an input)"
done
[ "$(ci_rc "$ci_a" matches src/a.ts --not-inputs 'src/**')" = 1 ] || miss "ci_inputs: --not-inputs is not read by matches"
[ "$(cd "$ci_a" && HEAVY_NOT_INPUTS='src/**' python3 "$ci_tools/ci_inputs.py" matches src/a.ts >/dev/null 2>&1; echo $?)" = 1 ] || miss "ci_inputs: HEAVY_NOT_INPUTS is not read when --not-inputs is absent"
# the key does not depend on the folder it runs in or the --root it is given
mkdir -p "$ci_a/deep/er"
ci_k_root=$(ci_key "$ci_a")
[ "$(ci_key "$ci_a/src")" = "$ci_k_root" ] || miss "ci_inputs: the key computed from a subfolder differs from the key from the root"
[ "$(ci_key "$ci_a/deep/er")" = "$ci_k_root" ] || miss "ci_inputs: the key computed from an empty-ish subfolder differs from the key from the root"
[ "$(ci_key "$ci_a/src" --root "$ci_a/src")" = "$ci_k_root" ] || miss "ci_inputs: --root pointing at a subfolder gives a different key"
[ "$(ci_key "$ci_a" --root src)" = "$ci_k_root" ] || miss "ci_inputs: --root src gives a different key"
ci_put "$ci_a" sub/README.md three; ci_commit "$ci_a" "edit sub"
[ "$(ci_key "$ci_a/src")" != "$ci_k_root" ] || miss "ci_inputs: an edit outside the subfolder leaves the key computed from it unchanged"
[ "$(ci_rc "$ci_a" key --rev no-such-rev)" = 2 ] || miss "ci_inputs: a revision that does not resolve does not exit 2"
[ "$(ci_rc "$ci_a" nonsense)" = 2 ] || miss "ci_inputs: a wrong call does not exit 2"

# 49b. a path with spaces and non-ASCII letters: a stable key, and the file counts
ci_b=$(ci_repo b)
ci_put "$ci_b" "src/a b ü.ts" one; ci_put "$ci_b" src/z.ts one
ci_commit "$ci_b" base
ci_b1=$(ci_key "$ci_b"); ci_b2=$(ci_key "$ci_b")
[ "$ci_b1" = "$ci_b2" ] || miss "ci_inputs: the key of a repo with 'src/a b ü.ts' is not stable ($ci_b1 / $ci_b2)"
case "$ci_b1" in sha256:*) ;; *) miss "ci_inputs: no key for a repo with 'src/a b ü.ts' ($ci_b1)" ;; esac
ci_put "$ci_b" "src/a b ü.ts" two; ci_commit "$ci_b" edit
[ "$(ci_key "$ci_b")" != "$ci_b1" ] || miss "ci_inputs: editing 'src/a b ü.ts' leaves the key unchanged"

# 49c. the same tree outside _acceptance/ gives the same key; code merged from main changes it
ci_c=$(ci_repo c)
ci_put "$ci_c" src/a.ts one; ci_commit "$ci_c" base
git -C "$ci_c" checkout -q -b feature
ci_put "$ci_c" _acceptance/v/evidence.md proof; ci_commit "$ci_c" evidence
ci_c_feat=$(ci_key "$ci_c")
[ "$ci_c_feat" = "$(ci_key "$ci_c" --rev main)" ] || miss "ci_inputs: two commits equal outside _acceptance/ give different keys"
git -C "$ci_c" checkout -q main
ci_put "$ci_c" src/b.ts new; ci_commit "$ci_c" "main moves"
git -C "$ci_c" checkout -q feature
git -C "$ci_c" merge -q --no-edit --no-ff main >/dev/null 2>&1 || miss "ci_inputs: could not merge main into the test branch"
[ "$(ci_key "$ci_c")" != "$ci_c_feat" ] || miss "ci_inputs: merging a code change from main leaves the key unchanged"
# 49d. the check that stands for every tier: green only when every tier is "success"
ci_verdict() { ( NEEDS_JSON="$1" python3 "$ci_tools/ci_verdict.py" 2>&1 ); }
ci_vrc() { local rc=0; ( NEEDS_JSON="$1" python3 "$ci_tools/ci_verdict.py" ) >/dev/null 2>&1 || rc=$?; printf '%s' "$rc"; }
ci_needs() { printf '{"quick": {"result": "%s", "outputs": {}}, "heavy": {"result": "%s", "outputs": {}}}' "$1" "$2"; }
[ "$(ci_vrc "$(ci_needs success success)")" = 0 ] || miss "ci_verdict: success + success is not green"
ci_skip_why="did not run: an earlier tier failed, or this pull request is a draft"
ci_cancel_why="cancelled: a newer push replaces this run"
for q in success skipped cancelled failure; do
  for h in success skipped cancelled failure; do
    [ "$q $h" = "success success" ] && continue
    ci_vo=$(ci_verdict "$(ci_needs "$q" "$h")") || true
    [ "$(ci_vrc "$(ci_needs "$q" "$h")")" = 1 ] || miss "ci_verdict: $q + $h is not red"
    for pair in "quick $q" "heavy $h"; do
      read -r ci_tier ci_res <<<"$pair"
      case "$ci_res" in
        success) case "$ci_vo" in *"$ci_tier: success"*) miss "ci_verdict: $q + $h names $ci_tier, which is green" ;; esac ;;
        skipped) case "$ci_vo" in *"$ci_tier: skipped — $ci_skip_why"*) ;; *) miss "ci_verdict: $q + $h has no line for $ci_tier skipped ($ci_vo)" ;; esac ;;
        cancelled) case "$ci_vo" in *"$ci_tier: cancelled — $ci_cancel_why"*) ;; *) miss "ci_verdict: $q + $h has no line for $ci_tier cancelled ($ci_vo)" ;; esac ;;
        failure) case "$ci_vo" in *"$ci_tier: failure — failed"*) ;; *) miss "ci_verdict: $q + $h has no line for $ci_tier failure ($ci_vo)" ;; esac ;;
      esac
    done
  done
done
[ "$(ci_verdict "$(ci_needs failure success)" | wc -l | tr -d ' ')" = 1 ] || miss "ci_verdict: one red tier does not print exactly one line"
[ "$(ci_vrc '{}')" = 1 ] || miss "ci_verdict: an empty needs object is not red"
[ "$(ci_vrc 'not json')" = 1 ] || miss "ci_verdict: a string that is not JSON is not red"
[ "$(ci_vrc '')" = 1 ] || miss "ci_verdict: an empty NEEDS_JSON is not red"
[ "$(cd "$TMP" && env -u NEEDS_JSON python3 "$ci_tools/ci_verdict.py" >/dev/null 2>&1; echo $?)" = 1 ] || miss "ci_verdict: no NEEDS_JSON is not red"

# 49e. two tiers in make: the browser checks are heavy, make check still runs both
ci_e="$TMP/tci-e"; mkdir -p "$ci_e" && git -C "$ci_e" init -q -b main
python3 "$S/apply.py" --target "$ci_e" --preset react-vite --with design --var project_name=P --var description=x \
  --var owner=acme >/dev/null 2>&1 || miss "tiers: apply react-vite with design failed"
ci_plan() { ( cd "$ci_e" && make -n "$1" 2>&1 ) || true; }
ci_q=$(ci_plan check-quick); ci_h=$(ci_plan check-heavy); ci_all=$(ci_plan check)
case "$ci_q" in *playwright*) miss "tiers: make check-quick runs the browser checks ($ci_q)" ;; esac
case "$ci_q" in *"npm run --silent lint"*"node tools/design_guards.mjs"*) ;; *) miss "tiers: make check-quick lacks lint or the design guards ($ci_q)" ;; esac
case "$ci_h" in *"npx playwright test"*) ;; *) miss "tiers: make check-heavy does not run the browser checks ($ci_h)" ;; esac
case "$ci_h" in *"npm run --silent lint"*) miss "tiers: make check-heavy runs the light tier ($ci_h)" ;; esac
case "$ci_h" in *"ledgers.py draw"*"npx playwright test"*) ;; *) miss "tiers: the heavy tier does not wait for make derived ($ci_h)" ;; esac
case "$ci_all" in *"npm run --silent lint"*"npx playwright test"*) ;; *) miss "tiers: make check does not run both tiers ($ci_all)" ;; esac
# a preset with nothing heavy: check-heavy is green and says so
for ci_p in ts-node python claude-plugin; do
  ci_d="$TMP/tci-e-$ci_p"; mkdir -p "$ci_d" && git -C "$ci_d" init -q -b main
  python3 "$S/apply.py" --target "$ci_d" --preset "$ci_p" --var project_name=P --var description=x --var owner=acme >/dev/null 2>&1 \
    || miss "tiers: apply $ci_p failed"
  ci_o=$(cd "$ci_d" && make check-heavy 2>&1) || miss "tiers: $ci_p make check-heavy with no heavy checks is red ($ci_o)"
  [ "$ci_o" = "no heavy checks" ] || miss "tiers: $ci_p make check-heavy with no heavy checks does not say so ($ci_o)"
  for ci_t in check-quick check-heavy; do
    grep -q "^$ci_t:" "$ci_d/Makefile" || miss "tiers: the $ci_p Makefile has no $ci_t"
  done
  grep -q '^HEAVY_TARGETS :=' "$ci_d/Makefile" || miss "tiers: the $ci_p Makefile does not define HEAVY_TARGETS"
  grep -q '^check: check-quick check-heavy' "$ci_d/Makefile" || miss "tiers: the $ci_p make check is not both tiers"
done

# 49f. the three jobs of every preset's ci.yml, read as text
# ci_block <file> <job>: the lines of one job; ci_step <file> <job> <text>: the step holding the text
ci_block() { awk -v job="  $2:" '$0 == job { on = 1; next } on && /^  [^ ]/ { on = 0 } on' "$1"; }
ci_step() { ci_block "$1" "$2" | awk -v want="$3" '
  /^      - / { if (hit) exit; step = "" } { step = step $0 "\n" } index($0, want) { hit = 1 }
  END { if (hit) printf "%s", step }'; }
for ci_p in ts-node python claude-plugin; do
  ci_y="$ROOT/plugins/repo-setup/presets/$ci_p/starter/dot.github/workflows/ci.yml"
  ci_chk=$(ci_block "$ci_y" check); ci_hv=$(ci_block "$ci_y" heavy); ci_qk=$(ci_block "$ci_y" quick)
  [ -n "$ci_qk" ] && [ -n "$ci_hv" ] && [ -n "$ci_chk" ] || miss "ci.yml ($ci_p): jobs quick, heavy and check are not all there"
  printf '%s\n' "$ci_chk" | grep -qx '    if: always()' || miss "ci.yml ($ci_p): check does not run always()"
  printf '%s\n' "$ci_chk" | grep -qx '    needs: \[quick, heavy\]' || miss "ci.yml ($ci_p): check does not wait for both quick and heavy"
  printf '%s\n' "$ci_chk" | grep -qxF '          NEEDS_JSON: ${{ toJSON(needs) }}' || miss "ci.yml ($ci_p): check does not hand the results to ci_verdict.py through NEEDS_JSON"
  printf '%s\n' "$ci_chk" | grep -qx '        run: python3 tools/ci_verdict.py' || miss "ci.yml ($ci_p): check does not run ci_verdict.py"
  if grep -q 'run:.*toJSON' "$ci_y"; then miss "ci.yml ($ci_p): toJSON(needs) is written into a command"; fi
  printf '%s\n' "$ci_hv" | grep -qx '    needs: quick' || miss "ci.yml ($ci_p): heavy does not wait for quick"
  printf '%s\n' "$ci_hv" | grep -qxF "    if: github.event_name != 'pull_request' || !github.event.pull_request.draft" \
    || miss "ci.yml ($ci_p): heavy also runs on a draft pull request"
  printf '%s\n' "$ci_hv" | grep -q 'run: make check-heavy$' || miss "ci.yml ($ci_p): heavy does not run make check-heavy"
  printf '%s\n' "$ci_qk" | grep -q 'run: make check-quick$' || miss "ci.yml ($ci_p): quick does not run make check-quick"
  if printf '%s\n' "$ci_qk" | grep -q 'make check-heavy\|run: make check$'; then miss "ci.yml ($ci_p): quick runs the heavy tier"; fi
  # the run on the main branch reuses no key: the only restore step is for pull requests
  ci_rs=$(ci_step "$ci_y" heavy 'actions/cache/restore@')
  [ -n "$ci_rs" ] || miss "ci.yml ($ci_p): heavy has no restore step"
  printf '%s' "$ci_rs" | grep -qxF "        if: github.event_name == 'pull_request'" || miss "ci.yml ($ci_p): the restore step also runs on the main branch"
  [ "$(grep -c 'actions/cache/restore@' "$ci_y")" = 1 ] || miss "ci.yml ($ci_p): more than one restore step"
  ci_ky=$(ci_step "$ci_y" heavy 'id: key')
  printf '%s' "$ci_ky" | grep -q 'heavy-ok-' && printf '%s' "$ci_ky" | grep -q 'python3 tools/ci_inputs.py key' \
    || miss "ci.yml ($ci_p): heavy does not make its key heavy-ok-<input key>"
  printf '%s' "$(ci_step "$ci_y" heavy 'actions/cache/save@')" | grep -qF 'key: ${{ steps.key.outputs.key }}' \
    || miss "ci.yml ($ci_p): heavy does not save under the input key"
  grep -qx '    types: \[opened, synchronize, reopened, ready_for_review\]' "$ci_y" || miss "ci.yml ($ci_p): pull_request lacks ready_for_review"
  grep -qxF '  HEAVY_NOT_INPUTS: "docs/** wiki/** *.md _acceptance/**"' "$ci_y" || miss "ci.yml ($ci_p): HEAVY_NOT_INPUTS is not the default list"
  grep -qxF '  group: ci-${{ github.ref }}' "$ci_y" && grep -qx '  cancel-in-progress: true' "$ci_y" || miss "ci.yml ($ci_p): concurrency changed"
done
grep -q 'run: make build$' "$ROOT/plugins/repo-setup/presets/ts-node/starter/dot.github/workflows/ci.yml" || miss "ci.yml (ts-node): quick does not build"
grep -q 'run: make validate$' "$ROOT/plugins/repo-setup/presets/claude-plugin/starter/dot.github/workflows/ci.yml" || miss "ci.yml (claude-plugin): quick does not run the validator"

# 49g. a required check behind the one that stands for every tier: github_setup says so
ci_gs() { echo 41 > "$TMP/tci-ids"
  ( cd "$rw" && PATH="$TMP/rsbin:$PATH" GH_CALLS="$TMP/tci-calls" FAKE_RULESET_IDS="$TMP/tci-ids" FAKE_CHECKS="$TMP/tci-checks" \
    python3 -B tools/github_setup.py "$@" </dev/null ) 2>&1 || true; }
ci_behind="is a required check that can be skipped, and GitHub counts a skipped check as green"
printf 'check\ne2e\n' > "$TMP/tci-checks"
case "$(ci_gs)" in *"e2e $ci_behind"*"only check stands for it"*) ;; *) miss "github_setup: the dry run does not say that a required e2e can be skipped" ;; esac
case "$(ci_gs --prune)" in *"e2e $ci_behind"*) miss "github_setup: warns about the e2e that --prune drops" ;; esac
printf 'check\n' > "$TMP/tci-checks"
case "$(ci_gs)" in *"$ci_behind"*) miss "github_setup: warns about a skipped check when none is required" ;; esac
cp "$rw/governance/autonomy.yaml" "$TMP/tci-policy"
sed 's/^required_checks: .*$/required_checks: [heavy]/' "$TMP/tci-policy" > "$rw/governance/autonomy.yaml"
case "$(ci_gs)" in *"heavy $ci_behind"*) ;; *) miss "github_setup: the dry run does not say that a required heavy can be skipped" ;; esac
cp "$TMP/tci-policy" "$rw/governance/autonomy.yaml"
echo "ok  tiered CI (or misses reported above)"
