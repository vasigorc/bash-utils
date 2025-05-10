{ pkgs }:

let
  unstable = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixpkgs-unstable.tar.gz") {};
in
{
  buildInputs = with pkgs; [
    # Neovim with all dependencies
    unstable.neovim
    nodejs
    # Language servers
    nodePackages.typescript-language-server
    nodePackages.vscode-langservers-extracted
    nodePackages."@tailwindcss/language-server"
    lua-language-server
    # Required tools
    fzf
    ripgrep
    vimPlugins.lazygit-nvim
    lazygit
    asciidoctor
  ];

  shellHook = ''
    # Ensure XDG paths are set correctly if needed
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_DATA_HOME="$HOME/.local/share"
    export XDG_STATE_HOME="$HOME/.local/state"
    export XDG_CACHE_HOME="$HOME/.cache"
    # create a default lazygit config if it doesn't exist
    if [ ! -f "$HOME/.config/lazygit/config.yml" ]; then
      echo "Creating default lazygit config at ~/.config/lazygit/config.yml"
      mkdir -p "$HOME/.config/lazygit"
      lazygit --config > "$HOME/.config/lazygit/config.yml"
    fi
  '';
}
