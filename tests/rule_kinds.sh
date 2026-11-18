# 50. rule kinds (docs/superpowers/specs/2026-11-18-rule-kinds-design.md, RS7): every list item in
#     the AGENTS.md fragments says what holds it (a machine, a word, or "not a rule"), a machine
#     must point at a test that proves it, and the generated AGENTS.md ends with the section that
#     names the machines this repository has. Sourced by tests/run.sh; uses its ROOT, S, TMP, json,
#     subst and miss.

# A small plugin tree: one fragment, one check in the registry, one tagged test.
rk="$TMP/rk"; rk_frag="$rk/root/presets/_core/starter/+AGENTS.md"; mkdir -p "$rk_frag" "$rk/tests"
rk_tool() { python3 "$S/rule_kinds.py" check --root "$rk/root" --tests "$rk/tests" "$@"; }
rk_registry() {
  cat > "$rk/root/rule-checks.toml" <<'T'
[summary]
heading = "## What holds these rules"
intro = "A machine catches a miss of these:"
closing = "Nothing listed here covers the other rules."
closing_alone = "No machine is listed."
[checks.commit-format]
catches = "commit format"
reaction = "`conventional-commits` goes red (GitHub)"
kind = "red"
present_when = ".github/workflows/pr-title.yml"
T
}
rk_fragment() { # the fragment, with $1 as the kind of the parent item ("" for none)
  cat > "$rk_frag/10-a.md" <<M
## Rules

- Commits follow the format. <!-- kept: commit-format -->
- A rule on two lines,
  kept by word. <!-- kept: word -->
- Parent:${1:+ <!-- kept: $1 -->}
  - child one <!-- kept: none -->

\`\`\`
- not an item
\`\`\`
M
}
# rk_says <words>: the tool is red and its report has these words
rk_says() {
  local out
  if out=$(rk_tool 2>&1); then miss "rule kinds: the check passes, expected: $1"; return; fi
  echo "$out" | grep -qF -- "$1" || miss "rule kinds: no report of '$1': $(echo "$out" | head -3)"
}
rk_registry; printf '# rule-check: commit-format\n' > "$rk/tests/x.sh"

# 50a. an item without a kind is the one problem: a line of two, a nested item and a line in a
#      fenced block are read as they are
rk_fragment ""
out=$(rk_tool 2>&1) && miss "rule kinds: an item without a kind passes"
echo "$out" | grep -q '10-a.md:6: list item has no kind' || miss "rule kinds: no line for the item without a kind: $out"
[ "$(echo "$out" | grep -c '10-a.md')" = 1 ] || miss "rule kinds: a fenced line or a nested item is misread: $out"

# 50b. every item has one kind: green, and the last line is the count
rk_fragment word
out=$(rk_tool 2>&1) || miss "rule kinds: a fully labelled tree fails: $out"
[ "$(echo "$out" | tail -1)" = "rule kinds: 1 held by a machine, 2 kept by word, 1 not rules" ] \
  || miss "rule kinds: the count line reads: $(echo "$out" | tail -1)"

# 50c. two kinds on one item; a kind outside any item
subst 's|^- Commits follow the format\. |- Commits follow the format. <!-- kept: word --> |' "$rk_frag/10-a.md"
rk_says "10-a.md:3: list item has two kinds"
rk_fragment word; printf '\nA paragraph with a kind. <!-- kept: word -->\n' >> "$rk_frag/10-a.md"
rk_says "10-a.md:13: marker outside a list item"

# 50d. a machine nobody registered; a machine without a tagged test
rk_fragment nope
rk_says "10-a.md:6: unknown check 'nope'"
rk_fragment word; rm "$rk/tests/x.sh"
rk_says "check 'commit-format' has no test tagged '# rule-check: commit-format'"
python3 "$S/rule_kinds.py" check --root "$rk/root" >/dev/null 2>&1 || miss "rule kinds: without --tests the tag is still asked for"
printf '# rule-check: commit-format\n' > "$rk/tests/x.sh"

# 50e. the registry itself: a field left out, a kind that is none of the three, a check no rule
#      uses, no registry at all
subst '/^present_when/d' "$rk/root/rule-checks.toml"
rk_says "check 'commit-format' lacks present_when"
rk_registry; subst 's/^kind = "red"/kind = "blue"/' "$rk/root/rule-checks.toml"
rk_says "check 'commit-format': kind must be red, refuses or raises-tier"
rk_registry
printf '[checks.spare]\ncatches = "x"\nreaction = "y"\nkind = "refuses"\npresent_when = "z"\n' >> "$rk/root/rule-checks.toml"
printf '# rule-check: spare\n' >> "$rk/tests/x.sh"
rk_says "check 'spare' is not used by any rule"
rm "$rk/root/rule-checks.toml"
rk_says "rule-checks.toml is missing"
rk_registry

# 50f. --json: the same answer for a program
rk_fragment ""
{ rk_tool --json 2>/dev/null || true; } | json 'str(d["ok"]) + " " + str(len(d["problems"])) + " " + str(d["total"]) + " " + str(sorted(d["counts"]))' \
  | grep -qx "False 1 {'machine': 1, 'word': 1, 'none': 1} \['presets/_core/starter/+AGENTS.md/10-a.md'\]" \
  || miss "rule kinds: --json does not give ok, problems, counts and total"
rk_fragment word

# rk_finish <present paths, comma separated> <new|adopt> [plugin root]: what `finish` makes of the
# small fragment
rk_finish() { python3 - "$S" "${3:-$rk/root}" "$1" "$2" "$rk_frag/10-a.md" 2>/dev/null <<'PY' || true
import sys
sys.path.insert(0, sys.argv[1])
from pathlib import Path
import rule_kinds
have = set(filter(None, sys.argv[3].split(",")))
text = Path(sys.argv[5]).read_bytes()
sys.stdout.buffer.write(rule_kinds.finish(text, Path(sys.argv[2]), lambda p: p in have, sys.argv[4] == "adopt"))
PY
}
rk_stripped() {
  cat <<'M'
## Rules

- Commits follow the format.
- A rule on two lines,
  kept by word.
- Parent:
  - child one

```
- not an item
```
M
}

# 50g. the check is present: the kinds go, and the section names the check, then the other rules
{ rk_stripped; cat <<'M'

## What holds these rules

A machine catches a miss of these:

- commit format: `conventional-commits` goes red (GitHub)

Nothing listed here covers the other rules.
M
} > "$rk/want-present.md"
rk_finish .github/workflows/pr-title.yml new > "$rk/got.md"
cmp -s "$rk/want-present.md" "$rk/got.md" || miss "rule kinds: the section for a present check differs: $(diff "$rk/want-present.md" "$rk/got.md" | head -6)"

# 50h. the check is not in this repository: no list, the sentence for a repository without machines
{ rk_stripped; printf '\n## What holds these rules\n\nNo machine is listed.\n'; } > "$rk/want-absent.md"
rk_finish "" new > "$rk/got.md"
cmp -s "$rk/want-absent.md" "$rk/got.md" || miss "rule kinds: the section without machines differs: $(diff "$rk/want-absent.md" "$rk/got.md" | head -6)"

# 50i. adopt: the kinds go, no section
rk_stripped > "$rk/want-adopt.md"
rk_finish .github/workflows/pr-title.yml adopt > "$rk/got.md"
cmp -s "$rk/want-adopt.md" "$rk/got.md" || miss "rule kinds: adopt does not give the fragment without kinds and without a section"

# 50j. templates without a registry (every release before this one): not one byte changes
mkdir -p "$rk/bare"
rk_finish .github/workflows/pr-title.yml new "$rk/bare" > "$rk/got.md"
cmp -s "$rk_frag/10-a.md" "$rk/got.md" || miss "rule kinds: without a registry the text is changed"

# 50k. a release before rule kinds, rebuilt by this code, gives the AGENTS.md it gave then. The
#      fragments of that release are kept in tests/fixtures/rule-kinds/pre; the hashes are what
#      the code before this change wrote for these three installs.
# rk_release <dir> <version>: this plugin with that version; "pre" as third word takes the
# registry away and puts the fragments of the release before rule kinds in place
rk_release() {
  mkdir -p "$(dirname "$1")"; cp -R "$ROOT/plugins/repo-setup" "$1"
  find "$1" -name __pycache__ -prune -exec rm -rf {} +
  subst "s/\"version\": \"[^\"]*\"/\"version\": \"$2\"/" "$1/.claude-plugin/plugin.json"
  if [ "${3:-}" = pre ]; then
    rm -f "$1/rule-checks.toml"
    cp -R "$ROOT/tests/fixtures/rule-kinds/pre/." "$1/"
  fi
}
# rk_install <plugin dir> <target> <apply arguments...>
rk_install() {
  local plugin="$1" target="$2"; shift 2
  mkdir -p "$target"; git -C "$target" init -q -b main
  python3 "$plugin/scripts/apply.py" --target "$target" "$@" \
    --var project_name=R --var description=x --var owner=acme >/dev/null
}
rk_sha() { python3 -c "import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())" "$1"; }
rk_old="$TMP/rk-arch/repo-setup-v0.0.1"; rk_release "$rk_old" 0.0.1 pre
rk_install "$rk_old" "$TMP/rk-pre-s" --preset ts-node
rk_install "$rk_old" "$TMP/rk-pre-t" --preset ts-api --level team --archetype service-api --deploy container --with mcp,ai,github-agents
rk_install "$rk_old" "$TMP/rk-pre-p" --preset claude-plugin --level team
[ "$(rk_sha "$TMP/rk-pre-s/AGENTS.md")" = 0b55750fd1c635e037aca79e69fd50a0de67b7991ea9573a8537da918bff1ce0 ] || miss "rule kinds: an older release's AGENTS.md is rebuilt differently (ts-node starter)"
[ "$(rk_sha "$TMP/rk-pre-t/AGENTS.md")" = cd5c95c267724b65e3e7bca557ee3eae13c110700594415209e83044a60bb9a9 ] || miss "rule kinds: an older release's AGENTS.md is rebuilt differently (ts-api team, every layer)"
[ "$(rk_sha "$TMP/rk-pre-p/AGENTS.md")" = a101f60d3b4c4a9a88b6179b06551a593330397f97ebd93f3b0ec94f3a8b1f6c ] || miss "rule kinds: an older release's AGENTS.md is rebuilt differently (claude-plugin team)"

# 50l. apply itself: with a registry and one kind in the templates, a new repository gets the
#      section for what it has, and a repository set up with --adopt gets none. Built on the
#      release before rule kinds, so it stays the same whatever the real fragments say.
rk_wired="$TMP/rk-wired"; rk_release "$rk_wired" 0.0.3 pre
cp "$rk/root/rule-checks.toml" "$rk_wired/rule-checks.toml"
subst 's|^\(- Commit messages follow Conventional Commits .*\)$|\1 <!-- kept: commit-format -->|' "$rk_wired/presets/_core/starter/+AGENTS.md/10-guide.md.tmpl"
grep -q 'kept: commit-format' "$rk_wired/presets/_core/starter/+AGENTS.md/10-guide.md.tmpl" || miss "rule kinds: the stand-in templates did not get a kind"
rk_install "$rk_wired" "$TMP/rk-w-team" --preset ts-node --level team
rk_install "$rk_wired" "$TMP/rk-w-starter" --preset ts-node
grep -qx -- '- commit format: `conventional-commits` goes red (GitHub)' "$TMP/rk-w-team/AGENTS.md" || miss "rule kinds: apply does not name the check a team repository has"
grep -q 'kept:' "$TMP/rk-w-team/AGENTS.md" && miss "rule kinds: apply leaves a kind in AGENTS.md"
grep -qx '## What holds these rules' "$TMP/rk-w-starter/AGENTS.md" || miss "rule kinds: a starter repository gets no section"
grep -q 'commit format' "$TMP/rk-w-starter/AGENTS.md" && miss "rule kinds: a starter repository is told of a check it does not have"
[ "$(tail -1 "$TMP/rk-w-starter/AGENTS.md")" = "No machine is listed." ] || miss "rule kinds: a starter repository without machines does not end with the sentence for it"
mkdir -p "$TMP/rk-w-adopt/src" && git -C "$TMP/rk-w-adopt" init -q -b main && echo 'export {};' > "$TMP/rk-w-adopt/src/index.ts"
python3 "$rk_wired/scripts/apply.py" --target "$TMP/rk-w-adopt" --preset ts-node --level team --adopt \
  --var project_name=R --var description=x --var owner=acme >/dev/null
grep -q 'What holds\|kept:' "$TMP/rk-w-adopt/AGENTS.md" && miss "rule kinds: a repository set up with --adopt gets the section, or keeps a kind"
# the base of the upgrade path: what planned_files rebuilds is what apply wrote, adopt or not
for d in rk-w-team rk-w-adopt; do
  same=$(python3 - "$rk_wired/scripts" "$TMP/$d" <<'PY' 2>&1 || true
import hashlib, json, sys
sys.path.insert(0, sys.argv[1])
import apply
m = json.load(open(f"{sys.argv[2]}/.repo-setup.json"))
choices = apply.choices_from_manifest(m)
plan = apply.planned_files(choices, apply.render_variables(m["vars"], choices), adopt=bool(m.get("adopt")))
print("ok" if hashlib.sha256(plan["AGENTS.md"]["content"]).hexdigest() == m["files"]["AGENTS.md"] else "differ")
PY
)
  [ "$same" = ok ] || miss "rule kinds: planned_files does not rebuild the AGENTS.md apply wrote ($d: $same)"
done

# --- the plugin's own fragments and registry ---------------------------------------------------
rk_plugin="$ROOT/plugins/repo-setup"
rk_check() { python3 "$S/rule_kinds.py" check --root "${1:-$rk_plugin}" --tests "${2:-$ROOT/tests}"; }

# 50m. every list item of every fragment has a kind, and every machine has a tagged test
rk_real=$(rk_check 2>&1) || miss "rule kinds: the plugin's own fragments fail: $(echo "$rk_real" | head -5)"

# 50n. the red direction, on copies: a new rule without a kind, a machine nobody registered, a
#      machine whose proof lost its tag
rk_copy="$TMP/rk-copy"; cp -R "$rk_plugin" "$rk_copy"
printf -- '- A rule nobody owns.\n' >> "$rk_copy/presets/_core/team/+AGENTS.md/55-autonomy.md"
out=$(rk_check "$rk_copy" 2>&1) && miss "rule kinds: a new rule without a kind passes"
echo "$out" | grep -q '55-autonomy.md:[0-9]*: list item has no kind' || miss "rule kinds: the new rule is not named: $(echo "$out" | head -3)"
rm -rf "$rk_copy"; cp -R "$rk_plugin" "$rk_copy"
subst 's/<!-- kept: module-boundaries -->/<!-- kept: module-walls -->/' "$rk_copy/archetypes/modular-monolith/starter/+AGENTS.md/40-modular-monolith.md"
out=$(rk_check "$rk_copy" 2>&1) && miss "rule kinds: a machine nobody registered passes"
echo "$out" | grep -q "unknown check 'module-walls'" || miss "rule kinds: the unregistered machine is not named: $(echo "$out" | head -3)"
mkdir -p "$TMP/rk-tests"; cp "$ROOT"/tests/*.sh "$TMP/rk-tests/"
subst '/# rule-check: module-boundaries/d' "$TMP/rk-tests/run.sh"
out=$(rk_check "$rk_plugin" "$TMP/rk-tests" 2>&1) && miss "rule kinds: a machine without a tagged test passes"
echo "$out" | grep -q "check 'module-boundaries' has no test tagged" || miss "rule kinds: the unproven machine is not named: $(echo "$out" | head -3)"

# Five repositories, set up by the plugin as it is.
rk_s="$TMP/rk-starter"; rk_install "$rk_plugin" "$rk_s" --preset ts-node
rk_t="$TMP/rk-team"; rk_install "$rk_plugin" "$rk_t" --preset ts-node --level team --archetype modular-monolith
rk_f="$TMP/rk-full"; rk_install "$rk_plugin" "$rk_f" --preset ts-api --level team --archetype service-api --deploy container --with mcp,ai,github-agents
rk_p="$TMP/rk-plugin"; rk_install "$rk_plugin" "$rk_p" --preset claude-plugin --level team
rk_a="$TMP/rk-adopt"; mkdir -p "$rk_a/src" && echo 'export {};' > "$rk_a/src/index.ts"
rk_install "$rk_plugin" "$rk_a" --preset ts-node --level team --adopt
rk_has() { grep -q -- "$2" "$1/AGENTS.md"; }

# 50o. by install: a starter repository is not told of the commit check or the secret scan; a
#      team repository is told of both, and of what its layers add
rk_has "$rk_s" '^- a wiki page that breaks its page format: `make check` goes red$' || miss "rule kinds: starter lacks the line for the wiki format"
for line in '^- commit format:' '^- a secret in a commit:' '^- a deleted or weakened test'; do
  rk_has "$rk_s" "$line" && miss "rule kinds: starter names a machine it does not have: $line"
done
for line in '^- commit format: `conventional-title` or `conventional-commits` goes red (GitHub)$' '^- a secret in a commit: `secret-scan` goes red (GitHub)$' \
  '^- a module reaching past another module.s public API: `make check` goes red$' '^- a deleted or weakened test, a looser `agent:` setting,'; do
  rk_has "$rk_t" "$line" || miss "rule kinds: team lacks the line $line"
done
rk_has "$rk_f" '^- a breaking change to the API contract: `make check` goes red$' || miss "rule kinds: a service API lacks the line for api-compat"
rk_has "$rk_f" 'a module reaching past' && miss "rule kinds: a repository without modules is told of module boundaries"
rk_has "$rk_p" '^- manifest versions that disagree, a plugin whose source is the repository root: `make check` goes red$' || miss "rule kinds: a plugin repository lacks the line for the manifest lint"
rk_has "$rk_p" 'a wiki page' && miss "rule kinds: a plugin repository is told of a wiki it does not have"

# 50p. every new repository: one section, no kind left, the closing sentence, and every machine
#      it names is a file the repository has
for d in "$rk_s" "$rk_t" "$rk_f" "$rk_p"; do
  [ "$(grep -c '^## What holds these rules$' "$d/AGENTS.md")" = 1 ] || miss "rule kinds: $(basename "$d") does not have the section exactly once"
  grep -q 'kept:' "$d/AGENTS.md" && miss "rule kinds: $(basename "$d") has a kind left in AGENTS.md"
  [ "$(tail -1 "$d/AGENTS.md")" = "miss: keeping them is on you." ] || miss "rule kinds: $(basename "$d") does not end with the sentence about the other rules"
  grep -q ' $' "$d/AGENTS.md" && miss "rule kinds: $(basename "$d") has a line that ends with a space"
  named=$(python3 - "$rk_plugin" "$d" <<'PY' 2>&1 || true
import pathlib, sys, tomllib
plugin, repo = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
checks = tomllib.load(open(plugin / "rule-checks.toml", "rb"))["checks"]
first = {f"- {e['catches']}: {e['reaction']}".splitlines()[0]: e for e in checks.values()}
section = (repo / "AGENTS.md").read_text(encoding="utf-8").split("## What holds these rules", 1)[1]
lines = [line for line in section.splitlines() if line.startswith("- ")]
bad = [line for line in lines if line not in first or not (repo / first[line]["present_when"]).exists()]
print("ok" if lines and not bad else "bad: " + "; ".join(bad or ["no machine listed"]))
PY
)
  [ "$named" = ok ] || miss "rule kinds: $(basename "$d") names a machine it does not have ($named)"
done

# 50q. a repository set up with --adopt: the kinds go, no section
grep -q 'What holds\|kept:' "$rk_a/AGENTS.md" && miss "rule kinds: an adopted repository gets the section, or keeps a kind"
grep -q '^- Never commit secrets\.$' "$rk_a/AGENTS.md" || miss "rule kinds: an adopted repository lacks a rule as the fragments now word it"

# 50r. the section adds no stop of its own (the phrases of 43g)
for phrase in 'get approval before you start' 'ask in the issue and stop' 'need human review' 'need a human reviewer' 'one approval is required' '(high tier)'; do
  for d in "$rk_t" "$rk_f" "$rk_p"; do
    sed -n '/^## What holds these rules$/,$p' "$d/AGENTS.md" | grep -qiF "$phrase" && miss "rule kinds: the section stops for a person: $phrase"
  done
done

# 50s. what apply wrote is what planned_files rebuilds: the base of the next upgrade
for d in "$rk_t" "$rk_a"; do
  same=$(python3 - "$S" "$d" <<'PY' 2>&1 || true
import hashlib, json, sys
sys.path.insert(0, sys.argv[1])
import apply
m = json.load(open(f"{sys.argv[2]}/.repo-setup.json"))
choices = apply.choices_from_manifest(m)
plan = apply.planned_files(choices, apply.render_variables(m["vars"], choices), adopt=bool(m.get("adopt")))
print("ok" if hashlib.sha256(plan["AGENTS.md"]["content"]).hexdigest() == m["files"]["AGENTS.md"] else "differ")
PY
)
  [ "$same" = ok ] || miss "rule kinds: planned_files does not rebuild the AGENTS.md apply wrote ($(basename "$d"): $same)"
done

echo "ok  rule kinds: $(rk_check 2>/dev/null | tail -1 | sed 's/^rule kinds: //') (or misses reported above)"
