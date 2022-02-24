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
brew install grep
brew install node
brew install yarn
brew install tmux

echo "installing asdf"
echo ""
brew install asdf
echo -e "\n. $(brew --prefix asdf)/libexec/asdf.sh" >> ${ZDOTDIR:-~}/.zshrc
asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
asdf plugin-add yarn
asdf install nodejs latest
asdf install yarn latest
asdf global nodejs latest
asdf global yarn latest

echo "installing vim and nvim"
echo ""
brew install vim
brew install neovim

cp /.config/nvim/init.vim ~/.config/nvim/

echo "install oh-my-zsh"
echo ""
curl -fsSL https://raw.github.com/ohmyzsh/master/tools/install.sh
git clone https://github.com/spaceship-promp/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship-prompt" --depth=1
ln -s "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"
