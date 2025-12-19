Run complete audit pipeline from analysis to submission-ready reports
# Purpose
Orchestrate the full audit workflow: analyze, generate PoCs, write reports, and compile QA.

# Arguments
- `$ARGUMENTS` format: `<project-name>`
- Example: `pooltogether`

# Orchestration Flow

## 1. Confirm Project
Invoke **project-manager**: "Resolve and validate project"
- Verify project is registered
- Get scope and known issues
- Confirm ready for full audit

Present summary and confirm:
```
Full Audit: pooltogether
━━━━━━━━━━━━━━━━━━━━━━━━

Project: pooltogether
Submodule: lib/2025-01-pooltogether
Contracts in scope: 12
Known issues: 5

This will:
  1. Run full vulnerability analysis
  2. Generate PoCs for High/Medium findings
  3. Write submission reports
  4. Compile QA report for Low findings
  5. Review all findings before completion

Proceed? (Invoke to continue, or provide feedback)
```

## 2. Run Analysis
Execute `/analyze` orchestration:
- Invoke **vuln-scanner**: Scan all in-scope contracts
- Invoke **deduplicator**: Filter duplicates
- Invoke **sanitizer**: Remove known issues
- Invoke **severity-classifier**: Classify findings
- Invoke **finding-manager**: Store findings

Report progress:
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

## 3. Generate PoCs for High Findings
For each High finding:
- Invoke **poc-generator**: Create PoC
- Invoke **poc-validator**: Validate PoC
- Invoke **finding-manager**: Update status

Report progress:
```
PoC Generation: High Severity
─────────────────────────────
H-01 Reentrancy in claimPrize........... ✓ PASS
H-02 Flash loan manipulation............ ✓ PASS
H-03 Access control bypass.............. ⚠ FAILED (needs manual review)
```

## 4. Generate PoCs for Medium Findings
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

## 5. Write Reports for High/Medium
For each finding with passing PoC:
- Invoke **report-writer**: Generate report
- Invoke **report-validator**: Validate quality
- Invoke **finding-manager**: Update to submitted

Report progress:
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

## 6. Compile QA Report
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
QA report saved: reports/pooltogether/submissions/qa-report.md
```

## 7. Review All Findings
For each finding:
- Invoke **validity-checker**: Check for invalid patterns
- Invoke **severity-auditor**: Validate severity
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

## 8. Final Summary
Present complete audit results:
```
Full Audit Complete: pooltogether
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Submissions Ready:
  High:   2 reports (H-03 needs manual PoC)
  Medium: 6 reports (M-05 needs manual PoC)
  QA:     1 report (8 findings)

Files:
  reports/pooltogether/submissions/H-01-submission.md
  reports/pooltogether/submissions/H-02-submission.md
  reports/pooltogether/submissions/M-01-submission.md
  reports/pooltogether/submissions/M-02-submission.md
  reports/pooltogether/submissions/M-03-submission.md
  reports/pooltogether/submissions/M-04-submission.md
  reports/pooltogether/submissions/M-06-submission.md
  reports/pooltogether/submissions/M-07-submission.md
  reports/pooltogether/submissions/qa-report.md

Action Items:
  ⚠ H-03: Manual PoC needed - check reports/pooltogether/findings/high/H-03.json
  ⚠ M-05: Manual PoC needed - check reports/pooltogether/findings/medium/M-05.json
  ⚠ M-02: Review severity classification

Review all submissions before C4 submission deadline.
```

# Agent Delegation
This command orchestrates the full pipeline:
- **project-manager**: Project validation
- **vuln-scanner**: Vulnerability analysis
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
