# Coach & Ship Skills

A workflow pack for building and shipping code changes with a coding agent. It comes in two versions, one for Claude Code and one for OpenAI Codex CLI, and has three goals:

1. **Automation** — turn an overarching engineering goal into repeatable PR-sized loops.
2. **Code quality** — require implementation, tests, real verification, simplification, an efficiency review, independent review, and CI/merge babysitting.
3. **Budget preservation** — avoid defaulting to a swarm of subagents; prefer deterministic tools, and on Claude Code prefer Codex for review and execution where safe.

```text
claude/
  commands/coach.md     # /coach implementation loop
  agents/               # writer, tester, verifier, reviewer
  skills/               # ship, simplify, efficiency-review, verify, design-check, pr, babysit
codex/
  skills/               # the same seven, adapted for Codex, plus code-review and security-review
hooks/
  ship-merge-gate.sh    # blocks `gh pr merge` until the gates passed
  claude-settings.snippet.json
  codex-hooks.json
install.sh              # ./install.sh claude | codex
```

The Codex version has no `/coach` command or subagents. It carries its own `code-review` and `security-review` skills, because Codex has no built-in equivalents of the ones Claude Code ships, and its `ship` adds a security gate.

## Philosophy

`/coach` gets a local change to **READY**: scoped implementation, tests/gates, real verification evidence, and independent review.

`/ship` gets a ready change to **MERGED** or stops honestly with the unmet invariant.

The workflow is intentionally evidence-first:

- Tests passing is not enough; changed behaviour must be exercised through the real CLI/API/UI/workflow/library boundary.
- The executor does not verify or review its own work.
- Subagents are used only when they add independent signal.
- Codex review/execution is preferred where available to preserve Anthropic subscription budget.

## Installation

```bash
git clone https://github.com/leighstillard/coach-ship-skills.git
cd coach-ship-skills
./install.sh claude    # into ~/.claude (or $CLAUDE_HOME)
./install.sh codex     # into ~/.codex  (or $CODEX_HOME)
```

The installer replaces the matching skill directories, copies the merge-gate hook, and tells you how to register it:

- **Claude Code:** add the `PreToolUse` entry from `hooks/claude-settings.snippet.json` to `~/.claude/settings.json`, then start a new session.
- **Codex:** the installer writes `~/.codex/hooks.json` if you have none (otherwise merge `hooks/codex-hooks.json` by hand, using the full path to the installed script as the command). Start Codex, run `/hooks`, and trust the new hook; Codex skips a hook until you do. Use Codex CLI 0.166.0 or later, where the hook is told the directory the command really runs in.

The hook needs `jq` and `gh`. In Codex a hook that errors or times out lets the command run, so treat it as a guardrail, not a lock.

## Usage

### Build a change

Inside Claude Code:

```text
/coach Fix the CSV import crash when the optional email column is missing.
```

`/coach` will:

1. Write a shared brief.
2. Classify risk as `tiny`, `normal`, or `high-risk`.
3. Choose the cheapest safe execution path.
4. Implement or dispatch an executor.
5. Add/run tests when useful.
6. Verify via a real entry point.
7. Run independent review.
8. Stop with a structured READY / NOT READY / BLOCKED report.

### Ship a ready change

```text
/ship
```

`ship` enforces these invariants before merge:

1. Diff understood, with a clean secrets scan.
2. Simplified.
3. Efficient (`efficiency-review` passes).
4. Verified with real entry-point evidence.
5. Design checked if user-visible.
6. Security reviewed when the diff touches a security surface (Codex version).
7. PR body carries evidence.
8. Independent review addressed, including review-bot threads.
9. CI green and review uncontested.
10. Merged or blocked honestly.
11. Cleaned up: branch, worktrees, strays, and follow-up issues.

`simplify`, `verify`, and independent review each leave a marker file for the commit they passed on, and the merge-gate hook refuses `gh pr merge` when the PR's head commit lacks one. A fix after review is a new commit with no markers, so it goes back through the gates.

## Recommended companion tooling

This pack works best with:

- Claude Code or OpenAI Codex CLI
- Git + GitHub CLI (`gh`)
- OpenAI Codex Claude Code plugin/companion commands, if available, for budget-aware implementation and independent review
- A project-level `AGENTS.md` or `CLAUDE.md` containing build/test/verification commands

Codex is optional. If unavailable, the pack falls back to Claude subagents for writer/reviewer paths.

## Project-level setup tips

Add stable repo instructions to `AGENTS.md` or `CLAUDE.md`, for example:

```markdown
# Project Rules

## Build and test
- Run `npm test` for focused unit tests.
- Run `npm run typecheck` before PR.

## Verification
- For CLI changes, run the local binary with real arguments.
- For API changes, start the service and hit the real endpoint.

## PRs
- Keep PRs small and evidence-rich.
- Include rollback notes for risky changes.
```

The more explicit your verification commands are, the better `/coach` and `/ship` perform.

## Updating an existing install

Re-run:

```bash
git pull
./install.sh claude   # or codex
```

The installer overwrites the matching command, agent, skill, and hook files.

## License

MIT. See [LICENSE](LICENSE).
