#!/usr/bin/env bash
# watch-checks.sh <pr-number> [interval-seconds] [max-wait-seconds]
# Polls `gh pr checks` until the checks settle. Exit: 0 all passed, 1 a check
# failed, 2 usage or query error (message printed), 3 no checks reported yet,
# 4 still pending after max-wait (default 1800). Never maps an error to an
# empty or passing result.
set -u
[ $# -ge 1 ] || { echo 'usage: watch-checks.sh <pr-number> [interval-seconds] [max-wait-seconds]' >&2; exit 2; }
n=$1
interval=${2:-90}
deadline=$(( $(date +%s) + ${3:-1800} ))
while :; do
  out=$(gh pr checks "$n" 2>&1)
  rc=$?
  case $rc in
    0) printf '%s\nchecks: all passed\n' "$out"; exit 0 ;;
    1) # gh also exits 1 when the PR has no checks at all; that is not a failure
       if grep -q 'no checks reported' <<<"$out"; then echo 'checks: none reported'; exit 3; fi
       printf '%s\nchecks: failed\n' "$out"; exit 1 ;;
    8) [ "$(date +%s)" -lt "$deadline" ] || { printf '%s\nchecks: still pending at the deadline\n' "$out"; exit 4; }
       echo "checks: pending ($(date +%T))"; sleep "$interval" ;;
    *) printf 'gh pr checks exited %s:\n%s\n' "$rc" "$out" >&2; exit 2 ;;
  esac
done
