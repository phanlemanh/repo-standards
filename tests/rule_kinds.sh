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

echo "ok  rule kinds (or misses reported above)"
