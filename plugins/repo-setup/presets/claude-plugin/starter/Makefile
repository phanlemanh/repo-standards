# One-command tasks. CI runs `make check`; run it before every PR.
.DEFAULT_GOAL := help
PYTHON ?= python3
CLAUDE ?= npx -y @anthropic-ai/claude-code
CHECK_TARGETS := lint test

# Extra targets from repo-setup layers (governance...) live in mk/*.mk.
# They append to CHECK_TARGETS, so `make check` grows with the setup.
-include mk/*.mk

.PHONY: help setup lint test check validate bump

help: ## Show available commands
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  make %-10s %s\n", $$1, $$2}'

setup: ## Check the tools this repo needs (there is nothing to install)
	@$(PYTHON) -c 'import sys; sys.exit(sys.version_info < (3, 8))' || { echo "Python 3.8 or newer is needed" >&2; exit 1; }
	@command -v node >/dev/null || echo "node not found: needed only for 'make validate' (version in .nvmrc)"
	@echo "Ready. Try: make check"

lint: ## Check the marketplace and plugin manifests
	$(PYTHON) tools/plugin_lint.py

test: ## Run the tests
	bash tests/run.sh

check: $(CHECK_TARGETS) ## Everything CI runs offline

validate: ## Validate with the official Claude Code validator (downloads it with npx)
	$(CLAUDE) plugin validate .
	@for d in plugins/*/; do $(CLAUDE) plugin validate "$$d" || exit 1; done

bump: ## Bump the version in every manifest and the changelog: make bump V=minor
	$(PYTHON) tools/bump_version.py $(V)
