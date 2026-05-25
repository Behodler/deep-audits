Generate a C4-compliant submission report for a finding
# Purpose
Orchestrate creation of a professional, C4-compliant report ready for submission. The output maps directly to C4's submission form fields.

# Arguments
- `$ARGUMENTS` format: `<project-name> <finding-label>`
- Example: `pooltogether H-01`

# C4 Submission Form Fields
The C4 form has these separate fields that we generate content for:

| Form Field | Generated Content |
|------------|-------------------|
| **Title** | `[H-01] Clear vulnerability description` |
| **Link to root cause** | GitHub URL to vulnerable code |
| **Details** | Report body (see structure below) |
| **PoC** | Foundry test code (workspace-integrated, or standalone) |

# Orchestration Flow

## 1. Resolve report dir and load finding
Invoke **project-manager**: "Get the latest versioned report dir for the project" → `<report-dir>` (e.g. `reports/nft-staking-12/`).
Invoke **finding-manager**: "Get finding with PoC details"
- Look up finding by project and label
- Verify finding exists and has status "ready"
- If status is "needs-poc": Suggest `/generate-poc` first
- If status is "draft": Warn that PoC is required for H/M
- Load full finding details including attached PoC path

## 2. Validate PoC passes
Invoke **poc-validator**: "Verify the PoC compiles and passes"
- Run the PoC (workspace: `forge test --match-path test/poc-<label>.t.sol`; standalone: fresh forge env).
- Ensure all tests pass. If it fails: report the issue and suggest `/generate-poc` to regenerate.

## 3. Generate Report (Details Field)
Invoke **report-writer**: "Generate C4-compliant report"
- Create report body with EXACTLY TWO main sections:
  - `## Finding description and impact`
  - `## Recommended mitigation steps`
- **NO** top-level `#` headings (title is separate form field)
- **NO** inline PoC code (PoC is separate form field)
- All subheadings must be `###` or lower
- Include metadata comment at top with Title and Root Cause Link

## 4. Validate Report Format
Invoke **report-validator**: "Check report meets C4 standards"
- Verify EXACTLY two `##` headings present
- Check NO `#` headings in body
- Verify NO inline PoC code blocks
- Check professional quality (no LLM patterns)
- Validate severity justification
- Confirm metadata comment present

## 5. Handle Validation Result
**If validation passes**:
- Save report to `<report-dir>/submissions/<label>-submission.md`
- Verify the PoC exists (workspace `workspace/<project>/test/poc-<label>.t.sol`, or standalone `<report-dir>/pocs/<label>-poc.t.sol`)
- Invoke **finding-manager**: "Update finding status to submitted"
- Present summary for final review

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

C4 Form Fields Ready:
┌─────────────────────────────────────────────────────────────┐
│ Title: [H-01] Reentrancy in claimPrize drains prize pool    │
├─────────────────────────────────────────────────────────────┤
│ Root Cause Link:                                            │
│ https://github.com/code-423n4/.../PrizePool.sol#L240-L252   │
├─────────────────────────────────────────────────────────────┤
│ Details: reports/pooltogether/submissions/H-01-submission.md│
├─────────────────────────────────────────────────────────────┤
│ PoC: reports/pooltogether/pocs/H-01-poc.t.sol               │
└─────────────────────────────────────────────────────────────┘

Quality Checks:
  ✓ Details format correct (## headings only)
  ✓ No inline PoC in details
  ✓ PoC is standalone (only forge-std import)
  ✓ PoC tests pass
  ✓ Professional quality

Finding status updated: ready → submitted

Copy content from each file into corresponding C4 form field.
```

**On Validation Issues**:
```
Report Validation Issues: pooltogether H-01
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Issues Found:
  ✗ PoC has external imports (not standalone)
  ✗ Details contains inline PoC code
  ⚠ Impact section lacks specific quantities

Required Actions:
  - Run `/generate-poc pooltogether H-01` to create standalone PoC
  - Remove PoC code block from details
  - Add ETH amounts to impact statement

Report NOT saved. Fix issues and regenerate.
```

# Details Field Structure (CRITICAL)
The Details body MUST have exactly this structure:

```markdown
<!--
C4 Submission Metadata
Title: [H-01] Vulnerability title here
Root Cause Link: https://github.com/code-423n4/.../Contract.sol#L100-L150
PoC File: H-01-poc.t.sol
-->

## Finding description and impact

### Summary
Brief 1-2 sentence description.

### Vulnerability details
Technical explanation with code snippets showing the vulnerable pattern.

### Impact
Concrete consequences with quantified amounts where possible.

## Recommended mitigation steps

Practical fix with code example.
```

# Agent Delegation
This command orchestrates report creation without writing content directly:
- **finding-manager**: Get finding details, update status
- **poc-validator**: Verify PoC is standalone and passes
- **report-writer**: Generate report content
- **report-validator**: Quality assurance

# Error Handling
- **Finding not found**: List available findings
- **No PoC**: Suggest `/generate-poc` first
- **PoC not standalone**: Require regeneration with standalone template
- **PoC tests fail**: Suggest fix and regeneration
- **Format issues**: Report specific problems with fix suggestions

# Examples
```
/write-report pooltogether H-01
# Generate submission report for H-01

/write-report aave-v4 M-03
# Generate submission report for M-03
```

# Critical Rules
1. **PoC must be standalone** - Only forge-std import allowed
2. **PoC tests must pass** - No broken tests
3. **Details has two sections only** - `## Finding description and impact` and `## Recommended mitigation steps`
4. **No # headings** - Title goes in form field, not details
5. **No inline PoC** - PoC is separate form field
6. **Professional quality** - Match audit standards
7. **Accurate claims** - Don't overstate impact
