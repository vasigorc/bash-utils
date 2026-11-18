# Named Agent Teams Implementation Plan

> For agentic workers: REQUIRED: load the `subagent-driven-development` Superpowers skill with `superpowers_skill` to implement this plan.

Goal: Configure multiple named role/model lineups in one config and launch any member, including just its orchestrator.
Architecture: Shared team/model resolution used by agent-role and hw/ht; tab-scoped persisted selection avoids Herdr server environment inheritance pitfalls. Preserve worker isolation and the orchestrator's normal user context as separate launch policies.
Tech Stack: Bash, zsh, jq, existing Pi/Herdr CLI integration and stub-based shell tests.

## Approved direction

Vasile approved implementing the single-config design discussed on 2026-11-18. Current entry points: agents/bin/agent-role and terminals/herdr/herdr.zsh. Current role frontmatter maps dev→coder, reviewer/qa→critic, pm→strong. Live config has coder=Sonnet 5.5, strong=Opus 5.5, critic=Sol 6.1, budget=DeepSeek v4.1 Flash. Reviewer is pinned.

## One cohesive implementation slice: named-team launches

Files:
- Modify agents/bin/agent-role: team CLI, tab context, team-aware role baseline/pins, metadata/model inspection/restart, first-class orchestrator launch.
- Create a small shared resolver/helper under agents/ if necessary; share policy rather than duplicate jq expressions in zsh and bash.
- Modify terminals/herdr/herdr.zsh: --team and reuse the orchestrator launch path without breaking existing pi/claude support, layout, -m, -r, cwd or labels.
- Modify agents/roles/config.example.json: named Core/Primavera lineups and required model aliases; retain portable machine-local config semantics.
- Modify agents/README.md, terminals/herdr/2-HerdrAgentWorkspaces.md and agents/skills/orchestrate/SKILL.md as needed for the public CLI and team semantics.
- Add focused tests under agents/test/ and extend canonical existing tests; keep all existing tests passing.

### Contract

1. Support `hw --team core`, `ht --team primavera`, and `hw --team primavera -r reviewer`. hw/ht still create their existing editor/lower-pane layout. Starting a team launches only the selected member, not the full lineup.
2. Support `agent-role orchestrator --team primavera` inside Herdr, starting only an orchestrator pane without creating the hw layout; support a preselected pane for hw/ht reuse. Worker `agent-role reviewer --team core --chat` is supported too.
3. One `teams` map in config maps team names to role names to existing preset aliases (full provider/model identifiers may use existing resolution semantics). Core: orch strong, dev coder, reviewer critic, qa critic, pm strong. Primavera: orch critic, dev budget, reviewer strong, qa coder, pm strong. QA/PM unspecified by user use these documented illustrative defaults.
4. No team selected: preserve existing behavior and models. Missing worker assignment in a selected team falls back to role frontmatter; missing orchestrator assignment in an explicitly selected team must fail clearly, not silently choose the user's default. Unknown team or malformed assignments fail before creating panes.
5. Persist selection per Herdr tab in the existing configurable state hierarchy. Implicit worker launches inherit that selection. A team explicitly requested for an unbound tab can bind it after validation. Conflicting explicit selection in a bound tab fails before any mutation; no implicit team switching of live tabs. New hw/ht tabs use the explicit team only (no accidental ambient team inheritance).
6. Pins protect a role's team-specific baseline. Selecting Primavera's Opus reviewer does not require --force. Existing explicit --preset and AGENT_ROLES_PRESET behavior is retained relative to that baseline; global preset overrides never hijack pinned reviewers.
7. Orchestrator: normal user Pi config/extensions/tools, ORCHESTRATOR.md plus STYLE.md, async orch-wake extension, no worker agent-dir isolation/tools/task reply protocol. Preserve existing Claude orchestrator support in hw/ht; if a configured team's provider/model cannot be used as a Claude CLI model, fail clearly rather than passing it blindly. No need to add a new general client configuration language.
8. Preserve cwd, session identity, team and selected preset across supported restart/model-switch paths. Include team identity in --models/start metadata where appropriate. Retain the existing family-warning behavior; avoid false differences between model alias and actual model.
9. Team, role and model configuration must be validated before destructive restart or pane creation. Persist tab context atomically and avoid cross-tab bleed. Do not introduce eval or unsafe shell interpolation of team/config/model values.
10. Ensure --dry-run is informative and side-effect-free with respect to tab binding and panes. Existing prompt cache/agent-dir preparation conventions can remain where required by existing dry-run behavior.
11. Tests must use existing stub patterns. NEVER start another real Herdr server: it restores session.json and duplicates real agents. Do not change live config, install paths, stop real agents, or commit/push in the implementation slice.

### Execution

- [x] Inspect complete launcher/helpers/tests and extend the canonical test fixtures.
- [x] Write tests for team resolution, two-tab isolation, direct orchestrator policy, hw/ht reuse, pins, restart, solo chat, invalid config and legacy behavior. Demonstrate focused RED.
- [x] Implement minimal shared resolution and team-scoped launch behavior; demonstrate GREEN.
- [x] Run all agents/test/*.sh tests plus existing node test entry points if relevant; Bash/zsh syntax checks and git diff --check.
- [x] Update examples/docs; report exact commands, results, design trade-offs and remaining limitations.
- [x] Independent spec review followed by code-quality review; fix concrete findings and rerun tests.

## Activation (after review)

Inspect actual symlink targets before changing installation. Back up live ~/.config/agent-roles/config.json, add the two teams while preserving all existing presets/extensions/tools/pins, and ensure no-team default stays unchanged. Activate repo launcher changes via the existing install mechanism only if needed, carefully preserving the user's local orchestrate skill overlay. Validate via --dry-run, never by starting test agents in the real session. Do not restart an existing orchestrator or switch live models automatically.
