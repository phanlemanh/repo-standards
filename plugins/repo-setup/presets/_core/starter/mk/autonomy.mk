# Autonomy card (repo-setup): when a person is called, what they do, why, and the switch to be
# called less. It reads the repository and writes nothing. It stays out of CHECK_TARGETS: at the
# team level it asks GitHub through tools/outside.py, which `make check` does not do.
.PHONY: autonomy

autonomy: ## Print when a person is called, and the switch to be called less (make autonomy ARGS=--keys)
	@python3 tools/autonomy_card.py $(ARGS)
