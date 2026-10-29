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

For a project that other people clone, make the import optional, so that the project still evaluates on machines that do not have this
repository (this is what [wasm_definitive_guide](https://github.com/vasigorc/wasm_definitive_guide/blob/main/devenv.nix) does):

```nix
{ lib, ... }:
let
  nvimModule = "${builtins.getEnv "HOME"}/repos/bash-utils/devenv/nvim.nix";
in
{
  imports = lib.optional (builtins.pathExists nvimModule) nvimModule;
}
```

This relies on impure evaluation, which is `devenv`'s default.

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
3. Syncs `~/.local/share/nvim` into `~/.local-nix/share/nvim`: plugin checkouts and parsers (`lazy`, `lazy-rocks`, `site`,
   `treesitter-parser`) as exact mirrors, everything else additively (see below).
4. Mirrors `~/.config/lazygit` into `~/.config-nix/lazygit`. With no host config, `lazygit` runs on its built-in defaults.

The host directories are only ever read.

### Update Neovim plugins on the host, not inside the shell

Step 2 and the four plugin directories in step 3 are mirrors (`rsync --delete`), so anything that exists only on the `*-nix` side of
those is removed on the next entry. Plugin updates made only inside the shell are discarded and the plugins go back to the host's versions.

**Everything else under the data dir is never deleted.** That is user data and tool state that gets created inside the shell: chat
history (`codecompanion-history`), scratch files, DB UI queries, Mason packages, `jdtls` workspaces, ... It is copied from the host,
but only where the host's file is newer (`rsync --update`), so what you create inside the shell survives restarts. It does not flow back
to the host though, so it is not visible outside of the shell.

> An earlier version of this module put `--delete` on the whole data dir, with only `mason/` protected. That deleted chat history,
> code reviews and a scratch file created inside the shell, because they exist only on the `*-nix` side, and they could not be recovered.
> The rule is now the other way around: only the directories that are known to hold plugin code are deleted from, and anything unknown is kept.

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

### lazygit

[nix/nvim-module.nix](../nix/nvim-module.nix) creates the `lazygit` config once, with `lazygit --config > config.yml`. That writes a
full dump of the defaults of whichever `lazygit` version ran, and it is never refreshed. When the shell later gets a newer `lazygit`,
old keys stop validating (`<c-R>` became `<ctrl+r>`) and `lazygit` refuses to start with:

```
The config at `~/.config-nix/lazygit/config.yml` has a validation error.
Unrecognized key '<c-R>' for keybinding 'Commits.ResetCherryPick[0]'.
```

This module mirrors the host's `~/.config/lazygit` instead, so `lazygit` inside the shell uses the same config as outside of it. Keep that
config valid for the `lazygit` version that your shell resolves (`lazygit --version` inside the shell). Note that `lazygit` only reports
the first validation error.

If you used the older module, its stale dump is overwritten by the next shell entry, as long as `~/.config/lazygit` exists. Otherwise
delete `~/.config-nix/lazygit/config.yml`.

`lazygit` also **rewrites** config files it migrates, so never point `--use-config-file` at a tracked file to test it (I once
reformatted [../lazygit/config.yaml](../lazygit/config.yaml) that way); test a copy.

### Mason shadows the Nix packages

Inside Neovim, Mason's `bin` directory is first on `PATH`. If you install a tool with Mason (e.g. `:LspInstall wasm_language_tools`) that
the shell also provides as a Nix package, Neovim uses Mason's copy. The Nix one is still on `PATH` outside of Neovim.

#### rust-analyzer: take it from the toolchain, not from Mason

`rust-analyzer` has to match the `cargo` it drives, so do not install it with Mason. LazyVim's Rust extra does not either: it only asks Mason
for `codelldb` and expects `rust-analyzer` on `PATH`, which is where `rustaceanvim` looks for it. Let each environment provide its own: the
`rustup` component on the host, and the Nix one that ships with the toolchain in the shell (`languages.rust`).

I once had a Mason copy from a year earlier shadowing the Nix one. It passes `--lockfile-path` to `cargo metadata`, which cargo 1.99.1 does not
accept, so every workspace load failed and `rust-analyzer` quietly fell back to a `--no-deps` workspace: your own crate plus the sysroot, but
none of its dependencies. The symptoms: `K` answers `No information available` on anything from a dependency, while `:checkhealth vim.lsp` shows
a healthy, attached client. It worked on the host only because `rustup` had an older cargo (1.90.0) that still accepts the flag.

To get rid of it, uninstall it on the host first and then inside the shell, because the data sync is additive and would otherwise copy
the host's package back:

```vim
:MasonUninstall rust-analyzer
```

To diagnose something similar, start Neovim with `RA_LOG='info,project_model=debug'`, look for `WARN ... cargo metadata failed` in the log file
given by `--log-file` in the `Command` that `:checkhealth vim.lsp` shows for `rust-analyzer` (copy it before quitting, Neovim deletes its temp dir
on exit), and ask the server for `rust-analyzer/analyzerStatus`, which starts with `Loaded N packages`. A tiny number means the dependencies were
not loaded: 15 with the broken Mason copy against 235 with the Nix one, for a crate whose `cargo metadata` lists 265 packages.

### Example: `.wat` files

In [wasm_definitive_guide](https://github.com/vasigorc/wasm_definitive_guide) the shell provides
[wasm-language-tools](https://github.com/g-plane/wasm-language-tools), a language server and formatter for the WebAssembly text format
(the `wat_server` binary). `nvim-lspconfig` already knows it as `wasm_language_tools`, so after entering the shell, open a `.wat` file and run:

```vim
:LspInstall wasm_language_tools
```

This gives diagnostics, document symbols, inlay hints (e.g. the implicit `(;0;)` indices and `i32` types) and formatting. As described above,
Mason installs its own copy for this, and Neovim prefers it over the one from the Nix package.

`nvim-treesitter` does not ship a Treesitter parser for `.wat` files, so there is no Treesitter-based highlighting or text objects for them.

### Differences from nix/nvim-module.nix

| | `nix/nvim-module.nix` (`nix-shell`) | `devenv/nvim.nix` (`devenv`) |
|---|---|---|
| Data sync | `rsync -a --force` | `lazy`, `lazy-rocks`, `site`, `treesitter-parser`: `--delete`; the rest: `--update`, never deleted |
| `lazygit` config | a `lazygit --config` dump, created once | mirror of `~/.config/lazygit` |
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
