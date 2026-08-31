# QA Report for phoenix-nft-staking (run-17)

**Scope:** `src/NFTStakerPriceScaled.sol` (story-017)
**Commit:** `eee9d3a301bc0a2f9ff5557dd6b9875262152e95`

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 1 |
| Centralization | 0 |
| **Total** | **1** |

This run audited the single new file `NFTStakerPriceScaled.sol` — a price-scaling variant of `NFTStaker.sol` that normalizes a dispatcher's prime-token-decimal price into reward-token (phUSD) units before sizing the emission rate. There are no High, Medium, or Centralization findings. One Low-severity operational footgun is reported below, followed by two informational notes and the attached automated 4naly3er report.

---

## Low Risk Findings

### [L-08] `priceScale` magnitude is unbounded and decimal-unchecked <!-- id: pns17l8 -->

**Location**: [`NFTStakerPriceScaled.sol#L230`](../../../../lib/phoenix-nft-staking/src/NFTStakerPriceScaled.sol#L230) (constructor), [`NFTStakerPriceScaled.sol#L435`](../../../../lib/phoenix-nft-staking/src/NFTStakerPriceScaled.sol#L435) (`_recomputeSchedule`)

**Description**: The immutable `priceScale` is the magnitude that this contract exists to apply — it normalizes the dispatcher's prime-token-decimal price into reward-token (phUSD, 18dp) units. Yet the contract cannot verify it. The constructor only guards against zero:

```solidity
require(_priceScale != 0, "NFTStaker: zero price scale"); // L230
```

There is no upper bound and no decimal-consistency check. `_recomputeSchedule` then trusts the deploy-time magnitude unconditionally:

```solidity
latestPrice = latestPrice * priceScale; // L435
```

A wrong (but plausible, off-by-decimals) magnitude silently mis-sizes the emission rate and the derived runway, with no on-deploy signal:

- **Too high** — the per-second rate `R = S * targetAPY / SECONDS_PER_YEAR` is over-sized, so `runway = budget / R` collapses; the earliest stakers over-earn and the funded budget depletes prematurely, pausing emissions until a top-up.
- **Too low** — `newRate` floor-divides toward zero, silently re-introducing the floor-to-zero emission degradation that the price-scaling variant exists to fix.

There is also a **dispatcher-repoint corollary**: because `priceScale` is `immutable`, the contract is pinned to a single price-token-decimal regime. Re-pointing the dispatcher to a config with a different price-token decimal count requires a fresh deployment, not a setter call.

**Impact (why Low, not Medium/High)**: Solvency is structurally safe. `priceScale` never touches the budget ledger, and every payout is bounded by the real funded balance through `_safePay`'s shortfall-revert — there is no theft, no insolvency, and no third-party value leak. The only effect is mis-sizing the *rate/runway*, which the trusted owner can self-correct at any time via `setTargetAPY` (`priceScale` and `targetAPY` are independent linear factors on the rate). No attacker path exists; the trigger is purely a deploy-time owner config choice. Under the three-law hierarchy this is an in-scope **non-obvious operational footgun** (Law 3): a competent, non-malicious owner would be surprised that the very magnitude the feature exists to normalize is itself unverifiable on-chain. The absurd-overflow leg (a magnitude so large the multiply reverts) is an *obvious* misconfig and was correctly suppressed in dedup.

**Recommendation**:
1. Add a deploy-time invariant binding `priceScale` to the actual decimal regime, e.g.

   ```solidity
   require(
       priceScale == 10 ** (rewardToken.decimals() - priceTokenDecimals),
       "NFTStaker: price scale / decimal mismatch"
   );
   ```

   or pass `priceTokenDecimals` and derive `priceScale` internally so it cannot be supplied inconsistently.
2. Document the canonical value in the deploy runbook (`1e12` for a 6dp USDC-priced dispatcher → 18dp phUSD).
3. Emit a `PriceScaleSet(priceScale)` event in the constructor for on-chain auditability of the chosen magnitude.

---

## Informational / Notes

These are notes for completeness, not defects. No action is required.

- **N-01 — Maintenance coupling / fork drift**: `NFTStakerPriceScaled.sol` is a hand-maintained fork of `NFTStaker.sol` that adds the price-scaling layer. Future fixes to the base `NFTStaker` (emission math, solvency accounting, setter gating) must be mirrored into this variant by hand; there is no shared base contract enforcing parity. Track this coupling so the two files do not diverge silently.

- **N-02 — Floor-before-scale precision (refuted non-issue)**: `_recomputeSchedule` applies the `mulDiv` floor rounding on `latestPrice` *before* multiplying by `priceScale` (L430 then L435), which mathematically loses slightly more precision than scaling first would. The error was measured at roughly **2.5 ppb** and is **conservative for the protocol** (rounds emissions down, never up), so it cannot cause over-emission or insolvency. Explicitly evaluated and refuted — included only for completeness.

---

## Appendix: Automated Report (4naly3er)

The C4-style automated SAST/gas report generated by **4naly3er** over `src/NFTStakerPriceScaled.sol` is attached alongside this document as [`4naly3er-report.md`](./4naly3er-report.md). It surfaces standard gas-optimization and non-critical Solidity patterns (custom errors vs revert strings, `address(0)` checks, `!= 0` vs `> 0`, unchecked-block opportunities, etc.). None of its instances rise to a Low+ security finding on their own; they are provided as the automated baseline for the QA section.
