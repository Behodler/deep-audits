Extract and display specific findings for C4 submission selection
# Purpose
Create a filtered view of findings to help select the top 10 for C4 submission.

# Arguments
- `$ARGUMENTS` format: `<project-name> <finding-labels|file>`
- Labels can be comma-separated or space-separated: `H1,H2,M1` or `H-01 H-02 M-01`
- Accepts shorthand (H1, M2) or full labels (H-01, M-02)
- File input: JSON file containing array of labels
- Example: `pooltogether H1,H2,M1,M2,M3`
- Example: `pooltogether findings_view.json`

# Input File Format
**findings_view.json**:
```json
{
  "findings": ["H-01", "H-02", "M-01", "M-02", "M-03"]
}
```
Or simple array:
```json
["H-01", "H-02", "M-01"]
```

# Orchestration Flow

## 1. Parse Arguments
- Extract project name (first argument)
- Determine if second argument is a file or label list
- If file: Read and parse JSON
- If labels: Parse comma/space-separated list
- Normalize labels (H1 → H-01, h-1 → H-01)
- Warn if exceeding 10 findings (C4 limit per warden)

## 2. Resolve Project
Invoke **project-manager**: "Resolve friendly name"
- Look up in registered-projects.json
- If not found: List registered projects

## 3. Load Selected Findings
Invoke **finding-manager**: "Get findings by labels"
- Load each requested finding
- Verify all findings exist
- If any missing: Report which ones and continue with available
- Get full details including PoC status

## 4. Load Submission Reports
For each finding with status "submitted":
- Read from `reports/<project>/submissions/<label>-submission.md`
- Note which findings don't have submission reports yet

## 5. Display Summary View
Present selection summary:
```
Report View: pooltogether
━━━━━━━━━━━━━━━━━━━━━━━━━
Selected: 5 findings (C4 max: 10)

High Severity (2)
─────────────────
✓ H-01 [submitted] Reentrancy in claimPrize allows draining prize pool
✓ H-02 [ready]     Flash loan manipulation of prize calculation

Medium Severity (3)
───────────────────
✓ M-01 [submitted] Missing slippage protection in swap
✓ M-02 [submitted] Oracle staleness not checked
○ M-03 [needs-poc] Unbounded loop in batch claim

Legend: ✓ = has report  ○ = needs work

Submission Readiness
────────────────────
  Ready to submit: 3 (H-01, M-01, M-02)
  Needs report:    1 (H-02)  → /write-report pooltogether H-02
  Needs PoC:       1 (M-03)  → /generate-poc pooltogether M-03

Remaining C4 slots: 5
```

## 6. Generate Combined Report (Optional)
If `--combine` flag provided, create a combined document:
```
Combined Selection Report: pooltogether
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

================================================================================
[H-01] Reentrancy in claimPrize allows draining prize pool
================================================================================
<full submission content>

================================================================================
[H-02] Flash loan manipulation of prize calculation
================================================================================
<full submission content or "[Report not yet generated]">

... (continues for each finding)
```

Save to: `reports/<project>/submissions/selection-view-<timestamp>.md`

# Agent Delegation
This command orchestrates report extraction without implementing storage logic:
- **project-manager**: Resolve project name
- **finding-manager**: Query findings by specific labels

# Label Normalization
The command accepts flexible label formats:
- `H1` → `H-01`
- `h-1` → `H-01`
- `H-01` → `H-01` (unchanged)
- `m2` → `M-02`
- `c1` → `C-01`
- `L3` → `L-03`

# Error Handling
- **Unknown project**: List registered projects
- **Finding not found**: Report missing, continue with available
- **Over 10 findings**: Warn about C4's 10 submission limit (but allow)
- **No findings selected**: Show usage examples
- **File not found**: Report file path error
- **Invalid JSON**: Report parsing error

# Examples
```
/report-view pooltogether H1,H2,M1
# View 3 specific findings

/report-view pooltogether H-01 H-02 M-01 M-02 M-03
# View 5 findings (space-separated)

/report-view pooltogether findings_view.json
# View findings listed in JSON file

/report-view pooltogether H1,H2,M1,M2,M3 --combine
# Create combined report document
```

# Output Modes
- **Default**: Summary with readiness status
- **--combine**: Generate combined submission document
- **--json**: Output as JSON for programmatic use

# Critical Rules
1. **Warn over 10** - C4 limits submissions per warden, but allow flexibility
2. **Preserve order** - Display in severity order (H, M, L/C)
3. **Show gaps** - Clearly indicate which findings need work
4. **Actionable** - Include next steps for incomplete findings
