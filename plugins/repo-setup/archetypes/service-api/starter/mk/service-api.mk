# Service API (repo-setup archetype): the contract is generated from ontology/ and checked.
CHECK_TARGETS += api-contract api-compat
.PHONY: openapi api-contract api-compat

# `make gen` also regenerates the contract.
gen: openapi

openapi: ## Regenerate contracts/openapi.json from ontology/
	$(PYTHON) tools/openapi_gen.py --out contracts/openapi.json

api-contract: ## Check contracts/openapi.json is up to date with ontology/
	$(PYTHON) tools/openapi_gen.py --out contracts/openapi.json --check

api-compat: ## Fail on breaking API changes against the default branch
	$(PYTHON) tools/api_compat.py
