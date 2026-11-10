---
name: security-review
description: "Security review of a diff for exploitable vulnerabilities. Use when the user says security review, /security-review, or as the security gate of the ship skill when a diff touches auth, user input handling, secrets, network calls, file paths, subprocess execution, or deserialization. High-signal only: reports concrete attack paths, not theoretical hardening."
metadata:
  short-description: Find exploitable vulnerabilities introduced by a diff
---

# Security Review

## Goal
Every exploitable vulnerability introduced or exposed by this diff is reported with a concrete attack path, or the diff earns `SECURITY PASS`. High signal only — a finding without an attacker-controlled path to impact is noise.

## Step 0: Applicability
Inspect the diff. If it touches none of: authn/authz, user/external input handling, secrets/credentials, network calls, file paths, subprocess execution, deserialization/parsing, crypto, or dependency changes — say `SECURITY N/A — no security-relevant surface touched` and stop.

## Process
0. **Learn the repo's own defences first.** Find the security libraries, sanitisers, validation helpers, and auth middleware the codebase already uses, and how existing code calls them. New code that departs from an established safe pattern, or opens a surface the old code did not have, is where findings come from.
1. **Map attacker-controlled inputs.** For each changed file, identify what data an external party can influence: request params, headers, file contents, filenames, env vars, DB rows written by other users, webhook payloads, LLM output used in tools.
2. **Trace each input to its sinks.** Follow attacker-controlled data through the diff to dangerous sinks.
3. **Check each category that applies:**
   - **Injection** — SQL/command/template/XSS/header/log injection; string-built queries or shell commands; `eval`/`exec` on tainted data.
   - **AuthN/AuthZ** — missing or client-side-only checks on new endpoints/paths; IDOR (object IDs without ownership checks); privilege escalation; auth logic changed for existing routes.
   - **Secrets** — hardcoded credentials/tokens; secrets in logs, error messages, URLs, or committed files; overly broad credential scope.
   - **SSRF / path traversal** — user-influenced URLs fetched server-side; user-influenced file paths without normalization + allowlist.
   - **Deserialization / parsing** — unsafe loaders (pickle, yaml.load, XML with entities) on external data; prototype pollution; zip-slip.
   - **Crypto** — home-rolled crypto, weak hashes for passwords, static IVs/keys, missing signature verification, `verify=False`.
   - **Race/logic** — TOCTOU on security decisions; unbounded operations gated only client-side; check-then-act on shared state.
   - **Dependencies** — new packages: typo-squats, known CVEs, install scripts; pinned to mutable refs.

## Signal filter (mandatory)
Find first, then filter. Collect candidate findings in one pass. Then take each candidate separately, by reading code only, and score how confident you are that it is exploitable: 0.9 and up means a certain exploit path, 0.8 to 0.9 a clear pattern with a known way to exploit it, below 0.8 speculative. Report only 0.8 and above. When a fresh-context session is available (`codex exec --sandbox read-only`), run the filter there so it does not inherit the finder's reasoning. Better to miss a theoretical issue than to bury a real one.

Do NOT report:
- theoretical issues with no attacker-controlled path in this codebase's deployment reality
- missing hardening or defence in depth (one-line notes at most, never findings), including missing audit logs
- denial of service, rate limiting, and memory or CPU exhaustion, including regex DoS
- missing validation on a field with no proven security impact
- race conditions and timing attacks that are theoretical rather than concretely exploitable
- memory-safety bugs in memory-safe languages
- findings in unit tests, test fixtures, or documentation, unless they contain real credentials
- log spoofing, and logging of non-sensitive data; logging a secret, password, or personal data IS a finding
- SSRF where the attacker controls only the path, not the host or protocol
- regex injection, and user content placed in an AI system prompt
- pre-existing issues the diff did not touch: mention in one line, do not count against the verdict

Working assumptions:
- Environment variables and CLI flags are trusted; an attack that needs to control one is invalid.
- UUIDs are unguessable.
- React and Angular escape output by default; report XSS there only through an unsafe method (`dangerouslySetInnerHTML`, `bypassSecurityTrustHtml`, and the like).
- Client-side code is not where permission checks live; a missing check in browser code is not a finding when the server enforces it.
- Shell scripts, GitHub Actions workflows, and notebooks rarely see untrusted input; report injection there only with a specific path by which untrusted input arrives.
- Subtle web issues (tabnabbing, XS-Leaks, prototype pollution, open redirects) need very high confidence.
- Medium findings are reported only when obvious and concrete.

## Findings format
```
[CRITICAL|HIGH|MEDIUM] <file>:<line> — <one-line vulnerability>
Attack: <who controls what input → concrete exploitation → impact>
Fix: <one-line remediation>
```

## Verdict
End with exactly one:
- **SECURITY PASS** — security-relevant surface reviewed, no exploitable findings.
- **FINDINGS** — list per format above. Critical/high block ship.
- **SECURITY N/A** — no security-relevant surface touched.

## Gotchas
- The diff can expose a pre-existing vuln (e.g. new route into old unsafe code) — that counts as introduced by this diff.
- Parameterized queries built with f-string table/column names are still injection.
- "Internal only" services are not a mitigation unless enforced by the code/network config you can see.
- Check what the diff logs: new log lines are a common secrets leak.

## Attribution
The find-then-filter method, the confidence floor, and most of the exclusions and working assumptions are adapted from Anthropic's `security-review` command (https://github.com/anthropics/claude-code-security-review, MIT License, Copyright (c) 2025 Anthropic). Unlike that command, this skill still reviews new dependencies and secrets written to logs.
