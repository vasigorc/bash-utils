#!/usr/bin/env bash

NIXOS_VERSION="24.11"  # Can be changed when new stable versions come out
CHANNEL_URL="https://nixos.org/channels/nixos-${NIXOS_VERSION}/git-revision"

get_latest_commit() {
    curl -L "$CHANNEL_URL" 2>/dev/null | tr -d '\n'
}

latest_commit=$(get_latest_commit)

if [ -z "$latest_commit" ]; then
    echo "Error: Failed to fetch the latest commit"
    exit 1
fi

new_url="https://github.com/NixOS/nixpkgs/archive/${latest_commit}.tar.gz"

echo "Current directory contents:"
echo "Finding Nix files to update..."
find . -name "*.nix" ! -name "*module*.nix" -type f | while read -r file; do
    echo "Found: $file"
done

# Ask for confirmation
read -p "Do you want to update these files to use nixos-${NIXOS_VERSION} (commit: ${latest_commit})? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    # Update each file
    find . -name "*.nix" ! -name "*module*.nix" -type f | while read -r file; do
        echo "Updating $file..."
        perl -i -pe "s|archive/[a-f0-9]+\.tar\.gz|archive/${latest_commit}.tar.gz|g" "$file"
    done
    echo "Updated Nix files to use commit ${latest_commit}"
    
    # Verify the changes
    echo -e "\nVerifying changes:"
    find . -name "*.nix" ! -name "*module*.nix" -type f | while read -r file; do
        echo -e "\n$file contains:"
        grep -A 1 "fetchTarball" "$file"
    done
fi
