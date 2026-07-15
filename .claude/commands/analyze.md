Run vulnerability analysis on target contracts
# Purpose
Orchestrate a comprehensive vulnerability scan of a project's in-scope contracts, filtering and classifying results. Self-audit of the Phoenix/Behodler suite; C4 conventions are an output spec, not a contest goal.

# Arguments
- `$ARGUMENTS` format: `<project-name> [contract-path] [--full]`
- Project name is the friendly name from registration (case-insensitive; normalized to lowercase-kebab).
- `--full` forces a cold scan of the entire scope. Without it, the run is a **regression scan** when a ledger exists (see step 3).
- Examples:
  - `phoenix-nft-staking` — regression scan if a ledger exists, else full
  - `phoenix-nft-staking --full` — cold scan of all in-scope contracts
  - `phoenix-nft-staking src/Staking.sol` — focused scan of one contract

# Orchestration Flow

## 1. Resolve Project
Invoke **project-manager**: "Resolve friendly name to submodule path"
- Normalize the name to lowercase-kebab, look up in `registered-projects.json`.
- If not found: list registered projects and suggest `/add-project`.
- Get `lib/<submodule>`, scope, and the current submodule git commit (`HEAD`).

## 1.5. Create Versioned Report Directory
Invoke **project-manager**: "Create versioned report directory for this audit run"
- Creates `reports/<project>-XX/` (next sequential, zero-padded). Legacy unversioned `reports/<project>/` counts as version 0.
- Store the versioned path for all subsequent steps. All findings, profiles, and submissions go under it.

## 2. Get Scope and Known Issues
Invoke **project-manager**: "Get scope and known issues for project"
- Retrieve the in-scope contract list and known issues (for sanitization).
- **Scope is default-in-scope (denylist):** the in-scope set is every first-party `.sol` minus `lib/**` and any project `outOfScope` globs — computed live, not read from an allowlist. New contracts are automatically in scope (see `registered-projects.json` → `scopePolicy`).
- If a contract-path is given, filter scope to it (an explicit user-supplied focus, distinct from the default).

## 3. Load Ledger and Determine Run Mode
Invoke **project-manager**: "Load the persistent ledger and compute changed files"
- Read `reports/ledgers/<project>.json` (the persistent findings ledger).
- Compute `changed_since(lastAuditedCommit, HEAD)` via read-only `git -C lib/<submodule> diff --name-only`.
- **Run mode:**
  - No ledger, or `--full` → **full scan** (entire scope).
  - Ledger present, no `--full` → **regression scan**: scanners still receive the full scope for context, but focus effort on changed files/functions and on previously-`open` findings.
- **New-in-scope files always get full attention.** `changed_since` returns a `newInScope` list — first-party contracts that changed and are not in the prior `scope` snapshot (e.g. a new migrator). These are **never** treated as out-of-scope or deferred to a confirmation: they are scanned as if cold, even in regression mode, and named explicitly in the run summary so the user sees them. Surfacing beats tidiness (Law 1).
- Pass the ledger (open/fixed/acknowledged fingerprints) and the changed-file set to downstream agents.
- Also invoke **project-manager** `get_story_intent` to resolve the `[story-NNN]` intents for the audited range (+ design docs / `CLAUDE.md` / `designDecisions`) for the **story-faithfulness** scanner (Law 2). Regression mode → the changed-commit range; `--full` → stories touching in-scope files.

```
Run Mode
────────
Ledger: reports/ledgers/phoenix-nft-staking.json (12 findings: 3 open, 7 fixed, 2 acknowledged)
Last audited commit: a1b2c3d
Changed since: src/Staking.sol, src/RewardVault.sol (2 files)
NEW in scope: src/InPlaceMigrator.sol (1 file — auto-included, scanned cold)
Mode: REGRESSION (focus on changed code + open findings) — use --full to force cold scan
```

## 4. Tier 1 — Parallel Local + Deterministic Analysis
Run these IN PARALLEL:

### 4a. Profile Contracts
Invoke **contract-profiler** for each in-scope contract (parallel where possible):
- Produce verified properties, local findings, interface abstractions, and trust assumptions.
- Output: `<report-dir>/profiles/`

### 4b. Static Analysis (Slither + Aderyn + Semgrep)
Invoke **static-analyzer**: "Run deterministic SAST and normalize findings"
- Runs Slither, Aderyn, and Semgrep over the contracts; filters noise; tags each finding with its `source`.
- Output: `<report-dir>/static-analysis-findings.json`

### 4c. Pattern Matching
Invoke **pattern-matcher**: "Match code against vulnerability patterns"
- Checks code against `patterns/vulnerability-patterns.json`.
- Output: `<report-dir>/pattern-matches.json`

**Why Tier 1 first**: downstream interaction scanners receive interface abstractions instead of raw source. This prevents over-ingestion, lets interaction analysis treat local properties as verified axioms, and surfaces local issues early.

```
Tier 1 — Local + Deterministic
───────────────────────────────
Profiles:   3 contracts (2 local findings)
Slither:    15 findings   Aderyn: 9   Semgrep: 4   (after filtering)
Patterns:   22 checked, 3 matches
```

## 5. Tier 2 — Interaction Analysis
Run these IN PARALLEL:

### 5a. Code Vulnerability Scan
Invoke **code-scanner**: "Scan for cross-contract code vulnerabilities"
- Works from profiles (trust verified properties; do not re-check local issues).
- Focus: cross-contract reentrancy, access-control chains, callback exploitation, call-sequence attacks, shared-state corruption.

### 5b. Economic Vulnerability Scan
Invoke **econ-scanner**: "Scan for cross-contract economic vulnerabilities"
- Works from profiles + documentation.
- Focus: intent vs implementation, cross-contract value leakage, oracle/flash-loan surfaces, incentive misalignment, MEV paths.

### 5c. Story-Faithfulness Scan (Law 2)
Invoke **story-faithfulness**: "Verify in-scope features implement the stories they derive from"
- Works from profiles + the resolved `[story-NNN]` intents + design docs.
- Checks (1) does the implementation conform to each story's acceptance criteria, and (2) **Law-1 override** — is the story's *own* intent unsafe? An unsafe story escalates to a security finding; a behavioural deviation becomes a faithfulness (`F-XX`) finding for the spec-conformance report.

## 6. Tier 3 — Property & Symbolic Verification (default)
Run these IN PARALLEL. Skippable for a fast pass via `--no-deep`, but they are part of the standard flow.

### 6a. Invariant + Stateful Fuzzing
Invoke **invariant-generator**: "Generate and run invariant tests"
- Generates property contracts from profiles; runs them under `forge test` (invariant) **and** a stateful fuzzer (Medusa primary, Echidna fallback).
- Any failing property → counterexample → High-severity finding.
- Output: `workspace/<project>/test/Invariant.t.sol`, `medusa.json`, `<report-dir>/invariant-results.json`

### 6b. Symbolic Analysis (Halmos)
Invoke **symbolic-analyzer**: "Generate and run Halmos symbolic tests"
- Targets pure arithmetic / share-price / fee functions from profiles.
- Counterexamples → High-severity findings.
- Output: `workspace/<project>/test/Symbolic.t.sol`, `<report-dir>/symbolic-results.json`
- **Honesty rule (do not skip):** only a Halmos `[PASS]` counts as "proven safe", and only
  over its recorded domain. `[TIMEOUT]`/`[ERROR]` prove nothing — they are recorded as
  `unverified`, never implied as verified. Timeouts on nonlinear 256-bit arithmetic are
  common and expected. If symbolic is skipped (no workspace, all-timeout, tool missing), the
  run **says so explicitly** — a missing `symbolic-results.json` must never be read as
  "verified clean". A report's safety claim must cite an actual `proofs[]` [PASS] artifact.

```
Tier 3 — Verification
─────────────────────
Invariants: 8 generated, 10k fuzz runs — 1 failure: invariant_noShareInflation
Symbolic:   5 tests — 3 proved (2 unbounded, 1 bounded <2^128), 1 counterexample, 1 TIMEOUT (unverified)
Note: fuzzing/symbolic did NOT prove the 1 timed-out property safe — carried to manual-review.
```

## 7. Deduplicate Findings
Invoke **deduplicator**: "Filter obvious and common issues from all sources"
- Combine: local findings (4a), static analysis (4b), pattern matches (4c), code findings (5a), economic findings (5b), story-faithfulness findings (5c), invariant/symbolic counterexamples (6).
- The pattern-matcher **`manualReview`** (low-confidence) list is **not** noise-filtered — preserve it to `<report-dir>/manual-review.json` as a visible parked channel for human / higher-tier adjudication (Law 1: recall beats tidiness).
- Remove exact duplicates, consolidate shared root causes, filter tool noise. Track source for the audit trail.

## 8. Sanitize Against Known Issues and Ledger
Invoke **sanitizer**: "Remove known issues, then reconcile against the ledger"
- First filter against the project's documented known issues.
- Then reconcile each remaining finding against `reports/ledgers/<project>.json` by fingerprint:
  - matches an `open` entry → mark **still-open**, bump `lastSeenRun`, do not regenerate a report
  - matches a `fix-pending` entry → **never suppress**; treat exactly like `open` (still-open + carryover stub). If the code changed since `lastAuditedCommit` and the finding survived, flag **⚠ FIX-PENDING STILL LIVE (possible incomplete fix)** — second only to REGRESSION in signal.
  - matches `acknowledged` / `wont-fix` / `false-positive` → suppress (like a known issue)
  - matches a `fixed` entry but reappears → flag **REGRESSION** (high priority)
  - no match → genuinely **new** finding
- Document every removal/reconciliation.

## 9. Classify Severity
Invoke **severity-classifier**: "Classify findings by C4 severity"
- High (3): direct asset risk. Medium (2): function/availability impact or value leak with stated assumptions. Low/QA: state handling, spec deviation, centralization.
- Document justification; flag borderline cases. REGRESSION findings inherit at least their prior severity.

## 10. Create Finding Records and Update Ledger
Invoke **finding-manager**: "Create finding records and upsert the ledger"
- Write findings to `<report-dir>/findings/<severity>/` with labels `H-01`, `M-01`, `L-01`, `C-01`, and **`F-01` faithfulness** (Law-2 deviations → `findings/faithfulness/`, compiled into `submissions/spec-conformance.md`, kept out of the QA bundle).
- Status `draft` or `needs-poc`. Tag new vs regressed vs still-open.
- For each **still-open** entry (all severities), write a thin carryover stub to `<report-dir>/submissions/carryover/<label>-CARRYOVER.md` linking back to its original report — so untriaged-but-unfixed findings never disappear from the run you review.
- Upsert `reports/ledgers/<project>.json`: add new entries, bump `lastSeenRun` for still-open, mark entries whose code changed and are no longer flagged as `fixed` at the current commit, set `lastAuditedCommit = HEAD`.

## 11. Save Analysis Report
Save raw analysis to `<report-dir>/analysis-<timestamp>.json` (scan metadata, counts, filtering + reconciliation stats).
- If a regression run surfaced no new/regressed findings, write a one-line `<report-dir>/NO-NEW-FINDINGS.md` instead of the full empty tree. **Carryover stubs are still written** in this case (step 10) — "no new findings" does not mean "no open findings"; the `NO-NEW-FINDINGS.md` note should point to `submissions/carryover/` when stubs exist.

## 12. Present Summary
```
Analysis Complete: phoenix-nft-staking
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Run: reports/phoenix-nft-staking-12/   Mode: REGRESSION (changed: 2 files)

Tier 1:  profiles 3 · slither 15 · aderyn 9 · semgrep 4 · patterns 3
Tier 2:  code 28 · econ 14
Tier 3:  1 invariant failure · 1 symbolic counterexample

Pipeline:
  Raw: 74 → Deduplicated: 30 → After known-issues: 24
  Ledger reconciliation: 18 still-open · 1 fix-pending · 2 acknowledged (suppressed) · 1 REGRESSION · 3 new

Classified (new + regressed only):
  High: 1 (1 REGRESSION)   Medium: 2   Low: 1

Carried over (still open from prior runs):  M-01, L-02, L-04
  → reports/phoenix-nft-staking-12/submissions/carryover/  (stubs link to original reports)

Output:  reports/phoenix-nft-staking-12/
Ledger:  reports/ledgers/phoenix-nft-staking.json (updated)

Next:
  /list-findings phoenix-nft-staking
  /generate-poc phoenix-nft-staking H-01
  /ledger phoenix-nft-staking
```

# Agent Delegation
- **project-manager**: resolve names, scope/known issues, ledger + changed-file computation, versioned dir
- **contract-profiler**: per-contract local analysis (Tier 1)
- **static-analyzer**: Slither + Aderyn + Semgrep (Tier 1)
- **pattern-matcher**: pattern database (Tier 1)
- **code-scanner** / **econ-scanner**: interaction analysis (Tier 2)
- **story-faithfulness**: story/spec conformance + unsafe-story escalation (Tier 2, Law 2)
- **invariant-generator** / **symbolic-analyzer**: property + symbolic verification (Tier 3)
- **deduplicator**: filter duplicates and common issues
- **sanitizer**: known issues + ledger reconciliation
- **severity-classifier**: C4 severity
- **finding-manager**: store findings, upsert ledger

## Tiered Analysis Architecture
```
TIER 1 (parallel)   contract-profiler · static-analyzer (Slither/Aderyn/Semgrep) · pattern-matcher
        │
TIER 2 (parallel)   code-scanner · econ-scanner · story-faithfulness   (consume profiles + story intents)
        │
TIER 3 (parallel)   invariant-generator (forge + medusa/echidna) · symbolic-analyzer (halmos)
        │
        ▼           deduplicator → sanitizer (+ledger) → severity-classifier → finding-manager (+ledger)
```

# Error Handling
- **Unknown project**: suggest registration.
- **Empty scope**: warn and offer to scan all `.sol` files.
- **Missing tool** (slither/aderyn/semgrep/halmos/medusa): note the gap, continue with available tools; suggest re-running the SessionStart setup.
- **Scan failures**: report the specific contract error and continue.

# Critical Rules
1. **Never modify source repos** during analysis (read-only `git diff` only).
2. **Preserve all raw findings** before filtering.
3. **Document every filtering and ledger-reconciliation decision.**
4. **Flag uncertain classifications and regressions** for review.
