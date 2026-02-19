SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

HOST := $(shell hostname)

.PHONY: help bootstrap startup link unlink restow adopt adopt-dry adopt-merge \
        ensure-locale ohmyzsh-install mise-install mise-install-globals \
        nvim-stable nvim-nightly nvim-current nvim-subtree-pull nvim-subtree-push \
        fonts-linux fonts-windows doctor

help:
	@echo "Targets: bootstrap | link | unlink | restow | adopt | adopt-dry | adopt-merge | ensure-locale | mise-install | mise-install-globals | ohmyzsh-install | nvim-subtree-pull | nvim-subtree-push | nvim-stable | nvim-nightly | nvim-switch-stable | nvim-switch-nightly | fonts-linux | fonts-windows | startup | doctor"

bootstrap:
	bash bootstrap.sh

startup:
	bash scripts/startup.sh

link:
	bash stow-all.sh

unlink:
	find stow -maxdepth 1 -mindepth 1 -type d -printf "%f\n" | xargs -I{} stow -d stow -t $$HOME -D {}

restow:
	unlink link

adopt:
		bash scripts/adopt-existing.sh

adopt-dry:
	bash scripts/adopt-existing.sh --dry-run

adopt-merge:
	@echo "1) Adopting existing files (will backup to .migration_backups/)..."
	bash scripts/adopt-existing.sh
	@echo "2) Launching merge tool against latest backups..."
	MERGE_TOOL=$${MERGE_TOOL:-nvimdiff} bash scripts/merge-from-backup.sh

ensure-locale:
	bash scripts/ensure-locale.sh

ohmyzsh-install:
	bash scripts/ohmyzsh-install.sh

mise-install:
	bash scripts/install-mise.sh

mise-install-globals:
	bash scripts/install-mise-globals.sh

nvim-subtree-pull:
	bash scripts/nvim-subtree.sh pull

nvim-subtree-push:
	bash scripts/nvim-subtree.sh push

nvim-stable:
	bash scripts/nvim-manager.sh use stable

nvim-nightly:
	bash scripts/nvim-manager.sh use nightly

nvim-current:
	bash scripts/nvim-manager.sh current

fonts-linux:
	bash scripts/install-fonts.sh

fonts-windows:
	pwsh -NoProfile -ExecutionPolicy Bypass -File "$$HOME/.dotfiles/scripts/win/install-fonts.ps1"

doctor:
	@command -v stow      >/dev/null || echo "MISSING: stow"
	@command -v zsh       >/dev/null || echo "MISSING: zsh"
	@command -v nvim      >/dev/null || echo "MISSING: nvim"
	@command -v mise      >/dev/null || echo "MISSING: mise"
	@command -v starship  >/dev/null || echo "MISSING: starship"
	@command -v lazygit   >/dev/null || echo "MISSING: lazygit"
	@command -v zoxide    >/dev/null || echo "MISSING: zoxide"
	@command -v eza       >/dev/null || echo "MISSING: eza"
	@command -v rg        >/dev/null || echo "MISSING: ripgrep"
	@command -v fzf       >/dev/null || echo "MISSING: fzf"
	@command -v node      >/dev/null || echo "MISSING: node"
	@command -v go        >/dev/null || echo "MISSING: go"
	@echo "doctor done (no output = all present)"
