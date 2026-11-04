eval: eval-agent
.PHONY: eval-agent

eval-agent: ## Run agent evals against the real API (costs money)
	npx tsx evals/runAgent.ts
