Validate a finding before submission
# Purpose
Orchestrate comprehensive validation of a finding to catch issues before C4 submission.

# Arguments
- `$ARGUMENTS` format: `<project-name> <finding-label>`
- Example: `pooltogether H-01`

# Orchestration Flow

## 1. Load Finding
Invoke **finding-manager**: "Get complete finding details"
- Look up finding by project and label
- Load all finding data: description, severity, PoC, report
- Get current status

## 2. Validity Check
Invoke **validity-checker**: "Verify finding is not a known invalid type"
- Check for C4 invalid patterns:
  - Non-standard ERC-20 (except USDT)
  - Fee-on-transfer assumptions
  - Approve race condition
  - User input mistakes
  - Reckless admin assumptions
  - CryptoPunks support
- Check scope:
  - Finding in in-scope contract?
  - Root cause in OOS parent contract?
- Report any validity concerns

## 3. Severity Audit
Invoke **severity-auditor**: "Validate severity classification"
- Independent severity assessment
- Compare against C4 definitions:
  - High: Direct asset risk, no hypotheticals
  - Medium: Function/availability impact, stated assumptions
  - Low: State handling, centralization
- Check for overstatement
- Document agreement/disagreement with reasoning

## 4. PoC Validation
Invoke **poc-validator**: "Verify PoC still passes"
- Run PoC test
- Verify it demonstrates claimed impact
- Check test would fail if vulnerability fixed
- Report any PoC issues

## 5. Report Validation
Invoke **report-validator**: "Check submission quality"
- Verify all sections present
- Check professional quality
- Validate severity justification
- Confirm PoC formatted correctly
- Flag any LLM-pattern concerns

## 6. Compile Review Results
Aggregate all validation results:
```
Finding Review: pooltogether H-01
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Validity Check:
  ✓ Not a known invalid pattern
  ✓ In scope
  ✓ No OOS root cause

Severity Audit:
  Claimed: High
  Assessed: High
  ✓ Agreement - Direct asset theft confirmed

PoC Validation:
  ✓ Compiles successfully
  ✓ Test passes
  ✓ Demonstrates claimed impact
  ✓ Fails when fixed

Report Quality:
  ✓ All sections present
  ✓ Professional quality
  ✓ Severity justified
  ✓ PoC included

Overall Status: READY FOR SUBMISSION
```

## 7. Handle Issues
**If issues found**:
```
Finding Review: pooltogether H-02
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Validity Check:
  ✓ Not a known invalid pattern
  ✓ In scope

Severity Audit:
  Claimed: High
  Assessed: Medium
  ⚠ DISAGREEMENT
  Reason: Attack requires oracle staleness (external condition)
  Recommendation: Consider downgrading to Medium

PoC Validation:
  ✓ Test passes

Report Quality:
  ⚠ Impact section lacks specific quantities

Issues Found: 2
  1. Severity may be overstated (High → Medium)
  2. Report impact needs more detail

Actions:
  - Review severity classification
  - Add specific ETH amounts to impact
  - Regenerate report with /write-report
```

# Agent Delegation
This command orchestrates validation without implementing checks:
- **finding-manager**: Get finding details
- **validity-checker**: Check for invalid patterns
- **severity-auditor**: Independent severity review
- **poc-validator**: Verify PoC works
- **report-validator**: Quality assurance

# Error Handling
- **Finding not found**: List available findings
- **No PoC**: Note as issue, suggest generation
- **No report**: Note as issue, suggest writing

# Examples
```
/review-finding pooltogether H-01
# Full validation of H-01 before submission

/review-finding aave-v4 M-03
# Review medium-severity finding
```

# Critical Rules
1. **Check all aspects** - Validity, severity, PoC, report
2. **Flag disagreements** - Don't hide severity concerns
3. **Be thorough** - Catch issues before C4 judges do
4. **Document reasoning** - Clear explanation for all flags
