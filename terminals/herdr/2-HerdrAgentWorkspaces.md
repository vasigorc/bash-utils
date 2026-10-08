# herdr agent workspaces

<!--toc:start-->

- [herdr agent workspaces](#herdr-agent-workspaces)
  - [What you get](#what-you-get)
  - [Before you start](#before-you-start)
  - [Start a workspace with hw](#start-a-workspace-with-hw)
  - [Work with the orchestrator](#work-with-the-orchestrator)
  - [Drive agents by hand](#drive-agents-by-hand)
  - [Close an agent's pane](#close-an-agents-pane)
  - [Troubleshooting](#troubleshooting)
  - [Test the setup](#test-the-setup)
  <!--toc:end-->

## What you get

One herdr workspace for each project, with an orchestrator agent and role
agents in panes:

```text
+----------------+          +----------------+------+
| nvim           |          | nvim           | side |
+--------+-------+   --->   +--------+-------+      |
| orch   | dev   |          | orch   | dev   |      |
+--------+-------+          +--------+-------+------+
```

- The **orchestrator** (`orch`) is the agent that you talk with. It can be Pi
  or Claude Code. It plans the work and gives tasks to the role agents.
- The **role agents** are always Pi. dev opens right of the orchestrator.
  pm, qa, and reviewer open in the **side** column, one under the other.
- The side column is there only when you need it. The first of pm, qa, or
  reviewer makes it. When the last of them stops, it goes away and the layout
  returns to two rows.
- The role prompts, models, and the `agent-role` launcher are in
  [agents](../../agents/README.md).
- The project's `AGENTS.md` tells every agent which checks and tools to use.

The tmux-to-herdr setup itself is in
[herdr as a tmux replacement](./1-HerdrTmuxMigration.md).

## Before you start

1. Install herdr and jq, and run herdr outside tmux. See
   [Install](./1-HerdrTmuxMigration.md#install-alongside-tmux) and
   [Launching](./1-HerdrTmuxMigration.md#launching).
2. Install the agent integrations, so that herdr can see when an agent is
   working, blocked, or done:

   ```sh
   herdr integration install pi
   herdr integration install claude
   herdr integration status          # both must show "current"
   ```

3. From the root of this repo, run `agents/install.sh`. See
   [agents: Install](../../agents/README.md#install). Then open a new shell,
   so that `hw` is loaded.

## Start a workspace with hw

```sh
hw                              # current directory, Pi orchestrator
hw ~/src/my-project my-project  # directory and label
hw -o claude -m sonnet          # Claude Code orchestrator on Sonnet
hw -h                           # usage
```

| Option | Environment variable | Default | Meaning |
|---|---|---|---|
| `-o`, `--orchestrator` | `HW_ORCHESTRATOR` | `pi` | `pi` or `claude` |
| `-m`, `--model` | `HW_MODEL` | the orchestrator's own | orchestrator model (format below) |

An option wins over its environment variable, and the variable wins over the
default. Use the variables for a machine default, for example
`export HW_ORCHESTRATOR=claude` in `~/.zshrc`.

The model format depends on the orchestrator:

| Orchestrator | Format | Examples | List them |
|---|---|---|---|
| `pi` | `provider/id`, with an optional `:thinking` level | `anthropic/claude-opus-5-5`, `openrouter/z-ai/glm-5.3:high` | `pi --list-models` |
| `claude` | an alias or a model id, with no provider | `sonnet`, `opus`, `claude-sonnet-5-5` | `claude --help` (see `--model`) |

`hw` stops with a message if herdr or jq is not installed, or if the herdr
server is not running. You can run `hw` outside herdr, for example from tmux.
The workspace then appears in herdr, and `hw` tells you so.

`hw` makes the workspace, opens nvim at the top, and starts the orchestrator
at the bottom. The orchestrator's name is `<workspace id>-orch` in lower case,
for example `w4-orch`. It gets two extra prompt files that no other agent gets:
`agents/shared/ORCHESTRATOR.md` and `agents/shared/STYLE.md` (ASD-STE100).

## Work with the orchestrator

Tell the orchestrator what you want and which roles to use. For example:

> Add input validation to the signup form. Plan it, have dev implement it
> test-first, and have reviewer review it.

- You do not have to name the `orchestrate` skill. When you ask for dev,
  reviewer, qa, or pm, the orchestrator loads it.
- The orchestrator starts and stops the role agents with `agent-role`.
- pm runs only when you ask for it. pm files issues only when the orchestrator
  tells it to.
- **Approvals.** Claude Code asks before it runs a command that is not in its
  allowlist. A Pi extension can do the same. Answer in the orchestrator pane.
  Use one approver only: if two people or tools answer, a late Enter goes into
  the input box.
- The orchestrator waits in the foreground while an agent works, so it cannot
  talk with you during that time. See the "Waiting" part of the
  `orchestrate` skill.

### Without hw

Any Pi or Claude Code session in a herdr pane can be the orchestrator.
`install.sh` links the `orchestrate` skill for both, and `agent-role` is on
`PATH`. Outside herdr, the skill stops and says that it needs a herdr pane.

| Case | What to do |
|---|---|
| A session that runs already | Type `/skill:orchestrate` (Pi) or `/orchestrate` (Claude Code) at the start of a message, then give the task. Or ask for dev or reviewer, and the agent loads the skill itself. |
| A new session with the full prompt | `pi --append-system-prompt ~/.cache/agent-roles/orchestrator.md`, or `claude --append-system-prompt-file ~/.cache/agent-roles/orchestrator.md`. `hw` writes this file each time it runs. |

The skill alone does not give the orchestrator the `STYLE.md` writing rules
or the `ORCHESTRATOR.md` prompt. Only the full prompt gives them. In Pi,
`--append-system-prompt` replaces `APPEND_SYSTEM.md`.

## Drive agents by hand

You do not usually need this: the orchestrator does it. It helps when you test
or fix something.

`agent-role` must run in a shell in the workspace. It opens dev right of the
pane that runs it, so run it from the orchestrator pane with the `!` shell
prefix. Pi and Claude Code both have it:

```text
!agent-role dev
```

The orchestrator then also sees the new agent's name.

| Task | Command |
|---|---|
| Start a role agent | `agent-role dev` (or `reviewer`, `qa`, `pm`) |
| Preview the start command | `agent-role dev --dry-run` |
| Stop role agents and close their panes | `agent-role --stop w4-dev w4-reviewer` |
| List agents | `herdr agent list` |
| Show one agent | `herdr agent get w4-dev` |
| Give a task and wait | `agent-role --prompt w4-dev --wait --timeout 300000`, with the task on stdin (below) |
| Wait again, while it works | `herdr agent wait w4-dev --timeout 300000` |
| Read its output | `herdr agent read w4-dev --source recent-unwrapped --lines 200` |
| Stop the command that it runs | `herdr agent send-keys w4-dev esc` |
| Snapshot of the files | `agent-role --snapshot` (a git tree id; equal ids mean no file changed) |
| Focus its pane | `herdr agent focus w4-dev` |
| Close the workspace | `herdr workspace close w4` |

Give the task in a quoted heredoc. The shell then changes nothing in it, so
backticks and `$(...)` stay text:

```sh
agent-role --prompt w4-dev --wait --timeout 300000 <<'TASK'
Fix the bug in `src/main.go`. Run the tests.
TASK
```

In `herdr agent prompt w4-dev "<task>"`, the shell runs the backticks and the
`$(...)` in the task before herdr gets it.

## Close an agent's pane

The orchestrator keeps its agents open between tasks, because a follow-up
task to the same agent keeps its context. It stops them when the work is
complete. Close a pane yourself only after the orchestrator's final report,
or when you drive the agents by hand.

There are three ways:

1. **`agent-role --stop <name> [<name>...]`** stops each agent and closes its
   pane. If it was the last agent in the side column, the side column closes
   too. An agent that is not there any more is not an error.
2. **`prefix + x`** in the pane closes it, as in tmux. Pi saves the session as
   it goes, so nothing is lost. The side column also closes with its last
   pane.
3. **In the pane:** quit the agent (ctrl+d in Pi). The pane stays open with an
   idle shell. The next side agent reuses it.

**Close the whole workspace** with `herdr workspace close <id>`. herdr sends
SIGHUP to every pane, so all agents and nvim stop. Close it only when no agent
is in a turn. You can get the work back:

- Pi and Claude Code keep their sessions on disk. Run `pi -r` or `claude -r`
  in the same directory and pick the session. The orchestrator and the role
  agents share that directory, so check that you pick the right one.
- nvim does not save open buffers, but it keeps a swap file. Recover the edits
  with `nvim -r <file>`.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `hw: the herdr server is not running` | No herdr server. | Start `herdr` in a terminal tab that does not run tmux. |
| `agent_pane_busy` | The shell in a new pane is not ready yet. | `hw` and `agent-role` retry for 15 s. Run the command again. |
| Claude: `agent_not_ready ... blocked during startup` | Claude Code shows the folder-trust dialog the first time in a directory. | Answer it in the pane. herdr then sees the agent. |
| Status `blocked` | A permission prompt or a dialog waits for input. | Read the pane and answer. |
| A wait runs to its timeout after the agent finished | The wait used `--until done`. herdr changes `done` to `idle` when someone looks at the pane. | Wait without `--until`: it ends at `idle`, `done`, or `blocked`. |
| An agent works for a long time. Its pane shows one command, and the `Elapsed` time grows. | The command does not end, for example a server or a watch mode. The bash tool in Pi has no default timeout. | `herdr agent send-keys <name> esc` stops the command. The orchestrator asks you after 15 minutes. |
| The orchestrator reports that reviewer, qa, or pm changed files | A check wrote a file that git does not ignore, or the agent edited a file. | Read `git diff --stat <before> <after>`. Restore the files or add the output to `.gitignore`. Then give the task again. |
| A task arrived changed, or a command in it ran | The task was in double quotes. | Use `agent-role --prompt <name> <<'TASK'`. |
| `invalid_agent_name` | Names must be lower case: `[a-z][a-z0-9_-]`, 32 characters or fewer. | Use `--name`. |
| `agent ... exists` | An agent with that name runs already. | `agent-role --stop <name>`, or use `--name`. |
| The side column looks wrong | The column is built for the `hw` layout: one pane at the top, one row below. | Close the side panes, then start the side agent again. |
| A role agent does not have a tool | Pi ignores a tool name that does not exist. | Check the names in the role file and in `extraTools`. |
| A role agent cannot find its model | `agent-role` starts Pi with `-ne`, so only the configured extensions load. | Add the provider's extension to `extensions` in the config. |
| A pane does not see a variable | Panes get their environment from the herdr server. `workspace create --env` reaches only the first pane. | Export the variable in that pane, or restart the herdr server from a shell that has it. |

## Test the setup

The test uses a scratch repo and your real config. It costs a few cents to
about one dollar. Run the commands from the root of this repo, in a herdr pane.

**1. Check the parts without agents.**

```sh
agent-role --help
agent-role dev --dry-run          # shows: pi -ne -e ... --model <coder preset> ...
herdr integration status          # pi and claude: current
hw -h                             # usage line
```

**2. Make the scratch repo.**

```sh
agents/test/scratch-repo.sh /tmp/agents-test
```

**3. Test with a Pi orchestrator.**

```sh
hw /tmp/agents-test agents-pi
```

Paste this prompt into the orchestrator. It does not name the skill, so it
also tests that the orchestrator finds the skill itself:

> Add a function slugify(text) to slug.py. It returns the text in lower case,
> with runs of whitespace turned into a single dash, and with all other
> characters that are not ASCII letters, digits, or dashes removed. Make a
> plan, then have dev implement it test-first, and have reviewer review the
> result. Skip pm and qa. I approve the plan in advance. Report to me when the
> work is done.

Check:

- [ ] The orchestrator loads the `orchestrate` skill and runs
      `printenv HERDR_ENV`.
- [ ] dev opens right of the orchestrator.
- [ ] reviewer opens in a new side column on the right, about 40% wide and the
      full height of the tab.
- [ ] dev reports RED (an `ImportError` or a failing test), then GREEN, and
      ends with `STATUS: done`.
- [ ] reviewer runs `python3 -m unittest` again and marks each finding
      VERIFIED or UNVERIFIED.
- [ ] The orchestrator runs the tests again itself.
- [ ] The orchestrator stops dev and reviewer with one
      `agent-role --stop` command. Their panes close, the side column goes
      away, and the layout returns to two rows. Do not close the panes
      yourself during this check.
- [ ] The orchestrator's report uses ASD-STE100 and lists the open points.
- [ ] The suggested commit message uses Conventional Commits, for example
      `feat(slug): add slugify`. The scratch repo has no convention of its
      own.
- [ ] `git -C /tmp/agents-test log --oneline` shows only `init`.

Then reset the repo and close the workspace:

```sh
git -C /tmp/agents-test restore . && git -C /tmp/agents-test clean -fdq
herdr workspace list                  # find the id of agents-pi
herdr workspace close <id>
```

**4. Test with a Claude Code orchestrator.**

```sh
hw -o claude -m sonnet /tmp/agents-test agents-claude
```

The first time, Claude Code asks if you trust the folder. Choose "Yes, I
trust this folder". Then paste the same prompt and use the same checks. The
scratch repo's `.claude/settings.json` allows the orchestrator commands, so
there must be no permission prompts, or almost none.

**5. Optional: test pm and qa together.**

> Ask pm if a CHANGELOG.md is worth adding now, and ask qa which inputs could
> break slugify. Do not file issues.

Check that pm and qa open one under the other in the side column, that pm
gives one of build, shrink, expand, defer, or drop, and that nothing is filed.
qa can report `blocked`, because the scratch repo has no running system. That
is fine for this check.

**6. Optional: drive an agent by hand.** In the orchestrator pane, run
`!agent-role reviewer`, then `!agent-role --stop <name>`. Check that the side
column appears and goes away. Then run `!agent-role reviewer` again and close
its pane with `prefix + x`. Check that the side column goes away again.

**7. Clean up.**

```sh
herdr workspace close <id>
rm -rf /tmp/agents-test
```
