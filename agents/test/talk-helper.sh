#!/usr/bin/env bash
# The talk helper of herdr.zsh, against a stub agent-role.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >"$LOG"\n' >"$tmp/bin/agent-role"
chmod +x "$tmp/bin/agent-role"
export PATH="$tmp/bin:$PATH" LOG="$tmp/log"

failures=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; failures=$((failures + 1)); }
talk() { zsh -c "source '$root/terminals/herdr/herdr.zsh'; talk $*" 2>&1; }

: >"$LOG"
HERDR_ENV=1 talk pm --preset strong
[[ $(cat "$LOG") == 'pm --chat --focus --preset strong' ]] &&
  pass 'talk starts the role in chat mode with focus' || fail "talk args: $(cat "$LOG")"

: >"$LOG"
out=$(HERDR_ENV=1 talk) && rc=0 || rc=$?
[[ $rc == 1 && $out == *usage* && ! -s $LOG ]] && pass 'no role: usage' || fail 'no role'

: >"$LOG"
out=$(HERDR_ENV=1 talk --preset strong) && rc=0 || rc=$?
[[ $rc == 1 && ! -s $LOG ]] && pass 'an option first is not a role' || fail 'option first'

: >"$LOG"
out=$(HERDR_ENV=0 talk pm) && rc=0 || rc=$?
[[ $rc == 1 && $out == *'inside a herdr pane'* && ! -s $LOG ]] &&
  pass 'outside herdr: clear error' || fail 'outside herdr'

((failures == 0)) || { echo "$failures talk test(s) failed"; exit 1; }
echo "All talk helper tests passed"
