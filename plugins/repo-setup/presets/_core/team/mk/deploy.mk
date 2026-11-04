# Deploy targets used by .github/workflows/deploy.yml (ENV=staging|production).
# Replaced by a deploy layer (e.g. `--deploy container`); edit for your platform otherwise.
.PHONY: deploy smoke
ENV ?= staging

deploy: ## Deploy to ENV (staging|production)
	@echo "No deploy configured. Re-run repo-setup with --deploy container, or edit mk/deploy.mk." >&2; exit 1

smoke: ## Smoke-test the deployed ENV
	@echo "No smoke test configured (mk/deploy.mk)." >&2; exit 1
