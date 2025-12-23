# Core Concepts & Navigation

<!--toc:start-->

- [Prefix Key](#prefix-key)
- [Sessions](#sessions)
  - [Session management (Outside tmux)](#session-management-outside-tmux)
  - [Session management (Inside tmux)](#session-management-inside-tmux)
- [Windows](#windows)
- [Panes](#panes)
  - [Copy Mode](#copy-mode)
  <!--toc:end-->

**Date**: 2025-12-01
**Version**: tmux 3.4

## Prefix Key

> The Foundation: All tmux commands start with the prefix key

| Key        | Description                                |
| ---------- | ------------------------------------------ |
| `Ctrl+b`   | Prefix key - press before any tmux command |
| `Ctrl+b :` | Enter command mode (like vim `:`)          |

**Tip**: Press `Ctrl+b`, release both keys, then press the command key.

## Sessions

> Sessions=Project Contexts-Persistent workspace that survive terminal disconnects

### Session management (Outside tmux)

| Command                       | Description                |
| ----------------------------- | -------------------------- |
| `tmux new -s <name>`          | Create new named session   |
| `tmux ls`                     | List all sessions          |
| `tmux a`                      | Attach to last session     |
| `tmux a -t <name>`            | Attach to specific session |
| `tmux kill-session -t <name>` | Kill specific session      |

### Session management (Inside tmux)

| Key                              | Description                                           |
| -------------------------------- | ----------------------------------------------------- |
| `Ctrl+b d`                       | **Detach** from current session                       |
| `Ctrl+b s`                       | **Interactive session switcher** (arrow keys + Enter) |
| `Ctrl+b $`                       | Rename current session                                |
| `Ctrl+b :kill-session -t <name>` | Kill session from the command mode                    |
| `Ctrl+b :new`                    | Start a new session                                   |

Use cases:

- Different projects/contexts per session
- Long-running processes that survive disconnects
- Quick context switching without loosing layouts

## Windows

> Windows=Tabs - Multiple workspaces within a session

Window operations

| Key        | Description                                   |
| ---------- | --------------------------------------------- |
| `Ctrl+b c` | Create new window                             |
| `Ctrl+b ,` | Rename current window                         |
| `Ctrl+b &` | **Kill** current workflow (asks confirmation) |

Window navigation

| Key          | Description                                  |
| ------------ | -------------------------------------------- |
| `Ctrl+b n`   | Next window                                  |
| `Ctrl+b p`   | **Previous** window                          |
| `Ctrl+b 0-9` | Jump to window by **number**                 |
| `Ctrl+b l`   | Toggle between last **two** windows          |
| `Ctrl+b w`   | Interactive window list (arrow keys + Enter) |

**Status Bar Indicators**:

- `0:editor*` - Window 0 named "editor", currently active(\*)
- `1:logs-` - Window 1 named "logs", last visited

**Use Cases:**

- `0:editor` - Code and git commands
- `1:logs` - Application and system logs
- `2:build` - Build tools (cargo, sbt, npm)
- `3:monitoring` - htop, system metrics

## Panes

> **Panes** = **Splits** - Multiple terminals within a window

**Pane Splitting**

| Key        | Description                         |
| ---------- | ----------------------------------- |
| `Ctrl+b "` | Split **horizontally** (top/bottom) |
| `Ctrl+b %` | Split **vertically** (left/right)   |

**Mnemonic**: `"`=horizontal line, `%`=vertical slash

**Pane Navigation**

| Key                  | Description                              |
| -------------------- | ---------------------------------------- |
| `Ctrl+b <arrow_key>` | Move to pane in **arrow** direction      |
| `Ctrl+b o`           | Cycle to **next** pane                   |
| `Ctrl+b ;`           | Toggle between **last two** panes        |
| `Ctrl+b q`           | Show pane numbers (press number to jump) |

**Pane management**

| Key        | Description                |
| ---------- | -------------------------- |
| `Ctrl+b z` | Zoom-in/out pane           |
| `Ctrl+b x` | **Kill** current pane      |
| `Ctrl+b !` | break pane into new window |
| `Ctrl+b {` | Move pane left             |
| `Ctrl+b }` | Move pane right            |

**Exit pane**: Type `exit` or press `Ctrl+d`

### Copy Mode

> **Copy Mode**=**Vim-powered Scrollback**-Navigate and copy terminal history

| Key        | Description            |
| ---------- | ---------------------- |
| `Ctrl+b [` | **Enter** copy mode    |
| `q`        | **Exit** copy mode     |
| `Ctrl+c`   | Also exist copy mode   |
| `Enter`    | Copy to general buffer |
