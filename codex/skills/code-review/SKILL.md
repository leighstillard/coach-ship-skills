---
name: code-review
description: "Independent code review of a diff before it merges. Use when the user says review this, code review, /code-review, as the review gate of the ship skill, or before merging a PR. Reviews the branch diff against the default branch for correctness, contracts, tests, and maintainability, and classifies findings by severity."
metadata:
  short-description: Review a diff for defects with severity-classified findings
---

# Code Review

## Goal
Every defect a competent human reviewer would block on is found, classified, and reported with `file:line` references and a concrete failure scenario. No style-nit noise.

## Independence
The review must not inherit the implementer's assumptions:
- If this session wrote the diff, prefer spawning a fresh-context reviewer:
  ```bash
  codex exec --sandbox read-only "Use the code-review skill to review the diff of <branch> against <default branch> in $(pwd)"
  ```
  or `claude -p "Review the diff of <branch> against <default branch> for correctness, contracts, tests, and maintainability; classify findings critical/important/minor with file:line and failure scenarios"` when available.
- If reviewing in-session, re-derive intent from the diff and commit messages alone before consulting your memory of writing it. State intent first, then check the code against it.

A reviewer is read-only: it does not edit files, commit, push, post comments, move `HEAD`, or hand the review to another reviewer.

## Process
1. **Scope.** Review what would actually merge, not a diff against the branch tip. Compare against the default branch's upstream (`origin/<default>`) when it exists and is ahead of the local branch, otherwise the local branch: `base=$(git merge-base HEAD <comparison-ref>)`, then `git diff "$base" --stat` and the full `git diff "$base"`. List changed files and which entry points they affect.
2. **Intent.** One sentence per logical change, derived from commits/PR body. If a change has no discernible intent, that is itself a finding. When a plan, issue, or spec exists for the change, read it: a requirement the diff misses, or behaviour the plan never asked for, is a finding too.
3. **Correctness pass.** For each changed function/path: wrong-input handling, off-by-one, null/empty, error paths, concurrency, resource cleanup, silent behaviour changes to existing callers.
4. **Contract pass.** Public API/schema/config/CLI compatibility; migrations reversible; wire formats and serialized data backwards compatible.
5. **Test pass.** Do the tests actually exercise the new behaviour and its failure modes, or only the happy path? Would the tests fail if the change were reverted?
6. **Maintainability pass.** Misleading names/comments, duplication of an existing utility, abstraction that hides a bug, dead code introduced by this diff.
7. **Validation pass.** Read the whole diff before writing anything up; do not stop at the first defect. Then take each candidate finding on its own and try to disprove it: open the call sites and tests, and confirm the scenario can happen. Drop what a linter, formatter, or type checker already reports, and what the code silences on purpose (an ignore comment with a reason).

## Findings format
For each finding:
```
[CRITICAL|IMPORTANT|MINOR] <file>:<line> — <one-line defect>
Scenario: <concrete input/state → wrong outcome>
Fix: <one-line suggestion>
```
- **CRITICAL** — bug, data loss, broken contract, security hole. Blocks merge.
- **IMPORTANT** — likely defect or missing test for risky behaviour. Fix or explicitly accept with rationale.
- **MINOR** — non-blocking improvement. Never gate on these.

## Coverage
After the findings, list the files you read in full, the areas you did not verify (and why), and anything you declined to judge, such as a product decision. An unread area is not an approved one.

## Verdict
End with exactly one:
- **APPROVED** — no critical/important findings.
- **APPROVED WITH NOTES** — only accepted/rebutted important findings and minors remain.
- **CHANGES REQUIRED** — unresolved critical or important findings listed.

## Gotchas
- Verify claims against the code, not the PR description; the body may say things the diff does not do.
- A finding without a concrete failure scenario is an opinion — downgrade it to MINOR or drop it.
- Review the diff in context: open surrounding code before flagging something the codebase already handles.
- Do not demand refactors of pre-existing code; scope findings to what this diff introduced or touched.
