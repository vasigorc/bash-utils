# devenv

[devenv](https://devenv.sh) modules that I reuse across projects.

## nvim.nix

Neovim, plus the tools my config shells out to (language servers, `fzf`, `ripgrep`, `lazygit`, `asciidoctor`, `nixfmt`, `statix`),
running against an **isolated copy** of my host Neovim config and plugins. It is the `devenv` counterpart of
[nix/nvim-module.nix](../nix/nvim-module.nix) and, like it, contains nothing project specific: add it to any project's
`devenv.nix` and pair it with that project's own toolchain.

### Requirements

- [Nix](https://nixos.org/download/) and [devenv](https://devenv.sh/getting-started/)
- A working Neovim set-up on the host (`~/.config/nvim` and `~/.local/share/nvim`), which is what gets copied

### Usage

In the project's `devenv.nix` (use the absolute path to where you cloned this repository):

```nix
{ ... }:
{
  imports = [ /home/<you>/repos/bash-utils/devenv/nvim.nix ];

  # the project's own packages, languages, scripts, ...
}
```

Then enter the shell with `--no-reload`:

```shell
devenv shell --no-reload
nvim
```

Why `--no-reload`: by default `devenv shell` wraps the session in an auto-reload layer (the `devenv watching N files` bar at the bottom
of the terminal). In my case this stopped `Ctrl+h/j/k/l` window navigation from working in `nvim` (I use
[vim-herdr-navigation](https://github.com/paulbkim-dev/vim-herdr-navigation)). The mappings were identical with and without `devenv`,
and `--no-reload` fixed it. The only downside is that you have to re-enter the shell yourself after editing `devenv.nix` or `devenv.yaml`.

### What it does on every shell entry

1. Points `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME` and `XDG_CACHE_HOME` at `~/.config-nix`, `~/.local-nix/share`,
   `~/.local-nix/state` and `~/.cache-nix`, so Neovim inside the shell never touches the host's files.
2. Mirrors `~/.config/nvim` into `~/.config-nix/nvim`.
3. Mirrors `~/.local/share/nvim` (plugins, parsers, ...) into `~/.local-nix/share/nvim`.
4. Creates a default `lazygit` config if there is none.

The host directories are only ever read.

### Update Neovim plugins on the host, not inside the shell

Steps 2 and 3 are mirrors (`rsync --delete`), so anything that exists only on the `*-nix` side is removed on the next entry,
**with one exception**: `mason/` is protected from deletion, so Mason packages installed inside the shell are kept.
Plugin updates made only inside the shell are discarded and the plugins go back to the host's versions.

This is deliberately different from [nix/nvim-module.nix](../nix/nvim-module.nix), whose data sync is a plain `rsync -a --force`
without `--delete`. That version breaks as soon as a plugin gets updated inside the shell. On the next entry `rsync` overwrites the
plugin's tracked files with the host's older versions, but leaves the files that only exist in the newer version. The result is a plugin
checkout that mixes two versions. I hit this with [CodeCompanion](https://github.com/olimorris/codecompanion.nvim): the newer code reads
`config.display.chat.stream_interval`, which the older, restored `config.lua` does not define, so `:CodeCompanionChat` failed with:

```
builder.lua:122: attempt to compare number with nil
```

To check for this, run `git status` inside a plugin checkout under `~/.local-nix/share/nvim/lazy/`. A healthy checkout is identical to
the host's. A mixed one has the host's `HEAD` but also untracked files that the host's checkout does not have (181 of them for CodeCompanion).

### Mason shadows the Nix packages

Inside Neovim, Mason's `bin` directory is first on `PATH`. If you install a tool with Mason (e.g. `:LspInstall wasm_language_tools`) that
the shell also provides as a Nix package, Neovim uses Mason's copy. The Nix one is still on `PATH` outside of Neovim.

### Differences from nix/nvim-module.nix

| | `nix/nvim-module.nix` (`nix-shell`) | `devenv/nvim.nix` (`devenv`) |
|---|---|---|
| Data sync | `rsync -a --force` | `rsync -a --delete`, `mason/` protected |
| `vimPlugins.lazygit-nvim`, `vimPlugins.markdown-preview-nvim` | in `buildInputs` | dropped, `lazy.nvim` installs plugins itself |
| Package pins | the nixpkgs commit pinned in [nix/nvim.nix](../nix/nvim.nix) | the project's `devenv.yaml` and `devenv.lock` |

### Testing

From a project that imports the module:

```shell
devenv shell --no-reload -- bash -c 'command -v nvim lazygit rg fzf'
```

and, to confirm the isolation, in the shell:

```shell
echo $XDG_CONFIG_HOME   # /home/<you>/.config-nix
nvim --headless -c 'lua io.stdout:write(vim.fn.stdpath("data"))' -c q   # /home/<you>/.local-nix/share/nvim
```
