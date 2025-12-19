Generate a runnable Foundry proof-of-concept for a finding
# Purpose
Orchestrate creation and validation of a coded PoC that proves a vulnerability.

# Arguments
- `$ARGUMENTS` format: `<project-name> <finding-label>`
- Example: `pooltogether H-01`

# Critical Path Rules

## Source Repos Are Read-Only
**CRITICAL: The `lib/` directory contains git submodules of source repos that are STRICTLY READ-ONLY.**
- NEVER write files to `lib/<project>/`
- NEVER modify any files in source repos
- Source repos must remain exactly as cloned from C4

## File Location
PoC files MUST be saved to the reports directory:
```
reports/<project-name>/pocs/<label>-poc.t.sol
```

Example for "brix" project:
```
reports/brix/pocs/H-01-poc.t.sol
```

**NEVER save to:**
- `lib/<project>/test/` (source repo is READ-ONLY)
- Root directory
- `test/` at repository root
- Any location inside `lib/`

## Mandatory Validation
Every PoC MUST be validated with `forge test` BEFORE reporting success.
If validation fails, fix and retry until it passes.

# Orchestration Flow

## 1. Resolve Project
Invoke **project-manager**: "Resolve project and get submodule path"
- Get the submodule path (e.g., `lib/2025-11-brix-money-c4-audit`)
- Verify project exists
- Get Foundry configuration (Solidity version)

## 2. Load Finding
Invoke **finding-manager**: "Get finding details"
- Look up finding by project and label
- Verify finding exists
- Check current status (should be "draft" or "needs-poc")
- Load full finding details: contract, function, line, description, attack path

## 3. Analyze Project Structure
Before generating, the poc-generator MUST:
```bash
# Get Solidity version
grep "solidity" lib/<project>/foundry.toml

# Check existing test patterns
ls lib/<project>/test/*.t.sol | head -5

# Read target contract interfaces
cat lib/<project>/src/<contract>.sol | head -100
```

## 4. Generate PoC
Invoke **poc-generator**: "Create Foundry test proving vulnerability"
- Use EXACT Solidity version from project's foundry.toml
- Use relative imports from `lib/<project>/test/`
- Match project's existing test patterns
- Include:
  - Proper imports
  - setUp() matching project style
  - Test function demonstrating exploit
  - Clear assertions proving impact
  - Comments explaining attack steps

## 5. Save PoC
Save to: `reports/<project-name>/pocs/<label>-poc.t.sol`

Example:
```
reports/brix/pocs/H-01-poc.t.sol
```

**REMINDER: NEVER save to lib/ - source repos are read-only.**

## 6. Validate PoC (MANDATORY)
Invoke **poc-validator**: "Validate PoC compiles and runs"

The PoC must be validated by running forge test from the project submodule with the PoC path:
```bash
cd lib/<project> && forge test --match-path ../../reports/<project-name>/pocs/<label>-poc.t.sol -vv
```

Alternatively, copy the PoC temporarily to run tests, then remove the copy.

**If validation fails:**
1. Analyze the error (compilation, runtime, assertion)
2. Fix the issue
3. Re-save the file
4. Re-run validation
5. Repeat until passing

**Only proceed to step 7 after validation passes.**

## 7. Update Finding Status
Invoke **finding-manager**: "Attach PoC to finding and update status"
- Attach PoC file path
- Update finding status to "ready"

## 8. Completion Report
**On Success**:
```
PoC Generated: <project> <label>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Status: ✓ PASSING
File: reports/<project-name>/pocs/<label>-poc.t.sol

Validation:
  forge build: ✓ PASS
  forge test:  ✓ PASS

Run with:
  cd lib/<project> && forge test --match-path ../../reports/<project-name>/pocs/<label>-poc.t.sol -vvvv

Finding status updated: needs-poc → ready

Next Steps:
  /write-report <project> <label>
```

**On Failure (after retries exhausted)**:
```
PoC Generation Failed: <project> <label>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Error: <error type>

Details:
  <specific error message>

Attempted fixes:
  1. <fix attempt 1>
  2. <fix attempt 2>

Manual intervention required.
```

# Agent Delegation
This command orchestrates PoC creation:
- **project-manager**: Resolve project path and config
- **finding-manager**: Get finding details, update status
- **poc-generator**: Create test code (with built-in validation)
- **poc-validator**: Final validation before success report

# Error Handling
- **Finding not found**: List available findings
- **Wrong status**: Warn if already has PoC or is submitted
- **Compilation errors**: Fix imports, version, syntax - retry
- **Test failures**: Analyze assertion, fix logic - retry
- **Import issues**: Check project structure - fix paths

# Critical Rules
1. **NEVER write to lib/** - Source repos are strictly read-only
2. **File MUST be in reports/<project>/pocs/** - Nowhere else
3. **MUST use project Solidity version** - Check foundry.toml
4. **MUST pass forge test** - Validate before reporting success
5. **MUST retry on failure** - Don't give up after first error
6. **NEVER report success without validation** - Always run forge test
