# WezTerm Kitty replacement setup

<!--toc:start-->
- [Config location](#config-location)
- [Why WezTerm](#why-wezterm)
- [Default mode: Kitty replacement plus real tmux](#default-mode-kitty-replacement-plus-real-tmux)
- [Copy mode and search](#copy-mode-and-search)
- [Claude Code / OpenCode scrollback](#claude-code--opencode-scrollback)
- [Known limitations](#known-limitations)
<!--toc:end-->

**Date**: 2026-06-16
**Tested with**: WezTerm `20240203-110809-5046fc22`, Claude Code `2.1.177`

## Config location

Primary config:

```bash
~/.config/wezterm/wezterm.lua
```

Repo copy:

```bash
terminals/wezterm/wezterm.lua
```

Install/update from this repo:

```bash
mkdir -p ~/.config/wezterm
cp terminals/wezterm/wezterm.lua ~/.config/wezterm/wezterm.lua
```

Try it explicitly without making WezTerm your default terminal:

```bash
wezterm --config-file ~/.config/wezterm/wezterm.lua
```

Validate that WezTerm can parse the config:

```bash
wezterm --config-file ~/.config/wezterm/wezterm.lua show-keys --lua >/tmp/wezterm-keys.lua
```

## Why WezTerm

Goal: use WezTerm as the Kitty replacement first: preserve Catppuccin/font quality and let real tmux keep owning `Ctrl+b`. The WezTerm-as-tmux-replacement bindings are preserved in the config, but disabled by default.

Important appearance choices:

- Font: `JetBrainsMonoNL Nerd Font Mono` through `wezterm.font_with_fallback`.
- Font size: `13.0`.
- Theme: Catppuccin Macchiato, with the active Kitty palette pinned explicitly.
- Scrollback: `10000` lines.
- Bell disabled, opacity `0.95`.

## Default mode: Kitty replacement plus real tmux

The current config intentionally does **not** set a WezTerm `Ctrl+b` leader. This means `Ctrl+b` passes through to tmux, so attaching to a real session works as expected:

```bash
tmux a -t infra-central
```

Inside tmux, use your existing tmux mappings:

| Key | Action |
| --- | --- |
| `Ctrl+b z` | Toggle pane zoom |
| `Ctrl+b [` | Enter tmux copy mode |
| `Ctrl+b l` | Toggle between the last two tmux windows |
| `Ctrl+b %` / `Ctrl+b "` | Split tmux panes |

The optional WezTerm-native tmux replacement layer is still present in `~/.config/wezterm/wezterm.lua`, guarded by:

```lua
local enable_wezterm_tmux_replacement_keys = false
```

Flip that to `true` only if you want WezTerm itself to own `Ctrl+b` panes/tabs instead of running tmux inside WezTerm. When enabled, WezTerm maps `Ctrl+b c`, `Ctrl+b ,`, `Ctrl+b l`, splits, copy-mode, pane resize, and tab switching to native WezTerm actions.

## Copy mode and search

Default mode keeps `Ctrl+b [` for tmux, so use WezTerm's direct copy-mode bindings when you want terminal-level scrollback/copy:

```text
Ctrl+Shift+x
Cmd+Shift+x
```
Useful keys inside copy mode:

| Key | Action |
| --- | --- |
| `h/j/k/l` | Vim-style movement |
| `Ctrl+u` / `Ctrl+d` | Half-page up/down |
| `Ctrl+b` / `Ctrl+f` | Page up/down |
| `g` / `G` | Top/bottom of scrollback |
| `v` | Start character selection |
| `V` | Start line selection |
| `Ctrl+v` | Start block selection |
| `y` | Copy selection and stay in copy mode |
| `Enter` | Copy selection and exit copy mode |
| `/` or `?` | Enter search pattern editor |
| `n` / `N` | Next / previous match after a pattern exists |

WezTerm does not perfectly clone tmux's `/` forward vs `?` backward search model. In this config, both `/` and `?` open the search pattern editor; use `n` and `N` to move through matches. While typing the search pattern, WezTerm's default search table supports `Ctrl+n` / `Ctrl+p`, arrow keys, and `PageUp` / `PageDown` for match navigation.

Alternative if this still feels awkward: use WezTerm's command palette (`Ctrl+Shift+p`) and search-related commands, or use Claude Code transcript mode for Claude-specific history.

## Claude Code / OpenCode scrollback

Fullscreen TUIs often use the terminal alternate screen buffer. Terminals, including WezTerm, cannot expose native scrollback for content that the app only renders in the alternate buffer.

For Claude Code native terminal scrollback, add this to `~/.zshrc`:

```zsh
# Claude Code: use classic main-screen rendering so native terminal/WezTerm scrollback works.
export CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN=1
```

Then start a fresh shell and run `claude`. This overrides Claude Code fullscreen/no-flicker mode. It may not apply to `claude attach` background-session views, which Claude docs say always use fullscreen rendering.

If staying in Claude Code fullscreen mode:

| Key | Action |
| --- | --- |
| `PgUp` / `PgDn` | Scroll conversation |
| `Ctrl+Home` / `Ctrl+End` | Jump to start/latest message |
| `Ctrl+o` | Transcript mode |
| `Ctrl+o`, then `[` | Write conversation into native terminal scrollback |
| `Ctrl+o`, then `/` | Search transcript inside Claude Code |
| `Ctrl+o`, then `v` | Open transcript in `$VISUAL` / `$EDITOR` |

WezTerm option included for non-mouse-capturing alt-screen apps:

```lua
config.alternate_buffer_wheel_scroll_speed = 1
```

This only controls WezTerm's wheel-to-arrow fallback when the app has not enabled mouse reporting. Claude Code fullscreen handles mouse/scrolling itself, so this setting is not a magic native-scrollback fix for Claude.

## Known limitations

- WezTerm default mode now relies on real tmux for sessions, panes, and `Ctrl+b` muscle memory.
- The disabled WezTerm-native tmux layer is useful for experiments, but it conflicts with real tmux because both want `Ctrl+b`.
- Claude Code fullscreen content lives in Claude's TUI, not WezTerm native scrollback. Use `CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN=1` for classic renderer, or Claude transcript mode when fullscreen is needed.
