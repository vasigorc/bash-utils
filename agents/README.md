# agents

Role agents for herdr. The orchestrator can be Pi or Claude Code. The role
agents are always Pi.

| Path | What it is |
|---|---|
| `shared/ORCHESTRATOR.md` | Tells the orchestrator to load the `orchestrate` skill when you ask for a role |
| `shared/STYLE.md` | ASD-STE100 writing rules for the orchestrator only |
| `skills/orchestrate/SKILL.md` | Orchestrator rules and commands (Pi and Claude Code) |
| `roles/_base.md` | Rules that every role agent gets |
| `roles/{dev,reviewer,qa,pm}.md` | One role each: frontmatter (`preset`, `tools`, `pane`) and a prompt |
| `roles/config.example.json` | Example machine config: preset models, extensions, extra tools |
| `bin/agent-role` | Starts and stops role agents in herdr panes, gives them tasks on stdin, and takes snapshots of the work tree |
| `install.sh` | Links the tools into your home directory |
| `test/scratch-repo.sh` | Makes a tiny repo to test the setup |
| `pi/settings.json` | Portable Pi settings (see `pi/README.md`) |

The project's `AGENTS.md` names the checks, the VCS and forge tools, and the
branch policy. The role files name none of them.

How to use `hw` and `ht`, drive agents by hand, fix problems, and test the
setup:
[herdr agent workspaces](../terminals/herdr/2-HerdrAgentWorkspaces.md).

## Install

From the root of this repo:

```sh
agents/install.sh --dry-run   # show what it will do
agents/install.sh
```

The script finds the repo from its own location, so the repo can live
anywhere. You can run it again at any time. It makes these links:

| Link | Points to | Made only if |
|---|---|---|
| `~/.local/bin/agent-role` | `agents/bin/agent-role` | always |
| `~/.pi/agent/skills/orchestrate` | `agents/skills/orchestrate` | `~/.pi/agent` exists |
| `~/.claude/skills/orchestrate` | `agents/skills/orchestrate` | `~/.claude` exists |
| `$ZSH_CUSTOM/herdr.zsh` | `terminals/herdr/herdr.zsh` | oh-my-zsh is installed |

oh-my-zsh loads `$ZSH_CUSTOM/*.zsh`, so `hw` and `ht` need no line in
`~/.zshrc`.
Without oh-my-zsh, the script prints the `source` line to add.

It also copies `roles/config.example.json` to
`~/.config/agent-roles/config.json` if that file does not exist. Edit it for
the machine:

- `presets`: the model for each preset (`coder`, `strong`, `critic`). Keep
  `critic` in a different model family from `coder`.
- `extensions`: the extensions that role agents load, with `-e`. Keep
  `herdr-agent-state.ts` so that herdr can see the agent state. Add the
  extensions that your model providers need. Do not add an extension that
  your Pi install puts in each agent dir: Pi can load both copies and stop.
  Built-in extensions, such as `builtin:mcp`, load only if they are in this
  list (a trusted project can add more, see below).
- `extraTools`: more tools for a role, for example
  `{"qa": ["chrome_navigate_page"]}`.

To remove the links: `agents/install.sh --uninstall`. The config stays.

## Role agent dir

Role agents do not use `~/.pi/agent`. `agent-role` gives them their own Pi
agent dir, `~/.local/state/agent-roles/pi-agent` (set another one with
`AGENT_ROLES_PI_DIR`). Each new pane gets it in `PI_CODING_AGENT_DIR`. A pane
that is there already gets it with `export`, and its shell keeps it.

So Pi does not find your extensions, packages, skills and prompts in
`~/.pi/agent`. From outside the project, only the config extensions load,
and the extensions that a managed Pi install adds to each agent dir. This is
why `agent-role` does not use `-ne`: a managed install can refuse it.

Before each start, `agent-role` links `auth.json`, `models.json`,
`keybindings.json`, `trust.json` and `AGENTS.md` from `~/.pi/agent`. It copies
`theme`, `tuiMode`, `terminal`, `hideThinkingBlock` and `defaultThinkingLevel`
from your settings. Role agents therefore trust the same projects as you, and
a trust choice in a role agent changes your file.

In a project that you trust, a role agent also loads the project's own
`.pi` resources: skills, prompts, settings, and extensions. `-ne` used to
block project extensions, and Pi has no setting that blocks only them.
`agent-role` prints a note at start when the project `.pi` adds extensions
or packages.

`auth.json` and `trust.json` are links to your files. Pi locks a file by
the path it opens, so your Pi and a role agent use two locks for the same
file. When both write at the same time, one write can be lost:

- `trust.json` changes only when you answer a trust prompt. A lost write
  means that Pi asks again later.
- `auth.json` changes when Pi refreshes an OAuth token or you log in. A
  lost write can keep an old token. Run `/login` again if a provider stops.
  With API keys from the environment, the file does not change.

Do not copy `auth.json` instead: a token refresh in a copy makes the token
in your file invalid.

Role sessions are in the role agent dir. `/resume` in your own Pi does not
show them.

## Orchestrator prompt

Only the orchestrator gets `ORCHESTRATOR.md` and `STYLE.md`. `hw` and `ht`
start it with `--append-system-prompt` (Pi) or `--append-system-prompt-file`
(Claude Code). Role agents and Pi sessions outside `hw` and `ht` do not get
them.

## Notes

- `--append-system-prompt` replaces `APPEND_SYSTEM.md`. It does not add to
  it. A Pi orchestrator from `hw` or `ht` therefore ignores any
  `APPEND_SYSTEM.md`.
- A project `.pi/APPEND_SYSTEM.md` replaces `~/.pi/agent/APPEND_SYSTEM.md`.
- Pi ignores a name in `--tools` that is not a tool. It shows no error. Check
  the tool names in `extraTools`.
