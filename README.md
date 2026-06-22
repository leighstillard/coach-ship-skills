# Coach & Ship Skills for Claude Code

A small Claude Code workflow pack for building and shipping code changes with three goals:

1. **Automation** — turn an overarching engineering goal into repeatable PR-sized loops.
2. **Code quality** — require implementation, tests, real verification, simplification, independent review, and CI/merge babysitting.
3. **Anthropic budget preservation** — avoid defaulting to a swarm of Claude subagents; prefer deterministic tools and Codex review/execution where safe.

The pack contains one slash command, four Claude subagents, and six skills that work together:

```text
commands/
  coach.md              # /coach implementation loop
agents/
  writer.md             # scoped implementation fallback
  tester.md             # test design from contract
  verifier.md           # real entry-point verification
  reviewer.md           # independent diff review fallback
skills/
  ship/                 # release/merge gate loop
  verify/               # prove behaviour through real entry points
  design-check/         # visual/UX/human-facing output gate
  pr/                   # commit, push, open PR with evidence
  babysit/              # watch CI/reviews/conflicts until merged or blocked
  simplify/             # remove unnecessary complexity before shipping
```

## Philosophy

`/coach` gets a local change to **READY**: scoped implementation, tests/gates, real verification evidence, and independent review.

`/ship` gets a ready change to **MERGED** or stops honestly with the unmet invariant.

The workflow is intentionally evidence-first:

- Tests passing is not enough; changed behaviour must be exercised through the real CLI/API/UI/workflow/library boundary.
- The executor does not verify or review its own work.
- Subagents are used only when they add independent signal.
- Codex review/execution is preferred where available to preserve Anthropic subscription budget.

## Installation

### Option 1: Install with the script

```bash
git clone https://github.com/leighstillard/coach-ship-skills.git
cd coach-ship-skills
./install.sh
```

By default this installs into `~/.claude`.

To install somewhere else:

```bash
CLAUDE_HOME=/path/to/.claude ./install.sh
```

### Option 2: Manual install

Copy the files into your Claude Code config directory:

```bash
mkdir -p ~/.claude/commands ~/.claude/agents ~/.claude/skills
cp commands/coach.md ~/.claude/commands/coach.md
cp agents/*.md ~/.claude/agents/
cp -R skills/ship skills/verify skills/design-check skills/pr skills/babysit skills/simplify ~/.claude/skills/
```

Restart Claude Code, or start a new Claude Code session, so commands/skills/agents are reloaded.

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

`/ship` enforces these invariants before merge:

1. Diff understood.
2. Simplified.
3. Verified with real entry-point evidence.
4. Design checked if user-visible.
5. PR body carries evidence.
6. Independent review addressed.
7. CI green and review uncontested.
8. Merged or blocked honestly.

## Recommended companion tooling

This pack works best with:

- Claude Code
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
./install.sh
```

The installer overwrites the matching command/agent/skill files in `~/.claude`.

## License

MIT. See [LICENSE](LICENSE).
