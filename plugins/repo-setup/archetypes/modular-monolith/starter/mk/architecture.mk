# Modular monolith (repo-setup archetype): module boundaries are part of `make check`.
CHECK_TARGETS += boundaries
.PHONY: boundaries

boundaries: ## Check module boundaries (architecture/modules.yaml)
	$(PYTHON) tools/boundaries.py
