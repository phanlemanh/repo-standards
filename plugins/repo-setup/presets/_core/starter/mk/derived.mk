# Derived files (repo-setup): a file drawn from smaller sources stays out of git. `make derived`
# draws every one of them. Other layers add to the two lists below from their own mk/ file:
#   DERIVED_TARGETS += my-target   a target that draws files
#   DERIVED_FILES   += path/to/it  a file it draws, so that a copy in git turns make check red
# `derived` takes DERIVED_TARGETS as prerequisites by second expansion, after every mk file is read,
# so a target added by a file read after this one still runs. The Makefile of each preset puts `| derived` ahead of the steps that read the
# drawn files, and `derived` itself waits for `upgrade`: a file with conflict markers is not drawn from.
# `.SECONDEXPANSION` is on for the whole Makefile: write no `$$` in a prerequisite list in an mk file.
PYTHON ?= python3
# ledgers.py, ledgers_split.py, ledgers_split_read.py, ledgers_ontology.py and ontology_codegen.py use the standard
# library only: they run with the system python3 even where PYTHON is `uv run python` (which could sync a venv at every session start).
LEDGERS_PYTHON ?= python3
DERIVED_TARGETS += wiki-derived
DERIVED_FILES += wiki/log.md wiki/index.md ontology/glossary.md
CHECK_TARGETS += derived-untracked ledgers-check
# The code generated from ontology/ (GEN_OUT and GEN_LANG are set by the preset Makefile before it
# reads mk/*.mk; a preset with no generated code leaves GEN_OUT empty) is drawn, stamped, in the
# fragments shape. A repository that still commits the file (the one-file shape) keeps it as it is.
ifneq ($(GEN_OUT),)
DERIVED_TARGETS += gen-derived
DERIVED_FILES += $(GEN_OUT)
endif
.PHONY: derived wiki-derived gen-derived derived-untracked ledgers-check log split

.SECONDEXPANSION:

derived: upgrade $$(DERIVED_TARGETS) ## Draw every file the repository keeps out of git
	@:

wiki-derived: ## Draw the wiki log, the wiki index and the glossary from their fragments
	@$(LEDGERS_PYTHON) tools/ledgers.py draw

gen-derived: ## Draw the code generated from ontology/ (a repository that commits it keeps it as it is)
	@$(LEDGERS_PYTHON) tools/ledgers.py draw-gen --gen-out $(GEN_OUT) --gen-lang $(GEN_LANG)

derived-untracked: ## Fail when a drawn file is in git
	@$(LEDGERS_PYTHON) tools/ledgers.py untracked $(DERIVED_FILES)

ledgers-check: ## Fail on a wrong ledger fragment or two sources for one ledger
	@$(LEDGERS_PYTHON) tools/ledgers.py check

# `$(value m)` hands the text over as typed: make does not expand a `$` in it. It is exported to
# the one recipe below only, through the environment, so quotes and backticks reach the tool too.
log: export LOG_ENTRY = $(value m)
log: ## Add a line to the wiki log: make log m="what changed — link"
	@$(LEDGERS_PYTHON) tools/ledgers.py add-log -- "$$LOG_ENTRY"

# One ledger at a time, in a pull request of its own: L=log, index, glossary or gen. DRY=1 prints
# what would be written and the comparison, and writes nothing.
split: ## Move a one-file ledger into fragments without losing an entry: make split L=log [DRY=1]
	@$(LEDGERS_PYTHON) tools/ledgers.py split $(L) $(if $(GEN_OUT),--gen-out $(GEN_OUT) --gen-lang $(GEN_LANG)) $(if $(DRY),--dry-run)
