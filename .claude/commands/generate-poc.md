Generate a runnable Foundry proof-of-concept for a finding
# Purpose
Orchestrate creation and validation of a coded PoC that proves a vulnerability.

# Arguments
- `$ARGUMENTS` format: `<project-name> <finding-label>`
- Example: `nft-staking H-01`

# Critical Path Rules

## Source repos are read-only
The `lib/` submodules are STRICTLY READ-ONLY. Never write into `lib/<project>/`, the repo root, or repo-root `test/`.

## PoC location (workspace-first)
- **Preferred**: `workspace/<project>/test/poc-<label>.t.sol` — imports the project's real contracts/harnesses and runs with its own forge config (drop-in runnable).
- **Fallback** (only if a workspace cannot be created): standalone `<latest-report-dir>/pocs/<label>-poc.t.sol`, importing only `forge-std/Test.sol` with all dependencies inlined.

## Mandatory validation
Every PoC MUST pass `forge test` before reporting success. If validation fails, fix and retry until it passes.

# Orchestration Flow

## 1. Resolve Project & Workspace
Invoke **project-manager**: "Resolve project, ensure workspace exists, get latest report dir"
- Get submodule path and Solidity version (`grep solidity lib/<submodule>/foundry.toml`).
- Ensure `workspace/<project>/` exists (create via `create_workspace` if not).
- Get the latest versioned report dir for the standalone fallback path.

## 2. Load Finding
Invoke **finding-manager**: "Get finding details"
- Look up by project + label; verify it exists; status should be `draft` or `needs-poc`.
- Load contract, function, lineStart/lineEnd, description, attack path.

## 3. Generate PoC
Invoke **poc-generator**: "Create Foundry test proving the vulnerability"
- Workspace-first; standalone fallback only if no workspace.
- Use the project's Solidity version; mirror existing test patterns; include setUp, exploit test, and clear assertions on the exploited state.

## 4. Validate PoC (MANDATORY)
Invoke **poc-validator**: "Validate PoC compiles and passes"
```bash
# Workspace:
cd workspace/<project> && forge test --match-path test/poc-<label>.t.sol -vvv
# Standalone fallback:
mkdir -p /tmp/poc && cd /tmp/poc && forge init --no-commit && cp <poc> test/ && forge test -vvv
```
On failure: analyze the error, fix (usually a missing inline dependency, wrong interface, or unrealistic setup), re-save, re-run. Only proceed once it passes.

## 5. Update Finding Status
Invoke **finding-manager**: "Attach PoC to finding and update status"
- Attach the PoC path and set status to `ready`.

## 6. Completion Report
**On success**:
```
PoC Generated: <project> <label>   ✓ PASSING
File: workspace/<project>/test/poc-<label>.t.sol
Run:  cd workspace/<project> && forge test --match-path test/poc-<label>.t.sol -vvvv
Status: needs-poc → ready
Next:  /write-report <project> <label>
```
**On failure (retries exhausted)**: report the error type, message, and attempted fixes; flag for manual intervention.

# Agent Delegation
- **project-manager**: resolve project, ensure workspace, latest report dir
- **finding-manager**: load finding, update status
- **poc-generator**: create the test (with built-in validation)
- **poc-validator**: final validation before success

# Error Handling
- **Finding not found**: list available findings.
- **Wrong status**: warn if already has a PoC or is submitted.
- **Compilation/test failures**: fix imports/version/logic and retry.

# Critical Rules
1. **NEVER write to `lib/`** — read-only.
2. **Workspace-first**, standalone only when no workspace is possible.
3. **MUST use the project Solidity version.**
4. **MUST pass `forge test`** before reporting success — never report success without validation.
5. **MUST retry on failure** — don't give up after the first error.
