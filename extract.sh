#!/usr/bin/bash

cd "$(dirname "${BASH_SOURCE}")"

git pull origin main

function extract() {
  rsync --exclude ".git/" \ --exclude "main.sh" \ --exclude "README.md" \ --exclude "LICENSE.txt" \ --exclude ".config/" -avh --no-perms . ~
  source ~/.zshrc
  source ~/.tmux.conf
  vim +'PlugInstall --sync' +qa
}

if [[ "$1" == "--force" || "$1" == "-f" ]]
then
  extract
else
  read -p "This may overwrite existing files in your home directory. Are you sure? (y/n) " -n 1
  echo ""

  if [[ $REPLY =~ ^[Yy]$ ]]
  then
    extract
  fi
fi

unset extract
