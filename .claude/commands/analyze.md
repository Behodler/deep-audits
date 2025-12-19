Run vulnerability analysis on target contracts
# Purpose
Orchestrate a comprehensive vulnerability scan of a project's in-scope contracts, filtering and classifying results.

# Arguments
- `$ARGUMENTS` format: `<project-name> [contract-path]`
- Example: `pooltogether` or `pooltogether src/PrizePool.sol`
- Project name is the friendly name from registration

# Orchestration Flow

## 1. Resolve Project
Invoke **project-manager**: "Resolve friendly name to submodule path"
- Look up in registered-projects.json
- If not found: List registered projects and suggest `/add-project`
- Get full path: `lib/<submodule-name>`

## 2. Get Scope and Known Issues
Invoke **project-manager**: "Get scope and known issues for project"
- Retrieve in-scope contract list
- Load known issues for later sanitization
- If contract-path specified in $ARGUMENTS: Filter scope to that contract

## 3. Code Vulnerability Scan
Invoke **code-scanner**: "Scan contracts for code-level vulnerabilities"
- Pass: project path, scope list
- Analyze each in-scope contract
- Identify code-level vulnerabilities:
  - Reentrancy
  - Access control
  - Integer issues
  - Storage/memory safety
  - External call risks
- Return raw findings list with confidence levels

## 4. Economic Vulnerability Scan
Invoke **econ-scanner**: "Scan contracts for economic vulnerabilities"
- Pass: project path, scope list, documentation
- Analyze economic design and incentives:
  - Intent verification (docs vs implementation)
  - Pricing/fee calculation errors
  - Oracle manipulation vectors
  - Flash loan attack surfaces
  - Incentive misalignments
  - MEV extraction paths
- Return raw findings list with economic impact

## 5. Deduplicate Findings
Invoke **deduplicator**: "Filter obvious and common issues from scan results"
- Combine findings from both code-scanner and econ-scanner
- Remove exact duplicates
- Consolidate findings with same root cause
- Filter low-value/common issues that add no insight
- Track consolidation reasoning

## 6. Sanitize Against Known Issues
Invoke **sanitizer**: "Remove issues matching known issues list"
- Compare findings against project's documented known issues
- Filter findings that duplicate known issues
- Flag partial matches for human review
- Document all removals with reasoning

## 7. Classify Severity
Invoke **severity-classifier**: "Classify findings by C4 severity"
- Apply C4 severity definitions:
  - High (3): Direct asset risk
  - Medium (2): Function/availability impact
  - Low/QA: State handling, centralization
- Document justification for each classification
- Flag borderline cases

## 8. Create Finding Records
Invoke **finding-manager**: "Create finding records for classified issues"
- Generate finding files in `reports/<project>/findings/`
- Assign labels (H-01, M-01, etc.)
- Set status to "draft" or "needs-poc"
- Store in appropriate severity subdirectory

## 9. Save Analysis Report
Save raw analysis to `reports/<project>/`:
- `analysis-<timestamp>.json`: Full scan results
- Include: scan metadata, findings count, filtering stats

## 10. Present Summary
Display to user:
```
Analysis Complete: pooltogether
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Contracts Scanned: 12
Raw Findings: 47
After Deduplication: 23
After Sanitization: 18

Classified Findings:
  High:   3
  Medium: 7
  Low:    8

Next Steps:
  /list-findings pooltogether
  /generate-poc pooltogether H-01
  /full-audit pooltogether
```

# Agent Delegation
This command orchestrates analysis without implementing scan logic:
- **project-manager**: Resolve names, get scope/known issues
- **code-scanner**: Identify code-level implementation bugs
- **econ-scanner**: Identify economic/game-theoretic vulnerabilities
- **deduplicator**: Filter duplicates and common issues
- **sanitizer**: Remove known issues
- **severity-classifier**: Apply C4 severity rules
- **finding-manager**: Store findings

# Error Handling
- **Unknown project**: Suggest registration
- **Empty scope**: Warn and offer to scan all .sol files
- **Scan failures**: Report specific contract errors
- **No findings**: Report clean scan (rare but possible)

# Examples
```
/analyze pooltogether
# Full analysis of all in-scope contracts

/analyze pooltogether src/PrizePool.sol
# Focused analysis of single contract

/analyze aave-v4 src/core/
# Analysis of contracts in specific directory
```

# Critical Rules
1. **Never modify source repos** during analysis
2. **Preserve all raw findings** before filtering
3. **Document every filtering decision**
4. **Flag uncertain classifications** for review
