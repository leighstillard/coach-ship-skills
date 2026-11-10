#!/usr/bin/env bash
# PreToolUse hook for shell commands (Claude Code and Codex CLI share the contract).
# Refuses `gh pr merge` unless the command pins the commit it merges with
# --match-head-commit <40-char sha> and simplify, verify and review each left a marker
# for that commit: $(git rev-parse --git-common-dir)/ship/<sha>.{simplified,verified,reviewed}.
# gh itself refuses the merge when the PR head is no longer that commit, so the hook never
# has to work out which PR or repository the command means. A new commit has a new SHA
# and no markers.
# Auto-merge is refused: it can land a later push that never passed the gates.
# Deliberate bypass, visible in the transcript: prefix the command with SHIP_GATE=off.
# This reads the command as text, so it stops a forgotten gate, not a determined author:
# an alias, a script file, or a command built at run time gets past it. To keep the text
# honest it refuses anything it cannot read simply: a merge command with a comment, with
# more than one merge, or with more than one pin. Text that merely mentions
# "gh ... pr merge" is treated as a merge (refused, the safe side).
INPUT=$(cat)
Q="[\"']?"   # an optional quote around a word
MERGE_RE="(^|[^[:alnum:]_-])gh$Q([[:space:]]+[^;&|]*)?[[:space:]]+${Q}pr$Q[[:space:]]+${Q}merge([^[:alnum:]_-]|\$)"
if ! command -v jq >/dev/null; then
  RAW=${INPUT//\\n/ }; RAW=${RAW//\\/ }   # inside the JSON a continued line is a backslash pair and \n
  grep -qE "$MERGE_RE" <<<"$RAW" || exit 0
  echo "ship merge gate: jq is not installed, so this merge cannot be checked. Install jq, or prefix SHIP_GATE=off for a merge outside ship." >&2
  exit 2
fi
CMD=$(jq -r '.tool_input.command // empty' <<<"$INPUT" | tr '\\\n' '  ')   # join continued lines
grep -qE "$MERGE_RE" <<<"$CMD" || exit 0
grep -qE '(^|[[:space:];&|])SHIP_GATE=off[[:space:]]' <<<"$CMD" && exit 0
deny() { jq -n --arg r "ship merge gate: $1 Prefix SHIP_GATE=off only for a merge that is not going through ship." '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'; exit 0; }
[ "$(grep -oE "pr$Q[[:space:]]+${Q}merge" <<<"$CMD" | wc -l)" -eq 1 ] || deny "more than one merge in one command. Run each merge as its own command."
grep -q '#' <<<"$CMD" && deny "the merge command contains a # comment, which could hide a flag from this check. Run the merge without it."
[ "$(grep -o -- '--match-head-commit' <<<"$CMD" | wc -l)" -le 1 ] || deny "more than one --match-head-commit. Pin exactly one commit."
grep -q -- '--auto' <<<"$CMD" && deny "auto-merge can land a later commit that never passed the gates. Wait for the checks, then merge with --match-head-commit <sha>."
SHA=$(grep -oE -- '--match-head-commit[=[:space:]]+"?[0-9a-f]{40}' <<<"$CMD" | head -1 | grep -oE '[0-9a-f]{40}$')
[ -n "$SHA" ] || deny "the merge must pin its commit: add --match-head-commit followed by the literal 40-character SHA the gates passed on (not a \$(...) substitution, which the hook cannot read)."
DIR=$(jq -r '.cwd // empty' <<<"$INPUT"); DIR=${DIR:-$PWD}
GD=$(git -C "$DIR" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || deny "$DIR is not a git checkout, so no markers can be checked. Run the merge from the checkout the gates ran in."
MISSING=""
for g in simplified verified reviewed; do [ -e "$GD/ship/$SHA.$g" ] || MISSING="$MISSING $g"; done
[ -z "$MISSING" ] && exit 0
deny "commit ${SHA:0:12} has no marker for:$MISSING. Re-run those gates on this commit; each writes \$(git rev-parse --git-common-dir)/ship/<sha>.<gate> when it ends green (ship, Merge markers)."
