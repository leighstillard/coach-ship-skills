---
name: "simplify"
description: "Simplify a completed diff before it ships. Use before /ship, after a feature works, or when a change feels over-engineered. Removes unnecessary abstraction, scope creep, dead code introduced by the diff, and confusing structure without changing behaviour."
---

# Simplify

## Goal
The diff does the same job with less code, less surprise, and fewer review risks. Behaviour must not change except to remove accidental scope creep.

## Process
1. **Inventory the diff.** Run `git diff --stat` and inspect changed files. Identify the user-requested behaviour in one sentence.
2. **Prune scope.** Remove changes that do not trace directly to the request: speculative abstractions, broad formatting, opportunistic refactors, unused options, debug logs, and dead code introduced by this diff.
3. **Flatten complexity.** Prefer direct code over a new abstraction used once. Keep existing project patterns even if you would design them differently.
4. **Preserve contracts.** Do not change public APIs, schema, data migrations, or user-visible behaviour while simplifying unless the brief explicitly allows it.
5. **Re-run gates.** Run the focused tests/build command that proved the diff before simplification. If behaviour is user-visible, preserve or refresh verification evidence.

## Verdict
End with:
- **SIMPLIFIED** — list removed/changed complexity and commands run.
- **UNCHANGED** — explain why the diff is already minimal.
- **BLOCKED** — explain what decision is needed.

## Gotchas
- Do not beautify unrelated code.
- Do not delete pre-existing dead code unless this diff made it unreachable.
- Do not replace a boring existing pattern with a clever new one.
- Merging independent `if`s into one `switch`/`if-else` chain, or reordering its cases, makes it first-match-wins. List the inputs that match more than one condition; prove that set empty or add a test for it before calling the result SIMPLIFIED. A green suite is evidence only for the inputs it exercises.
