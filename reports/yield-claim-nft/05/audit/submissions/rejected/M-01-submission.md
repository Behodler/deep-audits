<!--
C4 Submission Metadata
Title: [M-01] Dust-sized mints bypass phUSD mint-debt tax via integer rounding in `onDispatch`
Root Cause Link: https://github.com/Behodler/yield-claim-nft/blob/2805a4d/src/V2/hooks/BalancerPoolerMintDebtHook.sol#L89-L95
PoC File: workspace/yield-claim-nft/test/poc-M-01.t.sol
-->

## Finding description and impact

### Summary

`BalancerPoolerMintDebtHook.onDispatch` computes the phUSD mint-debt as `added = (amount * ratio) / 100` and silently early-returns when `added == 0`. Because Solidity integer division truncates, any `amount` strictly less than `ceil(100 / ratio)` accrues zero debt. At the deployed default `ratio = 30`, amounts `1`, `2`, and `3` all produce `added == 0` and are therefore dispatched without incurring the documented tax. A minter can split a larger dispatch into dust-sized sub-dispatches and bypass the `ratio%` mint-debt entirely, while the sUSDS/BPT backing still accrues to the pool.

### Vulnerability details

The vulnerable code at [`BalancerPoolerMintDebtHook.sol#L89-L95`](https://github.com/Behodler/yield-claim-nft/blob/2805a4d/src/V2/hooks/BalancerPoolerMintDebtHook.sol#L89-L95):

```solidity
function onDispatch(address minter, uint256 amount, bytes calldata) external {
    if (msg.sender != dispatcher) revert OnlyDispatcher();
    uint256 added = (amount * ratio) / 100;
    if (added == 0) return;
    mintDebt += added;
    emit DebtAccrued(minter, amount, added, mintDebt);
}
```

The hook's NatSpec states that *"the debt equals `ratio`% of the USDS `amount`"*. The implementation does not honour that contract. Two properties of the expression `(amount * ratio) / 100` break the invariant:

1. **Rounding floor.** For any `ratio R in [1, 99]`, every `amount < ceil(100 / R)` produces `added == 0`. At `R = 30` the floor is `4`, so amounts `1..3` are untaxed. At `R = 1` the floor is `100`, widening the attack surface further should the owner ever lower the ratio.
2. **Silent no-op.** When `added == 0` the function returns without emitting any event. There is no `DebtSkipped` counterpart to `DebtAccrued`, so the bypass leaves no on-chain trace for off-chain monitoring.

A minter can therefore split an aggregate notional `A` into `A / 3` dispatches of 3 wei USDS each, route each through `NFTMinterV2` → `BalancerPoolerV2` → `onDispatch`, and pay **zero** phUSD debt on the full notional. The sUSDS conversion and subsequent BPT pooling inside the dispatcher proceed normally — the backing grows, but the tax ledger does not.

More generally, the protocol's *effective* tax rate is `floor(amount * ratio / 100) / amount`, which is strictly less than `ratio / 100` for any `amount * ratio` not divisible by `100`, and collapses to `0%` at the dust boundary. This is a persistent asymmetry, not a one-off rounding artefact.

### Impact

The phUSD debt beneficiary (recipient) is systematically under-paid whenever dispatches land at or below the rounding floor. Over many dust-split mints, the protocol's effective ratio drifts below the configured `ratio`. NFT-holders accrue sUSDS/BPT backing faster than the advertised tax would imply, which means:

- the hook does not implement the tax documented in its own NatSpec;
- the protocol's debt ledger underreports owed phUSD;
- the attacker/minter obtains backing exposure without paying the intended tax.

This is a value leak with a clear attack path but requires the attacker to tolerate paying gas for many small mints, which is why Medium (not High) is appropriate under C4's criteria: *"assets not at direct risk, but protocol function … impacted, or value leak with stated assumptions and external requirements"*. The stated assumption is that a minter is willing to amortise gas across dust-sized calls; the external requirement is the default `ratio = 30` configuration shipped by the constructor. Both are trivially satisfied.

## Recommended mitigation steps

Any of the following, ordered by preference, closes the rounding-floor bypass:

1. **Require a non-zero accrual for every non-zero dispatch.** Replace the silent early-return with a revert whenever the amount is non-trivial but the computed debt rounds to zero:

   ```solidity
   uint256 added = (amount * ratio) / 100;
   if (added == 0) {
       if (amount == 0 || ratio == 0) return; // genuinely zero cases
       revert AmountBelowTaxFloor();
   }
   mintDebt += added;
   emit DebtAccrued(minter, amount, added, mintDebt);
   ```

   This makes the tax total: the hook either taxes or reverts, never silently passes.

2. **Round up instead of down.** Guarantees at least 1 wei of debt on every non-zero dispatch:

   ```solidity
   uint256 added = (amount * ratio + 99) / 100;
   ```

3. **Use basis points for the ratio.** Replacing the `uint8 ratio` / `/100` pair with a `uint16 ratioBps` / `/10_000` pair shrinks the rounding window by two orders of magnitude and aligns with the convention already used elsewhere in the V2 codebase (`growthBasisPoints`). Combine with option (2) for full coverage.

4. **At minimum, remove the silent event suppression.** If under-floor dispatches must be permitted (e.g. for gas tests), emit a `DebtSkipped(minter, amount)` event so the ledger reveals the gap and off-chain indexers can flag the asymmetry. This does not fix the leak but makes it observable.

Options (1) and (3) together give the most defensible design: basis-point precision plus a revert on sub-floor dispatches.

### Proof of Concept

The PoC is provided at `workspace/yield-claim-nft/test/poc-M-01.t.sol` and runs against the in-repo Foundry suite:

```bash
cd workspace/yield-claim-nft
forge test --match-contract M01PoCTest -vv
```

The test contract contains three scenarios. Each asserts a specific property of the rounding bypass:

- **`test_M01_dustDispatchAccruesZeroDebt`** — dispatches `amount ∈ {1, 2, 3}` through the hook at the default `ratio = 30`, asserts `mintDebt` does not change, and asserts `vm.getRecordedLogs().length == 0` to prove the bypass is silent. The key assertion is `assertEq(hook.mintDebt(), 0, "mintDebt remains zero after dust dispatches")` at line 93.
- **`test_M01_dustSplitBypassesTaxVersusSingleDispatch`** — performs `10_000` dispatches of 3 wei each (`30_000` wei aggregate) on one hook instance and a single `30_000` wei dispatch on a second hook instance. The dust-split hook's `mintDebt` is `0`; the single-dispatch hook's `mintDebt` is `9_000` (30% of 30_000). Asserted at lines 131-136 via `assertEq(honestDebt - dustDebt, 9_000, "full 9_000 wei of tax is bypassed")`. The test also calls `hook.pull()` and confirms `phUSD.balanceOf(recipient) == 0` on the dust path, demonstrating the downstream impact on the debt beneficiary.
- **`test_M01_roundingBoundaryIsSharp`** — proves the cliff is one wei wide: `amount = 3` accrues 0 debt, `amount = 4` accrues 1 wei (line 160). A subsequent `1_000`-iteration loop of `amount = 3` dispatches leaves `mintDebt` unchanged, showing the bypass is unbounded in iteration count.
- **`test_M01_bypassGeneralisesAcrossRatios`** — reconfigures `ratio` to `1` and `49` via `setRatio` and confirms the rounding floor matches `ceil(100 / R)` at both extremes. This rules out "default-ratio-specific quirk" as an explanation.

All assertions pass against the current `BalancerPoolerMintDebtHook` source, confirming that the rounding-floor bypass is reachable and exploitable as described.
