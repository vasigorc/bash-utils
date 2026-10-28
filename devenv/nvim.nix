{ pkgs, ... }:

# devenv port of ../nix/nvim-module.nix: Neovim plus the tools my config shells out to, running against an
# isolated copy of my host Neovim config/plugins. See README.md for usage and caveats.
{
  packages = with pkgs; [
    neovim
    nodejs

    # Language servers
    typescript-language-server
    vscode-langservers-extracted
    tailwindcss-language-server
    lua-language-server
    marksman

    # Tools the config shells out to
    fzf
    ripgrep
    rsync # for syncing the host config into the shell, see enterShell
    lazygit
    asciidoctor

    # Nix tools
    nixfmt
    statix
  ];

  enterShell = ''
    # Isolate Neovim/lazygit state from the host's under *-nix XDG dirs
    export XDG_CONFIG_HOME="$HOME/.config-nix"
    export XDG_DATA_HOME="$HOME/.local-nix/share"
    export XDG_STATE_HOME="$HOME/.local-nix/state"
    export XDG_CACHE_HOME="$HOME/.cache-nix"

    mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME"

    # Both syncs below are mirrors (--delete) of the host, which only ever gets read.
    # Unlike nvim-module.nix the data sync deletes: with a plain `rsync -a` a plugin updated only inside the shell
    # gets its tracked files reverted to the host's version on every entry while its newer untracked files stay,
    # leaving a plugin tree that mixes two versions. Update plugins on the host, not in here.
    if [ -d "$HOME/.config/nvim" ]; then
      echo "Syncing Neovim config from $HOME/.config/nvim"
      rsync -a --delete "$HOME/.config/nvim/" "$XDG_CONFIG_HOME/nvim/"
    fi

    # The P rule protects Mason packages installed only inside the shell from --delete
    if [ -d "$HOME/.local/share/nvim" ]; then
      echo "Syncing Neovim data from $HOME/.local/share/nvim"
      rsync -a --delete --filter='P /mason/***' "$HOME/.local/share/nvim/" "$XDG_DATA_HOME/nvim/"
    fi

    # Unlike nvim-module.nix this does not dump `lazygit --config` once: that dump pins the key syntax of the lazygit
    # that wrote it and is never refreshed, and newer lazygit versions reject old keys (e.g. `<c-R>` is now
    # `<ctrl+r>`), so lazygit refused to start. Mirror the host's config instead; with none, lazygit uses its defaults.
    if [ -d "$HOME/.config/lazygit" ]; then
      echo "Syncing lazygit config from $HOME/.config/lazygit"
      rsync -a --delete "$HOME/.config/lazygit/" "$XDG_CONFIG_HOME/lazygit/"
    fi
  '';
}
