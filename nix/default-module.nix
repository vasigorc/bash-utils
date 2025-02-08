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
        # Add any nix-shell specific configurations here
        export GIT_PAGER=
    '';
}
