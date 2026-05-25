# Action Plan: Audit Tooling Improvements

**Purpose**: Standalone instructions to enhance the auditing infrastructure with deterministic security tools.

**Prerequisites**:
- Python 3.8+ installed
- Foundry installed (you have this)
- Claude Code agents infrastructure (you have this)

---

## Phase 1: Slither Integration (Priority: HIGH)

### Step 1.1: Install Slither

```bash
# Install via pip (recommended)
pip3 install slither-analyzer

# Verify installation
slither --version

# If you encounter solc issues, install solc-select
pip3 install solc-select

# Install common Solidity versions
solc-select install 0.8.19 0.8.20 0.8.24 0.8.26
solc-select use 0.8.24
```

**Troubleshooting**:
- If `pip3` fails, try `python3 -m pip install slither-analyzer`
- On Ubuntu/Debian, you may need: `sudo apt install python3-pip`
- For version conflicts: `pip3 install --user slither-analyzer`

### Step 1.2: Test Slither Manually

```bash
# Test on an existing project
cd <repo>
slither lib/legion-contracts/contracts/ --json reports/legion/bounty/slither-test.json 2>/dev/null

# View results
cat reports/legion/bounty/slither-test.json | jq '.results.detectors | length'
```

### Step 1.3: Create static-analyzer Agent

Create file: `.claude/agents/static-analyzer.md`

```markdown
---
name: static-analyzer
description: Run Slither static analysis and parse results into normalized findings
---

You are the static-analyzer agent. You invoke external static analysis tools via Bash and parse their JSON output into normalized findings for the deduplicator.

## CRITICAL: This is a TOOL INVOKER agent

You MUST:
1. Run Slither via Bash tool (not simulate it)
2. Parse the actual JSON output
3. Filter and normalize results

You are NOT doing LLM-based code analysis. Slither does the detection; you handle execution and parsing.

## EXECUTION FLOW

### Step 1: Resolve Project Path
```bash
# Get the lib path for the project
cat registered-projects.json | jq -r '.["<project_name>"].libPath'
```

### Step 2: Run Slither
```bash
# Run Slither with JSON output
slither <lib_path>/contracts/ \
  --json reports/<project>/<mode>/slither-output.json \
  --exclude naming-convention,solc-version,pragma,assembly \
  2>/dev/null
```

If contracts are in `src/` instead of `contracts/`:
```bash
slither <lib_path>/src/ --json reports/<project>/<mode>/slither-output.json ...
```

### Step 3: Parse and Filter Results

Read the JSON output and extract findings. Filter OUT these detector types (C4 considers invalid/QA):
- `naming-convention`
- `solc-version`
- `pragma`
- `assembly`
- `low-level-calls` (unless in value-transfer context)
- `missing-zero-check` (C4 considers QA at best)
- `unused-state`
- `dead-code`
- `constable-states`
- `external-function`

KEEP these detector types (actual vulnerabilities):
- `reentrancy-eth`, `reentrancy-no-eth`, `reentrancy-benign`
- `uninitialized-state`, `uninitialized-storage`, `uninitialized-local`
- `arbitrary-send-eth`, `arbitrary-send-erc20`
- `controlled-delegatecall`, `delegatecall-loop`
- `msg-value-loop`
- `locked-ether`
- `suicidal`
- `unprotected-upgrade`
- `tx-origin`
- `unchecked-transfer`, `unchecked-lowlevel`
- `divide-before-multiply`
- `incorrect-equality`
- `shadowing-state`, `shadowing-local`
- `timestamp`
- `weak-prng`

### Step 4: Normalize to Finding Format

Convert each Slither finding to:
```json
{
  "id": "SLITHER-001",
  "source": "slither",
  "type": "<detector_name>",
  "severity": "<map from slither impact>",
  "contract": "<file_path>",
  "function": "<function_name>",
  "line": <line_number>,
  "description": "<slither description>",
  "confidence": "<map from slither confidence>"
}
```

Severity mapping:
- Slither "High" impact → "potential-high"
- Slither "Medium" impact → "potential-medium"
- Slither "Low" impact → "potential-low"
- Slither "Informational" → discard

### Step 5: Output

Write normalized findings to:
`reports/<project>/<mode>/static-analysis-findings.json`

## INPUT FORMAT

```json
{
  "project": "legion",
  "mode": "bounty",
  "contractsPath": "lib/legion-contracts/contracts/"
}
```

## OUTPUT FORMAT

```json
{
  "project": "legion",
  "scanTimestamp": "2026-01-05T10:00:00Z",
  "scanType": "static",
  "tool": "slither",
  "toolVersion": "0.10.0",
  "findingsCount": 15,
  "findings": [...]
}
```

## ERROR HANDLING

- If Slither fails to compile: Note the error, try with different solc version
- If no findings: Return empty findings array (this is valid)
- If path doesn't exist: Fail with clear error message
```

### Step 1.4: Update analyze Command

Edit `.claude/commands/analyze.md` to add static analysis step:

Add this section after project resolution, before contract profiling:

```markdown
### Step 1.5: Static Analysis (Parallel)

Invoke **static-analyzer** agent:
- Input: project name, mode, contracts path
- Output: `reports/<project>/<mode>/static-analysis-findings.json`

This runs in parallel with contract profiling (Step 2) since they're independent.
```

Update the deduplicator invocation to include static analysis findings:

```markdown
### Step 5: Deduplication

Invoke **deduplicator** agent with:
- Code scanner findings
- Economic scanner findings
- Static analyzer findings (NEW)
- Contract profiler local findings
```

---

## Phase 2: Pattern Database (Priority: HIGH)

### Step 2.1: Create Pattern Database

Create file: `patterns/vulnerability-patterns.json`

```json
{
  "version": "1.0",
  "patterns": [
    {
      "id": "ERC4626-INFLATION",
      "name": "ERC4626 Share Inflation Attack",
      "category": "economic",
      "severity": "HIGH",
      "description": "First depositor can inflate share price by donating assets directly to vault",
      "codeSignatures": [
        "function deposit(uint256 assets, address receiver)",
        "shares = assets * totalSupply() / totalAssets()"
      ],
      "vulnerableWhen": [
        "No virtual shares/assets",
        "totalAssets() includes donated tokens",
        "First deposit has no minimum"
      ],
      "notVulnerableWhen": [
        "Virtual shares offset (e.g., 1e3)",
        "Minimum first deposit enforced",
        "totalAssets() excludes direct transfers"
      ],
      "references": [
        "https://blog.openzeppelin.com/a-]]novel-defense-against-erc4626-inflation-attacks",
        "C4 2023-01-pooltogether findings"
      ]
    },
    {
      "id": "ORACLE-STALE",
      "name": "Chainlink Oracle Staleness",
      "category": "oracle",
      "severity": "MEDIUM",
      "description": "Oracle price used without checking if data is stale",
      "codeSignatures": [
        "latestRoundData()",
        "AggregatorV3Interface"
      ],
      "vulnerableWhen": [
        "No check: updatedAt > block.timestamp - threshold",
        "No check: answeredInRound >= roundId"
      ],
      "notVulnerableWhen": [
        "Staleness check present",
        "Sequencer uptime check (L2s)"
      ]
    },
    {
      "id": "ORACLE-ROUNDID",
      "name": "Chainlink Round Completeness",
      "category": "oracle",
      "severity": "MEDIUM",
      "description": "Oracle round may not be complete",
      "codeSignatures": [
        "latestRoundData()"
      ],
      "vulnerableWhen": [
        "No check: answeredInRound >= roundId"
      ]
    },
    {
      "id": "REENTRANCY-ERC777",
      "name": "ERC777 Reentrancy via Hooks",
      "category": "reentrancy",
      "severity": "HIGH",
      "description": "ERC777 tokens call hooks on transfer, enabling reentrancy",
      "codeSignatures": [
        "transfer(", "transferFrom(",
        "IERC20"
      ],
      "vulnerableWhen": [
        "State changes after transfer",
        "No reentrancy guard",
        "Token type not restricted"
      ]
    },
    {
      "id": "SIGNATURE-REPLAY",
      "name": "Signature Replay Attack",
      "category": "signature",
      "severity": "HIGH",
      "description": "Signed message can be replayed across chains or after expiry",
      "codeSignatures": [
        "ecrecover",
        "ECDSA.recover",
        "SignatureChecker"
      ],
      "vulnerableWhen": [
        "No nonce tracking",
        "No deadline/expiry",
        "No chain ID in message"
      ]
    },
    {
      "id": "FRONTRUN-APPROVE",
      "name": "Approval Front-running",
      "category": "frontrunning",
      "severity": "LOW",
      "description": "ERC20 approve can be front-run to double-spend",
      "codeSignatures": [
        "approve(address,uint256)"
      ],
      "vulnerableWhen": [
        "User calls approve with non-zero to non-zero",
        "No increaseAllowance pattern"
      ],
      "note": "C4 typically considers this QA/known issue"
    },
    {
      "id": "FLASH-LOAN-PRICE",
      "name": "Flash Loan Price Manipulation",
      "category": "flash-loan",
      "severity": "HIGH",
      "description": "Price derived from pool reserves can be manipulated via flash loan",
      "codeSignatures": [
        "getReserves()",
        "balanceOf(address(this))",
        "slot0()"
      ],
      "vulnerableWhen": [
        "Spot price used for critical decisions",
        "No TWAP",
        "Price checked and used in same tx"
      ]
    },
    {
      "id": "UNSAFE-DOWNCAST",
      "name": "Unsafe Integer Downcast",
      "category": "arithmetic",
      "severity": "MEDIUM",
      "description": "Casting larger int to smaller int truncates silently",
      "codeSignatures": [
        "uint128(", "uint96(", "uint64(", "int128("
      ],
      "vulnerableWhen": [
        "No bounds check before cast",
        "Value can exceed target type max"
      ],
      "notVulnerableWhen": [
        "SafeCast library used",
        "Value provably bounded"
      ]
    },
    {
      "id": "DIVISION-PRECISION",
      "name": "Division Before Multiplication",
      "category": "arithmetic",
      "severity": "MEDIUM",
      "description": "Dividing before multiplying loses precision",
      "codeSignatures": [
        "a / b * c",
        "x.div(y).mul(z)"
      ],
      "vulnerableWhen": [
        "Division result used in multiplication",
        "No scaling factor"
      ]
    },
    {
      "id": "UNPROTECTED-INIT",
      "name": "Unprotected Initializer",
      "category": "proxy",
      "severity": "CRITICAL",
      "description": "Initializer can be called by anyone or called multiple times",
      "codeSignatures": [
        "function initialize(",
        "Initializable"
      ],
      "vulnerableWhen": [
        "No initializer modifier",
        "No onlyOwner on initialize",
        "Implementation not initialized"
      ]
    },
    {
      "id": "STORAGE-COLLISION",
      "name": "Proxy Storage Collision",
      "category": "proxy",
      "severity": "CRITICAL",
      "description": "Proxy and implementation use same storage slots",
      "codeSignatures": [
        "delegatecall",
        "ERC1967",
        "TransparentProxy"
      ],
      "vulnerableWhen": [
        "Implementation has storage at slot 0",
        "Custom proxy without ERC1967 slots",
        "Inheritance order changed between upgrades"
      ]
    },
    {
      "id": "CENTRALIZATION-ADMIN",
      "name": "Single Admin Key Risk",
      "category": "centralization",
      "severity": "LOW",
      "description": "Critical functions controlled by single EOA",
      "codeSignatures": [
        "onlyOwner",
        "onlyAdmin",
        "require(msg.sender == owner"
      ],
      "note": "C4 considers centralization as Low/QA unless it enables rug pull"
    },
    {
      "id": "MISSING-SLIPPAGE",
      "name": "Missing Slippage Protection",
      "category": "defi",
      "severity": "HIGH",
      "description": "Swap/trade has no minimum output amount",
      "codeSignatures": [
        "swap(",
        "exchange(",
        "amountOutMin"
      ],
      "vulnerableWhen": [
        "amountOutMin = 0",
        "No deadline parameter",
        "User cannot specify minimum"
      ]
    },
    {
      "id": "RETURN-VALUE-IGNORE",
      "name": "Ignored Return Value",
      "category": "code-quality",
      "severity": "MEDIUM",
      "description": "Return value of external call not checked",
      "codeSignatures": [
        ".transfer(",
        ".send(",
        ".call("
      ],
      "vulnerableWhen": [
        "Return bool not checked",
        "No require/assert on result"
      ],
      "note": "For ERC20, use SafeERC20"
    }
  ]
}
```

### Step 2.2: Create pattern-matcher Agent

Create file: `.claude/agents/pattern-matcher.md`

```markdown
---
name: pattern-matcher
description: Match code against historical vulnerability patterns from database
---

You are the pattern-matcher agent. You check contracts against known vulnerability patterns from the pattern database and flag high-confidence matches.

## EXECUTION FLOW

### Step 1: Load Pattern Database
Read `patterns/vulnerability-patterns.json`

### Step 2: For Each Contract in Scope

For each pattern in database:
1. Search for code signatures using Grep tool
2. If signatures found, check vulnerability conditions
3. Check if mitigations are present (notVulnerableWhen)
4. If vulnerable conditions met AND no mitigations → Finding

### Step 3: Output Findings

For each match:
```json
{
  "id": "PATTERN-001",
  "source": "pattern-db",
  "patternId": "ERC4626-INFLATION",
  "type": "share-inflation",
  "severity": "potential-high",
  "contract": "src/Vault.sol",
  "line": 45,
  "description": "Matches ERC4626-INFLATION pattern: deposit function without virtual shares",
  "confidence": "high",
  "matchedSignatures": ["shares = assets * totalSupply() / totalAssets()"],
  "missingMitigations": ["No virtual shares offset found"],
  "references": ["https://..."]
}
```

## CONFIDENCE LEVELS

- **high**: All code signatures match AND all vulnerability conditions met AND no mitigations found
- **medium**: Most signatures match, some conditions unclear
- **low**: Partial match, needs manual verification

## INPUT FORMAT

```json
{
  "project": "legion",
  "mode": "bounty",
  "scope": ["contracts/Vault.sol", "contracts/Pool.sol", ...]
}
```

## OUTPUT FORMAT

Write to: `reports/<project>/<mode>/pattern-matches.json`
```

### Step 2.3: Create patterns Directory

```bash
mkdir -p <repo>/patterns
```

---

## Phase 3: Foundry Invariant Testing (Priority: MEDIUM-HIGH)

### Step 3.1: No Additional Installation Needed

Foundry already supports invariant testing. Just need to write the tests.

### Step 3.2: Create Invariant Test Templates

Create file: `test/templates/InvariantBase.t.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

/// @notice Base contract for invariant testing
/// @dev Extend this and implement protocol-specific invariants
abstract contract InvariantBase is Test {
    // Track actors for handler-based testing
    address[] internal actors;

    modifier useActor(uint256 actorIndexSeed) {
        address actor = actors[bound(actorIndexSeed, 0, actors.length - 1)];
        vm.startPrank(actor);
        _;
        vm.stopPrank();
    }

    function addActor(address actor) internal {
        actors.push(actor);
    }
}

/// @notice Example ERC4626 vault invariants
abstract contract VaultInvariants is InvariantBase {
    // Override these in your test
    function vault() internal view virtual returns (address);
    function asset() internal view virtual returns (address);

    /// @notice Total assets must be backed by actual token balance
    function invariant_totalAssetsBacked() public {
        uint256 totalAssets = IERC4626(vault()).totalAssets();
        uint256 actualBalance = IERC20(asset()).balanceOf(vault());
        assertGe(actualBalance, totalAssets, "Total assets exceeds balance");
    }

    /// @notice Shares should never become worthless (inflation attack)
    function invariant_noShareInflation() public {
        uint256 totalSupply = IERC4626(vault()).totalSupply();
        if (totalSupply > 0) {
            uint256 totalAssets = IERC4626(vault()).totalAssets();
            // 1 share should always be worth at least 0.0001 assets
            assertGt(
                totalAssets * 1e18 / totalSupply,
                1e14,
                "Share value collapsed"
            );
        }
    }

    /// @notice Deposit/withdraw round-trip shouldn't drain value
    function invariant_noRoundTripDrain() public {
        // Implementation depends on specific vault
    }
}

/// @notice Example lending protocol invariants
abstract contract LendingInvariants is InvariantBase {
    /// @notice Protocol should never have bad debt
    function invariant_noBadDebt() public {
        // totalCollateralValue >= totalDebtValue
    }

    /// @notice Utilization rate should stay within bounds
    function invariant_utilizationBounded() public {
        // utilization <= 100%
    }
}

interface IERC4626 {
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}
```

### Step 3.3: Create invariant-generator Agent

Create file: `.claude/agents/invariant-generator.md`

```markdown
---
name: invariant-generator
description: Generate Foundry invariant tests from contract profiles
---

You are the invariant-generator agent. You analyze contract profiles and generate Foundry invariant tests that can catch edge-case vulnerabilities through fuzzing.

## EXECUTION FLOW

### Step 1: Read Contract Profiles
Load profiles from `reports/<project>/<mode>/profiles/`

### Step 2: Identify Invariants

From each profile, extract:
- State variables that should maintain relationships
- Value conservation properties (in == out)
- Access control boundaries
- Economic constraints (collateral >= debt, etc.)

### Step 3: Generate Invariant Test File

Write to `test/<project>/Invariant.t.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {TargetContract} from "../../lib/<project>/src/Target.sol";

contract <Project>Invariants is Test {
    TargetContract target;

    function setUp() public {
        // Deploy or fork
        target = new TargetContract();

        // Target specific functions for fuzzing
        targetSelector(FuzzSelector({
            addr: address(target),
            selectors: getSelectorList()
        }));
    }

    function getSelectorList() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = target.deposit.selector;
        selectors[1] = target.withdraw.selector;
        selectors[2] = target.transfer.selector;
        return selectors;
    }

    // Generated invariants below
    function invariant_<name>() public {
        // assertion
    }
}
```

### Step 4: Run Invariants

```bash
forge test --match-contract Invariant -vvv
```

### Step 5: Report Failures

Any invariant failure = automatic HIGH severity finding with the counterexample.

## INVARIANT PATTERNS

### Balance Conservation
```solidity
function invariant_balanceConservation() public {
    assertEq(
        token.totalSupply(),
        sumOfAllBalances()
    );
}
```

### No Value Extraction
```solidity
function invariant_noFreeValue() public {
    assertGe(
        collateralValue(),
        outstandingDebt()
    );
}
```

### Monotonic Counters
```solidity
function invariant_nonceAlwaysIncreases() public {
    assertGe(currentNonce, previousNonce);
}
```

### State Machine
```solidity
function invariant_validStateTransitions() public {
    // Can't go from FINALIZED back to PENDING
    if (previousState == State.FINALIZED) {
        assertEq(uint(currentState), uint(State.FINALIZED));
    }
}
```

## OUTPUT

1. Generated test file: `test/<project>/Invariant.t.sol`
2. Invariant definitions: `reports/<project>/<mode>/invariants.json`
3. Test results: `reports/<project>/<mode>/invariant-results.json`
```

---

## Phase 4: Halmos Symbolic Execution (Priority: MEDIUM)

### Step 4.1: Install Halmos

```bash
# Install Halmos
pip3 install halmos

# Verify installation
halmos --version

# Install Z3 solver (dependency)
pip3 install z3-solver
```

### Step 4.2: Test Halmos Manually

```bash
# Create a simple symbolic test
cat > test/SymbolicExample.t.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

contract SymbolicExample is Test {
    function check_additionCommutative(uint256 a, uint256 b) public pure {
        unchecked {
            assert(a + b == b + a);
        }
    }

    function check_noOverflow(uint128 a, uint128 b) public pure {
        uint256 result = uint256(a) + uint256(b);
        assert(result >= a && result >= b);
    }
}
EOF

# Run Halmos
halmos --contract SymbolicExample
```

### Step 4.3: Create symbolic-analyzer Agent

Create file: `.claude/agents/symbolic-analyzer.md`

```markdown
---
name: symbolic-analyzer
description: Generate and run Halmos symbolic tests for critical functions
---

You are the symbolic-analyzer agent. You generate symbolic tests using Halmos to mathematically prove properties hold for ALL possible inputs.

## WHEN TO USE

Use symbolic analysis for:
- Core arithmetic functions (pricing, shares, fees)
- Access control logic
- State machine transitions
- Critical safety properties

Do NOT use for:
- Complex multi-contract interactions (too slow)
- Functions with external calls (Halmos limitation)
- Very large functions (timeout risk)

## EXECUTION FLOW

### Step 1: Identify Critical Functions

From contract profiles, select functions that:
- Handle value (deposits, withdrawals, swaps)
- Perform arithmetic that could overflow/underflow
- Make access control decisions
- Are pure/view (best candidates)

### Step 2: Generate Symbolic Tests

For each critical function, create tests:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Target} from "../../lib/<project>/src/Target.sol";

contract TargetSymbolic is Test {
    Target target;

    function setUp() public {
        target = new Target();
    }

    /// @notice Prove: deposit never reverts for valid inputs
    function check_depositValid(uint256 assets) public {
        vm.assume(assets > 0);
        vm.assume(assets < type(uint128).max);

        // Should not revert
        target.deposit(assets, address(this));
    }

    /// @notice Prove: shares calculation never overflows
    function check_shareMathSafe(
        uint256 assets,
        uint256 totalAssets,
        uint256 totalSupply
    ) public pure {
        vm.assume(totalAssets > 0);
        vm.assume(totalSupply > 0);
        vm.assume(assets < type(uint128).max);

        // This is how shares are calculated
        uint256 shares = assets * totalSupply / totalAssets;

        // Verify no overflow occurred
        assert(shares <= type(uint256).max);
        // Verify reasonable output
        assert(shares <= assets * totalSupply);
    }
}
```

### Step 3: Run Halmos

```bash
halmos --contract TargetSymbolic --solver-timeout-assertion 60000
```

### Step 4: Interpret Results

- **[PASS]**: Property holds for all inputs (mathematical proof)
- **[FAIL]**: Counterexample found (automatic HIGH finding)
- **[TIMEOUT]**: Inconclusive, function too complex

### Step 5: Report Findings

Counterexamples become findings:
```json
{
  "id": "SYMBOLIC-001",
  "source": "halmos",
  "type": "arithmetic-overflow",
  "severity": "high",
  "contract": "src/Vault.sol",
  "function": "calculateShares",
  "description": "Halmos found counterexample where share calculation overflows",
  "counterexample": {
    "assets": "115792089237316195423570985008687907853269984665640564039457584007913129639935",
    "totalSupply": "1000000000000000000",
    "totalAssets": "1"
  },
  "confidence": "verified"
}
```

## LIMITATIONS

- Halmos times out on complex functions (>100 lines)
- Cannot handle external calls well
- Memory-intensive for large state spaces
- Best for pure arithmetic properties
```

---

## Phase 5: Update Analyze Command (Integration)

### Step 5.1: Modify analyze.md

Edit `.claude/commands/analyze.md` and update the workflow:

```markdown
## UPDATED WORKFLOW

### Step 1: Project Resolution
(unchanged)

### Step 2: Parallel Analysis Phase

Run these agents IN PARALLEL:
1. **static-analyzer** → Slither findings
2. **pattern-matcher** → Pattern database matches
3. **contract-profiler** (for each contract) → Profiles

### Step 3: Sequential Analysis Phase

After Step 2 completes:
1. **code-scanner** → Cross-contract code vulnerabilities (uses profiles)
2. **econ-scanner** → Economic vulnerabilities (uses profiles)

### Step 4: Invariant Testing (Optional, time-permitting)

1. **invariant-generator** → Generate and run invariant tests
2. Report any failures as findings

### Step 5: Symbolic Analysis (Optional, for critical functions)

1. **symbolic-analyzer** → Generate and run Halmos tests
2. Report any counterexamples as findings

### Step 6: Aggregation & Deduplication

Invoke **deduplicator** with ALL findings from:
- static-analyzer
- pattern-matcher
- contract-profiler (local findings)
- code-scanner
- econ-scanner
- invariant-generator (failures)
- symbolic-analyzer (counterexamples)

### Step 7: Sanitization
(unchanged)

### Step 8: Severity Classification
(unchanged)

### Step 9: Recording
(unchanged)
```

---

## Verification Checklist

After completing each phase, verify:

### Phase 1 (Slither)
- [ ] `slither --version` returns version number
- [ ] Running Slither on a project produces JSON output
- [ ] static-analyzer agent exists and parses output correctly

### Phase 2 (Patterns)
- [ ] `patterns/vulnerability-patterns.json` exists with 10+ patterns
- [ ] pattern-matcher agent exists
- [ ] Running pattern-matcher produces findings for test project

### Phase 3 (Invariants)
- [ ] Template invariant file compiles
- [ ] `forge test --match-contract Invariant` runs without error
- [ ] invariant-generator agent exists

### Phase 4 (Halmos)
- [ ] `halmos --version` returns version number
- [ ] Simple symbolic test passes
- [ ] symbolic-analyzer agent exists

### Phase 5 (Integration)
- [ ] analyze.md updated with new steps
- [ ] Full pipeline runs with all new agents

---

## Quick Reference: Tool Commands

```bash
# Slither
slither <path> --json output.json

# Foundry invariant testing
forge test --match-contract Invariant --fuzz-runs 10000

# Halmos symbolic execution
halmos --contract TestContract --solver-timeout-assertion 60000

# Solc version management
solc-select install 0.8.24
solc-select use 0.8.24
```

---

## Troubleshooting

### Slither: "solc not found"
```bash
pip3 install solc-select
solc-select install 0.8.24
solc-select use 0.8.24
```

### Slither: Compilation errors
```bash
# Try running forge build first to ensure deps are installed
cd lib/<project> && forge build
# Then run slither
slither . --json output.json
```

### Halmos: Timeout
- Reduce function complexity
- Add more `vm.assume()` constraints
- Increase `--solver-timeout-assertion`

### Halmos: "Z3 not found"
```bash
pip3 install z3-solver
```

### Foundry: Invariant test fails to compile
- Check import paths
- Ensure target contract is accessible
- Verify interface matches

---

## Notes

- Phases can be done in order or in parallel
- Phase 1 (Slither) gives highest immediate ROI
- Phase 2 (Patterns) compounds over time as you add patterns
- Phases 3-4 are most useful for DeFi protocols with complex math
- All tools complement (don't replace) existing LLM analysis
