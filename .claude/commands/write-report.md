Generate a C4-compliant submission report for a finding
# Purpose
Orchestrate creation of a professional, C4-compliant report ready for submission.

# Arguments
- `$ARGUMENTS` format: `<project-name> <finding-label>`
- Example: `pooltogether H-01`

# Orchestration Flow

## 1. Load Finding with PoC
Invoke **finding-manager**: "Get finding with PoC details"
- Look up finding by project and label
- Verify finding exists and has status "ready"
- If status is "needs-poc": Suggest `/generate-poc` first
- If status is "draft": Warn that PoC is required for H/M
- Load full finding details including attached PoC

## 2. Validate PoC Status
Invoke **poc-validator**: "Verify PoC still passes"
- Ensure PoC hasn't been broken by any changes
- If PoC fails: Report issue and suggest regeneration
- Get latest test output for report

## 3. Generate Report
Invoke **report-writer**: "Generate C4-compliant report"
- Create full report with sections:
  - Title: `[H-01] Clear vulnerability description`
  - Severity: High/Medium
  - Location: File#Line with link
  - Summary: 1-2 sentence overview
  - Vulnerability Details: Technical explanation with code
  - Impact: Concrete consequences
  - Proof of Concept: PoC in diff format
  - Recommended Mitigation: Practical fix

## 4. Validate Report
Invoke **report-validator**: "Check report meets C4 standards"
- Verify all required sections present
- Check professional quality (no LLM patterns)
- Validate severity justification
- Confirm PoC is included and formatted correctly
- Flag any issues for correction

## 5. Handle Validation Result
**If validation passes**:
- Save report to `reports/<project>/submissions/<label>-submission.md`
- Invoke **finding-manager**: "Update finding status to submitted"
- Present report for final review

**If validation fails**:
- Present specific issues found
- Suggest corrections
- Offer to regenerate with fixes
- Keep status as "ready"

## 6. Completion Report
**On Success**:
```
Report Generated: pooltogether H-01
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Status: VALIDATED
File: reports/pooltogether/submissions/H-01-submission.md

Quality Checks:
  ✓ All sections present
  ✓ Professional quality
  ✓ Severity justified
  ✓ PoC included and runnable

Finding status updated: ready → submitted

Review the report and submit to C4 when ready.
```

**On Validation Issues**:
```
Report Validation Issues: pooltogether H-01
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Issues Found:
  ⚠ Impact section lacks specific quantities
  ⚠ Mitigation could be more specific

Suggestions:
  - Add ETH amounts to impact statement
  - Provide code example for mitigation

Report saved as draft. Fix issues and regenerate.
```

# Agent Delegation
This command orchestrates report creation without writing content directly:
- **finding-manager**: Get finding details, update status
- **poc-validator**: Verify PoC status
- **report-writer**: Generate report content
- **report-validator**: Quality assurance

# Error Handling
- **Finding not found**: List available findings
- **No PoC**: Suggest `/generate-poc` first
- **PoC broken**: Suggest regeneration
- **Quality issues**: Report specific problems

# Examples
```
/write-report pooltogether H-01
# Generate submission report for H-01

/write-report aave-v4 M-03
# Generate submission report for M-03
```

# Critical Rules
1. **PoC required** for High/Medium findings
2. **Professional quality** - Match audit standards
3. **Accurate claims** - Don't overstate impact
4. **Complete sections** - All required sections filled
5. **Runnable PoC** - Must work with project test suite
