# UniPoolerV2 — light profile (escrow-facing surface; unchanged this run)
- **Surface the escrow reads (constructor only):** `pair()`, `router()`, `sUSDS()`, `phUSD()`. All four are immutable.
- **Guarantees the escrow relies on:** the constructor enforces pair tokens == {sUSDS, phUSD} (`PairTokenMismatch`) and `pair == IUniswapV2Factory(router.factory()).getPair(sUSDS, phUSD)` (`PairNotCanonical`). The second check is also why a poisoned pair cannot be swapped out (escrow LOCAL-001).
- **Inbound value from the escrow:** LP (POL, which only leaves via owner `rescueERC20`), skimmed sUSDS/phUSD, and sUSDS shares from `wrapUsds`.
- **`pool()`:** `onlyAuthorizedPooler`/`whenNotPaused`/`nonReentrant`. It syncs first and reverts `EmptyPair` before the seed, so it cannot pre-empt the escrow.
- **Prior findings:** none changed by the escrow. L-22/L-24/Q-20 are wont-fix, Q-21 is fix-pending, Q-23 is open. L-24 (dust pre-seed) is the root of escrow LOCAL-001.
- **Local findings:** none new.
