# 55. what the generated files say matches what the repository has (docs/reports/2026-11-22-ux-audit.md,
#     F6 and F7; docs/reports/2026-11-24-newcomer-simulation.md, N3 to N5). A generated file that
#     describes something the repository does not have reached new repositories three times in two
#     weeks, so the claim is checked against the template it describes, not only reworded.
#     Sourced by tests/run.sh; uses its ROOT and miss.

gw_pl="$ROOT/plugins/repo-setup"
gw_tour="$gw_pl/skills/new/references/tour.md"
gw_skill="$gw_pl/skills/new/SKILL.md"

# 55a. the tour (docs/START-HERE.md) says what runs by itself inside Claude Code, read from the one
#      settings template every repository gets: no claim that nothing runs while it has a hook, and
#      each `make` target a hook runs is named.
gw_hooks=$(python3 - "$gw_pl/presets/_core/starter/dot.claude/settings.json.tmpl" <<'PY'
import json, re, sys
text = re.sub(r"\{\{[a-z_]+\}\}", "", open(sys.argv[1], encoding="utf-8").read())
for event, groups in json.loads(text).get("hooks", {}).items():
    for group in groups:
        for hook in group.get("hooks", []):
            targets = re.findall(r"\bmake(?: -s)? ([a-z][a-z-]*)", hook.get("command", ""))
            print(event, *(targets or ["-"]))
PY
) || miss "wording: the settings template does not parse once its placeholders are removed"
if [ -n "$gw_hooks" ]; then
  python3 - "$gw_tour" <<'PY' || miss "wording: tour.md says nothing runs by itself inside Claude Code, but the settings template has a hook"
import re, sys
t = open(sys.argv[1], encoding="utf-8").read()
sys.exit(1 if re.search(r"nothing (runs|happens) (by itself|automatically|on its own)", t, re.I) else 0)
PY
  while read -r gw_event gw_target; do
    if [ "$gw_target" = - ]; then
      grep -F "$gw_event" "$gw_tour" >/dev/null || miss "wording: tour.md does not say what the $gw_event hook runs"
    else
      grep -F "make $gw_target" "$gw_tour" >/dev/null || miss "wording: tour.md does not name make $gw_target, which the $gw_event hook runs"
    fi
  done <<EOF
$gw_hooks
EOF
fi

# 55b. owner with no remote (N3): context.md gives the order to take it in, without a question
gw_ctx=$(cat "$gw_pl/skills/new/references/layers/context.md")
case "$gw_ctx" in *'no remote'*'gh api user'*'git config user.name'*) ;; *) miss "wording: context.md has no rule for owner when the repository has no remote (remote, then gh api user, then git config user.name)" ;; esac

# 55c. hands-off delivery (N4): the default is "runs on your machine", and the options stay as they are
gw_dlv="$gw_pl/skills/new/references/layers/delivery.md"
gw_rec=$(grep '^\*\*Recommendation when the user hands this to Claude' "$gw_dlv" || true)
case "$gw_rec" in *'runs on your machine'*) ;; *) miss "wording: delivery.md does not make \"runs on your machine\" the hands-off default ($gw_rec)" ;; esac
case "$gw_rec" in *'`container` when'*) miss "wording: delivery.md still recommends container to a user who hands the layer to Claude" ;; esac
[ "$(grep -c '^| `container` |\|^| Nothing yet |\|^| Serverless' "$gw_dlv")" = 3 ] || miss "wording: delivery.md options changed (N4 changes the wording only)"

# 55d. progress lines follow the conversation's language (N5)
gw_lang=$(awk '/^## Language/ { on = 1; next } /^## / { on = 0 } on' "$gw_skill" | tr 'A-Z' 'a-z')
case "$gw_lang" in *'progress lines'*) ;; *) miss "wording: the Language section of new/SKILL.md does not say progress lines follow conversation_language" ;; esac

# 55e. the generated README points to docs/START-HERE.md (F6), and new translates it into docs_language
for gw_readme in "$gw_pl/presets/_core/starter/README.md.tmpl" "$gw_pl/presets/claude-plugin/starter/README.md.tmpl"; do
  grep -F '(docs/START-HERE.md)' "$gw_readme" >/dev/null || miss "wording: ${gw_readme#"$gw_pl"/} does not link docs/START-HERE.md"
done
case "$(tr '\n' ' ' < "$gw_skill" | tr -s ' ')" in *'README.md` into `docs_language`'*) ;; *) miss "wording: new/SKILL.md does not translate README.md into docs_language" ;; esac
echo "ok  generated wording (or misses reported above)"
