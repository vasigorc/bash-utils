{ pkgs }:

{
  buildInputs = with pkgs; [
    # Shell and utilities
    zsh
    bat
    git-extras
    oh-my-zsh
    jq
    git
    fzf
    fzf-git-sh
    silver-searcher
    ripgrep # similar to silver-search but integrates well with vim/nvim
    eza # modern replacement for ls
  ];

  shellHook = ''
    # Add any nix-shell specific configurations here
    export GIT_PAGER=
  '';
}
