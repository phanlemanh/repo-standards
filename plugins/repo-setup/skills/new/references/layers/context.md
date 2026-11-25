# Layer: context

**Framing.** What is this project for, who is on the team, and what must it respect (deadline, compliance, existing systems)? This feeds every later layer.

**Depends on:** nothing. Say how those decisions constrain this layer.

**Only one sensible answer when:** the user already said it, for example a name and one sentence. Then say it in one line and move on.

**Kind of repository.** If the project is a set of Claude Code plugins (skills, commands, agents,
hooks offered through a marketplace), say so here. It settles `stack` (`claude-plugin`), and the
layers listed by `blueprint.py not-applicable claude-plugin` each get one line with their reason
instead of a question.

## Options

Offer two or three. Put anything the user already named on the list, even if you would not
recommend it. Say when each option would be wrong.

| Option | Why | Trade-off | Wrong when | Label |
|---|---|---|---|---|
| Name, one sentence, owner | Enough to start | Later layers assume more | Regulated data or a fixed deadline exist and were not named | `automated` |
| Add constraints: compliance, deadline, existing systems | Prevents wrong proposals later | One more question | A small personal project | `automated` |

Labels: `automated` (`apply.py` does it and it is verified), `partial` (the core is automated and
the manual steps are listed), `manual` (only recorded, with guidance; `doctor` does not score it).

**Recommendation when the user hands this to Claude:** ask only for the name and one sentence, and take the owner as below.

**Owner.** The GitHub user or organization that will hold the repository: `LICENSE` names it, and
at level `team` `CODEOWNERS` and `SECURITY.md` use it as a handle. Take the first that gives one,
without a question:

1. The owner part of the `origin` remote URL.
2. With no remote, the GitHub account signed in on this machine: `gh api user --jq .login`.
3. With neither, the name in `git config user.name`, and a `manual_steps` line: set `owner` to the
   GitHub handle once the repository has one. At level `team` that name is not a handle, so ask for
   the handle in the same question as the name and the sentence instead.

Say in one line which one you took.

## Recording

Write the result to `layers.context` in `setup-blueprint.yaml`: `status`, `source` (`user` or
`proposed`), `automation`, `choice`, `why`, `rejected`, `manual_steps`. A layer marked `manual` is
not applied at all, so when a layer mixes both, use `partial`: keep what `apply.py` can do in `choice`
and put the rest in `manual_steps`.
Choice keys: `project_name`, `description`, `owner`.
