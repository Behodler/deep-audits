# QA Report — phoenix-vault (reflax-yield-vault)

**Scope:** `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol`, `src/AMMAdapters/CurveAMMAdapter.sol`, `src/AMMAdapters/IAMMAdapter.sol`, `src/AMMAdapters/ICurveRouterNG.sol`
**Commit:** `7d11f66c9ac9b70a947f8a023872e424f4632ab9`

This report bundles all Low-severity and Centralization findings for the engagement. High/Medium findings are submitted separately. An automated SAST/gas baseline (4naly3er) is attached as an appendix.

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 2 |
| Centralization | 1 |
| **Total** | **3** |

| ID | Title |
|----|-------|
| [L-01](#l-01-slippagetolerancebps-is-uninitialized-and-its-setter-has-no-sane-upper-bound) | `slippageToleranceBps` is uninitialized and its setter has no sane upper bound |
| [L-02](#l-02-_skimsurplusbatch-reverts-the-entire-batch-on-a-single-zero-address-entry-and-iterates-an-unbounded-caller-supplied-array) | `_skimSurplusBatch` reverts the entire batch on a single zero-address entry, and iterates an unbounded caller-supplied array |
| [C-01](#c-01-owner-and-authorized-withdrawer-power-bundle) | Owner and authorized-withdrawer power bundle |

---

## Low Risk Findings

### [L-01] `slippageToleranceBps` is uninitialized and its setter has no sane upper bound

**Location:**
- [`ERC4626MarketYieldStrategy.sol#L40`](https://github.com/Behodler/reflax-yield-vault/blob/7d11f66c9ac9b70a947f8a023872e424f4632ab9/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L40) (state variable, no initializer)
- [`ERC4626MarketYieldStrategy.sol#L190-L195`](https://github.com/Behodler/reflax-yield-vault/blob/7d11f66c9ac9b70a947f8a023872e424f4632ab9/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L190-L195) (`setSlippageTolerance`)

**Description:**

This is a missing-validation / uninitialized-state finding with two related parts.

**(a) No initializer / no nonzero default.** `slippageToleranceBps` is declared without an initial value and the constructor never sets it, so it defaults to `0`:

```solidity
uint256 public slippageToleranceBps;
```

Every swap-bearing path computes its floor as `minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS`. With `slippageToleranceBps == 0`, `minOut == idealUnderlying`, i.e. the swap is required to clear at exactly the NAV-derived ideal with zero tolerance. Under any non-zero pool spread or fee this floor is unattainable and the swap reverts. The strategy is therefore non-functional for deposits/withdrawals/skims until an owner calls `setSlippageTolerance`. There is nothing in the contract that signals this precondition.

**(b) Setter has no sane upper bound.** `setSlippageTolerance` only checks the value against the absolute maximum:

```solidity
function setSlippageTolerance(uint256 _bps) external onlyOwner {
    require(_bps <= MAX_BPS, "ERC4626MarketYieldStrategy: slippage tolerance exceeds MAX_BPS");
    ...
}
```

`MAX_BPS == 10000` (100%). The only guard accepts the entire `[0, 10000]` range, including values that make `minOut` collapse toward `0` and effectively disable slippage protection. This is reported strictly as a missing-validation defect: the contract lacks a tighter, protocol-appropriate ceiling and a nonzero floor. It is **not** a claim that an owner would maliciously set 100% (that would be an excluded reckless-admin scenario).

**Impact:** Availability-until-configured (the strategy reverts all swaps on a fresh deploy until the owner configures a tolerance), plus an overly permissive parameter band that removes the safety value the parameter is meant to provide. No funds are directly at risk.

**Recommendation:**
- Initialize `slippageToleranceBps` to a conservative non-zero default in the constructor (e.g. `50` = 0.5%), or require it as a constructor argument so the contract is never deployed in an unusable state.
- Constrain the setter with a meaningful upper bound rather than `MAX_BPS`, and reject `0`:

```solidity
uint256 public constant MAX_SLIPPAGE_BPS = 500; // 5%, choose per protocol policy

function setSlippageTolerance(uint256 _bps) external onlyOwner {
    require(_bps > 0 && _bps <= MAX_SLIPPAGE_BPS, "slippage out of allowed range");
    uint256 oldBps = slippageToleranceBps;
    slippageToleranceBps = _bps;
    emit SlippageToleranceSet(oldBps, _bps);
}
```

---

### [L-02] `_skimSurplusBatch` reverts the entire batch on a single zero-address entry, and iterates an unbounded caller-supplied array

**Location:** [`ERC4626MarketYieldStrategy.sol#L468-L470`](https://github.com/Behodler/reflax-yield-vault/blob/7d11f66c9ac9b70a947f8a023872e424f4632ab9/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L468-L470) (loop body); see also [`#L462-L488`](https://github.com/Behodler/reflax-yield-vault/blob/7d11f66c9ac9b70a947f8a023872e424f4632ab9/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L462-L488) for context.

**Description:**

`_skimSurplusBatch` iterates a caller-supplied `clients[]` array and uses a hard `require` to reject a zero address inside the loop:

```solidity
for (uint256 i = 0; i < clients.length; i++) {
    address client = clients[i];
    require(client != address(0), "ERC4626MarketYieldStrategy: client cannot be zero address");
    uint256 principal = clientBalances[token][client];
    if (principal == 0) continue;
    ...
    uint256 surplus = total > principal ? total - principal : 0;
    if (surplus == 0) continue;
    ...
}
```

This is inconsistent with how the same loop handles other "nothing to do" entries: a client with `principal == 0` or `surplus == 0` is skipped gracefully via `continue`, whereas a single `address(0)` entry reverts the **entire** batch. A caller assembling a large list (or merging lists from multiple sources) that contains one stray zero address loses the whole call's work and must rebuild and resubmit.

Separately, `clients[]` is unbounded and caller-supplied, and the loop performs an external `vault.convertToShares()` call per non-trivial entry, so gas scales linearly with the array length. There is no length cap.

Both effects are self-inflicted by a trusted caller (the function is gated by the authorized-withdrawer role); there is no third-party harm and no asset loss, hence Low. The issue is the inconsistent failure mode and the lack of a defensive bound, not a security boundary break.

**Recommendation:**
- Make the zero-address case consistent with the other skip conditions by replacing the in-loop `require` with a `continue`, so a single bad entry no longer aborts the batch:

```solidity
for (uint256 i = 0; i < clients.length; i++) {
    address client = clients[i];
    if (client == address(0)) continue;
    ...
}
```

- Consider enforcing a maximum `clients.length` (or documenting a safe batch-size ceiling) to bound gas and avoid an out-of-gas batch.

---

## Centralization Risks

### [C-01] Owner and authorized-withdrawer power bundle

**Location:** Multiple (acknowledged design):
- [`setRoute` (CurveAMMAdapter.sol#L68)](https://github.com/Behodler/reflax-yield-vault/blob/7d11f66c9ac9b70a947f8a023872e424f4632ab9/src/AMMAdapters/CurveAMMAdapter.sol#L68)
- [`setSlippageTolerance` (ERC4626MarketYieldStrategy.sol#L190)](https://github.com/Behodler/reflax-yield-vault/blob/7d11f66c9ac9b70a947f8a023872e424f4632ab9/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L190)
- `depositAsOwner` / `withdrawAsOwner` (`ERC4626MarketYieldStrategy.sol#L242`, `#L254`)
- `emergencyWithdraw` and the two-phase total-withdrawal timelock (inherited from `AYieldStrategy`)
- Surplus-skim recipient selection in [`_skimSurplusBatch` (ERC4626MarketYieldStrategy.sol#L462-L488)](https://github.com/Behodler/reflax-yield-vault/blob/7d11f66c9ac9b70a947f8a023872e424f4632ab9/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L462-L488)

**Description:**

The strategy concentrates several privileged powers in the owner and the authorized-withdrawer roles:

- **Routing:** the owner sets AMM routes via `setRoute`, fully determining the pool/path every swap clears through.
- **Slippage:** the owner sets `slippageToleranceBps` (see L-01), controlling the protective floor on all swaps.
- **Owner deposit/withdraw:** `depositAsOwner` / `withdrawAsOwner` let the owner move positions on behalf of the strategy.
- **Emergency exit:** an `emergencyWithdraw` path and a two-phase total-withdrawal flow (24h wait / 48h execute) inherited from `AYieldStrategy`.
- **Skim recipient:** the caller of the surplus skim chooses the `recipient` that receives skimmed surplus.

**Scope of the withdrawer power (verified):** the authorized withdrawer can redirect **yield/surplus only** — it can never redirect or extract client **principal**. This was confirmed: `clientBalances` (per-client principal) is intentionally untouched by the skim path, and the principal-protection invariant holds across the withdraw/skim flows. The two-phase total-withdrawal timelock is sound and is not bypassable by the emergency path.

This is acknowledged, authorized design per the project's system assumptions (the owner is expected to be a trusted multisig acting in the protocol's and clients' interest) and the documented two-phase emergency-withdrawal design. It is reported here as a centralization note for completeness rather than as an exploitable defect; an owner-key compromise would widen routing/slippage/emergency control, but principal redirection remains outside these powers.

**Recommendation:**
- Hold the owner role in a multisig (and consider a timelock on `setRoute` / `setSlippageTolerance`) so route and slippage changes are observable before they take effect.
- Emit events (with old/new values) on every privileged parameter change to support off-chain monitoring — `setSlippageTolerance` already does; ensure `setRoute` and the owner deposit/withdraw paths are equally observable.
- Document the trust model (owner = trusted multisig; withdrawer = yield-only) prominently for clients so the boundary between redirectable yield and protected principal is explicit.

---

## Appendix — Automated analysis (4naly3er)

The automated C4-style SAST/gas report below was produced by **4naly3er** over the four in-scope files at commit `7d11f66c9ac9b70a947f8a023872e424f4632ab9`. It is included as the standard bot-report baseline. Items here are largely gas/best-practice and informational; where they overlap the manual findings above (notably the in-loop zero-address `require` and the missing nonzero-value / parameter validation around the slippage setter), the manual findings are authoritative. The full markdown is in [`4naly3er-report.md`](./4naly3er-report.md). Summary of categories surfaced:

- **Gas Optimizations:** 15 categories (e.g. cache array length outside loop, custom errors vs revert strings, `unchecked` for-loop increments, `!= 0` vs `> 0`).
- **Non-Critical:** 17 categories (e.g. magic numbers vs constants, events missing indexed fields / old+new values, consider disabling `renounceOwnership()`, style-guide ordering).
- **Low:** 8 categories (e.g. use a 2-step ownership transfer / `Ownable2Step`, division-by-zero not prevented, possible rounding / loss of precision, `PUSH0` on non-mainnet chains under 0.8.20+).
- **Medium:** present (automated heuristics; superseded by the separately-submitted manual H/M findings).

See the full attached report for per-instance line references and code links.
