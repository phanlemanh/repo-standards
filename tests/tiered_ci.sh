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
echo "ok  tiered CI (or misses reported above)"
