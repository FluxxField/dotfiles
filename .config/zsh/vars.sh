#!/bin/bash
VAR_DOTFILES_BRANCH="main"

VAR_BREW_BINS=( $(cut -d '=' -f1 $HOME/.config/brew/bins.txt) )
VAR_BREW_CASKST=( $(cut -d '=' -f1 $HOME/.config/brew/casks.txt) )
