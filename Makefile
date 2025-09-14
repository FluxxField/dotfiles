SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

HOST := $(shell hostname)

help:
	@echo "Targets: bootstrap | link | unlink | restow | doctor"

bootstrap:
	bash bootstrap.sh

link:
	./stow-all.sh

unlink:
	find stow -maxdepth 1 -mindepth 1 -type d -printf "%f\n" | xargs -I{} stow -d stow -t $$HOME -D {}

restow:
	unlink link

nvim-stable:
	bash scripts/nvim-manager.sh install stable && bash scripts/nvim-manager.sh switch stable

nvim-nightly:
	bash scripts/nvim-manager.sh install nightly && bash scripts/nvim-manager.sh switch nightly

nvim-switch-stable:
	bash scripts/nvim-manager.sh switch stable

nvim-switch-nightly:
	bash scripts/nvim-manager.sh switch nightly

doctor:
	@command -v stow >/dev/null || echo "stow missing"
	@command -v zsh >/dev/null || echo "zsh missing"
	@command -v nvim >/dev/null || echo "neovim missing"
	@command -v mise >/dev/null || echo "mise missing"
