#!/usr/bin/env bash
# Pane placement of agent-role (--pane right|down|up|left), against a stub
# herdr and a stub pi, with the real role files. No server or agents are started.
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
  'pane run') log "run $3" ;;
  'pane swap') log "swap $4 $6" ;;
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
fail() { echo "FAIL: $1"; cat "$HERDR_LOG"; failures=$((failures + 1)); }
# placed DESCRIPTION PANE_OPTION WANT_LOG_LINES...: start dev with --pane, then
# the herdr calls that move panes must be exactly these lines, in this order.
placed() {
  local d=$1 opt=$2 got want
  shift 2
  : >"$HERDR_LOG"
  "$ar" dev --pane "$opt" >/dev/null
  got=$(grep -E '^(split|swap)' "$HERDR_LOG" || true)
  want=$(printf '%s\n' "$@")
  [[ $got == "$want" ]] && pass "$d" || { fail "$d"; echo "want: $want"; echo "got:  $got"; }
  "$ar" --stop wt-t2-dev >/dev/null
}
st=$AGENT_ROLES_PI_DIR/role-agents/wt-t2-dev.json

placed '--pane right splits the calling pane to the right' right 'split caller right'
placed '--pane down splits the calling pane down' down 'split caller down'
placed '--pane up splits down, then swaps' up 'split caller down' 'swap caller new-pane'
placed '--pane left splits right, then swaps' left 'split caller right' 'swap caller new-pane'

# The saved placement is the one that was given, so a restart repeats it.
for w in down up left; do
  "$ar" dev --pane "$w" >/dev/null
  [[ $(jq -r .where "$st") == "$w" ]] && pass "state keeps where=$w" || fail "state where=$w"
  : >"$HERDR_LOG"
  "$ar" --restart wt-t2-dev >/dev/null
  case $w in
    down) want=$'split caller down' ;;
    up) want=$'split caller down\nswap caller new-pane' ;;
    left) want=$'split caller right\nswap caller new-pane' ;;
  esac
  [[ $(grep -E '^(split|swap)' "$HERDR_LOG" || true) == "$want" ]] &&
    pass "restart repeats $w" || fail "restart repeats $w"
  "$ar" --stop wt-t2-dev >/dev/null
done

# A pane id is still turned into right or side.
"$ar" dev --pane some-pane >/dev/null
[[ $(jq -r .where "$st") == right ]] && pass 'a PANE_ID becomes right' || fail 'a PANE_ID becomes right'
"$ar" --stop wt-t2-dev >/dev/null

((failures == 0)) || { echo "$failures pane placement test(s) failed"; exit 1; }
echo "All pane placement tests passed"
