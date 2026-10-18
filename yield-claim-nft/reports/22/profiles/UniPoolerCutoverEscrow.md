# UniPoolerCutoverEscrow — contract profile (run 22, @0fd6bdf, story-052 [review])

`src/migration/UniPoolerCutoverEscrow.sol`, 425 LOC, ^0.8.20, inherits only OZ ReentrancyGuard. New in scope this run.

## Verified local properties
- Every state-changing function (`exitAndSeed`, `wrapUsds`, `abort`) is `onlyOperator` + `nonReentrant`. The operator is immutable and non-zero. There is no owner, no setter, no receive/fallback and no payable function.
- No function takes an address argument. Outflows go only to: the V3 Router (it burns BPT through its exact allowance), the pair (the seed), `newPooler` (LP, skim, sUSDS shares) and `oldPooler` (abort).
- Every approval is exact and is reset to 0 afterwards.
- The one loop is fixed at 2 iterations. No `unchecked` blocks, no assembly, no weak randomness, no ERC721/1155/777 callback surface.
- Storage holds only the ReentrancyGuard slot. Everything else is immutable.
- Only file-local Balancer/pooler interfaces are used (story-050 decoupling holds).
- Fail-safe post-checks:
  - If Router02 seeds a different pair, the `lpReceived` and reserve checks revert.
  - If the pool's tokens are not {sUSDS, phUSD}, the call reverts with `NothingToSeed` or on the length mismatch.
- 37 unit and invariant tests pass in `work/`. The fork tests were not run.

## Local findings
| id | sev | where | summary |
|---|---|---|---|
| LOCAL-001 | local-low | L359-375, L399-400 | 1 wei + `pair.sync()` (or a dust direct `pair.mint`) on the canonical pair permanently blocks `exitAndSeed`. Funds are safe because `abort` works. The escrow has no recovery path: Router02 cannot seed one-sided reserves, and a same-code redeploy fails identically because the pair is fixed as canonical by UniPoolerV2. Recovery needs a different contract (direct transfer + `pair.mint`). Cross-ref phStaging run-39 L-01 and UniPoolerV2 L-24. |
| LOCAL-002 | local-low (footgun) | L199, L217, L295-301, L415-418 | `_bpt` is a snapshot of `oldPooler.pool()`, which the owner can change, while `BalancerPoolerV2.withdrawBPT` pays out the current `_pool`. A `setPool` between escrow deploy and `withdrawBPT` strands the BPT permanently: `exitAndSeed` reverts `NoBPT` and `abort` does not return it. Any token outside the four is likewise locked forever. |
| LOCAL-003 | info | L256-262, L382-384 | `minAmountsOut` is checked only for length 2 and non-zero values (1 wei passes). Its order (Balancer token order: sUSDS first) is not validated. The seed has no price or ratio floor. |

## Story-052 open questions vs code
1. **No on-chain share floor:** confirmed. Only `length==2` and `>0` are checked: `if (minAmountsOut[i] == 0) revert ...ZeroMinAmountOut(i);` (LOCAL-003).
2. **Whole-balance seed:** confirmed. `uint256 s = IERC20(_sUSDS).balanceOf(address(this)); uint256 p = IERC20(_phUSD).balanceOf(address(this));` runs after the exit. Stray balances bypass `minAmountsOut`. The LP is 100% `newPooler`'s, so a donor cannot profit: donating and then arbitraging is net-negative under constant product.
3. **Pair DoS:** confirmed DoS-only for funds. An unsynced donation is handled by `skim(_newPooler)`. A synced donation or dust mint hits `revert UniPoolerCutoverEscrow__PairNotEmpty(...)`, and the contract has no recovery mode (LOCAL-001).
4. **Operator key loss:** confirmed. `address private immutable _operator;` gates `abort` too, and there is no fallback key, so all four balances would be stranded. This is accepted design (Law 3).
5. **No rescue for other tokens:** confirmed. `_returnAll` covers only `_bpt/_sUSDS/_phUSD/_usds`. The new detail is the `setPool` snapshot (LOCAL-002).
6. **Inherited seed price:** confirmed. The seed ratio is the exit proceeds ratio plus any strays, with no oracle or $1 check. Router02 `mins == desired` only forces exact consumption. Deferred to econ-scanner.

## Trust assumptions
- The operator is honest and keeps the key.
- `newPooler` is a UniPoolerV2 whose constructor enforced pair tokens and canonicality.
- `v3Router` is the genuine Balancer V3 Router.
- `oldPooler.pool()` is unchanged through the cutover.
- The four tokens are plain ERC20s.
- story-103's off-chain core computes tight floors over the combined BPT and broadcasts privately.

## Other observations
- `deadline` only reaches Router02. Because the call is atomic, it bounds the V3 exit too.
- `abort` restores the pre-cutover status quo on oldPooler. Returned sUSDS can be re-pooled into Balancer by any authorized pooler, and returned USDS gets re-swept by `_dispatch` donations. All four tokens can be rescued by the owner via `rescueERC20`.
- The factory `feeTo` is live (Q-23). The seed is the first mint (`kLast == 0`), so no fee is taken at seed.
