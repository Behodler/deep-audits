<!--
C4 Submission Metadata
Title: [M-01] `_skimSurplusBatch` over-skims surplus when `clients[]` contains duplicates, under-backing client principal
Severity: Medium
Root Cause Link: https://github.com/Behodler/reflax-yield-vault/blob/master/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L462-L488
PoC File: workspace/phoenix-vault/test/poc-M01-overskim.t.sol
-->

# [M-01] `_skimSurplusBatch` over-skims surplus when `clients[]` contains duplicates, under-backing client principal

**Severity:** Medium

**Lines of code:**
[`src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L462-L488`](https://github.com/Behodler/reflax-yield-vault/blob/master/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L462-L488) (accumulation loop `L468-L478`, share ceiling `L481`)

## Finding description and impact

### Summary

`_skimSurplusBatch` skims the surplus (yield) of every client in a caller-supplied `clients[]` array in a single aggregate swap. The loop does not deduplicate the array. A client address that appears `k` times has its surplus shares added to the swap total `k` times, while the only ceiling ever applied is the strategy's *total held shares* — not the true aggregate surplus. The aggregate swap therefore sells shares that back *other* clients' principal. Because principal accounting (`clientBalances` / `totalDeposited`) is intentionally left untouched, the resulting shortfall is silent and only surfaces later, when an affected client withdraws and receives less than their recorded principal.

### Vulnerability details

The batch loop sums per-client surplus shares once per array occurrence and caps the total only against the contract's entire vault-share balance:

```solidity
for (uint256 i = 0; i < clients.length; i++) {
    address client = clients[i];
    require(client != address(0), "...");
    uint256 principal = clientBalances[token][client];
    if (principal == 0) continue;
    uint256 total = (totalValue * principal) / td; // == totalBalanceOf(client)
    uint256 surplus = total > principal ? total - principal : 0;
    if (surplus == 0) continue;
    totalShares += vault.convertToShares(surplus); // added once PER OCCURRENCE
    emit SurplusSkimmed(token, client, msg.sender, surplus, recipient);
}
if (totalShares == 0) return;
uint256 availableShares = vault.balanceOf(address(this));
if (totalShares > availableShares) totalShares = availableShares; // L481: only ceiling
```

The intended invariant is that the strategy never sells more shares than the aggregate surplus across distinct clients, so that the shares backing each client's principal remain in the vault. The duplicate handling breaks this:

- A client listed twice contributes `2 × convertToShares(surplus)` to `totalShares`.
- The `L481` ceiling (`availableShares`) is the strategy's entire held balance, which backs `principal + surplus` for all clients. With realistic surplus far smaller than principal, `2 × surplusShares` is still well below `availableShares`, so the ceiling does not bite.
- `convertToAssets(totalShares)` worth of underlying is then sold and transferred to the recipient — pulling value out of the share pool that backs principal.

Principal accounting is deliberately not adjusted for surplus skims (the `// Principal tracking intentionally untouched` comment at `L487`), so `totalBalanceOf`/withdrawal math continues to assume the principal is still fully backed. The deficit is invisible in the ledger and only manifests as an under-delivered withdrawal for whichever client exits into the now-undercollateralized pool.

### Trigger and likelihood

`skimSurplusBatch` is gated by `onlyAuthorizedWithdrawer`, a trusted role, so this is not an external-attacker exploit and is correctly below the C4 High bar. The realistic trigger is operational, not malicious: these batch arrays are assembled off-chain (e.g. a keeper script enumerating clients to skim). A duplicate entry — from a script bug, a re-run that appends instead of replaces, an overlapping page in a paginated client list, or a config that lists the same client under two labels — silently over-skims and bleeds third-party clients' backing. There is no on-chain guard that rejects or collapses the duplicate, and no revert at skim time signals that anything went wrong.

### Impact

The strategy becomes under-collateralized against recorded principal. Clients who deposited in good faith can no longer withdraw their full principal; the over-skimmed value has already been transferred to the skim recipient. The loss is borne by clients other than (or in addition to) the duplicated one, and it surfaces with no error at the time of the operator action, making it hard to detect or attribute. This is a value-leak / loss-of-funds impact contingent on a trusted-role operational mistake with no external requirement beyond the duplicate itself — Medium per the C4 framework.

## Proof of Concept

A runnable, deterministic Foundry PoC is provided at `workspace/phoenix-vault/test/poc-M01-overskim.t.sol`. It imports the real in-scope `ERC4626MarketYieldStrategy` (verified byte-identical to the read-only `lib/reflax-yield-vault` copy) and uses faithful ERC4626 / AMM mocks. Critically, the AMM adapter's execution price is synced to fair vault NAV before each swap, so all slippage/sandwich economics are removed and the over-skim is isolated as a pure accounting defect.

Run:

```bash
cd workspace/phoenix-vault
forge test --match-contract M01PoCTest -vv
```

Scenario (`test_M01_duplicateClientsOverSkim`): clients A and B each deposit 100,000 USDe (`totalDeposited = 200,000`). The vault then accrues +20% NAV yield, giving each client 20,000 of surplus — a **true aggregate surplus of 40,000**. An operator calls `skimSurplusBatch(underlying, [A, A, B, B], recipient)`.

The key assertions and the values they hold at:

```solidity
// 1. The duplicated [A,A,B,B] list skims ~2x the true aggregate surplus.
assertGt(skimmed, trueAggregateSurplus, "duplicate list over-skims beyond true surplus");
assertApproxEqRel(skimmed, 2 * trueAggregateSurplus, 0.01e18, "over-skim ~= 2x true surplus");

// 2. Principal accounting is untouched (loss is silent).
assertEq(strategy.getTotalDeposited(address(underlying)), 200_000 ether, "principal unchanged by skim (INV-1)");

// 3. Held-share value has fallen BELOW recorded principal.
assertLt(heldValueAfter, strategy.getTotalDeposited(address(underlying)),
    "M-01 CONFIRMED: held-share value < principal after duplicate skim");

// 4. Downstream harm: client B can no longer recover full principal.
assertLt(bClaim, 100_000 ether, "client B under-collateralized below principal");
```

Demonstrated numbers:

- True aggregate surplus: **40,000 USDe**.
- Value actually skimmed: **~79,999.99 USDe ≈ 2×** the true surplus.
- `totalDeposited`: unchanged at **200,000** (the loss is invisible in principal accounting).
- Held-share backing: **240,000 → 160,000 USDe** — below the 200,000 recorded principal.
- Client B's recoverable claim: **80,000 USDe**, i.e. **20,000 below** B's 100,000 principal.

The under-delivery is demonstrated as an arithmetic shortfall (held backing < principal; B's claim < B's principal), not merely a revert — assertion 4 is the concrete loss.

Control (`test_M01_uniqueListIsSafe_control`): the identical deposit/yield with a deduplicated `[A, B]` list leaves principal fully backed and both clients fully recoverable, isolating the duplication as the sole root cause.

This is corroborated independently by:

- **Halmos** (`AccountingSymbolic.t.sol`): `check_skim_no_overskim_duplicates` is *refuted* with an exact 2× counterexample for `[A,A]` and `[A,A,B,B]`, while the deduplicated `[A,B]` control (`check_skim_dedup_exact`) is *proven* safe over all paths.
- **Foundry + Medusa invariants**: the `shareBackingCoversPrincipal` / `skimCannotUnderbackPrincipal` invariant breaks under duplicate batches; a 50,000-run fuzz of `testFuzz_overskim_duplicate` shows the over-skim is universal.

## Recommended mitigation steps

Replace the total-held-shares ceiling at `L481` with a ceiling derived from the strategy's true aggregate surplus, and **revert** (rather than silently clamp) when the requested skim exceeds it. This is O(1) — independent of `clients.length` — and structurally guarantees the strategy can never sell shares that back principal, regardless of array contents:

```solidity
// replaces L481: `if (totalShares > availableShares) totalShares = availableShares;`
uint256 aggregateSurplus = totalValue > td ? totalValue - td : 0;
uint256 maxSurplusShares = vault.convertToShares(aggregateSurplus);
require(totalShares <= maxSurplusShares, "ERC4626MarketYieldStrategy: skim exceeds aggregate surplus");
```

**Revert, not clamp.** The `clients[]` array originates off-chain (a front-end / keeper that enumerates clients), so a duplicate is an upstream defect that should be surfaced, not absorbed. Silently clamping a duplicate-inflated `totalShares` down to the ceiling would let the call succeed while the loop still emits one `SurplusSkimmed` event per array occurrence — so the per-client event trail over-reports and no longer reconciles against the aggregate actually swapped, an opaque and hard-to-audit result. Reverting fails loudly and forces the off-chain caller to correct the malformed array before any value moves.

This introduces no false reverts for well-formed input. Per-client surplus is floored before summation (`Σ floor(convertToShares(surplusᵢ)) ≤ floor(convertToShares(Σ surplusᵢ))`) and any `clients[]` array is a subset of all clients (`Σ surplusᵢ ≤ totalValue − totalDeposited`), so any array of *distinct* clients satisfies `totalShares ≤ maxSurplusShares` and passes. A duplicate that pushes the summed shares past the aggregate surplus — exactly the PoC's `[A, A, B, B]` case — trips the `require`. The replaced `availableShares` clamp is no longer needed: `maxSurplusShares = convertToShares(totalValue − td) < balanceOf(this)`, so the swap allowance remains within the held balance.

**Completeness note.** Because the ceiling uses the *global* aggregate surplus, it guarantees principal can never be under-backed for any array and rejects every duplicate case that would cause a loss. A duplicate confined to a strict subset of clients, whose over-skim is fully absorbed by excluded clients' surplus, would not trip the `require` — but neither can it under-back principal, so no loss occurs. If rejecting *every* duplicate unconditionally (independent of impact) is desired, supplement with an O(n) seen-address set (a `mapping` / transient set) — not an O(n²) pairwise scan.
