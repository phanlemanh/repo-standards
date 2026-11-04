# Layer: ai

**Framing.** Does the product itself call an LLM? Start by asking: do you really need an agent? This is about AI inside the product. Agents working on the repo belong to `governance`.

**Depends on:** architecture. Say how those decisions constrain this layer.

**Only one sensible answer when:** the user said the product has no AI. Then say it in one line and move on.

## Options

Offer two or three. Put anything the user already named on the list, even if you would not
recommend it. Say when each option would be wrong.

| Option | Why | Trade-off | Wrong when | Label |
|---|---|---|---|---|
| No AI | Nothing to run or pay for | No AI features | A real need exists | `automated` |
| `ai_tier: call` | Classify, summarise, extract: one request, one response | No multi-step work | Steps depend on earlier results | `automated` |
| `ai_tier: workflow` | Several steps that your code controls | You write the flow | The steps cannot be listed in advance | `automated` |
| `ai_tier: agent` | Open problems where the model chooses the steps | Cost, latency, harder to test | Any of the four criteria below fails | `automated` |

Labels: `automated` (`apply.py` does it and it is verified), `partial` (the core is automated and
the manual steps are listed), `manual` (only recorded, with guidance; `doctor` does not score it).

Check four criteria before an agent; if one fails, propose a simpler tier: **complexity** (multi-step
and hard to specify in advance), **value** (worth the extra cost and latency), **viability** (the
model can do this kind of task), **cost of error** (mistakes can be caught and recovered).

If the user does want an agent, offer where it runs (`agent_runtime`):

| Runtime | Fits when | Label |
|---|---|---|
| `tool-runner` (recommended) | Your own tools, your own hosting | `automated` |
| `manual-loop` | You need control of every step and no beta dependency | `manual` |
| `agent-sdk` | The agent works on files and code | `manual` |
| `managed-agents` | Long runs in a sandbox hosted by Anthropic. In beta, no ZDR or HIPAA | `manual` |

The agent tier brings a sample ontology and the `mcp` capability. RAG, remote MCP, observability,
agent-to-agent protocols and multi-agent orchestration are recorded as `manual`.

**Recommendation when the user hands this to Claude:** no AI unless the user asked for it; otherwise the lowest tier that does the job.

## Recording

Write the result to `layers.ai` in `setup-blueprint.yaml`: `status`, `source` (`user` or
`proposed`), `automation`, `choice`, `why`, `rejected`, `manual_steps`.
Choice keys: `ai_tier` (`none`, `call`, `workflow`, `agent`), `agent_runtime`.
