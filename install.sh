#!/usr/bin/env bash
# install.sh [claude|codex]   (default: claude)
set -euo pipefail

AGENT="${1:-claude}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$AGENT" in
  claude) DEST="${CLAUDE_HOME:-$HOME/.claude}" ;;
  codex)  DEST="${CODEX_HOME:-$HOME/.codex}" ;;
  *) echo "usage: install.sh [claude|codex]" >&2; exit 2 ;;
esac

# The merge gate cannot run without jq, and the Codex hook config is written with it.
command -v jq >/dev/null || { echo "install.sh: jq is required (the merge gate uses it). Install jq and run this again." >&2; exit 1; }

install_file() {
  mkdir -p "$(dirname "$2")"
  cp "$1" "$2"
  printf 'installed %s\n' "$2"
}

# Replaces the whole skill directory, so a file removed upstream does not linger.
# An existing directory of the same name is moved aside first, never deleted: it may
# be the user's own skill.
BACKUP="$DEST/skills-backup-$(date +%Y%m%d-%H%M%S)"
install_dir() {
  if [ -e "$2" ]; then
    mkdir -p "$BACKUP"
    mv "$2" "$BACKUP/"
  fi
  mkdir -p "$(dirname "$2")"
  cp -R "$1" "$2"
  printf 'installed %s\n' "$2"
}

for skill in "$REPO_ROOT/$AGENT/skills"/*/; do
  install_dir "${skill%/}" "$DEST/skills/$(basename "$skill")"
done

if [ "$AGENT" = claude ]; then
  install_file "$REPO_ROOT/claude/commands/coach.md" "$DEST/commands/coach.md"
  for agent in "$REPO_ROOT"/claude/agents/*.md; do
    install_file "$agent" "$DEST/agents/$(basename "$agent")"
  done
fi

install_file "$REPO_ROOT/hooks/ship-merge-gate.sh" "$DEST/hooks/ship-merge-gate.sh"
chmod +x "$DEST/hooks/ship-merge-gate.sh"

echo
[ -d "$BACKUP" ] && echo "Previous copies of the replaced skills were moved to $BACKUP. Delete it once you have checked nothing of yours was in there."
if [ "$AGENT" = codex ]; then
  if [ ! -e "$DEST/hooks.json" ]; then
    # The shipped config names $HOME/.codex; write the directory actually installed into,
    # shell-escaped so a path with spaces or $ still runs.
    jq --arg c "$(printf '%q' "$DEST/hooks/ship-merge-gate.sh")" \
      '.hooks.PreToolUse[0].hooks[0].command = $c' "$REPO_ROOT/hooks/codex-hooks.json" > "$DEST/hooks.json.new"
    mv "$DEST/hooks.json.new" "$DEST/hooks.json"
    printf 'installed %s\n' "$DEST/hooks.json"
  else
    echo "Merge gate: $DEST/hooks.json already exists. Add the PreToolUse entry from hooks/codex-hooks.json to it by hand, with the command set to $DEST/hooks/ship-merge-gate.sh."
  fi
  echo "Then start codex, run /hooks, and trust the new hook. Codex skips a hook until you do."
else
  echo "Merge gate: add the PreToolUse entry from hooks/claude-settings.snippet.json to $DEST/settings.json, with the command set to $DEST/hooks/ship-merge-gate.sh."
  echo "Start a new Claude Code session so commands, agents, and skills are reloaded."
fi
