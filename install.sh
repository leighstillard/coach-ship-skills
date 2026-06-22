#!/usr/bin/env bash
set -euo pipefail

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$CLAUDE_HOME/commands" "$CLAUDE_HOME/agents" "$CLAUDE_HOME/skills"

install_file() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  printf 'installed %s
' "$dst"
}

install_dir() {
  local src="$1"
  local dst="$2"
  rm -rf "$dst"
  mkdir -p "$(dirname "$dst")"
  cp -R "$src" "$dst"
  printf 'installed %s
' "$dst"
}

install_file "$REPO_ROOT/commands/coach.md" "$CLAUDE_HOME/commands/coach.md"
for agent in writer tester verifier reviewer; do
  install_file "$REPO_ROOT/agents/$agent.md" "$CLAUDE_HOME/agents/$agent.md"
done
for skill in ship verify design-check pr babysit simplify; do
  install_dir "$REPO_ROOT/skills/$skill" "$CLAUDE_HOME/skills/$skill"
done

cat <<EOF

Coach & Ship skills installed into: $CLAUDE_HOME
Start a new Claude Code session so commands, agents, and skills are reloaded.
EOF
