# 56. a drawn file not drawn yet is not a broken wiki (issue #69). A wiki page may link a file another
#     tool draws and git ignores (design-assembly's design/screens.yaml). On a clone where it is not
#     drawn yet, wiki_lint warns and names the way to draw it; doctor's ontology_wiki_valid passes.
#     A missing file git does not ignore, or one git tracks, is still broken. Sourced by
#     tests/run.sh; uses its ROOT, S, TMP, json, verdict and miss.

wd="$TMP/wiki-drawn"; mkdir -p "$wd" && git -C "$wd" init -q -b main
python3 "$S/apply.py" --target "$wd" --preset ts-node --var project_name=W --var description=x --var owner=acme >/dev/null
python3 "$ROOT/tests/apply_fixture.py" coffee "$wd" >/dev/null
printf '\n# Drawn by design-assembly\ndesign/screens.yaml\n' >> "$wd/.gitignore"
wd_page="$wd/wiki/entities/customer.md"
wd_links() { # the front matter links of the page, then a line for its body
  python3 - "$wd_page" "$1" "$2" <<'PY'
import re, sys
path, links, body = sys.argv[1:]
text = open(path, encoding="utf-8").read()
text, n = re.subn(r"^links: \[.*\]$", f"links: [{links}]", text, count=1, flags=re.M)
assert n == 1
open(path, "w", encoding="utf-8").write(text.split("\n<!-- 56 -->", 1)[0] + "\n<!-- 56 -->\n" + body + "\n")
PY
}
wd_lint() { ( cd "$wd" && { python3 tools/wiki_lint.py --json || true; } ) | json '"\n".join("%s %s" % (k, e["message"]) for k in ("errors", "warnings") for e in d[k])'; }

# 56a. a front matter link and a body link to an ignored file not drawn yet: a warning each, no error
wd_links 'ontology/entities/Customer.yaml, design/screens.yaml' 'Screens: [screens](../../design/screens.yaml).'
out=$(wd_lint)
grep '^errors ' <<<"$out" >/dev/null && miss "drawn: wiki_lint reports an ignored file not drawn yet as an error ($out)"
grep "^warnings front matter link 'design/screens.yaml' is not drawn yet" <<<"$out" >/dev/null \
  || miss "drawn: wiki_lint does not warn that the front matter link is not drawn yet ($out)"
grep "^warnings link '../../design/screens.yaml' is not drawn yet" <<<"$out" >/dev/null \
  || miss "drawn: wiki_lint does not warn that the body link is not drawn yet ($out)"
grep 'not drawn yet.*make derived' <<<"$out" >/dev/null || miss "drawn: the warning does not name make derived ($out)"
expect "$wd" ontology_wiki_valid '^pass$'

# 56b. once drawn, the link is read as any other: no warning left
mkdir -p "$wd/design" && echo 'screens: []' > "$wd/design/screens.yaml"
out=$(wd_lint)
grep 'not drawn yet' <<<"$out" >/dev/null && miss "drawn: wiki_lint still warns once the file is drawn ($out)"
rm -rf "$wd/design"

# 56c. a missing file git does not ignore is still broken, in front matter and in the body
wd_links 'ontology/entities/Customer.yaml, design/flows.yaml' 'Flows: [flows](../../design/flows.yaml).'
out=$(wd_lint)
grep "^errors front matter link 'design/flows.yaml' does not exist" <<<"$out" >/dev/null \
  || miss "drawn: a missing front matter link git does not ignore is not an error ($out)"
grep "^errors broken link '../../design/flows.yaml'" <<<"$out" >/dev/null \
  || miss "drawn: a missing body link git does not ignore is not an error ($out)"
expect "$wd" ontology_wiki_valid '^fail'

# 56d. a file git tracks, then deleted, is broken even where .gitignore names its path
mkdir -p "$wd/design" && echo 'screens: []' > "$wd/design/screens.yaml"
git -C "$wd" add -f design/screens.yaml && rm -rf "$wd/design"
wd_links 'ontology/entities/Customer.yaml, design/screens.yaml' ''
out=$(wd_lint)
grep "^errors front matter link 'design/screens.yaml' does not exist" <<<"$out" >/dev/null \
  || miss "drawn: a tracked file that was deleted passes as not drawn yet ($out)"
echo "ok  drawn files not drawn yet in the wiki (or misses reported above)"
