#!/usr/bin/env bash
# Async replies in agent-role: the pane environment, the role-reply extension,
# the pending marker of --prompt, and the clean-up. A stub herdr and a stub pi;
# no server or agents are started.
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
export AGENT_ROLES_STATE_DIR="$tmp/state"
unset AGENT_ROLES_ASYNC
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
  'pane run') log "run $3" ;;
  'agent prompt')
    log "prompt $3 $4"
    [[ ${PROMPT_FAIL:-0} != 1 ]] || { echo '{"error":{"code":"test"}}'; exit 1; }
    echo '{"result":{}}' ;;
  'pane swap') log "swap $4 $6" ;;
  'pane split')
    log "split $3 $5"
    log "splitfull $*"
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
st=$AGENT_ROLES_STATE_DIR
marker=$st/pending/wt-t2/wt-t2-dev.json
task() { "$ar" --prompt wt-t2-dev "$@" <<<'do the thing'; }

# Environment and extension: task mode.
out=$("$ar" dev --dry-run)
[[ $out == *'AGENT_ROLE_NAME=wt-t2-dev'*'AGENT_ROLE_PREFIX=wt-t2'*'AGENT_ROLE_MODE=task'*"AGENT_ROLES_STATE_DIR=$st"* ]] &&
  pass 'task pane env names the agent, the prefix and the mode' || fail "task pane env: $out"
[[ $out == *'-e '*'pi/extensions/role-reply.ts'* ]] &&
  pass 'a task agent loads role-reply.ts' || fail 'role-reply.ts not loaded'
out=$("$ar" dev --chat --dry-run)
[[ $out == *'AGENT_ROLE_MODE=chat'* && $out != *role-reply.ts* ]] &&
  pass 'a chat agent has mode chat and no role-reply.ts' || fail "chat: $out"
out=$(AGENT_ROLES_EXT_DIR=/nonexistent "$ar" dev --dry-run 2>&1)
[[ $out == *'role-reply.ts is missing'* ]] && pass 'a missing extension is a warning' || fail 'missing ext'


# A new pane gets the environment from herdr (--env), one option for each name.
: >"$HERDR_LOG"
"$ar" dev >/dev/null
full=$(grep '^splitfull' "$HERDR_LOG")
[[ $full == *'--env AGENT_ROLE_NAME=wt-t2-dev'*'--env AGENT_ROLE_PREFIX=wt-t2'*'--env AGENT_ROLE_MODE=task'* ]] &&
  pass 'a new pane gets the role environment with --env' || fail "split env: $full"
"$ar" --stop wt-t2-dev >/dev/null

# --prompt with AGENT_ROLES_ASYNC=1: marker, hint, herdr prompt.
"$ar" dev >/dev/null
: >"$HERDR_LOG"
err=$(AGENT_ROLES_ASYNC=1 task 2>&1 >/dev/null)
[[ -f $marker && $(jq -r .name "$marker") == wt-t2-dev && -n $(jq -r .started_at "$marker") ]] &&
  pass '--prompt writes the pending marker when async' || fail 'no marker'
[[ $err == *'async. Do not wait for wt-t2-dev. End your turn'* ]] &&
  pass '--prompt tells the orchestrator to end its turn' || fail "hint: $err"
grep -q '^prompt wt-t2-dev do the thing' "$HERDR_LOG" && pass 'the task goes to herdr' || fail 'task not sent'

# A new task clears the old reply files.
mkdir -p "$st/replies/wt-t2" "$st/handled/wt-t2"
echo old >"$st/replies/wt-t2/wt-t2-dev.md"; echo '{}' >"$st/handled/wt-t2/wt-t2-dev.json"
AGENT_ROLES_ASYNC=1 task >/dev/null 2>&1
[[ ! -e $st/replies/wt-t2/wt-t2-dev.md && ! -e $st/handled/wt-t2/wt-t2-dev.json ]] &&
  pass 'a new task clears the old reply files' || fail 'old reply files kept'

# No marker: sync call, no ASYNC, a chat agent, a failed prompt, no state file.
rm -f "$marker"
task >/dev/null 2>&1
[[ ! -e $marker ]] && pass 'no marker without AGENT_ROLES_ASYNC' || fail 'marker without async'
err=$(task 2>&1 >/dev/null); [[ $err != *async* ]] && pass 'no hint without AGENT_ROLES_ASYNC' || fail 'hint without async'
AGENT_ROLES_ASYNC=1 task --wait --timeout 1000 >/dev/null 2>&1
[[ ! -e $marker ]] && pass 'no marker with --wait (a sync call)' || fail 'marker with --wait'
PROMPT_FAIL=1 AGENT_ROLES_ASYNC=1 task >/dev/null 2>&1 && rc=0 || rc=$?
[[ $rc != 0 && ! -e $marker ]] && pass 'a failed prompt leaves no marker and fails' || fail "failed prompt rc=$rc"
AGENT_ROLES_ASYNC=1 "$ar" --prompt no-such-agent <<<'x' >/dev/null 2>&1 || true
[[ ! -d $st/pending/no-such-agent ]] && pass 'an agent without a state file gets no marker' || fail 'marker without state'

# Stop clears everything.
AGENT_ROLES_ASYNC=1 task >/dev/null 2>&1
echo r >"$st/replies/wt-t2/wt-t2-dev.md"; echo '{}' >"$st/replies/wt-t2/wt-t2-dev.json"
"$ar" --stop wt-t2-dev >/dev/null
[[ ! -e $marker && -z $(ls "$st/replies/wt-t2" 2>/dev/null) ]] &&
  pass '--stop clears the marker and the replies' || fail '--stop left files'

# A chat agent gets no marker.
"$ar" dev --chat >/dev/null
AGENT_ROLES_ASYNC=1 task >/dev/null 2>&1
[[ ! -e $marker ]] && pass 'a chat agent gets no marker' || fail 'marker for chat agent'
"$ar" --stop wt-t2-dev >/dev/null

((failures == 0)) || { echo "$failures async reply test(s) failed"; exit 1; }
echo "All async reply tests passed"
