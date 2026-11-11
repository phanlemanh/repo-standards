# One-command tasks. CI runs `make check`; run it before every PR.
.DEFAULT_GOAL := help
GEN_OUT := src/generated/ontology.ts
PYTHON ?= python3
CHECK_TARGETS := lint typecheck test ontology

# Extra targets from repo-setup layers (architecture, governance...) live in mk/*.mk.
# They append to CHECK_TARGETS, so `make check` grows with the setup.
# Check steps run quietly: a passing step prints only its tool's short result, a failing
# step prints the tool's full report.
-include mk/*.mk

.PHONY: help setup dev build format lint typecheck test gen ontology check clean

help: ## Show available commands
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  make %-10s %s\n", $$1, $$2}'

setup: ## Install dependencies from the lockfile
	npm ci

dev: ## Run locally with reload
	npm run dev

build: ## Compile to dist/
	npm run build

format: ## Auto-format all files
	npm run format

lint: ## Lint and check formatting
	@npm run --silent lint

typecheck: ## Strict type check
	@npm run --silent typecheck

test: ## Run tests
	@npm run --silent test

gen: ## Regenerate types from ontology/
	python3 tools/ontology_codegen.py --lang ts --out $(GEN_OUT)

ontology: ## Check ontology/ + wiki/ consistency and generated code
	@python3 tools/wiki_lint.py
	@python3 tools/ontology_codegen.py --lang ts --out $(GEN_OUT) --check

check: $(CHECK_TARGETS) ## Everything CI runs
	@echo "make check passed: $(CHECK_TARGETS)"

clean: ## Remove build output
	rm -rf dist coverage
