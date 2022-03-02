#!/bin/zsh

function install_xcode () {
  if ! xcode-select -p 2>/dev/null; then
    xcode-select --install
    while ! xcode-select -p 2>/dev/null; do sleep 5; done
  fi
}

function install_brew () {
  [ ! -f "`which brew`" ] && /bin/bash -c "$(curl -fsL https://raw.githubusercontent.com/Homebrew/installmaster/install.sh)" || brew update
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
