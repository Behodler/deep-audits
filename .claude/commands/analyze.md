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

## 1.5. Create Versioned Report Directory
Invoke **project-manager**: "Create versioned report directory for this audit run"
- Creates `reports/<project>-XX/` where XX is the next sequential version
- If unversioned `reports/<project>/` exists (legacy), treat as version 0
- First run (no existing directories) creates `reports/<project>-01/`
- Store the versioned path (e.g., `reports/pooltogether-01/`) for use in all subsequent steps
- **All findings, profiles, and submissions go under this versioned directory**

```
Creating Report Directory
─────────────────────────
New audit run: reports/pooltogether-03/
Previous versions found: pooltogether (legacy), pooltogether-01, pooltogether-02
```

## 2. Get Scope and Known Issues
Invoke **project-manager**: "Get scope and known issues for project"
- Retrieve in-scope contract list
- Load known issues for later sanitization
- If contract-path specified in $ARGUMENTS: Filter scope to that contract

## 2.5. Check for Cross-Mode Findings (Optimization)
Invoke **finding-manager**: "Check if other mode has existing findings in the same versioned directory"

**IMPORTANT**: Cross-mode import only looks **within the same versioned directory**.
- If running bounty in `reports/pooltogether-03/`, only checks `reports/pooltogether-03/audit/`
- Does NOT look at `reports/pooltogether-02/audit/` or any other version
- This ensures audit isolation between runs

**If other mode exists in same version:**
```
Cross-Mode Detection
────────────────────
Existing analysis found: reports/pooltogether-03/audit/
  High findings: 3
  Medium findings: 7
  Low findings: 8

These will be used as seed candidates for bounty classification.
Full scan will still run to catch additional issues.
```

**Decision Tree:**
1. Running **bounty** and **audit** exists in same versioned directory:
   - Invoke **finding-manager**: "Import High findings from audit as bounty candidates"
   - These become input for severity-classifier (may become Critical or High)
   - Still run full code-scanner and econ-scanner (audit may have missed bounty-relevant issues)

2. Running **audit** and **bounty** exists in same versioned directory:
   - Invoke **finding-manager**: "Import Critical/High findings from bounty as audit High candidates"
   - Still run full analysis (need Medium/Low/QA that bounty doesn't have)

3. No other mode exists in this versioned directory:
   - Proceed with fresh analysis

**Important**: Cross-mode import seeds the classifier but does NOT skip scanning. The other mode's findings inform but don't replace the full analysis.

## 2.6. Parallel Analysis Phase

Run these three analysis tasks IN PARALLEL:

### 2.6a. Profile Contracts (Local Analysis)
Invoke **contract-profiler** for each in-scope contract (parallel where possible):
- Pass: contract path, project path, related contracts (imports/inheritance)
- Produce per-contract:
  - **Verified properties**: No unbounded loops, checked arithmetic, reentrancy guards, etc.
  - **Local findings**: Issues exploitable without cross-contract interaction
  - **Interface abstraction**: Entry points, state mutators, external calls, trust boundaries
  - **Trust assumptions**: What the contract assumes about external dependencies

**Output**: Array of contract profiles saved to `<versioned-report-dir>/<mode>/profiles/`

### 2.6b. Static Analysis (Slither)
Invoke **static-analyzer**: "Run Slither static analysis"
- Pass: project path, contracts path, mode
- Runs Slither with JSON output
- Filters informational/low-value detectors
- Normalizes findings to common format
- **Output**: `<versioned-report-dir>/<mode>/static-analysis-findings.json`

### 2.6c. Pattern Matching
Invoke **pattern-matcher**: "Match code against vulnerability patterns"
- Pass: project name, mode, scope, versioned report directory
- Checks code against `patterns/vulnerability-patterns.json`
- Flags high-confidence pattern matches
- **Output**: `<versioned-report-dir>/<mode>/pattern-matches.json`

**Why this step exists**: Downstream scanners receive interface abstractions instead of raw source. This:
1. Prevents over-ingestion of scope
2. Lets interaction analysis treat local properties as verified axioms
3. Surfaces local issues early (unbounded loops, missing access control)
4. Compresses context for agents with limited windows

```
Parallel Analysis Phase
───────────────────────
Profiling Contracts:
[✓] src/PrizePool.sol (450 LOC, 2 local findings)
[✓] src/Vault.sol (320 LOC, 0 local findings)
[✓] src/PrizeVault.sol (280 LOC, 1 local finding)
Profiles saved: reports/pooltogether-01/audit/profiles/

Static Analysis (Slither):
[✓] Completed: 15 findings (after filtering)
Output: reports/pooltogether-01/audit/static-analysis-findings.json

Pattern Matching:
[✓] Checked 22 patterns, 3 matches
Output: reports/pooltogether-01/audit/pattern-matches.json
```

## 3. Code Vulnerability Scan (Interaction-Level)
Invoke **code-scanner**: "Scan for cross-contract code vulnerabilities"
- Pass: project path, scope list, **contract profiles from step 2.6**
- **SCOPE RESTRICTION**: Scanner works from profiles, not raw source
  - Trust verified properties (don't re-check unbounded loops if profile says none)
  - Focus on interaction patterns between contracts
  - Use interface abstractions for cross-contract reasoning
- Identify interaction-level code vulnerabilities:
  - Reentrancy across contract boundaries
  - Access control gaps in call chains
  - External call sequencing risks
  - Callback vulnerabilities
  - Cross-contract state corruption
- Return raw findings list with confidence levels
- **Local findings already captured in profiles - do not duplicate**

## 4. Economic Vulnerability Scan (Interaction-Level)
Invoke **econ-scanner**: "Scan for cross-contract economic vulnerabilities"
- Pass: project path, scope list, documentation, **contract profiles from step 2.6**
- **SCOPE RESTRICTION**: Scanner works from profiles for local context
  - Use interface abstractions to understand value flow entry points
  - Trust verified arithmetic properties from profiles
  - Focus on protocol-wide economic interactions
- Analyze economic design and incentives:
  - Intent verification (docs vs implementation)
  - Pricing/fee calculation errors across contracts
  - Oracle manipulation vectors (cross-contract)
  - Flash loan attack surfaces (multi-contract flows)
  - Incentive misalignments between protocol actors
  - MEV extraction paths through contract interactions
- Return raw findings list with economic impact
- **Local arithmetic issues already captured in profiles - do not duplicate**

## 5. Deduplicate Findings
Invoke **deduplicator**: "Filter obvious and common issues from scan results"
- Combine findings from:
  - **Local findings** from contract profiles (step 2.6a)
  - **Static analysis findings** from Slither (step 2.6b)
  - **Pattern matches** from pattern-matcher (step 2.6c)
  - **Interaction findings** from code-scanner (step 3)
  - **Economic findings** from econ-scanner (step 4)
- Remove exact duplicates
- Consolidate findings with same root cause
- Filter low-value/common issues that add no insight
- Track consolidation reasoning
- Note source of each finding for audit trail

## 6. Sanitize Against Known Issues
Invoke **sanitizer**: "Remove issues matching known issues list"
- Compare findings against project's documented known issues
- Filter findings that duplicate known issues
- Flag partial matches for human review
- Document all removals with reasoning

## 6.5. Advanced Testing (Optional, Time-Permitting)

These steps provide additional verification but may be time-intensive:

### 6.5a. Invariant Testing
Invoke **invariant-generator**: "Generate and run invariant tests"
- Pass: project path, contract profiles
- Generates Foundry invariant tests from contract profiles
- Runs fuzzing with `forge test --match-contract Invariant`
- Any failing invariant = HIGH severity finding with counterexample
- **Output**: `test/<project>/Invariant.t.sol`, `<versioned-report-dir>/<mode>/invariant-results.json`

**When to use**: For DeFi protocols with complex state (vaults, lending, AMMs)

### 6.5b. Symbolic Analysis (Halmos)
Invoke **symbolic-analyzer**: "Generate and run Halmos symbolic tests"
- Pass: project path, critical functions from profiles
- Generates symbolic tests for core arithmetic functions
- Runs Halmos for mathematical verification
- Counterexamples become HIGH severity findings
- **Output**: `test/<project>/Symbolic.t.sol`, `<versioned-report-dir>/<mode>/symbolic-results.json`

**When to use**: For pure arithmetic functions, pricing logic, share calculations

```
Advanced Testing (Optional)
───────────────────────────
Invariant Testing:
[✓] Generated 8 invariants
[✓] Ran 10000 fuzz runs
[!] 1 failure: invariant_noShareInflation
Finding: INVARIANT-001 (potential-high)

Symbolic Analysis:
[✓] Generated 5 symbolic tests
[✓] 4 passed, 1 timeout
Finding: SYMBOLIC-001 counterexample found
```

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
- Pass the versioned report directory from step 1.5
- Generate finding files in `<versioned-report-dir>/<mode>/findings/`
  - Audit: `<versioned-report-dir>/audit/findings/`
  - Bounty: `<versioned-report-dir>/bounty/findings/`
- Assign labels (H-01, M-01, CRIT-01, etc.)
- Set status to "draft" or "needs-poc"
- Store in appropriate severity subdirectory
- If imported from other mode, link to source finding in metadata

## 9. Save Analysis Report
Save raw analysis to `<versioned-report-dir>/<mode>/`:
- `analysis-<timestamp>.json`: Full scan results
- Include: scan metadata, findings count, filtering stats, cross-mode import stats

## 10. Present Summary
Display to user:

**Regular Audit (fresh):**
```
Analysis Complete: pooltogether
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Audit Run: reports/pooltogether-01/
Contracts Profiled: 12

Tier 1 (Parallel Local Analysis):
  Verified clean: 9 contracts
  Local findings: 5
  Slither findings: 15
  Pattern matches: 3

Tier 2 (Interaction Analysis):
  Code findings: 28
  Economic findings: 14

Pipeline:
  Raw Findings: 65 (5 local + 15 slither + 3 pattern + 28 code + 14 econ)
  After Deduplication: 28
  After Sanitization: 22

Classified Findings:
  High:   4
  Medium: 8
  Low:    10

Output: reports/pooltogether-01/audit/
Profiles: reports/pooltogether-01/audit/profiles/

Next Steps:
  /list-findings pooltogether
  /generate-poc pooltogether H-01
  /full-audit pooltogether
```

**Regular Audit (with bounty cross-mode in same version):**
```
Analysis Complete: pooltogether
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Audit Run: reports/pooltogether-01/
Cross-Mode: Imported 3 findings from reports/pooltogether-01/bounty/
Contracts Profiled: 12

Tier 1 (Local Analysis):
  Verified clean: 9 contracts
  Local findings: 5

Tier 2 (Interaction Analysis):
  Code findings: 28
  Economic findings: 14

Pipeline:
  Raw Findings: 50 (5 local + 28 code + 14 econ + 3 imported)
  After Deduplication: 25
  After Sanitization: 20

Classified Findings:
  High:   4 (1 from bounty CRIT-01, 1 from bounty H-01)
  Medium: 8
  Low:    8

Output: reports/pooltogether-01/audit/
Profiles: reports/pooltogether-01/audit/profiles/

Next Steps:
  /list-findings pooltogether
  /generate-poc pooltogether H-01
  /full-audit pooltogether
```

**Bounty Mode (fresh):**
```
Analysis Complete: pooltogether (BOUNTY)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Audit Run: reports/pooltogether-01/
Contracts Profiled: 12

Tier 1 (Parallel Local Analysis):
  Verified clean: 9 contracts
  Local findings: 5
  Slither findings: 15
  Pattern matches: 3

Tier 2 (Interaction Analysis):
  Code findings: 28
  Economic findings: 14

Pipeline:
  Raw Findings: 65 (5 local + 15 slither + 3 pattern + 28 code + 14 econ)
  After Deduplication: 28
  After Sanitization: 22

Classified Findings (Critical/High only):
  Critical: 1
  High:     3
  ⚠️ Discarded: 18 (Medium/Low not accepted)

Output: reports/pooltogether-01/bounty/
Profiles: reports/pooltogether-01/bounty/profiles/

⚠️ BOUNTY REQUIREMENTS:
  • PoC mandatory for ALL findings
  • $25 USDC deposit per submission

Next Steps:
  /list-findings pooltogether bounty
  /generate-poc pooltogether CRIT-01
  /full-audit pooltogether bounty
```

**Bounty Mode (with audit cross-mode in same version):**
```
Analysis Complete: pooltogether (BOUNTY)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Audit Run: reports/pooltogether-01/
Cross-Mode: Imported 3 High findings from reports/pooltogether-01/audit/
Contracts Profiled: 12

Tier 1 (Local Analysis):
  Verified clean: 9 contracts
  Local findings: 5

Tier 2 (Interaction Analysis):
  Code findings: 28
  Economic findings: 14

Pipeline:
  Raw Findings: 50 (5 local + 28 code + 14 econ + 3 imported)
  After Deduplication: 24
  After Sanitization: 19

Classified Findings (Critical/High only):
  Critical: 2 (1 promoted from audit H-01)
  High:     2 (1 from audit H-02)
  ⚠️ Discarded: 15 (Medium/Low not accepted)

Output: reports/pooltogether-01/bounty/
Profiles: reports/pooltogether-01/bounty/profiles/

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
- **contract-profiler**: Local analysis per contract (Tier 1) - produces verified properties and interface abstractions
- **static-analyzer**: Run Slither static analysis and normalize findings (Tier 1)
- **pattern-matcher**: Match code against vulnerability pattern database (Tier 1)
- **code-scanner**: Identify cross-contract code vulnerabilities (Tier 2) - consumes profiles
- **econ-scanner**: Identify economic/game-theoretic vulnerabilities (Tier 2) - consumes profiles
- **deduplicator**: Filter duplicates and common issues
- **sanitizer**: Remove known issues
- **invariant-generator**: Generate and run Foundry invariant tests (optional)
- **symbolic-analyzer**: Generate and run Halmos symbolic tests (optional)
- **severity-classifier**: Apply C4 severity rules
- **finding-manager**: Store findings

## Tiered Analysis Architecture
```
┌─────────────────────────────────────────────────────────────────────────┐
│                    TIER 1: PARALLEL LOCAL ANALYSIS                       │
│                                                                          │
│  ┌─────────────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │   contract-profiler     │  │ static-analyzer │  │ pattern-matcher │  │
│  │  (per-contract analysis)│  │    (Slither)    │  │  (pattern DB)   │  │
│  └───────────┬─────────────┘  └────────┬────────┘  └────────┬────────┘  │
│              │                         │                     │           │
│              └─────────────────────────┼─────────────────────┘           │
│                                        ▼                                 │
│              ┌──────────────────────────────────────────────┐            │
│              │    Combined Tier 1 Findings + Profiles        │            │
│              │  (verified props, interfaces, static finds)   │            │
│              └───────────────────────┬──────────────────────┘            │
└──────────────────────────────────────┼──────────────────────────────────┘
                                       │
┌──────────────────────────────────────▼──────────────────────────────────┐
│                     TIER 2: INTERACTION ANALYSIS                         │
│       ┌──────────────────┐              ┌──────────────────┐            │
│       │   code-scanner   │              │   econ-scanner   │            │
│       │ (cross-contract  │              │ (protocol-wide   │            │
│       │  code issues)    │              │  economic issues)│            │
│       └────────┬─────────┘              └────────┬─────────┘            │
│                │                                  │                      │
│                └──────────────┬───────────────────┘                      │
│                               ▼                                          │
│                Combined Interaction Findings                             │
└──────────────────────────────────────────────────────────────────────────┘
                                       │
┌──────────────────────────────────────▼──────────────────────────────────┐
│                    TIER 3: ADVANCED TESTING (Optional)                   │
│       ┌────────────────────┐          ┌────────────────────┐            │
│       │invariant-generator │          │ symbolic-analyzer  │            │
│       │   (Foundry fuzz)   │          │     (Halmos)       │            │
│       └────────┬───────────┘          └────────┬───────────┘            │
│                │                                │                        │
│                └──────────────┬─────────────────┘                        │
│                               ▼                                          │
│              Verified/Falsified Properties + Counterexamples             │
└──────────────────────────────────────────────────────────────────────────┘
```

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
