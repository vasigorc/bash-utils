#!/usr/bin/env bash
# Presets, pinned roles, --models, --set-model and --restart, against a stub
# herdr and a stub pi. No server or agents are started.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
ar=$root/agents/bin/agent-role
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/roles" "$tmp/agents" "$tmp/work"
export PATH="$tmp/bin:$PATH"
export AGENT_ROLES_CONFIG="$tmp/config.json" AGENT_ROLES_DIR="$tmp/roles"
export XDG_CACHE_HOME="$tmp/cache"
export AGENT_ROLES_PI_DIR="$tmp/pi-agent" PI_CODING_AGENT_DIR="$tmp/user-agent"
export HERDR_ENV=1 HERDR_PANE_ID=caller HERDR_TAB_ID=wT:t2
export AGENTS="$tmp/agents" HERDR_LOG="$tmp/herdr.log" PANE_TEXT="$tmp/pane.txt"
unset AGENT_ROLES_PRESET
mkdir -p "$PI_CODING_AGENT_DIR"
echo '{}' >"$PI_CODING_AGENT_DIR/settings.json"
cd "$tmp/work"

cat >"$AGENT_ROLES_CONFIG" <<'JSON'
{"presets": {"coder": "anthropic/claude-sonnet-5-5", "strong": "anthropic/claude-opus-5-5:high",
  "critic": "openai/gpt-6.1-sol", "auto": "router/auto", "gone": "nokey/model"},
 "pinned": ["reviewer"]}
JSON
printf -- '---\npreset: coder\npane: right\n---\nDev.\n' >"$tmp/roles/dev.md"
printf -- '---\npreset: critic\npane: right\n---\nReviewer.\n' >"$tmp/roles/reviewer.md"

# Pi can use every model of the config but nokey/model.
cat >"$tmp/bin/pi" <<'STUB'
#!/usr/bin/env bash
[[ $1 == --list-models ]] || { echo "unexpected pi call: $*" >&2; exit 1; }
printf '%s\n' 'provider   model' 'anthropic  claude-sonnet-5-5' \
  'anthropic  claude-opus-5-5' 'openai     gpt-6.1-sol' 'router     auto'
STUB
# An agent is a file in $AGENTS that holds its pane. A pane shows $PANE_TEXT.
cat >"$tmp/bin/herdr" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
log() { printf '%s\n' "$*" >>"$HERDR_LOG"; }
case "$1 $2" in
  'agent get')
    [[ -f $AGENTS/$3 ]] || { echo '{"error":{"code":"agent_not_found"}}'; exit 1; }
    jq -n --arg p "$(cat "$AGENTS/$3")" '{result: {agent: {pane_id: $p}}}' ;;
  'agent start')
    log "start $3 $7"
    echo "$7" >"$AGENTS/$3"
    echo '{"result":{}}' ;;
  'agent prompt')
    log "prompt $3 $4"
    # Like Pi: /model adds a model change to the session file, if there is
    # one, and shows "Model: <id>". SWITCH=0: Pi does nothing.
    if [[ ${SWITCH:-1} == 1 && $4 == '/model '* ]]; then
      m=${4#/model } st=$AGENT_ROLES_PI_DIR/role-agents/$3.json
      f=$(find "$AGENT_ROLES_PI_DIR/sessions" -name "*_$(jq -r .session "$st").jsonl" 2>/dev/null | head -n 1)
      [[ -z $f ]] || jq -nc --arg p "${m%%/*}" --arg i "${m#*/}" \
        '{type: "model_change", provider: $p, modelId: $i}' >>"$f"
      echo "  Model: ${m#*/}" >>"$PANE_TEXT"
    fi ;;
  'pane list')
    jq -n '{result: {panes: [{pane_id: "side-x", tab_id: "wT:t2", label: "side: old", agent: null}]}}' ;;
  'pane run') log "run $3" ;;
  'agent send-keys') log "keys $3 $4" ;;
  'pane split')
    n=$(($(cat "$AGENTS/.n" 2>/dev/null || echo 0) + 1))
    echo "$n" >"$AGENTS/.n"
    log "split $3 $5"
    echo "{\"result\":{\"pane\":{\"pane_id\":\"pane-$n\"}}}" ;;
  'pane rename') ;;
  'pane close')
    log "close $3"
    grep -lx -- "$3" "$AGENTS"/* 2>/dev/null | xargs rm -f ;;
  'pane read') cat "$PANE_TEXT" ;;
  'agent list')
    [[ -n ${ORCH_SESSION:-} ]] || exit 1
    jq -n --arg f "$ORCH_SESSION" '{result: {agents: [{pane_id: "caller", name: null,
      agent_session: {kind: "path", value: $f}}]}}' ;;
  *) exit 1 ;;
esac
STUB
chmod +x "$tmp/bin/pi" "$tmp/bin/herdr"

failures=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; cat "$tmp/err" 2>/dev/null || true; failures=$((failures + 1)); }
# run DESCRIPTION WANT_RC PATTERN... -- ARG...: each PATTERN is in stdout+stderr.
run() {
  local d=$1 want=$2 rc=0 out p
  shift 2
  local -a pats=()
  while [[ $1 != -- ]]; do pats+=("$1"); shift; done
  shift
  : >"$HERDR_LOG"
  bash "$ar" "$@" >"$tmp/out" 2>"$tmp/err" || rc=$?
  out=$(cat "$tmp/out" "$tmp/err")
  [[ $rc == "$want" ]] || { fail "$d (rc $rc, want $want)"; return; }
  for p in "${pats[@]}"; do
    [[ $out == *"$p"* ]] || { fail "$d (no '$p')"; echo "$out"; return; }
  done
  pass "$d"
}

run 'role preset and a named session' 0 '--model anthropic/claude-sonnet-5-5' \
  '--session-id wt-t2-dev-' -- dev --dry-run
run '--preset gives another model' 0 '--model anthropic/claude-opus-5-5:high' -- \
  dev --preset strong --dry-run
run '--preset takes provider/id' 0 '--model other/model' -- dev --preset other/model --dry-run
run 'unknown preset stops' 1 "preset 'nope' is not in" -- dev --preset nope --dry-run
run 'pinned role refuses --preset' 1 'reviewer keeps its preset' -- \
  reviewer --preset auto --dry-run
run 'pinned role takes --preset with --force' 0 '--model router/auto' -- \
  reviewer --preset auto --force --dry-run
run 'pinned role takes its own preset' 0 '--model openai/gpt-6.1-sol' -- \
  reviewer --preset critic --dry-run
AGENT_ROLES_PRESET=auto run 'AGENT_ROLES_PRESET sets a role that is not pinned' 0 \
  '--model router/auto' -- dev --dry-run
AGENT_ROLES_PRESET=auto run 'AGENT_ROLES_PRESET skips a pinned role' 0 \
  '--model openai/gpt-6.1-sol' 'AGENT_ROLES_PRESET is not used' -- reviewer --dry-run
run '--session continues a session id' 0 '--session-id dev-1' -- dev --session dev-1 --dry-run
run 'bad session id stops' 1 'a session id has only' -- dev --session 'a b' --dry-run

run 'a model that Pi cannot use stops before a pane' 1 'Pi cannot use the model nokey/model' -- \
  dev --preset gone
[[ ! -s $HERDR_LOG ]] && pass 'no pane for a model that Pi cannot use' ||
  { fail 'no pane for a model that Pi cannot use'; cat "$HERDR_LOG"; }

# Start two agents. The state file has what a restart needs.
run 'start dev' 0 '"preset": "coder"' -- dev
run 'start reviewer' 0 '"model": "openai/gpt-6.1-sol"' -- reviewer --name rev
st=$AGENT_ROLES_PI_DIR/role-agents/wt-t2-dev.json
if jq -e --arg c "$tmp/work" '.role == "dev" and .preset == "coder" and .where == "right"
  and .cwd == $c and .tab == "wT:t2" and (.session | startswith("wt-t2-dev-"))
  and .skip == 0' "$st" >/dev/null; then
  pass 'state file'
else fail 'state file'; cat "$st"; fi

# The dev session: a model change to a router, and a reply from a real model.
sessions=$AGENT_ROLES_PI_DIR/sessions/--work--
mkdir -p "$sessions"
devfile=$sessions/2026_$(jq -r .session "$st").jsonl
jq -nc '{type: "model_change", provider: "router", modelId: "auto"},
  {type: "message", message: {role: "assistant", provider: "router", model: "auto",
    responseModel: "claude-opus-5-5"}}' >"$devfile"
run '--models shows the model and the real model' 0 \
  '"name":"wt-t2-dev","role":"dev","preset":"coder","model":"router/auto","reply":"router/claude-opus-5-5","family":"anthropic"' \
  '"name":"rev","role":"reviewer","preset":"critic","model":"openai/gpt-6.1-sol","reply":null,"family":"openai"' \
  -- --models
[[ $(cat "$tmp/err") != *warning* ]] && pass 'no warning for two families' ||
  fail 'no warning for two families'

# The orchestrator. Pi: the last model change, or a reply that started after
# it. Claude Code: the last reply.
export ORCH_SESSION=$tmp/orch.jsonl
orch() { # description pattern, with the session on stdin
  cat >"$ORCH_SESSION"
  run "$1" 0 "$2" -- --models
}
orch '--models: a Pi reply after the model change' \
  '{"name":"orchestrator","role":"orchestrator","model":"openai/gpt-6.1-sol","reply":"gpt-6.1-sol","family":"openai"}' <<'JSONL'
{"type":"model_change","timestamp":"2026-01-01T10:00:00.000Z","provider":"anthropic","modelId":"claude-opus-5-5"}
{"type":"message","message":{"role":"assistant","provider":"openai","model":"gpt-6.1-sol","timestamp":1767261660000}}
JSONL
grep -q 'warning: rev and orchestrator both use openai models' "$tmp/err" &&
  pass 'warning for the orchestrator' || fail 'warning for the orchestrator'
orch '--models: a model change after the last reply wins' \
  '"model":"openai/gpt-6.1-sol","reply":"claude-opus-5-5","family":"openai"' <<'JSONL'
{"type":"message","message":{"role":"assistant","provider":"anthropic","model":"claude-opus-5-5","timestamp":1767261600000}}
{"type":"model_change","timestamp":"2026-01-01T10:01:00.500Z","provider":"openai","modelId":"gpt-6.1-sol"}
JSONL
orch '--models: a reply that was in flight at the change does not count' \
  '"model":"openai/gpt-6.1-sol","reply":"claude-opus-5-5","family":"openai"' <<'JSONL'
{"type":"model_change","timestamp":"2026-01-01T10:01:00.500Z","provider":"openai","modelId":"gpt-6.1-sol"}
{"type":"message","message":{"role":"assistant","provider":"anthropic","model":"claude-opus-5-5","timestamp":1767261660400}}
JSONL
orch '--models: a router keeps its name, the reply gives the family' \
  '"model":"router/auto","reply":"claude-real","family":"anthropic"' <<'JSONL'
{"type":"model_change","timestamp":"2026-01-01T10:00:00.000Z","provider":"router","modelId":"auto"}
{"type":"message","message":{"role":"assistant","provider":"router","model":"auto","responseModel":"claude-real","timestamp":1767261660000}}
JSONL
orch '--models reads a Claude Code session' \
  '"model":"claude-opus-5-5","reply":"claude-opus-5-5","family":"anthropic"' <<'JSONL'
{"type":"assistant","timestamp":"2026-01-01T10:00:00.000Z","message":{"model":"claude-opus-5-5"}}
JSONL
unset ORCH_SESSION

# Switch the reviewer. Pinned: it needs --force, but not for its own preset.
# The reviewer has had no task, so it has no session file: it starts again.
run '--set-model refuses a pinned role' 1 'reviewer keeps its preset' -- --set-model rev coder
run '--set-model before the first task starts again' 0 'has had no task yet' \
  '"preset": "strong"' '"model": "anthropic/claude-opus-5-5:high"' -- --set-model rev strong --force
grep -q '^close pane-2$' "$HERDR_LOG" && grep -q '^start rev pane-3$' "$HERDR_LOG" &&
  pass 'the new start replaces the old pane' || { fail 'the new start replaces the old pane'; cat "$HERDR_LOG"; }
run '--set-model to a model that Pi cannot use' 1 'Pi cannot use the model' -- \
  --set-model wt-t2-dev gone

# With a session file, a new model change is the proof.
jq -nc '{type: "message", message: {role: "user"}}' \
  >"$sessions/2026_$(jq -r .session "$AGENT_ROLES_PI_DIR/role-agents/rev.json").jsonl"
run '--set-model back to the own preset of a pinned role' 0 \
  '{"name":"rev","preset":"critic","model":"openai/gpt-6.1-sol"}' -- --set-model rev critic
run '--set-model gives the thinking level' 0 '"preset":"strong"' -- --set-model rev strong --force
grep -qx 'prompt rev /model anthropic/claude-opus-5-5' "$HERDR_LOG" &&
  grep -qx 'prompt rev /thinking high' "$HERDR_LOG" && pass '/model and /thinking sent' ||
  { fail '/model and /thinking sent'; cat "$HERDR_LOG"; }
run '--set-model the same model again' 0 '"preset":"strong"' -- --set-model rev strong --force
run 'back to critic' 0 '"preset":"critic"' -- --set-model rev critic

# dev has a session file: a new model change there is the proof. Its family
# is the family of the new model, not of the last reply.
run '--set-model with a session file' 0 '"preset":"critic"' \
  'warning: rev and wt-t2-dev both use openai models' -- --set-model wt-t2-dev critic
SWITCH=0 AGENT_ROLES_SWITCH_TRIES=3 run 'no new model change is no proof' 1 \
  'did not switch' -- --set-model wt-t2-dev coder

# Restart on a new preset: the same session, cwd and pane kind. The session
# names other models, but the restart model wins.
session=$(jq -r .session "$st")
lines=$(wc -l <"$devfile" | tr -d ' ')
run '--restart --preset' 0 '"preset": "strong"' -- --restart wt-t2-dev --preset strong
if grep -qx 'close pane-1' "$HERDR_LOG" && grep -q '^split caller right' "$HERDR_LOG" &&
  [[ $(jq -r .session "$st") == "$session" && $(jq -r .preset "$st") == strong &&
    $(jq -r .skip "$st") == "$lines" ]]; then
  pass 'restart keeps the session'
else fail 'restart keeps the session'; cat "$HERDR_LOG" "$st"; fi
run '--models after a restart' 0 '"name":"wt-t2-dev","role":"dev","preset":"strong","model":"anthropic/claude-opus-5-5:high"' \
  -- --models
run '--restart refuses a pinned role' 1 'reviewer keeps its preset' -- --restart rev --preset auto
[[ -f $AGENTS/rev ]] && pass 'a refused restart keeps the agent' ||
  fail 'a refused restart keeps the agent'

# A pane given by id keeps its kind for a restart.
run 'start dev in a side pane by id' 0 '"pane": "side-x"' -- dev --name dev2 --pane side-x
[[ $(jq -r .where "$AGENT_ROLES_PI_DIR/role-agents/dev2.json") == side ]] &&
  pass 'a side pane by id restarts in the side column' ||
  { fail 'a side pane by id restarts in the side column'; cat "$AGENT_ROLES_PI_DIR/role-agents/dev2.json"; }

# A stopped agent leaves no state file.
run '--stop' 0 '"stopped":"rev"' -- --stop rev dev2
[[ ! -e $AGENT_ROLES_PI_DIR/role-agents/rev.json ]] && pass 'stop removes the state file' ||
  fail 'stop removes the state file'

if ((failures)); then
  echo "$failures test(s) failed"
  exit 1
fi
echo 'All preset and model tests passed'
