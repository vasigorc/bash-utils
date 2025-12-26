# Advanced Window Management

<!--toc:start-->

- [Advanced Window Management](#advanced-window-management)
  - [Advanced Window Operations](#advanced-window-operations)
    - [Window Finding & Jumping](#window-finding-jumping)
  - [Copy Mode Deep Dive](#copy-mode-deep-dive)
    - [Searching in Copy Mode](#searching-in-copy-mode)
    - [Text Selection (Emacs Mode - Default)](#text-selection-emacs-mode-default)
    - [Copy & Paste Workflow](#copy-paste-workflow)
  - [Graceful Cleanup](#graceful-cleanup)
    - [Closing Panes](#closing-panes)
    - [Closing Windows](#closing-windows)
  - [Pane Output Logging](#pane-output-logging)
    - [Pipe Pane (Capture Terminal Output)](#pipe-pane-capture-terminal-output)
  - [Session Management Best Practices](#session-management-best-practices)
    - [Creating & Switching Sessions](#creating-switching-sessions)
  <!--toc:end-->

**Date**: 2025-12-02
**Version**: tmux 3.4

## Advanced Window Operations

**Window reordering**

| Command                                       | Description                                     |
| --------------------------------------------- | ----------------------------------------------- |
| `Ctrl+b :swap-window -s <source> -t <target>` | Swap two windows by number                      |
| `Ctrl+b :swap-window -t <target>`             | Swap current window with target                 |
| `Ctrl+b :move-window -t <position>`           | Move current window to position (must be empty) |
| `Ctrl+b :move-window -k -t <position>`        | Force move, killing existing window at position |

**Examples:**

```bash
# Swap windows 0 and 2
:swap-window -s 0 -t 2

# Swap current window with window 1
:swap-window -t 1

# Move current window to position 4 (if empty)
:move-window -t 4
```

**Tip**: `swap-window` is safer than `move-window` because you rarely have empty positions.

### Window Finding & Jumping

| Key        | Description                                 |
| ---------- | ------------------------------------------- |
| `Ctrl+b f` | **Find** window by name (partial match)     |
| `Ctrl+b w` | Interactive window **picker** (visual list) |
| `Ctrl+b '` | Prompt for window **number or name**        |
| `Ctrl+b l` | Toggle between **last two** windows         |

**Use Cases:**

- `Ctrl+b f` - Quick search when you have many windows
- `Ctrl+b w` - Visual overview of all windows and panes
- `Ctrl+b l` - Rapid toggle (editor ↔ logs, code ↔ tests)

## Copy Mode Deep Dive

### Searching in Copy Mode

**Enter copy mode first:** `Ctrl+b [`

| Key | Description                   |
| --- | ----------------------------- |
| `/` | Search **forward** (like vim) |
| `?` | Search **backward**           |
| `n` | Jump to **next** match        |
| `N` | Jump to **previous** match    |

**Workflow:**

1. `Ctrl+b [` - Enter copy mode
2. `/error` - Search for "error"
3. `n` - Cycle through matches
4. `q` - Exit copy mode

**Real-world use:** Finding specific log entries, error messages, transaction IDs

### Text Selection (Emacs Mode - Default)

**Navigation in copy mode:**

| Key       | Description                |
| --------- | -------------------------- |
| `h/j/k/l` | Move left/down/up/right    |
| `w`       | Jump to next word          |
| `b`       | Jump back word             |
| `0`       | Beginning of line          |
| `$`       | End of line                |
| `g`       | Top of buffer              |
| `G`       | Bottom of buffer (Shift+g) |
| `Ctrl+u`  | Half page up               |
| `Ctrl+d`  | Half page down             |

**Selection & Copying:**

| Key          | Description                           |
| ------------ | ------------------------------------- |
| `Space`      | **Start** selection                   |
| `Enter`      | **Copy** selection and exit copy mode |
| `Esc` or `q` | **Cancel** selection / exit copy mode |

### Copy & Paste Workflow

| Key        | Description                    |
| ---------- | ------------------------------ |
| `Ctrl+b [` | Enter copy mode                |
| `Space`    | Start selection (in copy mode) |
| `Enter`    | Copy selection (in copy mode)  |
| `Ctrl+b ]` | **Paste** from tmux buffer     |

**Position Indicator:** `[0/28]`

- First number = current line (0 = newest/bottom)
- Second number = total lines in scrollback
- Scrolling up increases the first number

## Graceful Cleanup

### Closing Panes

| Method             | When to Use                                                |
| ------------------ | ---------------------------------------------------------- |
| `exit` or `Ctrl+d` | **Preferred** - Clean shell exit, warns about running jobs |
| `Ctrl+b x`         | Force kill pane, asks confirmation (y/n)                   |

**Behavior:**

- `exit` with running process: Shell warns "you have running jobs", confirm to close
- `Ctrl+b x`: tmux kills pane immediately, terminates all processes

### Closing Windows

| Method          | Description                                             |
| --------------- | ------------------------------------------------------- |
| Close all panes | Exit each pane; window auto-closes when last pane exits |
| `Ctrl+b &`      | Kill entire window, asks confirmation (y/n)             |

## Pane Output Logging

### Pipe Pane (Capture Terminal Output)

> **Pipe Pane** = **Output Logging** - Capture all terminal output to a file

| Command                              | Description                                   |
| ------------------------------------ | --------------------------------------------- |
| `Ctrl+b :pipe-pane -o 'cat >>file'`  | Toggle logging current pane output to file    |
| `Ctrl+b :pipe-pane`                  | Stop logging (toggle off)                     |
| `Ctrl+b :pipe-pane -o 'cat >>~/log'` | Log to home directory file                    |

**Format Specifiers:**

| Variable | Description                    | Example |
| -------- | ------------------------------ | ------- |
| `#I`     | Window index                   | `2`     |
| `#P`     | Pane index                     | `1`     |
| `#S`     | Session name                   | `dev`   |
| `#W`     | Window name                    | `logs`  |

**Examples:**

```bash
# Log pane output with window and pane identifiers
Ctrl+b :pipe-pane -o 'cat >>output.#I-#P'
# Creates file: output.2-1 (window 2, pane 1)

# Log with session and window context
Ctrl+b :pipe-pane -o 'cat >>~/logs/#S-#W.log'
# Creates file: ~/logs/dev-logs.log

# Using custom command to process output
Ctrl+b :pipe-pane -o 'terminal >>chapter_2_exercises.#I-#P'
# Pipes through 'terminal' command to file

# Stop logging
Ctrl+b :pipe-pane
```

**Workflow:**

1. Start logging before running commands: `Ctrl+b :pipe-pane -o 'cat >>session.log'`
2. Run your commands (terraform, build, tests, etc.)
3. Stop logging: `Ctrl+b :pipe-pane`
4. Review output: `less session.log` or `cat session.log`

**Use Cases:**

- Capture build logs for later analysis
- Record terraform/deployment outputs
- Save debugging sessions
- Document terminal workflows for tutorials
- Keep audit trail of administrative commands

**Tips:**

- Use `>>` (append) instead of `>` (overwrite) to preserve logs across toggles
- Files are created in current working directory unless absolute path specified
- Logging continues even when switching panes/windows
- Check if logging is active: Look for `[pipe]` indicator in pane status

## Session Management Best Practices

### Creating & Switching Sessions

| Command                                                              | Description                             |
| -------------------------------------------------------------------- | --------------------------------------- |
| `tmux new-session -d -s <name>`                                      | Create session in background (detached) |
| `tmux switch-client -t <name>`                                       | Switch to another session               |
| Combined: `tmux new-session -d -s <name> \; switch-client -t <name>` | Create and switch in one command        |

**Workflow:**

```bash
# From inside tmux, create new project session without leaving current one
tmux new-session -d -s ml-project \; switch-client -t ml-project

# Switch between projects
Ctrl+b s  # Interactive session picker

# List all sessions from any terminal
tmux ls
```
