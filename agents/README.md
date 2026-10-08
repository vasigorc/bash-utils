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
| `bin/agent-role` | Starts or stops a role agent in a herdr pane |
| `install.sh` | Links the tools into your home directory |
| `test/scratch-repo.sh` | Makes a tiny repo to test the setup |
| `pi/settings.json` | Portable Pi settings (see `pi/README.md`) |

The project's `AGENTS.md` names the checks, the VCS and forge tools, and the
branch policy. The role files name none of them.

How to use `hw`, drive agents by hand, fix problems, and test the setup:
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

oh-my-zsh loads `$ZSH_CUSTOM/*.zsh`, so `hw` needs no line in `~/.zshrc`.
Without oh-my-zsh, the script prints the `source` line to add.

It also copies `roles/config.example.json` to
`~/.config/agent-roles/config.json` if that file does not exist. Edit it for
the machine:

- `presets`: the model for each preset (`coder`, `strong`, `critic`). Keep
  `critic` in a different model family from `coder`.
- `extensions`: the only extensions that role agents load. `agent-role` starts
  Pi with `-ne`. Keep `herdr-agent-state.ts` so that herdr can see the agent
  state. Add the extensions that your model providers need.
- `extraTools`: more tools for a role, for example
  `{"qa": ["chrome_navigate_page"]}`.

To remove the links: `agents/install.sh --uninstall`. The config stays.

## Orchestrator prompt

Only the orchestrator gets `ORCHESTRATOR.md` and `STYLE.md`. `hw` starts it
with `--append-system-prompt` (Pi) or `--append-system-prompt-file` (Claude
Code). Role agents and Pi sessions outside `hw` do not get them.

## Notes

- `--append-system-prompt` replaces `APPEND_SYSTEM.md`. It does not add to
  it. A Pi orchestrator from `hw` therefore ignores any `APPEND_SYSTEM.md`.
- A project `.pi/APPEND_SYSTEM.md` replaces `~/.pi/agent/APPEND_SYSTEM.md`.
- Pi ignores a name in `--tools` that is not a tool. It shows no error. Check
  the tool names in `extraTools`.
