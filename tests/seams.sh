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
dry "$sm" | grep 'ruleset on' | grep ', gate$' >/dev/null || miss "seams: without agent workflows, github_setup does not require the gate the policy names: $(dry "$sm" | grep 'ruleset on')"
sm_fresh "$gs" "$sm"
sm_set "$sm" '^  check: ""$' '  check: gate'
sm_set "$sm" '^default: medium$' 'default: low'
sm_ok "$sm" || miss "seams: without agent workflows, a proof named gate is refused ($(cat "$sm.err"))"
[ "$(cd "$sm" && python3 -B tools/autonomy.py --files README.md 2>/dev/null | json 'd["proof"]')" = gate ] \
  || miss "seams: without agent workflows, a proof named gate is not handed on as the proof"
dry "$sm" | grep 'ruleset on' | grep ', gate$' >/dev/null || miss "seams: without agent workflows, github_setup does not require the proof named gate: $(dry "$sm" | grep 'ruleset on')"
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
  printf '%s' "$smd_out" | json '"mk/design.mk" in d["conflict"] and d["exit_code"] == 1' | grep True >/dev/null \
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
printf '%s' "$smj_out" | json '"mk/design.mk" in d["conflict"] and "mk/design.mk" not in d["skip_reasons"]' | grep True >/dev/null \
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
printf '%s' "$smp_out" | json '".editorconfig" in d["conflict"]' | grep True >/dev/null || miss "seams: the repository's own .editorconfig is not reported as a conflict"

# 51c. the four lists of make (docs/seam-contracts.md, section 1): a target another tool adds from its
#      own mk/ file runs where the page says. CHECK_TARGETS in the light tier (make check-quick, behind
#      the required check), HEAVY_TARGETS in the heavy tier only, DERIVED_TARGETS in make derived, and a
#      file named in DERIVED_FILES turns make check red once it is in git, when its first line carries
#      sha256: (the mark of a drawn file that is not markdown). An unmarked file is the repository's own.
smk="$TMP/seam-make"; mkdir -p "$smk" && git -C "$smk" init -q -b main
python3 "$S/apply.py" --target "$smk" --preset ts-node --level team --var project_name=M --var description=x --var owner=acme >/dev/null
cat > "$smk/mk/other-tool.mk" <<'MK'
CHECK_TARGETS += seam-light
HEAVY_TARGETS += seam-heavy
DERIVED_TARGETS += seam-draw
DERIVED_FILES += seam/drawn.txt
.PHONY: seam-light seam-heavy seam-draw
seam-light:
	@echo seam-light ran
seam-heavy:
	@echo seam-heavy ran
seam-draw:
	@mkdir -p seam && echo '# drawn by the other tool, sha256:0123' > seam/drawn.txt
MK
# smk_plan <dir> <target>: what make would run, or why it cannot say
smk_plan() { make -C "$1" -n "$2" 2>&1 || true; }
smk_runs() { # <dir> <target> <recipe> <yes|no>
  case "$(smk_plan "$1" "$2")" in
    *"$3"*) [ "$4" = yes ] || miss "seams: make $2 runs $3, which the contract keeps out of it" ;;
    *) [ "$4" = no ] || miss "seams: make $2 does not run $3: $(smk_plan "$1" "$2" | head -3)" ;;
  esac
}
smk_runs "$smk" check-quick "seam-light ran" yes
smk_runs "$smk" check-quick "seam-heavy ran" no
smk_runs "$smk" check-heavy "seam-heavy ran" yes
smk_runs "$smk" check-heavy "seam-light ran" no
smk_runs "$smk" derived "drawn.txt" yes
git -C "$smk" add -A >/dev/null 2>&1
mkdir -p "$smk/seam" && echo 'a file of the repository own' > "$smk/seam/drawn.txt" && git -C "$smk" add -f seam/drawn.txt
smk_out=$( (cd "$smk" && make derived-untracked) 2>&1) || miss "seams: an unmarked file at a DERIVED_FILES path is taken for a drawn one: $smk_out"
echo '# drawn by the other tool, sha256:0123' > "$smk/seam/drawn.txt" && git -C "$smk" add -f seam/drawn.txt
smk_out=$( (cd "$smk" && make derived-untracked) 2>&1) && miss "seams: a drawn file named in DERIVED_FILES is in git and make check stays green"
case "$smk_out" in *seam/drawn.txt*) ;; *) miss "seams: the drawn file in git that DERIVED_FILES names is not named: $smk_out" ;; esac
# the red direction, on a copy: a Makefile whose light tier forgets CHECK_TARGETS is caught
smk2="$TMP/seam-make-red"; rm -rf "$smk2"; cp -R "$smk" "$smk2"
subst 's/^check-quick: \$(CHECK_TARGETS)/check-quick:/' "$smk2/Makefile"
case "$(smk_plan "$smk2" check-quick)" in *"seam-light ran"*) miss "seams: the check of the light tier passes on a Makefile that does not run CHECK_TARGETS" ;; esac

# 51d. affected.mjs --json (docs/seam-contracts.md, section 2): the keys the page names are exactly the
#      keys ui_select.mjs reads from the answer, so neither can change alone
seam_keys() { # <page> <ui_select.mjs>: "same" or what differs
  python3 - "$1" "$2" <<'PY'
import pathlib, re, sys
page = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8") if pathlib.Path(sys.argv[1]).exists() else ""
code = pathlib.Path(sys.argv[2]).read_text(encoding="utf-8")
part = page.split("## 2.", 1)[1].split("\n## ", 1)[0] if "## 2." in page else ""
named = set(re.findall(r"^\| `([a-z]+)` \|", part, re.M))
read = set(re.findall(r"\bdata\.([a-z]+)\b", code))
print("same" if named and named == read else f"page names {sorted(named)}, ui_select.mjs reads {sorted(read)}")
PY
}
sk_ui="$ROOT/plugins/repo-setup/capabilities/design/starter/tools/ui_select.mjs"
sk=$(seam_keys "$ROOT/docs/seam-contracts.md" "$sk_ui")
[ "$sk" = same ] || miss "seams: the keys of affected.mjs differ between docs/seam-contracts.md and ui_select.mjs: $sk"
cp "$ROOT/docs/seam-contracts.md" "$TMP/seam-page.md"; subst '/^| `grep` |/d' "$TMP/seam-page.md"
[ "$(seam_keys "$TMP/seam-page.md" "$sk_ui")" != same ] || miss "seams: a key left out of the page goes unseen"

# 51e. the names and the list other tools read in the workflows (docs/seam-contracts.md, sections 3
#      and 4): every ci.yml has the summary job check and leaves _acceptance/** out of the heavy
#      tier's inputs; the agent pipeline's job is gate
seam_ci() { # <ci.yml>: nothing, or what is missing
  grep -q '^  check:$' "$1" || echo "no job check"
  grep -qE '^  HEAVY_NOT_INPUTS: ".*_acceptance/\*\*' "$1" || echo "_acceptance/** is an input of the heavy tier"
}
for ci in "$ROOT"/plugins/repo-setup/presets/*/starter/dot.github/workflows/ci.yml; do
  sc=$(seam_ci "$ci")
  [ -z "$sc" ] || miss "seams: ${ci#"$ROOT"/}: $sc"
done
grep -q '^  gate:$' "$ROOT/plugins/repo-setup/capabilities/github-agents/team/dot.github/workflows/pr-pipeline.yml" \
  || miss "seams: the agent pipeline has no job named gate"
cp "$ROOT/plugins/repo-setup/presets/ts-node/starter/dot.github/workflows/ci.yml" "$TMP/seam-ci.yml"
subst 's| _acceptance/\*\*||' "$TMP/seam-ci.yml"
[ -n "$(seam_ci "$TMP/seam-ci.yml")" ] || miss "seams: a ci.yml that reads _acceptance/** as an input goes unseen"

echo "ok  seams with other tools (or misses reported above)"
