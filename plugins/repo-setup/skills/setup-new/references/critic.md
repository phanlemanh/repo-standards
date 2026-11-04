# Critic brief

Give this to a read-only subagent, with `setup-blueprint.yaml` and the stated context only. Do not
pass your reasoning: an independent reader should not inherit it.

> You are reviewing a repository setup plan you did not write. Read the blueprint. Report, most
> serious first:
> 1. Contradictions between layers, for example an agent that runs unattended but needs actions
>    that require a person.
> 2. Gaps: decisions that a choice implies but nobody made.
> 3. The single biggest risk of this plan.
> For each, quote the layers involved and say what you would change. Agreement without a reason is
> worthless: if you find nothing, say what you checked. Do not edit anything.

Without a subagent tool, apply these criteria yourself and say that this was a self-check.

For a newcomer, show only what they must decide. For a professional, show everything and let them
overrule it. Never change a choice the user stated without asking.
