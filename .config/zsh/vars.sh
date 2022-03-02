#!/bin/bash

VAR_DOTFILES_BRANCH="main"

VAR_BREW_BINS=( $(cut -d '=' -f1 $HOME/.config/brew/bins.txt) )
VAR_BREW_CASKST=( $(cut -d '=' -f1 $HOME/.config/brew/casks.txt) )

PRIMARY='\033[36m'
SECONDARY='\033[33m'
TERTIARY='\033[92m'
