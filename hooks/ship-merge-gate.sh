#!/usr/bin/env bash
# Refuses `gh pr merge` unless verify, simplify and review each left a marker
# for the PR's head commit: $(git rev-parse --git-common-dir)/ship/<sha>.{verified,simplified,reviewed}.
# The SHA is the PR's headRefOid when the command names a PR (number or URL), so a
# merge of a worktree's PR from the main checkout checks the right commit;
# with no PR named it is the checkout's HEAD. A new commit changes the SHA, so old
# markers stop counting.
# Deliberate bypass, visible in the transcript: prefix the command with SHIP_GATE=off.
# Known limit: the PR number is the first bare number or /pull/N after `merge`; a number
# inside a flag value (--subject "fix 3") is misread, and the wrong SHA is refused (safe side).
command -v jq >/dev/null || exit 0
INPUT=$(cat)
CMD=$(jq -r '.tool_input.command // empty' <<<"$INPUT")
# gh in command position: line start or after ; & | ( , optionally behind rtk or VAR=val
grep -qE '(^|[;&|(])[[:space:]]*(rtk[[:space:]]+)?([A-Za-z_]+=[^[:space:]]*[[:space:]]+)*gh[[:space:]]+pr[[:space:]]+merge' <<<"$CMD" || exit 0
grep -qE '(^|[[:space:];&|])SHIP_GATE=off[[:space:]]' <<<"$CMD" && exit 0
DIR=$(jq -r '.cwd // empty' <<<"$INPUT"); DIR=${DIR:-$PWD}
deny() { jq -n --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'; exit 0; }
GD=$(git -C "$DIR" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || deny "ship merge gate: $DIR is not a git checkout, so no markers can be checked. Run the merge from a checkout of the repo, or prefix SHIP_GATE=off if this merge is outside /ship."
REST=$(grep -oE 'gh[[:space:]]+pr[[:space:]]+merge[^;&|]*' <<<"$CMD" | head -1)
PR=$(grep -oE '(^|[[:space:]]|/pull/)[0-9]+([[:space:]]|$)' <<<"${REST#*merge}" | head -1 | tr -dc 0-9)
if [ -n "$PR" ]; then
  SHA=$(cd "$DIR" && gh pr view "$PR" --json headRefOid -q .headRefOid 2>&1) || deny "ship merge gate: could not read PR #$PR's head commit (gh: $SHA). Check gh auth and the PR number, or prefix SHIP_GATE=off if this merge is outside /ship."
else
  SHA=$(git -C "$DIR" rev-parse HEAD)
fi
MISSING=""
for g in verified simplified reviewed; do [ -e "$GD/ship/$SHA.$g" ] || MISSING="$MISSING $g"; done
[ -z "$MISSING" ] && exit 0
WHAT=HEAD; [ -n "$PR" ] && WHAT="PR #$PR head"
deny "ship merge gate: $WHAT ${SHA:0:12} has no marker for:$MISSING. Re-run those gates on this commit; each writes \$(git rev-parse --git-common-dir)/ship/<sha>.<gate> when it ends green (ship, Merge markers). Prefix SHIP_GATE=off only for a merge that is not going through /ship."
