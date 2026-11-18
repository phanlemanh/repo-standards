# One-command tasks. `make check` is everything CI runs offline; run it before every PR.
.DEFAULT_GOAL := help
PYTHON ?= python3
CLAUDE ?= npx -y @anthropic-ai/claude-code
# Two tiers. CI runs the light one (CHECK_TARGETS) on every push and the heavy one
# (HEAVY_TARGETS) when the files it reads change.
CHECK_TARGETS := lint test
HEAVY_TARGETS :=

# Extra targets from repo-setup layers (governance...) live in mk/*.mk.
# They append to CHECK_TARGETS or HEAVY_TARGETS, so `make check` grows with the setup.
-include mk/*.mk

# Every check step, those layers added in mk/*.mk too, waits for `make derived` (mk/derived.mk).
# `upgrade` runs first and `derived` waits for it, so it stays out of the list.
$(filter-out upgrade derived-untracked derived,$(CHECK_TARGETS)) $(HEAVY_TARGETS): | derived

.PHONY: help setup lint test check check-quick check-heavy validate bump

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

check-quick: $(CHECK_TARGETS) ## The light tier: CI runs it on every push

check-heavy: $(HEAVY_TARGETS) ## The heavy tier: CI runs it when the files it reads change
	@$(if $(strip $(HEAVY_TARGETS)),:,echo "no heavy checks")

check: check-quick check-heavy ## Everything CI runs offline: both tiers

validate: ## Validate with the official Claude Code validator (downloads it with npx)
	$(CLAUDE) plugin validate .
	@for d in plugins/*/; do $(CLAUDE) plugin validate "$$d" || exit 1; done

bump: ## Bump the version in every manifest and the changelog: make bump V=minor
	$(PYTHON) tools/bump_version.py $(V)
