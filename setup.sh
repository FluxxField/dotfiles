# Load the variables in the current from the local vars.sh file if present under
# config otherwise read from the fallback file at github.
[ -f $HOME/.config/zsh/vars.sh  ] && source $HOME/.config/zsh/vars.sh  \
                                  || source /dev/stdin <<< "$(curl https://raw.githubusercontent.com/kalkayan/dotfiles/main/.config/zsh/vars.sh)"


# Load utility functions from the utils.sh file (where all the heavy lifting 
# installation code is written) otherwise read them from the fallback file.
[ -f $HOME/.config/zsh/utils.sh ] && source $HOME/.config/zsh/utils.sh \
                                  || source /dev/stdin <<< "$(curl https://raw.githubusercontent.com/kalkayan/dotfiles/main/.config/zsh/utils.sh)"
                                  
ask_password

install_xcode

install_brew

update_shell

setup_dotfiles

install_bins $VAR_BREW_BINS

install_casks $VAR_BREW_CASKS

. $HOME/.config/zsh/post_install.sh

install_ohmyzsh

install_nvim_req

asdf_setup

source $HOME.zshrc
