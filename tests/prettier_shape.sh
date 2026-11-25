# 57. The files a Node repository receives pass its own prettier as they are written, before any
#     format step. An upgrade writes a template as it is and runs nothing after it, so a template
#     prettier would change leaves `make check` red at `lint` after a clean upgrade (exit 0,
#     nothing marked). Found on a copy of design-ci-probe, 0.10.3 -> 0.10.5.dev0: the table of the
#     autonomy-change skill and the plugin keys of .claude/settings.json
#     (docs/reports/2026-11-26-release-readiness-0.10.5.md, L1). A new repository never showed it:
#     its install runs `npm run format`. Sourced by tests/run.sh; uses its ROOT, S, TMP and miss.
#     57a runs prettier when it is on the PATH or in npm's cache (it never goes to the network).
#     57b, the shapes prettier keeps, runs everywhere, prettier or not.

ps_combos="ts-node:team:: ts-node:starter:: react-vite:team:design: \
ts-api:team:github-agents:container react-vite:team:design,github-agents:"
ps_market_github="--var marketplace=phanlemanh/repo-standards"
ps_market_git="--var marketplace=https://git.example.com/platform/repo-standards-marketplace.git"
ps_dirs=()
ps_i=0
for ps_spec in $ps_combos; do
  IFS=: read -r ps_preset ps_level ps_caps ps_deploy <<<"$ps_spec"
  ps_d="$TMP/prettier-shape-$ps_i"; mkdir -p "$ps_d" && git -C "$ps_d" init -q -b main
  ps_args=(--target "$ps_d" --preset "$ps_preset" --level "$ps_level" --var project_name=P
    --var description=d --var owner=acme)
  [ -n "$ps_caps" ] && ps_args+=(--with "$ps_caps")
  [ -n "$ps_deploy" ] && ps_args+=(--deploy "$ps_deploy")
  # One marketplace given as owner/repo, one as a long git URL, one with none: the plugin keys of
  # settings.json take a different shape in each.
  case $((ps_i % 3)) in 0) ps_args+=($ps_market_github) ;; 1) ps_args+=($ps_market_git) ;; esac
  python3 "$S/apply.py" "${ps_args[@]}" >/dev/null || miss "prettier shape: apply.py failed for $ps_spec"
  ps_dirs+=("$ps_d:$ps_spec")
  ps_i=$((ps_i + 1))
done
# The files the plugin wrote, as .repo-setup.json lists them.
ps_files() { python3 -c 'import json,sys; print("\n".join(json.load(open(sys.argv[1]))["files"]))' "$1/.repo-setup.json"; }

# 57a. prettier --check, with the repository's own .prettierrc.json and .prettierignore
if command -v prettier >/dev/null 2>&1; then ps_prettier="prettier"
elif command -v npx >/dev/null 2>&1 && npx --offline prettier --version >/dev/null 2>&1; then ps_prettier="npx --offline prettier"
else ps_prettier=""; fi
if [ -n "$ps_prettier" ]; then
  for ps_entry in "${ps_dirs[@]}"; do
    ps_d="${ps_entry%%:*}"; ps_spec="${ps_entry#*:}"
    ps_out=$(cd "$ps_d" && ps_files "$ps_d" | xargs $ps_prettier --check --ignore-unknown --log-level warn 2>&1) \
      || miss "prettier shape ($ps_spec): prettier would change files the plugin wrote: $(grep -o '\[warn\] [^ ]*$' <<<"$ps_out" | sed 's/\[warn\] //' | tr '\n' ' ')"
  done
else
  echo "skip  prettier shape 57a: prettier is not on the PATH or in npm's cache, the prettier run was not done"
fi

# 57b. the shapes prettier keeps, read without prettier: no two blank lines in a row in Markdown,
#      every row of a Markdown table as wide as the others, and in .claude/settings.json an object
#      written on one line fits printWidth and has a space inside its braces.
for ps_entry in "${ps_dirs[@]}"; do
  ps_d="${ps_entry%%:*}"; ps_spec="${ps_entry#*:}"
  ps_out=$(python3 - "$ps_d" <<'PY'
import fnmatch, json, re, sys, unicodedata
from pathlib import Path

root = Path(sys.argv[1])
files = list(json.loads((root / ".repo-setup.json").read_text())["files"])
ignore = []
if (root / ".prettierignore").is_file():
    ignore = [p.strip() for p in (root / ".prettierignore").read_text().splitlines()
              if p.strip() and not p.startswith("#")]
width = 80
if (root / ".prettierrc.json").is_file():
    width = json.loads((root / ".prettierrc.json").read_text()).get("printWidth", 80)


def ignored(rel: str) -> bool:
    for pat in ignore:
        if pat.endswith("/") and (rel.startswith(pat) or f"/{pat}" in f"/{rel}"):
            return True
        if fnmatch.fnmatch(rel, pat) or fnmatch.fnmatch(rel.rsplit("/", 1)[-1], pat):
            return True
    return False


def shown(text: str) -> int:
    return sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in text)


problems = []
for rel in files:
    path = root / rel
    if ignored(rel) or not path.is_file():
        continue
    if rel.endswith(".md"):
        lines = path.read_text(encoding="utf-8").split("\n")
        fenced, blank, table = False, 0, []
        for n, line in enumerate(lines + [""], 1):
            if line.lstrip().startswith(("```", "~~~")):
                fenced = not fenced
            if fenced:
                blank, table = 0, []
                continue
            blank = blank + 1 if line.strip() == "" and n <= len(lines) - 1 else 0
            if blank == 2:
                problems.append(f"{rel}:{n}: two blank lines in a row")
            if line.startswith("|"):
                table.append(line)
                continue
            if len({shown(row) for row in table}) > 1:
                problems.append(f"{rel}:{n - len(table)}: table rows of different widths")
            table = []
    if rel == ".claude/settings.json":
        for n, line in enumerate(path.read_text(encoding="utf-8").split("\n"), 1):
            # prettier breaks an object that does not fit; it never breaks a long string, and
            # braces inside a string are not an object
            bare = re.sub(r'"(?:[^"\\]|\\.)*"', '""', line)
            if "{" in bare and "}" in bare and shown(line) > width:
                problems.append(f"{rel}:{n}: longer than printWidth {width}")
            if '{""' in bare or '""}' in bare:
                problems.append(f"{rel}:{n}: an object on one line without a space inside its braces")
print("\n".join(problems))
PY
)
  [ -z "$ps_out" ] || miss "prettier shape ($ps_spec): $(tr '\n' ';' <<<"$ps_out")"
done
