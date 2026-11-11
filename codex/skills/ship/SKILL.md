---
name: ship
description: "Take a finished local change to a merged PR through non-negotiable release gates. Use when the user says ship it, /ship, get this merged, release this, or when a local diff is ready to go out. Enforces simplify, efficiency review, verify, design applicability, security applicability, PR evidence, independent review, CI, and merge babysitting."
metadata:
  short-description: Ship a local change to a merged PR through release gates
---

# Ship

## Goal
The change is merged to the default branch, or you stop with the exact unmet invariant and evidence. You may choose the order, but you may not waive invariants.

## Invariants
These are preconditions, not a checklist. If any is unmet, achieving it becomes the next action.

1. **Diff understood.** `git status` and `git diff` have been inspected; every changed/untracked file is intentional, and a secrets scanner has run clean over the branch commits and the working tree (the `pr` skill runs it in its pre-flight; its result is evidence for **PR carries evidence**).
2. **Simplified.** The `simplify` skill has run on the final shape, or explicitly returned `UNCHANGED`. Substantial code changes after simplify reopen this invariant.
3. **Efficient.** The `efficiency-review` skill ended in `EFFICIENCY_REVIEW: PASS` on the final shape (Medium/Low findings go in the PR body as notes). `FAIL` means fix the Critical/High findings and re-run; a fix reopens **Simplified**, and any code change after `PASS` reopens this invariant.
4. **Verified.** The `verify` skill ended in `VERIFIED` with real entry-point evidence. Tests/builds alone do not satisfy this. Any code change after `VERIFIED` reopens this invariant.
5. **Design checked when user-visible.** The `design-check` skill passed, passed with notes, or returned `DESIGN N/A`.
6. **Security reviewed when applicable.** If the diff touches auth, user input handling, secrets, network calls, file paths, subprocess execution, or deserialization, the `security-review` skill returned `SECURITY PASS` or its findings are fixed. Otherwise mark `SECURITY N/A`.
7. **PR carries evidence.** The `pr` skill opened a PR whose body includes verification evidence, review/design notes, and risk/rollback.
8. **Independent review addressed.** Run the `code-review` skill with independence: prefer spawning a fresh-context reviewer (`codex exec --sandbox read-only "Use the code-review skill to review <branch> against <default branch>"`, or `claude -p` if available) so the review does not inherit this session's assumptions. Ask for an adversarial pass (the reviewer tries to break the change, not only read it) when the diff touches a trust boundary. Decide by the files touched, not by how the change feels: hooks or anything that runs on session events, auth or secrets handling, settings/config merging, install or release scripts, CI and workflow files, network clients. Repo-installed review bots (a Codex connector, CodeRabbit, or similar) are reviewers too: find them as bot authors in `gh api repos/<o>/<r>/pulls/<n>/comments` and `.../issues/<n>/comments` and as check runs, read every thread they open before merge, and reply on each with the fix commit or a rebuttal. Critical findings are fixed; important findings are fixed or explicitly accepted/rebutted. Non-trivial fixes reopen **Simplified**, **Efficient**, **Verified**, **Design checked when user-visible** and **Security reviewed when applicable**, and the merge gate below enforces it.
9. **Green and uncontested.** CI is green, or green except credential-only reds that the PR body documents with the exact missing requirement and a tracking issue (the `babysit` skill, first-run bucket); required approvals and review comments are addressed; every repo review bot has finished, or the `babysit` skill has recorded the decision to merge without it; conflicts are resolved; merge method matches repo convention.
10. **Merged or blocked honestly.** The `babysit` skill owns the final loop until merged or a real blocker is reported. **See Repo overrides: a repo that never self-merges changes this invariant.**
11. **Cleaned up.** After a merge (or a terminal handoff), no debris is left behind. See **Cleanup** below. This invariant only comes due once the diff has landed or ship has stopped; a blocked ship reports what it *would* clean, then stops.

**Merge markers.** A user-level PreToolUse hook (`~/.codex/hooks/ship-merge-gate.sh`, registered in `~/.codex/hooks.json`) refuses `gh pr merge` unless the command pins its commit with `--match-head-commit <sha>` and that commit has all three markers. It also refuses `--auto`, because auto-merge can land a later push that never passed the gates. It looks for the markers in the session's checkout; from a session started in another directory, begin the command with `cd <checkout> &&`. Write each one the moment its gate ends green on the current HEAD, never before and never from memory:

```bash
m="$(git rev-parse --path-format=absolute --git-common-dir)/ship"; mkdir -p "$m"
touch "$m/$(git rev-parse HEAD).simplified"  # simplify returned SIMPLIFIED or UNCHANGED
touch "$m/$(git rev-parse HEAD).verified"    # verify returned VERIFIED
touch "$m/$(git rev-parse HEAD).reviewed"    # Independent review addressed
```

A new commit has a new SHA and no markers, so a late review fix sends you back through the gates. A refusal is a gate to re-run, not an obstacle: never write a marker for a gate that did not run on this SHA, and never prefix `SHIP_GATE=off` inside a ship. That bypass is for merges outside the ship skill. Codex runs the tool anyway when a hook errors or times out, so the hook is a guardrail and the markers are still yours to keep honest.

## Repo overrides

### Repos that never self-merge
Some repos make human review the gate: their contributor rules (`AGENTS.md`, `CONTRIBUTING.md`, branch protection) say authors never merge their own feature work. In such a repo **Merged or blocked honestly** changes:

- **Ship stops at review handed off, not merged.** Once the PR is open with evidence, independent review addressed, requested reviewers assigned, and CI green, ship is **done**. Report the terminal state as `REVIEW REQUESTED` (not `MERGED`). Do **not** run the `babysit` skill to sit on the PR and merge it.
- **Exception: merge only when the humans have already cleared it.** If at least one non-author reviewer has approved, every requested reviewer has approved, and no review is still pending or requesting changes, ship may merge, respecting the repo's merge convention and target branch. Otherwise, hand off and stop.
- CI-fix and review-comment loops before that handoff still apply. This override only removes the babysit-to-merge tail, not the gates before it.

Record any other per-repo rule the same way: name the repo, name the invariant it changes, and say what the terminal state becomes.

## Retrospective mode
When the user asks to ship a PR that is already merged, nothing is waived because the code is on main. The diff under review is the merge against the base it landed on (`git diff <base-before-merge> <merge-commit>`); every invariant runs against it; evidence is appended to the merged PR's body; fixes ship as a follow-up PR through the normal gates; the exit report says `MERGED (retrospective)` and names the follow-up PR.

## Cleanup
Once the change has landed, sweep for debris created by or exposed by this diff. Report what you found and what you did; when something is ambiguous, list it for the user rather than deleting silently.

- **Merged branch.** Delete the merged head branch (`gh pr merge --delete-branch`, or `git push origin --delete <branch>` + local `git branch -d`) unless it is a protected/long-lived branch (`main`, a `develop` or release branch, a frozen branch kept for audit). Never delete a branch that isn't fully merged. Deleting a branch is an event other PRs react to: if any PR is based on this branch (a stack), first retarget it to the default branch and `git rebase --onto <default> <old-base-head>` it, or merge the top of the stack only, because GitHub closes dependants when their base is deleted. Remove any worktree that holds the branch before `--delete-branch`, and never chain an irreversible step after a cleanup step that can fail: run them separately and check each.
- **Worktrees.** If the work used a git worktree, `git worktree remove` it once merged (and prune with `git worktree prune`).
- **Unchecked work.** `git status` clean? No uncommitted changes, no unpushed commits on the merged branch, no stashes created for this task left dangling. Flag anything still local: nothing is done until it is pushed.
- **Scratch artifacts.** Remove temp files this ship created (scratchpad diffs, prompt files, review outputs). Do not commit them; do not leave them referenced in the PR.
- **Untracked strays.** Re-run `git status` for untracked files that appeared during ship — decide each: commit (belongs in the diff), gitignore, or delete. None should be left unexplained.
- **Loose threads.** Any review finding accepted-not-fixed, deferred TODO, or follow-up the diff implies has a tracking issue filed (not just a comment) before ship closes.

## Budget policy
- Use deterministic tools and shell commands before model review where possible.
- Prefer a fresh-context reviewer for independence, but do not skip review if spawning one is unavailable. Fall back to in-session review with fresh-eyes discipline (see the code-review skill).
- Do not launch redundant sub-sessions during ship; ship is a gate loop, not an implementation swarm.
- If a gate fails because credentials or budgets are exhausted, stop with `BLOCKED` and the exact missing requirement.

## State tracking
Maintain a visible invariant checklist. Report transitions tersely:
- `[ship] simplify: SIMPLIFIED → efficiency`
- `[ship] efficiency: PASS → verify`
- `[ship] verify: NOT VERIFIED → fixing blocker`
- `[ship] review: critical fixed → re-verify`
- `[ship] ci: green + approved → merge`

## PR evidence minimum
The PR body must contain:
- changed behaviour (`What`)
- reason/context (`Why`)
- verification commands and representative output (`How verified`)
- design screenshots/output or `DESIGN N/A`
- security review status or `SECURITY N/A`
- independent review status and unresolved accepted risks
- rollback notes

## Exit report
End with:
```markdown
[ship] <MERGED | REVIEW REQUESTED | BLOCKED | NOT SHIPPED>
PR: <url if opened>
Merged: <yes/no + merge commit if available>
Invariant status:
- Diff understood: <evidence>
- Simplified: <SIMPLIFIED/UNCHANGED/BLOCKED>
- Efficiency: <PASS/PASS WITH NOTES/FAIL>
- Verified: <VERIFIED/NOT VERIFIED>
- Design: <PASS/PASS WITH NOTES/DESIGN N/A/FAIL>
- Security: <SECURITY PASS/FINDINGS FIXED/SECURITY N/A>
- Review: <reviewer used + unresolved findings>
- CI/merge: <status>
- Cleanup: <branch deleted? worktree removed? tree clean? strays/scratch handled? follow-ups filed — or N/A if not merged>
Next: <only if not merged>
```

## Gotchas
- Never open a PR before verification unless the user explicitly asks for a draft/WIP PR; label it as not verified in the body.
- Never merge with unresolved critical review findings.
- Do not count a reviewer's prose summary as evidence that CI or verification passed.
- A late CI/review fix invalidates prior verification if it changes behaviour.
