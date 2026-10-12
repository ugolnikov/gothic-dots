# Thin entry points for the common dotfiles tasks. `make` or `make help`.
.DEFAULT_GOAL := help

SHELL_SH := $(shell git ls-files '*.sh') bin/please .githooks/pre-commit .githooks/pre-push
SHELL_FISH := $(shell git ls-files '*.fish')

.PHONY: help install test lint fmt doctor backup check-packages

help: ## show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

install: ## link configs (no packages): ./install.sh --no-packages
	./install.sh --no-packages

test: ## run the bats test suite
	bats tests/

lint: ## run the fast local guards (secrets, binds, coverage, keybinds)
	./scripts/scan-secrets.sh --all
	./scripts/check-binds.sh
	./scripts/check-coverage.sh
	./scripts/gen-keybinds.sh --check

fmt: ## format shell (shfmt) and fish (fish_indent)
	shfmt -i 4 -ci -w $(SHELL_SH)
	fish_indent -w $(SHELL_FISH)

doctor: ## desktop health check (commands, links, fonts, Hyprland)
	./scripts/doctor.sh

backup: ## snapshot local edits to the snapshots branch
	./scripts/dotfiles-backup.sh

check-packages: ## validate packages.txt / aur.packages.txt against Arch + AUR
	./scripts/check-packages.sh
