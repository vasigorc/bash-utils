#!/usr/bin/env bash
# Exercise hw/ht with a stub herdr; never contact a server or start agents.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
export PATH="$tmp/bin:$PATH" XDG_CACHE_HOME="$tmp/cache"
export HERDR_ENV=1 HERDR_WORKSPACE_ID=wT HW_ORCHESTRATOR=pi HW_MODEL=
export HERDR_LOG="$tmp/herdr.log" START_FAIL=0

cat >"$tmp/bin/herdr" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
case "$1 $2" in
  'status server') echo 'status: running' ;;
  'workspace create' | 'tab create')
    echo '{"result":{"root_pane":{"tab_id":"wT:t2","pane_id":"wT:p1"}}}' ;;
  'pane split') echo '{"result":{"pane":{"pane_id":"wT:p1J"}}}' ;;
  'pane run') printf 'run %s %s\n' "$3" "$4" >>"$HERDR_LOG" ;;
  'agent start')
    printf 'start %s %s\n' "$3" "$7" >>"$HERDR_LOG"
    if [[ $START_FAIL == 1 ]]; then
      echo '{"error":{"code":"test_failure"}}'; exit 1
    fi
    echo '{"result":{}}' ;;
  'pane rename') printf 'rename %s %s\n' "$3" "$4" >>"$HERDR_LOG" ;;
  *) echo "Unexpected herdr call: $*" >&2; exit 1 ;;
esac
STUB
chmod +x "$tmp/bin/herdr"

failures=0
for helper in hw ht; do
  : >"$HERDR_LOG"
  cat >"$tmp/expected" <<'EXPECTED'
run wT:p1 nvim
start wt-t2-orch wT:p1J
rename wT:p1J wT:p1J · wt-t2-orch
EXPECTED
  if zsh -f -c 'source "$1"; "$2" "$3"' _ \
    "$root/terminals/herdr/herdr.zsh" "$helper" "$tmp" &&
    diff -u "$tmp/expected" "$HERDR_LOG"; then
    echo "PASS: $helper labels only the orchestrator after start"
  else
    echo "FAIL: $helper orchestrator label"
    failures=$((failures + 1))
  fi
done

export START_FAIL=1
: >"$HERDR_LOG"
if zsh -f -c 'source "$1"; ht "$2"' _ \
  "$root/terminals/herdr/herdr.zsh" "$tmp" >"$tmp/out" 2>"$tmp/err"; then
  echo 'FAIL: ht accepted a failed agent start'
  failures=$((failures + 1))
elif grep -q '^rename ' "$HERDR_LOG"; then
  echo 'FAIL: ht renamed a pane after failed agent start'
  failures=$((failures + 1))
else
  echo 'PASS: failed start does not rename a pane'
fi

((failures == 0))
echo 'All 3 orchestrator pane label tests passed'
