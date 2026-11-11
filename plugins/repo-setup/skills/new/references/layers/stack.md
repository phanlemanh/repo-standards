# Layer: stack

**Framing.** Which language and framework? This decides what can be generated.

**Depends on:** architecture, ai. Say how those decisions constrain this layer.

**Only one sensible answer when:** detection found an existing stack, the user named one that has a preset, or the repo ships Claude Code plugins (`claude-plugin`). Then say it in one line and move on.

## Options

Offer two or three. Put anything the user already named on the list, even if you would not
recommend it. Say when each option would be wrong.

| Option | Why | Trade-off | Wrong when | Label |
|---|---|---|---|---|
| `python` or `ts-node` | Library, CLI, worker | No web layer | It serves HTTP | `automated` |
| `fastapi` or `ts-api` | HTTP API | A server to run | No API is needed | `automated` |
| `react-vite` | Web front end | No backend, and it cannot use the `ai` capability | A server must hold secrets | `automated` |
| `claude-plugin` | The repo ships Claude Code plugins through a marketplace | No app scaffold: no archetype, `ai`, `mcp`, deploy, ontology or wiki | The product is an app that also has a plugin | `automated` |
| Go, Rust, Java and others | Team skills or requirements | No preset: no scaffold | A supported stack would do | `manual` |

Labels: `automated` (`apply.py` does it and it is verified), `partial` (the core is automated and
the manual steps are listed), `manual` (only recorded, with guidance; `doctor` does not score it).

**Recommendation when the user hands this to Claude:** the language the user already knows; otherwise `python`.

## Recording

Write the result to `layers.stack` in `setup-blueprint.yaml`: `status`, `source` (`user` or
`proposed`), `automation`, `choice`, `why`, `rejected`, `manual_steps`. A layer marked `manual` is
not applied at all, so when a layer mixes both, use `partial`: keep what `apply.py` can do in `choice`
and put the rest in `manual_steps`.
Choice keys: `preset`; for an unsupported stack record it and run `doctor.py` to list what a repo needs.
With `claude-plugin`, two more choice keys: `plugin_name` names the sample plugin (default: the
project slug), and `plugin_versioning: independent` says plugins are released on their own schedule
(default `lockstep`: one version for all).
