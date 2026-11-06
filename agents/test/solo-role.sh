#!/usr/bin/env bash
# hw -r ROLE and ht -r ROLE, against a stub herdr and a stub agent-role. Nothing
# contacts a server or starts agents.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
export PATH="$tmp/bin:$PATH" XDG_CACHE_HOME="$tmp/cache"
export HERDR_WORKSPACE_ID=wT HW_ORCHESTRATOR=pi HW_MODEL=
export HERDR_LOG="$tmp/herdr.log" AR_LOG="$tmp/agent-role.log"

cat >"$tmp/bin/herdr" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
case "$1 $2" in
  'status server') echo 'status: running' ;;
  'workspace create' | 'tab create')
    echo "$1 $2" >>"$HERDR_LOG"
    echo '{"result":{"root_pane":{"tab_id":"wT:t2","pane_id":"wT:p1"}}}' ;;
  'pane split') echo '{"result":{"pane":{"pane_id":"wT:p1J"}}}' ;;
  'pane run') printf 'run %s %s\n' "$3" "$4" >>"$HERDR_LOG" ;;
  'agent start') printf 'start %s\n' "$3" >>"$HERDR_LOG"; echo '{"result":{}}' ;;
  'pane rename') printf 'rename %s\n' "$3" >>"$HERDR_LOG" ;;
  *) echo "Unexpected herdr call: $*" >&2; exit 1 ;;
esac
STUB
# The stub agent-role records the herdr environment that it gets, and its args.
cat >"$tmp/bin/agent-role" <<'STUB'
#!/usr/bin/env bash
printf 'env=%s tab=%s pane=%s args=%s\n' "${HERDR_ENV:-}" "${HERDR_TAB_ID:-}" \
  "${HERDR_PANE_ID:-}" "$*" >>"$AR_LOG"
[[ ${AR_FAIL:-0} != 1 ]]
STUB
chmod +x "$tmp/bin/herdr" "$tmp/bin/agent-role"

# hw resolves DIR to a real path. Run from another directory than DIR, so a
# missing --cwd shows: agent-role would use the caller directory.
dir=$(cd "$tmp" && pwd -P)
mkdir -p "$tmp/elsewhere"
cd "$tmp/elsewhere"

failures=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; echo "-- herdr:"; cat "$HERDR_LOG"; echo "-- agent-role:"; cat "$AR_LOG"; failures=$((failures + 1)); }
# helper ARG...: run hw or ht in zsh, in the current environment.
helper() { zsh -f -c 'source "$1"; shift; "$@"' _ "$root/terminals/herdr/herdr.zsh" "$@"; }

# hw -r pm, outside herdr (HERDR_ENV unset): agent-role gets the new tab.
: >"$HERDR_LOG" >"$AR_LOG"
(unset HERDR_ENV; helper hw -r pm "$tmp" >/dev/null)
[[ $(cat "$AR_LOG") == "env=1 tab=wT:t2 pane=wT:p1J args=pm --chat --focus --pane wT:p1J --cwd $dir" ]] &&
  pass 'hw -r starts the role in chat mode in the new tab, outside herdr' || fail 'hw -r outside herdr'
grep -qx 'run wT:p1 nvim' "$HERDR_LOG" && pass 'nvim runs on top' || fail 'nvim on top'
! grep -q '^start' "$HERDR_LOG" && pass 'no orchestrator starts' || fail 'orchestrator started'
! grep -q '^rename' "$HERDR_LOG" && pass 'hw does not rename the role pane' || fail 'rename'
[[ ! -e $XDG_CACHE_HOME/agent-roles/orchestrator.md ]] && pass 'no orchestrator prompt' ||
  fail 'orchestrator prompt written'

# Inside another tab: the env override still points agent-role at the new tab.
: >"$HERDR_LOG" >"$AR_LOG"
HERDR_ENV=1 HERDR_TAB_ID=other:t9 HERDR_PANE_ID=other:p9 helper hw --role qa "$tmp" >/dev/null
[[ $(cat "$AR_LOG") == "env=1 tab=wT:t2 pane=wT:p1J args=qa --chat --focus --pane wT:p1J --cwd $dir" ]] &&
  pass 'the caller tab does not leak to agent-role' || fail 'caller tab leaked'

# -m becomes --preset.
: >"$HERDR_LOG" >"$AR_LOG"
HERDR_ENV=1 helper hw -m strong -r pm "$tmp" >/dev/null
[[ $(cat "$AR_LOG") == *'args=pm --chat --focus --pane wT:p1J --cwd '"$dir"' --preset strong' ]] &&
  pass '-m with -r is --preset' || fail '-m with -r'

# ht -r works the same, in the current workspace.
: >"$HERDR_LOG" >"$AR_LOG"
HERDR_ENV=1 helper ht -r pm "$tmp" >/dev/null
grep -qx 'tab create' "$HERDR_LOG" && grep -q 'args=pm --chat --focus' "$AR_LOG" &&
  pass 'ht -r' || fail 'ht -r'

# -o claude with -r is refused before anything is made.
: >"$HERDR_LOG" >"$AR_LOG"
if HERDR_ENV=1 helper hw -o claude -r pm "$tmp" >"$tmp/out" 2>&1; then
  fail '-o claude with -r was accepted'
elif grep -q 'always Pi' "$tmp/out" && [[ ! -s $HERDR_LOG && ! -s $AR_LOG ]]; then
  pass '-o claude with -r is refused'
else fail '-o claude with -r message'; cat "$tmp/out"; fi

# HW_ORCHESTRATOR=claude in the environment does not block -r.
: >"$HERDR_LOG" >"$AR_LOG"
HW_ORCHESTRATOR=claude HERDR_ENV=1 helper hw -r pm "$tmp" >/dev/null &&
  grep -q 'args=pm --chat' "$AR_LOG" && pass 'HW_ORCHESTRATOR=claude does not block -r' ||
  fail 'HW_ORCHESTRATOR=claude'

# A failed role start makes hw fail.
: >"$HERDR_LOG" >"$AR_LOG"
if AR_FAIL=1 HERDR_ENV=1 helper hw -r pm "$tmp" >"$tmp/out" 2>&1; then
  fail 'hw -r hid a failed role start'
else pass 'a failed role start fails hw'; fi

# Without -r, hw still starts the orchestrator.
: >"$HERDR_LOG" >"$AR_LOG"
HERDR_ENV=1 helper hw "$tmp" >/dev/null
grep -q '^start wt-t2-orch' "$HERDR_LOG" && [[ ! -s $AR_LOG ]] &&
  pass 'hw without -r starts the orchestrator' || fail 'hw without -r'

((failures == 0)) || { echo "$failures solo role test(s) failed"; exit 1; }
echo "All solo role tests passed"
