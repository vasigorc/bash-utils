#!/usr/bin/env bash
# scratch-repo.sh DIR: make a tiny git repo to test the role agents.
#
# The repo has a Python module with stdlib tests, an AGENTS.md that names the
# checks, and a Claude Code allowlist for the orchestrator commands.
set -euo pipefail

dir=${1:?usage: scratch-repo.sh DIR}
[[ ! -e $dir ]] || { echo "scratch-repo: $dir exists" >&2; exit 1; }
mkdir -p "$dir/.claude"
cd "$dir"
git init -q

cat >slug.py <<'EOF'
"""Small text helpers."""


def collapse_spaces(text):
    """Return text with runs of whitespace collapsed to one space."""
    return " ".join(text.split())
EOF

cat >test_slug.py <<'EOF'
import unittest

from slug import collapse_spaces


class CollapseSpacesTest(unittest.TestCase):
    def test_collapses_runs_of_whitespace(self):
        self.assertEqual(collapse_spaces("a  b\t\nc"), "a b c")

    def test_strips_leading_and_trailing_whitespace(self):
        self.assertEqual(collapse_spaces("  a  "), "a")


if __name__ == "__main__":
    unittest.main()
EOF

cat >AGENTS.md <<'EOF'
# scratch repo

A tiny Python module with stdlib tests.

- Checks: `python3 -m unittest -q` (run from the repo root).
- Do not commit. The user commits.
- Work on the branch that is checked out.
EOF

cat >.gitignore <<'EOF'
__pycache__/
EOF

cat >.claude/settings.json <<'EOF'
{
  "permissions": {
    "allow": [
      "Bash(herdr agent:*)",
      "Bash(herdr --skill)",
      "Bash(agent-role:*)",
      "Bash(printenv:*)",
      "Bash(git diff:*)",
      "Bash(git status:*)",
      "Bash(git ls-files:*)",
      "Bash(python3 -m unittest:*)",
      "Bash(python3 -c:*)"
    ]
  }
}
EOF

git add . && git -c user.name=scratch -c user.email=scratch@example.com commit -qm init
python3 -m unittest -q
echo "scratch-repo: ready in $dir"
