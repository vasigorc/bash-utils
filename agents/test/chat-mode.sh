#!/usr/bin/env bash
# Chat mode of agent-role (--chat, --focus), against a stub herdr and a stub
# pi, with the real role files. No server or agents are started.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
ar=$root/agents/bin/agent-role
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/agents" "$tmp/work"
export PATH="$tmp/bin:$PATH"
export AGENT_ROLES_CONFIG="$tmp/config.json" AGENT_ROLES_DIR="$root/agents/roles"
export XDG_CACHE_HOME="$tmp/cache"
export AGENT_ROLES_PI_DIR="$tmp/pi-agent" PI_CODING_AGENT_DIR="$tmp/user-agent"
export HERDR_ENV=1 HERDR_PANE_ID=caller HERDR_TAB_ID=wT:t2
export AGENTS="$tmp/agents" HERDR_LOG="$tmp/herdr.log"
unset AGENT_ROLES_PRESET
mkdir -p "$PI_CODING_AGENT_DIR"
echo '{}' >"$PI_CODING_AGENT_DIR/settings.json"
cd "$tmp/work"

cat >"$AGENT_ROLES_CONFIG" <<'JSON'
{"presets": {"coder": "anthropic/claude-sonnet-5-5", "strong": "anthropic/claude-opus-5-5:high",
  "critic": "openai/gpt-6.1-sol"}, "pinned": ["reviewer"]}
JSON
cat >"$tmp/bin/pi" <<'STUB'
#!/usr/bin/env bash
[[ $1 == --list-models ]] || { echo "unexpected pi call: $*" >&2; exit 1; }
printf '%s\n' 'provider   model' 'anthropic  claude-sonnet-5-5' \
  'anthropic  claude-opus-5-5' 'openai     gpt-6.1-sol'
STUB
# An agent is a file in $AGENTS that holds its pane.
cat >"$tmp/bin/herdr" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
log() { printf '%s\n' "$*" >>"$HERDR_LOG"; }
case "$1 $2" in
  'agent get')
    [[ -f $AGENTS/$3 ]] || { echo '{"error":{"code":"agent_not_found"}}'; exit 1; }
    jq -n --arg p "$(cat "$AGENTS/$3")" '{result: {agent: {pane_id: $p}}}' ;;
  'agent start')
    log "start $*"
    echo "$7" >"$AGENTS/$3"
    echo '{"result":{}}' ;;
  'agent focus') log "focus $3" ;;
  'pane split')
    log "split $3 $5"
    echo '{"result":{"pane":{"pane_id":"new-pane"}}}' ;;
  'pane rename') ;;
  'pane close')
    log "close $3"
    grep -lx -- "$3" "$AGENTS"/* 2>/dev/null | xargs rm -f ;;
  'pane list') echo '{"result":{"panes":[]}}' ;;
  'agent list') exit 1 ;;
  *) echo "Unexpected herdr call: $*" >&2; exit 1 ;;
esac
STUB
chmod +x "$tmp/bin/pi" "$tmp/bin/herdr"

failures=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; failures=$((failures + 1)); }
# check DESCRIPTION: pass when the command that follows succeeds.
check() { local d=$1; shift; if "$@"; then pass "$d"; else fail "$d"; fi; }
# The prompt file that a dry run gives to Pi.
prompt_of() { "$ar" "$@" --dry-run | sed -n 's/.*--append-system-prompt \([^ ]*\).*/\1/p'; }

chat_prompt=$(prompt_of pm --chat)
task_prompt=$(prompt_of pm)

check 'chat prompt is its own file' test "$chat_prompt" = "$XDG_CACHE_HOME/agent-roles/pm.chat.md"
check 'task prompt keeps its file' test "$task_prompt" = "$XDG_CACHE_HOME/agent-roles/pm.md"
check 'chat prompt has no STATUS line rule' bash -c "! grep -q 'STATUS: done' '$chat_prompt'"
check 'chat prompt has no orchestrator framing' \
  bash -c "! grep -q 'orchestrator started you' '$chat_prompt'"
check 'chat prompt says there is no orchestrator' grep -q 'There is no orchestrator' "$chat_prompt"
check 'chat prompt keeps the role body' grep -q '^# Role: pm' "$chat_prompt"
check 'chat prompt keeps the shared limits' grep -q 'Do not commit, push' "$chat_prompt"
check 'chat prompt ends with the chat rules' \
  bash -c "tail -n 7 '$chat_prompt' | grep -q '^## Chat mode'"
check 'task prompt has the orchestrator framing' \
  grep -q 'An orchestrator started you' "$task_prompt"
check 'task prompt has the STATUS rule' grep -q 'STATUS: done' "$task_prompt"
check 'task prompt has no chat rules' bash -c "! grep -q 'There is no orchestrator' '$task_prompt'"
check 'both prompt files exist together' test -f "$chat_prompt" -a -f "$task_prompt"

# Start in chat mode with focus, then without focus.
: >"$HERDR_LOG"
"$ar" dev --chat --focus >/dev/null
check 'chat start uses the chat prompt' grep -q 'dev.chat.md' "$HERDR_LOG"
check '--focus focuses the new agent' grep -qx 'focus wt-t2-dev' "$HERDR_LOG"
st=$AGENT_ROLES_PI_DIR/role-agents/wt-t2-dev.json
check 'state file keeps chat mode' jq -e '.chat == true' "$st" >/dev/null

# A restart keeps chat mode.
: >"$HERDR_LOG"
"$ar" --restart wt-t2-dev >/dev/null
check 'restart keeps the chat prompt' grep -q 'dev.chat.md' "$HERDR_LOG"
check 'restart does not focus' bash -c "! grep -q '^focus' '$HERDR_LOG'"
check 'state file still has chat mode' jq -e '.chat == true' "$st" >/dev/null
"$ar" --stop wt-t2-dev >/dev/null

# Task mode: no focus by default, and the state file says so.
: >"$HERDR_LOG"
"$ar" dev >/dev/null
check 'task start uses the task prompt' bash -c "grep -q 'dev.md' '$HERDR_LOG' && ! grep -q 'dev.chat.md' '$HERDR_LOG'"
check 'task start does not focus' bash -c "! grep -q '^focus' '$HERDR_LOG'"
check 'state file has task mode' jq -e '.chat == false' "$st" >/dev/null

((failures == 0)) || { echo "$failures chat mode test(s) failed"; exit 1; }
echo "All chat mode tests passed"
