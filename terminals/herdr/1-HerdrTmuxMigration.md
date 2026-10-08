# herdr as a tmux replacement

<!--toc:start-->

- [herdr as a tmux replacement](#herdr-as-a-tmux-replacement)
  - [Why herdr](#why-herdr)
  - [Install (alongside tmux)](#install-alongside-tmux)
  - [Launching](#launching)
  - [tmux to herdr key map](#tmux-to-herdr-key-map)
  - [Seamless Ctrl-h/j/k/l with Neovim](#seamless-ctrl-hjkl-with-neovim)
  - [Copy mode, scroll and yank](#copy-mode-scroll-and-yank)
  - [What did not port](#what-did-not-port)
  - [Rolling back](#rolling-back)
  <!--toc:end-->

## Why herdr

[herdr](https://herdr.dev) is a terminal workspace manager built for AI coding
agents: persistent server sessions like tmux, plus agent status detection, a
workspace/agent sidebar, and a CLI/socket API (`herdr pane ...`) agents can drive.
It runs **next to** tmux: separate binary, separate config dir
(`~/.config/herdr`). Nothing here changes `~/.tmux.conf`.

## Install (alongside tmux)

Install herdr with its own installer. It works on macOS and Linux, and it puts
the binary in `~/.local/bin` (so that directory must be on `PATH`):

```sh
curl -fsSL https://herdr.dev/install.sh | sh
```

Other ways to install are on [herdr.dev/docs/install](https://herdr.dev/docs/install).
Keep only one herdr on `PATH`: `which -a herdr` must show one line.

`vim-herdr-navigation`, `hw`, and `agent-role` need `jq`:

| OS | jq |
| --- | --- |
| macOS 15 or later | included (`/usr/bin/jq`) |
| Ubuntu | `sudo apt install jq` |
| Fedora | `sudo dnf install jq` |

Then, from this folder, install the config:

```sh
mkdir -p ~/.config/herdr
cp config.toml ~/.config/herdr/config.toml  # copy, same as .tmux.conf
herdr config check                          # must print "config: ok"
```

Invalid values in `config.toml` are **dropped with only a diagnostic**, so always
run `herdr config check` after editing. Example: `prefix+pipe` is rejected, but
`prefix+|` works.

Then install the Neovim navigation plugin (see [below](#seamless-ctrl-hjkl-with-neovim)).

## Launching

Open a **new WezTerm tab that is not running tmux**, then run `herdr`. It starts
or attaches to the persistent server. `prefix+q` detaches; the server keeps running.

> ⚠️ Don't start herdr from inside a tmux pane. The server inherits `TMUX` and
> every herdr pane still sees `$TMUX` (observed on 0.9.1), so anything that
> branches on `$TMUX` (zshrc wrappers, scripts) will think it runs under tmux.
> Navigation is unaffected because it keys off `$HERDR_PANE_ID`.

## tmux to herdr key map

Prefix stays `Ctrl+b`.

| tmux (this repo) | herdr (this config) | Notes |
| --- | --- | --- |
| `prefix \|` split side by side | `prefix \|` | `split_vertical`, opens in current dir (`new_cwd = "follow"`) |
| `prefix -` split stacked | `prefix -` | `split_horizontal` |
| `prefix r` reload config | `prefix r` | herdr's default `prefix r` is resize mode, moved to `prefix R` |
| `M-arrows` resize by 5 | `Alt+arrows` | one fixed step size |
| `prefix S-arrows` resize by 10 | `prefix R` | interactive resize mode (keys shown in `prefix ?`) |
| `C-h/j/k/l` (vim-tmux-navigator) | `C-h/j/k/l` | vim-herdr-navigation plugin |
| `prefix ;` last pane | `prefix ;` | |
| `prefix z` zoom | `prefix z` | |
| `prefix x` kill pane | `prefix x` | |
| `prefix c` / `n` / `p` / `1..9` windows | same keys, on **tabs** | |
| `prefix [` copy mode | `prefix [` | see [copy mode](#copy-mode-scroll-and-yank) |
| `prefix d` detach | `prefix q` | |
| `prefix s` / `w` session / window tree | `prefix w` workspace picker, `prefix g` goto | |
| — | `prefix b` | toggle agent sidebar |
| — | `prefix ?` | built-in help, shows the live bindings |

Theme: Catppuccin Mocha built-in, overridden to the Macchiato palette in
`[theme.custom]` (herdr has no built-in Macchiato). Tab bar at the top, like
`status-position top`.

## Seamless Ctrl-h/j/k/l with Neovim

Uses [vim-herdr-navigation](https://github.com/paulbkim-dev/vim-herdr-navigation).
herdr binds `C-h/j/k/l` to a plugin action; the action checks the focused pane's
foreground process. If it is (n)vim, the key is forwarded to Neovim. Otherwise,
herdr moves focus. Inside Neovim, at a split edge, the plugin calls
`herdr pane focus --direction`.

1. **Neovim side** (`~/.config/nvim/lua/plugins/`):
   - `herdr-navigation.lua`: lazy.nvim always installs the checkout; the editor
     half and its `C-h/j/k/l` maps load **only when `$HERDR_PANE_ID` is set**.
   - `vim-tmux-navigator.lua`: skips `C-h/j/k/l` inside herdr and keeps
     `C-\` (TmuxNavigatePrevious). Under tmux it is unchanged.
2. **herdr side**: link the plugin from lazy.nvim's checkout, so
   `lazy-lock.json` pins both halves to the same commit:

   ```sh
   herdr plugin link ~/.local/share/nvim/lazy/vim-herdr-navigation
   herdr plugin list          # vim-herdr-navigation ... enabled
   ```

3. `[[keys.command]]` entries in `config.toml` bind `ctrl+h/j/k/l` to
   `vim-herdr-navigation.{left,down,up,right}`.

Apps that want `C-h/j/k/l` themselves (lazygit, k9s) can be passed through with
`HERDR_NAV_PASSTHROUGH_RE`; see the plugin README. Neovim behind a wrapper or over
ssh is detected as "not vim", and herdr moves focus instead.

## Copy mode, scroll and yank

`prefix [` enters copy mode. **Its keys are hard-coded:**

- Move: `hjkl`, `w b e W B E`, `0 ^ $`, `{ }`, `g`/`G` (single `g`),
  `C-u C-d C-b C-f`, PgUp/PgDn.
- Search: `/ ? n N`.
- Select: `v`/Space, `V`.
- Copy: `y`/Enter copy to the system clipboard (pbcopy locally, OSC 52 over ssh)
  **and exit**.
- Exit: `q`; Esc clears the selection, then exits.

Gaps vs tmux: no `C-v` block selection, no counts (`5j`), no `f/t`, no `H/M/L`,
no `o`, no text objects, and `y` exits copy mode.

**Escape hatch: `prefix e`** opens the focused pane's full scrollback in `$EDITOR`
(nvim) in an overlay, with full vim available.

Mouse: `mouse_capture = true` (like `mouse on`); drag-select copies on release.

## What did not port

| tmux | Why it's fine |
| --- | --- |
| `escape-time 0`, `extended-keys csi-u`, `default-terminal`, `terminal-features RGB`, `focus-events` | herdr owns the PTY (embedded Ghostty VT); truecolor is on and nvim negotiates the kitty keyboard protocol itself |
| `renumber-windows`, `base-index 1` | tabs are an ordered list; `prefix 1..9` is 1-based |
| `allow-passthrough on` | herdr renders kitty graphics itself (`kitty_graphics = true`); check with [image-test.md](./image-test.md) |
| tmux-resurrect / continuum | the server persists across detach; `[experimental] pane_history = true` keeps recent screen history across full server restarts |
| tmux-yank | built-in clipboard copy |
| tpm | no plugin manager needed |
| `alternate-screen off` (zshrc `opencode-tmux`) | no equivalent; the wrapper is harmless as long as `$TMUX` is unset (see [Launching](#launching)) |

## Rolling back

herdr and tmux share nothing, so rolling back is just "run `tmux` again". To remove
herdr completely:

```sh
herdr server stop
herdr plugin unlink vim-herdr-navigation
rm "$(command -v herdr)" && rm -rf ~/.config/herdr ~/.local/state/herdr
```

The Neovim side is inert outside herdr: without `$HERDR_PANE_ID`, the mappings
are exactly the vim-tmux-navigator ones.
