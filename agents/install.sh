#!/usr/bin/env bash
# install.sh: link the agent tools from this repo into your home directory.
#
# Usage: agents/install.sh [--dry-run] [--uninstall]
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

# Each entry: source in the repo | link | directory that must exist (or "-").
links=(
  "agents/bin/agent-role|$HOME/.local/bin/agent-role|-"
  "agents/skills/orchestrate|$HOME/.pi/agent/skills/orchestrate|$HOME/.pi/agent"
  "agents/skills/orchestrate|$HOME/.claude/skills/orchestrate|$HOME/.claude"
  "terminals/herdr/herdr.zsh|$zsh_custom/herdr.zsh|$zsh_custom"
)

link() { # source link
  local src=$repo/$1 dst=$2
  if [[ ! -e $src ]]; then
    say "missing  $src is not in the repo. Nothing linked for $dst"
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
  local src=$repo/$1 dst=$2
  if [[ -L $dst && $(readlink "$dst") == "$src" ]]; then
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
