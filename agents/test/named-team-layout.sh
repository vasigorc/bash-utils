#!/usr/bin/env bash
# Integration through the real launcher and zsh helpers, using only stubs.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/work"
export PATH="$tmp/bin:$PATH" XDG_CACHE_HOME="$tmp/cache" XDG_STATE_HOME="$tmp/state"
export AGENT_ROLES_CONFIG="$tmp/config.json" AGENT_ROLES_PI_DIR="$tmp/pi-agent"
export PI_CODING_AGENT_DIR="$tmp/user-agent" HERDR_LOG="$tmp/herdr.log"
export HERDR_ENV=1 HERDR_WORKSPACE_ID=wT HERDR_TAB_ID=ambient:t9 HERDR_PANE_ID=ambient:p9
unset AGENT_ROLES_PRESET HW_MODEL HW_ORCHESTRATOR
ln -s "$root/agents/bin/agent-role" "$tmp/bin/agent-role"
cat >"$AGENT_ROLES_CONFIG" <<'JSON'
{"presets":{"coder":"anthropic/claude-sonnet-5-5","strong":"anthropic/claude-opus-5-5","critic":"openai/gpt-6.1-sol"},"teams":{"core":{"orchestrator":"strong","reviewer":"critic"},"primavera":{"orchestrator":"critic","reviewer":"strong"}},"pinned":["reviewer"]}
JSON
cat >"$tmp/bin/pi" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' 'anthropic claude-sonnet-5-5' 'anthropic claude-opus-5-5' 'openai gpt-6.1-sol'
STUB
cat >"$tmp/bin/herdr" <<'STUB'
#!/usr/bin/env bash
case "$1 $2" in
  'status server') echo 'status: running' ;;
  'workspace create'|'tab create') echo "$*" >>"$HERDR_LOG"; echo '{"result":{"root_pane":{"tab_id":"wT:t2","pane_id":"top"}}}' ;;
  'pane split') echo "$*" >>"$HERDR_LOG"; echo '{"result":{"pane":{"pane_id":"lower"}}}' ;;
  'pane run'|'pane rename'|'agent focus') echo "$*" >>"$HERDR_LOG" ;;
  'pane list') echo '{"result":{"panes":[]}}' ;;
  'agent get'|'agent list') exit 1 ;;
  'agent start') echo "$*" >>"$HERDR_LOG"; echo '{"result":{}}' ;;
  *) echo "Unexpected herdr: $*" >&2; exit 1 ;;
esac
STUB
chmod +x "$tmp/bin/pi" "$tmp/bin/herdr"
helper() { zsh -f -c 'source "$1"; shift; "$@"' _ "$root/terminals/herdr/herdr.zsh" "$@"; }
failures=0
for h in hw ht; do
  helper "$h" --help >"$tmp/help"
  if grep -q -- '--team' "$tmp/help" && grep -q 'HW_MODEL.*team\|team.*HW_MODEL' "$tmp/help"; then
    echo "PASS: $h team help"
  else echo "FAIL: $h team help"; failures=$((failures+1)); fi
done
agent-role --help >"$tmp/help"
for option in --team --client --validate; do
  if grep -q -- "$option" "$tmp/help"; then echo "PASS: help $option";
  else echo "FAIL: help $option"; failures=$((failures+1)); fi
done
for h in hw ht; do
  : >"$HERDR_LOG"
  # Separate stub tab lifecycles between assertions.
  rm -rf "$tmp/state/agent-roles/tabs"
  if helper "$h" --team primavera "$tmp/work" label >/dev/null &&
    grep -q 'agent start wt-t2-orch --kind pi --pane lower' "$HERDR_LOG" &&
    grep -q -- '--model openai/gpt-6.1-sol' "$HERDR_LOG" &&
    grep -q 'pane run top nvim' "$HERDR_LOG" &&
    ! grep -q 'role-reply.ts' "$HERDR_LOG"; then echo "PASS: $h team orchestrator reuse";
  else echo "FAIL: $h team orchestrator reuse"; failures=$((failures+1)); fi
  : >"$HERDR_LOG"
  if helper "$h" --team core "$tmp/work" >/dev/null 2>&1 &&
    grep -q -- '--model anthropic/claude-opus-5-5' "$HERDR_LOG"; then
    echo "PASS: $h reused tab id gets fresh binding"
  else echo "FAIL: $h reused tab id"; failures=$((failures+1)); fi
  : >"$HERDR_LOG"
  if helper "$h" "$tmp/work" >/dev/null &&
    HERDR_TAB_ID=wT:t2 agent-role dev --dry-run >"$tmp/worker" 2>&1 &&
    grep -q 'team: none' "$tmp/worker"; then
    echo "PASS: $h plain fresh tab worker has no stale team"
  else echo "FAIL: $h stale plain tab team"; failures=$((failures+1)); fi
  : >"$HERDR_LOG"
  if HW_MODEL=coder helper "$h" --team primavera "$tmp/work" >/dev/null &&
    grep -q -- '--model anthropic/claude-sonnet-5-5' "$HERDR_LOG"; then
    echo "PASS: $h HW_MODEL overrides team"
  else echo "FAIL: $h HW_MODEL precedence"; failures=$((failures+1)); fi
  : >"$HERDR_LOG"
  if HW_MODEL=coder helper "$h" --team primavera -m critic "$tmp/work" >/dev/null &&
    grep -q -- '--model openai/gpt-6.1-sol' "$HERDR_LOG"; then
    echo "PASS: $h explicit model overrides HW_MODEL"
  else echo "FAIL: $h explicit model precedence"; failures=$((failures+1)); fi
  : >"$HERDR_LOG"
  if helper "$h" --team primavera -r reviewer "$tmp/work" >/dev/null &&
    grep -q -- '--model anthropic/claude-opus-5-5' "$HERDR_LOG" &&
    ! grep -q -- 'orch-wake.ts' "$HERDR_LOG"; then echo "PASS: $h selected worker chat";
  else echo "FAIL: $h worker chat"; failures=$((failures+1)); fi
  for t in missing core; do
    : >"$HERDR_LOG"
    if helper "$h" --team "$t" -o claude "$tmp/work" >"$tmp/out" 2>&1; then
      if [[ $t == missing ]]; then failures=$((failures+1)); fi
    elif [[ $t == missing && ! -s $HERDR_LOG ]]; then echo "PASS: invalid team preflight";
    else failures=$((failures+1)); fi
    rm -rf "$tmp/state/agent-roles/tabs"
  done
  : >"$HERDR_LOG"
  if helper "$h" --team primavera -o claude "$tmp/work" >"$tmp/out" 2>&1; then failures=$((failures+1));
  elif [[ ! -s $HERDR_LOG ]] && grep -q 'Claude' "$tmp/out"; then echo 'PASS: incompatible Claude preflight';
  else failures=$((failures+1)); fi
done
((failures == 0)) || { echo "$failures layout tests failed"; exit 1; }
echo 'All named-team layout tests passed'
