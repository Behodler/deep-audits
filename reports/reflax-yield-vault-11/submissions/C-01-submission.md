<!--
ID: ryv11c1
C4 Submission Metadata
Title: [C-01] Owner-key centralization surface: emergency-withdraw accounting desync, timelock bypass, and a MAX_BPS slippage config trap
Root Cause Link: https://github.com/Behodler/reflax-yield-vault/blob/master/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L386-L395
PoC File: (none — centralization writeup, no exploit path)
-->

## Finding description and impact

### Trust model

`reflax-yield-vault` is a **self-owned, all-protocol-owned-client** system. The `owner` is the protocol itself, and every authorized client is a protocol-controlled account. Within this model, "the owner can move client funds to the owner" is the designed fund-migration behaviour, not an attack. The three items below are therefore **centralization characteristics** — concentrations of trust in the owner key — rather than exploitable High/Medium vulnerabilities. They are reported so the protocol can decide which to harden and which to accept, and so the custody requirements on the owner key are made explicit.

Two other items reviewed in this run are **not** centralization issues and are not discussed here: `H-02` is inert (its only real residual is the event-amount mismatch already tracked as `L-06`), and `M-02` is a false-positive donation-DoS. See `submissions/rejected/REJECTION-RATIONALE.md` for the full disposition.

The three sub-sections below are ordered by how actionable they are: C-01.1 is a latent footgun worth fixing even under a fully trusted owner; C-01.2 is the explicit owner-key trust surface; C-01.3 is an owner misconfiguration trap.

---

### C-01.1 — `_emergencyWithdraw` silently desyncs accounting

**What.** `_emergencyWithdraw` transfers vault shares to `owner()` but never decrements `clientBalances` or `totalDeposited`. The accounting maps continue to report the full pre-emergency principal even though the strategy no longer holds the corresponding shares.

**Where.** `ERC4626MarketYieldStrategy._emergencyWithdraw` ([L386-L395](https://github.com/Behodler/reflax-yield-vault/blob/master/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L386-L395)):

```solidity
function _emergencyWithdraw(uint256 amount) internal override {
    uint256 totalShares = vault.balanceOf(address(this));
    require(totalShares > 0, "ERC4626MarketYieldStrategy: no shares to withdraw");

    uint256 sharesToTransfer = amount < totalShares ? amount : totalShares;

    // Transfer vault tokens (shares) directly to owner
    IERC20(address(vault)).safeTransfer(owner(), sharesToTransfer);
}
```

The downstream surfaces are `_withdrawInternal` (share quantity is clamped to the live `vault.balanceOf`) and `_skimSurplus` (per-client surplus is derived from `vault.convertToAssets(vault.balanceOf(address(this)))`).

**Impact.** This is the one item that is a genuine footgun even with a fully trusted, good-faith owner. The danger is the **partial** path: if the owner performs a partial emergency withdraw (`amount < totalShares`) and the strategy keeps operating, the books are now overstated. Subsequent client withdrawals are under-collateralized against the recorded principal, and `skimSurplus` silently no-ops whenever live `totalValue < totalDeposited`, returning zero with no revert to signal the broken state. A full-drain followed by redeployment is recoverable operationally; a partial drain followed by continued operation quietly corrupts accounting.

**Recommendation.** In `_emergencyWithdraw`, decrement `totalDeposited` (and the corresponding `clientBalances`) by the value withdrawn — zeroing both on a full drain — so the books always track the shares actually held. Alternatively, restrict `emergencyWithdraw` to a terminal/paused state so the strategy cannot continue operating against corrupted accounting after a partial exit.

**Disposition:** OPEN hardening recommendation (worth actively fixing).

---

### C-01.2 — `withdrawAsOwner` bypasses the 24h anti-rugpull timelock

**What.** `withdrawAsOwner` routes straight to `_withdrawInternal` with only `onlyOwner` and `nonReentrant` guards — no Phase-1 announcement, no 24h waiting period, and no `whenNotPaused`. The two-phase `totalWithdrawal` mechanism is documented as the anti-rugpull control, but `withdrawAsOwner` (and `emergencyWithdraw`) sidestep it entirely.

**Where.** `ERC4626MarketYieldStrategy.withdrawAsOwner` ([L279-L281](https://github.com/Behodler/reflax-yield-vault/blob/master/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L279-L281)):

```solidity
function withdrawAsOwner(address client, address recipient, uint256 amount) external onlyOwner nonReentrant {
    _withdrawInternal(address(underlyingToken), amount, recipient, client);
}
```

The two-phase path it bypasses is `AYieldStrategy.totalWithdrawal`, whose NatSpec ([AYieldStrategy.sol#L317](https://github.com/Behodler/reflax-yield-vault/blob/master/src/AYieldStrategy.sol#L317)) states it *"Provides community protection against rugpulls while allowing legitimate fund migrations,"* enforced via `WAITING_PERIOD = 24 hours` ([AYieldStrategy.sol#L61](https://github.com/Behodler/reflax-yield-vault/blob/master/src/AYieldStrategy.sol#L61)).

**Impact.** This is the owner-key trust surface. Because two owner-only escape hatches (`withdrawAsOwner` immediately, `emergencyWithdraw` immediately) reach the same client principal without the waiting period, the 24h timelock is only a meaningful guarantee if the owner *voluntarily* uses the two-phase path. In the protocol-owned trust model this is acceptable by design, but a compromised owner key carries the same authority with no advance on-chain notice. The high-visibility `WithdrawalExecuted` event also never fires on this path, so off-chain monitors keyed to the two-phase signal see nothing.

**Recommendation.** Make the guarantee explicit one way or the other. Either document clearly that the 24h timelock is **advisory** — a convenience for signalling good-faith migrations, not a hard guarantee against the owner key — or, if it is meant to be a hard guarantee, route **all** owner-initiated principal withdrawals (`withdrawAsOwner`, and the principal-bearing portion of `emergencyWithdraw`) through the two-phase `totalWithdrawal` machinery so no immediate-drain path to client principal exists.

**Disposition:** ACKNOWLEDGED by-design (owner-key trust surface; document or harden).

---

### C-01.3 — `setSlippageTolerance` accepts `MAX_BPS`, zeroing all principal credits

**What.** The slippage-tolerance setter validates `_bps <= MAX_BPS`, permitting `_bps == 10000`. At that value `_creditedPrincipal` returns 0 for every deposit, so depositors' tokens are consumed while zero principal is credited.

**Where.** `setSlippageTolerance` ([L194-L199](https://github.com/Behodler/reflax-yield-vault/blob/master/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L194-L199)):

```solidity
function setSlippageTolerance(uint256 _bps) external onlyOwner {
    require(_bps <= MAX_BPS, "ERC4626MarketYieldStrategy: slippage tolerance exceeds MAX_BPS");
    ...
}
```

with `MAX_BPS = 10000` (L43) and the credit formula `amount * (MAX_BPS - slippageToleranceBps) / MAX_BPS` ([L213](https://github.com/Behodler/reflax-yield-vault/blob/master/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L213)). At `_bps == MAX_BPS` the numerator factor `(MAX_BPS - slippageToleranceBps)` is zero, so every credited principal is zero.

**Impact.** An owner misconfiguration trap, not an attack. Setting tolerance to the boundary value (or any value near it) silently turns deposits into donations: tokens are transferred in and swapped, but the depositor is credited zero principal and cannot recover their funds via a normal withdrawal. The guard's `<=` makes the most damaging value reachable, and there is no sane upper cap below the boundary to catch a fat-finger.

**Recommendation.** Change the guard to `_bps < MAX_BPS` and add a sane upper cap well below the boundary (e.g. `require(_bps <= 500)`, i.e. 5%) so a single misconfiguration cannot zero out principal credits.

**Disposition:** owner config trap (low-cost guard hardening recommended).
