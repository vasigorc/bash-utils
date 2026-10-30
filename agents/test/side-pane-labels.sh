#!/usr/bin/env bash
# Run the real launcher against a stub herdr; no server or agents are started.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/roles"
export PATH="$tmp/bin:$PATH"
export AGENT_ROLES_CONFIG="$tmp/config.json" AGENT_ROLES_DIR="$tmp/roles"
export XDG_CACHE_HOME="$tmp/cache"
export HERDR_ENV=1 HERDR_PANE_ID=caller HERDR_TAB_ID=wT:t2
export PANE_FIXTURE="$tmp/panes.json" HERDR_LOG="$tmp/herdr.log"

printf '%s\n' '{"presets":{"test":"test-model"}}' >"$AGENT_ROLES_CONFIG"
cat >"$tmp/roles/reviewer.md" <<'ROLE'
---
preset: test
pane: side
---
Test role.
ROLE

cat >"$tmp/bin/herdr" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
case "$1 $2" in
  'agent get') exit 1 ;;
  'pane list')
    [[ $* == 'pane list --workspace wT' ]]
    cat "$PANE_FIXTURE" ;;
  'pane layout')
    echo 'layout' >>"$HERDR_LOG"
    echo '{"result":{"layout":{"panes":[{"pane_id":"caller","rect":{"x":0,"y":0}}]}}}' ;;
  'pane split')
    printf 'split %s %s\n' "$3" "$5" >>"$HERDR_LOG"
    echo '{"result":{"pane":{"pane_id":"new-pane"}}}' ;;
  'pane rename')
    printf 'rename %s %s\n' "$3" "$4" >>"$HERDR_LOG" ;;
  'agent start')
    printf 'start %s %s\n' "$3" "$7" >>"$HERDR_LOG"
    echo '{"result":{}}' ;;
  *) echo "Unexpected herdr call: $*" >&2; exit 1 ;;
esac
STUB
chmod +x "$tmp/bin/herdr"

# Idle distractors precede valid side panes: none may be reused or split.
# Fixtures follow the pane list fields consumed by side_panes().
fixture() {
  jq -n --arg label "$1" --argjson agent "$2" '{result: {panes: [
    {pane_id: "null-label", tab_id: "wT:t2", label: null, agent: null},
    {pane_id: "non-side", tab_id: "wT:t2", label: "work", agent: null},
    {pane_id: "near-prefix", tab_id: "wT:t2", label: "side:wrong", agent: null},
    {pane_id: "other-legacy", tab_id: "wT:t3", label: "side", agent: null},
    {pane_id: "other-named", tab_id: "wT:t3", label: "side: other", agent: null},
    {pane_id: "side-pane", tab_id: "wT:t2", label: $label, agent: $agent}
  ]}}' >"$PANE_FIXTURE"
}

failures=0
check() {
  local description=$1
  shift
  cat >"$tmp/expected"
  : >"$HERDR_LOG"
  if bash "$root/agents/bin/agent-role" reviewer "$@" >"$tmp/out" 2>"$tmp/err" &&
    diff -u "$tmp/expected" "$HERDR_LOG"; then
    echo "PASS: $description"
  else
    echo "FAIL: $description"
    cat "$tmp/err"
    failures=$((failures + 1))
  fi
}

fixture side '{"name":"busy"}'
check 'new pane below legacy side column uses resolved default name' <<'EXPECTED'
split side-pane down
rename new-pane side: wt-t2-reviewer
start wt-t2-reviewer new-pane
EXPECTED

fixture 'side: busy' '{"name":"busy"}'
check 'new pane below named side column stays in that column' <<'EXPECTED'
split side-pane down
rename new-pane side: wt-t2-reviewer
start wt-t2-reviewer new-pane
EXPECTED

fixture side null
check 'reuse legacy idle pane and label it with explicit name' --name reviewer-next <<'EXPECTED'
rename side-pane side: reviewer-next
start reviewer-next side-pane
EXPECTED

fixture 'side: old-reviewer' null
check 'reuse named idle pane and replace its old name' --name reviewer-next <<'EXPECTED'
rename side-pane side: reviewer-next
start reviewer-next side-pane
EXPECTED

if ((failures)); then
  echo "$failures test(s) failed"
  exit 1
fi
echo 'All 4 side-pane label tests passed'
