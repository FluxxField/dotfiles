#!/usr/bin/env zsh

which -s brew
if [[ $? != 0 ]]; then
  echo "##############################"
  echo "# installing brew"
  echo "##############################"
  curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh;
else
  echo "##############################"
  echo "# updating brew"
  echo "##############################"
  brew update
fi

echo "##############################"
echo "# upgrading brew"
echo "##############################"
brew upgrade

echo "##############################"
echo "# installing packages"
echo "##############################"
brew install wget
brew install gnupg
brew install grep
brew install node
brew install yarn
brew install tmux

which -s asdf
if [[ $? != 0 ]]; then
  echo "##############################"
  echo "# installing asdf"
  echo "##############################"
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

which -s vim
if [[ $? != 0 ]]; then
  echo "##############################"
  echo "# installing vim"
  echo "##############################"
  brew install vim
fi

which -s nvim
if [[ $? != 0 ]]; then
  echo "##############################"
  echo "# installing neovim"
  echo "##############################"
  brew install neovim
  # overridding init.vim with repo version (points to .vimrc)
  cp /.config/nvim/init.vim ~/.config/nvim/
fi

if [ ! -d ~/.oh-my-zsh ]; then
  echo "##############################"
  echo "# installing oh-my-zsh"
  echo "##############################"
  # Install oh-my-zsh
  curl -fsSL https://raw.github.com/ohmyzsh/master/tools/install.sh
  # install spaceship theme for oh-my-zsh
  git clone https://github.com/spaceship-prompt/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship-prompt" --depth=1
  # symlink theem
  ln -s "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"
  # install autosuggestions
  git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
  # install syntax highlighting
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
fi

