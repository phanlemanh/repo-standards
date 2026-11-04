eval: eval-agent
.PHONY: eval-agent

eval-agent: ## Run agent evals against the real API (costs money)
	uv run python evals/run_agent.py
