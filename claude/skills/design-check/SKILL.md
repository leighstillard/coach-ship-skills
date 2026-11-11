---
name: design-check
description: "Visual and UX review for user-visible changes: frontend components, HTML/CSS, templates, dashboards, rendered docs, emails, and CLI output formatting. Use as part of /ship when a diff touches UI/human-facing output. If nothing user-visible changed, explicitly mark not applicable and stop."
---

# Design Check

## Step 0: Applicability
Inspect the diff. If no human-facing surface changed, say `DESIGN N/A — no user-visible surface touched` and stop.

Human-facing surfaces include web/mobile UI, templates, CSS, generated documents/emails, screenshots, terminal output, errors users see, and rendered docs.

## Step 1: Render the actual output
Do not review design from source alone.
- Web UI: run the app/storybook and capture desktop plus narrow mobile screenshots.
- CLI/errors: run commands that show normal, empty, long, and error output.
- Docs/emails/PDFs: render the final artifact.

## Step 2: Review
Check:
- Consistency with existing components/tokens/patterns.
- Loading/empty/error/overflow/long-text states.
- Keyboard/focus and accessible names for interactive elements.
- Contrast and non-colour-only meaning.
- Alignment, density, and avoidance of one-off AI-looking decoration.
- Neighbouring surfaces affected by shared component changes.

## Step 3: Fix or flag
Fix mechanical defects directly when safe. Flag judgement calls with screenshot/output evidence and a one-line recommendation. Do not redesign broadly without instruction.

## Verdict
- **PASS** — screenshots/output evidence included.
- **PASS WITH NOTES** — non-blocking judgement calls listed.
- **FAIL** — blocking design/accessibility/usability defects listed.
- **DESIGN N/A** — no user-visible surface changed.

## Gotchas
- Source review is not design review.
- If dark mode or responsive layouts exist, sample them.
- CLI output is design when humans read it.
