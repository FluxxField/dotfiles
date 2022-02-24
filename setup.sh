#!/usr/bin/bash

exists() {
  command -v "$1" &>/dev/null
}

if ! exists brew; then
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
brew tap homebrew/cask-fonts
brew install --cask font-hack-nerd-font

if ! exists tmux; then
  echo ""
  echo "##############################"
  echo "# installing tmux"
  echo "##############################\n"
  brew install tmux
fi

if ! [[ ~/.tmux/plugins/tmp ]]
then
  echo ""
  echo "##############################"
  echo "# installing tmux plugin manager"
  echo "##############################\n"
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi

if ! exists asdf; then
  echo ""
  echo "##############################"
  echo "# installing asdf"
  echo "##############################\n"
  brew install asdf
  echo -e "\n. $(brew --prefix asdf)/libexec/asdf.sh" >> ${ZDOTDIR:-~}/.zshrcw
else
  echo ""
  echo "##############################"
  echo "# updating asdf"
  echo "##############################\n"
  asdf update
fi

if ! exists node; then
  echo ""
  echo "##############################"
  echo "# installing nodejs"
  echo "##############################\n"
  asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
  asdf install nodejs latest
  asdf global nodejs latest
fi

if ! exists yarn; then
  echo ""
  echo "##############################"
  echo "# installing yarn"
  echo "##############################\n"
  asdf plugin-add yarn
  asdf install yarn latest
  asdf global yarn latest
fi

if ! exists go; then
  echo ""
  echo "##############################"
  echo "# updating go"
  echo "##############################\n"
  asdf plugin-add golang https://github.com/kennyp/asdf-golang.git
  asdf install golang latest
  asdf global golang latest
fi 

if ! alias vim &>/dev/null; then
  echo ""
  echo "##############################"
  echo "# installing vim"
  echo "##############################\n"
  brew install vim
fi

if ! exists nvim; then
  echo ""
  echo "##############################"
  echo "# installing neovim"
  echo "##############################\n"
  brew install neovim
  cp ./.config/nvim/init.vim ~/.config/nvim/
fi

if ! [[ -f ~/.vim/autoload/plug.vim ]]
then
  echo ""
  echo "##############################"
  echo "# installing vim-plug"
  echo "##############################\n"
  curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

if ! [[ -d ~/.oh-my-zsh ]]
then
  echo ""
  echo "##############################"
  echo "# installing oh-my-zsh"
  echo "##############################\n"
  curl -fsSL https://raw.github.com/ohmyzsh/master/tools/install.sh
fi

if ! [[ -d "$ZSH_CUSTOM/themes/spaceship-prompt" ]]
then
  echo ""
  echo "##############################"
  echo "# installing spaceship theme"
  echo "##############################\n"
  git clone https://github.com/spaceship-prompt/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship-prompt" --depth=1
  ln -s "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"
fi

if ! [[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]
then
  echo ""
  echo "##############################"
  echo "# installing zsh autosuggestions"
  echo "##############################\n"
  git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
fi

if ! [[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]
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
