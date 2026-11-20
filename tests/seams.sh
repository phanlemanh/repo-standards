# 51. seams with other tools: a name or a file that this setup and another tool both use
#     (design-assembly, delivery-loop). The setup reads neither tool, so each case is told from
#     this side only. Sourced by tests/run.sh; uses its S, TMP, gs, gsa, dry, json and miss.

# sm_set <repo> <pattern of one line of the policy> <the line to put there>
sm_set() {
  python3 - "$1/governance/autonomy.yaml" "$2" "$3" <<'PY'
import re, sys
path, pattern, line = sys.argv[1:]
text = open(path, encoding="utf-8").read()
text, n = re.subn(pattern, line, text, flags=re.M)
assert n == 1, (pattern, n)
open(path, "w", encoding="utf-8").write(text)
PY
}
# sm_ok <repo>: the policy is accepted; what it said goes to <repo>.err
sm_ok() { ( cd "$1" && python3 -B tools/autonomy.py --write-codeowners >/dev/null && python3 -B tools/autonomy.py --check-codeowners >/dev/null 2>"$1.err" ); }
sm_fresh() { rm -rf "$2" && cp -R "$1" "$2"; }

# 51a. `gate` is the setup's own check only where the agent pipeline reports it. Without that
#      pipeline the name is free. Found on a repository whose feature loop reports its proof as
#      `gate`: the policy refused the name as "required already", and nothing required it.
sm="$TMP/seam-team"; sma="$TMP/seam-agents"
sm_fresh "$gs" "$sm"
sm_set "$sm" '^required_checks: .*$' 'required_checks: [gate]'
sm_ok "$sm" || miss "seams: without agent workflows, a check named gate is refused under required_checks ($(cat "$sm.err"))"
dry "$sm" | grep 'ruleset on' | grep -q ', gate$' || miss "seams: without agent workflows, github_setup does not require the gate the policy names: $(dry "$sm" | grep 'ruleset on')"
sm_fresh "$gs" "$sm"
sm_set "$sm" '^  check: ""$' '  check: gate'
sm_set "$sm" '^default: medium$' 'default: low'
sm_ok "$sm" || miss "seams: without agent workflows, a proof named gate is refused ($(cat "$sm.err"))"
[ "$(cd "$sm" && python3 -B tools/autonomy.py --files README.md 2>/dev/null | json 'd["proof"]')" = gate ] \
  || miss "seams: without agent workflows, a proof named gate is not handed on as the proof"
dry "$sm" | grep 'ruleset on' | grep -q ', gate$' || miss "seams: without agent workflows, github_setup does not require the proof named gate: $(dry "$sm" | grep 'ruleset on')"
# With the pipeline the name is taken: its own job reports under it.
sm_fresh "$gsa" "$sma"
sm_set "$sma" '^required_checks: .*$' 'required_checks: [gate]'
if sm_ok "$sma"; then miss "seams: with agent workflows, the pipeline's own gate was accepted under required_checks"; fi
grep -q 'gate is one of the setup.s own checks' "$sma.err" || miss "seams: with agent workflows, the refusal of gate does not say why ($(cat "$sma.err"))"
sm_fresh "$gsa" "$sma"
sm_set "$sma" '^  check: ""$' '  check: gate'
if sm_ok "$sma"; then miss "seams: with agent workflows, the pipeline's own gate was accepted as the proof"; fi
# The checks every team repository has stay the setup's own, with or without the pipeline.
for own in check secret-scan; do
  sm_fresh "$gs" "$sm"
  sm_set "$sm" '^required_checks: .*$' "required_checks: [$own]"
  if sm_ok "$sm"; then miss "seams: the setup's own check '$own' was accepted under required_checks"; fi
done

# 51b. a file of the repository's own where the setup puts a file that joins checks to
#      `make check`: the checks are not joined, so the run is not done. It ends with 1 and names
#      them. Found with mk/design.mk, a name a repository gives its own design checks.
smd="$TMP/seam-design"; mkdir -p "$smd/mk" && git -C "$smd" init -q -b main
printf 'CHECK_TARGETS += design\n.PHONY: design\ndesign:\n\t@echo the repository own design check\n' > "$smd/mk/design.mk"
smd_own=$(shasum < "$smd/mk/design.mk")
smd_apply() { python3 "$S/apply.py" --target "$smd" --preset react-vite --level team --with design --var project_name=D --var description=x --var owner=acme "$@"; }
for mode in --dry-run ""; do
  smd_rc=0; smd_out=$(smd_apply --json $mode 2>/dev/null) || smd_rc=$?
  [ "$smd_rc" = 1 ] || miss "seams: a conflict on mk/design.mk ends the run with $smd_rc (${mode:-real run})"
  printf '%s' "$smd_out" | json '"mk/design.mk" in d["conflict"] and d["exit_code"] == 1' | grep -q True \
    || miss "seams: mk/design.mk is not reported as a conflict with exit code 1 (${mode:-real run})"
  smd_why=$(printf '%s' "$smd_out" | json 'd["skip_reasons"].get("mk/design.mk", "")')
  for target in design-guards ui-floor; do
    case "$smd_why" in *"$target"*) ;; *) miss "seams: the conflict on mk/design.mk does not name $target (${mode:-real run}: $smd_why)" ;; esac
  done
done
[ "$(shasum < "$smd/mk/design.mk")" = "$smd_own" ] || miss "seams: the repository's own mk/design.mk was changed"
smd_text=$(smd_apply 2>&1 || true)
case "$smd_text" in *"design-guards"*"ui-floor"*) ;; *) miss "seams: the plain report does not name the checks left out" ;; esac
case "$smd_text" in *"another name"*) ;; *) miss "seams: the plain report does not say how to join the checks" ;; esac
# The way out: any other name in mk/ is read too. Then the setup's file is written and its checks run.
mv "$smd/mk/design.mk" "$smd/mk/own-design.mk"
smd_rc=0; smd_apply --json >/dev/null 2>&1 || smd_rc=$?
[ "$smd_rc" = 0 ] || miss "seams: after renaming the repository's file the run still ends with $smd_rc"
smd_plan=$(make -C "$smd" -n check 2>&1 || true)
case "$smd_plan" in *"tools/design_guards.mjs"*) ;; *) miss "seams: after renaming, make check does not run the design guards" ;; esac
case "$smd_plan" in *"the repository own design check"*) ;; *) miss "seams: after renaming, make check lost the repository's own check" ;; esac
# The repository's own file may join the same checks itself: then nothing is left out.
smj="$TMP/seam-joined"; mkdir -p "$smj/mk" && git -C "$smj" init -q -b main
printf 'CHECK_TARGETS += design-guards\nHEAVY_TARGETS += \\\n  ui-floor # browser\n.PHONY: design-guards ui-floor\ndesign-guards ui-floor:\n\t@echo own\n' > "$smj/mk/design.mk"
smj_rc=0; smj_out=$(python3 "$S/apply.py" --target "$smj" --preset react-vite --level team --with design --var project_name=D --var description=x --var owner=acme --json 2>/dev/null) || smj_rc=$?
[ "$smj_rc" = 0 ] || miss "seams: a repository whose own mk/design.mk joins the same checks gets exit code $smj_rc"
printf '%s' "$smj_out" | json '"mk/design.mk" in d["conflict"] and "mk/design.mk" not in d["skip_reasons"]' | grep -q True \
  || miss "seams: checks the repository's own file joins are reported as left out"
# The wall of the upgrade path joins by putting itself first (`CHECK_TARGETS := upgrade ...`): it counts too.
smu="$TMP/seam-upgrade"; mkdir -p "$smu/mk" && git -C "$smu" init -q -b main
printf '# the repository own notes on upgrades\n' > "$smu/mk/upgrade.mk"
smu_rc=0; smu_out=$(python3 "$S/apply.py" --target "$smu" --preset python --var project_name=U --var description=x --var owner=acme --json 2>/dev/null) || smu_rc=$?
[ "$smu_rc" = 1 ] || miss "seams: a conflict on mk/upgrade.mk ends the run with $smu_rc"
case "$(printf '%s' "$smu_out" | json 'd["skip_reasons"].get("mk/upgrade.mk", "")')" in
  "not in make check: upgrade") ;;
  *) miss "seams: the conflict on mk/upgrade.mk does not name upgrade alone ($(printf '%s' "$smu_out" | json 'd["skip_reasons"].get("mk/upgrade.mk", "")'))" ;;
esac
# A link at that path keeps its own reason, and the checks left out are added to it.
sml="$TMP/seam-link"; mkdir -p "$sml/mk" && git -C "$sml" init -q -b main
printf '# elsewhere\n' > "$sml/elsewhere.mk"; ln -s ../elsewhere.mk "$sml/mk/upgrade.mk"
sml_why=$(python3 "$S/apply.py" --target "$sml" --preset python --var project_name=L --var description=x --var owner=acme --json 2>/dev/null | json 'd["skip_reasons"].get("mk/upgrade.mk", "")' || true)
case "$sml_why" in *"symbolic link"*"not in make check: upgrade"*) ;; *) miss "seams: a link where a joining file goes loses a reason ($sml_why)" ;; esac
# A file that joins nothing is a conflict as before: reported, left alone, and the run ends well.
smp="$TMP/seam-plain"; mkdir -p "$smp" && git -C "$smp" init -q -b main
echo 'root = true' > "$smp/.editorconfig"
smp_rc=0; smp_out=$(python3 "$S/apply.py" --target "$smp" --preset python --var project_name=P --var description=x --var owner=acme --json 2>/dev/null) || smp_rc=$?
[ "$smp_rc" = 0 ] || miss "seams: a conflict on a file that joins no check ends the run with $smp_rc"
printf '%s' "$smp_out" | json '".editorconfig" in d["conflict"]' | grep -q True || miss "seams: the repository's own .editorconfig is not reported as a conflict"

echo "ok  seams with other tools (or misses reported above)"
