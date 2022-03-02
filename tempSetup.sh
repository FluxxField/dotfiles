# Loads the zsh vars. Checks the home dir then falls back to Github
[ -f $HOME/.config/zsh/vars.sh ] && source $HOME/.config/zsh/vars.sh \ || source /dev/stdin <<< "$(curl https://raw.githubusercontent.com/FluxxField/dotfiles/main/.config/zsh/vars.sh)"

# Loads the utility functions. Checks the home dir then falls back to Github
[ -f $HOME/.config/zsh/utils.sh ] && source $HOME/.config/zsh/utils.sh \ || source /dev/stdin "$(curl https://raw.githubusercontent.com/FluxxField/dotfiles/main/.config/zsh/utils.sh)"

install_xcode

install_brew

update_shell

setup_dotfiles

install_bins $VAR_BREW_BINS

install_casks $VAR_BREW_CASKS

. $HOME/.config/zsh/post_installation.sh

source $HOME.zshrc