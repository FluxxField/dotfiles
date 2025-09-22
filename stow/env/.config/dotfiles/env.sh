# Dotfiles environment settings

# Startup upgrades (safe default: off)
export DOTFILES_STARTUP_AUTO_UPGRADE=0
export DOTFILES_STARTUP_INTERVAL_HOURS=24

# Fonts during bootstrap (Linux + Windows via WSL)
export DOTFILES_INSTALL_FONTS=1

# Locale defaults
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

# GOPATH for Go-installed tools
export GOPATH="${GOPATH:-$HOME/go}"
export PATH="$GOPATH/bin:$PATH"

# Re-exec into zsh at the end of bootstrap
export DOTFILES_REEXEC_ZSH="${DOTFILES_REEXEC_ZSH:-1}"

export WINUSER="$(cmd.exe /C "echo %USERNAME%)" | tr -d '\r')"
