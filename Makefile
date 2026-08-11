SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

.PHONY: help validate preflight init-sync init-sync-dry-run build build-dry-run \
        smoke-sdk smoke-sdk-dry-run smoke-cvd smoke-cvd-dry-run \
        telegram-configure telegram-test telegram-dry-run

help: ## Show task entry points
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z0-9_-]+:.*## / {printf "  %-24s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

validate: ## Run local syntax/help/static contract checks
	@tests/shell-safety.sh
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck -x -P scripts scripts/*.sh scripts/lib/*.sh tests/*.sh; \
	else \
		printf '%s\n' 'WARN: shellcheck not installed; lint step skipped' >&2; \
	fi

preflight: ## Run read-only host capability checks
	@scripts/host-preflight.sh

init-sync: ## Verify, initialize, sync, and export a revision lock
	@scripts/aosp-init-sync.sh

init-sync-dry-run: ## Print AOSP init/sync stages without mutation
	@scripts/aosp-init-sync.sh --dry-run

build: ## Build the approved AOSP Cuttlefish target
	@scripts/aosp-build.sh

build-dry-run: ## Print build stages without sourcing/building AOSP
	@scripts/aosp-build.sh --dry-run

smoke-sdk: ## Run the dedicated SDK Emulator evidence loop
	@scripts/sdk-emulator-smoke.sh

smoke-sdk-dry-run: ## Print SDK Emulator smoke stages without launch
	@scripts/sdk-emulator-smoke.sh --dry-run

smoke-cvd: ## Run the locally built Cuttlefish evidence loop
	@scripts/cuttlefish-smoke.sh

smoke-cvd-dry-run: ## Print Cuttlefish smoke stages without launch
	@scripts/cuttlefish-smoke.sh --dry-run

telegram-configure: ## Securely configure a private Telegram bot chat
	@scripts/configure-telegram.sh

telegram-test: ## Send a Telegram configuration test
	@scripts/telegram-notify.sh --test

telegram-dry-run: ## Validate notifier arguments without secrets/network
	@scripts/telegram-notify.sh --test --dry-run
