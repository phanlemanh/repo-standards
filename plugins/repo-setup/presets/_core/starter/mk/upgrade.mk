# Upgrade (repo-setup): a setup file that still holds the conflict markers an upgrade wrote keeps
# make check red, so an unfinished merge cannot reach the default branch.
CHECK_TARGETS += upgrade
.PHONY: upgrade

upgrade: ## Fail while a file repo-setup manages still holds conflict markers
	@python3 tools/upgrade_markers.py
