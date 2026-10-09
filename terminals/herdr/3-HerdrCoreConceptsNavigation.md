# herdr Core Concepts & Navigation

<!--toc:start-->

- [Legend: tmux vs herdr vocabulary](#legend-tmux-vs-herdr-vocabulary)
- [Prefix Key](#prefix-key)
- [Workspaces (tmux sessions)](#workspaces-tmux-sessions)
  - [Workspace management (Outside herdr)](#workspace-management-outside-herdr)
  - [Workspace management (Inside herdr)](#workspace-management-inside-herdr)
  - [Worktree workspaces (Git worktrees)](#worktree-workspaces-git-worktrees)
  - [Named sessions (not a tmux session)](#named-sessions-not-a-tmux-session)
- [Tabs (tmux windows)](#tabs-tmux-windows)
- [Panes](#panes)
  - [Copy Mode](#copy-mode)
- [Things herdr has that tmux does not](#things-herdr-has-that-tmux-does-not)

<!--toc:end-->

**Date**: 2026-10-09
**Version**: herdr 0.9.1 installed. Default keys come from the 0.9.3 docs; the action names exist in 0.9.1.
**Companion**: [tmux version](../tmux/1-CoreConceptsNavigation.md), [tmux to herdr key map](./1-HerdrTmuxMigration.md)

Keys marked **(config)** come from [config.toml](./config.toml), not from herdr defaults.
Press `prefix ?` to see the live bindings. That list wins over this file.

## Legend: tmux vs herdr vocabulary

> The same word does not always mean the same thing. Read this table first.

| tmux term | herdr term | Difference |
| --- | --- | --- |
| session | **workspace** | Closest match: top-level container, one per project. A workspace also rolls up the state of its agents in the sidebar. |
| window | **tab** | Same idea: a layout inside the container. Tabs are numbered `1..9`, not `0..9`. |
| pane | **pane** | Same idea: a real terminal. Herdr can also read it and send input from the CLI. |
| server | **server** | Same idea: a background process owns the panes. `herdr server stop` kills it and every pane. |
| (none) | **session** | **Trap.** A herdr session is a named, separate server (own sockets, workspaces, state). It is NOT a tmux session. Use workspaces first. |
| attach / detach | attach / detach | `herdr` attaches. `prefix q` detaches. Same behavior. |
| `prefix d` | `prefix q` | Detach key moved. |
| `prefix s` (session switcher) | `prefix w` or `prefix g` | **Trap.** `prefix s` opens **settings** in herdr. |
| `prefix q` (pane numbers) | none | `prefix q` means detach in herdr. There is no pane-number overlay. |
| `prefix l` (last window) | `prefix l` | **Trap.** In herdr, `prefix l` focuses the pane on the right. |
| `prefix o` (next pane) | `prefix Tab` | **Trap.** In herdr, `prefix o` opens the last notification target. |
| command mode (`prefix :`) | none | No command prompt. Use the `herdr` CLI from a shell pane. |
| status bar | tab bar + sidebar | The tab bar shows tabs. The sidebar shows workspaces and agent state. Toggle it with `prefix b`. |
| copy mode | copy mode | Same name, same vim keys, `prefix [`. |
| mouse on | `mouse_capture = true` | On in [config.toml](./config.toml). Herdr is mouse-native: click panes, tabs and workspaces. |
| (none) | **worktree workspace** | Herdr only. A workspace opened on a real **Git worktree** that herdr creates for you. It is grouped under the repo's workspace. See [Worktree workspaces](#worktree-workspaces-git-worktrees). |
| (none) | **agent** | Herdr only. A process it recognizes in a pane. State: `blocked`, `working`, `done`, `idle`, `unknown`. |
| (none) | **modes** | Herdr has terminal mode (keys go to the pane), prefix mode (one action after the prefix) and navigate mode (workspace navigation). |

## Prefix Key

> The Foundation: All herdr commands start with the prefix key, like tmux

| Key | Description |
| --- | --- |
| `Ctrl+b` | Prefix key. Press before any herdr command. Same as tmux. |
| `Ctrl+b ?` | Show every active binding. Press `/` in the list to filter. |
| `Ctrl+b s` | Settings. **Not** a session switcher. |

**Tip**: Press `Ctrl+b`, release both keys, then press the command key. Capital letters in this file mean
`Shift`+letter, for example `Ctrl+b N` is `Ctrl+b` then `Shift+n`.

Reload and resize are swapped **(config)**:

| Key | Default herdr | In this repo |
| --- | --- | --- |
| `Ctrl+b r` | resize mode | reload config (like tmux) |
| `Ctrl+b R` | reload config | resize mode |

## Workspaces (tmux sessions)

> Workspaces=Project Contexts-Persistent containers that survive detach

A workspace owns tabs and panes. Use one per repo, task or investigation.

### Workspace management (Outside herdr)

| Command | Description |
| --- | --- |
| `herdr` | Start or attach to the default session (like `tmux a`). Run it in a terminal that is not inside tmux. |
| `herdr workspace create --cwd <dir> --label <name>` | Create a named workspace in a running server (like `tmux new -s <name>`). Runs at once, with defaults if you omit options. |
| `herdr workspace list` | List all workspaces, with IDs (like `tmux ls`). Prints JSON. |
| `herdr workspace get <id>` | Show one workspace. |
| `herdr workspace focus <id>` | Switch to a workspace. |
| `herdr workspace rename <id> <label>` | Rename a workspace. |
| `herdr workspace close <id>` | Close a workspace (like `tmux kill-session -t`). |
| `hw [dir] [label]` | Repo helper: workspace with nvim plus an orchestrator agent. See [agent workspaces](./2-HerdrAgentWorkspaces.md). |

There is no `herdr new -s`. Names are labels, and the CLI works with IDs. Read the ID from the JSON that
`create` or `list` returns.

### Workspace management (Inside herdr)

| Key | Description |
| --- | --- |
| `Ctrl+b q` | **Detach** from the client. The server keeps running. |
| `Ctrl+b w` | **Workspace picker / navigation**. Move with the keys shown in the panel, Enter to select. |
| `Ctrl+b g` | **Pane navigator**: lists panes across workspaces and tabs; pick one to jump to it. Release `Ctrl` before `g`: `Ctrl+g` goes to the app in the pane (Pi opens its editor). |
| `Ctrl+b N` | New workspace (like `Ctrl+b :new`). |
| `Ctrl+b W` | Rename current workspace (tmux: `Ctrl+b $`). |
| `Ctrl+b D` | Close current workspace (tmux: `kill-session`). |
| `Ctrl+b b` | Toggle the sidebar. |

Not bound by default: next/previous workspace, and jump to workspace by number. Set `next_workspace`,
`previous_workspace` or `switch_workspace = "prefix+shift+1..9"` in `[keys]` if you want them.

Use cases:

- One workspace per project, repo or task
- Agents that keep working while you are detached
- Quick context switching: the sidebar shows which workspace needs attention

### Worktree workspaces (Git worktrees)

> A worktree here is a **Git worktree** (`git worktree`): a second checkout of the same repo on another branch.
> Herdr can create one for you and open it as a new workspace. tmux has no equivalent.

| Command / key | Description |
| --- | --- |
| `herdr worktree create --cwd <repo> --branch <name> [--base <ref>]` | Create a Git worktree for `<name>` and open it as a new workspace. `--branch` is required. `--base` picks the start point. |
| `herdr worktree create ... --path <dir>` | Put the checkout at `<dir>` instead of the default `~/.herdr/worktrees` (set `[worktrees] directory` to change the default). |
| `herdr worktree open --cwd <repo> --branch <name>` | Open an **existing** worktree (by `--branch` or `--path`) as a workspace. Creates nothing. |
| `herdr worktree list --cwd <repo>` | List the worktree workspaces for a repo. |
| `herdr worktree remove --workspace <id>` | Remove the checkout of a herdr-managed worktree. A dirty checkout needs `--force`. |
| `Ctrl+b G` | New worktree workspace, from the keyboard. |

Things to know:

- Herdr runs Git for you. The new workspace starts in the new checkout, so agents in it do not touch your main checkout.
- Herdr may ask whether you trust the repository before it runs Git. `--trust-repository` skips the question for one command. Use it only on repos you trust.
- `herdr workspace create` and `hw` do **not** create worktrees. They open a workspace in a directory that must already exist.

### Named sessions (not a tmux session)

> A herdr session = a separate herdr **server**. Most days you will not need one.

| Command | Description |
| --- | --- |
| `herdr session list` | List sessions (the default one is called `default`). |
| `herdr session attach <name>` | Attach to a named session. |
| `herdr --session <name>` | Same, as a flag. |
| `herdr session stop <name>` | Stop that session's server and its panes. |
| `herdr session delete <name>` | Delete a stopped session. Use the exact name, including case. |
| `herdr server stop` | Stop the default server. Every pane in it dies. |

A named session has its own workspaces, tabs, panes and sockets. It shares the one global config file.

## Tabs (tmux windows)

> Tabs=Layouts - Multiple views within a workspace

Tab operations

| Key | Description |
| --- | --- |
| `Ctrl+b c` | Create new tab |
| `Ctrl+b T` | Rename current tab (tmux: `Ctrl+b ,`) |
| `Ctrl+b X` | **Close** current tab (tmux: `Ctrl+b &`). tmux asks to confirm; whether herdr does is not checked. |

Tab navigation

| Key | Description |
| --- | --- |
| `Ctrl+b n` | Next tab |
| `Ctrl+b p` | **Previous** tab |
| `Ctrl+b 1-9` | Jump to tab by **number**. There is no tab 0. |
| (none) | tmux `Ctrl+b l` (last two windows). No default herdr action. |
| `Ctrl+b w` / `Ctrl+b g` | Workspace picker / pane navigator. tmux's `Ctrl+b w` lists windows instead. |

CLI: `herdr tab list`, `create`, `focus`, `rename`, `close`, `get`.

**Tab bar**: the bar at the top shows your tabs. tmux's `*` (current) and `-` (last) markers do not exist.
The sidebar shows agent state per workspace instead.

**Use Cases:**

- `agents` - orchestrator and role agents
- `logs` - application and system logs
- `server` - dev server, build tools
- `review` - diffs and test runs

## Panes

> **Panes** = **Splits** - Multiple terminals within a tab

**Pane Splitting**

| Key | Description |
| --- | --- |
| `Ctrl+b -` | Split **stacked** (top/bottom). tmux: `Ctrl+b "`. |
| `Ctrl+b \|` | Split **side by side** (left/right) **(config)**. tmux: `Ctrl+b %`. Herdr default is `Ctrl+b v`. |

New panes open in the current directory (`new_cwd = "follow"`).

**Mnemonic**: `-`=horizontal line, `|`=vertical line. This differs from tmux, where `"` and `%` name the
split *line*, not the layout. Read the table, not the symbol.

**Pane Navigation**

| Key | Description |
| --- | --- |
| `Ctrl+b h/j/k/l` | Move to pane in that direction. tmux uses arrow keys. |
| `Ctrl+h/j/k/l` | Move with no prefix **(config)**. Needs the [vim-herdr-navigation plugin](./1-HerdrTmuxMigration.md#seamless-ctrl-hjkl-with-neovim). |
| `Ctrl+b Tab` | Cycle to **next** pane (tmux: `Ctrl+b o`). `Ctrl+b Shift+Tab` goes back. |
| `Ctrl+b ;` | Toggle between **last two** panes **(config)**. Not bound by default. |
| (none) | tmux `Ctrl+b q` (pane numbers). No equivalent. |

**Pane management**

| Key | Description |
| --- | --- |
| `Ctrl+b z` | Zoom-in/out pane |
| `Ctrl+b x` | **Kill** current pane |
| `Ctrl+b P` | Rename pane (herdr only) |
| `Ctrl+b H/J/K/L` | Swap pane with its neighbor (tmux: `Ctrl+b {` and `}`) |
| `Alt+arrows` | Resize directly, no prefix **(config)**. |
| `Ctrl+b R` | Resize mode **(config)**. Herdr default is `Ctrl+b r`. |
| (none) | tmux `Ctrl+b !` (break pane into new window). Keyless. Use `herdr pane move <pane-id> --new-tab`. |

**Exit pane**: Type `exit` or press `Ctrl+d`

CLI: `herdr pane list|current|split|focus|resize|zoom|swap|move|close|rename|read|send-text|send-keys|run`.
`read`, `send-text`, `send-keys` and `run` have no tmux key equivalent. They are what agents use to
drive other panes. See [agent workspaces](./2-HerdrAgentWorkspaces.md).

### Copy Mode

> **Copy Mode**=**Vim-powered Scrollback**-Navigate and copy terminal history

| Key | Description |
| --- | --- |
| `Ctrl+b [` | **Enter** copy mode |
| `q` | **Exit** copy mode |
| `Esc` | Also exits. First press clears a selection or a search. |
| `v` / `Space` | Start selection |
| `y` / `Enter` | Copy selection |
| `/` / `?` | Search forward / backward. `n` and `N` repeat. |

Unlike tmux, `Ctrl+c` does not exit copy mode. Output stays live while you scroll.
Mouse drag-select copies without entering copy mode. Full detail:
[copy mode, scroll and yank](./1-HerdrTmuxMigration.md#copy-mode-scroll-and-yank).

## Things herdr has that tmux does not

| Key / command | Description |
| --- | --- |
| `Ctrl+b b` | Toggle the agent sidebar |
| `Ctrl+b g` | Pane navigator across all workspaces and tabs, in one list |
| `Ctrl+b e` | Edit scrollback in your editor |
| `Ctrl+b o` | Open the target of the last notification |
| `Ctrl+b G` | New Git worktree, opened as its own workspace. See [Worktree workspaces](#worktree-workspaces-git-worktrees). |
| `herdr agent start\|prompt\|read` | Start and talk to agents in panes |
| `herdr --remote <ssh-target>` | Attach to a server on another machine |

## Source

- Keys: herdr 0.9.3 docs, [Keyboard](https://herdr.dev/docs/keyboard/) and [Configuration](https://herdr.dev/docs/configuration/#keybindings), plus the default values in the config reference.
- Commands: `herdr workspace|tab|pane|session --help` on 0.9.1.
- Not tested: the keys were not pressed in a live herdr. Check any key with `prefix ?`.
