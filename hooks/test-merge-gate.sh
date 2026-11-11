#!/usr/bin/env bash
# Runs ship-merge-gate.sh against a table of commands in a throwaway repo.
# Usage: hooks/test-merge-gate.sh   (exit 0 when every case matches)
set -u
H="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ship-merge-gate.sh"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
git init -q "$T/r"; cd "$T/r" || exit 1
git -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m one
OLD=$(git rev-parse HEAD)
m="$(git rev-parse --path-format=absolute --git-common-dir)/ship"; mkdir -p "$m"
touch "$m/$OLD.simplified" "$m/$OLD.verified" "$m/$OLD.reviewed"
git -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m two
NEW=$(git rev-parse HEAD)   # no markers
git init -q "$T/b"; git -C "$T/b" -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m b
SHB=$(git -C "$T/b" rev-parse HEAD); mb="$T/b/.git/ship"; mkdir -p "$mb"
touch "$mb/$SHB.simplified" "$mb/$SHB.verified" "$mb/$SHB.reviewed"
ln -s "$T/b" "$T/b c"   # the same repo B under a path with a space
fail=0
check() { # <want: allow|deny> <command>
  out=$(jq -n --arg c "$2" --arg d "$PWD" '{tool_name:"Bash",cwd:$d,tool_input:{command:$c}}' | bash "$H")
  got=allow; grep -q '"deny"' <<<"$out" && got=deny
  [ "$got" = "$1" ] && printf 'ok   %-5s %s\n' "$got" "$2" || { printf 'FAIL want %s got %s: %s\n' "$1" "$got" "$2"; fail=1; }
}
check allow "git status"
check allow "gh pr view 3"
check allow "gh pr merge 3 --squash --match-head-commit $OLD"
check allow "gh pr merge --squash --match-head-commit=$OLD"
check deny  "gh pr merge 3 --squash --match-head-commit $NEW"
check deny  "gh pr merge 3 --squash"
check deny  "gh pr merge"
check deny  "gh pr merge 3 --squash --match-head-commit \"\$(git rev-parse HEAD)\""
check deny  "gh pr merge 3 --auto --squash --match-head-commit $OLD"
check deny  "gh --repo owner/repo pr merge 3 --squash"
check deny  "command gh pr merge 3"
check deny  "cd /tmp && /usr/bin/gh pr merge https://github.com/o/r/pull/42 --merge"
check deny  "FOO=1 gh pr merge 3"
check allow "SHIP_GATE=off gh pr merge 3 --squash"
check allow "gh --repo owner/repo pr merge 3 --squash --match-head-commit $OLD"
check deny  "gh pr merge 3 --squash # --match-head-commit $OLD"
check deny  "gh pr merge 3 --squash '--auto' --match-head-commit $OLD"
check deny  "'gh' pr merge 3 --squash"
check deny  "gh pr merge 3 --match-head-commit $OLD && gh pr merge 4"
check deny  "gh pr merge 3 --match-head-commit $OLD --match-head-commit $NEW"
check deny  "gh pr \\
  merge 3 --squash"
check allow "gh pr \\
  merge 3 --squash --match-head-commit $OLD"
# quoted --subject/--body values are skipped; other quoted text is still read
check allow "gh pr merge 3 --squash --subject \"Fix #12 (pr merge --auto)\" --match-head-commit $OLD"
check allow "gh pr merge 3 --squash -b 'see #4; --auto is off' --match-head-commit $OLD"
check deny  "gh pr merge 3 --squash --subject \"x --match-head-commit $OLD\""
check allow "gh pr merge 3 --squash --match-head-commit \"$OLD\""
check allow "gh pr merge 3 --squash --match-head-commit '$OLD'"
check deny  "gh pr merge 3 --squash --subject \"a \\\" b\" --match-head-commit $OLD"
check deny  "gh pr merge 3 --squash --subject \"unclosed --match-head-commit $OLD"
check deny  "gh pr merge 3 --squash --match-head-commit $OLD; sh -c \"gh pr merge 4\""
check deny  "gh pr merge 3 --squash --match-head-commit $OLD \"--auto\""
# repo B, gated, merged from a session in repo A
check allow "cd $T/b && gh pr merge 1 --squash --match-head-commit $SHB"
check allow "cd \"$T/b c\" && gh pr merge 1 --squash --match-head-commit $SHB"
check allow "cd ../b && gh pr merge 1 --squash --match-head-commit $SHB"
check allow "FOO=1 cd '../b c'; gh pr merge 1 --squash --match-head-commit $SHB"
check deny  "gh pr merge 1 --squash --match-head-commit $SHB"
check deny  "cd \$HOME/x && gh pr merge 1 --squash --match-head-commit $SHB"
check deny  "git status && cd $T/b && gh pr merge 1 --squash --match-head-commit $SHB"
out=$(jq -n --arg c "gh pr merge 1 --squash --match-head-commit $SHB" --arg d "$PWD" '{tool_name:"Bash",cwd:$d,tool_input:{command:$c}}' | bash "$H")
grep -q 'is not in' <<<"$out" && echo "ok   pin from another repo names 'is not in'" || { echo "FAIL pin from another repo: $out"; fail=1; }
cd "$T" || exit 1   # not a git checkout
check deny  "gh pr merge 3 --squash --match-head-commit $OLD"
# without jq: a merge is blocked with exit 2, anything else passes
nojq=$(mktemp -d); for b in bash cat grep git; do ln -s "$(command -v $b)" "$nojq/$b"; done
printf '%s' '{"tool_input":{"command":"gh pr merge 3"}}' | PATH="$nojq" bash "$H" 2>/dev/null; [ $? -eq 2 ] && echo "ok   no jq: merge blocked (exit 2)" || { echo "FAIL no jq: merge not blocked"; fail=1; }
printf '%s' '{"tool_input":{"command":"gh pr \\\\\nmerge 3"}}' | PATH="$nojq" bash "$H" 2>/dev/null; [ $? -eq 2 ] && echo "ok   no jq: multiline merge blocked (exit 2)" || { echo "FAIL no jq: multiline merge not blocked"; fail=1; }
printf '%s' '{"tool_input":{"command":"git status"}}' | PATH="$nojq" bash "$H"; [ $? -eq 0 ] && echo "ok   no jq: other command passes" || { echo "FAIL no jq: other command blocked"; fail=1; }
rm -rf "$nojq"
exit $fail
