#!/usr/bin/env bash
# Unit tests of the async reply extensions (no model, a fake Pi API).
set -euo pipefail
command -v node >/dev/null || { echo "SKIP: node is not installed"; exit 0; }
exec node "$(dirname "${BASH_SOURCE[0]}")/async-extensions.mjs"
