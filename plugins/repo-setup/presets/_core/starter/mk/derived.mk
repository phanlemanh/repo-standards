# Derived files (repo-setup): a file drawn from smaller sources stays out of git. `make derived`
# draws every one of them. Other layers add to the two lists below from their own mk/ file:
#   DERIVED_TARGETS += my-target   a target that draws files
#   DERIVED_FILES   += path/to/it  a file it draws, so that a copy in git turns make check red
# `derived` takes DERIVED_TARGETS as prerequisites by second expansion, after every mk file is read,
# so a target added by a file read after this one still runs. The Makefile of each preset puts `| derived` ahead of the steps that read the
# drawn files, and `derived` itself waits for `upgrade`: a file with conflict markers is not drawn from.
PYTHON ?= python3
DERIVED_TARGETS += wiki-derived
DERIVED_FILES += wiki/log.md wiki/index.md ontology/glossary.md
CHECK_TARGETS += derived-untracked
.PHONY: derived wiki-derived derived-untracked

.SECONDEXPANSION:

derived: upgrade $$(DERIVED_TARGETS) ## Draw every file the repository keeps out of git
	@:

wiki-derived: ## Draw the wiki log, the wiki index and the glossary from their fragments
	@$(PYTHON) tools/ledgers.py draw

derived-untracked: ## Fail when a drawn file is in git
	@$(PYTHON) tools/ledgers.py untracked $(DERIVED_FILES)
