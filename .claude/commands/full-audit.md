Run complete audit pipeline from analysis to submission-ready reports
# Purpose
Orchestrate the full self-audit workflow end to end: analyze, generate PoCs, write reports, and compile QA. Output follows C4 conventions as a quality spec.

# Arguments
- `$ARGUMENTS` format: `<project-name> [--full]`
- Project name is the friendly name from registration (case-insensitive).
- `--full` forces a cold scan; otherwise re-runs are regression scans against the ledger (see `/analyze`).

# Orchestration Flow

## 1. Confirm Project
Invoke **project-manager**: "Resolve and validate project"
- Verify the project is registered; get scope, known issues, and the current submodule commit.

## 1.2. Create Versioned Report Directory
Invoke **project-manager**: "Create versioned report directory for this audit run"
- Creates `reports/<project>-XX/` (next sequential version). Store the path for all steps.

## 1.3. Setup Workspace (If Not Exists)
Invoke **project-manager**: "Check if workspace exists, create if needed"
- If `workspace/<project>/` is absent: shallow-clone from the submodule URL and remove the remote.
- **Why**: source repos in `lib/` are read-only, but PoCs and Tier-3 tests need project infrastructure (harnesses, mocks, fork config). PoCs/tests are written to `workspace/<project>/test/`.

Present a summary and confirm:
```
Full Audit: phoenix-nft-staking
━━━━━━━━━━━━━━━━━━━━━━━
Submodule:   lib/phoenix-nft-staking
Report dir:  reports/phoenix-nft-staking-12/
Workspace:   workspace/phoenix-nft-staking/
Scope:       6 contracts        Known issues: 5
Ledger:      3 open · 7 fixed · 2 acknowledged
Run mode:    REGRESSION (2 files changed) — pass --full for a cold scan

This will: analyze → generate PoCs (High/Medium) → write reports → compile QA → final review.
Proceed? (Invoke to continue, or provide feedback)
```

## 2. Run Analysis
Execute the `/analyze` orchestration (Tier 1 → Tier 3 → dedup → sanitize+ledger → classify → store). See `analyze.md` for the full step list.

```
Analysis Phase
──────────────
Mode: REGRESSION (changed: src/Staking.sol, src/RewardVault.sol)
Raw 74 → dedup 30 → known-issues 24 → ledger: 18 still-open, 2 suppressed, 1 REGRESSION, 3 new
Classified (new + regressed): High 1 · Medium 2 · Low 1
```

## 3. Generate PoCs for High Findings
For each High finding (new or regressed):
- Invoke **poc-generator**: create PoC (workspace-first).
- Invoke **poc-validator**: validate it compiles and passes.
- Invoke **finding-manager**: update status.

```
PoC Generation: High
────────────────────
H-01 Reward debt drain (REGRESSION) ... ✓ PASS
```

## 4. Generate PoCs for Medium Findings
For each Medium finding: poc-generator → poc-validator → finding-manager (as above).

## 5. Write Reports for High/Medium
For each finding with a passing PoC:
- Invoke **report-writer**: generate the submission report.
- Invoke **report-validator**: validate quality.
- Invoke **finding-manager**: update to submitted.

```
Report Generation
─────────────────
H-01 ✓ VALID   M-01 ✓ VALID   M-02 ✓ VALID
```

## 6. Compile QA Report
Invoke **qa-bundler**: "Compile Low and Centralization findings"
- Bundle Low + Centralization findings into a single QA report.
- Run **4naly3er** and attach its automated QA/gas markdown to the bundle.
- Save to `<report-dir>/submissions/qa-report.md`.

## 7. Final Review
For each finding: invoke **validity-checker** (invalid patterns) and **severity-auditor** (severity sanity). Flag concerns.

```
Final Review
────────────
H-01 ✓ valid, severity confirmed (regression — was fixed in phoenix-nft-staking-08)
M-02 ⚠ severity questioned (might be Low)
```

## 8. Final Summary
```
Full Audit Complete: phoenix-nft-staking
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Run: reports/phoenix-nft-staking-12/   Mode: REGRESSION

Submissions ready:
  High:   1 report (1 regression)
  Medium: 2 reports
  QA:     1 report (Low + Centralization + 4naly3er output)
  Carryover: 3 still-open from prior runs (M-01, L-02, L-04) — stubs in submissions/carryover/

Reports:  reports/phoenix-nft-staking-12/submissions/*.md
PoCs:     workspace/phoenix-nft-staking/test/poc-*.t.sol
Ledger:   reports/ledgers/phoenix-nft-staking.json (updated)

Action items:
  ⚠ M-02: review severity classification
  ⚠ H-01: REGRESSION of a finding marked fixed in phoenix-nft-staking-08 — confirm the fix regressed

Triage: record decisions with /ledger phoenix-nft-staking (ack / fixed / reopen).
```

# Agent Delegation
project-manager · contract-profiler · static-analyzer · pattern-matcher · code-scanner · econ-scanner · invariant-generator · symbolic-analyzer · deduplicator · sanitizer · severity-classifier · finding-manager · poc-generator · poc-validator · report-writer · report-validator · qa-bundler · validity-checker · severity-auditor

# Error Handling
- **Analysis failures**: continue with partial results.
- **PoC failures**: flag for manual review, continue.
- **Report issues**: flag for review, continue.
- **Missing tools**: note the gap, continue with what's available.
- **Keep going**: don't stop on individual failures.

# Critical Rules
1. **Complete the pipeline** — don't stop on failures.
2. **Flag issues clearly** — the user can address them manually.
3. **Preserve all work** — even partial results.
4. **Surface regressions prominently** — a reappearing fixed bug is the highest-signal finding.
