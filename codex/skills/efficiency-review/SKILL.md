---
name: efficiency-review
description: Blocking efficiency gate for /ship. Reviews a diff (or whole codebase) for algorithmic complexity, N+1 and query patterns, unbounded memory, I/O in loops and missing indexes. Detects the stack, delegates to performance-oracle and postgres-best-practices when installed, suggests other skills when the workload warrants, and emits a PASS/FAIL verdict. Use when a diff must be clear of performance regressions before PR or merge.
metadata:
  short-description: Blocking performance gate for a diff before it ships
---

# Efficiency Review

Gate, not advisor. Every blocking finding must be a concrete, reproducible claim about this diff. "Could be slow" is not a finding.

## 1. Scope

- Diff mode (default): `git diff --merge-base origin/main` (no second commit, so staged and unstaged work is included) (or the base the pipeline passes). Review changed hunks plus the functions that call them — a hot path is often unchanged code that now calls new slow code.
- Codebase mode: only when asked explicitly. Walk entry points → data access → hot loops; do not read everything.

## 2. Detect what's in use

Inspect the diff and repo root once. Record the stack before reviewing.

| Signal | Workload |
|---|---|
| `go.mod`, `*.go` | Go |
| `*.sql`, `migrations/`, `sqlc`, `pgx`, `gorm`, `database/sql`, `prisma`, `drizzle`, `sqlalchemy` | SQL / Postgres |
| `package.json` + React/Next/Svelte | Frontend |
| `*.py` | Python |
| Dockerfile, Terraform, CDK, Helm | Infra |
| ORM models or query builders | N+1 risk |

## 3. Delegate to installed skills

Check `~/.codex/skills/`, `.agents/skills/` for the names below. Invoke what exists against the relevant files; fold their findings into the verdict using this skill's severity rules.

| Workload | Skill | Install if missing |
|---|---|---|
| Any code | `performance-oracle` | `npx skills add ratacat/claude-skills --skill performance-oracle --agent codex` |
| Postgres / SQL | `postgres-best-practices` | `npx skills add supabase/agent-skills --skill postgres-best-practices --agent codex` |
| Non-Postgres SQL (MySQL, SQL Server, Oracle) | `sql-optimization` | `npx skills add github/awesome-copilot --skill sql-optimization --agent codex` |
| Frontend bundles / Core Web Vitals | `web-quality-skills` performance | `/plugin marketplace add addyosmani/web-quality-skills` |

A missing skill never blocks. Run the baseline below regardless and append one line per missing skill: `SUGGEST: install <skill> — <workload> detected`.

## 4. Baseline checks (always run)

Go through every category; say explicitly when a category has nothing in scope.

**Algorithmic**
- State time and space complexity for each new or changed loop/recursion over a collection.
- Flag O(n²) or worse where n is unbounded or user/DB-driven. Nested iteration over two result sets, `contains`/`indexOf` inside a loop, repeated sort, string concatenation in a loop.
- Project at 10× / 100× current volume. If a fixture, comment, or schema gives a realistic n, use it.

**Data access**
- N+1: a query, RPC, or HTTP call inside a loop or per-item mapper. Check ORM lazy loads and resolver-per-field in GraphQL.
- `SELECT *` on wide tables, missing `LIMIT` on unbounded reads, `OFFSET` pagination on large tables.
- New `WHERE` / `JOIN` / `ORDER BY` columns without a supporting index in migrations; functions wrapped around indexed columns; implicit type casts.
- New migrations: lock behaviour (`ADD COLUMN ... DEFAULT` on big tables, non-`CONCURRENTLY` index creation).
- Transactions held open across network calls.

**Memory**
- Unbounded slices/maps/arrays grown from external input; caches without eviction; reading whole files or result sets into memory where streaming exists.
- Go: `append` in loops without preallocation when length is known; goroutine leaks (no cancellation, unbuffered channel with no reader); `defer` inside loops.

**I/O and concurrency**
- Sequential independent I/O that could be batched or run concurrently; sync calls on a request path that belong on a queue.
- Missing timeouts or context propagation on outbound calls.
- Retries without backoff; polling where an event exists.

**Caching and repetition**
- Same expensive computation or query repeated within one request; regex/template/schema compiled per call instead of once.

## 5. Evidence rule

Before marking anything Critical or High:
1. If a benchmark or test exists for the path, run it (`go test -bench`, `pytest-benchmark`, `vitest bench`). Quote numbers.
2. If a database is reachable, run `EXPLAIN (ANALYZE, BUFFERS)` on the new or changed query. Quote the plan node that matters.
3. If neither is possible, downgrade to Medium and state what measurement would confirm it.

Exception: a complexity-class regression against the code it replaces stays High without a measurement when the finding states both complexities, the lines that prove each, and why n is unbounded.

Never fabricate numbers. Never cite a plan you did not run.

## 6. Severity → gate

| Severity | Definition | Gate |
|---|---|---|
| Critical | Will fail or degrade in production at current scale (unbounded N+1, O(n²) on DB rows, unbounded memory growth, table lock in migration) | FAIL |
| High | Measurable regression on a hot path, or clear complexity-class regression vs the code it replaces | FAIL |
| Medium | Real inefficiency, cold path or bounded n, or unmeasured | PASS with note |
| Low | Style-level (preallocation, minor allocation) | PASS with note |

Scale cues come from the repo (row counts in comments, fixtures, schema, load tests). Absent any cue, assume n is unbounded for anything sourced from a DB, API, or user.

## 7. Output

Emit exactly this block last so the pipeline can parse it. Nothing after it.

```
EFFICIENCY_REVIEW: PASS | FAIL
STACK: <detected workloads>
SKILLS_RUN: <names or none>
SUGGEST: <install lines, or none>

FINDINGS:
- [CRITICAL|HIGH|MEDIUM|LOW] <file>:<line> — <what> — <why it matters at scale> — <fix> — <evidence or "unmeasured">

CLEAN: <categories reviewed with nothing to report>
```

FAIL iff any Critical or High finding exists. Keep findings to one line each; the fix is a direction, not a patch. Do not restate the diff.

## Non-goals

Correctness, security, style, test coverage — other gates own those. Do not comment on them even when noticed; the pipeline runs them separately.
