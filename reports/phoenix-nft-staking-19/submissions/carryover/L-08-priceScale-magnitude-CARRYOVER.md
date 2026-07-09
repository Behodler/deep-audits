# [CARRYOVER] L-08 — NFTStakerPriceScaled priceScale magnitude unchecked (silent emission/runway mis-sizing)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phoenix-nft-staking`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/NFTStakerPriceScaled.sol#L230-L435` (constructor / `_recomputeSchedule`)
- **First seen:** phoenix-nft-staking-17  ·  **Still present as of:** phoenix-nft-staking-19
- **Original report:** [reports/phoenix-nft-staking-17/findings/low/L-08-pricescale-magnitude-unchecked.json](../../phoenix-nft-staking-17/findings/low/L-08-pricescale-magnitude-unchecked.json)
- **Fingerprint:** `0200236f…`

Re-confirmed present @321d0a9 by this cold-full scan (DEDUP-19-009). NOT re-reported. Immutable `priceScale` is unbounded/decimal-unchecked beyond ctor `!=0`; a wrong-magnitude deploy value silently mis-sizes emission rate/runway. Solvency-safe, owner-correctable via `setTargetAPY`; Law-3 non-obvious deploy-time footgun. See the original finding record for the full description, impact, and recommendation (deploy-time assert `priceScale == 10**(rewardDecimals - priceDecimals)`).
