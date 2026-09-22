# QA Report for phoenix-phase-2-staging, run 37 (script audit)

- **Run**: `phoenix-phase-2-staging-37`
- **Source**: [Behodler/phoenix-phase-2-staging @ `1349be8`](https://github.com/Behodler/phoenix-phase-2-staging/tree/1349be82a717fcf9a30725d2e9cc047b4f3721d6), branch `master`, read-only
- **Nested source**: `lib/stable-staker` pinned at [Behodler/stable-staker @ `cf8de27`](https://github.com/Behodler/stable-staker/tree/cf8de2718816a1c7df794dafb9d567e5694d826d) by the commit above
- **Entry point**: `stable-staker-v2-cutover`
- **Inputs**: `reports/37/findings/low/stable-staker-v2-cutover__L-13.json`, `reports/37/findings/qa/stable-staker-v2-cutover__Q-07.json`

> **Faithfulness is not in this file.** This run's story deviation, **F-05** (`pps37f5`), is reported in [`spec-conformance.md`](./spec-conformance.md). Carryover QA from earlier runs is not merged or renumbered here.

## Summary

| Severity | Count |
|----------|------:|
| Low Risk | 1 |
| QA | 1 |
| Centralization | 0 |
| **Total** | **2** |

Neither finding has an asset, value or availability impact in this cutover.

---

## Low Risk Findings

### [L-13] package.json runbook comment still says the set-aside buffer pct is "copied from V1's source" for every token <!-- id: pps37l13 -->

- **Fingerprint**: `071ce9f9120a4ff30e468a6c8a5c0671c2b020c750d3099cc6f95806c83c9a9f`
- **Root cause class**: `StaleRunbookDoc`
- **Location**: [package.json#L49](https://github.com/Behodler/phoenix-phase-2-staging/blob/1349be82a717fcf9a30725d2e9cc047b4f3721d6/package.json#L49) (`//StableStakerV2Cutover`)

**Description**: Commit `1349be8` set V2's set-aside buffer to zero on the sDOLA destination strategy. The script NatSpec was updated to match ([CutoverStableStakerV2Mainnet.s.sol#L68-L73](https://github.com/Behodler/phoenix-phase-2-staging/blob/1349be82a717fcf9a30725d2e9cc047b4f3721d6/script/CutoverStableStakerV2Mainnet.s.sol#L68-L73)): the pct is V1's pct on the source for USDC and USDe, and zero for DOLA. The operator runbook comment in `package.json` L49 was not updated. It still reads "set-aside buffer pct copied from V1's source" for every token.

**Impact**: None on chain. The script asserts the correct target (0 for DOLA) in Phase 4, Phase 8 and the verifier, and nothing reads this text. At worst, an operator reading the runbook mistakes the correct DOLA `0%` log line for a failure. The story deviation itself is covered separately by F-05.

**Recommendation**: Change package.json L49 to: "set-aside buffer pct copied from V1's source (USDC/USDe); ZERO on the sDOLA destination (DOLA)", so it matches the script NatSpec at L68-73.

---

## QA Findings

### [Q-07] With V2's sDOLA buffer at 0, `initiateMigration` has no idle top-up for floored share-redemption dust <!-- id: pps37q7 -->

- **Fingerprint**: `7c0c0c7c443a7a9321d9b2bc858d514ef436cbd27fe3a764b1f4d04cc7352b3b`
- **Root cause class**: `ZeroBufferRemovesMigrationRoundingCushion`
- **Location**: [StableStakerV2.sol#L838-L842](https://github.com/Behodler/stable-staker/blob/cf8de2718816a1c7df794dafb9d567e5694d826d/src/StableStakerV2.sol#L838-L842) (`initiateMigration`). The file is `lib/stable-staker/src/StableStakerV2.sol` in the staging repo at `1349be8`.
- **Verified**: **No.** This was reasoned from source and not measured on a fork. The sDOLA strategy's own rounding may keep the value at or above booked principal, in which case the shortfall is zero in practice.

**Description**: `initiateMigration` measures the realised amount from the contract balance, `R = min(IERC20(token).balanceOf(address(this)), P)`, so any set-aside buffer already held by V2 cushions a below-par exit. With the DOLA buffer pct now zero, V2 holds no idle DOLA for that purpose. At a future V2 terminal migration off the sDOLA strategy, a floored share-to-asset redemption could leave `R` a few wei below `P`.

**Impact**: A few wei of DOLA, spread pro rata across DOLA stakers, at a future owner-initiated V2 migration off the sDOLA strategy. It cannot happen in this cutover, and no attacker can steer it. This is rounding dust, not an owner footgun.

**Recommendation**: Accept and document; no code change. A non-zero DOLA pct is not warranted to cover wei dust, because it would divert about 10% of DOLA yield. If a cushion is wanted before a future V2 DOLA `initiateMigration`, transfer a nominal amount of DOLA straight to V2 (the idle balance `R` reads), as the `_targetBufferPct` NatSpec suggests. Record this in the story written for R37-CUT-01.

---
