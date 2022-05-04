#!/usr/bin/env bash

# this is a sample script that performs the following:
# 1. Makes sure that at least one argument is provided to the script
# 2. Read a file 'testFile.txt' in the same directory as the script
# 3. Filter out the lines from the file that do not match the first argument to the script
# 4. Keep only the fourth (space separated) column in each line
# 5. Reverse sorts the remainder of the line
# 6. Prints the most recent line if any or exits with an error

set -eo pipefail

BASENAME=$(basename "$0")

usage() {
  cat <<EOM
Usage:
  $BASENAME filter_prefix
EOM
  exit 0
}

if [[ $# -lt 1 ]]; then
  usage
fi

FILTER_PREFIX="$1"

declare -a initialArray

mapfile -t initialArray < testFile.txt

for (( i = 0; i < ${#initialArray[@]}; i++ )); do
  line_value=${initialArray[i]}
  if [[ "$line_value" == *"$FILTER_PREFIX"* ]]; then
    initialArray[i]=$(echo "$line_value" | tr -s ' ' | cut -d ' ' -f 4)
  fi
done

readarray -t sortedArray < <(for a in "${initialArray[@]}"; do echo "$a"; done | sort -r)

if [[ ${#sortedArray[@]} -eq 0 ]]; then
  echo "No valid entries in testFile.txt"
  exit 1
else
  echo "Most recent value is ${sortedArray[0]}"
fi
