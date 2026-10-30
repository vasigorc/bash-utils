#!/usr/bin/env bash
# install.sh: copy the agent tools from this repo into an install directory,
# and link them into your home directory from there.
#
# Usage: agents/install.sh [--dry-run] [--uninstall]
#
# The links never point into the repo, so edits, pulls and branch switches in
# the repo do not change the live tools. Run the script again to sync the
# install directory (rsync --delete). The copy keeps the repo layout:
# agent-role finds ../roles and herdr.zsh finds ../../agents from there.
#
# Install directory: $AGENT_ROLES_HOME, default ~/.local/share/agent-roles.
# The copy never includes roles/config.example.json, pi/ or test/. The
# machine config (~/.config/agent-roles/config.json) is not in the copy.
#
# Local overlay: $AGENT_ROLES_OVERLAY, default ~/.config/agent-roles/local.
# It has the repo layout (for example agents/roles/<role>.md). The script
# copies it over the install directory after each sync, so local-only files
# stay live and are never in the repo. An overlay file replaces the repo file
# with the same path; the script prints each one.
#
# The script finds the repo from its own location, so the repo can live
# anywhere and have any name. You can run it more than one time. It replaces
# only its own links, and it backs up a real file that is in the way.
#
# It never changes ~/.zshrc. If oh-my-zsh is installed, it links herdr.zsh into
# $ZSH_CUSTOM, which oh-my-zsh loads. If not, it prints the line to add.
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
dry=0 uninstall=0
for arg in "$@"; do
  case $arg in
    --dry-run) dry=1 ;;
    --uninstall) uninstall=1 ;;
    -h | --help) sed -n '2,/^set -euo/{/^set -euo/d;s/^# \{0,1\}//;p;}' "$0"; exit 0 ;;
    *) echo "install.sh: unknown option: $arg" >&2; exit 1 ;;
  esac
done

run() { if ((dry)); then printf '  + %s\n' "$*"; else "$@"; fi; }
say() { printf '%s\n' "$*"; }

zsh_custom=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}
config=${XDG_CONFIG_HOME:-$HOME/.config}/agent-roles/config.json
dest=${AGENT_ROLES_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/agent-roles}
excludes=(--exclude .git --exclude .DS_Store
  --exclude /roles/config.example.json --exclude /pi/ --exclude /test/)
overlay=${AGENT_ROLES_OVERLAY:-${config%/*}/local}

if ((!uninstall)); then
  command -v rsync >/dev/null || { say "missing  rsync"; exit 1; }
  run mkdir -p "$dest/agents" "$dest/terminals/herdr"
  run rsync -a --delete "${excludes[@]}" "$repo/agents/" "$dest/agents/"
  run rsync -a --delete "$repo/terminals/herdr/herdr.zsh" "$dest/terminals/herdr/"
  say "synced   $dest from $repo"
  if [[ -d $overlay ]]; then
    run rsync -a --exclude .DS_Store --exclude '*.patch' "$overlay/" "$dest/"
    while IFS= read -r f; do
      if [[ -e $repo/$f ]]; then say "overlay  $f (replaces the repo file)"
      else say "overlay  $f"; fi
    done < <(cd "$overlay" && find . -type f ! -name .DS_Store ! -name '*.patch' | sed 's|^\./||' | sort)
  fi
fi

# Each entry: source in the repo | link | directory that must exist (or "-").
links=(
  "agents/bin/agent-role|$HOME/.local/bin/agent-role|-"
  "agents/skills/orchestrate|$HOME/.pi/agent/skills/orchestrate|$HOME/.pi/agent"
  "agents/skills/orchestrate|$HOME/.claude/skills/orchestrate|$HOME/.claude"
  "terminals/herdr/herdr.zsh|$zsh_custom/herdr.zsh|$zsh_custom"
)

link() { # source link
  local src=$dest/$1 dst=$2
  # In a dry run the copy can be missing, so check the repo source instead.
  if [[ ! -e $src ]] && ! { ((dry)) && [[ -e $repo/$1 ]]; }; then
    say "missing  $src is not in the install copy. Nothing linked for $dst"
    return
  fi
  if [[ -L $dst && $(readlink "$dst") == "$src" ]]; then
    say "ok       $dst"
    return
  fi
  if [[ -L $dst ]]; then
    say "relink   $dst (was -> $(readlink "$dst"))"
    run rm "$dst"
  elif [[ -e $dst ]]; then
    local backup
    backup=$dst.bak.$(date +%Y%m%d%H%M%S)
    say "backup   $dst -> $backup"
    run mv "$dst" "$backup"
  fi
  run mkdir -p "$(dirname "$dst")"
  run ln -s "$src" "$dst"
  say "linked   $dst -> $src"
}

unlink_own() { # source link
  local dst=$2
  if [[ -L $dst && ( $(readlink "$dst") == "$dest/$1" ||
    $(readlink "$dst") == "$repo/$1" ) ]]; then
    run rm "$dst"
    say "removed  $dst"
  fi
}

for entry in "${links[@]}"; do
  IFS='|' read -r src dst need <<<"$entry"
  if ((uninstall)); then
    unlink_own "$src" "$dst"
  elif [[ $need == - || -d $need ]]; then
    link "$src" "$dst"
  elif [[ $src == terminals/herdr/herdr.zsh ]]; then
    say "skipped  $dst (no oh-my-zsh). Add this line to ~/.zshrc:"
    say "           source $repo/terminals/herdr/herdr.zsh"
  else
    say "skipped  $dst ($need does not exist)"
  fi
done

if ((uninstall)); then
  say "kept     $config (machine config; remove it yourself if you want)"
  exit 0
fi

if [[ -e $config ]]; then
  say "ok       $config (kept)"
else
  run mkdir -p "$(dirname "$config")"
  run cp "$repo/agents/roles/config.example.json" "$config"
  say "created  $config. Edit the presets and extensions for this machine."
fi

# Checks only. The script installs none of these.
for cmd in herdr jq pi; do
  command -v "$cmd" >/dev/null || say "missing  $cmd (see terminals/herdr/1-HerdrTmuxMigration.md)"
done
command -v claude >/dev/null || say "note     claude not found; only a Pi orchestrator is possible"
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) say "warning  ~/.local/bin is not on PATH, so agent-role is not found" ;;
esac
if command -v herdr >/dev/null; then
  say "check    herdr integration status (pi and claude must be current):"
  herdr integration status 2>/dev/null | grep -E '^(pi|claude):' | sed 's/^/           /' || true
fi
