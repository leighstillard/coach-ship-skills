#!/usr/bin/env bash
# PreToolUse hook for shell commands (Claude Code and Codex CLI share the contract).
# Refuses `gh pr merge` unless the command pins the commit it merges with
# --match-head-commit <40-char sha> and simplify, verify and review each left a marker
# for that commit: $(git rev-parse --git-common-dir)/ship/<sha>.{simplified,verified,reviewed}.
# gh itself refuses the merge when the PR head is no longer that commit, so the hook never
# has to work out which PR or repository the command means. A new commit has a new SHA
# and no markers.
# The checkout is the session's directory (.cwd), unless the command starts with
# `cd <path> &&` or `cd <path> ;` where <path> is literal (quoted or bare, no $ or backtick,
# relative to .cwd, ~/ meaning $HOME): then it is <path>. The pinned commit must exist there.
# Auto-merge is refused: it can land a later push that never passed the gates.
# Limit: on a merge queue branch gh enables auto-merge itself while required checks are
# pending; the hook cannot see branch protection, so babysit merges only on settled checks.
# Deliberate bypass, visible in the transcript: prefix the merge itself with SHIP_GATE=off
# (an assignment anywhere else, or in quoted text, does not count). A newline separates
# commands; a backslash-newline joins lines. A leading cd that cannot be read is refused.
# This reads the command as text, so it stops a forgotten gate, not a determined author:
# an alias, a script file, or a command built at run time gets past it. To keep the text
# honest it refuses anything it cannot read simply: a merge command with a comment, with
# more than one merge, or with more than one pin, or quoting it cannot pair (an escaped
# quote, an unclosed one). A quoted --subject/-t/--body/-b value is skipped unless it is
# double-quoted with a $(...) or backtick in it; other quoted text is read like the rest.
# Text that merely mentions "gh ... pr merge" is treated as a merge (refused, the safe side).
INPUT=$(cat)
Q="[\"']?"   # an optional quote around a word
FLAGS="([[:space:]]+-[^[:space:];&|]+([[:space:]]+[^-[:space:];&|][^[:space:];&|]*)?)*"   # pr -R o/r merge, pr -Ro/r merge, ...
PR_MERGE="${Q}pr$Q$FLAGS[[:space:]]+${Q}merge([^[:alnum:]_-]|\$)"
MERGE_CORE="gh$Q([[:space:]]+[^;&|]*)?[[:space:]]+$PR_MERGE"
MERGE_RE="(^|[^[:alnum:]_-])$MERGE_CORE"
ASSIGN="([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*"
if ! command -v jq >/dev/null; then
  RAW=${INPUT//\\n/ }; RAW=${RAW//\\/ }   # inside the JSON a continued line is a backslash pair and \n
  grep -qE "$MERGE_RE" <<<"$RAW" || exit 0
  echo "ship merge gate: jq is not installed, so this merge cannot be checked. Install jq, or prefix SHIP_GATE=off for a merge outside ship." >&2
  exit 2
fi
RAWCMD=$(jq -r '.tool_input.command // empty' <<<"$INPUT")
CMD=${RAWCMD//$'\\\n'/}; CMD=${CMD//$'\n'/;}; CMD=${CMD//\\/ }   # join continued lines; a newline separates commands
grep -qE "$MERGE_RE" <<<"$CMD" || exit 0
deny() { jq -n --arg r "ship merge gate: $1 Prefix SHIP_GATE=off only for a merge that is not going through ship." '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'; exit 0; }
UNREAD="the merge command has quoting this check cannot read; simplify it."
T=${RAWCMD//\\\\/}; [[ $T == *\\[\"\']* ]] && deny "$UNREAD"   # an escaped quote (an odd run of backslashes)
# CHK = CMD with each quoted --subject/-t/--body/-b value replaced by QUOTED; other quoted text stays readable
CHK=""; R=$CMD; QRE="^([^\"']*)([\"'])(.*)$"
while [[ $R =~ $QRE ]]; do
  CHK+=${BASH_REMATCH[1]}; q=${BASH_REMATCH[2]}; R=${BASH_REMATCH[3]}
  [[ $R == *"$q"* ]] || deny "$UNREAD"
  S=${R%%"$q"*}; R=${R#*"$q"}
  RUNS=""; [[ $q == '"' && ( $S == *'$('* || $S == *'`'* ) ]] && RUNS=1   # "$(...)" runs; keep it readable
  if [[ -z $RUNS && ( $CHK =~ (^|[[:space:]])(--subject|-t|--body|-b)(=|[[:space:]]+)\$?$ || $S =~ ^(--subject|-t|--body|-b)= ) ]]; then CHK+=QUOTED
  elif [[ $S =~ ^([0-9a-f]{40}|gh|pr|merge)$ ]]; then CHK=${CHK%\$}; CHK+=$S   # $'...' around a word is still that word
  else CHK+=$q$S$q; fi
done
CHK+=$R
[ "$(tr ';&|()`' '\n\n\n\n\n\n' <<<"$CHK" | grep -cE "$MERGE_RE")" -eq 1 ] || deny "more than one merge in one command. Run each merge as its own command."   # one per simple command, $(...) included
# the bypass counts only as a prefix of that one merge, read after quoted subjects are masked
grep -qE "(^|[;&|(])[[:space:]]*${ASSIGN}SHIP_GATE=off[[:space:]]+$ASSIGN([^[:space:];&|]*/)?$MERGE_CORE" <<<"$CHK" && exit 0
grep -q '#' <<<"$CHK" && deny "the merge command contains a # comment, which could hide a flag from this check. Run the merge without it."
[ "$(grep -o -- '--match-head-commit' <<<"$CHK" | wc -l)" -le 1 ] || deny "more than one --match-head-commit. Pin exactly one commit."
grep -q -- '--auto' <<<"$CHK" && deny "auto-merge can land a later commit that never passed the gates. Wait for the checks, then merge with --match-head-commit <sha>."
SHA=$(grep -oE -- '--match-head-commit[=[:space:]]+[0-9a-f]{40}' <<<"$CHK" | head -1 | grep -oE '[0-9a-f]{40}$')
[ -n "$SHA" ] || deny "the merge must pin its commit: add --match-head-commit followed by the literal 40-character SHA the gates passed on (not a \$(...) substitution, which the hook cannot read)."
DIR=$(jq -r '.cwd // empty' <<<"$INPUT"); DIR=${DIR:-$PWD}
# A first command `cd <literal path> &&` (or `;`) names the checkout instead of the session's.
DQ="\"([^\"\$\`]*)\""; SQ="'([^'\$\`]*)'"; BARE="([^\"'[:space:];&|\$\`]+)"
CD_RE="^[[:space:]]*${ASSIGN}cd[[:space:]]+($DQ|$SQ|$BARE)[[:space:]]*(&&|;)"
CD_ANY="^[[:space:]]*${ASSIGN}cd([[:space:];&]|\$)"
if [[ $CMD =~ $CD_ANY ]]; then
  [[ $CMD =~ $CD_RE ]] || deny "the cd target cannot be read by this check (a variable, substitution or ~user). Use an absolute path or ~/."
  P="${BASH_REMATCH[3]}${BASH_REMATCH[4]}${BASH_REMATCH[5]}"   # one of the three is set
  case "${BASH_REMATCH[5]}" in "~") P=$HOME ;; "~/"*) P=$HOME/${P#"~/"} ;; "~"*) P="" ;; esac   # bare ~ only; ~user is not read
  [ -n "$P" ] || deny "the cd target cannot be read by this check (~user or empty). Use an absolute path or ~/."
  [[ $P == /* ]] && DIR=$P || DIR=$DIR/$P
fi
GD=$(git -C "$DIR" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || deny "$DIR is not a git checkout, so no markers can be checked. Run the merge from the checkout the gates ran in."
git -C "$DIR" cat-file -e "$SHA^{commit}" 2>/dev/null || deny "commit ${SHA:0:12} is not in $DIR. Run the merge from the checkout the gates ran in, or start the command with cd <that checkout> &&."
MISSING=""
for g in simplified verified reviewed; do [ -e "$GD/ship/$SHA.$g" ] || MISSING="$MISSING $g"; done
[ -z "$MISSING" ] && exit 0
deny "commit ${SHA:0:12} has no marker for:$MISSING. Re-run those gates on this commit; each writes \$(git rev-parse --git-common-dir)/ship/<sha>.<gate> when it ends green (ship, Merge markers)."
