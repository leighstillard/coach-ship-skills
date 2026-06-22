---
name: ship
description: "Take a finished local change to a merged PR through non-negotiable release gates. Use when the user says ship it, /ship, get this merged, release this, or when /coach has a READY local diff. Enforces simplify, verify, design applicability, PR evidence, independent review, CI, and merge babysitting while preserving Anthropic budget where safe."
---

# Ship

## Goal
The change is merged to the default branch, or you stop with the exact unmet invariant and evidence. You may choose the order, but you may not waive invariants.

## Invariants
These are preconditions, not a checklist. If any is unmet, achieving it becomes the next action.

1. **Diff understood.** `git status` and `git diff` have been inspected; every changed/untracked file is intentional.
2. **Simplified.** `/simplify` has run on the final shape, or explicitly returned `UNCHANGED`. Substantial code changes after simplify reopen this invariant.
3. **Verified.** `/verify` ended in `VERIFIED` with real entry-point evidence. Tests/builds alone do not satisfy this. Any code change after `VERIFIED` reopens this invariant.
4. **Design checked when user-visible.** `/design-check` passed, passed with notes, or returned `DESIGN N/A`.
5. **PR carries evidence.** `/pr` opened a PR whose body includes verification evidence, review/design notes, and risk/rollback.
6. **Independent review addressed.** Prefer `/codex:review --wait` for normal diffs and `/codex:adversarial-review --wait` for high-risk/design-heavy diffs when Codex is available. Otherwise use an independent Claude reviewer. Critical findings are fixed; important findings are fixed or explicitly accepted/rebutted. Non-trivial fixes reopen invariants 2-4.
7. **Green and uncontested.** CI is green, required approvals/review comments are addressed, conflicts are resolved, and merge method matches repo convention.
8. **Merged or blocked honestly.** `/babysit` owns the final loop until merged or a real blocker is reported.

## Budget policy
- Use deterministic tools and shell commands before model review where possible.
- Prefer Codex for independent review to preserve Anthropic budget, but do not skip review if Codex is unavailable.
- Do not launch redundant Claude subagents during ship; ship is a gate loop, not an implementation swarm.
- If a gate fails because credentials or budgets are exhausted, stop with `BLOCKED` and the exact missing requirement.

## State tracking
Maintain a visible invariant checklist. Report transitions tersely:
- `[ship] simplify: SIMPLIFIED → verify`
- `[ship] verify: NOT VERIFIED → fixing blocker`
- `[ship] review: critical fixed → re-verify`
- `[ship] ci: green + approved → merge`

## PR evidence minimum
The PR body must contain:
- changed behaviour (`What`)
- reason/context (`Why`)
- verification commands and representative output (`How verified`)
- design screenshots/output or `DESIGN N/A`
- independent review status and unresolved accepted risks
- rollback notes

## Exit report
End with:
```markdown
[ship] <MERGED | BLOCKED | NOT SHIPPED>
PR: <url if opened>
Merged: <yes/no + merge commit if available>
Invariant status:
- Diff understood: <evidence>
- Simplified: <SIMPLIFIED/UNCHANGED/BLOCKED>
- Verified: <VERIFIED/NOT VERIFIED>
- Design: <PASS/PASS WITH NOTES/DESIGN N/A/FAIL>
- Review: <tool used + unresolved findings>
- CI/merge: <status>
Next: <only if not merged>
```

## Gotchas
- Never open a PR before verification unless the user explicitly asks for a draft/WIP PR; label it as not verified in the body.
- Never merge with unresolved critical review findings.
- Do not count a reviewer's prose summary as evidence that CI or verification passed.
- A late CI/review fix invalidates prior verification if it changes behaviour.
