---
name: "babysit"
description: "Shepherd an open PR to merge. Watches CI, fixes failures, addresses review comments, resolves conflicts, and enables/executes merge when green. Use after opening a PR, when the user says babysit/watch/get this merged, or as the final step of /ship."
---

# Babysit

## Goal
The PR merges, or you stop with a precise blocker and the evidence for it.

## Loop
Poll without spinning:
```bash
gh pr view <number> --json state,reviewDecision,mergeable,comments,headRefName,baseRefName
 gh pr checks <number>
```
Wait 60-120 seconds between unchanged pending states. To wait on checks, run `scripts/watch-checks.sh <number>` once in the foreground first; arm it as a background watch only after that run printed a real state. It loops while `gh pr checks` reports pending (exit 8), then exits 0 (all passed) or 1 (a check failed). Exit 3 means the PR has no checks reported (none configured, or none started yet: look again once before treating it as "no CI"), and exit 4 means checks were still pending after 30 minutes, which is the point to decide about a check that will not finish. Any other `gh` exit stops it with exit 2 and the error printed, so a broken query never looks like "no checks".

Every PR body write (accepted reds, a bot skipped, evidence) goes through REST and is read back, never `gh pr edit --body`:
```bash
gh api -X PATCH repos/<owner>/<repo>/pulls/<n> -F body=@body.md >/dev/null
gh pr view <n> --json body -q .body | grep -F "<a line you just added>"
```

The status rollup mixes check runs (`name/status/conclusion`), status contexts (`context/state`) and, for a bot that has not started yet, nothing at all; a wait predicate must handle all three or it hangs on the one it does not know. Repo review bots (Codex connector, CodeRabbit, or similar) end one of three ways, and the loop names which: finished with findings (address them, reply on each thread), finished clean, or not going to finish: conclusion `neutral` or `skipped`, a "rate limited" summary, or still running about 15 minutes after the push while not a required check. The third is a recorded decision, written into the PR body, to merge without that bot. It is not an indefinite wait and not a blocker.

### CI failed
1. Read the actual failure log: `gh run view <run-id> --log-failed`.
2. Classify:
   - caused by this diff → fix, run local verification, commit, push.
   - flaky/infra → retry once; if it repeats, treat as real or escalate.
   - broken on base branch → prove or cite evidence, then read the workflow's `needs:` for the failed job. If it gates nothing, stop; do not absorb main's failure into this PR. If it gates the deploy (or another job the change needs), say so: a mergeable PR whose deploy is blocked never reaches users. Fix it in its own PR when the fix is small and reversible, otherwise stop and name the blocker. Never absorb the fix into this PR.
   - first run of a check this PR introduces (no CI on base, or a relocated workflow) → the PR owns the first green: fix content the check validates in a separate, clearly titled commit, never hidden in the wiring commit. A red whose only cause is a missing credential is recorded in the PR body as an accepted red with the exact missing requirement and a tracking issue; ship's **Green and uncontested** reads "green except documented credential-only reds". A wired check that pulls a tool unpinned (`npx -p <pkg>` with no version) is noted in the PR as a drift source.
3. Loop guard: after 3 distinct failed fix attempts for the same check, stop and summarize attempts.

### Review comments arrived
- Address substantive comments in code, batching fixes where practical. Repo bot threads count: reply on each with the fix commit or a rebuttal.
- Reply with what changed or a concise rebuttal.
- Escalate genuine disputes after at most two back-and-forths.
- Do not mark reviewer threads resolved unless repo convention says authors resolve.

### Merge conflict
- Fetch and rebase/merge according to repo convention.
- Resolve conservatively; inspect both sides' intent before choosing.
- Re-run relevant tests and verification before pushing.
- Use `--force-with-lease` after a rebase, never bare `--force`.

### All green + approved
- Determine merge convention from repo settings/recent PRs.
- Merge directly once everything is green, pinning the commit the gates passed on: `gh pr merge <number> --squash --match-head-commit <full 40-character sha>` (use the repo's merge method). The merge hook refuses a merge that does not pin its commit as a literal SHA, refuses `--auto` (auto-merge can land a later push that never passed the gates), and refuses a commit that lacks the verified, simplified and reviewed markers (ship, Merge markers). Run the merge only right after `scripts/watch-checks.sh <number>` exits 0, or 3 on a repo with no CI, or 1 when every failure is a credential-only red the PR body already documents (CI failed, first-run bucket) and `gh pr view <number> --json mergeStateStatus` reads `CLEAN` or `UNSTABLE`, never `BLOCKED`. The reason: on a branch that requires a merge queue, gh enables auto-merge by itself while required checks are still pending, and the hook cannot see that from the command. `gh pr checks` does not list a required check that has not started, so read `mergeStateStatus` too; with checks settled and the state not `BLOCKED`, gh merges at once or adds the PR to the merge queue. Under /ship a refusal means return to ship and re-run the named gates; for a merge outside /ship, prefix `SHIP_GATE=off`. Before `--delete-branch`, remove any worktree holding the branch and check no other PR is based on it (ship, Cleanup).
- Confirm the PR state is merged and report the URL/merge commit if available.

## Exit conditions
Stop when:
- merged
- blocked on human review with no actionable comments
- loop guard tripped
- failure requires a product/security/API/data decision
- credentials/permissions are missing

## Gotchas
- `gh pr checks` can return non-zero while pending; read the output.
- Pushing fixes can dismiss approvals; batch review fixes.
- External checks you cannot inspect/retry are blockers, not reasons to wait forever.
