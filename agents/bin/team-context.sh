# Shared named-team policy. Sourced by agent-role (Bash).
# tab keys encode every byte, rather than lossy agent-name normalization.
team_path() {
  local key
  key=$(printf '%s' "$tab" | od -An -tx1 | tr -d ' \n')
  printf '%s/tabs/%s.json\n' "$state_root" "$key"
}
select_team() {
  local bound="" path
  if [[ ${saved_team:-0} == 0 && -n $tab ]]; then
    path=$(team_path)
    if [[ -e $path ]]; then
      bound=$(jq -er '.team | select(type == "string" and length > 0)' "$path") || die "invalid tab team context: $path"
      echo "agent-role: note: inheriting team '$bound' by tab id; cannot verify tab incarnation. Tabs created outside hw/ht may have stale context after id reuse." >&2
    fi
  fi
  [[ -z $team_opt || -z $bound || $team_opt == "$bound" ]] ||
    die "tab $tab is bound to team '$bound', not '$team_opt'"
  team=${team_opt:-$bound}
  [[ -n $team ]] || return 0
  jq -e --arg t "$team" '(.teams | type) == "object" and (.teams | has($t))' "$config" >/dev/null || die "unknown team '$team'"
  jq -e --arg t "$team" '.teams[$t] | type == "object" and all(to_entries[];
    (.key | test("^[A-Za-z0-9_-]+$")) and (.value | type == "string" and length > 0))' "$config" >/dev/null || die "malformed assignment in team '$team'"
  local r p
  while IFS=$'\t' read -r r p; do
    [[ $r == orchestrator || -f $roles_dir/$r.md ]] || die "no role file for team assignment '$r'"
    resolve_model "$p" >/dev/null
  done < <(jq -r --arg t "$team" '.teams[$t] | to_entries[] | [.key, .value] | @tsv' "$config")
}
team_baseline() { # role fallback
  local p=""
  [[ -z $team ]] || p=$(jq -r --arg t "$team" --arg r "$1" '.teams[$t][$r] // empty' "$config")
  if [[ $1 == orchestrator && -n $team && -z $p ]]; then
    die "team '$team' has no orchestrator assignment"
  fi
  printf '%s\n' "${p:-$2}"
}
# Called ONLY by hw/ht immediately after a successful tab/workspace create.
# This is not a way to change the binding of a live tab.
init_fresh_tab() {
  [[ -n $tab ]] || die "fresh tab initialization needs HERDR_TAB_ID"
  rm -f "$(team_path)"
}

# Saved empty team is explicit none, not a request for ambient inheritance.
restore_team() {
  local st=$1 target
  target=$(jq -r '.tab // empty' "$st")
  [[ -n $target && $tab == "$target" ]] || die "agent belongs to tab '$target'; run this operation in that tab"
  team_opt=$(jq -r '.team // empty' "$st")
  saved_team=1
  select_team
}

bind_team() (
  [[ -n $team && -n $tab ]] || return 0
  local path lock tmp="" i
  path=$(team_path); lock=$path.lock
  mkdir -p "${path%/*}" || exit 1
  for ((i=0; !i || i<100; i++)); do
    mkdir "$lock" 2>/dev/null && break
    sleep 0.05
  done
  [[ $i -lt 100 ]] || die "tab team context is locked: $tab"
  trap '[[ -z $tmp ]] || rm -f "$tmp"; rmdir "$lock"' EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM
  # Recheck under the lock: two concurrent first launches cannot switch a tab.
  if [[ -e $path ]]; then
    local bound
    bound=$(jq -er '.team | select(type == "string" and length > 0)' "$path") || exit 1
    if [[ $bound != "$team" ]]; then
      die "tab $tab is already bound to another team"
    fi
  else
    tmp=$(mktemp "$path.XXXXXX") || exit 1
    jq -n --arg team "$team" --arg tab "$tab" '{$team, $tab}' >"$tmp" || exit 1
    mv "$tmp" "$path" || exit 1
  fi
)
