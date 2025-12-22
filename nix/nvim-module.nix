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
    marksman
    ripgrep
    rsync # For syncing local configs into the shell
    vimPlugins.lazygit-nvim
    lazygit
    asciidoctor
    vimPlugins.markdown-preview-nvim
    # Nix tools
    nixfmt-rfc-style
    statix
  ];

  shellHook = ''
    # Ensure XDG paths are set correctly for the Nix environment
    export XDG_CONFIG_HOME="$HOME/.config-nix"
    export XDG_DATA_HOME="$HOME/.local-nix/share"
    export XDG_STATE_HOME="$HOME/.local-nix/state"
    export XDG_CACHE_HOME="$HOME/.cache-nix"

    # Create the directories if they don't exist
    mkdir -p "$XDG_CONFIG_HOME"
    mkdir -p "$XDG_DATA_HOME"
    mkdir -p "$XDG_STATE_HOME"
    mkdir -p "$XDG_CACHE_HOME"

    # Sync Neovim configuration
    if [ -d "$HOME/.config/nvim" ]; then
      echo "Syncing Neovim config from $HOME/.config/nvim"
      rsync -a --delete "$HOME/.config/nvim/" "$XDG_CONFIG_HOME/nvim/"
    fi

    # Sync Neovim data (parsers, plugins, etc.)
    if [ -d "$HOME/.local/share/nvim" ]; then
      echo "Syncing Neovim data from $HOME/.local/share/nvim"
      rsync -a "$HOME/.local/share/nvim/" "$XDG_DATA_HOME/nvim/"
    fi

    # create a default lazygit config if it doesn't exist
    if [ ! -f "$XDG_CONFIG_HOME/lazygit/config.yml" ]; then
      echo "Creating default lazygit config at $XDG_CONFIG_HOME/lazygit/config.yml"
      mkdir -p "$XDG_CONFIG_HOME/lazygit"
      lazygit --config > "$XDG_CONFIG_HOME/lazygit/config.yml"
    fi
  '';
}
