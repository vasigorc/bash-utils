#!/usr/bin/env bash

script_dir="$(dirname "$(readlink -f "$0")")"

version_file="$script_dir/NIXOS_VERSION"

if [ ! -f $version_file ]; then
    echo "Error: NIXOS_VERSION file not found"
    exit 1
fi

NIXOS_VERSION="$(awk -F = '/NIXOS_VERSION/ { print $2 }' "$version_file")"

if [ -z "$NIXOS_VERSION" ]; then
    echo "Error: Could not read NIXOS_VERSION from file"
    exit 1
fi

CHANNEL_URL="https://nixos.org/channels/nixos-${NIXOS_VERSION}/git-revision"

get_latest_commit() {
    curl -L "$CHANNEL_URL" 2>/dev/null | tr -d '\n'
}

latest_commit=$(get_latest_commit)

if [ -z "$latest_commit" ]; then
    echo "Error: Failed to fetch the latest commit"
    exit 1
fi

echo "$latest_commit"