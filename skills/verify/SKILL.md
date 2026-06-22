---
name: verify
description: "Prove a change actually works before it ships. Use whenever a change is done, after implementing a feature/fix, before opening a PR, or when the user says verify/check this works/is this actually working. Tests passing is not sufficient; this skill requires real entry-point evidence."
---

# Verify

Core principle: **tests passing ≠ feature working**. Verification means executing the changed behaviour through the same boundary a user, service, or downstream caller uses.

## Process

### 1. Restate the contract
Briefly state what the change is supposed to do from the user's perspective. If you cannot state it, ask or mark NOT VERIFIED.

### 2. Run the existing gates
Run the repo's relevant gates, escalating from cheapest to broadest:
- format/lint/typecheck/build
- focused tests for touched area
- full test suite when practical before PR/merge

If a gate was already failing before the change, record that evidence and do not pretend it passed.

### 3. Drive the real entry point
Exercise the actual surface:
- CLI → run the installed/local binary or package command with real args.
- API/service → start the service, call the endpoint, inspect body and side effects.
- UI → run the app, interact with the changed path, capture screenshots if useful.
- Workflow/worker/pipeline → run a small real input and inspect output artifacts/rows/state.
- Library → write and run a throwaway consumer script.

Capture command + representative output. Screenshots or logs count only when tied to the command/path that produced them.

### 4. Edge/failure sweep
Try the highest-value applicable cases, not an infinite checklist:
- empty/zero/nil input
- boundary/off-by-one
- duplicate/repeated invocation/idempotency
- malformed dependency response or timeout
- unicode/long strings if strings cross a boundary
- permissions/auth for new access paths
- backwards compatibility for old config/data/callers

### 5. Reliability sweep
Check that new failure modes are diagnosable:
- errors carry context and are not swallowed
- external calls have timeout/retry/cancellation where appropriate
- logs are useful but contain no secrets/PII
- resources are cleaned up

### 6. Verdict
End with exactly one:
- **VERIFIED** — evidence proves the contract through the real entry point.
- **NOT VERIFIED** — something failed, could not run, or only tests/builds ran.

Partial verification is NOT VERIFIED with notes.

## Gotchas
- Do not verify by re-reading code.
- Do not count executor claims or CI summaries as evidence unless you retrieved the underlying output.
- Any code change after VERIFIED invalidates the verdict; re-run the relevant verification.
