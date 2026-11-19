# agents

Role agents for herdr. The orchestrator can be Pi or Claude Code. The role
agents are always Pi.

## Named teams

The machine-local config has one `teams` map. Each team maps role names to
preset aliases from `presets`, or to full `provider/model` identifiers.
`config.example.json` includes these illustrative lineups:

| Team | orchestrator | dev | reviewer | qa | pm | mutant |
|---|---|---|---|---|---|---|
| core | strong | coder | critic | critic | strong | budget |
| primavera | critic | budget | strong | coder | strong | budget |

Starting a team starts only the selected member. Workers start on demand.
Without a team, existing frontmatter presets and defaults stay unchanged.
A missing worker assignment uses its frontmatter preset. A selected team
must assign its orchestrator. Unknown teams and malformed assignments fail
before panes are created. Presets remain machine-local; do not copy example
model choices over an existing config.

Selection is stored atomically under `AGENT_ROLES_STATE_DIR/tabs` (default
`$XDG_STATE_HOME/agent-roles`, or `~/.local/state/agent-roles`). Each Herdr tab
has its own byte-encoded key. Workers in that tab inherit the selection;
`--team` can bind an unbound tab but cannot change a bound one. New `hw`/`ht`
tabs use only the explicit team, never the caller's selection. Immediately
after creation, the helpers clear any binding from a previous use of that tab
id, including for plain (no-team) tabs. The internal `--init-fresh-tab` path
is only for that creation boundary; never use it to reset a live tab.
`--dry-run` shows the team and preset without binding or creating panes.

Tab incarnation is not verified: the inspected Herdr 0.9.5 installed docs do
not establish a lifetime-unique tab identifier. Tabs created outside `hw`/`ht`
can reuse persisted context. Inheritance prints a warning about this limit;
use `hw`/`ht` for fresh tabs rather than relying on plain-tab id uniqueness.
No unsupported Herdr identifier or server-start heuristic is used.

Pins protect the team's baseline: Primavera's reviewer can start on `strong`
without `--force`. Global `AGENT_ROLES_PRESET` does not override pinned roles.
`--models` includes team identity. Pi restart/model changes retain the team,
cwd and session, including an explicit saved no-team choice; a chat restart
stays in chat mode. Run restart/model changes in the agent's saved tab;
cross-tab operations are rejected before stop or prompt. Pinned restarts accept
aliases of the same resolved baseline model without `--force`.

For `hw`/`ht`, model precedence stays: explicit `-m` > `HW_MODEL` > team
assignment > client default. This also applies to `-r` member selection;
selecting a team does not suppress `HW_MODEL`.

The first-class orchestrator uses normal user Pi configuration and tools,
`ORCHESTRATOR.md`, `STYLE.md`, and `orch-wake.ts`, not worker isolation or
reply rules. `--pane ID` reuses a shell pane. Named-team `hw`/`ht` use this
launch path. Claude remains supported with `-o claude`; team model values
must be plain `anthropic/claude-*` identifiers with no thinking suffix.
Other providers fail before layout creation. Direct `--client claude` is
also supported, but Claude restart/model-switch commands are not supported.

## Quick start

| I want to… | Run |
|---|---|
| Start an orchestrator | `hw` (new workspace) or `ht` (new tab) |
| Select a named lineup | `hw --team core` or `ht --team primavera` |
| Start just an orchestrator in this tab | `agent-role orchestrator --team primavera` |
| Start an agent in this pane, no split | `agent-role orchestrator --here` |
| Chat with a team member | `hw --team primavera -r reviewer` |
| Chat with pm or qa in this tab | `agent-role pm --chat --focus` |
| Chat with one role in a new workspace | `hw -r pm` |
| Pick the model | `hw -m strong`, `agent-role qa --chat --focus --preset strong` |
| Stop a role agent | `agent-role --stop <name>` |

In chat mode (`--chat`) there is no orchestrator and no `STATUS:` report.
You talk with the agent. `--focus` moves the focus to its pane. Run it inside
herdr.

| Path | What it is |
|---|---|
| `shared/ORCHESTRATOR.md` | Tells the orchestrator to load the `orchestrate` skill when you ask for a role |
| `shared/STYLE.md` | ASD-STE100 writing rules for the orchestrator only |
| `skills/orchestrate/SKILL.md` | Orchestrator rules and commands (Pi and Claude Code) |
| `roles/_base.md` | Rules that every role agent gets |
| `roles/_task.md`, `roles/_chat.md` | Added by mode: `_task.md` (orchestrator and `STATUS:` report) by default, `_chat.md` (a person, no report) with `--chat` |
| `roles/{dev,reviewer,qa,pm,mutant}.md` | One role each: frontmatter (`preset`, `tools`, `pane`) and a prompt |
| `roles/config.example.json` | Example machine config: preset models, extensions, extra tools |
| `bin/agent-role` | Starts, stops and restarts role agents in herdr panes, changes their models, gives them tasks on stdin, and takes snapshots of the work tree |
| `pi/extensions/role-reply.ts`, `pi/extensions/orch-wake.ts` | Async replies: the role agent writes a reply file when a task ends, and the Pi orchestrator wakes up (see the herdr guide) |
| `install.sh` | Links the tools into your home directory |
| `test/scratch-repo.sh` | Makes a tiny repo to test the setup |
| `test/*-labels.sh`, `test/presets-and-models.sh`, `test/chat-mode.sh`, `test/pane-placement.sh`, `test/current-pane.sh`, `test/solo-role.sh`, `test/async-replies.sh`, `test/async-extensions.sh`, `test/mutant-role.sh` | Tests of `agent-role` and `hw` with a stub herdr and a stub pi |
| `pi/settings.json` | Portable Pi settings (see `pi/README.md`) |

The project's `AGENTS.md` names the checks, the VCS and forge tools, and the
branch policy. The role files name none of them.

How to use `hw` and `ht`, drive agents by hand, fix problems, and test the
setup:
[herdr agent workspaces](../terminals/herdr/2-HerdrAgentWorkspaces.md).

## Start in the current pane

`agent-role ROLE --here` starts the client in the calling herdr pane, with no
split and no new tab. The main use is to start only the orchestrator from a
shell pane:

```sh
agent-role orchestrator --here
agent-role orchestrator --here --team primavera --preset strong
agent-role pm --here --chat --focus --session pm-20260101
```

The foreground client gets the same role, team, preset, session, cwd and
prompt as a split launch. An orchestrator keeps normal user Pi context,
`STYLE.md` and `orch-wake.ts`. Workers keep their isolated Pi agent dir and
their reply rules. Pi and Claude Code are both supported for the
orchestrator.

`--here` needs a terminal on stdin and stdout, and the pane must not host an
agent. It refuses `--pane` in either option order, ignores the role's default
placement, and treats `--focus` as a no-op. `--dry-run` and `--validate`
print the foreground `env ... pi ...` command and start nothing.

Herdr names the agent only after it detects the client in the pane. Detection
is bounded (`AGENT_ROLES_HERE_TRIES` polls, 0.2 s apart, default 100). The
state file appears only after the name is set, so `--models` never lists an
agent that herdr does not know. If detection times out, or the client exits
first, no state file is written and the reason goes to
`$XDG_CACHE_HOME/agent-roles/here-<name>.log`. The launch JSON is printed
before the client starts; it does not prove readiness. `--here` does not
relabel the pane: when you exit the client, herdr clears the agent name and
the pane keeps its shell label.

Exit the client to return to the shell, then resume the same session with:

```sh
agent-role ROLE --here --session ID [--preset PRESET]
```

Because the agent lives in your shell pane, `--stop`, `--restart` and the
model-change restart fallback refuse `--here` agents before any pane closes.
For a batch `--stop`, every name is checked before any pane closes.
`--set-model` still uses the live `/model` path when the agent has a session;
it refuses the restart fallback when the agent has had no task yet.

The protection does not depend on the agent state file. Before the client
starts, `--here` writes a small guard file for the pane in
`$AGENT_ROLES_STATE_DIR/here-panes` (default
`~/.local/state/agent-roles/here-panes`). It holds the agent name, the pane
and the client process id. While that client runs, a stop or restart refuses
when the name or the pane matches, even if the state file is missing or
corrupt, if herdr has not named the agent yet (a name herdr does not know is
not proof of exit), or if the agent got another name. If herdr cannot be read
while a guard is live, a stop refuses too. A second `--here` in a guarded pane
refuses.

After the client exits, the guard is stale. The next stop or check removes it,
so `--stop NAME` then cleans up the old state and closes no pane. Limits: a
guard is stale when its process is gone or its start time differs, so a pid
that the system reused does not keep it. A guard that cannot be read is never
treated as stale: the error names the file, and you remove it when no `--here`
client runs. Closing the pane by hand (`prefix + x`) is not blocked.

## Mutant test measurer

`mutant` builds a kill matrix: which tests catch which small source changes.
It uses the `budget` preset in either example team, or the role's budget
fallback when a team has no explicit mutant assignment.

Give it the source files, the test files, the exact test command, and a
notes directory outside the checkout. It requires a clean tree. Have
reviewer check its proposed mutant list before the run. While it runs, no
dev, other mutant, or read-only role may use that checkout. Take snapshots
before and after the run; their ids must match. The role restores every
source change byte for byte and reports evidence; it never edits tests.


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

- `presets`: the model for each preset (`coder`, `strong`, `critic`,
  `budget`). Keep `critic` in a different model family from `coder`.
  `budget` is a cheap model for mechanical work, such as the mutant role.
  You can add more presets, for example `auto` for a model router. See
  [Models](#models).
- `pinned`: roles that keep the preset of their role file, for example
  `["reviewer"]`. To change the preset of a pinned role, add `--force`.
- `extensions`: the extensions that role agents load, with `-e`. Keep
  `herdr-agent-state.ts` so that herdr can see the agent state. Add the
  extensions that your model providers need. Do not add an extension that
  your Pi install puts in each agent dir: Pi can load both copies and stop.
  Built-in extensions, such as `builtin:mcp`, load only if they are in this
  list (a trusted project can add more, see below).
- `extraTools`: more tools for a role, for example
  `{"qa": ["chrome_navigate_page"]}`.

To remove the links: `agents/install.sh --uninstall`. The config stays.

## Models

Each role file names a preset. The config gives the model of each preset.
To use another model, give a preset name or a `provider/id`:

| Command | What it does |
|---|---|
| `agent-role dev --preset strong` | Starts dev on the `strong` model |
| `agent-role --list` | Lists the available worker roles |
| `agent-role mutant` | Starts the test measurer on `budget` in the side column |
| `agent-role mutant --team primavera --dry-run` | Shows the team model and launch without starting an agent |
| `AGENT_ROLES_PRESET=auto agent-role dev` | Starts each role that is not pinned on `auto` |
| `agent-role --set-model NAME strong` | Switches a running agent with the Pi command `/model`. The session stays. This works also while the agent works: the next model request uses the new model. An agent that has had no task yet starts again in a new pane, as with `--restart`, and the command prints the new start |
| `agent-role --restart NAME --preset strong` | Stops the agent and starts it again on the same session, in a new pane. Use it when the agent is stuck |
| `agent-role --models` | Shows the model of each role agent of the tab and of the orchestrator |
| `hw -m strong` | Starts a Pi orchestrator on the `strong` model |

agent-role stops before it makes a pane when Pi cannot use the model, for
example when no key for its provider is set. On a machine whose config has
no `auto` preset, `--preset auto` stops with an error.

A router picks the model for each request. `--models` shows the model of
the last reply in `reply`, so you can see which model the router used.

The reviewer must not check work with the model family that made it.
`--models`, `--set-model` and each start print a warning when the reviewer
has the family of dev or of the orchestrator of the tab. Put
`reviewer` in `pinned`, so that `AGENT_ROLES_PRESET` and a `--preset` by
mistake do not change it.

agent-role keeps one state file for each role agent in
`~/.local/state/agent-roles/pi-agent/role-agents/`. `--stop` removes it.
Each start gives the session an id (`NAME-YYYYMMDDhhmmss`), so that
`--restart` and `--models` can find the session file. Pi prints a warning
before it starts a session with a new id. This is normal.

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

### After a herdr restart

After a server restart, herdr resumes each agent pane that reported a
session (`[session] resume_agents_on_restore`, on by default). For Pi, it
runs `pi --session <path>` in a new shell. That shell has no
`PI_CODING_AGENT_DIR`, so a resumed role agent uses `~/.pi/agent` and loads
all your packages, a command guard too. It also does not get what
`agent-role` gives at start: the role prompt, the `--tools` list, the reply
extension and the config extensions. Its session file stays in the role
agent dir, so it still looks like the same role agent.

So after a herdr restart, restart each role agent with
`agent-role --restart <name>`. It keeps the session and starts it again with
the role agent dir, the prompt and the tools.

To see if a role session ran with your agent dir, count its custom entries.
Entries that only your packages write show that it did:

```shell
jq -r 'select(.type == "custom" or .type == "custom_message") | .customType' <session.jsonl> | sort | uniq -c
```

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
