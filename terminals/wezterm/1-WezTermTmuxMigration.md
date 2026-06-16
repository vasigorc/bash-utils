# WezTerm tmux-style setup

<!--toc:start-->
- [Config location](#config-location)
- [Why WezTerm](#why-wezterm)
- [tmux-style mappings](#tmux-style-mappings)
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

Try it explicitly without making WezTerm your default terminal:

```bash
wezterm --config-file ~/.config/wezterm/wezterm.lua
```

Validate that WezTerm can parse the config:

```bash
wezterm --config-file ~/.config/wezterm/wezterm.lua show-keys --lua >/tmp/wezterm-keys.lua
```

## Why WezTerm

Goal: keep most tmux/Kitty muscle memory while using WezTerm's native panes, tabs, copy mode, font fallback, and Catppuccin rendering.

Important appearance choices:

- Font: `JetBrainsMonoNL Nerd Font Mono` through `wezterm.font_with_fallback`.
- Font size: `13.0`.
- Theme: Catppuccin Macchiato, with the active Kitty palette pinned explicitly.
- Scrollback: `10000` lines.
- Bell disabled, opacity `0.95`.

## tmux-style mappings

WezTerm calls tmux windows "tabs". The config maps the familiar tmux prefix to WezTerm actions:

| Key | Action |
| --- | --- |
| `Ctrl+b c` | New tab/window |
| `Ctrl+b ,` | Rename current tab/window |
| `Ctrl+b &` | Close current tab/window, with confirmation |
| `Ctrl+b n` / `Ctrl+b p` | Next / previous tab |
| `Ctrl+b l` | Toggle between the last two tabs/windows |
| `Ctrl+b 1..9` | Jump to tab number |
| `Ctrl+b %` | Side-by-side split |
| `Ctrl+b "` | Top/bottom split |
| `Ctrl+b |` | Side-by-side split alias |
| `Ctrl+b -` | Top/bottom split alias |
| `Ctrl+b h/j/k` | Move pane left/down/up |
| `Ctrl+b Shift+l` | Move pane right |
| `Ctrl+b Arrow` | Move between panes |
| `Alt+Arrow` | Resize pane by 5 cells |
| `Ctrl+b Shift+Arrow` | Resize pane by 10 cells |
| `Ctrl+b z` | Toggle pane zoom |
| `Ctrl+b x` | Close current pane, with confirmation |
| `Ctrl+b r` | Reload WezTerm config |
| `Ctrl+b :` | Open WezTerm command palette |

Note: shifted punctuation can vary by keyboard layout/terminal reporting. The config binds both punctuation and physical shifted-key variants for `%` and `"`, but `|` / `-` are kept as reliable aliases.

## Copy mode and search

Enter copy mode:

```text
Ctrl+b [
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

Alternative if this still feels awkward: use WezTerm's command palette (`Ctrl+Shift+p` or `Ctrl+b :`) and search-related commands, or use Claude Code transcript mode for Claude-specific history.

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

- WezTerm tabs are not tmux sessions. They do not survive terminal process exit like tmux sessions do.
- Some exact tmux copy-mode search semantics are not available one-for-one.
- Claude Code fullscreen content lives in Claude's TUI, not WezTerm native scrollback. Use `CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN=1` for classic renderer, or Claude transcript mode when fullscreen is needed.
