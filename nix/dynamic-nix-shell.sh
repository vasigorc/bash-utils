#!/bin/bash

# Get the directory where the script resides
script_dir="$(dirname "$(readlink -f "$0")")"

nixos_commit=$("$script_dir/get_nixos_commit.sh")

# Get a pinned nixpgs version
nixpkgs_url="https://github.com/NixOS/nixpkgs/archive/$nixos_commit.tar.gz"

# Collect Nix module names from arguments
nix_modules=("$@")

# Generate a unique temporary file name using timestamp, milliseconds and PID
timestamp=$(date +%s%3N)
pid=$$
nix_shell_combined="$script_dir/._nix_shell_${timestamp}_${pid}.nix"

# Create the combined shell
{
  echo "{ pkgs ? import (fetchTarball \"$nixpkgs_url\") {} }:"
  echo "let"
  for nix_module in "${nix_modules[@]}"; do
    echo "    $nix_module = import $script_dir/$nix_module-module.nix { inherit pkgs; };"
  done
  echo "in"
  echo "pkgs.mkShell {"
  echo -n "  buildInputs = "
  for i in "${!nix_modules[@]}"; do
    echo -n "${nix_modules[$i]}.buildInputs"
    if [ $i -lt $((${#nix_modules[@]} - 1)) ]; then
      echo -n " ++ "
    fi
  done
  echo ";" # Close buildInputs

  # Handle shellHook
  echo -n "  shellHook = "
  for i in "${!nix_modules[@]}"; do
    echo -n "${nix_modules[$i]}.shellHook"
    if [ $i -lt $((${#nix_modules[@]} - 1)) ]; then
      echo -n " + "
    fi
  done
  echo ";" # Close shellHook

  echo "}"
} >"$nix_shell_combined"

# Set up portable environment variables only if default module is included
if [[ " ${nix_modules[@]} " =~ " default " ]]; then
  echo "Setting up zsh environment for default module..."
  export NIX_BUILD_SHELL="$HOME/.oh-my-zsh/custom/plugins/nix-shell/scripts/buildShellShim"
  export SHELL="$HOME/.oh-my-zsh/custom/plugins/nix-shell/scripts/buildShellShim"
  export PATH="$PATH:$HOME/.oh-my-zsh/custom/plugins/nix-shell/scripts"
fi

# Launch nix-shell
nix-shell "$nix_shell_combined"

# Clean up
rm "$nix_shell_combined"
