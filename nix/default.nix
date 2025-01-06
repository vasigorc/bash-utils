{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/06278c77b5d162e62df170fec307e83f1812d94b.tar.gz") {} }:

pkgs.mkShell {

    buildInputs = with pkgs; [
    # Shell and utilities
    zsh
    oh-my-zsh
    jq
    git
    fzf
    silver-searcher

    # Docker and related tools
    docker
    docker-compose
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
        )
        source $ZSH/oh-my-zsh.sh

        # Add aliases or configurations
        export GIT_PAGER=
    '';
}
