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
export AGENT_ROLES_PI_DIR="$tmp/pi-agent" PI_CODING_AGENT_DIR="$tmp/user-agent"
mkdir -p "$PI_CODING_AGENT_DIR"
printf '%s\n' '{"theme":"dark","defaultThinkingLevel":"high","packages":["npm:x"]}' \
  >"$PI_CODING_AGENT_DIR/settings.json"
echo '{}' >"$PI_CODING_AGENT_DIR/auth.json"
export HERDR_ENV=1 HERDR_PANE_ID=caller HERDR_TAB_ID=wT:t2
export PANE_FIXTURE="$tmp/panes.json" HERDR_LOG="$tmp/herdr.log"

printf '%s\n' '{"presets":{"test":"test/model"}}' >"$AGENT_ROLES_CONFIG"

# Pi lists the models that it can use: here only test/model.
cat >"$tmp/bin/pi" <<'STUB'
#!/usr/bin/env bash
[[ $1 == --list-models ]] || { echo "unexpected pi call: $*" >&2; exit 1; }
printf '%s\n' 'provider  model' 'test      model'
STUB
chmod +x "$tmp/bin/pi"
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
    [[ $* == *" --env PI_CODING_AGENT_DIR=$AGENT_ROLES_PI_DIR"* ]] ||
      { echo "split without the role agent dir: $*" >&2; exit 1; }
    printf 'split %s %s\n' "$3" "$5" >>"$HERDR_LOG"
    echo '{"result":{"pane":{"pane_id":"new-pane"}}}' ;;
  'pane rename')
    printf 'rename %s %s\n' "$3" "$4" >>"$HERDR_LOG" ;;
  'pane run')
    printf 'run %s %s\n' "$3" "$4" >>"$HERDR_LOG" ;;
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
  sed "s|\$AGENT_ROLES_PI_DIR|$AGENT_ROLES_PI_DIR|" >"$tmp/expected"
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
rename new-pane side: new-pane · wt-t2-reviewer
start wt-t2-reviewer new-pane
EXPECTED

fixture 'side: busy' '{"name":"busy"}'
check 'new pane below named side column stays in that column' <<'EXPECTED'
split side-pane down
rename new-pane side: new-pane · wt-t2-reviewer
start wt-t2-reviewer new-pane
EXPECTED

fixture side null
check 'reuse legacy idle pane and label it with explicit name' --name reviewer-next <<'EXPECTED'
rename side-pane side: side-pane · reviewer-next
run side-pane export PI_CODING_AGENT_DIR=$AGENT_ROLES_PI_DIR
start reviewer-next side-pane
EXPECTED

fixture 'side: old-reviewer' null
check 'reuse named idle pane and replace its old name' --name reviewer-next <<'EXPECTED'
rename side-pane side: side-pane · reviewer-next
run side-pane export PI_CODING_AGENT_DIR=$AGENT_ROLES_PI_DIR
start reviewer-next side-pane
EXPECTED

fixture 'side: stale-pane · old-reviewer' null
check 'reuse addressed idle pane and refresh its stale address' --name reviewer-next <<'EXPECTED'
rename side-pane side: side-pane · reviewer-next
run side-pane export PI_CODING_AGENT_DIR=$AGENT_ROLES_PI_DIR
start reviewer-next side-pane
EXPECTED

check 'right pane includes address and default name' --pane right <<'EXPECTED'
split caller right
rename new-pane new-pane · wt-t2-reviewer
start wt-t2-reviewer new-pane
EXPECTED

check 'explicit ordinary pane includes address without side marker' --pane non-side <<'EXPECTED'
rename non-side non-side · wt-t2-reviewer
run non-side export PI_CODING_AGENT_DIR=$AGENT_ROLES_PI_DIR
start wt-t2-reviewer non-side
EXPECTED

fixture side null
check 'explicit legacy side pane keeps its marker' --pane side-pane <<'EXPECTED'
rename side-pane side: side-pane · wt-t2-reviewer
run side-pane export PI_CODING_AGENT_DIR=$AGENT_ROLES_PI_DIR
start wt-t2-reviewer side-pane
EXPECTED

fixture 'side: stale-pane · old-reviewer' null
check 'explicit addressed side pane keeps marker and refreshes address' --pane side-pane <<'EXPECTED'
rename side-pane side: side-pane · wt-t2-reviewer
run side-pane export PI_CODING_AGENT_DIR=$AGENT_ROLES_PI_DIR
start wt-t2-reviewer side-pane
EXPECTED

# The role agent dir links the user's files and keeps lean settings.
d=$AGENT_ROLES_PI_DIR
if [[ $(readlink "$d/auth.json") == "$PI_CODING_AGENT_DIR/auth.json" && ! -e $d/trust.json ]] &&
  jq -e '.theme == "dark" and .defaultThinkingLevel == "high" and .packages == []
    and (.extensions | index("-builtin:mcp"))' "$d/settings.json" >/dev/null; then
  echo "PASS: role agent dir links user files and keeps lean settings"
else
  echo "FAIL: role agent dir"
  ls -la "$d"; cat "$d/settings.json"
  failures=$((failures + 1))
fi

# A failed merge stops the start and leaves no lock and no temp file.
printf 'not json\n' >"$PI_CODING_AGENT_DIR/settings.json"
if ! bash "$root/agents/bin/agent-role" reviewer --pane right >/dev/null 2>&1 &&
  [[ ! -e $d/settings.json.lock ]] && ! compgen -G "$d/.settings.*" >/dev/null; then
  echo "PASS: failed settings merge removes its lock and temp file"
else
  echo "FAIL: failed settings merge"
  ls -la "$d"
  failures=$((failures + 1))
fi

if ((failures)); then
  echo "$failures test(s) failed"
  exit 1
fi
echo 'All 11 agent-role tests passed'
