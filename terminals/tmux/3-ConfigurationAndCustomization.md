# Configuration and Customization

<!--toc:start-->

- [Configuration and Customization](#configuration-and-customization)
  - [Configuration Management](#configuration-management)
    - [Config File Location](#config-file-location)
    - [Reload Configuration](#reload-configuration)
    - [Full Server Restart](#full-server-restart)
  - [Vi Mode in Copy Mode](#vi-mode-in-copy-mode)
    - [Vi-Style Selection & Copy](#vi-style-selection-copy)
    - [Selection Modes](#selection-modes)
  - [Custom Keybindings](#custom-keybindings)
    - [Pane Splitting](#pane-splitting)
    - [Pane Resizing](#pane-resizing)
  - [Sensible Defaults (This Config)](#sensible-defaults-this-config) - [General Settings](#general-settings) - [Terminal & Display](#terminal-display)
  <!--toc:end-->

## Configuration Management

Copy [tmux.conf](./tmux.conf) to `~/.tmux.conf` for the described below changes to take effect.

### Config File Location

- Primary config: `~/.tmux.conf`
- Loaded automatically when tmux server starts

### Reload Configuration

- **Reload config**: `Ctrl+b r` (custom shortcut)
- **Manual reload**: `Ctrl+b :source-file ~/.tmux.conf`
- **Note**: Some bindings require server restart to fully clear

### Full Server Restart

- Kill server: `tmux kill-server` (closes all sessions!)
- Start fresh: `tmux` or `tmux new -s name`

## Vi Mode in Copy Mode

### Vi-Style Selection & Copy

1. Enter copy mode: `Ctrl+b [`
2. Navigate to start position
3. **Begin selection**: `v` (visual mode)
4. Navigate to extend selection
5. **Copy/yank**: `y` (exits copy mode)
6. **Paste**: `Ctrl+b ]`

### Selection Modes

- `v` - character-wise visual selection
- `V` - line-wise visual selection
- `Ctrl+v` - rectangle/block selection (toggle while in visual mode)
- `r` - alternative rectangle toggle

## Custom Keybindings

### Pane Splitting

- **Vertical split** (side-by-side): `Ctrl+b |`
- **Horizontal split** (top-bottom): `Ctrl+b -`
- Opens in current directory automatically

### Pane Resizing

- **Fine resize** (5 cells): `Alt+Left/Right/Up/Down` (no prefix!)
- **Large resize** (10 cells): `Ctrl+b Shift+Left/Right/Up/Down`
- Repeatable: keep holding after first press

## Sensible Defaults (This Config)

### General Settings

- **Mouse support**: Enabled (click, scroll, resize)
- **Scrollback buffer**: 10,000 lines
- **Base index**: Windows and panes start at 1 (not 0)
- **Auto-renumber**: Windows renumber when one closes
- **Escape delay**: 0ms (critical for vim)

### Terminal & Display

- **Terminal type**: `tmux-256color` (true color support)
- **Focus events**: Enabled (vim can detect pane switches)
- **Passthrough**: Enabled (for NeoVim image.nvim)
