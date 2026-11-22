# Work outside the repository, for a platform this plugin does not generate

A team-level repository lists its work outside the repository in two files, read by
`tools/outside.py`:

- `governance/outside.toml`: the kinds of command the machine may run (recipes). A file of the
  rules of the game: a person decides each recipe.
- `ops/outside.toml`: each piece of work (rows). Adding a row goes like any product change.

The plugin seeds recipes and rows for GitHub. When the `delivery` layer is `manual` (a platform
of the user's choice), write the recipes and rows for that platform this way:

1. **Use the service's own command-line tool** (its CLI), logged in by the user. No API token
   in a file, no script of your own around an HTTP API when the CLI does it.
2. **Every recipe has a `check`** that lists what is there and prints one line per thing, so
   `expect_line` can match one line. A check that cannot answer leaves the row unknown, never in
   place.
3. **A key is a row of its own**, of kind `secret`, with `store` taking the value on standard
   input. Never put a value in a recipe, a row or an argument. Values the machine can make (a
   password for a database role the app logs in with, say) are `source = "generated"`.
4. **A setting the machine may change has `apply`.** One that changes a wall (protection of a
   branch or an environment) has no `apply`: it is only checked, and a person says go.
5. **Try each command first**, directly in the session, where Claude Code asks for permission as
   usual. Only then write it as a recipe. `python3 tools/outside.py status --draft` prints what the
   working tree would run, and runs nothing.
6. **Recipes go in a pull request of their own**, so a person decides them apart from the rows
   and the code. Rows can come with the code that needs them.
7. **`DEPLOY_ENABLED`** is a `github-variable` row with `value = "true"`, added only once
   `make deploy` works.
8. **What stays a person's**: creating a key at the service's page, entering it with
   `python3 tools/outside.py secrets`, and decisions (`decision = "..."` rows), such as approving
   production.

After the pull request merges, `python3 tools/outside.py status` checks the rows, `apply` applies
the machine's list, and the `Yours` list is what is left for the person.
