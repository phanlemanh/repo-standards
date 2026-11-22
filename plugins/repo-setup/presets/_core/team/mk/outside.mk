# Work outside the repository (repo-setup team level): see tools/outside.py and ops/outside.toml.
# Not part of make check: it asks GitHub and the other services, over the network.
.PHONY: outside

outside: ## Show what is in place outside the repository, what the machine applies, what is yours
	python3 tools/outside.py status
