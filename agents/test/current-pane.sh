#!/usr/bin/env bash
# agent-role --here: launch a role in the calling herdr pane, with no split.
# A stub herdr and a stub pi, plus a local pseudo-terminal for the real
# launches. No server is contacted and no live pane changes.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
ar=$root/agents/bin/agent-role
tmp=$(mktemp -d)
live_pid=""
trap 'rm -rf "$tmp"; [[ -z $live_pid ]] || kill "$live_pid" 2>/dev/null || true' EXIT
mkdir -p "$tmp/bin" "$tmp/agents" "$tmp/work"
export PATH="$tmp/bin:$PATH"
export AGENT_ROLES_CONFIG="$tmp/config.json" AGENT_ROLES_DIR="$root/agents/roles"
export XDG_CACHE_HOME="$tmp/cache" XDG_STATE_HOME="$tmp/state"
export AGENT_ROLES_PI_DIR="$tmp/pi-agent" PI_CODING_AGENT_DIR="$tmp/user-agent"
export AGENT_ROLES_STATE_DIR="$tmp/state/agent-roles"
export HERDR_ENV=1 HERDR_PANE_ID=caller HERDR_TAB_ID=wT:t2
export AGENTS="$tmp/agents" HERDR_LOG="$tmp/herdr.log" PI_LOG="$tmp/pi.log"
export DETECTED="$tmp/detected" LIST_COUNT="$tmp/list.count"
unset AGENT_ROLES_PRESET
mkdir -p "$PI_CODING_AGENT_DIR"
echo '{}' >"$PI_CODING_AGENT_DIR/settings.json"
cd "$tmp/work"

meta=$AGENT_ROLES_PI_DIR/role-agents
cache=$XDG_CACHE_HOME/agent-roles
here_dir=$AGENT_ROLES_STATE_DIR/here-panes

command -v python3 >/dev/null ||
  { echo "FAIL: python3 is required for the current-pane pty tests" >&2; exit 1; }

cat >"$AGENT_ROLES_CONFIG" <<'JSON'
{"presets": {"coder": "anthropic/claude-sonnet-5-5", "strong": "anthropic/claude-opus-5-5:high",
  "critic": "openai/gpt-6.1-sol", "budget": "anthropic/claude-haiku-4"},
 "pinned": ["reviewer"],
 "teams": {"core": {"orchestrator": "strong", "dev": "coder"}}}
JSON

# Pi lists the models it can use. A real launch records its environment and
# arguments, tells the stub herdr that it is up, and exits.
cat >"$tmp/bin/pi" <<'STUB'
#!/usr/bin/env bash
if [[ $1 == --list-models ]]; then
  printf '%s\n' 'provider   model' 'anthropic  claude-sonnet-5-5' \
    'anthropic  claude-opus-5-5' 'openai     gpt-6.1-sol' \
    'anthropic  claude-haiku-4'
  exit 0
fi
{
  printf 'cwd=%s\n' "$PWD"
  printf 'agent_dir=%s\n' "${PI_CODING_AGENT_DIR:-}"
  printf 'role_name=%s\n' "${AGENT_ROLE_NAME:-}"
  printf 'prefix=%s\n' "${AGENT_ROLE_PREFIX:-}"
  printf 'mode=%s\n' "${AGENT_ROLE_MODE:-}"
  printf 'args=%s\n' "$*"
  printf 'pid=%s\n' "$$"
  printf 'markers=%s\n' "$(ls "$AGENT_ROLES_STATE_DIR/here-panes" 2>/dev/null | tr '\n' ' ')"
} >>"$PI_LOG"
[[ ${PI_NO_DETECT:-0} == 1 ]] || : >"$DETECTED"
sleep "${PI_SLEEP:-1}"
exit "${PI_RC:-0}"
STUB

# An agent exists when $DETECTED is set. A rename makes a named agent, which
# "agent get" then finds. $AGENTS/$name holds the pane of the agent.
cat >"$tmp/bin/herdr" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
log() { printf '%s\n' "$*" >>"$HERDR_LOG"; }
case "$1 $2" in
  'agent list')
    if [[ ${LIST_FAIL:-0} == 1 ]]; then
      echo '{"error":{"code":"socket_error","message":"agent list socket error"}}' >&2
      exit 1
    fi
    if [[ -n ${LIST_AFTER_FIRST:-} ]]; then
      n=$(( $(cat "$LIST_COUNT" 2>/dev/null || echo 0) + 1 )); echo "$n" >"$LIST_COUNT"
      if ((n == 1)); then echo '{"result":{"agents":[]}}'; else printf '%s\n' "$LIST_AFTER_FIRST"; fi
      exit 0
    fi
    if [[ -n ${LIST_BODY:-} ]]; then
      printf '%s\n' "$LIST_BODY"; exit 0
    fi
    if [[ -e ${DETECTED:-/nonexistent} ]]; then
      jq -nc --arg p "$HERDR_PANE_ID" --arg k "${AGENT_KIND:-pi}" --arg n "${AGENT_NAME:-}" \
        '{result:{agents:[{pane_id:$p, name:(if $n == "" then null else $n end), agent:$k}]}}'
    else
      echo '{"result":{"agents":[]}}'
    fi ;;
  'agent get')
    if [[ ${GET_FAIL:-0} == 1 ]]; then
      echo '{"error":{"code":"socket_error","message":"agent get socket error"}}' >&2
      exit 1
    fi
    if [[ -f $AGENTS/$3 ]]; then
      jq -n --arg p "$(cat "$AGENTS/$3")" '{result:{agent:{pane_id:$p}}}'
    else
      echo '{"error":{"code":"agent_not_found"}}'; exit 1
    fi ;;
  'agent rename')
    log "rename $3 $4"
    if [[ ${RENAME_FAIL:-0} == 1 ]]; then
      echo '{"error":{"code":"invalid_agent_name"}}' >&2
      exit 1
    fi
    printf '%s' "$3" >"$AGENTS/$4"
    echo '{"result":{}}' ;;
  'agent prompt')
    log "prompt $3 $4"
    if [[ $4 == '/model '* ]]; then
      m=${4#/model }
      st=$AGENT_ROLES_PI_DIR/role-agents/$3.json
      f=$(find "$PI_CODING_AGENT_DIR/sessions" "$AGENT_ROLES_PI_DIR/sessions" \
        -name "*_$(jq -r .session "$st").jsonl" 2>/dev/null | head -n 1 || true)
      [[ -z $f ]] || jq -nc --arg p "${m%%/*}" --arg i "${m#*/}" \
        '{type:"model_change",provider:$p,modelId:$i}' >>"$f"
    fi
    echo '{"result":{}}' ;;
  'agent focus') log "focus $3" ;;
  'agent start') log "start $3 $7"; printf '%s' "$7" >"$AGENTS/$3"; echo '{"result":{}}' ;;
  'pane split') log "split $3 $5"; echo '{"result":{"pane":{"pane_id":"new-pane"}}}' ;;
  'pane rename') log "rename-pane $3 $4" ;;
  'pane run') log "run $3" ;;
  'pane close') log "close $3"; grep -lx -- "$3" "$AGENTS"/* 2>/dev/null | xargs rm -f || true ;;
  'pane list') echo '{"result":{"panes":[]}}' ;;
  'pane process-info') echo '{"result":{"process_info":{"foreground_process_group_id":null}}}' ;;
  *) echo "Unexpected herdr call: $*" >&2; exit 1 ;;
esac
STUB
# Sentinels: a stub client of each kind stays executable on PATH for the whole
# run, so a probe can never fall back to a real client. A failure is a stub
# exit code (PI_RC), never a missing or non-executable stub.
cat >"$tmp/bin/claude" <<'STUB'
#!/usr/bin/env bash
echo "claude stub" >>"$PI_LOG"
exit 99
STUB
# mv fails for the here state file when MV_FAIL=1; otherwise it is the real mv.
cat >"$tmp/bin/mv" <<'STUB'
#!/usr/bin/env bash
if [[ ${MV_FAIL:-0} == 1 && $* == *'/.here.'* ]]; then
  echo "mv: simulated publish failure" >&2; exit 1
fi
exec /bin/mv "$@"
STUB
chmod +x "$tmp/bin/pi" "$tmp/bin/herdr" "$tmp/bin/claude" "$tmp/bin/mv"
[[ $(command -v pi) == "$tmp/bin/pi" && -x $tmp/bin/pi &&
  $(command -v claude) == "$tmp/bin/claude" && -x $tmp/bin/claude ]] ||
  { echo "FAIL: client sentinels are not first on PATH" >&2; exit 1; }

# A pseudo-terminal runner: the child sees a tty on stdin and stdout, its
# output goes to a file, and the exit status is the child's status.
cat >"$tmp/ptyrun.py" <<'PY'
import os, pty, select, signal, sys, time

out_path = sys.argv[1]
cmd = sys.argv[2:]
pid, fd = pty.fork()
if pid == 0:
    try:
        os.execvp(cmd[0], cmd)
    except Exception as exc:  # pragma: no cover
        os.write(2, str(exc).encode())
        os._exit(127)

out = open(out_path, "wb")
deadline = time.time() + 30
while time.time() < deadline:
    try:
        ready, _, _ = select.select([fd], [], [], max(0.0, deadline - time.time()))
    except OSError:
        break
    if not ready:
        break
    try:
        data = os.read(fd, 65536)
    except OSError:
        break
    if not data:
        break
    out.write(data)
out.close()
try:
    os.close(fd)
except OSError:
    pass

status = 0
try:
    reaped, status = os.waitpid(pid, os.WNOHANG)
except ChildProcessError:
    reaped = pid
if reaped == 0:
    try:
        os.kill(pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    _, status = os.waitpid(pid, 0)

if os.WIFEXITED(status):
    sys.exit(os.WEXITSTATUS(status))
if os.WIFSIGNALED(status):
    sys.exit(128 + os.WTERMSIG(status))
sys.exit(0)
PY

failures=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; failures=$((failures + 1)); }
check() { local d=$1; shift; if "$@"; then pass "$d"; else fail "$d"; fi; }

# pty_rc holds the exit status of the last run_pty call.
pty_rc=0
run_pty() { # OUT CMD...
  local out=$1
  shift
  pty_rc=0
  python3 "$tmp/ptyrun.py" "$out" "$@" || pty_rc=$?
}
wait_for() { # file [tries]
  local f=$1 n=${2:-50} i
  for ((i = 0; i < n; i++)); do
    [[ -e $f ]] && return 0
    sleep 0.1
  done
  return 1
}
wait_for_log() { # file pattern [tries]
  local f=$1 p=$2 n=${3:-50} i
  for ((i = 0; i < n; i++)); do
    [[ -f $f ]] && grep -q "$p" "$f" && return 0
    sleep 0.1
  done
  return 1
}
# No temporary here state file may remain once the helper has ended.
no_here_tmp() { # [tries]
  local n=${1:-40} i
  for ((i = 0; i < n; i++)); do
    compgen -G "$meta/.here.*" >/dev/null || return 0
    sleep 0.1
  done
  return 1
}
# A live process stands for a running --here client; a reaped one for an exit.
start_live() { sleep 60 </dev/null >/dev/null 2>&1 & live_pid=$!; }
stop_live() { [[ -z $live_pid ]] || { kill "$live_pid" 2>/dev/null || true; wait "$live_pid" 2>/dev/null || true; live_pid=""; }; }
dead_pid() { (exit 0) & local p=$!; wait "$p" || true; echo "$p"; }
write_marker() { # name pane pid
  local key
  mkdir -p "$here_dir"
  key=$(printf '%s' "$2" | od -An -tx1 | tr -d ' \n')
  jq -n --arg n "$1" --arg p "$2" --argjson pid "$3" --arg tab "wT:t2" \
    '{name:$n, pane:$p, pid:$pid, tab:$tab}' >"$here_dir/$key.json"
}

reset_state() {
  [[ -x $tmp/bin/pi && -x $tmp/bin/claude ]] || { echo "FAIL: a client sentinel is not executable" >&2; exit 1; }
  rm -rf "$meta" "$AGENT_ROLES_STATE_DIR/tabs" "$here_dir" "$cache"/here-*.log
  rm -f "$AGENTS"/* "$DETECTED" "$LIST_COUNT"
  : >"$HERDR_LOG" >"$PI_LOG"
}

# --- Option guards (no tty needed) --------------------------------------

reset_state
if out=$(bash "$ar" orchestrator --here --pane right --dry-run 2>&1); then
  fail '--here with --pane (here first) is refused'
else
  [[ $out == *--pane* ]] && pass '--here with --pane (here first) is refused' ||
    fail "--here --pane message: $out"
fi
[[ ! -s $HERDR_LOG ]] && pass 'conflict makes no herdr call' || fail 'conflict herdr call'

reset_state
if out=$(bash "$ar" orchestrator --pane right --here --dry-run 2>&1); then
  fail '--here with --pane (pane first) is refused'
else
  [[ $out == *--pane* ]] && pass '--here with --pane (pane first) is refused' ||
    fail "--pane --here message: $out"
fi

reset_state
out=$(bash "$ar" orchestrator --here --dry-run 2>&1)
[[ $out == *'env '* && $out == *'pi '* ]] && pass 'dry run prints the foreground env/client command' ||
  fail "here dry run: $out"
[[ $out != *'herdr agent start'* ]] && pass 'here dry run has no agent start' ||
  fail 'here dry run uses agent start'

reset_state
out=$(bash "$ar" dev --here --dry-run 2>&1)
[[ $out == *"PI_CODING_AGENT_DIR=$AGENT_ROLES_PI_DIR"* &&
  $out == *'AGENT_ROLE_NAME=wt-t2-dev'* && $out == *'AGENT_ROLE_MODE=task'* ]] &&
  pass 'worker dry run shows the isolated role environment' || fail "worker here dry run: $out"

reset_state
out=$(bash "$ar" reviewer --here --dry-run 2>&1)
[[ $out != *'herdr agent start'* ]] && pass 'here ignores the default role placement' ||
  fail 'here used the role placement'

reset_state
if out=$(bash "$ar" orchestrator --here </dev/null 2>&1); then
  fail 'a here launch without a terminal is refused'
else
  [[ $out == *terminal* ]] && pass 'a here launch without a terminal is refused' ||
    fail "non-tty message: $out"
fi
[[ ! -s $HERDR_LOG ]] && pass 'non-tty launch makes no herdr call' || fail 'non-tty herdr call'

reset_state
out=$(bash "$ar" orchestrator --here --validate 2>&1)
[[ $out == *'env '* && $out == *'pi '* && ! -s $HERDR_LOG ]] &&
  pass '--here --validate prints the command and starts nothing' ||
  fail "here validate: $out"

reset_state
out=$(bash "$ar" orchestrator --here --client claude --dry-run 2>&1)
[[ $out == *'claude'* && $out == *'--append-system-prompt-file'* ]] &&
  pass 'a Claude orchestrator here keeps its prompt option' || fail "here claude: $out"

# --- Real foreground launches (pseudo-terminal) -------------------------

reset_state
: >"$DETECTED"
run_pty "$tmp/pty.out" bash "$ar" orchestrator --here --team core --session busy
[[ $pty_rc != 0 ]] && pass 'a caller pane that hosts an agent is refused' ||
  fail 'a busy caller pane was accepted'
[[ ! -s $PI_LOG ]] && pass 'a busy caller pane does not start the client' ||
  fail 'a busy caller pane started the client'
! grep -qE '^(split|start|rename-pane)' "$HERDR_LOG" && pass 'a busy caller pane makes no pane' ||
  { fail 'a busy caller pane mutated a pane'; cat "$HERDR_LOG"; }
[[ ! -e $AGENT_ROLES_STATE_DIR/tabs ]] && pass 'a busy caller pane does not bind the team' ||
  fail 'a busy caller pane bound the team'
[[ ! -e $meta/wt-t2-orch.json ]] && pass 'a busy caller pane publishes no metadata' ||
  fail 'a busy caller pane published metadata'

reset_state
run_pty "$tmp/pty.out" env LIST_FAIL=1 bash "$ar" orchestrator --here --team core --session listfail
[[ $pty_rc != 0 ]] && pass 'a failed agent list refuses the here launch' ||
  fail 'a failed agent list was ignored'
[[ ! -s $PI_LOG ]] && pass 'a failed agent list starts no client' ||
  fail 'a client started after an agent-list error'
! grep -qE '^(split|start|rename-pane)' "$HERDR_LOG" && pass 'a failed agent list makes no pane' ||
  { fail 'a pane was made after an agent-list error'; cat "$HERDR_LOG"; }
[[ ! -e $AGENT_ROLES_STATE_DIR/tabs ]] && pass 'a failed agent list does not bind the team' ||
  fail 'the team was bound after an agent-list error'
[[ ! -e $meta/wt-t2-orch.json ]] && pass 'a failed agent list publishes no metadata' ||
  fail 'metadata was published after an agent-list error'
grep -q 'agent list socket error' "$tmp/pty.out" &&
  pass 'an agent-list error keeps the herdr diagnostic' || fail 'the herdr diagnostic was lost'

# The installed herdr schema needs a result object with an agents array. A
# null or missing result or agents is a read error, not an empty pane.
check_bad_list() { # BODY LABEL
  local body=$1 label=$2
  reset_state
  run_pty "$tmp/pty.out" env LIST_BODY="$body" bash "$ar" orchestrator --here --team core --session badlist
  [[ $pty_rc != 0 ]] && pass "a malformed list ($label) refuses the launch" ||
    fail "a malformed list ($label) was accepted"
  [[ ! -s $PI_LOG ]] && pass "a malformed list ($label) starts no client" ||
    fail "a malformed list ($label) started a client"
  [[ ! -e $AGENT_ROLES_STATE_DIR/tabs ]] && pass "a malformed list ($label) does not bind the team" ||
    fail "a malformed list ($label) bound the team"
  [[ ! -e $meta/wt-t2-orch.json && ! -e $here_dir ]] && pass "a malformed list ($label) publishes no state" ||
    fail "a malformed list ($label) published state"
  grep -q 'cannot read the herdr agent list' "$tmp/pty.out" &&
    pass "a malformed list ($label) is a read error" || fail "a malformed list ($label) message"
}
check_bad_list '{"result":null}' 'null result'
check_bad_list '{"result":{}}' 'empty result'
check_bad_list '{"result":{"agents":null}}' 'null agents'
check_bad_list '{"result":{"agents":["x",{"pane_id":"caller","agent":"pi","name":"someone"}]}}' 'scalar entry before a busy one'
check_bad_list '{"result":{"agents":[null]}}' 'null entry'
check_bad_list '{"result":{"agents":[[{"pane_id":"caller"}]]}}' 'array entry'
check_bad_list '{"result":{"agents":[{"agent":"pi","name":null}]}}' 'entry without pane_id'
check_bad_list '{"result":{"agents":[{"pane_id":7,"agent":"pi"}]}}' 'numeric pane_id'
check_bad_list '{"result":{"agents":[{"pane_id":"","agent":"pi"}]}}' 'empty pane_id'
check_bad_list '{"result":{"agents":[{"pane_id":"other","agent":5}]}}' 'numeric agent'
check_bad_list '{"result":{"agents":[{"pane_id":"other","agent":false}]}}' 'boolean agent'
check_bad_list '{"result":{"agents":[{"pane_id":"other","agent":"pi","name":7}]}}' 'numeric name'

# Valid lists: a busy caller pane is refused as busy; other panes are accepted.
reset_state
run_pty "$tmp/pty.out" env LIST_BODY='{"result":{"agents":[{"pane_id":"caller","agent":"pi","name":"x"}]}}' \
  bash "$ar" orchestrator --here --session validbusy
[[ $pty_rc != 0 && ! -s $PI_LOG ]] && grep -q 'already hosts an agent' "$tmp/pty.out" &&
  pass 'a valid busy list refuses as busy' || fail 'a valid busy list'
reset_state
run_pty "$tmp/pty.out" env LIST_BODY='{"result":{"agents":[{"pane_id":"other","agent":"pi","name":null},{"pane_id":"p3","agent":null}]}}' \
  AGENT_ROLES_HERE_TRIES=1 PI_SLEEP=1 bash "$ar" orchestrator --here --session validother
[[ $pty_rc == 0 ]] && grep -q -- '--session-id validother' "$PI_LOG" &&
  pass 'a valid list with other panes is accepted' || fail 'a valid list with other panes'

# A malformed list after a clean launch check: the helper keeps the diagnostic.
reset_state
run_pty "$tmp/pty.out" env LIST_AFTER_FIRST='{"result":{"agents":["x"]}}' AGENT_ROLES_HERE_TRIES=3 PI_SLEEP=2 \
  bash "$ar" orchestrator --here --session helperdiag
[[ $pty_rc == 0 ]] && pass 'a malformed helper list keeps the client running' || fail "helper diag rc=$pty_rc"
wait_for_log "$cache/here-wt-t2-orch.log" 'did not detect' 40 || true
grep -q 'agent list failed: unexpected agent list: {"result":{"agents":\["x"\]}}' "$cache/here-wt-t2-orch.log" &&
  pass 'the helper logs the malformed list' || { fail 'the helper lost the diagnostic'; cat "$cache/here-wt-t2-orch.log"; }
[[ ! -e $meta/wt-t2-orch.json ]] && pass 'a malformed helper list publishes nothing' || fail 'helper published on a malformed list'
no_here_tmp && pass 'a malformed helper list leaves no temp state' || fail 'temp state leaked (malformed list)'

# F2: an explicit empty --pane still conflicts with --here, in both orders.
for mode in --dry-run --validate; do
  reset_state
  if out=$(bash "$ar" orchestrator --here --pane "" $mode 2>&1); then
    fail "--here --pane '' $mode was accepted"
  else
    [[ $out == *--pane* ]] && pass "--here --pane '' $mode is refused" || fail "empty pane message: $out"
  fi
  reset_state
  if out=$(bash "$ar" orchestrator --pane "" --here $mode 2>&1); then
    fail "--pane '' --here $mode was accepted"
  else
    [[ $out == *--pane* ]] && pass "--pane '' --here $mode is refused" || fail "empty pane message: $out"
  fi
done
reset_state
run_pty "$tmp/pty.out" bash "$ar" orchestrator --here --pane "" --session emptypane
[[ $pty_rc != 0 && ! -s $PI_LOG ]] && pass "a real --here --pane '' starts no client" ||
  fail "a real --here --pane '' started a client"
reset_state
run_pty "$tmp/pty.out" bash "$ar" orchestrator --pane "" --here --team core --session emptypane2
[[ $pty_rc != 0 && ! -s $PI_LOG && ! -e $AGENT_ROLES_STATE_DIR/tabs ]] &&
  pass "a real --pane '' --here starts no client and binds no team" ||
  fail "a real --pane '' --here was accepted"

reset_state
run_pty "$tmp/pty.out" env LIST_BODY='{"result":{"agents":[]}}' AGENT_ROLES_HERE_TRIES=1 PI_SLEEP=1 \
  bash "$ar" orchestrator --here --session emptyok
[[ $pty_rc == 0 ]] && pass 'a valid empty agent list is accepted' ||
  fail "valid empty list rc=$pty_rc"
grep -q -- '--session-id emptyok' "$PI_LOG" && pass 'a valid empty list starts the client' ||
  fail 'a valid empty list did not start the client'

reset_state
run_pty "$tmp/pty.out" bash "$ar" orchestrator --here --name Orch_X --session badname
[[ $pty_rc != 0 ]] && pass 'an invalid here name is refused' || fail 'an invalid name was accepted'
[[ ! -s $PI_LOG ]] && pass 'an invalid name starts no client' || fail 'an invalid name started a client'
[[ ! -e $AGENT_ROLES_STATE_DIR/tabs ]] && pass 'an invalid name does not bind the team' ||
  fail 'an invalid name bound the team'
[[ ! -e $meta/Orch_X.json ]] && pass 'an invalid name publishes no metadata' ||
  fail 'an invalid name published metadata'
grep -q 'a-z' "$tmp/pty.out" && pass 'the invalid-name message names the rule' ||
  fail 'the invalid-name message is not clear'

reset_state
run_pty "$tmp/pty.out" bash "$ar" orchestrator --here --preset strong \
  --session orch-s1 --cwd "$tmp/work"
[[ $pty_rc == 0 ]] && pass 'orchestrator here exits with the client status' ||
  fail "orchestrator here rc=$pty_rc"
if wait_for "$meta/wt-t2-orch.json"; then
  st=$meta/wt-t2-orch.json
  jq -e --arg c "$tmp/work" '.role == "orchestrator" and .where == "here" and
    .pane == "caller" and .session == "orch-s1" and .cwd == $c and .chat == false' \
    "$st" >/dev/null && pass 'orchestrator here metadata' || { fail 'orchestrator here metadata'; cat "$st"; }
else
  fail 'orchestrator here metadata was not published'
fi
grep -q 'rename caller wt-t2-orch' "$HERDR_LOG" && pass 'the helper names the agent' ||
  fail 'the helper did not name the agent'
! grep -qE '^(split|start|rename-pane)' "$HERDR_LOG" && pass 'here creates no pane' ||
  { fail 'here created a pane'; cat "$HERDR_LOG"; }
grep -q "agent_dir=$PI_CODING_AGENT_DIR" "$PI_LOG" && pass 'orchestrator keeps user context' ||
  fail 'orchestrator context'
grep -q 'orch-wake.ts' "$PI_LOG" && pass 'orchestrator loads orch-wake' || fail 'orch-wake'
grep -q "cwd=$tmp/work" "$PI_LOG" && pass 'here runs in the given cwd' || fail 'here cwd'
grep -q 'args=.*--model anthropic/claude-opus-5-5:high' "$PI_LOG" && pass 'here uses the preset' ||
  fail 'here preset'
grep -q -- '--session-id orch-s1' "$PI_LOG" && pass 'here continues the session' || fail 'here session'
grep -q 'does not prove readiness' "$tmp/pty.out" && pass 'launch JSON says it is not readiness' ||
  fail 'launch JSON readiness note'
! grep -qE 'client exited|did not detect|named ' "$tmp/pty.out" &&
  pass 'helper output stays off the client screen' || fail 'helper output on the client screen'

reset_state
run_pty "$tmp/pty.out" bash "$ar" dev --here --preset strong --session dev-s1 --cwd "$tmp/work"
[[ $pty_rc == 0 ]] && pass 'worker here exits with the client status' || fail "worker here rc=$pty_rc"
if wait_for "$meta/wt-t2-dev.json"; then
  jq -e '.role == "dev" and .where == "here" and .chat == false' "$meta/wt-t2-dev.json" >/dev/null &&
    pass 'worker here metadata' || fail 'worker here metadata'
else
  fail 'worker here metadata was not published'
fi
grep -q "agent_dir=$AGENT_ROLES_PI_DIR" "$PI_LOG" && pass 'worker keeps its isolated context' ||
  fail 'worker context'
grep -q 'role_name=wt-t2-dev' "$PI_LOG" && grep -q 'mode=task' "$PI_LOG" &&
  pass 'worker here names the role and task mode' || fail 'worker here env'
grep -q 'role-reply.ts' "$PI_LOG" && pass 'a task worker loads role-reply' || fail 'role-reply'
! grep -qE '^(split|start|rename-pane)' "$HERDR_LOG" && pass 'worker here creates no pane' ||
  fail 'worker here pane'

reset_state
run_pty "$tmp/pty.out" bash "$ar" dev --here --chat --session devc-s1
[[ $pty_rc == 0 ]] && pass 'chat here exits with the client status' || fail "chat here rc=$pty_rc"
if wait_for "$meta/wt-t2-dev.json"; then
  jq -e '.chat == true' "$meta/wt-t2-dev.json" >/dev/null && pass 'chat here metadata' ||
    fail 'chat here metadata'
else
  fail 'chat here metadata was not published'
fi
grep -q 'mode=chat' "$PI_LOG" && pass 'chat here uses chat mode' || fail 'chat mode'
! grep -q 'role-reply.ts' "$PI_LOG" && pass 'a chat worker does not load role-reply' ||
  fail 'chat role-reply'

reset_state
run_pty "$tmp/pty.out" bash "$ar" orchestrator --here --team core --session orch-team
if wait_for "$meta/wt-t2-orch.json"; then
  jq -e '.team == "core" and .preset == "strong"' "$meta/wt-t2-orch.json" >/dev/null &&
    pass 'here records the team and its preset' || fail 'here team metadata'
else
  fail 'here team metadata was not published'
fi
grep -q 'args=.*--model anthropic/claude-opus-5-5:high' "$PI_LOG" &&
  pass 'here reaches the client with the team model' || fail 'here team model'
compgen -G "$AGENT_ROLES_STATE_DIR/tabs/*.json" >/dev/null &&
  pass 'here binds the tab team' || fail 'here did not bind the team'

reset_state
run_pty "$tmp/pty.out" bash "$ar" orchestrator --here --focus --session orch-focus
! grep -q '^focus' "$HERDR_LOG" && pass '--focus is a no-op for here' || fail 'here focused a pane'

# --- Bounded identity detection -----------------------------------------

reset_state
run_pty "$tmp/pty.out" env PI_NO_DETECT=1 PI_SLEEP=1 AGENT_ROLES_HERE_TRIES=2 \
  bash "$ar" orchestrator --here --session orch-to
[[ $pty_rc == 0 ]] && pass 'timeout keeps the client exit status' || fail "timeout rc=$pty_rc"
wait_for_log "$cache/here-wt-t2-orch.log" 'did not detect' 30 &&
  pass 'a detection timeout is logged' || fail 'no timeout log'
[[ ! -e $meta/wt-t2-orch.json ]] && pass 'no metadata before naming (timeout)' ||
  fail 'metadata published on timeout'
! grep -q '^rename' "$HERDR_LOG" && pass 'no rename on timeout' || fail 'rename on timeout'

reset_state
run_pty "$tmp/pty.out" env PI_NO_DETECT=1 PI_SLEEP=0 PI_RC=7 \
  bash "$ar" orchestrator --here --session orch-early
[[ $pty_rc == 7 ]] && pass 'an early client exit keeps its status' || fail "early rc=$pty_rc"
wait_for_log "$cache/here-wt-t2-orch.log" 'client exited' 30 &&
  pass 'an early client exit is logged' || fail 'no early-exit log'
[[ ! -e $meta/wt-t2-orch.json ]] && pass 'no metadata on early exit' || fail 'metadata on early exit'
! grep -q '^rename' "$HERDR_LOG" && pass 'no rename on early exit' || fail 'rename on early exit'
! grep -q '^close' "$HERDR_LOG" && pass 'an early exit closes no pane' || fail 'early exit closed a pane'

reset_state
run_pty "$tmp/pty.out" env AGENT_KIND=codex AGENT_ROLES_HERE_TRIES=2 PI_SLEEP=1 \
  bash "$ar" orchestrator --here --session wrongkind
[[ $pty_rc == 0 ]] && pass 'a wrong kind keeps the client running' || fail "wrong kind rc=$pty_rc"
! grep -q '^rename' "$HERDR_LOG" && pass 'the helper does not rename another kind' ||
  fail 'the helper renamed another kind'
[[ ! -e $meta/wt-t2-orch.json ]] && pass 'no metadata for another kind' ||
  fail 'metadata published for another kind'
wait_for_log "$cache/here-wt-t2-orch.log" 'did not detect' 30 &&
  pass 'a wrong kind is a detection miss' || fail 'no detection log for a wrong kind'

reset_state
run_pty "$tmp/pty.out" env AGENT_NAME=other-agent AGENT_ROLES_HERE_TRIES=2 PI_SLEEP=1 \
  bash "$ar" orchestrator --here --session diffname
[[ $pty_rc == 0 ]] && pass 'an existing other name keeps the client running' || fail "other name rc=$pty_rc"
! grep -q '^rename' "$HERDR_LOG" && pass 'the helper does not rename an existing other name' ||
  fail 'the helper renamed an existing other name'
[[ ! -e $meta/wt-t2-orch.json ]] && pass 'no metadata when the pane name is taken' ||
  fail 'metadata published when the pane name was taken'

reset_state
run_pty "$tmp/pty.out" env RENAME_FAIL=1 AGENT_ROLES_HERE_TRIES=2 PI_SLEEP=1 \
  bash "$ar" orchestrator --here --session renamefail
[[ $pty_rc == 0 ]] && pass 'a rename failure keeps the client running' || fail "rename failure rc=$pty_rc"
grep -q '^rename' "$HERDR_LOG" && pass 'the helper tries to name the detected agent' ||
  fail 'the helper did not try to name the detected agent'
[[ ! -e $meta/wt-t2-orch.json ]] && pass 'a rename failure publishes no metadata' ||
  fail 'metadata published after a rename failure'
wait_for_log "$cache/here-wt-t2-orch.log" 'could not name' 30 &&
  pass 'a rename failure is told apart from a detection miss' || fail 'rename failure log'
grep -q 'rename failed' "$cache/here-wt-t2-orch.log" &&
  pass 'the rename error is logged' || fail 'the rename error was not logged'

# Every helper exit path removes its temporary state file (Bash 3.2 does not
# run an EXIT trap when a background function returns).
reset_state
run_pty "$tmp/pty.out" bash "$ar" orchestrator --here --session cleanok
wait_for "$meta/wt-t2-orch.json" && no_here_tmp && pass 'success leaves no temp state' ||
  fail 'success left temp state'
reset_state
run_pty "$tmp/pty.out" env PI_NO_DETECT=1 PI_SLEEP=0 PI_RC=7 bash "$ar" orchestrator --here --session cleanearly
wait_for_log "$cache/here-wt-t2-orch.log" 'client exited' 40 || true
no_here_tmp && pass 'an early client exit leaves no temp state' || fail 'early exit left temp state'
reset_state
run_pty "$tmp/pty.out" env PI_NO_DETECT=1 PI_SLEEP=1 AGENT_ROLES_HERE_TRIES=2 bash "$ar" orchestrator --here --session cleanto
wait_for_log "$cache/here-wt-t2-orch.log" 'did not detect' 40 || true
no_here_tmp && pass 'a detection timeout leaves no temp state' || fail 'timeout left temp state'
reset_state
run_pty "$tmp/pty.out" env RENAME_FAIL=1 PI_SLEEP=1 AGENT_ROLES_HERE_TRIES=2 bash "$ar" orchestrator --here --session cleanren
wait_for_log "$cache/here-wt-t2-orch.log" 'could not name' 40 || true
no_here_tmp && pass 'a rename failure leaves no temp state' || fail 'rename failure left temp state'
reset_state
run_pty "$tmp/pty.out" env MV_FAIL=1 PI_SLEEP=1 bash "$ar" orchestrator --here --session cleanpub
[[ $pty_rc == 0 ]] && pass 'a publish failure keeps the client status' || fail "publish failure rc=$pty_rc"
wait_for_log "$cache/here-wt-t2-orch.log" 'publish failed' 40 &&
  pass 'a publish failure is logged' || { fail 'no publish failure log'; cat "$cache/here-wt-t2-orch.log"; }
no_here_tmp && pass 'a publish failure leaves no temp state' || fail 'publish failure left temp state'
[[ ! -e $meta/wt-t2-orch.json ]] && pass 'a publish failure publishes no state' || fail 'state published despite mv failure'
! grep -qE 'publish failed|simulated' "$tmp/pty.out" && pass 'helper errors stay off the client screen' ||
  fail 'helper errors reached the client screen'

# The launch guard: a marker for the calling pane exists before the client
# runs, belongs to the client process, and does not depend on naming.
reset_state
run_pty "$tmp/pty.out" env PI_NO_DETECT=1 PI_SLEEP=1 AGENT_ROLES_HERE_TRIES=2 bash "$ar" orchestrator --here --session guardlaunch
mk=$here_dir/$(printf '%s' caller | od -An -tx1 | tr -d ' \n').json
[[ $(grep '^markers=' "$PI_LOG" | head -n 1) == "markers=$(basename "$mk") " ]] &&
  pass 'the pane guard exists before the client runs' || { fail 'no pane guard at client start'; cat "$PI_LOG"; }
[[ -f $mk ]] && jq -e --arg pid "$(grep '^pid=' "$PI_LOG" | head -n 1 | cut -d= -f2)" \
  '.pane == "caller" and .name == "wt-t2-orch" and (.pid | tostring) == $pid' "$mk" >/dev/null &&
  pass 'the pane guard names the pane, the agent and the client pid' || fail 'pane guard content'
[[ ! -e $meta/wt-t2-orch.json ]] && pass 'the guard exists without main state (naming never happened)' ||
  fail 'main state present'
reset_state
start_live
write_marker wt-t2-orch caller "$live_pid"
run_pty "$tmp/pty.out" bash "$ar" orchestrator --here --team core --session guard2
[[ $pty_rc != 0 && ! -s $PI_LOG && ! -e $AGENT_ROLES_STATE_DIR/tabs ]] && grep -q 'already runs' "$tmp/pty.out" &&
  pass 'a second --here in a guarded pane is refused before binding' || fail 'second here in a guarded pane'
stop_live

# --- Refuse the split lifecycle for here agents --------------------------

write_here_meta() { # name role session session_dir
  mkdir -p "$meta"
  jq -n --arg name "$1" --arg role "$2" --arg session "$3" --arg sd "$4" \
    --arg cwd "$tmp/work" \
    '{name:$name, role:$role, preset:"coder", model:"anthropic/claude-sonnet-5-5",
      pane:"caller", where:"here", cwd:$cwd, session:$session, tab:"wT:t2",
      skip:0, team:"", client:"pi", session_dir:$sd, chat:false}' >"$meta/$1.json"
}
write_split_meta() { # name role
  mkdir -p "$meta"
  jq -n --arg name "$1" --arg role "$2" --arg cwd "$tmp/work" \
    --arg sd "$AGENT_ROLES_PI_DIR" \
    '{name:$name, role:$role, preset:"coder", model:"anthropic/claude-sonnet-5-5",
      pane:"new-pane", where:"right", cwd:$cwd, session:"s0", tab:"wT:t2",
      skip:0, team:"", client:"pi", session_dir:$sd, chat:false}' >"$meta/$1.json"
}

reset_state
write_here_meta wt-t2-dev dev dev-here "$AGENT_ROLES_PI_DIR"
printf '%s' caller >"$AGENTS/wt-t2-dev"
if out=$(bash "$ar" --stop wt-t2-dev 2>&1); then
  fail '--stop refuses a here agent'
else
  [[ $out == *--here* ]] && pass '--stop refuses a here agent' || fail "stop message: $out"
fi
! grep -q '^close' "$HERDR_LOG" && pass 'refused --stop closes no pane' || fail 'refused --stop closed a pane'

# A here agent that is definitively gone can be cleaned up: no pane closes.
reset_state
write_here_meta wt-t2-dev dev gone-here "$AGENT_ROLES_PI_DIR"
if out=$(bash "$ar" --stop wt-t2-dev 2>&1); then
  pass '--stop cleans up a gone here agent'
else
  fail "gone here stop: $out"
fi
[[ ! -e $meta/wt-t2-dev.json ]] && pass 'gone here cleanup removes the state file' ||
  fail 'gone here cleanup kept the state file'
! grep -q '^close' "$HERDR_LOG" && pass 'gone here cleanup closes no pane' ||
  fail 'gone here cleanup closed a pane'

# A transient agent-get failure must not erase the here protection.
reset_state
write_here_meta wt-t2-dev dev live-here "$AGENT_ROLES_PI_DIR"
printf '%s' caller >"$AGENTS/wt-t2-dev"
GET_FAIL=1 bash "$ar" --models >/dev/null 2>&1 || true
[[ -e $meta/wt-t2-dev.json ]] && pass 'a transient get failure keeps the here state' ||
  fail 'a transient get failure erased the here state'
if out=$(bash "$ar" --stop wt-t2-dev 2>&1); then
  fail '--stop succeeded after a transient read erased the here state'
else
  [[ $out == *--here* ]] && pass '--stop still refuses after a transient read' ||
    fail "transient stop: $out"
fi
! grep -q '^close' "$HERDR_LOG" && pass 'a transient read never closes the here pane' ||
  fail 'a transient read closed the here pane'

# --stop with a get read error refuses before any pane close.
reset_state
write_here_meta wt-t2-dev dev stop-read "$AGENT_ROLES_PI_DIR"
printf '%s' caller >"$AGENTS/wt-t2-dev"
if out=$(GET_FAIL=1 bash "$ar" --stop wt-t2-dev 2>&1); then
  fail 'a stop read error was ignored'
else
  [[ $out == *cannot* ]] && pass '--stop refuses on a get read error' ||
    fail "stop read error: $out"
fi
! grep -q '^close' "$HERDR_LOG" && pass 'a stop read error closes no pane' ||
  fail 'a stop read error closed a pane'

reset_state
write_here_meta wt-t2-dev dev dev-here "$AGENT_ROLES_PI_DIR"
write_split_meta wt-t2-orch orchestrator
printf '%s' caller >"$AGENTS/wt-t2-dev"
printf '%s' new-pane >"$AGENTS/wt-t2-orch"
if out=$(bash "$ar" --stop wt-t2-orch wt-t2-dev 2>&1); then
  fail 'a mixed --stop refuses before closing'
else
  [[ $out == *--here* ]] && pass 'a mixed --stop refuses before closing' || fail "mixed stop: $out"
fi
! grep -q '^close' "$HERDR_LOG" && pass 'mixed --stop preflight closes nothing' ||
  { fail 'mixed --stop closed a pane'; cat "$HERDR_LOG"; }

reset_state
write_here_meta wt-t2-dev dev dev-here "$AGENT_ROLES_PI_DIR"
printf '%s' caller >"$AGENTS/wt-t2-dev"
if out=$(bash "$ar" --restart wt-t2-dev 2>&1); then
  fail '--restart refuses a here agent'
else
  [[ $out == *--here* ]] && pass '--restart refuses a here agent' || fail "restart message: $out"
fi
! grep -qE '^(close|split)' "$HERDR_LOG" && pass 'refused --restart changes no pane' ||
  { fail 'refused --restart changed a pane'; cat "$HERDR_LOG"; }

# --set-model: the live session path stays; the restart fallback is refused.
reset_state
write_here_meta wt-t2-dev dev no-task "$AGENT_ROLES_PI_DIR"
printf '%s' caller >"$AGENTS/wt-t2-dev"
if out=$(bash "$ar" --set-model wt-t2-dev strong 2>&1); then
  fail '--set-model refuses the here restart fallback'
else
  [[ $out == *--here* ]] && pass '--set-model refuses the here restart fallback' ||
    fail "set-model fallback: $out"
fi
! grep -q '^prompt' "$HERDR_LOG" && pass 'no model prompt for the refused fallback' ||
  fail 'refused fallback prompted the agent'

reset_state
write_here_meta wt-t2-dev dev live-s1 "$AGENT_ROLES_PI_DIR"
printf '%s' caller >"$AGENTS/wt-t2-dev"
mkdir -p "$AGENT_ROLES_PI_DIR/sessions"
jq -nc '{type:"message",message:{role:"user"}}' \
  >"$AGENT_ROLES_PI_DIR/sessions/2026_live-s1.jsonl"
if out=$(bash "$ar" --set-model wt-t2-dev strong 2>&1); then
  pass '--set-model keeps the here live-session path'
else
  fail "here live set-model: $out"
fi
grep -q '^prompt wt-t2-dev /model anthropic/claude-opus-5-5' "$HERDR_LOG" &&
  pass 'the live path sends /model' || fail 'the live path did not send /model'

# --- Pane protection independent of the main state file -------------------

no_close() { ! grep -qE '^(close|split)' "$HERDR_LOG"; }
# A live client guards the pane. The agent is addressable and has a name, but
# the main state file is missing, then corrupt.
reset_state
start_live
write_marker wt-t2-orch caller "$live_pid"
printf '%s' caller >"$AGENTS/wt-t2-orch"
if out=$(bash "$ar" --stop wt-t2-orch 2>&1); then fail '--stop closed a guarded pane (no main state)'
else [[ $out == *--here* ]] && pass '--stop refuses a guarded pane with no main state' || fail "guard message: $out"; fi
no_close && pass 'no pane closes (no main state)' || fail 'a guarded pane was closed (no main state)'
mkdir -p "$meta"; printf 'not json' >"$meta/wt-t2-orch.json"
if out=$(bash "$ar" --stop wt-t2-orch 2>&1); then fail '--stop closed a guarded pane (corrupt main state)'
else pass '--stop refuses a guarded pane with corrupt main state'; fi
no_close && pass 'no pane closes (corrupt main state)' || fail 'a guarded pane was closed (corrupt state)'
[[ -e $meta/wt-t2-orch.json ]] && pass 'a refused stop keeps the state' || fail 'a refused stop removed state'

# Launch is pending: the client runs, but herdr has not named it yet. A
# missing name is not proof of exit.
reset_state
write_marker wt-t2-orch caller "$live_pid"
if out=$(bash "$ar" --stop wt-t2-orch 2>&1); then fail '--stop treated a pending launch as gone'
else [[ $out == *--here* ]] && pass '--stop refuses while naming is pending' || fail "pending message: $out"; fi
no_close && pass 'a pending launch closes no pane' || fail 'a pending launch closed a pane'
[[ -e $here_dir ]] && pass 'a refused stop keeps the guard' || fail 'a refused stop removed the guard'

# A renamed agent in a guarded pane is guarded by its pane, not by its name.
reset_state
write_marker wt-t2-orch caller "$live_pid"
printf '%s' caller >"$AGENTS/someone-else"
if out=$(bash "$ar" --stop someone-else 2>&1); then fail '--stop closed a guarded pane by another name'
else pass '--stop refuses a guarded pane by another agent name'; fi
no_close && pass 'no pane closes by another name' || fail 'a guarded pane closed by another name'

# A mixed batch: nothing closes when one name is guarded.
reset_state
write_marker wt-t2-orch caller "$live_pid"
printf '%s' caller >"$AGENTS/wt-t2-orch"
write_split_meta wt-t2-dev dev
printf '%s' new-pane >"$AGENTS/wt-t2-dev"
if bash "$ar" --stop wt-t2-dev wt-t2-orch >/dev/null 2>&1; then fail 'a mixed guarded batch was stopped'
else pass 'a mixed guarded batch is refused'; fi
no_close && pass 'a mixed guarded batch closes nothing' || { fail 'a mixed guarded batch closed a pane'; cat "$HERDR_LOG"; }
[[ -f $meta/wt-t2-dev.json ]] && pass 'a mixed guarded batch keeps the other state' || fail 'the other state was removed'

# A read error with a live guard refuses.
reset_state
write_marker wt-t2-orch caller "$live_pid"
write_split_meta wt-t2-dev dev
printf '%s' new-pane >"$AGENTS/wt-t2-dev"
if out=$(GET_FAIL=1 bash "$ar" --stop wt-t2-dev 2>&1); then fail '--stop ignored a read error under a live guard'
else [[ $out == *cannot* ]] && pass '--stop refuses on a read error under a live guard' || fail "read error message: $out"; fi
no_close && pass 'a read error under a live guard closes nothing' || fail 'closed on a read error'

# Remote restart and the model-change restart fallback refuse for a guarded
# pane even when the main state does not say "here".
reset_state
write_marker wt-t2-dev caller "$live_pid"
write_split_meta wt-t2-dev dev
printf '%s' caller >"$AGENTS/wt-t2-dev"
if out=$(bash "$ar" --restart wt-t2-dev 2>&1); then fail '--restart closed a guarded pane'
else [[ $out == *--here* ]] && pass '--restart refuses a guarded pane' || fail "restart guard: $out"; fi
no_close && pass '--restart on a guarded pane closes and splits nothing' || fail 'restart changed a guarded pane'
reset_state
write_marker wt-t2-dev caller "$live_pid"
write_split_meta wt-t2-dev dev
printf '%s' caller >"$AGENTS/wt-t2-dev"
if out=$(bash "$ar" --set-model wt-t2-dev strong 2>&1); then fail '--set-model fallback closed a guarded pane'
else pass '--set-model fallback refuses a guarded pane'; fi
no_close && pass 'the model restart fallback closes nothing on a guarded pane' || fail 'model fallback changed a guarded pane'
! grep -q '^prompt' "$HERDR_LOG" && pass 'no prompt for the refused fallback (guard)' || fail 'prompted despite the guard'
stop_live

# A stale guard (the client has exited) is not protection: cleanup works,
# closes no pane, and the guard goes away.
reset_state
write_marker wt-t2-orch caller "$(dead_pid)"
write_here_meta wt-t2-orch orchestrator gone "$AGENT_ROLES_PI_DIR"
if out=$(bash "$ar" --stop wt-t2-orch 2>&1); then pass '--stop cleans up after the client exited'
else fail "stale cleanup: $out"; fi
no_close && pass 'stale cleanup closes no pane' || fail 'stale cleanup closed a pane'
[[ ! -e $meta/wt-t2-orch.json && ! -e $here_dir/$(printf '%s' caller | od -An -tx1 | tr -d ' \n').json ]] &&
  pass 'stale cleanup removes the state and the guard' || fail 'stale cleanup left files'
# A stale guard on a pane that now hosts an ordinary agent does not block it.
reset_state
write_marker wt-t2-orch new-pane "$(dead_pid)"
write_split_meta wt-t2-dev dev
printf '%s' new-pane >"$AGENTS/wt-t2-dev"
bash "$ar" --stop wt-t2-dev >/dev/null 2>&1 && grep -q '^close new-pane' "$HERDR_LOG" &&
  pass 'a stale guard does not block an ordinary stop' || fail 'a stale guard blocked an ordinary stop'
# A guard whose pid was reused by another process (start time differs) is stale.
reset_state
start_live
mkdir -p "$here_dir"
jq -n --argjson pid "$live_pid" '{name:"wt-t2-dev",pane:"new-pane",pid:$pid,started:"Thu Jan  1 00:00:00 1970",tab:"wT:t2"}' \
  >"$here_dir/$(printf '%s' new-pane | od -An -tx1 | tr -d ' \n').json"
write_split_meta wt-t2-dev dev
printf '%s' new-pane >"$AGENTS/wt-t2-dev"
bash "$ar" --stop wt-t2-dev >/dev/null 2>&1 && grep -q '^close new-pane' "$HERDR_LOG" &&
  pass 'a guard with a reused pid is stale' || fail 'a reused pid kept the guard'
stop_live
# An unreadable guard fails closed and names the file to remove.
reset_state
mkdir -p "$here_dir"; printf 'garbage' >"$here_dir/ab.json"
write_split_meta wt-t2-dev dev
printf '%s' new-pane >"$AGENTS/wt-t2-dev"
if out=$(bash "$ar" --stop wt-t2-dev 2>&1); then fail '--stop ignored an unreadable guard'
else [[ $out == *ab.json* ]] && pass 'an unreadable guard refuses and names its file' || fail "unreadable guard: $out"; fi
no_close && pass 'an unreadable guard closes nothing' || fail 'closed despite an unreadable guard'

# --- Ordinary behavior is unchanged --------------------------------------

reset_state
run_pty "$tmp/pty.out" bash "$ar" dev --preset strong --session split-s1
[[ $pty_rc == 0 ]] && pass 'an ordinary launch still exits with the client' || fail "ordinary rc=$pty_rc"
grep -q '^split caller right' "$HERDR_LOG" && pass 'an ordinary launch still splits' ||
  { fail 'ordinary launch did not split'; cat "$HERDR_LOG"; }
grep -q '^start wt-t2-dev new-pane' "$HERDR_LOG" && pass 'an ordinary launch still starts' ||
  fail 'ordinary launch did not start'
! grep -q '^rename caller' "$HERDR_LOG" && pass 'an ordinary launch does not rename the caller' ||
  fail 'ordinary launch renamed the caller'
if wait_for "$meta/wt-t2-dev.json"; then
  jq -e '.where == "right"' "$meta/wt-t2-dev.json" >/dev/null && pass 'ordinary placement is saved' ||
    fail 'ordinary placement'
else
  fail 'ordinary metadata'
fi
if out=$(bash "$ar" --stop wt-t2-dev 2>&1); then
  pass 'an ordinary --stop still works'
else
  fail "ordinary stop: $out"
fi
grep -q '^close new-pane' "$HERDR_LOG" && pass 'an ordinary --stop closes its pane' ||
  fail 'ordinary stop did not close'

((failures == 0)) || { echo "$failures current-pane test(s) failed"; exit 1; }
echo "All current-pane tests passed"
