---
name: pr
description: "Commit, push, and open a pull request for the current change. Use when the user says open a PR, /pr, commit and push, or as the PR creation step of the ship skill. Requires verification evidence in the PR body."
metadata:
  short-description: Commit, push, and open an evidence-backed PR
---

# PR

## Goal
A clean branch is pushed and a PR exists with enough evidence for a reviewer to understand what changed, why, how it was verified, and what risk remains.

## Step 1: Pre-flight
- Run `git status --short --untracked-files=all` and inspect `git diff` / staged diff.
- Run a secrets scanner, not a glance: `gitleaks git --no-banner --log-opts="origin/<default>..HEAD" .` over the branch commits and `gitleaks dir .` over the tree (install: `go install github.com/zricethezav/gitleaks/v8@latest`; any equivalent scanner is fine). Paste the clean result under How verified. Then confirm no `.env`, debug prints, unrelated files, generated junk, or large binaries are included.
- Identify the default branch (`gh repo view --json defaultBranchRef` or `git symbolic-ref refs/remotes/origin/HEAD`).
- Do not commit on the default branch. Create a short kebab-case branch if needed.
- If the branch is stale, rebase/merge according to repo convention before opening the PR.

## Step 2: Commit
- Stage deliberately by path. Use `git add -A` only after every untracked path is accounted for.
- Match commit convention from recent history.
- Summary line: imperative, ≤72 chars, states what changed and why.
- Keep one logical change per commit unless repo convention prefers squash-only noise-free branches.

## Step 3: PR body
Check for `.github/PULL_REQUEST_TEMPLATE*` and honor it. Include, at minimum:
- **What** — concise behaviour/change summary.
- **Why** — user issue/ticket/context.
- **How verified** — paste the verification evidence: commands and representative output. `Tests pass` alone is insufficient.
- **Review/design/security** — independent review status, design screenshots/output, and security review status when applicable.
- **Risk / rollback** — likely failure modes and how to revert/disable.

## Step 4: Push/open
Run:
```bash
git push -u origin <branch>
gh pr create --title "<summary>" --body "<body>"
```
Then output the PR URL.

To change the body after opening, write it to a file and use REST, then read it back:
```bash
gh api -X PATCH repos/<owner>/<repo>/pulls/<n> -F body=@body.md >/dev/null
gh pr view <n> --json body -q .body | grep -F "<a line you just added>"
```

## Gotchas
- If `gh auth status` fails, stop and ask for auth; do not improvise credentials.
- Do not force-push over review activity without explicit instruction.
- If diff is very large, mention split risk before opening unless the user explicitly asked for one PR.
- CI config changes must be called out in the PR body.
- Never `gh pr edit --body`/`--body-file`: on repos that touch Projects (classic) it fails on a GraphQL deprecation and leaves the body unchanged. Only the read-back proves the write.
