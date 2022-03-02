# Post installations for
[[ "${VAR_BREW_BINS[@]} " =~ " neovim "]] && sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim' && nvim +PlugInstall +qall
