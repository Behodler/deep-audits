Generate a runnable Foundry proof-of-concept for a finding
# Purpose
Orchestrate creation and validation of a coded PoC that proves a vulnerability.

# Arguments
- `$ARGUMENTS` format: `<project-name> <finding-label>`
- Example: `pooltogether H-01`

# Orchestration Flow

## 1. Load Finding
Invoke **finding-manager**: "Get finding details"
- Look up finding by project and label
- Verify finding exists
- Check current status (should be "draft" or "needs-poc")
- Load full finding details: contract, function, line, description, attack path

## 2. Get Project Context
Invoke **project-manager**: "Get project test structure"
- Locate project's test directory
- Identify existing test patterns (setUp style, imports, helpers)
- Find relevant test file to extend
- Get Foundry configuration

## 3. Generate PoC
Invoke **poc-generator**: "Create Foundry test proving vulnerability"
- Generate test contract based on finding details
- Create attacker contract if needed (reentrancy, callbacks)
- Use project's existing test patterns
- Include:
  - Proper imports
  - setUp() matching project style
  - Test function demonstrating exploit
  - Clear assertions proving impact
  - Comments explaining attack steps

## 4. Format as Diff
Invoke **poc-generator**: "Format PoC as diff"
- Create diff format for C4 submission
- Target existing test file when possible
- Ensure diff is applicable with standard tools

## 5. Validate PoC
Invoke **poc-validator**: "Validate PoC compiles and runs"
- Copy PoC to project test directory
- Run `forge build` to verify compilation
- Run `forge test --match-test <test_name> -vvvv`
- Verify test passes and demonstrates issue
- Check assertions prove claimed impact

## 6. Handle Validation Result
**If PoC passes validation**:
- Invoke **finding-manager**: "Attach PoC to finding"
- Update finding status to "ready"
- Save PoC file to `reports/<project>/pocs/<label>-poc.t.sol`
- Present success message with test command

**If PoC fails validation**:
- Present detailed error information
- Show compilation errors or test failures
- Suggest fixes based on error type
- Offer to retry with modifications
- Keep finding status as "needs-poc"

## 7. Completion Report
**On Success**:
```
PoC Generated: pooltogether H-01
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Status: PASSING
File: reports/pooltogether/pocs/H-01-poc.t.sol

Run with:
  cd lib/pooltogether && forge test --match-test test_H01 -vvvv

Finding status updated: needs-poc → ready

Next Steps:
  /write-report pooltogether H-01
  /review-finding pooltogether H-01
```

**On Failure**:
```
PoC Generation Failed: pooltogether H-01
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Error: Compilation failed

Details:
  Error: Cannot find import "src/PrizePool.sol"

Suggestions:
  - Check import paths match project structure
  - Verify contract names are correct

Retry with: /generate-poc pooltogether H-01
```

# Agent Delegation
This command orchestrates PoC creation without implementing test logic:
- **finding-manager**: Get finding details, update status
- **project-manager**: Get test structure
- **poc-generator**: Create test code
- **poc-validator**: Verify PoC works

# Error Handling
- **Finding not found**: List available findings
- **Wrong status**: Warn if already has PoC or is submitted
- **Compilation errors**: Report with suggestions
- **Test failures**: Analyze and suggest fixes
- **Import issues**: Help resolve paths

# Examples
```
/generate-poc pooltogether H-01
# Generate PoC for high-severity finding H-01

/generate-poc aave-v4 M-03
# Generate PoC for medium-severity finding M-03
```

# Critical Rules
1. **PoC must compile** - No syntax errors
2. **PoC must pass** - Test must succeed
3. **PoC must prove claim** - Assertions match finding impact
4. **Use project test suite** - C4 requirement
5. **Provide as diff** - C4 submission format
