List findings for a project with optional filtering
# Purpose
Display current findings organized by severity and status.

# Arguments
- `$ARGUMENTS` format: `<project-name> [status]`
- Example: `pooltogether` or `pooltogether ready`
- Status options: draft, needs-poc, ready, submitted, all

# Orchestration Flow

## 1. Resolve Project
Invoke **project-manager**: "Resolve friendly name"
- Look up in registered-projects.json
- If not found: List registered projects

## 2. Get Findings
Invoke **finding-manager**: "List findings with filters"
- Get all findings for project
- Apply status filter if provided
- Group by severity (High, Medium, Low/QA)

## 3. Display Results
Present formatted list:
```
Findings: pooltogether
━━━━━━━━━━━━━━━━━━━━━━

High Severity (3)
─────────────────
H-01 [ready]     Reentrancy in claimPrize allows draining prize pool
H-02 [needs-poc] Flash loan manipulation of prize calculation
H-03 [draft]     Access control bypass in admin functions

Medium Severity (4)
───────────────────
M-01 [submitted] Missing slippage protection in swap
M-02 [ready]     Oracle staleness not checked
M-03 [needs-poc] Unbounded loop in batch claim
M-04 [draft]     Front-running vulnerability in auction

Low/QA (6)
──────────
L-01 [ready]     Missing zero-address check
L-02 [ready]     Event not emitted for fee change
C-01 [ready]     Owner can pause indefinitely
C-02 [ready]     No timelock on parameter changes
L-03 [draft]     Inconsistent error messages
L-04 [draft]     Missing natspec documentation

Summary
───────
Total: 13
  By Severity:  High: 3 | Medium: 4 | Low/QA: 6
  By Status:    draft: 4 | needs-poc: 2 | ready: 6 | submitted: 1

Next Steps:
  /generate-poc pooltogether H-02
  /write-report pooltogether H-01
  /review-finding pooltogether H-01
```

## 4. Filtered Views
**Status filter applied**:
```
/list-findings pooltogether ready

Findings: pooltogether (status: ready)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

High Severity
─────────────
H-01 [ready] Reentrancy in claimPrize allows draining prize pool

Medium Severity
───────────────
M-02 [ready] Oracle staleness not checked

Low/QA
──────
L-01 [ready] Missing zero-address check
L-02 [ready] Event not emitted for fee change
C-01 [ready] Owner can pause indefinitely
C-02 [ready] No timelock on parameter changes

Total Ready: 6

Next Steps:
  /write-report pooltogether H-01
  /review-finding pooltogether H-01
```

## 5. Empty Results
**No findings**:
```
Findings: pooltogether
━━━━━━━━━━━━━━━━━━━━━━

No findings recorded yet.

Next Steps:
  /analyze pooltogether
```

**No findings matching filter**:
```
Findings: pooltogether (status: submitted)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

No submitted findings.

Total findings: 13 (use /list-findings pooltogether all to see all)
```

# Agent Delegation
This command orchestrates listing without implementing storage logic:
- **project-manager**: Resolve project name
- **finding-manager**: Query and format findings

# Status Descriptions
- **draft**: Initial finding, needs refinement
- **needs-poc**: Validated but needs proof of concept
- **ready**: PoC attached, ready for report/submission
- **submitted**: Report generated, ready for C4

# Error Handling
- **Unknown project**: List registered projects
- **Invalid status**: List valid status options
- **No findings**: Suggest `/analyze`

# Examples
```
/list-findings pooltogether
# All findings for pooltogether

/list-findings pooltogether needs-poc
# Only findings needing PoC

/list-findings aave-v4 ready
# Ready findings for aave-v4
```
