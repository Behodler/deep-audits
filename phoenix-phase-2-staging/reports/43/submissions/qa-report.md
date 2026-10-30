# QA Report for phoenix-phase-2-staging: script audit `balancer-lp-migrator` (run 43)

**Project**: `phoenix-phase-2-staging`  ·  **Run**: `phoenix-phase-2-staging-43`
**Commit**: `8765278bebfffc46fed96996ea17df9cfa879fad` (`8765278`), branch `master`
**Entry point**: `balancer-lp-migrator`  ·  **Fork block**: 26,303,097
**Story**: story-121, `~/code/product-owner/stories/phStaging2/auto-complete/balancer-lp-migrator/121-balancer-lp-migrator.md` (state: `auto-complete`, which is final)

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 1 |
| Centralization | 0 |
| **Total** | **1** |

This run raised no Centralization findings. `BalancerLPMigrator` has no owner and no privileged functions.

Carryover QA from earlier runs is not merged here. It is published separately under `submissions/carryover/`, per finding-manager.

---

## Low Risk Findings

### [L-01] `migrate()` accepts 1-wei slippage floors, so the story's "no zero slippage floors" rule does not protect against sandwiches <!-- id: pps43l1 -->

**Entry point**: `balancer-lp-migrator`

**Location**: [src/periphery/BalancerLPMigrator.sol#L232-L246](https://github.com/Behodler/phoenix-phase-2-staging/blob/8765278bebfffc46fed96996ea17df9cfa879fad/src/periphery/BalancerLPMigrator.sol#L232-L246), `migrate()`

**Fingerprint**: `357565f8425a3e2c3007f71c92d5627ba22e9a91fd9ed51b7c5fee7254013fc8`
(`sha256(src/periphery/BalancerLPMigrator.sol:migrate:IneffectiveSlippageFloor:balancer-lp-migrator)`)

**Story**: story-121

**Status**: wont-fix (owner triage 2026-10-30 — floors to be enforced in the phlimbo-ui migrate modal). Owner: *"I'll deal with it on the ui side."* The contract stays as it is. The modal must derive all four minimums from `previewMigrate(bpt)` at signing time, minus a bounded tolerance, and use a short `deadline`.
**Reopen trigger**: `BalancerLPMigrator` is promoted for direct or Etherscan use without UI-derived floors, or the phlimbo-ui migrate modal ships without deriving all four mins from `previewMigrate` at signing time (bounded tolerance, short deadline).

```solidity
        if (minSUSDSOut == 0 || minPhUSDOut == 0 || amountSUSDSMin == 0 || amountPhUSDMin == 0) {
            revert ZeroMinimum();
        }

        IERC20(pool).safeTransferFrom(msg.sender, address(this), bptAmount);

        bool recoveryMode = _prepareExitMode();
        (sUSDSOut, phUSDOut) = _exit(bptAmount, minSUSDSOut, minPhUSDOut, recoveryMode);

        uint256 sUSDSUsed;
        uint256 phUSDUsed;
        IERC20(sUSDS).forceApprove(uniRouter, sUSDSOut);
        IERC20(phUSD).forceApprove(uniRouter, phUSDOut);
        (sUSDSUsed, phUSDUsed, liquidity) = IUniV2RouterMigrator(uniRouter)
            .addLiquidity(sUSDS, phUSD, sUSDSOut, phUSDOut, amountSUSDSMin, amountPhUSDMin, to, deadline);
```

**Description**: The only on-chain slippage rule in `migrate()` is that each of the four minimums is non-zero (L232). Story-121 gives this rule as a safety property: *"Require ... and **all four** min amounts `> 0` (Configuration Safety: no zero slippage floors)."* The contract NatSpec says the same thing (L112: *"The Balancer and V2 minimums (all four must be non-zero) are the caller's slippage guards."*). However, a 1-wei floor passes the check and is economically the same as zero. The Router02 `addLiquidity` call (L245-L246) is then priced entirely by the V2 phUSD/sUSDS pair's live reserves, and a searcher can move those reserves in the same block.

`migrate()` is permissionless and user-facing. Any BPT holder can call it, either directly through Etherscan or through the phlimbo-ui migration modal, which has not been built yet. Safe floors are only an off-chain convention: derive them from `previewMigrate(bpt)`, as the L264 NatSpec advises. No current caller has a tool that enforces this. The Balancer exit leg is not the exposure. The remaining holder owns about 100% of the BPT, and swaps are blocked once the pool is paused. The value at risk is in the V2 add.

The code follows the letter of story-121, so this is not an `F-xx`. The problem is that the story's safety rationale claims more than the rule delivers, which makes it an unsafe-story flag under Law 1 over Law 2. `spec-conformance.md` cross-references it.

**Impact**: The fork at block 26,303,097 ran a migration of the whole holding: 12,036.97 BPT exited to 11,096.40 sUSDS + 13,145.69 phUSD, about 22,206 sUSDS of value. The pair's reserves were 20,772.46 sUSDS / 24,578.08 phUSD.

- **1-wei floors** (`test_r43_sandwich_oneWeiFloors`): every sandwich of the V2 add succeeded.
  - A 10,000 sUSDS front-run/back-run cost the holder **1,101.79 sUSDS (about 5.0%)**, and the attacker netted **+893.92 sUSDS**.
  - The 10,000 phUSD-in direction cost the holder 866.59 sUSDS (attacker +688.99).
  - A 2,000-token sandwich cost the holder 54.55 to 74.80 sUSDS, depending on direction.
- **Floors 50 bp below an unmanipulated `previewMigrate`** (`test_r43_sandwich_50bpFloors`):
  - Every 2,000 and 10,000 front-run, in both directions, **reverts**.
  - The 20 and 50 token front-runs that fit inside the band lose the attacker 0.10 to 0.26 sUSDS. The holder's worst case is 0.004 sUSDS.

The contract's protection therefore works when the floors are meaningful. All of the remaining exposure comes from the floors the caller chooses. Today the realistic set of victims is one EOA (`0xc65f…e8db`, which holds about all of the remaining BPT). It would call through Etherscan or directly, with no floor guidance. BIP-928 makes this migrator the only exit for a position of about $25k.

**Severity rationale**: This is Low (QA). Choosing unsafe slippage parameters is user-input error under C4 rules, and that caps the finding below Medium. It is still reported rather than discarded for three reasons:
- story-121 and the NatSpec present the `!= 0` rule as slippage protection, which it is not;
- the funds are third-party LP funds, not protocol-owned liquidity;
- the UI that would compute safe floors does not exist yet.

**Proof of Concept**: `phoenix-phase-2-staging/work/test/audit-run43/BalancerLPMigratorRun43.fork.t.sol`
- `test_r43_sandwich_oneWeiFloors`: PASS (shows the 1-wei extraction)
- `test_r43_sandwich_50bpFloors`: PASS (bounded floors make every profitable sandwich revert)

Log: `phoenix-phase-2-staging/reports/43/script-audits/balancer-lp-migrator/evidence/run43-tests.log` (suite: 19 passed, 0 failed).

**Recommendation**:
1. **Bind the UI story.** The phlimbo-ui migration-modal story should require that all four floors come from `previewMigrate(bpt)`, read when the user signs, minus an explicit bounded tolerance (for example ≤ 50 bp), and that a short `deadline` is used.
2. **Optional on-chain hardening.** Do one of the following:
   - add the pair's reserve ratio as a caller-supplied bound, and revert if `getReserves()` has moved outside it; or
   - require the two Router02 floors to be at least `(1 - maxBps)` of the Balancer outputs, valued at the pair ratio.

   Either option makes a 1-wei floor impossible, not merely discouraged.
3. **At minimum**, amend the story-121 text and the contract NatSpec (L112) so that "non-zero" is no longer presented as slippage protection. Point callers to `previewMigrate` as the required source of the floors.

```solidity
// Illustrative hardening: bound the V2 floors relative to the Balancer outs
uint256 constant MAX_SLIPPAGE_BPS = 50;
if (amountSUSDSMin * 10_000 < sUSDSOutExpected * (10_000 - MAX_SLIPPAGE_BPS)) revert FloorTooLoose();
if (amountPhUSDMin * 10_000 < phUSDOutExpected * (10_000 - MAX_SLIPPAGE_BPS)) revert FloorTooLoose();
```

**Prior owner decisions (disclosure)**: The owner has three times marked a finding in the same MEV class `wont-fix` in `yield-claim-nft`: a V2 or Balancer LP-add priced at live reserves and protected only by floors. Those decisions are disclosed here, quoted verbatim from the ycn ledger:

- **ycn L-22** (`ycn20l22`, `a846cc40e6d6…`, `UniPoolerV2.pool`): `wont-fix`.
  > "Owner triage 2026-10-01: intended by design. Owner: \"That's the nature of tolerance. We're literally tolerating an attack of this size.\" The keeper-chosen tolerance t is the accepted MEV budget; per-zap extraction is bounded at ~0.44*t*Delta (ECON-001) on protocol-owned liquidity only, no user funds. Disposition does NOT cover sibling L-06 (342075dfba, BalancerPoolerV2.pool), which stays open, nor L-23 (shared-venue floor staleness), whose stale-floor mechanism could widen the effective tolerance beyond t."
- **ycn L-06** (`342075dfba3c…`, `BalancerPoolerV2.pool`): `wont-fix`.
  > "Owner triage 2026-10-01: wont-fix. Owner: \"We're retiring BalancerPooler so definitely close L-06.\" Two grounds: (1) BalancerPoolerV2 is being retired (story-050 delete-balancer-interfaces-post-winddown, currently in incomplete/ at 2bfa090, so the contract is still live until it lands); (2) in the interim the same tolerance rationale as L-22 ycn20l22 applies: keeper-chosen tolerance is the accepted MEV budget on protocol-owned liquidity. Does NOT cover L-23 floor staleness. If BalancerPoolerV2 is NOT retired, or is re-used by new code, this disposition should be revisited."
- **ycn L-15** (`e64f73d62919…`, `PromotionUniV2_Eth.pool`): `wont-fix` (2026-07-19).
  > "Owner-accepted wont-fix (2026-07-19): user understands the tradeoffs. On-chain-priceless LP-add MEV on PromotionUniV2_Eth Legs A/B is keeper-floor-bounded (all 5 min-out floors + minLP present), POL-only, no user funds; residual sandwich exposure on the thin ETH->promotion hop accepted as keeper-hygiene responsibility. Sibling of L-06."

**Why those dispositions do not carry over**: All three rest on the same premise. In each case a **keeper** the protocol controls chooses a bounded tolerance, the liquidity at stake is **protocol-owned**, and **no user funds** are exposed. None of those conditions holds here:
- `migrate()` is permissionless;
- the floors are chosen by an arbitrary caller and can be as loose as 1 wei;
- the funds are third-party LP funds. Story-121 Context says Sprint 34 already migrated the protocol's own LP, and the remaining BPT belongs to third parties.

The owner's tolerance stance is useful evidence of how much risk the owner accepts. It does not decide this finding, which is filed as new.

**Related open finding**: **ycn Q-24** (`ycn22q24`, `88bfa9493621…`, `UniPoolerCutoverEscrow.exitAndSeed`, `open`) has the same mechanism. There, `minAmountsOut` is only checked for `> 0`, 1 wei passes, and price protection is entirely off-chain. It is not a duplicate. Q-24 concerns an operator-gated, one-shot cutover of protocol funds, where the fork showed the sandwich to be net-negative. L-01 concerns a permissionless, user-facing migrator holding third-party funds, where the fork showed the sandwich to be profitable.

**Human review flag (resolved 2026-10-30)**: The open question was whether this is Low or invalid (user input), and whether direct or Etherscan calls to `migrate()` are an intended, unattended path. The owner resolved it by triage. Migrations are expected to go through the phlimbo-ui modal, which will enforce `previewMigrate`-derived floors, and the finding is `wont-fix` at Low. If direct or Etherscan use without UI-derived floors becomes an intended path, the reopen trigger above applies, and severity should be re-weighed toward Medium at that point.

---

## Centralization Risks

None this run.

---

## Appendix: Automated QA/gas report (4naly3er)

4naly3er was run scoped to `src/periphery/BalancerLPMigrator.sol`. The base path was `phoenix-phase-2-staging/work/`, whose copy of the file is byte-identical to `src/` at `8765278`. There were 0 import-resolution failures. The full output is in [`4naly3er-report.md`](./4naly3er-report.md).

| Category | Issue types |
|---|---|
| Medium (bot) | 1: M-1, fee-on-transfer accounting (out of scope: sUSDS and phUSD are not FoT) |
| Low (bot) | 5: zero-value transfers, division by zero, deadline equality, rounding, precision loss |
| Non-critical | 13 |
| Gas | 8 |

No bot finding was promoted to the manual bundle. The bot issues were triaged by category only, not instance by instance. No category covers the slippage-floor root cause of L-01, and none comes with a demonstrated High or Medium exploit path.
