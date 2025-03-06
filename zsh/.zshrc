# this is a partial ~/.zshrc file
# don't rely on it entirely
# this file assumes presence of zsh, oh-my-zsh, and sdkman
# for zsh it assumes also that you've installed the following plugins: zsh-autosuggestions zsh-syntax-highlighting, zsh-nix-shell

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="agnoster"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git docker docker-compose gcloud kubectl kubectx mvn npm node rust sbt scala sdk terraform aws nix-shell zsh-autosuggestions zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

# Make SDK available in the current shell
source "$HOME/.sdkman/bin/sdkman-init.sh"

export PAGER=""

export JAVA_HOME=/Users/vasilegorcinschi/.sdkman/candidates/java/current
alias vim="nvim"

export VIMCONFIG=~/.config/nvim
export VIMDATA=~/.local/share/nvim

