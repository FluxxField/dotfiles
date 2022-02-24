#!/usr/bin/zsh

cd "$(dirname "${BASH_SOURCE}")"

git pull origin main

function extract() {
  rsync --exclude ".git/" \ --exclude "main.sh" \ --exclude "README.md" \ --exclude "LICENSE.txt" \ --exclude ".config/" -avh --no-perms . ~
  source ~/.zshrc
  vim +'PlugInstall --sync' +qa
  npm install -g neovim
  yarn global add neovim
  python -m pip install pynvim --user
  python3 -m pip install pynvim --user
  python3 -m pip install --upgrade pip --user
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

vim +"checkhealth"
