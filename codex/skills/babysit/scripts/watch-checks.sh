#!/usr/bin/env bash
# watch-checks.sh <pr-number> [interval-seconds]
# Polls `gh pr checks` until the checks settle. Exit: 0 all passed, 1 a check
# failed, 2 usage or query error (message printed). Never maps an error to an
# empty or passing result.
set -u
[ $# -ge 1 ] || { echo 'usage: watch-checks.sh <pr-number> [interval-seconds]' >&2; exit 2; }
n=$1
interval=${2:-90}
while :; do
  out=$(gh pr checks "$n" 2>&1)
  rc=$?
  case $rc in
    0) printf '%s\nchecks: all passed\n' "$out"; exit 0 ;;
    1) printf '%s\nchecks: failed\n' "$out"; exit 1 ;;
    8) echo "checks: pending ($(date +%T))"; sleep "$interval" ;;
    *) printf 'gh pr checks exited %s:\n%s\n' "$rc" "$out" >&2; exit 2 ;;
  esac
done
