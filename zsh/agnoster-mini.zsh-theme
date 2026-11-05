# vim:ft=zsh ts=2 sw=2 sts=2
#
# agnoster-mini - A compact variant of agnoster's theme
#
# Changes from agnoster:
#   - No user@host segment (you know who you are)
#   - Path shortened: only last 2 directories shown (e.g. apps/api)
#   - Git segment shows the same branch + dirty state, from one `git status` call
#     (3 git processes per prompt instead of 13)
#   - Status indicators preserved (error, root, background jobs)
#   - Removed bzr, hg, terraform, AWS segments (unused)
#   - Keeps virtualenv/conda for Python work

CURRENT_BG='NONE'

case ${SOLARIZED_THEME:-dark} in
  light)
    CURRENT_FG=${CURRENT_FG:-'white'}
    CURRENT_DEFAULT_FG=${CURRENT_DEFAULT_FG:-'white'}
    ;;
  *)
    CURRENT_FG=${CURRENT_FG:-'black'}
    CURRENT_DEFAULT_FG=${CURRENT_DEFAULT_FG:-'default'}
    ;;
esac

# Colors (same as agnoster defaults)
: ${AGNOSTER_DIR_FG:=${CURRENT_FG}}
: ${AGNOSTER_DIR_BG:=blue}
: ${AGNOSTER_GIT_CLEAN_FG:=${CURRENT_FG}}
: ${AGNOSTER_GIT_CLEAN_BG:=green}
: ${AGNOSTER_GIT_DIRTY_FG:=black}
: ${AGNOSTER_GIT_DIRTY_BG:=yellow}
: ${AGNOSTER_VENV_FG:=black}
: ${AGNOSTER_VENV_BG:=blue}
: ${AGNOSTER_STATUS_RETVAL_FG:=red}
: ${AGNOSTER_STATUS_ROOT_FG:=yellow}
: ${AGNOSTER_STATUS_JOB_FG:=cyan}
: ${AGNOSTER_STATUS_FG:=${CURRENT_DEFAULT_FG}}
: ${AGNOSTER_STATUS_BG:=black}

# Powerline separator
() {
  local LC_ALL="" LC_CTYPE="en_US.UTF-8"
  SEGMENT_SEPARATOR=$'\ue0b0'
}

### Segment drawing

prompt_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
    echo -n " %{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%} "
  else
    echo -n "%{$bg%}%{$fg%} "
  fi
  CURRENT_BG=$1
  [[ -n $3 ]] && echo -n $3
}

prompt_end() {
  if [[ -n $CURRENT_BG ]]; then
    echo -n " %{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR"
  else
    echo -n "%{%k%}"
  fi
  echo -n "%{%f%}"
  CURRENT_BG=''
}

### Prompt components

# Status: error, root, background jobs
prompt_status() {
  local -a symbols
  [[ $RETVAL -ne 0 ]] && symbols+="%{%F{$AGNOSTER_STATUS_RETVAL_FG}%}✘"
  [[ $UID -eq 0 ]] && symbols+="%{%F{$AGNOSTER_STATUS_ROOT_FG}%}⚡"
  [[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{$AGNOSTER_STATUS_JOB_FG}%}⚙"
  [[ -n "$symbols" ]] && prompt_segment "$AGNOSTER_STATUS_BG" "$AGNOSTER_STATUS_FG" "$symbols"
}

# Virtualenv / Conda
prompt_virtualenv() {
  if [[ -n "$CONDA_DEFAULT_ENV" ]]; then
    prompt_segment magenta $CURRENT_FG "🐍 $CONDA_DEFAULT_ENV"
  fi
  if [[ -n "$VIRTUAL_ENV" && -n "$VIRTUAL_ENV_DISABLE_PROMPT" ]]; then
    prompt_segment "$AGNOSTER_VENV_BG" "$AGNOSTER_VENV_FG" "(${VIRTUAL_ENV:t:gs/%/%%})"
  fi
}

# Dir: last 2 path components (e.g. apps/api instead of full path)
prompt_dir() {
  prompt_segment "$AGNOSTER_DIR_BG" "$AGNOSTER_DIR_FG" '%2~'
}

# Git: branch + dirty state, same output as agnoster.
# agnoster runs `git status` (parse_git_dirty) and then vcs_info, which runs
# `git diff`, `git diff-index` and several `rev-parse` calls: about 10 git
# processes per prompt. Here one `git status --porcelain=v2 --branch` gives
# the branch, the dirty state, and the staged and unstaged markers.
# Honors oh-my-zsh.hide-status, oh-my-zsh.hide-dirty (no status call, clean
# color, no markers), DISABLE_UNTRACKED_FILES_DIRTY and
# GIT_STATUS_IGNORE_SUBMODULES, like parse_git_dirty.
prompt_git() {
  (( $+commands[git] )) || return

  local repo_path
  repo_path=$(command git rev-parse --git-dir 2>/dev/null) || return

  local hide
  hide=$(command git config --get-regexp '^oh-my-zsh\.hide-(status|dirty)$' 2>/dev/null)
  [[ $'\n'$hide$'\n' == *$'\n'oh-my-zsh.hide-status\ 1$'\n'* ]] && return

  local PL_BRANCH_CHAR
  () {
    local LC_ALL="" LC_CTYPE="en_US.UTF-8"
    PL_BRANCH_CHAR=$'\ue0a0' # 
  }

  local ref out line dirty staged unstaged mode
  local -a flags=(--porcelain=v2 --branch)
  if [[ $'\n'$hide$'\n' == *$'\n'oh-my-zsh.hide-dirty\ 1$'\n'* ]]; then
    flags+=(--untracked-files=no)  # branch only; changes are not shown
  else
    [[ ${DISABLE_UNTRACKED_FILES_DIRTY:-} == true ]] && flags+=(--untracked-files=no)
    [[ ${GIT_STATUS_IGNORE_SUBMODULES:-} == git ]] \
      || flags+=(--ignore-submodules=${GIT_STATUS_IGNORE_SUBMODULES:-dirty})
  fi

  if out=$(command git status $flags 2>/dev/null); then
    for line in ${(f)out}; do
      case $line in
        '# branch.head (detached)') ;;
        '# branch.head '*) ref="refs/heads/${line#\# branch.head }" ;;
        '#'*) ;;
        [12]' '*)  # changed or renamed entry: "1 XY ...", X=index, Y=worktree
          dirty=1
          [[ ${line[3]} != . ]] && staged=1
          [[ ${line[4]} != . ]] && unstaged=1 ;;
        'u '*) dirty=1 staged=1 unstaged=1 ;;  # unmerged
        *) dirty=1 ;;  # untracked
      esac
    done
    # hide-dirty: --untracked-files=no still lists tracked changes; drop them
    [[ $'\n'$hide$'\n' == *$'\n'oh-my-zsh.hide-dirty\ 1$'\n'* ]] && dirty= staged= unstaged=
  else
    # No work tree (for example inside .git): branch only, as agnoster shows
    ref=$(command git symbolic-ref HEAD 2>/dev/null)
  fi
  # Detached HEAD (also during a rebase): agnoster shows `git describe`
  [[ -n $ref ]] || ref=$(command git describe --tags --always 2>/dev/null) || return

  if [[ -n $dirty ]]; then
    prompt_segment "$AGNOSTER_GIT_DIRTY_BG" "$AGNOSTER_GIT_DIRTY_FG"
  else
    prompt_segment "$AGNOSTER_GIT_CLEAN_BG" "$AGNOSTER_GIT_CLEAN_FG"
  fi

  # Detect rebase/merge/bisect mode
  if [[ -e "${repo_path}/BISECT_LOG" ]]; then
    mode=" <B>"
  elif [[ -e "${repo_path}/MERGE_HEAD" ]]; then
    mode=" >M<"
  elif [[ -e "${repo_path}/rebase" || -e "${repo_path}/rebase-apply" || -e "${repo_path}/rebase-merge" || -e "${repo_path}/../.dotest" ]]; then
    mode=" >R>"
  fi

  local markers=${unstaged:+±}${staged:+✚}
  echo -n "${${ref:gs/%/%%}/refs\/heads\//$PL_BRANCH_CHAR }${markers:+ $markers}${mode}"
}

## Main prompt
build_prompt() {
  RETVAL=$?
  prompt_status
  prompt_virtualenv
  prompt_dir
  prompt_git
  prompt_end
}

PROMPT='%{%f%b%k%}$(build_prompt) %(!.#.$) '
