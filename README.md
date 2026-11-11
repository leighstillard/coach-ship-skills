# coach-ship-skills

Skills, agents and one hook that take a code change from "I have a task" to "merged PR", with gates the agent cannot talk its way past. There is a Claude Code version and an OpenAI Codex CLI version.

- `/coach` (Claude Code only) gets a change to a verified local diff.
- `ship` gets that diff to a merged PR, or stops and names the gate that is still red.
- `hooks/ship-merge-gate.sh` refuses `gh pr merge` unless the commit being merged passed the gates.

## How it works

`ship` is a list of invariants, not a script. The agent picks the order; it may not skip one:

1. **Diff understood**: every changed file is intentional, and gitleaks is clean over the branch commits and the tree.
2. **Simplified**: `simplify` ran on the final shape.
3. **Efficient**: `efficiency-review` returned PASS.
4. **Verified**: `verify` exercised the change through its real entry point (CLI, endpoint, UI, worker). Passing tests alone do not count.
5. **Design checked** when the change is user-visible.
6. **Security reviewed** when the diff touches auth, input handling, secrets, network calls, file paths, subprocesses or deserialization.
7. **PR carries evidence**: `pr` writes the verification output, review notes and rollback into the body.
8. **Independent review addressed**: a reviewer other than the author, plus every thread from review bots installed on the repo.
9. **Green and uncontested**: CI and approvals.
10. **Merged or blocked honestly**: `babysit` watches checks, fixes failures, answers review and merges.
11. **Cleaned up**: branch, worktrees, scratch files, follow-up issues.

A code change after a gate passed reopens it. To make that stick, `ship` writes an empty marker file for the commit each time `simplify`, `verify` or the review step passes on it. Running `simplify` or `verify` on its own writes nothing.

```
$(git rev-parse --git-common-dir)/ship/<sha>.simplified
$(git rev-parse --git-common-dir)/ship/<sha>.verified
$(git rev-parse --git-common-dir)/ship/<sha>.reviewed
```

The hook is a `PreToolUse` hook on shell commands. When a command is a `gh pr merge`, it requires `--match-head-commit <literal 40-char sha>` and all three markers for that SHA, and it refuses `--auto`. gh itself refuses the merge if the PR head is no longer that SHA, so a commit pushed after review has no markers and goes back through the gates.

The two versions differ in a few places:

| | Claude Code | Codex CLI |
|---|---|---|
| Implementation loop | `/coach` with `writer`, `tester`, `verifier`, `reviewer` agents (all pinned to Sonnet) | none; use Codex directly |
| Independent review | `/codex:review` or `/codex:adversarial-review` from the Codex plugin, else the `reviewer` agent | bundled `code-review` skill, run in a fresh `codex exec` or `claude -p` |
| Security gate | Claude Code's built-in `/security-review` | bundled `security-review` skill |

## Install

Requirements: `git`, `gh` (authenticated), `jq`, and `gitleaks` for the secrets scan. Codex CLI 0.166.0 or later for the Codex version.

```bash
git clone https://github.com/leighstillard/coach-ship-skills.git
cd coach-ship-skills
./install.sh claude    # into $CLAUDE_HOME, default ~/.claude
./install.sh codex     # into $CODEX_HOME, default ~/.codex
```

The installer copies the skills (and, for Claude, the command and agents) and the hook. If a skill directory of the same name already exists, it is moved to `skills-backup-<timestamp>/` rather than deleted. Then register the hook:

- **Claude Code**: add the `PreToolUse` entry from `hooks/claude-settings.snippet.json` to `$CLAUDE_HOME/settings.json` and start a new session. The snippet names `$HOME/.claude/hooks/ship-merge-gate.sh`; with a custom `CLAUDE_HOME`, use the path the installer prints.
- **Codex**: the installer writes `$CODEX_HOME/hooks.json`, pointing at the installed hook, if you have none; otherwise merge `hooks/codex-hooks.json` into yours, with the command set to the path the installer prints. Start Codex, run `/hooks` and trust the hook. Codex skips untrusted hooks.

To update, `git pull` and run the installer again.

Put your repo's build, test and verification commands in `AGENTS.md` or `CLAUDE.md`. `verify` and `coach` use them, and the gates are only as good as the commands they can run.

## Usage

```text
/coach Fix the CSV import crash when the optional email column is missing.
/ship
```

`/coach` writes a brief, picks a risk tier, implements (preferring Codex when the plugin is installed), verifies, reviews, and stops with READY, NOT READY or BLOCKED. `/ship` takes it from there and ends with an exit report listing each invariant and its evidence.

## FAQ

**The hook refused my merge. Now what?**
Read the reason; it names the missing marker, pin or flag. Inside a ship, re-run the gate it names on the current commit. Do not write markers by hand.

**How do I merge something that is not going through ship?**
Prefix the command with `SHIP_GATE=off`. That is visible in the transcript, which is the point.

**My session started in a different directory from the repo.**
The hook looks for markers in the session's checkout. Start the command with `cd /path/to/checkout &&` and it checks that checkout instead. The path must be literal: no `$VAR`, backticks or `~user`.

**Can the agent get around the hook?**
Yes, if it tries. The hook reads the command as text, so an alias, a script file or a command built at run time gets past it. It also refuses anything it cannot read simply: comments, two merges in one command, two pins, escaped or unbalanced quotes. Quoted `--subject` and `--body` values are ignored, so `Fix #12` in a subject is fine, unless the value is double-quoted and contains `$(...)` or a backtick, since the shell runs that. It is there to catch a forgotten gate, not to stop someone who means to skip it.

**Why refuse `--auto`?**
Auto-merge merges whatever the head is when the checks finish, which may be a commit pushed after review.

**What about merge-queue branches?**
On a branch that requires a merge queue, gh turns on auto-merge by itself if required checks are still pending, and the hook cannot see branch protection. `babysit` therefore merges only after `scripts/watch-checks.sh` reports the checks finished (exit 0, or 3 when the repo has no CI).

**Why are there only three markers when there are eleven invariants?**
Markers are for gates that a later commit can quietly invalidate. Efficiency, security and design are re-run inside ship when the code changes, but the hook does not enforce them.

**Does it need Codex?**
No. Without the Codex plugin, Claude Code falls back to its own `writer` and `reviewer` agents. It costs more Anthropic budget, which is why Codex is preferred when available.

**What if the repo forbids authors merging their own PRs?**
`ship` has a Repo overrides section. In such a repo it stops at `REVIEW REQUESTED` and merges only once a non-author reviewer has approved, every requested reviewer has approved, and nothing is pending.

**Can I ship a PR that is already merged?**
Yes. Retrospective mode runs every gate against the merged diff and ships fixes as a follow-up PR.

**How do I test the hook?**
`bash hooks/test-merge-gate.sh` runs it against a table of commands in throwaway repos and exits non-zero on any mismatch.

## Layout

```text
claude/commands/coach.md   /coach
claude/agents/             writer, tester, verifier, reviewer
claude/skills/             ship, simplify, efficiency-review, verify, design-check, pr, babysit
codex/skills/              the same seven, plus code-review and security-review
hooks/                     ship-merge-gate.sh, its test, and the Claude and Codex hook configs
install.sh                 ./install.sh claude | codex
```

## License

MIT. See [LICENSE](LICENSE).
