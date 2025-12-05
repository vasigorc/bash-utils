# Plugins & Power Features

<!--toc:start-->

- [TPM (Tmux Plugin Manager)](#tpm-tmux-plugin-manager)
  - [Installation](#installation)
  - [Plugin Management](#plugin-management)
- [tmux-resurrect (Session Persistence)](#tmux-resurrect-session-persistence)
  - [Usage](#usage)
  - [What Gets Saved](#what-gets-saved)
- [tmux-continuum (Automatic Persistence)](#tmux-continuum-automatic-persistence)
  - [Configuration](#configuration)
- [tmux-yank (Clipboard Integration)](#tmux-yank-clipboard-integration)
  - [Copy Mode with Clipboard](#copy-mode-with-clipboard)
- [Plugin Configuration Reference](#plugin-configuration-reference)
<!--toc:end-->

**Date**: 2025-12-05
**Version**: tmux 3.4

## TPM (Tmux Plugin Manager)

> Foundation for managing tmux plugins

### Installation

| Command                                                             | Description             |
| ------------------------------------------------------------------- | ----------------------- |
| `git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm` | Install TPM             |
| `ls -la ~/.tmux/plugins/`                                           | Verify TPM installation |

**Add to `.tmux.conf`:**

```
# List of plugins
set -g @plugin 'tmux-plugins/tpm'

# Initialize TMUX plugin manager (keep this line at the very bottom)
run '~/.tmux/plugins/tpm/tpm'
```

### Plugin Management

| Key            | Description                                |
| -------------- | ------------------------------------------ |
| `Ctrl+b I`     | **Install** new plugins (capital I)        |
| `Ctrl+b U`     | **Update** all plugins (capital U)         |
| `Ctrl+b alt+u` | **Uninstall** plugins not listed in config |

**Workflow:**

1. Add `set -g @plugin 'author/plugin-name'` to `.tmux.conf`
2. Reload config: `Ctrl+b r`
3. Install: `Ctrl+b I`

## tmux-resurrect (Session Persistence)

> Save and restore complete tmux sessions (windows, panes, programs)

**Installation:**

```
# Add to .tmux.conf plugins section
set -g @plugin 'tmux-plugins/tmux-resurrect'
```

### Usage

| Key             | Description                       |
| --------------- | --------------------------------- |
| `Ctrl+b Ctrl+s` | **Save** current session manually |
| `Ctrl+b Ctrl+r` | **Restore** saved session         |

**Messages:**

- Save: "Tmux environment saved!"
- Restore: "Tmux restore complete!"

### What Gets Saved

| Item                | Description                           |
| ------------------- | ------------------------------------- |
| Session names       | All named sessions                    |
| Window names        | Custom window names                   |
| Pane layouts        | Split configurations                  |
| Working directories | Each pane's current directory         |
| Running programs    | Basic programs (vim, less, man, etc.) |

**Use Cases:**

- System reboots - restore entire development environment
- Tmux server crashes - recover all work
- End of day - save state, restore tomorrow
- Testing configurations - save before experimenting

## tmux-continuum (Automatic Persistence)

> Automatic saving and restoration of tmux sessions

**Installation:**

```
# Add to .tmux.conf plugins section (after tmux-resurrect)
set -g @plugin 'tmux-plugins/tmux-continuum'
```

### Configuration

| Option                                 | Value      | Description                          |
| -------------------------------------- | ---------- | ------------------------------------ |
| `set -g @continuum-restore 'on'`       | `on`/`off` | Auto-restore on tmux start           |
| `set -g @continuum-save-interval '15'` | `0-60`     | Save interval in minutes (0=disable) |

**Verify Configuration:**

```
tmux show-option -gv @continuum-save-interval    # Should show: 15
tmux show-option -gv @continuum-restore          # Should show: on
```

**What Happens:**

- Every 15 minutes: Session automatically saved
- On `tmux` start: All previously saved sessions get restored
- No manual intervention needed

**Combined Workflow with tmux-resurrect:**

- `tmux-resurrect`: Manual save/restore when you want
- `tmux-continuum`: Automatic safety net every 15 minutes
- Best of both: Manual control + automatic backup

## tmux-yank (Clipboard Integration)

> Copy from tmux directly to system clipboard

**Installation:**

```
# Add to .tmux.conf plugins section
set -g @plugin 'tmux-plugins/tmux-yank'
```

### Copy Mode with Clipboard

| Key             | Description                                     |
| --------------- | ----------------------------------------------- |
| `Ctrl+b [`      | **Enter** copy mode                             |
| `v`             | Start **visual selection** (vi-mode)            |
| `V`             | Start **line selection** (vi-mode)              |
| `Ctrl+v`        | Start **block selection** (vi-mode)             |
| `y`             | **Copy to system clipboard** and exit copy mode |
| `q` or `Escape` | Exit copy mode without copying                  |

**Navigation in Copy Mode (vi-mode):**

| Key        | Description                    |
| ---------- | ------------------------------ |
| `h/j/k/l`  | Move cursor left/down/up/right |
| `w/b`      | Jump forward/backward by word  |
| `0`        | Start of line                  |
| `$`        | End of line                    |
| `g`        | Top of history                 |
| `G`        | Bottom of history              |
| `Ctrl+u`   | Page up                        |
| `Ctrl+d`   | Page down                      |
| `/pattern` | Search forward                 |
| `?pattern` | Search backward                |
| `n`        | Next search result             |
| `N`        | Previous search result         |

**Paste from System Clipboard:**

| Method              | Description                |
| ------------------- | -------------------------- |
| `Ctrl+Shift+v`      | Paste in terminal (Linux)  |
| `Ctrl+v`            | Paste in most applications |
| Right-click → Paste | Mouse paste                |

**Use Cases:**

- Copy error messages from logs → paste in browser/Slack
- Copy code from tmux → paste in external editor
- Copy command output → paste in documentation
- Works across all applications, not just tmux

## Plugin Configuration Reference

**Complete `.tmux.conf` plugins section:**

```
# List of plugins
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @plugin 'tmux-plugins/tmux-yank'

# Catppuccin theme (optional)
set -g @plugin "mark-pitblado/catppuccin-tmux"
set -g @catppuccin-tmux_show_git 0
set -g @catppuccin-tmux_pane_id_style hide
set -g @catppuccin-tmux_zoom_id_style hide
set -g @catppuccin-tmux_show_path 1
set -g status-position top

# tmux-continuum configuration
set -g @continuum-restore 'on'
set -g @continuum-save-interval '15'

# Initialize TMUX plugin manager (keep this line at the very bottom)
run '~/.tmux/plugins/tpm/tpm'
```

**Directory Structure:**

```
~/.tmux/plugins/
├── tpm/                    # Plugin manager
├── tmux-resurrect/         # Session persistence
├── tmux-continuum/         # Automatic saving
└── tmux-yank/              # Clipboard integration
```

**Troubleshooting:**

| Issue                     | Solution                                                                                                                                           |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| Plugin not installing     | 1. Check syntax in `.tmux.conf`<br>2. Reload: `Ctrl+b r`<br>3. Try: `Ctrl+b I` again                                                               |
| Resurrect not working     | 1. Check `~/.tmux/resurrect/` exists<br>2. Test save: `Ctrl+b Ctrl+s`<br>3. Check for "saved" message                                              |
| Continuum not auto-saving | 1. Verify interval: `tmux show-option -gv @continuum-save-interval`<br>2. Check plugin installed: `ls ~/.tmux/plugins/`                            |
| Clipboard not working     | 1. Test in copy mode: `Ctrl+b [`, then `v` to select, `y` to copy<br>2. Try paste in external app<br>3. Ensure `xclip` or `xsel` installed (Linux) |

**Installation verification:**

```
# Check all plugins installed
ls -la ~/.tmux/plugins/

# Should see:
# - tpm/
# - tmux-resurrect/
# - tmux-continuum/
# - tmux-yank/
```
