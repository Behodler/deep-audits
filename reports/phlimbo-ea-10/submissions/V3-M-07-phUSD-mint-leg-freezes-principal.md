<!--
ID: pe10m7
C4 Submission Metadata
Title: [M-07] phUSD mint leg in _claimRewards is un-wrapped, freezing all stakers' principal on a phUSD mint-authorization revocation (incomplete fix of V3-M-05)
Root Cause Link: https://github.com/Behodler/phlimbo-ea/blob/e32588d/src/PhlimboV3.sol#L863
PoC File: PoC_V3L14_phUSDMintFreeze.t.sol
incompleteFixOf: V3-M-05 (fix-pending)
Severity: Medium (DISPUTED — under human triage; see caveat)
Commit: e32588d
-->

## Finding description and impact

### Summary

`PhlimboV3._claimRewards` mints the beneficiary's pending phUSD reward with a bare, inline call:

```solidity
// src/PhlimboV3.sol:862-864  (_claimRewards)
uint256 pendingPhUSDAmount = ...;
if (pendingPhUSDAmount > 0) {
    phUSD.mint(beneficiary, pendingPhUSDAmount);   // <-- BARE, UNWRAPPED
}
```

`_claimRewards` sits on the critical path of `stake` (`:667`), `withdraw` (`:708`) and `claim` (`:765`). If PhlimboV3 loses its phUSD mint authorization, this call reverts and the revert propagates out through every one of those entry points, freezing the principal of **every** staker that has a non-zero pending phUSD accrual — until authorization is restored.

### Vulnerability details

Story-029 (the fix for the parent finding **V3-M-05**) hardened the two sibling reward legs of `_claimRewards` with a non-reverting `_tryTransfer`+bank pattern, so a reverting reward token defers the reward into a bank instead of bricking the principal path:

- Stable leg — [`PhlimboV3.sol#L875`](https://github.com/Behodler/phlimbo-ea/blob/e32588d/src/PhlimboV3.sol#L875): `if (!_tryTransfer(rewardToken, ...)) { /* bank */ }`
- Promo leg — [`PhlimboV3.sol#L899`](https://github.com/Behodler/phlimbo-ea/blob/e32588d/src/PhlimboV3.sol#L899): `if (_tryTransfer(promoToken, ...)) { ... } else { /* bank */ }`

The **phUSD mint leg** at [`PhlimboV3.sol#L863`](https://github.com/Behodler/phlimbo-ea/blob/e32588d/src/PhlimboV3.sol#L863) was **left un-wrapped**. This is the residual of V3-M-05: the fix banked the two transfer legs but did not bank the mint leg, so the same class of "a reverting reward operation bricks the principal path" survives on the phUSD leg.

`IFlax.mint` reverts the moment PhlimboV3 is no longer a live authorized minter on the phUSD token — i.e. when `canMint == false` or the stored `mintVersion` no longer matches the token's current version. The phUSD token exposes exactly two mechanisms that produce this state:

1. `phUSD.setMinter(PhlimboV3, false)` — directly de-authorizes PhlimboV3, and
2. `phUSD.revokeAllMintPrivileges()` — a global kill-switch that bumps the token-wide `mintVersion`, silently de-authorizing every previously-granted minter at once.

Either action is a plausible, non-obvious operational hazard: `revokeAllMintPrivileges()` is precisely the kind of switch an operator pulls to contain an **unrelated** minter incident on the shared ecosystem token. The operator's intent is to stop a leak elsewhere; the surprising, non-obvious side effect is that it simultaneously freezes the principal of every PhlimboV3 staker. That surprise is what makes this a reportable Law-3 footgun rather than a trusted-owner non-issue.

Attack / failure path:

1. Owner/operator calls `phUSD.revokeAllMintPrivileges()` or `phUSD.setMinter(PhlimboV3, false)` — typically to contain an unrelated minter incident on the shared token.
2. `_claimRewards:863` `phUSD.mint(beneficiary, ...)` reverts because PhlimboV3 is no longer a live authorized minter (unlike the banked stable `:875` and promo `:899` legs).
3. Every staker's `stake` / `withdraw` / `claim` reverts, because the reward-claim leg reverts inline — principal is frozen for **all** stakers simultaneously.
4. Recovery: the owner re-grants mint authorization (unfreezes) or sweeps principal out-of-band via `emergencyTransfer`.

There is **no** unprivileged or permissionless trigger; the freeze is a side effect of a privileged action on the shared token, and it cannot be induced by an external attacker.

### Impact

Temporary, total denial of service on principal. When mint authorization is revoked, **every** staker with a non-zero pending phUSD accrual is frozen out of `stake`, `withdraw` and `claim` at the same time. This is a strictly broader blast radius than the parent Medium **V3-M-05**, whose USDC-blocklist trigger froze only an individual blocklisted beneficiary; here a single shared-token authorization change freezes the entire staker set.

No assets are stolen and there is no permanent loss: principal remains locked in the contract and is fully recoverable once the owner re-grants the mint role (or sweeps out-of-band via `emergencyTransfer`). This recoverability is the honest basis for **Medium**, not High.

### Severity is disputed and under human triage

This finding is carried at **Medium** under the symmetry rule (borderline → keep the higher severity pending human triage). The two review passes disagreed:

- **severity-classifier → Low:** the trigger is owner-privileged with no unprivileged/permissionless path, and the freeze is fully owner-reversible with no asset loss. Under C4, a DoS that requires a privileged action and is recoverable by that same privilege is QA/Low.
- **severity-auditor → Medium:** the blast radius is **all** stakers' principal frozen at once (broader than the individual-beneficiary parent V3-M-05); the trigger is an **external** shared-ecosystem-token authorization revocation that PhlimboV3 does not control (matching the C4 Medium bar: "protocol function/availability impacted, temporary fund freeze, with stated assumptions and external requirements"); and users cannot self-recover.

**Deciding question for the human triager:** if the phUSD/Flax mint authority is the same trusted entity as PhlimboV3's owner **and** `revokeAllMintPrivileges()` is expected to be short-lived, then Low is defensible (a self-inflicted, self-cured freeze). If the Flax authority is a **separate** ecosystem operator (as the mutable interface-only dependency structure in this repo suggests) or the freeze is unbounded, then Medium holds. Finalize via `/ledger phlimbo-ea`.

### Proof of Concept

A passing Foundry PoC (`PoC_V3L14_phUSDMintFreeze.t.sol`) demonstrates the freeze end-to-end against `PhlimboV3` at commit `e32588d`. Test flow:

1. **Happy path** — with mint authorized, a staker (`carol`) withdraws her full principal plus freshly-minted pending phUSD, proving the path works normally.
2. **Asymmetry control** — a *stable* reward token that reverts on transfer to a blocked recipient (`dave`) does **not** brick `claim`/`withdraw`; the story-029 bank catches it and `totalUnclaimableStable` increases gracefully. This isolates the mint leg as the sole un-banked leg.
3. **Revoke** — `phUSD.revokeAllMintPrivileges()` bumps the mint version, de-authorizing PhlimboV3 (the PoC also notes `setMinter(phlimbo,false)` produces the identical freeze).
4. **All-staker freeze** — `withdraw`, `claim` and `stake` all revert for every staker with the exact mint error, and the PoC asserts `alice`/`bob` principal is still locked (`userInfo` unchanged), i.e. nobody can exit.
5. **Recovery** — re-granting the mint role at the bumped version lets the same `withdraw` succeed and `alice` fully exits, proving the freeze is temporary/recoverable (the Medium, not High, basis).

**Selector caveat.** The PoC models the revert with an `IFlax`-faithful mock (`TogglableFlax`) whose `mint` reverts with `NotAuthorizedMinter(address)` when `canMint == false` or `mintVersion` no longer matches — the two mechanisms named above. Because the real phUSD/Flax token is a **mutable, interface-only dependency** in this repo, the literal on-chain revert selector is illustrative, not confirmed against upstream. The finding does **not** depend on the specific selector: any revert from the un-wrapped mint call bricks the path identically.

## Recommended mitigation steps

Wrap the phUSD mint leg at `:863` in the same non-reverting `_tryTransfer`+bank pattern already applied to the stable (`:875`) and promo (`:899`) legs. On a mint failure, bank the pending phUSD amount and expose a permissionless pull so the beneficiary can claim it once authorization is restored, rather than letting the revert propagate through `stake`/`withdraw`/`claim`:

```solidity
// src/PhlimboV3.sol:862-864  (_claimRewards) — proposed
if (pendingPhUSDAmount > 0) {
    // mirror the stable/promo legs: never revert the principal path
    if (!_tryMint(phUSD, beneficiary, pendingPhUSDAmount)) {
        // bank the un-mintable phUSD for a later permissionless pull
        unclaimablePhUSD[beneficiary] += pendingPhUSDAmount;
        totalUnclaimablePhUSD += pendingPhUSDAmount;
    }
}
```

where `_tryMint` performs the mint inside a low-level call / try-catch and returns `false` on revert (analogous to the existing `_tryTransfer`). This decouples reward delivery from principal accounting, so a mint-authorization revocation defers the reward instead of freezing every staker's exit — closing the V3-M-05 residual entirely.

**Ledger note:** this is `incompleteFixOf` **V3-M-05** — V3-M-05 must be flagged as an incomplete fix, **not** auto-closed to `fixed`, until the mint leg is banked.
