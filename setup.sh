#!/usr/bin/env zsh

echo "installing brew"
echo ""
curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh;

echo "updating brew"
echo ""
brew update

echo "upgrading brew"
echo ""
brew upgrade

echo "installing packages"
echo ""
brew install wget
brew install gnupg
brew install vim
brew install grep
brew install neovim
