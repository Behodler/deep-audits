Run complete audit pipeline from analysis to submission-ready reports
# Purpose
Orchestrate the full audit workflow: analyze, generate PoCs, write reports, and compile QA.

# Arguments
- `$ARGUMENTS` format: `<project-name> [bounty]`
- Example: `pooltogether` (regular audit)
- Example: `pooltogether bounty` (bounty mode)

# Mode Detection
Parse `$ARGUMENTS` to detect mode:
- If "bounty" present → **Bounty Mode**
- Otherwise → **Regular Audit Mode**

## Bounty Mode Differences
Per C4 bounty guidelines (`documentation/Bounties-*.md`):
- **Only Critical and High severity accepted** (no Medium, no QA/Low)
- **Coded runnable PoCs are mandatory** for all findings
- **No QA report** - Low/Centralization findings are discarded
- **$25 USDC deposit required** per submission (inform user)

# Orchestration Flow

## 1. Confirm Project
Invoke **project-manager**: "Resolve and validate project"
- Verify project is registered
- Get scope and known issues
- Confirm ready for full audit

## 1.2. Create Versioned Report Directory
Invoke **project-manager**: "Create versioned report directory for this audit run"
- Creates `reports/<project>-XX/` where XX is the next sequential version
- If unversioned `reports/<project>/` exists (legacy), treat as version 0
- First run (no existing directories) creates `reports/<project>-01/`
- Store the versioned path for use in all subsequent steps
- **All findings, PoCs, and submissions go under this versioned directory**

Present summary and confirm:
```
Full Audit: pooltogether
━━━━━━━━━━━━━━━━━━━━━━━━

Project: pooltogether
Submodule: lib/2025-01-pooltogether
Report Directory: reports/pooltogether-01/
Contracts in scope: 12
Known issues: 5
Mode: Regular Audit

This will:
  1. Run full vulnerability analysis
  2. Generate PoCs for High/Medium findings
  3. Write submission reports
  4. Compile QA report for Low findings
  5. Review all findings before completion

Proceed? (Invoke to continue, or provide feedback)
```

**If Bounty Mode:**
```
Full Audit: pooltogether (BOUNTY)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Project: pooltogether
Submodule: lib/2025-01-pooltogether
Report Directory: reports/pooltogether-01/
Contracts in scope: 12
Known issues: 5
Mode: BOUNTY

⚠️  BOUNTY MODE ACTIVE:
  • Only Critical/High severity findings accepted
  • All findings require runnable PoC (mandatory)
  • No QA report will be generated
  • Each submission requires $25 USDC deposit

This will:
  1. Run full vulnerability analysis (Critical/High only)
  2. Generate PoCs for ALL findings (mandatory)
  3. Write submission reports
  4. Review all findings before completion

Proceed? (Invoke to continue, or provide feedback)
```

## 1.5. Check for Cross-Mode Optimization
Invoke **finding-manager**: "Check if other mode has existing findings in this versioned directory"

**IMPORTANT**: Cross-mode import only looks **within the same versioned directory**.
- If running in `reports/pooltogether-01/`, only checks for other mode in `reports/pooltogether-01/`
- Does NOT import from previous versions (`reports/pooltogether/`, `reports/pooltogether-02/`, etc.)
- This ensures each audit run is isolated

**If cross-mode findings exist in same version:**
```
Cross-Mode Optimization Available
─────────────────────────────────
Existing bounty analysis found in reports/pooltogether-01/bounty/ with 3 findings.
These will seed your audit analysis (still running full scan).

Imported findings will be re-classified under audit criteria.
```

**Decision Tree:**
- Running **bounty** + **audit** exists in same version → Import audit High findings as candidates
- Running **audit** + **bounty** exists in same version → Import bounty Critical/High as candidates
- Neither exists in this version → Fresh analysis

This optimization saves time by not re-discovering issues the other mode already found,
while still running the full scan to catch mode-specific issues.

## 2. Run Analysis
Execute `/analyze` orchestration:
- Invoke **code-scanner**: Scan for code-level vulnerabilities
- Invoke **econ-scanner**: Scan for economic vulnerabilities
- Invoke **deduplicator**: Filter duplicates
- Invoke **sanitizer**: Remove known issues
- Invoke **severity-classifier**: Classify findings (pass `mode: bounty` if bounty mode)
- Invoke **finding-manager**: Store findings

Report progress (Regular Audit):
```
Analysis Phase
──────────────
Scanning contracts... done
Raw findings: 47
After deduplication: 23
After sanitization: 18

Classified:
  High: 3
  Medium: 7
  Low: 8
```

Report progress (Bounty Mode):
```
Analysis Phase (BOUNTY)
───────────────────────
Scanning contracts... done
Raw findings: 47
After deduplication: 23
After sanitization: 18

Classified (Critical/High only):
  Critical: 1
  High: 2
  ⚠️ Discarded: 15 (Medium/Low not accepted in bounties)
```

## 3. Generate PoCs for Critical Findings (Bounty Mode Only)
**Skip this step in Regular Audit mode.**

For each Critical finding (bounty mode):
- Invoke **poc-generator**: Create PoC
- Invoke **poc-validator**: Validate PoC
- Invoke **finding-manager**: Update status
- **CRITICAL**: PoC is mandatory - finding cannot be submitted without passing PoC

Report progress:
```
PoC Generation: Critical Severity (MANDATORY)
─────────────────────────────────────────────
CRIT-01 Protocol insolvency via....... ✓ PASS
```

## 4. Generate PoCs for High Findings
For each High finding:
- Invoke **poc-generator**: Create PoC
- Invoke **poc-validator**: Validate PoC
- Invoke **finding-manager**: Update status
- **BOUNTY MODE**: PoC is mandatory - finding cannot be submitted without passing PoC

Report progress:
```
PoC Generation: High Severity
─────────────────────────────
H-01 Reentrancy in claimPrize........... ✓ PASS
H-02 Flash loan manipulation............ ✓ PASS
H-03 Access control bypass.............. ⚠ FAILED (needs manual review)
```

## 5. Generate PoCs for Medium Findings (Regular Audit Only)
**Skip this step in Bounty Mode** - Medium severity not accepted.

For each Medium finding:
- Invoke **poc-generator**: Create PoC
- Invoke **poc-validator**: Validate PoC
- Invoke **finding-manager**: Update status

Report progress:
```
PoC Generation: Medium Severity
───────────────────────────────
M-01 Missing slippage protection........ ✓ PASS
M-02 Oracle staleness................... ✓ PASS
M-03 Unbounded loop.................... ✓ PASS
M-04 Front-running vulnerability........ ✓ PASS
M-05 Timestamp dependence............... ⚠ FAILED
M-06 Unsafe downcast................... ✓ PASS
M-07 Missing access control............. ✓ PASS
```

## 6. Write Reports for Critical/High (Bounty) or High/Medium (Audit)
For each finding with passing PoC:
- Invoke **report-writer**: Generate report
- Invoke **report-validator**: Validate quality
- Invoke **finding-manager**: Update to submitted

Report progress (Regular Audit):
```
Report Generation
─────────────────
H-01 Submission report.................. ✓ VALID
H-02 Submission report.................. ✓ VALID
M-01 Submission report.................. ✓ VALID
M-02 Submission report.................. ✓ VALID
M-03 Submission report.................. ✓ VALID
M-04 Submission report.................. ✓ VALID
M-06 Submission report.................. ✓ VALID
M-07 Submission report.................. ✓ VALID
```

Report progress (Bounty Mode):
```
Report Generation (BOUNTY)
──────────────────────────
CRIT-01 Submission report............... ✓ VALID
H-01 Submission report.................. ✓ VALID
H-02 Submission report.................. ✓ VALID

⚠️ Reminder: Each submission requires $25 USDC deposit
```

## 7. Compile QA Report (Regular Audit Only)
**Skip this step in Bounty Mode** - QA/Low findings not accepted.

Invoke **qa-bundler**: "Compile Low and Centralization findings"
- Bundle all Low severity findings
- Include all Centralization risks
- Format as single QA report
- Save to submissions directory

```
QA Report Generation
────────────────────
Low findings included: 5
Centralization findings: 3
QA report saved: reports/pooltogether-01/audit/submissions/qa-report.md
```

## 8. Review All Findings
For each finding:
- Invoke **validity-checker**: Check for invalid patterns
- Invoke **severity-auditor**: Validate severity (use bounty criteria if bounty mode)
- Flag any concerns

```
Final Review
────────────
H-01 ✓ Valid, severity confirmed
H-02 ✓ Valid, severity confirmed
M-01 ✓ Valid, severity confirmed
M-02 ⚠ Severity questioned (might be Low)
...
```

## 9. Final Summary
Present complete audit results:

**Regular Audit:**
```
Full Audit Complete: pooltogether
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Submissions Ready:
  High:   2 reports (H-03 needs manual PoC)
  Medium: 6 reports (M-05 needs manual PoC)
  QA:     1 report (8 findings)

Output Directory: reports/pooltogether-01/audit/

C4 Form Mapping:
┌──────────────────────────────────────────────────────────────────────────┐
│ For each H/M finding, copy content to C4 form fields:                    │
│   Title          → from metadata comment in submission.md                │
│   Root Cause Link→ from metadata comment in submission.md                │
│   Details        → paste submission.md content (without metadata)        │
│   PoC            → paste poc.t.sol content (standalone, ready to run)    │
└──────────────────────────────────────────────────────────────────────────┘

Files:
  Submissions (Details field):
    reports/pooltogether-01/audit/submissions/H-01-submission.md
    reports/pooltogether-01/audit/submissions/H-02-submission.md
    reports/pooltogether-01/audit/submissions/M-01-submission.md
    ...
    reports/pooltogether-01/audit/submissions/qa-report.md

  PoCs (PoC field - standalone):
    reports/pooltogether-01/audit/pocs/H-01-poc.t.sol
    reports/pooltogether-01/audit/pocs/H-02-poc.t.sol
    reports/pooltogether-01/audit/pocs/M-01-poc.t.sol
    ...

Action Items:
  ⚠ H-03: Manual PoC needed - check reports/pooltogether-01/audit/findings/high/H-03.json
  ⚠ M-05: Manual PoC needed - check reports/pooltogether-01/audit/findings/medium/M-05.json
  ⚠ M-02: Review severity classification

Review all submissions before C4 submission deadline.
```

**Bounty Mode:**
```
Full Audit Complete: pooltogether (BOUNTY)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Submissions Ready:
  Critical: 1 report
  High:     2 reports

Output Directory: reports/pooltogether-01/bounty/

C4 Form Mapping:
┌──────────────────────────────────────────────────────────────────────────┐
│ For each finding, copy content to C4 bounty form fields:                 │
│   Title          → from metadata comment in submission.md                │
│   Root Cause Link→ from metadata comment in submission.md                │
│   Details        → paste submission.md content (without metadata)        │
│   PoC            → paste poc.t.sol content (standalone, ready to run)    │
└──────────────────────────────────────────────────────────────────────────┘

⚠️ BOUNTY SUBMISSION REQUIREMENTS:
  • $25 USDC deposit per finding to 0xB592d203fd9f55CC4746172A92E35baBA1046a14
  • Submit via bounty form at code4rena.com/bounties
  • Cannot edit after submission
  • Results announced in #c4-bounties Discord channel

Files:
  Submissions (Details field):
    reports/pooltogether-01/bounty/submissions/CRIT-01-submission.md
    reports/pooltogether-01/bounty/submissions/H-01-submission.md
    reports/pooltogether-01/bounty/submissions/H-02-submission.md

  PoCs (PoC field - standalone, mandatory):
    reports/pooltogether-01/bounty/pocs/CRIT-01-poc.t.sol
    reports/pooltogether-01/bounty/pocs/H-01-poc.t.sol
    reports/pooltogether-01/bounty/pocs/H-02-poc.t.sol

Total deposit required: $75 USDC (3 findings × $25)

Review all submissions before submitting - deposits are non-refundable if judged unsatisfactory.
```

# Agent Delegation
This command orchestrates the full pipeline:
- **project-manager**: Project validation
- **code-scanner**: Code-level vulnerability analysis
- **econ-scanner**: Economic vulnerability analysis
- **deduplicator**: Duplicate filtering
- **sanitizer**: Known issue removal
- **severity-classifier**: Severity assignment
- **finding-manager**: Finding storage
- **poc-generator**: PoC creation
- **poc-validator**: PoC validation
- **report-writer**: Report generation
- **report-validator**: Quality assurance
- **validity-checker**: Invalid pattern detection
- **severity-auditor**: Severity validation
- **qa-bundler**: QA report compilation

# Error Handling
- **Analysis failures**: Continue with partial results
- **PoC failures**: Flag for manual review, continue
- **Report issues**: Flag for review, continue
- **Keep going**: Don't stop on individual failures

# Critical Rules
1. **Complete the pipeline** - Don't stop on failures
2. **Flag issues clearly** - User can address manually
3. **Preserve all work** - Even partial results
4. **Final review** - Catch issues before submission
