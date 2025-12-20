Run vulnerability analysis on target contracts
# Purpose
Orchestrate a comprehensive vulnerability scan of a project's in-scope contracts, filtering and classifying results.

# Arguments
- `$ARGUMENTS` format: `<project-name> [contract-path] [bounty]`
- Example: `pooltogether` (regular audit, all contracts)
- Example: `pooltogether src/PrizePool.sol` (regular audit, single contract)
- Example: `pooltogether bounty` (bounty mode, all contracts)
- Example: `pooltogether src/PrizePool.sol bounty` (bounty mode, single contract)
- Project name is the friendly name from registration

# Mode Detection
Parse `$ARGUMENTS` to detect mode:
- If "bounty" present → **Bounty Mode**
- Otherwise → **Regular Audit Mode**

## Bounty Mode Differences
Per C4 bounty guidelines (`documentation/Bounties-*.md`):
- **Only Critical and High severity classified** (Medium/Low discarded)
- Uses bounty-specific severity criteria (see severity-classifier)
- Findings must meet "high likelihood" requirement for Critical

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

## 2.5. Check for Cross-Mode Findings (Optimization)
Invoke **finding-manager**: "Check if other mode has existing findings"

**If other mode exists:**
```
Cross-Mode Detection
────────────────────
Existing analysis found: reports/pooltogether/audit/
  High findings: 3
  Medium findings: 7
  Low findings: 8

These will be used as seed candidates for bounty classification.
Full scan will still run to catch additional issues.
```

**Decision Tree:**
1. Running **bounty** and **audit** exists:
   - Invoke **finding-manager**: "Import High findings from audit as bounty candidates"
   - These become input for severity-classifier (may become Critical or High)
   - Still run full code-scanner and econ-scanner (audit may have missed bounty-relevant issues)

2. Running **audit** and **bounty** exists:
   - Invoke **finding-manager**: "Import Critical/High findings from bounty as audit High candidates"
   - Still run full analysis (need Medium/Low/QA that bounty doesn't have)

3. No other mode exists:
   - Proceed with fresh analysis

**Important**: Cross-mode import seeds the classifier but does NOT skip scanning. The other mode's findings inform but don't replace the full analysis.

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
- Pass `mode: bounty` if bounty mode active

**Regular Audit Mode:**
- Apply C4 severity definitions:
  - High (3): Direct asset risk
  - Medium (2): Function/availability impact
  - Low/QA: State handling, centralization
- Document justification for each classification
- Flag borderline cases

**Bounty Mode:**
- Apply C4 bounty severity definitions:
  - Critical: High impact + high likelihood (see documentation/Bounties-Severity.md)
  - High: High impact, any likelihood (unclaimed yield, temporary freezing)
  - Discard: All Medium/Low findings (not accepted in bounties)
- Document justification for each classification
- Flag borderline Critical vs High cases

## 8. Create Finding Records
Invoke **finding-manager**: "Create finding records for classified issues"
- Generate finding files in `reports/<project>/<mode>/findings/`
  - Audit: `reports/<project>/audit/findings/`
  - Bounty: `reports/<project>/bounty/findings/`
- Assign labels (H-01, M-01, CRIT-01, etc.)
- Set status to "draft" or "needs-poc"
- Store in appropriate severity subdirectory
- If imported from other mode, link to source finding in metadata

## 9. Save Analysis Report
Save raw analysis to `reports/<project>/<mode>/`:
- `analysis-<timestamp>.json`: Full scan results
- Include: scan metadata, findings count, filtering stats, cross-mode import stats

## 10. Present Summary
Display to user:

**Regular Audit (fresh):**
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

Output: reports/pooltogether/audit/

Next Steps:
  /list-findings pooltogether
  /generate-poc pooltogether H-01
  /full-audit pooltogether
```

**Regular Audit (with bounty cross-mode):**
```
Analysis Complete: pooltogether
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Cross-Mode: Imported 3 findings from bounty analysis
Contracts Scanned: 12
Raw Findings: 47 (+ 3 imported)
After Deduplication: 25
After Sanitization: 20

Classified Findings:
  High:   4 (1 from bounty CRIT-01, 1 from bounty H-01)
  Medium: 8
  Low:    8

Output: reports/pooltogether/audit/

Next Steps:
  /list-findings pooltogether
  /generate-poc pooltogether H-01
  /full-audit pooltogether
```

**Bounty Mode (fresh):**
```
Analysis Complete: pooltogether (BOUNTY)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Contracts Scanned: 12
Raw Findings: 47
After Deduplication: 23
After Sanitization: 18

Classified Findings (Critical/High only):
  Critical: 1
  High:     2
  ⚠️ Discarded: 15 (Medium/Low not accepted)

Output: reports/pooltogether/bounty/

⚠️ BOUNTY REQUIREMENTS:
  • PoC mandatory for ALL findings
  • $25 USDC deposit per submission

Next Steps:
  /list-findings pooltogether bounty
  /generate-poc pooltogether CRIT-01
  /full-audit pooltogether bounty
```

**Bounty Mode (with audit cross-mode):**
```
Analysis Complete: pooltogether (BOUNTY)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Cross-Mode: Imported 3 High findings from audit analysis
Contracts Scanned: 12
Raw Findings: 47 (+ 3 imported)
After Deduplication: 24
After Sanitization: 19

Classified Findings (Critical/High only):
  Critical: 2 (1 promoted from audit H-01)
  High:     2 (1 from audit H-02)
  ⚠️ Discarded: 15 (Medium/Low not accepted)

Output: reports/pooltogether/bounty/

⚠️ BOUNTY REQUIREMENTS:
  • PoC mandatory for ALL findings
  • $25 USDC deposit per submission

Next Steps:
  /list-findings pooltogether bounty
  /generate-poc pooltogether CRIT-01
  /full-audit pooltogether bounty
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
# Full analysis of all in-scope contracts (regular audit)

/analyze pooltogether src/PrizePool.sol
# Focused analysis of single contract (regular audit)

/analyze aave-v4 src/core/
# Analysis of contracts in specific directory (regular audit)

/analyze pooltogether bounty
# Full analysis for bounty submission (Critical/High only)

/analyze pooltogether src/PrizePool.sol bounty
# Focused bounty analysis of single contract
```

# Critical Rules
1. **Never modify source repos** during analysis
2. **Preserve all raw findings** before filtering
3. **Document every filtering decision**
4. **Flag uncertain classifications** for review
