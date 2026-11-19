# Current-pane launch implementation plan

Goal: Add `agent-role ROLE --here` without changing ordinary role launches.
Architecture: Reuse role and team resolution. Launch in the foreground when requested, rather than queueing shell input into the busy calling pane.
Tech Stack: Bash 3.2, jq, Herdr, Pi; stub-based shell tests.

## Task 1: Implement and document --here

Files:
- Modify `agents/bin/agent-role` for option handling and current-pane launch behavior.
- Create `agents/test/current-pane.sh` for the foreground launch contract.
- Modify `agents/README.md` and `terminals/herdr/2-HerdrAgentWorkspaces.md` for user examples.
- Modify `agents/skills/orchestrate/SKILL.md` only if its launch guidance needs clarification.
- Modify `terminals/herdr/3-HerdrCoreConceptsNavigation.md` to explain hidden pane-swap shortcuts.

Steps:
1. Inspect client launch and Herdr identity behavior. Report a blocker if foreground launch cannot preserve required behavior.
2. Add focused failing tests for foreground execution and option validation.
3. Run the tests and record expected failures before implementation.
4. Implement the smallest compatible change. Preserve normal launch behavior.
5. Run focused tests, all runnable `agents/test/*.sh` suites, and shell syntax checks. Exclude `scratch-repo.sh`, which is a helper.
6. Update help and docs with examples and any lifecycle differences.
7. Report changes and test evidence. Do not install, commit, or push.

Coverage:
- Orchestrator uses normal user context, style, and wake extensions.
- Workers retain isolated context, role prompts, and chat/task mode.
- Team, preset, session, and cwd reach the foreground client.
- No split, pane run, or self-targeted agent start occurs for --here.
- Invalid combinations fail before team binding or pane mutation.
- Dry-run and validation do not launch the client.
- Client failures preserve exit status and never close the calling pane.
- Identity naming is bounded; metadata appears only after naming. Test detection success, timeout, and early client exit.
- Refuse real nonterminal launches and caller panes with existing agents before binding or mutation.
- Refuse --here with explicit --pane in either option order; --focus is a no-op.
- Refuse stop/restart for --here agents before destructive actions. Refuse the model-change restart fallback.
- Preserve ordinary split-pane lifecycle and the existing live-session model-change path.
- Document manual exit/resume, launch JSON versus readiness, and label behavior.
- Explain why pane-swap shortcuts are absent from the help list in `terminals/herdr/3-HerdrCoreConceptsNavigation.md`.

## Plan review corrections

The user approved manual lifecycle for --here agents. Stop/restart must refuse rather than close the shell pane. The design now covers identity publication order, terminal checks, option conflicts, foreground dry-run output, and help-menu omissions.

## Validation

Ask reviewer to check the plan before implementation. After implementation, obtain independent review and local QA. Check read-only snapshots before and after each task. Keep changes uncommitted for user review.
