#!/bin/zsh

function print () {
    [ $# -eq 2 ] && echo -e "$1$2\033[0m" || echo "$1"
}

function install_xcode () {
    print $SECONDARY "\nVerifying xcode command line tools installation"

    if ! xcode-select -p 2>/dev/null; then
        # Install the xcode command line tools - xcode-select is the eaisest way.
        print $SECONDARY "Installing XCode Command Line tools using default xcode-select"
        xcode-select --install

        # Wait for system to install the command line tools (this is to halt the
        # script until tools aren't installed).
        print $SECONDARY "The Installation is currently in progress, Click Agree on the prompt."
        while ! xcode-select -p 2>/dev/null; do sleep 5; done

        # Verify the installation (the loop will only break when the path for the
        # tools will be found, therefore, no extra verfication needed)
        print $TERTIARY "XCode Command line tools successfully installed."
    fi
}

function install_brew () {
    if [ ! -f "`which brew`" ]; then
      /bin/bash -c "$(curl -fsSL https://raw.githubuserconten.com/Homebrew/install/master/install.sh)"
      echo 'eval "$(/opt/homebrew/bin/brew)"' >> $HOME/.zprofile
      eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        brew update && print $SECONDARY "$(brew --version | head -1) is already installed."
    fi
}

function update_shell () {
    if [[ " $@ " =~ " --update-shell " ]]; then
        print $SECONDARY "Changing $SHELL to zsh"

        # Install the latest zsh shell
        brew install zsh

        # Chanage the default shell to zsh installed by Homebrew (macos may ship with
        # older version, therefore update the zsh)
        BREW_PREFIX=$(brew --prefix)
        if ! fgrep -q "${BREW_PREFIX}/bin/zsh" /etc/shells; then
        echo "${BREW_PREFIX}/bin/zsh" | sudo tee -a /etc/shells;
        chsh -s "${BREW_PREFIX}/bin/zsh";
        fi
    fi
}

function setup_dotfiles () {
    # The trick behind the mangement of dotfiles is cloning it as a bare repository
    # therefore, first, we need to define some arguments for the git command. The
    # location for the dotfiles is under $HOME directory.
    alias dotfiles="/usr/bin/git --git-dir=$HOME/.dotfiles --work-tree=$HOME"
    
    alias

    # Bring the dotfiles from hosted repository if not already present
    if [ ! -d "$HOME/.dotfiles" ]; then
        /usr/bin/git clone --bare https://github.com/kalkayan/dotfiles.git $HOME/.dotfiles
    fi

    # Reset the unstagged changes before updating (TODO: experiment with stash)
    if [[ " $@ " =~ " --dotfiles-reset " ]]; then
        /usr/bin/git --git-dir=$HOME/.dotfiles --work-tree=$HOME reset --hard
    fi

    # Activate the profile for the current dev machine and Update the dotfiles with
    # remote repository
    /usr/bin/git --git-dir=$HOME/.dotfiles --work-tree=$HOME config status.showUntrackedFiles no
    /usr/bin/git --git-dir=$HOME/.dotfiles --work-tree=$HOME checkout $VAR_DOTFILES_BRANCH
    /usr/bin/git --git-dir=$HOME/.dotfiles --work-tree=$HOME pull origin $VAR_DOTFILES_BRANCH
}

function install_bins () {
    # Brew Binaries - these are binaries that are available as brew formula. A list
    # of these formulas are stored in the bins.txt file under ~/.config/kalkayan
    # ~ Note ~ : this file is automatically updates with everytime brew installs or
    # removes a binary
    bins=( "$@" )

    # required to properly install coreutils
    export PATH="$(brew --prefix coreutils)/libexec/gnubin:/usr/local/bin:$PATH"

    # Install binaries using Homebrew, iterate over bins array and install.
    print $PRIMARY "Installing the following binaries $bins"
    for binary in "${bins[@]}"; do
        # split the brew formula into binary name and version of installation and
        # get the name of the binary (ex- php in php@7.4)
        b=`echo $binary | cut -d \@ -f 1`
        # check if the binary is already present, otherwise install
        if ! brew list --formula | grep "$b" 1>/dev/null; then
            brew install "$binary"
        fi
    done
}

function install_casks () {
    # Brew Casks - these are the casks that are available as brew formula. A list
    # of these casks are stored in the casks.txt under ~/.config/kalkayan folder.
    # ~ Note ~ : this file is automatically updates with everytime brew installs or
    # removes a casks
    casks=( "$@" )

    # required to properly install coreutils
    export PATH="$(brew --prefix coreutils)/libexec/gnubin:/usr/local/bin:$PATH"

    print $PRIMARY "Installing the following casks $casks"

    # Install casks using Homebrew, iterate over casks array and install.
    for c in "${casks[@]}"; do
        print $PRIMARY "$c"
        # first, check if the cask is present or not, if not install
        if ! brew list --cask | grep "$c" 1>/dev/null; then
            brew install --cask "$c"
        fi

    done

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
    print $TERTIARY "\nEnter your password to begin with the installation\n"

    # Ask for sudo beforehand, so that the script doesn't halt installation in the
    # later sections.
    sudo -v

    # Keep sudo session persistent, taken from -- https://gist.github.com/cowboy/3118588
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
}
