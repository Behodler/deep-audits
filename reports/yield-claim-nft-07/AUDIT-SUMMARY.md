# yield-claim-nft — Audit Summary (report 7)

**Scope commit:** [`1bb956c`](https://github.com/Behodler/yield-claim-nft/commit/1bb956c77cf9dab693fba88d773fd2316a7f2f0f) — `[story-033] Add migrateMint(uint256, address) to BalancerPoolerV2`

**Delta vs. previously reviewed commit (`c67d3c9`):** Purely additive (`git diff c67d3c9..1bb956c -- src/`). `BalancerPoolerV2.sol` gains one import (`INFTMinterV2`), two internal constants (`OLD_NFT_ID = 4` at L35, `NEW_NFT_INDEX = 6` at L40), and one external function (`migrateMint(uint256, address)` at L335-344). No other in-scope source file changed; line numbers on existing report-6 findings shift by approximately +11 for code below the insertion point, but bodies are byte-identical.

**Reference plan:** [`balancer-pooler-v3-and-staker-v2-migration-plan.md`](/home/justin/code/product-owner/scratchpad/planning-docs/phoenix/phase2/phoenix-nft-staking/v2/balancer-pooler-v3-and-staker-v2-migration-plan.md)

**Pipeline run:** code-scanner + econ-scanner in parallel → deduplicator (merged cross-scanner duplicates, sanitized cross-repo concerns, severity-classified per C4 regular-audit criteria). 14 raw findings → 4 Medium (all carry-forward) + 5 Low (all new) + 1 out-of-scope.

---

## 1. Does the change align with the plan?

**Yes — for yield-claim-nft's own slice of the plan.** Per the plan's "Scope by Project" table, yield-claim-nft's responsibility is "New `BalancerPoolerV3` dispatcher with `migrateMint` side-function. Inherits the existing pooler interface for new id-6 mints (USDS pay path unchanged)." That has been delivered.

| yield-claim-nft scope item from plan | Status |
|---|---|
| `migrateMint(uint256 amount, address mintRecipient)` external entry point | ✅ Shipped (`BalancerPoolerV2.sol:335-344`) |
| Burn id-4 from caller (no holder approval required, gated only by `authorizedBurners`) | ✅ Matches plan pseudocode |
| `mintFor` minted to `mintRecipient`, one NFT per loop iteration | ✅ Matches plan pseudocode |
| `configs[6].price` deliberately NOT advanced by migration | ✅ Confirmed — `mintFor` does not touch `configs[index].price`, only `_executeMint` does |
| USDS pay-path interface unchanged | ✅ `_dispatch` and `pool()` byte-identical to report-6 |

**One naming observation, not a finding:** the plan calls the new contract `BalancerPoolerV3`; the team kept the source name `BalancerPoolerV2` and treats the deployed instance behind `replaceDispatcher(6, ...)` as "V3". Functionally equivalent. Worth aligning the plan's terminology with the source for runbook clarity.

Cross-repo deliverables that the plan explicitly assigns to other submodules — `NFTStakerV2.stakeFor` / `withdrawRewardToken` (in `phoenix-nft-staking`), `MigrationHelper.sol` (in `phoenix-phase-2-staging`), the deployment broadcast script (also `phase-2-staging`), the runway phUSD mint (operator action) — are **not** yield-claim-nft's job and are out of scope for this audit.

---

## 2. Findings

### Mediums (4) — all carry-forward from report 6, all re-validated at HEAD

The code locations cited in report-6 are byte-identical at `1bb956c`; only line numbers shifted. PoCs from report-6 (`workspace/yield-claim-nft/test/poc-ECON-RAW-*.t.sol`) still apply.

| ID | Severity | Title | New line range |
|----|----------|-------|----------------|
| [ECON-RAW-001](audit/submissions/M-01-submission.md) | Medium | Single-sided UNBALANCED Balancer V3 add is MEV-extractable; caller-supplied `minBPT` is the only on-chain defence | `BalancerPoolerV2.sol:257-284` (was 246-273) |
| [ECON-RAW-002](audit/submissions/M-02-submission.md) | Medium | Donation swap (sUSDS → waUSDC) executes with `limitRaw=0`; only post-unwrap USDC slippage is checked | `BalancerPoolerV2.sol:225-254` (was 214-243) |
| [ECON-RAW-003](audit/submissions/M-03-submission.md) | Medium | `BalancerPoolerMintDebtHook` accrues phUSD debt against dispatched USDS notional, decoupled from realisable USDC | `BalancerPoolerMintDebtHook.sol:112-122` (unchanged) |
| [ECON-RAW-006](audit/submissions/M-04-submission.md) | Medium | Donation revert inside `unlockCallback` bricks LP-add; full DoS by USDC blocklist, Aave pause, or pool depletion | `BalancerPoolerV2.sol:217-254` (was 207-243) |

Submission files in `reports/yield-claim-nft-06/audit/submissions/M-{01..04}-submission.md` remain canonical. Re-using them as-is for report 7 is the recommended path — no content rewrites needed beyond updating cited line numbers.

### Lows (5) — all new, all tied to the `migrateMint` addition

| ID | Severity | Title |
|----|----------|-------|
| [DEDUP-L01](audit/findings/low/DEDUP-L01-migrate-reentrancy.json) | Low | `migrateMint` loops `mintFor` without `nonReentrant`; each iteration's ERC1155 acceptance callback exposes a partial-state observation window |
| [DEDUP-L02](audit/findings/low/DEDUP-L02-migrate-hardcoded-ids.json) | Low | `OLD_NFT_ID=4` / `NEW_NFT_INDEX=6` are hardcoded constants with no assertion that this contract is the canonical id-6 dispatcher — silent rerouting under `replaceDispatcher(6, X)` race, copy-paste re-deploy hazard, no post-migration lock |
| [DEDUP-L03](audit/findings/low/DEDUP-L03-migrate-pause-bypass.json) | Low | `migrateMint` bypasses all three pause/disable surfaces (`NFTMinterV2.paused`, `BalancerPoolerV2.paused`, `configs[6].disabled`); intentional per `test_migrateMint_runsWhenPaused`, but operator runbook gap |
| [RAW-002](audit/findings/low/RAW-002.json) | Low | O(`amount`) per-unit `mintFor` loop; large id-4 holders can be priced out at the block-gas limit (same pattern as report-6 L-08) |
| [RAW-006](audit/findings/low/RAW-006.json) | Low | No contract-level `Migrated` event; off-chain reconstruction must structurally match byproduct emissions on `NFTMinterV2` |

These five are the only new code-level / economic findings from the delta. The deduplicator merged the scanners' overlapping framings into the three `DEDUP-L*` entries.

### Lows (10) — carry-forward from report 6

All ten Lows from `reports/yield-claim-nft-06/audit/submissions/qa-report.md` (L-01 through L-10) still apply at HEAD. Code paths are byte-identical. L-05, L-06, and L-08 are particularly relevant alongside the new DEDUP-L03 and RAW-002 because they describe the same pause-topology and per-unit-loop patterns now also present on the migration path.

### Out of scope (1)

| ID | Why deferred |
|----|--------------|
| [ECON-RAW-009](audit/findings/_out_of_scope/ECON-RAW-009.json) | Deployment-ordering / staker top-up race. The on-chain symptom (early migrators capturing a disproportionate share of NFTStakerV2 reward runway if migration opens before step-11 top-up) is real, but the responsibility for ordering lives in `phoenix-phase-2-staging`'s broadcast script and in NFTStakerV2's reward-accrual semantics. Flag during those repos' audits. |

### No Highs or Criticals

The scanners considered and explicitly ruled out:
- Force-burn of arbitrary holders' id-4 NFTs — blocked by `msg.sender`-only burn target
- Inflation from nothing — blocked by the 1:1 burn:mint invariant
- Price-curve manipulation via migration — blocked because `mintFor` doesn't touch `configs[index].price`
- Hook accrual against migration — blocked because `migrateMint` doesn't route through `_dispatch`
- Reentrancy into value-flow paths — blocked by `nonReentrant` + `onlyMinter` on `dispatch` / `pool`

The DEDUP-L01 reentrancy is a *latent* surface (no in-scope consumer currently reads `totalSupply(6)` during a state-mutating path) — promotable to Medium only if NFTStakerV2 (out of scope) is designed to read `totalSupply(stakedId)` inside accrual math. Worth a back-and-forth with the NFTStakerV2 team before that work lands.

---

## 3. Recommendations

**Strictly within yield-claim-nft's scope:**

1. **Add `nonReentrant` to `migrateMint`** (one-line change; `ATokenDispatcherV2` already inherits OZ `ReentrancyGuard`). Cheapest possible mitigation for DEDUP-L01.
2. **Add a canonical-dispatcher consistency check** at the top of `migrateMint`:
   ```solidity
   require(
       INFTMinterV2(minter).tokenIdToDispatcher(NEW_NFT_INDEX) == address(this),
       "BalancerPoolerV2: not canonical id-6 dispatcher"
   );
   ```
   Single SLOAD; closes the `replaceDispatcher(6, X)` race, dual-authorisation, and copy-paste-redeploy traps in DEDUP-L02 in one stroke.
3. **Consider an irreversible `migrationClosed` switch** (owner-set, default false). Gives the operator a fast lever to halt migrations without revoking `authorizedBurner`/`authorizedMinter` (which may have other dependents). Addresses DEDUP-L03 operationally.
4. **Document the pause-bypass as intentional** in the `migrateMint` NatSpec and add the revocation runbook line to the operator playbook. DEDUP-L03 either gets recommendation (3) or accepts this documentation path; pick one.
5. **Emit a single `Migrated(caller, mintRecipient, amount)` event** at the end of `migrateMint`. Trivial; closes RAW-006.
6. **Consider adding `mintForBatch(index, recipient, quantity)` to `NFTMinterV2`** — single `_mintBatch` call instead of the per-unit loop. Caps RAW-002 (and the original report-6 L-08) at O(1) gas. Optional unless future migrations are anticipated for cohorts larger than ~600 NFTs.

**For the broader Phoenix phase-2 work (out of scope, flagged for handoff):**

- The carry-forward Mediums (ECON-RAW-001/002/003/006) are unchanged and will affect any fresh `BalancerPoolerV2` instance deployed via `replaceDispatcher(6, ...)`. The plan's "bug fix" wording — yet to land in this submodule per the visible commit history — should address ECON-RAW-001 and ECON-RAW-002 at minimum, ideally also ECON-RAW-003 and ECON-RAW-006.
- When NFTStakerV2 work begins in `phoenix-nft-staking`, ask whether `stakeFor` / accrual paths read `nftMinter.totalSupply(stakedId)`. If yes, DEDUP-L01 promotes to Medium and the `nonReentrant` fix becomes load-bearing.
- When the MigrationHelper is drafted in `phoenix-phase-2-staging`, the helper design must accommodate yield-claim-nft's `migrateMint(amount, mintRecipient)` signature (burns from `msg.sender`). The helper-side audit will need to decide how to authorise the burn — direct user call, ERC1155 `setApprovalForAll`, or an EIP-712 permit shape — but that's the helper's audit, not this one.

---

## 4. Artefact map

```
reports/yield-claim-nft-07/
├── AUDIT-SUMMARY.md          ← this file
└── audit/
    ├── findings/
    │   ├── medium/           4 carry-forward (ECON-RAW-001/002/003/006)
    │   ├── low/              5 new (DEDUP-L01/L02/L03 + RAW-002/006)
    │   ├── _duplicates/      7 raw findings consolidated into the DEDUP-Lxx entries
    │   ├── _out_of_scope/    1 (ECON-RAW-009 deployment ordering — cross-repo)
    │   ├── raw-code/         6 raw code-scanner findings (pre-dedup, for audit trail)
    │   └── raw-econ/         8 raw econ-scanner findings (pre-dedup, for audit trail)
    └── submissions/          (re-use reports/yield-claim-nft-06/audit/submissions/M-{01..04}.md
                               and qa-report.md verbatim — code unchanged)
```

The four Medium submissions and the QA bundle from report 6 are still canonical; only line-number references would change in a fresh write-up.
