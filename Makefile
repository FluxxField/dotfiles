SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

HOST := $(shell hostname)

help:
	@echo "Targets: bootstrap | link | unlink | restow | adopt | adopt-dry | adopt-merge | mise-globals | nvim-subtree-pull | nvim-subtree-push | nvim-stable | nvim-nightly | nvim-switch-stable | nvim-switch-nightly | fonts-linux | fonts-windows | doctor"

bootstrap:
	bash bootstrap.sh

link:
	./stow-all.sh

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

mise-globals:
	bash scripts/mide-setup-globas.sh

nvim-subtree-pull:
	bash scripts/nvim-subtree.sh pull

nvim-subtree-push:
	bash scripts/nvim-subtree.sh push

nvim-stable:
	bash scripts/nvim-manager.sh install stable && bash scripts/nvim-manager.sh switch stable

nvim-nightly:
	bash scripts/nvim-manager.sh install nightly && bash scripts/nvim-manager.sh switch nightly

nvim-switch-stable:
	bash scripts/nvim-manager.sh switch stable

nvim-switch-nightly:
	bash scripts/nvim-manager.sh switch nightly

fonts-linux:
	bash scripts/install-fonts.sh

fonts-windows:
	pwsh -NoProfile -ExecutionPolicy Bypass -File "$$HOME/.dotfiles/scripts/win/install-fonts.ps1"

doctor:
	@command -v stow >/dev/null || echo "stow missing"
	@command -v zsh >/dev/null || echo "zsh missing"
	@command -v nvim >/dev/null || echo "neovim missing"
	@command -v mise >/dev/null || echo "mise missing"
