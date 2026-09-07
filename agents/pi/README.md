# Pi coding agent

[pi](https://www.npmjs.com/package/@earendil-works/pi-coding-agent) is a
terminal coding agent. I drive it two ways: directly in a shell, and from
Neovim through CodeCompanion's ACP adapter (see `vasile-lazyvim-config`).

## Install

```shell
npm i -g @earendil-works/pi-coding-agent   # the agent itself -> `pi`
npm i -g pi-acp                            # ACP bridge for editors -> `pi-acp`
```

`pi-acp` only spawns whatever `pi` is on `PATH`; it does not bundle it. If node
comes from nvm, editors launched outside a shell will not see either binary --
point the editor at absolute paths in that case.

## Credentials

pi resolves credentials in this order: `--api-key` flag, then `~/.pi/agent/auth.json`,
then the environment. Nothing here holds secrets: keys live in the shell
(untracked), OAuth tokens in `auth.json` (untracked).

| provider | env var |
|---|---|
| OpenRouter (one key, most open-weight models) | `OPENROUTER_API_KEY` |
| DeepSeek direct (cheaper than via OpenRouter) | `DEEPSEEK_API_KEY` |
| Anthropic | `ANTHROPIC_API_KEY` |

`pi auth check --provider <name>` reports readiness, but only proves a
credential is *present* -- it does not call the provider. To prove a model
actually answers:

```shell
pi -p --no-session -nt --provider openrouter --model z-ai/glm-5.3-flash "Reply with exactly: OK"
```

Subscription (OAuth) providers use `/login` inside the TUI: ChatGPT Plus/Pro,
Claude Pro/Max, GitHub Copilot, xAI, OpenRouter, Radius. Note that Claude
Pro/Max through a third-party harness bills per token from Anthropic's extra
usage, not against plan limits -- it is not free the way first-party Claude
Code is.

Flat-rate coding plans are bought per vendor and get their own env vars:
`ZAI_API_KEY`, `KIMI_API_KEY`, `QWEN_TOKEN_PLAN_API_KEY`, `XIAOMI_TOKEN_PLAN_*_API_KEY`.

## settings.json

Copy `settings.json` to `~/.pi/agent/settings.json`.

```shell
cp agents/pi/settings.json ~/.pi/agent/settings.json
```

Three keys matter, and the schema is easy to get wrong:

- `defaultProvider` -- provider id, separate field
- `defaultModel` -- **bare** model id, no provider prefix. OpenRouter ids
  contain a slash themselves (`z-ai/glm-5.3-flash`), which makes a combined
  `provider/id` string look plausible; it is silently ignored and pi falls back
  to its built-in default.
- `enabledModels` -- patterns for `Ctrl+P` cycling. Not `scopedModels`, which
  is the in-memory name and does nothing in this file.

Both mistakes fail quietly, so confirm which model actually answered:

```shell
pi -p --no-session -nt --mode json "hi" | grep -o '"provider":"[^"]*","model":"[^"]*"'
```

## Usage

`Ctrl+L` or `/model` opens the full picker (`Ctrl+S` saves a new startup
default). `Ctrl+P` cycles the `enabledModels` shortlist. `/session` shows token
count and accumulated cost.
