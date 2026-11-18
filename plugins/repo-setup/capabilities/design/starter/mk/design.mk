CHECK_TARGETS += design-guards
# The browser checks are the heavy tier: CI runs them when the files they read change.
HEAVY_TARGETS += ui-floor

.PHONY: design-guards ui-floor ui-patch
design-guards: ## Prove the design guards still catch real violations
	@node tools/design_guards.mjs

# tools/ui_select.mjs runs Playwright. On a pull request in CI it runs only the screens the change
# reaches, when the repository has design-assembly's affected command; everywhere else, and with
# UI_FULL=1, every check.
ui-floor: ## Browser checks only (structure, accessibility, no sideways scroll): the fast loop for screens
	@npx playwright install $(if $(CI),--with-deps) chromium
	@node tools/ui_select.mjs --run$(if $(UI_FULL), --full)

ui-patch: ## Fix freshly added shadcn components for the browser checks (run after shadcn add)
	node tools/patch_ui.mjs
