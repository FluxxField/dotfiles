#!/usr/bin/bash

exists() {
  command -v "$1" >/dev/null 2>&1
}

if ! [ exists brew ]
then
  echo "##############################"
  echo "# installing brew"
  echo "##############################\n"
  curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
else
  brew update
fi

echo ""
echo "##############################"
echo "# installing packages"
echo "##############################\n"
brew install wget
brew install coreutils
brew install gnupg
brew install grep
brew install node
brew install yarn
brew install tmux

if ! [ exists asdf ]
then
  echo ""
  echo "##############################"
  echo "# installing asdf"
  echo "##############################\n"
  brew install asdf
  echo -e "\n. $(brew --prefix asdf)/libexec/asdf.sh" >> ${ZDOTDIR:-~}/.zshrcw
  asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
  asdf plugin-add yarn
  asdf plugin-add golang https://github.com/kennyp/asdf-golang.git
  asdf install nodejs latest
  asdf install yarn latest
  asdf install golang latest
  asdf global nodejs latest
  asdf global yarn latest
  asdf global golang latest
fi

if ! [ greadlink -f $(exists vim) ]
then
  echo ""
  echo "##############################"
  echo "# installing vim"
  echo "##############################\n"
  brew install vim
fi

if ! [ exists nvim ]
then
  echo ""
  echo "##############################"
  echo "# installing neovim"
  echo "##############################\n"
  brew install neovim
  cp ./.config/nvim/init.vim ~/.config/nvim/
fi

if ! [ -d ~/.oh-my-zsh ]
then
  echo ""
  echo "##############################"
  echo "# installing oh-my-zsh"
  echo "##############################\n"
  curl -fsSL https://raw.github.com/ohmyzsh/master/tools/install.sh
fi

if ! [ -d "$ZSH_CUSTOM/themes/spaceship-prompt" ]
then
  echo ""
  echo "##############################"
  echo "# installing spaceship theme"
  echo "##############################\n"
  git clone https://github.com/spaceship-prompt/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship-prompt" --depth=1
  ln -s "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"
fi

if ! [ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]
then
  echo ""
  echo "##############################"
  echo "# installing zsh autosuggestions"
  echo "##############################\n"
  git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
fi

if ! [ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]
then
  echo ""
  echo "##############################"
  echo "# installing zsh syntax highlighting"
  echo "##############################\n"
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
fi

echo ""
echo "##############################"
echo "# upgrading brew"
echo "##############################\n"
brew upgrade
