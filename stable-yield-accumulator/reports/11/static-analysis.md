# Static Analysis - stable-yield-accumulator (run 11)

- **Project:** stable-yield-accumulator
- **Submodule commit:** `lib/stable-yield-accumulator` @ 71abe3e
- **In-scope contract:** `src/StableYieldAccumulator.sol` (749 lines, pragma `^0.8.20`)
- **Scan timestamp:** 2026-05-27
- **Scan type:** static (deterministic SAST)

## Tool versions / status

| Tool | Version | Status | Notes |
|------|---------|--------|-------|
| Slither | 0.11.3 | OK (via scratch build) | 23 raw results; compiled with solc 0.8.30 |
| Aderyn | 0.6.8 | OK (via scratch build) | 0 high, 13 low-issue categories; 88 detectors |
| Semgrep | 1.163.0 | OK (direct on file) | 59 findings, all INFO-severity (gas/best-practice) |

`missingTools`: none.

### Compilation note (important for triage)

The `lib/stable-yield-accumulator` submodule's nested dependency submodules
(`lib/vault`, `lib/phlimbo-ea`, `lib/pauser`, `lib/yield-claim-nft`) are **not
checked out** in the audit repo (registered but empty; no network/SSH to fetch
them). Both Slither and Aderyn therefore failed to compile the lib/ source
directly (`Source "lib/vault/src/interfaces/IYieldStrategy.sol" not found`).

The stale `workspace/stable-yield-accumulator` clone (~30 commits behind at
f6c52ac) is **not line-compatible** with the in-scope source — the two
`StableYieldAccumulator.sol` files diverge by ~144 lines (20-line length delta,
divergence begins at line 115), so running tools there would yield wrong line
numbers.

To get accurate line numbers against the **exact in-scope source**, a scratch
project was assembled at `/tmp/sya-scan`: the unmodified lib/ `StableYieldAccumulator.sol`
and its local `IStableYieldAccumulator.sol`, with dependency interfaces sourced
from the workspace `lib/mutable/*`. Two methods present in the newer lib/ API
(`skimSurplus(address,address) returns (uint256)` and
`getAuthorizedClients() returns (address[])`) were added to the scratch copy of
`IYieldStrategy.sol` to satisfy the compiler. **lib/ was never modified.** Line
numbers below correspond to the in-scope lib/ source. Dependency-version skew
means tools cannot see the real strategy/phlimbo/minter implementations, so any
cross-contract dataflow finding would be a candidate for false-negative — these
are raw tool outputs for downstream triage, not validated findings.

## Filtering summary

Raw results across tools: ~95 (Slither 23, Aderyn ~60 in-scope instances, Semgrep 59).
After dropping C4 QA-only / informational / optimization detectors and
out-of-scope (OpenZeppelin lib) hits, **kept = 16** normalized findings (1
potential-medium, 15 potential-low), spanning 3 distinct issue types.

Dropped categories (noise per agent spec / C4 known-QA): `missing-zero-check`,
`costly-loop`, `cyclomatic-complexity`, `low-level-calls` (OZ Address.sol, OOS),
`cache-array-length` / storage-array-length, Aderyn centralization-risk,
large-numeric-literal, literal-instead-of-constant, push0, unspecific-pragma,
unused-error, state-change-without-event, address-set-without-checks,
modifier-invoked-once, loop-contains-require, and all Semgrep INFO performance
rules (prefix-increment, custom-error-not-require, nested-if,
state-variable-read-in-loop, checked-arithmetic-in-loop, array-length, etc.).

## Normalized findings (kept)

### Potential-Medium

| id | source | type | file:line | function | description |
|----|--------|------|-----------|----------|-------------|
| SLITHER-001 | slither | divide-before-multiply | StableYieldAccumulator.sol:629 (fn 617-640) | `_denormalizeAmount` | Division performed before multiplication can lose precision. `scaled = scaled * 1e18 / exchangeRate` (L629) and `scaled = scaled / (10 ** (18 - decimals))` (L634) — ordering of the decimal-normalization / exchange-rate math may truncate. Confidence: Medium. Triage against the documented 18-decimal normalization design. |

### Potential-Low

| id | source | type | file:line | function | description |
|----|--------|------|-----------|----------|-------------|
| ADERYN-001 | aderyn | nonreentrant-not-first-modifier | StableYieldAccumulator.sol:447 | `claim` | `nonReentrant` is not the first modifier on `claim(...)`. If a preceding modifier makes an external call before the reentrancy lock engages, the guard can be bypassed. Worth checking the modifier order on `claim` (also flagged near the `whenNotPaused`/guard ordering). |
| SLITHER-002..010 | slither | calls-loop | StableYieldAccumulator.sol:484, 554, 557, 558, 707 | `claim`, `_getYieldForStrategy`, `canClaim` | External calls inside loops over strategies/clients/NFT indices: `skimSurplus` (L484), `getAuthorizedClients` (L554), `totalBalanceOf` (L557), `principalOf` (L558), `IERC1155.balanceOf` (L707). Unbounded strategy/client lists or a reverting/gas-griefing strategy can DoS claim/quote paths. Confidence: Medium. Severity is gas/availability — triage whether lists are owner-bounded. |
| SEMGREP-001 | semgrep | use-ownable2step | StableYieldAccumulator.sol:57 | (contract decl) | Uses single-step `Ownable`; ownership transfer is not two-step, so a mistyped new-owner address bricks owner controls. QA / centralization-adjacent. |

#### calls-loop instance detail (SLITHER-002..010)

| id | line | call |
|----|------|------|
| SLITHER-002 | 484 | `IYieldStrategy(strategy).skimSurplus(token, msg.sender)` (in `claim`) |
| SLITHER-003 | 554 | `yieldStrategy.getAuthorizedClients()` (in `_getYieldForStrategy`) |
| SLITHER-004 | 557 | `yieldStrategy.totalBalanceOf(token, clients[i])` |
| SLITHER-005 | 558 | `yieldStrategy.principalOf(token, clients[i])` |
| SLITHER-006 | 707 | `IERC1155(nftMinter).balanceOf(caller, i)` (in `canClaim`) |

(Slither reports the L554/557/558 calls multiple times, once per call-stack
that reaches `_getYieldForStrategy`: via `calculateClaimAmount`, `getYield`,
and `getTotalYield` -> `_getNormalizedYieldForStrategy`. Deduplicated here to
the distinct call sites.)

## Cross-tool corroboration

- **Calls-in-loop / DoS surface** is corroborated structurally by Aderyn
  (`Costly operations inside loop` L247, `Storage Array Length not Cached`
  L464/659/740, `Loop Contains require/revert` L453/653) and Semgrep
  (`array-length-outside-loop`, `state-variable-read-in-a-loop` across the same
  loops). These were filtered as individual gas findings but reinforce that the
  loop-over-strategies pattern is the contract's main availability concern.
- No tool reported reentrancy-eth/no-eth, arbitrary-send, unchecked-transfer,
  delegatecall, suicidal, weak-prng, uninitialized-state, or tx-origin on the
  in-scope contract. `divide-before-multiply` is the only non-QA Slither hit.

## Out-of-scope hits (noted, not counted)

- Slither `low-level-calls` x4 in `lib/openzeppelin-contracts/contracts/utils/Address.sol` — dependency, out of scope.
- Aderyn `PUSH0 Opcode`, `Unspecific Solidity Pragma`, `Unused Error` on `src/interfaces/IStableYieldAccumulator.sol` — interface (context only, out of audit scope per per-repo rule).

## Raw tool output files

- `/home/justin/code/C4/solidity-audit/reports/stable-yield-accumulator/11/slither-output.json`
- `/home/justin/code/C4/solidity-audit/reports/stable-yield-accumulator/11/aderyn-report.json`
- `/home/justin/code/C4/solidity-audit/reports/stable-yield-accumulator/11/semgrep-output.json`
