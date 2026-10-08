# herdr helpers for zsh. This file is safe to load on a machine without herdr:
# hw checks for herdr when you run it.

# The agents directory of this repo, found from this file's real location.
typeset -g _HW_AGENTS=${${(%):-%x}:A:h:h:h}/agents

# hw [-o pi|claude] [-m MODEL] [dir] [label]: make a herdr workspace for
# agent work.
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
hw() {
  emulate -L zsh
  local -a o_orch o_model o_help
  zparseopts -D -E -F -- o:=o_orch -orchestrator:=o_orch m:=o_model -model:=o_model \
    h=o_help -help=o_help || return 1
  if (( $#o_help )); then
    cat <<EOF
usage: hw [-o pi|claude] [-m MODEL] [dir] [label]

Make a herdr workspace for agent work: nvim at the top, the orchestrator
below it. Role agents open with agent-role.

  -o, --orchestrator  pi or claude.
                      Default: \$HW_ORCHESTRATOR (now: ${HW_ORCHESTRATOR:-not set}), else pi.
  -m, --model         The orchestrator's model.
                      Default: \$HW_MODEL (now: ${HW_MODEL:-not set}), else the
                      orchestrator's own default.
                      pi:     provider/id, with an optional :thinking level.
                              Examples: anthropic/claude-opus-5-5,
                              openrouter/z-ai/glm-5.3:high. List: pi --list-models
                      claude: an alias or a model id, with no provider.
                              Examples: sonnet, opus, claude-sonnet-5-5.
  dir                 The workspace directory. Default: the current directory.
  label               The workspace label. Default: the directory name.
  -h, --help          Show this help.

Examples:
  hw
  hw ~/src/my-project my-project
  hw -o claude -m sonnet
  hw -m anthropic/claude-sonnet-5-5:high
EOF
    return 0
  fi

  local kind=${${o_orch[-1]:-${HW_ORCHESTRATOR:-pi}}#=}
  local model=${${o_model[-1]:-${HW_MODEL:-}}#=}
  local dir=${${1:-$PWD}:A}
  local label=${2:-${dir:t}}
  local ws wsid top orch out i prompt
  local -a args

  case $kind in
    pi | claude) ;;
    *) print -u2 "hw: unknown orchestrator: $kind (use pi or claude)"; return 1 ;;
  esac
  (( $+commands[herdr] )) || { print -u2 "hw: herdr is not installed"; return 1 }
  (( $+commands[jq] )) || { print -u2 "hw: jq is not installed"; return 1 }
  herdr status server 2>/dev/null | grep -q '^status: running' ||
    { print -u2 "hw: the herdr server is not running. Start herdr first, outside tmux."; return 1 }
  [[ -d $dir ]] || { print -u2 "hw: no such directory: $dir"; return 1 }

  # The orchestrator's extra prompt: its role, then the writing style. Only
  # the orchestrator gets these. Role agents do not.
  prompt=${XDG_CACHE_HOME:-$HOME/.cache}/agent-roles/orchestrator.md
  mkdir -p ${prompt:h}
  { cat $_HW_AGENTS/shared/ORCHESTRATOR.md && print && cat $_HW_AGENTS/shared/STYLE.md } >| $prompt 2>/dev/null
  [[ -n $model ]] && args+=(--model "$model")
  if [[ -s $prompt ]]; then
    case $kind in
      pi) args+=(--append-system-prompt "$prompt") ;;
      claude) args+=(--append-system-prompt-file "$prompt") ;;
    esac
  fi

  ws=$(herdr workspace create --cwd "$dir" --label "$label" --focus) || return
  wsid=$(jq -er '.result.workspace.workspace_id' <<<"$ws") &&
    top=$(jq -er '.result.root_pane.pane_id' <<<"$ws") ||
    { print -u2 "hw: unexpected reply: $ws"; return 1 }

  orch=$(herdr pane split "$top" --direction down --cwd "$dir" --no-focus |
    jq -er '.result.pane.pane_id') || { print -u2 "hw: orchestrator split failed"; return 1 }
  herdr pane run "$top" nvim >/dev/null

  # Agent names must be lowercase (ids can be "wA"). A new pane needs a
  # moment before its shell is ready.
  for i in {1..30}; do
    out=$(herdr agent start "${(L)wsid}-orch" --kind "$kind" --pane "$orch" -- $args 2>&1) && break
    [[ $out == *agent_pane_busy* ]] || { print -u2 "hw: $out"; return 1 }
    sleep 0.5
  done
  [[ $out != *'"error"'* ]] || { print -u2 "hw: $out"; return 1 }

  [[ ${HERDR_ENV:-} == 1 ]] ||
    print "hw: workspace $label ($wsid) is ready. Open herdr to see it."
}
