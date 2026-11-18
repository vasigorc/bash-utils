#!/usr/bin/env bash
# Fault injection against the shared helper only; no herdr server.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
export REAL_JQ=$(command -v jq) REAL_MKTEMP=$(command -v mktemp) REAL_MV=$(command -v mv)
for cmd in jq mktemp mv; do
  cat >"$tmp/bin/$cmd" <<'STUB'
#!/usr/bin/env bash
cmd=${0##*/}
if [[ $cmd == "$FAULT" ]]; then
  if [[ ${SIGNAL:-} == 1 ]]; then kill -TERM "$PPID"; sleep 0.1; fi
  exit 42
fi
case $cmd in
  jq) exec "$REAL_JQ" "$@" ;;
  mktemp) exec "$REAL_MKTEMP" "$@" ;;
  mv) exec "$REAL_MV" "$@" ;;
esac
STUB
  chmod +x "$tmp/bin/$cmd"
done
failures=0
for scenario in jq mktemp mv signal; do
  export FAULT=$scenario SIGNAL=0
  [[ $scenario != signal ]] || { FAULT=jq; SIGNAL=1; }
  state_root=$tmp/$scenario
  export state_root
  if PATH="$tmp/bin:$PATH" bash -c '
    set -euo pipefail
    source "$1/agents/bin/team-context.sh"
    die() { echo "$*" >&2; exit 1; }
    tab=wT:t2 team=core
    bind_team
  ' _ "$root"; then
    echo "FAIL: $scenario accepted failure"; failures=$((failures+1))
  fi
  if [[ -d $state_root/tabs ]] && [[ -z $(find "$state_root/tabs" -mindepth 1 -print) ]]; then
    echo "PASS: $scenario cleans lock and temporary files"
  else echo "FAIL: $scenario leaked state"; failures=$((failures+1)); fi
done
((failures == 0))
