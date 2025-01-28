{ pkgs }:

{
  buildInputs = with pkgs; [
    # Neovim with all dependencies
    neovim
    nodejs
    # Language servers
    nodePackages.typescript-language-server
    nodePackages.vscode-langservers-extracted
    nodePackages."@tailwindcss/language-server"
    lua-language-server
    # Required tools
    fzf
    ripgrep
    asciidoctor
  ];

  shellHook = ''
    # Ensure XDG paths are set correctly if needed
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_DATA_HOME="$HOME/.local/share"
    export XDG_STATE_HOME="$HOME/.local/state"
    export XDG_CACHE_HOME="$HOME/.cache"
  '';
}