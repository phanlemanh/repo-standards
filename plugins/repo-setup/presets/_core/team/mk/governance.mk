# Governance (repo-setup team level): autonomy policy must stay in sync with CODEOWNERS.
CHECK_TARGETS += governance
.PHONY: governance codeowners

governance: ## Check governance/autonomy.yaml and .github/CODEOWNERS agree
	python3 tools/autonomy.py --check-codeowners

codeowners: ## Regenerate .github/CODEOWNERS from governance/autonomy.yaml
	python3 tools/autonomy.py --write-codeowners
