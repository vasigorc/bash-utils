# herdr helpers for zsh. This file is safe to load on a machine without herdr:
# hw and ht check for herdr when you run them.

# The agents directory of this repo, found from this file's real location.
typeset -g _HW_AGENTS=${${(%):-%x}:A:h:h:h}/agents

# hw [-o pi|claude] [-m MODEL] [-r ROLE] [dir] [label]: make a herdr workspace
# for agent work.
# ht [-o pi|claude] [-m MODEL] [-r ROLE] [dir] [label]: make a tab in the
# current herdr workspace for agent work. Run it inside herdr.
#
# Both make the same layout:
#
#   +----------------+          +----------------+------+
#   | nvim           |          | nvim           | side |
#   +--------+-------+   --->   +--------+-------+      |
#   | orch   | dev   |          | orch   | dev   |      |
#   +--------+-------+          +--------+-------+------+
#
# agent-role opens dev right of the orchestrator. The side column appears when
# the first of pm, qa, or reviewer starts, and goes away when the last stops.
#
# An option wins over its environment variable, which wins over the default:
#   -o, --orchestrator  HW_ORCHESTRATOR  default: pi    (pi or claude)
#   -m, --model         HW_MODEL         default: the orchestrator's own
#
# With -r ROLE the lower pane is not an orchestrator. It runs that one role
# agent in chat mode (agent-role ROLE --chat), named <prefix>-ROLE, with the
# focus. Role agents are always Pi, so -o claude is refused. -m is then the
# preset of the role.
hw() { _herdr_agent_layout hw "$@" }
ht() { _herdr_agent_layout ht "$@" }

# talk ROLE [agent-role option...]: chat with one role agent in this tab. No
# orchestrator, no STATUS: report. The agent opens in its usual pane and gets
# the focus. Examples: talk pm, talk qa --preset strong.
# Outside herdr, talk makes a new workspace with hw -r ROLE. It then takes only
# --preset (as hw -m).
talk() {
  emulate -L zsh
  [[ -n ${1:-} && $1 != -* ]] || { print -u2 "usage: talk ROLE [agent-role option...]"; return 1 }
  (( $+commands[agent-role] )) || { print -u2 "talk: agent-role is not on your PATH"; return 1 }
  local role=$1
  shift
  if [[ ${HERDR_ENV:-} != 1 ]]; then
    local -a hw_args
    if [[ ${1:-} == --preset && -n ${2:-} ]]; then hw_args=(-m $2); shift 2; fi
    (( $# == 0 )) || { print -u2 "talk: outside herdr, use: hw -r $role [-m MODEL] [dir]"; return 1 }
    hw -r $role $hw_args
    return
  fi
  agent-role $role --chat --focus "$@"
}

# The agent name prefix for a tab: its id in lower case, with ":" as "-".
# Agent names allow only letters, digits, "_" and "-". Example: wT:t2 -> wt-t2.
_herdr_agent_prefix() { print -r -- ${(L)1//:/-} }

_herdr_agent_layout() {
  emulate -L zsh
  local cmd=$1 what
  shift
  case $cmd in
    hw) what="a herdr workspace" ;;
    ht) what="a tab in the current herdr workspace" ;;
  esac
  local -a o_orch o_model o_role o_help
  zparseopts -D -E -F -- o:=o_orch -orchestrator:=o_orch m:=o_model -model:=o_model \
    r:=o_role -role:=o_role h=o_help -help=o_help || return 1
  if (( $#o_help )); then
    cat <<EOF
usage: $cmd [-o pi|claude] [-m MODEL] [-r ROLE] [dir] [label]

Make $what for agent work: nvim at the top, the
orchestrator below it. Role agents open with agent-role.
hw makes a new workspace. ht makes a new tab in the current workspace, and
works only inside herdr.

  -o, --orchestrator  pi or claude.
                      Default: \$HW_ORCHESTRATOR (now: ${HW_ORCHESTRATOR:-not set}), else pi.
  -m, --model         The orchestrator's model.
                      Default: \$HW_MODEL (now: ${HW_MODEL:-not set}), else the
                      orchestrator's own default.
                      pi:     provider/id, with an optional :thinking level,
                              or a preset name of the agent-roles config.
                              Examples: anthropic/claude-opus-5-5,
                              openrouter/z-ai/glm-5.3:high, strong.
                              List: pi --list-models
                      claude: an alias or a model id, with no provider.
                              Examples: sonnet, opus, claude-sonnet-5-5.
  -r, --role          Chat with one role agent (dev, reviewer, qa, pm) in the
                      lower pane. There is no orchestrator. -m is then the
                      preset of the role, and -o claude is refused.
  dir                 The working directory. Default: the current directory.
  label               The label. Default: the directory name.
  -h, --help          Show this help.

Examples:
  $cmd
  $cmd ~/src/my-project my-project
  $cmd -o claude -m sonnet
  $cmd -m anthropic/claude-sonnet-5-5:high
  $cmd -r pm
EOF
    return 0
  fi

  local kind=${${o_orch[-1]:-${HW_ORCHESTRATOR:-pi}}#=}
  local model=${${o_model[-1]:-${HW_MODEL:-}}#=}
  local dir=${${1:-$PWD}:A}
  local label=${2:-${dir:t}}
  local role=${${o_role[-1]:-}#=}
  local reply tab top orch out i prompt
  local -a args

  case $kind in
    pi | claude) ;;
    *) print -u2 "$cmd: unknown orchestrator: $kind (use pi or claude)"; return 1 ;;
  esac
  if [[ -n $role ]]; then
    [[ $role =~ '^[A-Za-z0-9_-]+$' ]] || { print -u2 "$cmd: bad role name: $role"; return 1 }
    # Only an explicit -o claude is an error: HW_ORCHESTRATOR names the
    # orchestrator, and there is none here.
    [[ ${${o_orch[-1]:-}#=} != claude ]] ||
      { print -u2 "$cmd: role agents are always Pi, so -o claude does not work with -r"; return 1 }
    (( $+commands[agent-role] )) || { print -u2 "$cmd: agent-role is not on your PATH"; return 1 }
  fi
  (( $+commands[herdr] )) || { print -u2 "$cmd: herdr is not installed"; return 1 }
  (( $+commands[jq] )) || { print -u2 "$cmd: jq is not installed"; return 1 }
  herdr status server 2>/dev/null | grep -q '^status: running' ||
    { print -u2 "$cmd: the herdr server is not running. Start herdr first, outside tmux."; return 1 }
  [[ -d $dir ]] || { print -u2 "$cmd: no such directory: $dir"; return 1 }
  if [[ $cmd == ht ]]; then
    [[ ${HERDR_ENV:-} == 1 && -n ${HERDR_WORKSPACE_ID:-} ]] ||
      { print -u2 "ht: run ht inside a herdr pane, or use hw"; return 1 }
  fi

  if [[ -z $role ]]; then
    # The orchestrator's extra prompt: its role, then the writing style. Only
    # the orchestrator gets these. Role agents do not.
    prompt=${XDG_CACHE_HOME:-$HOME/.cache}/agent-roles/orchestrator.md
    mkdir -p ${prompt:h}
    { cat $_HW_AGENTS/shared/ORCHESTRATOR.md && print && cat $_HW_AGENTS/shared/STYLE.md } >| $prompt 2>/dev/null
    # For pi, a preset name of the agent-roles config gives its model. Any
    # other value goes to pi as it is.
    if [[ $kind == pi && -n $model && $model != */* ]]; then
      local config=${AGENT_ROLES_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/agent-roles/config.json}
      model=$(jq -r --arg p "$model" '.presets[$p] // $p' "$config" 2>/dev/null || print -r -- "$model")
    fi
    [[ -n $model ]] && args+=(--model "$model")
    if [[ -s $prompt ]]; then
      case $kind in
        pi) args+=(--append-system-prompt "$prompt") ;;
        claude) args+=(--append-system-prompt-file "$prompt") ;;
      esac
    fi
  fi

  case $cmd in
    hw) reply=$(herdr workspace create --cwd "$dir" --label "$label" --focus) || return ;;
    ht) reply=$(herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$dir" \
          --label "$label" --focus) || return ;;
  esac
  tab=$(jq -er '.result.root_pane.tab_id' <<<"$reply") &&
    top=$(jq -er '.result.root_pane.pane_id' <<<"$reply") ||
    { print -u2 "$cmd: unexpected reply: $reply"; return 1 }

  orch=$(herdr pane split "$top" --direction down --cwd "$dir" --no-focus |
    jq -er '.result.pane.pane_id') || { print -u2 "$cmd: orchestrator split failed"; return 1 }
  herdr pane run "$top" nvim >/dev/null

  if [[ -n $role ]]; then
    # agent-role takes the tab and the calling pane from the environment, and
    # needs HERDR_ENV=1. Without them it would use the caller's tab: the name
    # prefix, the side column and --models would point at the wrong tab. hw can
    # also run outside herdr, where HERDR_ENV is not set.
    HERDR_ENV=1 HERDR_TAB_ID=$tab HERDR_PANE_ID=$orch agent-role $role --chat --focus \
      --pane $orch ${model:+--preset $model} >/dev/null ||
      { print -u2 "$cmd: could not start $role in $tab (see above)"; return 1 }
    [[ ${HERDR_ENV:-} == 1 ]] ||
      print "$cmd: $label ($tab) is ready. Open herdr to see it."
    return 0
  fi

  # A new pane needs a moment before its shell is ready.
  for i in {1..30}; do
    out=$(herdr agent start "$(_herdr_agent_prefix $tab)-orch" --kind "$kind" \
      --pane "$orch" -- $args 2>&1) && break
    [[ $out == *agent_pane_busy* ]] || { print -u2 "$cmd: $out"; return 1 }
    sleep 0.5
  done
  [[ $out != *'"error"'* ]] || { print -u2 "$cmd: $out"; return 1 }
  herdr pane rename "$orch" "$orch · $(_herdr_agent_prefix $tab)-orch" >/dev/null

  [[ ${HERDR_ENV:-} == 1 ]] ||
    print "$cmd: $label ($tab) is ready. Open herdr to see it."
}
