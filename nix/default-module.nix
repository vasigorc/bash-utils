{ pkgs }:

{
    buildInputs = with pkgs; [
    # Shell and utilities
    zsh
    oh-my-zsh
    jq
    git
    fzf
    silver-searcher
    ripgrep # similar to silver-search but integrates well with vim/nvim
    ];

    shellHook = ''
        export SHELL=$(which zsh)
        exec zsh        
        export ZSH="$HOME/.oh-my-zsh"
        ZSH_THEME="robbyrussell"
        plugins=(
            git
            docker
            docker-compose
            terraform
            sbt
            nix-shell
        )
        source $ZSH/oh-my-zsh.sh

        # Add aliases or configurations
        export GIT_PAGER=
    '';
}
