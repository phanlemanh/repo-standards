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
# The policy every team repository receives names the agent pipeline only as a condition. One line
# said "the PR pipeline stops running its own reviewer agent" as a fact, also where no pipeline runs.
# Found on a repository with a feature loop and no agent workflows, while it took 0.10.3.
sm_said=$(grep -nE 'pipeline|reviewer agent' "$gs/governance/autonomy.yaml" | grep -v 'agent workflows' || true)
[ -z "$sm_said" ] || miss "seams: the policy says what the agent pipeline does without saying it is only with agent workflows: $sm_said"

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
#      and 4): every ci.yml has the summary job check and leaves _acceptance/** and the roadmap
#      page LO-TRINH.html out of the heavy tier's inputs; the agent pipeline's job is gate
seam_ci() { # <ci.yml>: nothing, or what is missing
  grep -q '^  check:$' "$1" || echo "no job check"
  grep -qE '^  HEAVY_NOT_INPUTS: ".*_acceptance/\*\*' "$1" || echo "_acceptance/** is an input of the heavy tier"
  grep -qE '^  HEAVY_NOT_INPUTS: "(.* )?LO-TRINH\.html[ "]' "$1" || echo "LO-TRINH.html is an input of the heavy tier"
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
cp "$ROOT/plugins/repo-setup/presets/ts-node/starter/dot.github/workflows/ci.yml" "$TMP/seam-ci.yml"
subst 's| LO-TRINH\.html||' "$TMP/seam-ci.yml"
[ -n "$(seam_ci "$TMP/seam-ci.yml")" ] || miss "seams: a ci.yml that reads LO-TRINH.html as an input goes unseen"

# 51f. design-assembly (docs/seam-contracts.md, sections 6 to 8): what the setup relies on in that
#      plugin, read at the version tests/fixtures/design-assembly/seam.json names. host-strings.json
#      beside it is a byte copy of the plugin's list of every string it reads in a repository's
#      Makefile and mk/ files. The plugin is never run here.
DAF="$ROOT/tests/fixtures/design-assembly"
da_fx() { python3 -c "import json,sys; d=json.load(open('$DAF/seam.json')); print($1)"; }
da_ver=$(da_fx 'd["version"]')
da_page=$(awk '/^## 6\. /{f=1} f' "$ROOT/docs/seam-contracts.md")
case "$da_page" in *"design-assembly $da_ver"*) ;; *) miss "seams: docs/seam-contracts.md does not say which version of design-assembly the fixtures were read at ($da_ver)" ;; esac
# The seven ledgers a repository has from birth: the list doctor reads, the fixture and the page agree.
da_birth=$(python3 -c "import json,sys; sys.path.insert(0, '$S'); import design_ledgers as d; print(json.dumps(list(d.BIRTH_LEDGERS)), d.TOOL_STAMP)" 2>&1 || true)
[ "$da_birth" = "$(da_fx 'json.dumps(d["birth_ledgers"]), d["tool_stamp"]["file"]')" ] \
  || miss "seams: the birth ledgers or the tool stamp of design_ledgers.py differ from the fixture: $da_birth"
[ "$(da_fx 'len(d["birth_ledgers"])')" = 7 ] || miss "seams: the fixture does not name seven birth ledgers"
for ledger in $(da_fx '" ".join(d["birth_ledgers"])'); do
  case "$da_page" in *"\`$ledger\`"*) ;; *) miss "seams: docs/seam-contracts.md does not name the birth ledger $ledger" ;; esac
done

# 51g. the strings the plugin reads, on a repository the setup gives a design floor (no install step).
#      Each read the plugin lists is one this setup answers for, or one in the plugin's own gate step;
#      a read this side does not know is red, so a new one in the plugin is a decision here.
da="$TMP/da-floor"; mkdir -p "$da" && git -C "$da" init -q -b main
python3 "$S/apply.py" --target "$da" --preset react-vite --level starter --with design --var project_name=D --var description=x --var owner=acme >/dev/null
da_host() { # <repo> <host-strings.json>: nothing, or what this setup no longer carries
  python3 - "$1" "$2" <<'PY'
import json, pathlib, re, sys
repo, strings = pathlib.Path(sys.argv[1]), json.loads(pathlib.Path(sys.argv[2]).read_text(encoding="utf-8"))
make = (repo / "Makefile").read_text(encoding="utf-8") if (repo / "Makefile").is_file() else ""
mks = sorted((repo / "mk").glob("*.mk"))
mk_text = {p.name: p.read_text(encoding="utf-8") for p in mks}
pkg = (repo / "package.json").read_text(encoding="utf-8") if (repo / "package.json").is_file() else ""
rules = {}
for line in make.splitlines():
    m = re.match(r"^([A-Za-z0-9_.-]+)\s*::?(?!=)(.*)$", line)
    if m:
        rules.setdefault(m.group(1), []).extend(m.group(2).split("##")[0].split())
def reaches(word, start="check"):
    seen, todo = set(), [start]
    while todo:
        t = todo.pop()
        if t in seen:
            continue
        seen.add(t)
        for w in rules.get(t, []):
            if w == word:
                return True
            todo.append(w)
    return False
def defined_before(var, name="design-assembly.mk"):
    return any(re.search(rf"^{var}\s*\+?=", text, re.M) for f, text in mk_text.items() if f < name)
GATE = "mk/design-assembly.mk"   # the plugin's own gate step: this setup writes nothing there
ours_tools = [t["path"] for t in strings["known_tools"]["tools"] if not t["path"].startswith("tools/design-assembly/")]
answer = {
    "include-mk": lambda r: re.search(r["text"], make, re.M),
    "rule-line": lambda r: any(re.match(r["text"], line) and line.startswith("check:") for line in make.splitlines()),
    "check-target": lambda r: "check" in rules,
    "check-targets-word": lambda r: reaches(r["text"]),
    "check-runs-this": lambda r: reaches("$(CHECK_TARGETS)"),
    "gate-joins-check": lambda r: not (repo / GATE).exists(),
    "gate-runs-check": lambda r: not (repo / GATE).exists(),
    "gate-step-file": lambda r: not (repo / GATE).exists(),
    "tool-pointer": lambda r: all(any(t in x for x in [make, pkg, *mk_text.values()]) for t in ours_tools),
    "test-in-check-targets": lambda r: defined_before("DERIVED_TARGETS"),
    "derived-targets-defined": lambda r: defined_before("DERIVED_TARGETS") and re.search(r"^derived:.*\$\$\(DERIVED_TARGETS\)", "\n".join(mk_text.values()), re.M),
    "derived-files": lambda r: defined_before("DERIVED_FILES") and re.search(r"untracked \$\(DERIVED_FILES\)", "\n".join(mk_text.values())),
}
if not strings.get("workflows", "").startswith("None"):
    print("the plugin reads a workflow now: " + strings.get("workflows", ""))
for r in strings["reads"]:
    if r["id"] not in answer:
        print(f"the plugin reads {r['id']} ({r['text']}), which this setup does not answer for")
    elif not answer[r["id"]](r):
        print(f"{r['id']}: {r['why']}")
for w in strings["writes"]:
    if w["file"] != GATE:
        print(f"the plugin writes {w['file']}, outside its gate step")
PY
}
da_out=$(da_host "$da" "$DAF/host-strings.json" 2>&1)
[ -z "$da_out" ] || miss "seams: a floored repository no longer carries what design-assembly reads: $da_out"
# the red direction: a Makefile that reads no mk/ file, a read this side does not know
cp -R "$da" "$TMP/da-red"; subst '/^-include mk\/\*\.mk/d' "$TMP/da-red/Makefile"
case "$(da_host "$TMP/da-red" "$DAF/host-strings.json")" in *include-mk*) ;; *) miss "seams: a Makefile that reads no mk/ file goes unseen" ;; esac
python3 -c "import json,sys; d=json.load(open(sys.argv[1])); d['reads'].append({'id':'new-read','text':'X','why':'x'}); json.dump(d, open(sys.argv[2],'w'))" "$DAF/host-strings.json" "$TMP/da-strings.json"
case "$(da_host "$da" "$TMP/da-strings.json")" in *new-read*) ;; *) miss "seams: a string the plugin starts reading goes unseen" ;; esac
# The plugin's gate step, built from the lines it writes, joins the gate where docs/seam-contracts.md says.
da_g="$TMP/da-gate"; cp -R "$da" "$da_g"
python3 - "$DAF/host-strings.json" "$da_g/mk/design-assembly.mk" <<'PY'
import json, sys
lines = [w["text"].replace("<each file the tool data keeps out of git>", "design/drawn-by-the-tool.json")
         for w in json.load(open(sys.argv[1]))["writes"]]
recipes = ".PHONY: design-assembly design-derived\ndesign-assembly:\n\t@node tools/design-assembly/check.mjs\ndesign-derived:\n\t@echo design-derived ran\n"
open(sys.argv[2], "w").write("\n".join(lines) + "\n" + recipes)
PY
case "$(smk_plan "$da_g" check-quick)" in *"tools/design-assembly/check.mjs"*) ;; *) miss "seams: make check-quick does not run the gate step design-assembly writes" ;; esac
case "$(smk_plan "$da_g" derived)" in *"design-derived ran"*) ;; *) miss "seams: make derived does not run the target the gate step adds to DERIVED_TARGETS" ;; esac
da_joined=$(python3 -c "import sys; sys.path.insert(0, '$S'); import make_wiring; print(make_wiring.joined_targets(open(sys.argv[1], 'rb').read()))" "$da_g/mk/design-assembly.mk")
[ "$da_joined" = "['design-assembly', 'design-derived']" ] || miss "seams: make_wiring does not see the targets of the gate step: $da_joined"
# One writer per ledger: the setup writes none of the ledgers, the stamp, the tool, the gate step or
# the other files the plugin's adopt --starter lays.
for f in $(da_fx '" ".join(d["birth_ledgers"] + [d["tool_stamp"]["file"]] + d["adopt_starter"]["also_writes"])') mk/design-assembly.mk tools/design-assembly; do
  [ ! -e "$da/$f" ] || miss "seams: the setup writes $f, which is design-assembly's"
done

# 51h. every clone of a repository with the design floor has the plugin: .claude/settings.json knows
#      its marketplace and enables it, beside the optional repo-standards entry; without the floor,
#      nothing of it.
da_settings() { # <repo>: the marketplaces and the plugins its settings name, or why they cannot be read
  python3 - "$1/.claude/settings.json" <<'PY'
import json, sys
try:
    s = json.load(open(sys.argv[1], encoding="utf-8"))
except (OSError, ValueError) as exc:
    print(f"unreadable: {exc}"); sys.exit()
m = s.get("extraKnownMarketplaces", {})
print(" ".join(f"{k}={v['source'].get('repo', v['source'].get('url'))}" for k, v in sorted(m.items())),
      "|", " ".join(f"{k}={v}" for k, v in sorted(s.get("enabledPlugins", {}).items())))
PY
}
da_m=$(da_fx 'd["marketplace"]')
[ "$(da_settings "$da")" = "design-assembly=$da_m | design-assembly@design-assembly=True" ] \
  || miss "seams: a repository with the design floor does not enable design-assembly: $(da_settings "$da")"
da2="$TMP/da-floor-market"; mkdir -p "$da2" && git -C "$da2" init -q -b main
python3 "$S/apply.py" --target "$da2" --preset react-vite --with design --var marketplace=phanlemanh/repo-standards --var project_name=D --var description=x --var owner=acme >/dev/null
[ "$(da_settings "$da2")" = "design-assembly=$da_m repo-standards=phanlemanh/repo-standards | design-assembly@design-assembly=True repo-setup@repo-standards=True" ] \
  || miss "seams: with a marketplace too, the settings do not name both plugins: $(da_settings "$da2")"
da3="$TMP/da-nofloor"; mkdir -p "$da3" && git -C "$da3" init -q -b main
python3 "$S/apply.py" --target "$da3" --preset react-vite --var marketplace=phanlemanh/repo-standards --var project_name=D --var description=x --var owner=acme >/dev/null
[ "$(da_settings "$da3")" = "repo-standards=phanlemanh/repo-standards | repo-setup@repo-standards=True" ] \
  || miss "seams: without the design floor the settings changed: $(da_settings "$da3")"

# 51i. an upgrade from a release that did not enable the plugin: an untouched settings.json takes the
#      new lines, an edited one is merged three ways and keeps the edit. The variable the earlier
#      template used still renders what that release wrote, or no base is found.
da_arch="$TMP/da-arch"; da_old="$da_arch/repo-setup-v0.0.1"; mkdir -p "$da_arch"
cp -R "$ROOT/plugins/repo-setup" "$da_old"; find "$da_old" -name __pycache__ -prune -exec rm -rf {} +
subst 's/"version": "[^"]*"/"version": "0.0.1"/' "$da_old/.claude-plugin/plugin.json"
subst 's/{{plugins_enabled}}/{{plugin_settings}}/' "$da_old/presets/_core/starter/dot.claude/settings.json.tmpl"
grep -q '{{plugin_settings}}' "$da_old/presets/_core/starter/dot.claude/settings.json.tmpl" || miss "seams: the stand-in release does not use the earlier settings placeholder"
for kind in untouched edited; do
  r="$TMP/da-up-$kind"; mkdir -p "$r" && git -C "$r" init -q -b main
  python3 "$da_old/scripts/apply.py" --target "$r" --preset react-vite --with design --var project_name=D --var description=x --var owner=acme >/dev/null
  case "$(da_settings "$r")" in *design-assembly*) miss "seams: the stand-in release already enables design-assembly ($kind)" ;; esac
  [ "$kind" = untouched ] || python3 -c "import pathlib,sys; p=pathlib.Path(sys.argv[1]); t=p.read_text(); o='      \"Bash(make:*)\",\n'; assert o in t; p.write_text(t.replace(o, o + '      \"Bash(npm test:*)\",\n', 1))" "$r/.claude/settings.json"
  [ "$kind" = untouched ] || grep 'npm test' "$r/.claude/settings.json" >/dev/null || miss "seams: the edit of settings.json was not made"
  rc=0; out=$(python3 "$S/apply.py" --target "$r" --base-from "$da_arch" --json 2>/dev/null) || rc=$?
  [ "$rc" = 0 ] || miss "seams: upgrading a $kind settings.json ends with $rc"
  want=$([ "$kind" = untouched ] && echo updated || echo merged)
  printf '%s' "$out" | json "'.claude/settings.json' in d['$want']" | grep True >/dev/null || miss "seams: an $kind settings.json is not $want: ${out:0:300}"
  [ "$(da_settings "$r")" = "design-assembly=$da_m | design-assembly@design-assembly=True" ] || miss "seams: after upgrading a $kind settings.json: $(da_settings "$r")"
  [ "$kind" = untouched ] || grep '"Bash(npm test:\*)"' "$r/.claude/settings.json" >/dev/null || miss "seams: the upgrade lost the repository's edit of settings.json"
done

# 51j. where the call sits in the skills: /repo-setup:new lays the birth ledgers through the plugin's
#      adopt with --starter, after the install commands and the domain, before the verification;
#      handles each exit code as the fixture says; offers the guide once, at the finish; asks
#      nothing for anyone.
da_sk="$ROOT/plugins/repo-setup/skills"
da_step=$(awk '/^## 6\./{f=1;next} /^## 7\./{f=0} f' "$da_sk/new/SKILL.md")
da_line() { printf '%s\n' "$da_step" | grep -nF -- "$1" | head -1 | cut -d: -f1 || true; }
da_install=$(da_line 'next_commands.install'); da_domain=$(da_line 'ontology-add'); da_call=$(da_line '/design-assembly:adopt'); da_verify=$(da_line 'next_commands.verify')
if [ -z "$da_call" ] || [ -z "$da_install" ] || [ -z "$da_domain" ] || [ -z "$da_verify" ] \
  || [ "$da_call" -le "$da_install" ] || [ "$da_call" -le "$da_domain" ] || [ "$da_call" -ge "$da_verify" ]; then
  miss "seams: /repo-setup:new does not call design-assembly's adopt after the install and the domain and before the verification (lines: install $da_install, domain $da_domain, call $da_call, verify $da_verify)"
fi
for word in --starter 'never answer' "$da_m" design-assembly@design-assembly; do
  case "$da_step" in *"$word"*) ;; *) miss "seams: step 6 of /repo-setup:new lacks: $word" ;; esac
done
# Exit 2 is a wrong call or a repository the plugin cannot read. A brand colour is not a reason for it:
# from its decision 0087 the plugin lays the birth ledgers there too and records the values as the
# repository's own, so the step never tells the person to adopt again without --starter.
for word in 'brand colour' 'keeps those values'; do
  case "$da_step" in *"$word"*) miss "seams: step 6 of /repo-setup:new still ties exit 2 to: $word" ;; esac
done
# The step names exit 2 in the words the fixture read from the plugin, so a fixture read again at a
# version that gives exit 2 another meaning turns this red until the step says it too.
da_m2=$(da_fx "d['adopt_starter']['exit']['2']['means']")
printf '%s\n' "$da_step" | grep -F '`2`' | grep -F -- "$da_m2" >/dev/null \
  || miss "seams: step 6 of /repo-setup:new does not say exit 2 means what the fixture read: $da_m2"
# The one new place a person appears (spec 0013 of design-assembly, question 2): an offer, at the end.
# Which step it offers follows the brand_primary answer this setup holds: the plugin's adopt where the
# repository was set up with a brand colour (its status says the guide is not for such a repository),
# its guide otherwise. The plugin's `next:` line does not tell the two apart, so it decides nothing.
da_end=$(awk '/^## 8\./{f=1;next} /^## /{f=0} f' "$da_sk/new/SKILL.md")
for word in brand_primary /design-assembly:adopt /design-assembly:new 'now or later' 'never answer'; do
  case "$da_end" in *"$word"*) ;; *) miss "seams: the finish of /repo-setup:new does not offer, once, the right step of design-assembly: $word" ;; esac
done
case "$da_end" in *'next:'*) miss "seams: the finish of /repo-setup:new lets the plugin's next: line choose the step" ;; esac
for code in 0 1 2; do
  says=$(da_fx "d['adopt_starter']['exit']['$code']['the setup says']")
  printf '%s\n' "$da_step" | grep -F "\`$code\`" | grep -F "$says" >/dev/null || miss "seams: step 6 of /repo-setup:new does not treat exit $code as: $says"
done
for flag in $(da_fx '" ".join(d["adopt_starter"]["flags_that_speak_for_a_person"])'); do
  case "$da_step" in *"$flag"*) miss "seams: step 6 of /repo-setup:new passes $flag, which speaks for a person" ;; esac
done
# An existing repository: the plugin's audit, then its adopt without --starter; doctor points at upgrade.
da_ad=$(cat "$da_sk/adopt/SKILL.md")
da_a1=$(printf '%s\n' "$da_ad" | grep -nF '/design-assembly:audit' | head -1 | cut -d: -f1 || true)
da_a2=$(printf '%s\n' "$da_ad" | grep -nF '/design-assembly:adopt' | head -1 | cut -d: -f1 || true)
{ [ -n "$da_a1" ] && [ -n "$da_a2" ] && [ "$da_a1" -lt "$da_a2" ]; } || miss "seams: /repo-setup:adopt does not run design-assembly's audit, then its adopt"
case "$da_ad" in *'without `--starter`'*) ;; *) miss "seams: /repo-setup:adopt does not say an existing repository adopts without --starter" ;; esac
for word in /design-assembly:upgrade --design-assembly-version 'claude plugin list --json' projectPath 'pass nothing'; do
  grep -qF -- "$word" "$da_sk/doctor/SKILL.md" || miss "seams: /repo-setup:doctor lacks: $word"
done

# 51k. doctor names the birth ledgers that are missing and a tool stamp behind the installed plugin,
#      from the files in the repository; it runs nothing of the plugin, and the notice is never scored.
da_doc() { python3 "$S/doctor.py" --target "$1" --json "${@:2}" 2>/dev/null | json "$DA_Q"; }
DA_Q='d["design_ledgers"]["missing"]'
[ "$(da_doc "$da")" = "$(da_fx 'd["birth_ledgers"]')" ] || miss "seams: doctor does not name the seven missing birth ledgers: $(da_doc "$da")"
da_score0=$(DA_Q='d["score"]' da_doc "$da")
for f in $(da_fx '" ".join(d["birth_ledgers"])'); do mkdir -p "$(dirname "$da/$f")"; echo '{}' > "$da/$f"; done
printf '{\n  "version": "0.34.0",\n  "tree": "0"\n}\n' > "$da/design/tool-stamp.json"
DA_Q='d["design_ledgers"]'
[ "$(da_doc "$da" --design-assembly-version 0.35.0)" = "{'missing': [], 'stamp': '0.34.0', 'installed': '0.35.0', 'behind': True, 'next': '/design-assembly:upgrade'}" ] \
  || miss "seams: doctor does not say the tool stamp is behind: $(da_doc "$da" --design-assembly-version 0.35.0)"
[ "$(da_doc "$da" --design-assembly-version 0.34.0)" = "{'missing': [], 'stamp': '0.34.0', 'installed': '0.34.0', 'behind': False, 'next': None}" ] \
  || miss "seams: doctor says a stamp at the installed version is behind: $(da_doc "$da" --design-assembly-version 0.34.0)"
[ "$(da_doc "$da")" = "{'missing': [], 'stamp': '0.34.0', 'installed': None, 'behind': None, 'next': None}" ] \
  || miss "seams: without the installed version doctor guesses: $(da_doc "$da")"
[ "$(DA_Q='d["score"]' da_doc "$da")" = "$da_score0" ] || miss "seams: the design ledgers changed the score of doctor"
da_text=$(python3 "$S/doctor.py" --target "$da" --design-assembly-version 0.35.0 2>&1 || true)
case "$da_text" in *"0.34.0"*"0.35.0"*"/design-assembly:upgrade"*) ;; *) miss "seams: the doctor report does not say the stamp is behind and what runs it up" ;; esac
rm "$da/design/screens.yaml"
da_text=$(python3 "$S/doctor.py" --target "$da" 2>&1 || true)
case "$da_text" in *"design/screens.yaml"*"/design-assembly:adopt"*) ;; *) miss "seams: the doctor report does not name a missing birth ledger and what lays it" ;; esac
[ "$(da_doc "$smk")" = None ] || miss "seams: doctor speaks of design ledgers in a repository without the floor: $(da_doc "$smk")"

echo "ok  seams with other tools (or misses reported above)"
