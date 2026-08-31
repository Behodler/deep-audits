> **Carryover QA report — audit 05** (cut down from `reports/reflax-yield-vault/05/submissions/qa-report.md`).
> Retained below (still open / untriaged as of audit 17): **L-01, C-01**.
> Removed as no longer live / carried elsewhere: L-02 (ancestor of ledger `L-02` / `81ee07506e426241` — **wont-fix**, human-triaged disposal).
> Labels are the originals — gaps in the sequence are the removals above, not omissions.
> Line numbers were accurate at the originating commit; re-verify against current HEAD (`cdd0743`).
>
> **Ledger mapping** (originating report label → ledger entry):
> - `L-01` → L-01 (ledger `L-01` / `6460e35331dff5c2`)
> - `C-01` → C-01 (ledger `C-01` / `679c917dabcb60af`)

*The text below is a verbatim copy of the retained sections of the original report.*

---

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
