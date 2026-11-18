#!/usr/bin/env bash
# Exercise the real mutant role and launcher with stub Pi and herdr only.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/work" "$tmp/user-agent"
export PATH="$tmp/bin:$PATH" XDG_CACHE_HOME="$tmp/cache" XDG_STATE_HOME="$tmp/state"
export AGENT_ROLES_CONFIG="$tmp/config.json" AGENT_ROLES_DIR="$root/agents/roles"
export AGENT_ROLES_PI_DIR="$tmp/pi-agent" PI_CODING_AGENT_DIR="$tmp/user-agent"
export AGENT_ROLES_STATE_DIR="$tmp/state/agent-roles" HERDR_LOG="$tmp/herdr.log"
export HERDR_ENV=1 HERDR_TAB_ID=wT:t2 HERDR_PANE_ID=caller
unset AGENT_ROLES_PRESET HW_MODEL HW_ORCHESTRATOR
cp "$root/agents/roles/config.example.json" "$AGENT_ROLES_CONFIG"
cat >"$tmp/bin/pi" <<'STUB'
#!/usr/bin/env bash
[[ " $* " == *" --list-models "* ]] || { echo "unexpected pi call: $*" >&2; exit 1; }
printf '%s\n' 'fireworks fireworks:accounts/fireworks/models/deepseek-v4p1-flash'
STUB
cat >"$tmp/bin/herdr" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
case "$1 $2" in
  'agent get'|'agent list') exit 1 ;;
  'pane list') echo '{"result":{"panes":[{"pane_id":"side-pane","tab_id":"wT:t2","label":"side","agent":{"name":"busy"}}]}}' ;;
  'pane split') echo "$*" >>"$HERDR_LOG"; echo '{"result":{"pane":{"pane_id":"new-pane"}}}' ;;
  'pane rename'|'pane run') echo "$*" >>"$HERDR_LOG" ;;
  'agent start') echo "$*" >>"$HERDR_LOG"; echo '{"result":{}}' ;;
  *) echo "Unexpected herdr call: $*" >&2; exit 1 ;;
esac
STUB
chmod +x "$tmp/bin/pi" "$tmp/bin/herdr"
launch() { bash "$root/agents/bin/agent-role" "$@"; }
failures=0
check() {
  local description=$1
  shift
  if "$@"; then echo "PASS: $description";
  else echo "FAIL: $description"; failures=$((failures + 1)); fi
}
launch --list >"$tmp/list" || failures=$((failures + 1))
check 'mutant is discoverable' grep -qx 'mutant' "$tmp/list"
check 'list omits prompt fragments' bash -c '! grep -q "^_" "$1"' _ "$tmp/list"
check 'list starts no panes or agents' test ! -s "$HERDR_LOG"
check 'approved public model presets' jq -e '.presets == {
  "coder":"anthropic/claude-sonnet-5-5", "strong":"anthropic/claude-opus-5-5",
  "critic":"openai/gpt-6.1-sol", "budget":"fireworks/fireworks:accounts/fireworks/models/deepseek-v4p1-flash"
}' "$AGENT_ROLES_CONFIG"
for team in none core primavera; do
  args=()
  [[ $team == none ]] || args=(--team "$team")
  if launch mutant "${args[@]}" --dry-run >"$tmp/dry" 2>"$tmp/err"; then
    check "$team uses budget" grep -q "team: $team; preset: budget" "$tmp/dry"
    check "$team uses approved budget model" grep -q -- '--model fireworks/fireworks:accounts/fireworks/models/deepseek-v4p1-flash' "$tmp/dry"
    check "$team uses side placement" grep -Fq '\<side\>' "$tmp/dry"
    check "$team keeps worker isolation" grep -Fq "PI_CODING_AGENT_DIR=$AGENT_ROLES_PI_DIR" "$tmp/dry"
  else echo "FAIL: $team mutant dry-run"; cat "$tmp/err"; failures=$((failures + 1)); fi
done
check 'both example teams assign mutant budget' jq -e '.teams.core.mutant == "budget" and .teams.primavera.mutant == "budget"' "$AGENT_ROLES_CONFIG"
# Older live configs need not declare mutant: frontmatter supplies budget.
jq 'del(.teams.core.mutant)' "$AGENT_ROLES_CONFIG" >"$tmp/fallback.json"
AGENT_ROLES_CONFIG="$tmp/fallback.json" launch mutant --team core --dry-run >"$tmp/fallback" 2>&1 || failures=$((failures + 1))
check 'missing team assignment falls back to budget' grep -q 'team: core; preset: budget' "$tmp/fallback"
for mode in task chat; do
  args=()
  [[ $mode == task ]] || args=(--chat)
  : >"$HERDR_LOG"
  if launch mutant "${args[@]}" --cwd "$tmp/work" >"$tmp/start" 2>"$tmp/err"; then
    check "$mode splits below side column" grep -q '^pane split side-pane --direction down' "$HERDR_LOG"
    check "$mode exports worker mode" grep -q "AGENT_ROLE_MODE=$mode" "$HERDR_LOG"
    check "$mode uses isolated worker dir" grep -Fq "PI_CODING_AGENT_DIR=$AGENT_ROLES_PI_DIR" "$HERDR_LOG"
    check "$mode gets exact mutant tools" grep -q -- '--tools read,write,grep,find,ls,bash' "$HERDR_LOG"
    if [[ $mode == task ]]; then
      check 'task has reply extension' grep -q 'role-reply.ts' "$HERDR_LOG"
      prompt="$tmp/cache/agent-roles/mutant.md"
      check 'task has STATUS contract' grep -q 'STATUS:' "$prompt"
    else
      check 'chat has no task reply extension' bash -c '! grep -q role-reply.ts "$1"' _ "$HERDR_LOG"
      prompt="$tmp/cache/agent-roles/mutant.chat.md"
      check 'chat gets chat rules' grep -q 'You talk directly with a person' "$prompt"
    fi
    check "$mode includes mutant role" grep -q 'You are mutant.' "$prompt"
    check "$mode has lean worker settings" jq -e '.packages == [] and (.extensions | index("-builtin:mcp") != null)' "$AGENT_ROLES_PI_DIR/settings.json"
  else echo "FAIL: mutant $mode start"; cat "$tmp/err"; failures=$((failures + 1)); fi
done
((failures == 0)) || { echo "$failures test(s) failed"; exit 1; }
echo 'All mutant role tests passed'
