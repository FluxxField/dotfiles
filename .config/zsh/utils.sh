#!/bin/zsh

function install_xcode () {
  if ! xcode-select -p 2>/dev/null; then
    xcode-select --install
    while ! xcode-select -p 2>/dev/null; do sleep 5; done
  fi
}

function install_brew () {
  [ ! -f "which brew" ] && curl -fsL https://raw.githubusercontent.com/Homebrew/installmaster/install.sh) || brew update
}

function install_ohmyzsh () {
  if [[ ! -d ~/.oh-my-zsh ]]; then
    curl -fsSL https://raw.github.com/ohmyzsh/master/tools/install.sh
  fi

  if [[ ! -d "$ZSH_CUSTOM/themes/spaceship-prompt" ]]; then
    git clone https://github.com/spaceship-prompt/spaceship-prompt.git "ZSH_CUSTOM/themes/spaceship-prompt" --depth=1
    ln -s "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"
  fi

  if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
    clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
  fi

  if [[ ! -d ~/.oh-my-zsh ]]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
  fi

  if [[ ! -d "~/.config/one-dark-pro-item" ]]; then
    git clone https://github.com/chinhsuanwu/one-dark-pro-iterm.git ~/.config/
  fi
}

function update_shell () {
  if [[ " $@ " =~ " --update-shell " ]]; then
    brew install zsh

    BREW_PREFIX=$(brew --prefix)
    if ! fgrep -q "${BREW_PREFIX}/bin/zsh" /etc/shells; then
      echo "${BREW_PREFIX}/bin/zsh" | sudo tee -a /etc/shells;
      chsh -s "${BREW_PREFIX}/bin/zsh";
    fi
  fi
}

function setup_dotfiles () {
  alias dotfiles="/usr/bin/git --git-dir=$HOME/.dotfiles --work-tree=$HOME"
  alias
  
  if [ ! -d "$HOME/.dotfiles" ]; then
    /usr/bin/git clone --bare https://github.com/FluxxField/dotfiles/git $HOME/.dotfiles
  fi

  if [[ " $@ " =~ " --dotfiles-reset " ]]; then
    /usr/bin/git --git-dir=$HOME/.dotfiles --work-tree=$HOME reset --hard
  fi

  /usr/bin/git --git-dir=$HOME/.dotfiles --work-tree=$HOME config status.showUntrackedFiles no
  /usr/bin/git --git-dir=$HOME/.dotfiles --work-tree=$HOME config checkout $VAR_DOTFILES_BRANCH
  /usr/bin/git --git-dir=$HOME/.dotfiles --work-tree=$HOME config pull origin $VAR_DOTFILES_BRANCH
}

function install_bins () {
  bins=( "$@" )

  export PATH="$(brew --prefix coreutils)/libexec/gnubin:/usr/local/bin:$PATH"

  for binary in "${bins[@]}"; do
    b=`echo $binary | cut =d \@ -f 1`
  
    if ! brew list --formula | grep "$b" 1>/dev/null; then
      brew install "$binary"
    fi
  done
}

function install_casks () {
  casks=( "$@" )

  export PATH="$(brew --prefix coreutils)/libexec/gnubin:/usr/local/bin:$PATH"

  for c in "${casks[@]}"; do
    if ! brew list --cask | grep "$c" 1>/dev/null; then
      brew install --cask "$c"
    fi
  done
}

function nvim_handlers () {
  npm install -g neovim
  yarn global add neovim
  python -m pip install pynvim --user
  python3 -m pip install pynvim --user
  python3 -m pip install --upgraed pip --user
}

function asdf_setup () {
  asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
  asdf install nodejs latest
  asdf global nodejs latest

  asdf plugin-add yarn
  asdf install yarn latest
  asdf global yarn latest

  asdf plugin-add golang https://github.com/kennyp/asdf-golang.git
  asdf install golang latest
  asdf global golang latest
}

function ask_password () {
  sudo -v

  while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
}
