---
name: babysit
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
Wait 60-120 seconds between unchanged pending states.

### CI failed
1. Read the actual failure log: `gh run view <run-id> --log-failed`.
2. Classify:
   - caused by this diff → fix, run local verification, commit, push.
   - flaky/infra → retry once; if it repeats, treat as real or escalate.
   - broken on base branch → prove or cite evidence, then stop; do not absorb main's failure into this PR.
3. Loop guard: after 3 distinct failed fix attempts for the same check, stop and summarize attempts.

### Review comments arrived
- Address substantive comments in code, batching fixes where practical.
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
- Enable auto-merge or merge directly as appropriate, e.g. `gh pr merge <number> --auto --squash`.
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
