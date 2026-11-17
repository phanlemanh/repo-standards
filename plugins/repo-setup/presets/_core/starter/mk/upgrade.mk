# Upgrade (repo-setup): a setup file that still holds the conflict markers an upgrade wrote keeps
# make check red, so an unfinished merge cannot reach the default branch. It runs first, so its
# message is the one you see, and `make format` waits for it: a formatter would move the markers
# where no check sees them, and the merge would be lost.
CHECK_TARGETS := upgrade $(CHECK_TARGETS)
.PHONY: upgrade

upgrade: ## Fail while a file repo-setup manages still holds conflict markers
	@python3 tools/upgrade_markers.py

format: upgrade
