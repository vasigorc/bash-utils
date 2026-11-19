# Current-pane role launches

## Approved behavior

The user approved `agent-role ROLE --here` on 2026-11-19.

- Launch the selected client in the calling Herdr pane. Create no pane or tab.
- Support orchestrator and worker roles. Preserve worker isolation and orchestrator user context.
- Preserve team, preset, session, working-directory, prompt, and chat behavior.
- Keep existing behavior when `--here` is absent.
- Refuse conflicting explicit placement before any launch or team binding.
- Keep dry-run and validation useful without launching a client.
- Avoid sending a command into the pane while its launcher holds the foreground.
- Use direct foreground execution. Require terminal stdin and stdout for real launches.
- Refuse a caller pane that already hosts an agent before team binding or pane mutation.
- Preserve agent identity with bounded detection and naming. Keep helper output off the client screen.
- Publish metadata only after Herdr recognizes the requested name. Never expose metadata that --models will delete before naming.
- If detection fails, stop the helper. Keep the foreground client usable and record the reason in a diagnostic log.
- Preserve the client exit status. Keep the caller shell environment unchanged after exit.
- Treat --focus as a no-op. Reject --here with any explicit --pane, regardless of option order.
- Print the foreground command in dry-run. Do not require a terminal for dry-run or validation.
- Print launch JSON before entering the client. Do not claim it proves readiness.
- Save current-pane placement distinctly. Refuse --stop and --restart for these agents before closing any pane. Preflight every name in a stop batch.
- Allow --set-model only through its existing live-session path. Refuse any fallback that would restart a --here agent.
- Manual lifecycle is user-approved: exit the client normally, then resume with --here --session ID.
- Document pane-label behavior and identity-detection limits.
- Never close the caller pane on launch failure.

## Pane swaps

No new shortcut is needed. Herdr 0.9.5 supports `Ctrl+b`, then `Shift+h/j/k/l` for neighboring pane swaps. Its installed changelog confirms this. The help list omits these actions; the default `prefix+shift+w` binding renames the workspace. Add this explanation to the guide.

## Scope

Change the launcher, focused tests, and relevant user docs. Do not change live configuration, install, commit, or push.
