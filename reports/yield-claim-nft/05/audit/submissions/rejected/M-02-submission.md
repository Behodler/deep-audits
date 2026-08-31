<!--
C4 Submission Metadata
Title: [M-02] Reflexive feedback loop: pull() mints phUSD into the same sUSDS/phUSD pool that backs NFT holders, enabling BPT-backing drain
Root Cause Links:
  - https://github.com/Behodler/yield-claim-nft/blob/2805a4d/src/V2/hooks/BalancerPoolerMintDebtHook.sol#L97-L107
  - https://github.com/Behodler/yield-claim-nft/blob/2805a4d/src/V2/dispatchers/BalancerPoolerV2.sol#L121-L165
PoC File: workspace/yield-claim-nft/test/poc-M-02.t.sol
-->

## Finding description and impact

### Summary

`BalancerPoolerMintDebtHook.pull()` ([BalancerPoolerMintDebtHook.sol#L97-L107](https://github.com/Behodler/yield-claim-nft/blob/2805a4d/src/V2/hooks/BalancerPoolerMintDebtHook.sol#L97-L107)) mints freshly created phUSD directly to `recipient`. That phUSD is fungible with the phUSD side of the sUSDS/phUSD Balancer pool that `BalancerPoolerV2` ([BalancerPoolerV2.sol#L121-L165](https://github.com/Behodler/yield-claim-nft/blob/2805a4d/src/V2/dispatchers/BalancerPoolerV2.sol#L121-L165)) deposits sUSDS into as single-sided liquidity. A rational `recipient` will immediately swap the minted phUSD back into that same pool in exchange for sUSDS, extracting yield-bearing collateral out of the BPT position that NFT-holder claims are economically backed by. The drain is a direct consequence of how `pull()` and `_pool` are wired together, and scales linearly with dispatch throughput.

### Vulnerability details

The hook and the dispatcher jointly implement the following settlement flow:

1. Users pay USDS to mint NFTs. `BalancerPoolerV2._dispatch()` wraps incoming USDS into sUSDS.
2. `BalancerPoolerV2.pool()` / `unlockCallback()` add that sUSDS single-sided into the configured sUSDS/phUSD Balancer pool (`_pool`), with the dispatcher itself as the BPT recipient ([BalancerPoolerV2.sol#L140-L159](https://github.com/Behodler/yield-claim-nft/blob/2805a4d/src/V2/dispatchers/BalancerPoolerV2.sol#L140-L159)).
3. For every dispatched USDS, `BalancerPoolerMintDebtHook.onDispatch()` accrues `ratio%` of the amount as phUSD debt on `mintDebt`.
4. `BalancerPoolerMintDebtHook.pull()` ([BalancerPoolerMintDebtHook.sol#L100-L106](https://github.com/Behodler/yield-claim-nft/blob/2805a4d/src/V2/hooks/BalancerPoolerMintDebtHook.sol#L100-L106)) realises the accumulated ledger by calling `phUSD.mint(recipient, debt)` and zeroing `mintDebt`.

NFT holders are economically long the dispatcher's BPT position in this sUSDS/phUSD pool. Their effective collateral is the pro-rata sUSDS and phUSD that BPT can redeem.

The unmodelled dynamic is that `pull()` does not hand `recipient` an off-pool asset. It hands `recipient` the exact token that forms the other side of the very pool the protocol is LPing into. With that phUSD in hand, `recipient` can execute a one-step reflexive arbitrage directly against the pool:

1. Call `pull()` to mint `mintDebt` worth of phUSD.
2. Call `swap(phUSD -> sUSDS)` on the sUSDS/phUSD pool (or via the Balancer router).
3. Keep the sUSDS.

Every unit of sUSDS that `recipient` extracts this way comes out of the pool's sUSDS reserves, and the dispatcher's BPT — held at `BalancerPoolerV2._pool` — gives up its pro-rata share of that loss. The minted phUSD has no economic backing, but the sUSDS that leaves the pool is real yield-bearing collateral that NFT holders had a claim on through the BPT.

The `ratio` parameter is advertised as a throughput tax measured in phUSD, but because `recipient` can always liquidate the minted phUSD back into the pool that sits behind the NFT claim, `ratio` is implicitly a tax on the BPT-backed NFT position itself. The larger the protocol's share of the sUSDS/phUSD pool (the intended design — the pool is set up for this purpose), the higher the fraction of the extractive swap that is absorbed by the protocol's own BPT rather than by external LPs.

### Impact

NFT-holder claim backing is systematically eroded by mechanism composition, not a bug. Every `pull()` cycle, when followed by a phUSD -> sUSDS swap on the bound pool, transfers real sUSDS from the dispatcher's BPT position to `recipient`, scaled by the protocol's LP share. Because the phUSD `pull()` produces is uncollateralised but the sUSDS coming out is yield-bearing, the round trip is net-extractive for `recipient` and net-lossy for NFT holders. The loss is permanent per cycle and compounds over the audit horizon.

The PoC demonstrates the drain quantitatively. After 1,000 USDS of dispatch throughput and a single `pull()` + swap cycle:

- 300e18 phUSD was minted via `pull()` (hook `ratio = 30%`).
- ~600e18 sUSDS was extracted out of the pool into `recipient`'s balance (the pool was sUSDS-heavy at 1400/400 after single-sided pooling, so swapping 300e18 phUSD in yields `(300 * 1400) / 700 = 600e18` sUSDS under the mock vault's constant-product rule).
- The protocol BPT's pro-rata claim on pool sUSDS reserves strictly decreased — the measured shrinkage (`bptClaimOnSusdsBefore - bptClaimOnSusdsAfter`) was 333e18, i.e. the protocol BPT's share of the extracted sUSDS.

Under realistic Balancer pool mechanics the swap output would be reduced by the pool's swap fee, and slippage would partially be absorbed by external LPs. Neither of those caveats eliminates the drain: they merely bound the per-cycle extraction. As long as the protocol is a non-trivial LP in the bound pool — the stated design — some fraction of every `pull()`'ed phUSD converts into sUSDS that was previously part of the NFT-holder backing.

### Severity justification (Medium)

Assets are not at direct risk via an unambiguous theft primitive: the reflexive swap requires a functioning external sUSDS/phUSD market and is subject to Balancer fees and slippage. The attack is nevertheless a concrete value leak that (a) requires only rational `recipient` behaviour (converting phUSD to the more-liquid sUSDS is the economically obvious action), (b) is guaranteed whenever the protocol is the dominant LP in the bound pool, which is the design assumption, and (c) reduces NFT-holder backing in a way that holders cannot observe ex-ante. That matches the C4 Medium definition: value leak under stated assumptions about realistic external participant behaviour.

## Recommended mitigation steps

Break the reflexive loop between `pull()` and the pool that `BalancerPoolerV2` is LPing into. Options in order of robustness:

1. **Settle debt in sUSDS, not phUSD.** Have `pull()` transfer sUSDS redeemed from a proportional BPT burn to `recipient` instead of minting phUSD. This makes the settlement amount equal to the economic cost and removes the free-phUSD primitive entirely.
2. **Make the minted debt token non-tradable against the backing pool.** Issue debt in a dedicated token (e.g. `debtUSD`) that is not registered in the sUSDS/phUSD pool, and redeem it separately against a protocol-controlled treasury. phUSD specifically must not appear as `pull()`'s output while it is also `_pool`'s token1/token0.
3. **Restrict `recipient` to a non-trading address.** Require `setRecipient` to only accept an address with a declared policy that prevents the phUSD-for-sUSDS swap against `_pool` (e.g. a timelocked escrow, an on-chain policy contract, or a contract whose code path provably does not interact with `_pool`). Enforce the constraint on-chain rather than documentationally.
4. **Enforce a cooldown and on-chain accounting of BPT value.** Gate `pull()` by a per-epoch cap tied to realised non-NFT-backed yield rather than dispatcher throughput, so the `ratio` tax cannot exceed the protocol's externally earned income.
5. **At minimum, document the economic coupling.** If the current design is intentional, state explicitly in the hook's NatSpec and in user-facing documentation that `ratio` is a tax on BPT backing via reflexive arbitrage, not on dispatched USDS throughput. The current NatSpec for `onDispatch` and `pull()` does not mention this coupling, and neither do the contract-level docs; NFT holders cannot be assumed to infer it.

### Proof of Concept

A runnable Foundry PoC is provided at `workspace/yield-claim-nft/test/poc-M-02.t.sol`:

- [`workspace/yield-claim-nft/test/poc-M-02.t.sol`](../../../../workspace/yield-claim-nft/test/poc-M-02.t.sol)

Run from the project root (`workspace/yield-claim-nft`):

```
forge test --match-contract PocM02_ReflexiveDrainTest -vv
```

The test sets up:

- An externally seeded sUSDS/phUSD pool (400e18 / 400e18) so that a swap is executable.
- `BalancerPoolerV2` configured with the `BalancerPoolerMintDebtHook` at `ratio = 30%`.
- 1,000e18 USDS dispatched through the dispatcher, then `pool()` called to single-side sUSDS into the pool.

It then executes the attack:

1. `debtHook.pull()` mints 300e18 phUSD to `recipient` (asserted against `mintDebt`).
2. `recipient` swaps the 300e18 phUSD into the sUSDS/phUSD pool and receives ~600e18 sUSDS (single-sided pooling left the pool sUSDS-heavy at 1400/400, amplifying the payout relative to phUSD in).
3. The protocol BPT's pro-rata claim on pool sUSDS reserves is recomputed; the assertion `bptClaimOnSusdsAfter < bptClaimOnSusdsBefore` passes, and the shrinkage (measured as 333e18, i.e. the dispatcher's BPT share of the 600e18 sUSDS that left the pool) is the NFT-holder backing loss.

The mock vault uses a constant-product rule for the swap so the pool strictly loses sUSDS on every phUSD-in trade; no fee is modelled. A real Balancer V3 stable pool would charge a swap fee and use a different curve, which reduces but does not eliminate the extracted amount — the structural drain is the reflexive mint-then-swap path, not the specific curve.
