# AI in the product (repo-setup capability "ai"). Not part of `make check`: evals cost money.
.PHONY: eval

eval: ## Run evals against the real API (needs ANTHROPIC_API_KEY, costs money)
	uv run python evals/run.py
