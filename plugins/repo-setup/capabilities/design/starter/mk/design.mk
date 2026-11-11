CHECK_TARGETS += design-guards ui-floor

.PHONY: design-guards ui-floor
design-guards: ## Prove the design guards still catch real violations
	@node tools/design_guards.mjs

ui-floor: ## Browser checks only (structure, accessibility, no sideways scroll): the fast loop for screens
	@npx playwright install $(if $(CI),--with-deps) chromium
	@npx playwright test
