# QA Report for phlimbo-ea (run phlimbo-ea-04)

Bundle of all Low-severity and Centralization findings for the Phlimbo audit, plus the
automated 4naly3er QA/gas baseline (see Appendix A). Spec-conformance / faithfulness items
(F-01) are reported separately and are intentionally **not** included here (Law 2).

Submodule HEAD: `1b1a32c4d1d7ec81a043f40ffe9a6d408c89d301`

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 7 |
| Centralization | 1 |
| **Total** | **8** |

| Label | Title |
|-------|-------|
| L-01 | CEI gap in stake/withdraw/claim (debt settled after external mint/transfer) — defense-in-depth |
| L-02 | `pauseWithdraw` bypasses the `MINIMUM_STAKE` dust guard (INV-6 weakening) |
| L-03 | Stable reward stranding via per-share rounding floor in `_updatePool` |
| L-04 | `setPauser` emits no event on rotation of the security-critical pauser role |
| L-05 | `pendingPhUSD` / `pendingStable` revert (Panic 0x11) instead of returning 0 |
| L-06 | Partial `pauseWithdraw` leaves reward debt anchored to pre-withdraw stake → claim/withdraw/stake underflow-brick |
| L-07 | Permissionless `collectReward` / free non-staker `claim()` poke re-anchors the depletion window — griefing |
| C-01 | `setPauser(0)` + `emergencyTransfer` permanently bricks withdrawals — owner footgun |

---

## Low Risk Findings

### [L-01] CEI violation in stake/withdraw/claim: debt settled after external mint/transfer, no reentrancy guard <!-- id: pe4l1 -->

**Severity**: Low (defense-in-depth)

**Location**: [Phlimbo.sol#L295-L381](lib/phlimbo-ea/src/Phlimbo.sol#L295) (`claim`/`stake`/`withdraw` via `_claimRewards`); external calls at [#L442](lib/phlimbo-ea/src/Phlimbo.sol#L442) (`phUSD.mint`) and [#L448](lib/phlimbo-ea/src/Phlimbo.sol#L448) (`rewardToken.transfer`).

**Description**: `_claimRewards` performs the external `phUSD.mint` (L442) and reward `transfer`
(L448) **before** the caller rebases `phUSDDebt` / `stableDebt` (debt is set after `_claimRewards`
returns), and none of `stake`/`withdraw`/`claim` carry a `nonReentrant` guard. Under the in-scope
token set — a standard ERC-20 phUSD with no mint callback and a standard stablecoin reward — there
is **no reachable trigger**, so today this is a pure checks-effects-interactions hygiene gap.

**Conditional escalation**: This escalates to **High only if** a callback/hook-capable token
(ERC-777 or any token with a transfer/mint hook) is ever wired onto the reward or phUSD path. In
that case an attacker's hook could re-enter `claim()` while debt is still stale and repeatedly draw
payout / over-mint. Such tokens are outside the in-scope set and on the known-invalid list, so the
finding is filed at Low as future-proofing, with the escalation explicitly flagged.

**Recommendation**: Follow checks-effects-interactions — rebase `phUSDDebt` / `stableDebt` before
the external `mint`/`transfer`, and/or add a `nonReentrant` guard to `stake`/`withdraw`/`claim`.
This costs little and removes the latent risk should a hooked token ever be added to the path.

---

### [L-02] `pauseWithdraw` bypasses the `MINIMUM_STAKE` dust guard (INV-6 weakening) <!-- id: pe4l2 -->

**Severity**: Low

**Location**: [Phlimbo.sol#L245-L261](lib/phlimbo-ea/src/Phlimbo.sol#L245) (`pauseWithdraw`); compare the dust guard in `withdraw` at [#L346-L351](lib/phlimbo-ea/src/Phlimbo.sol#L346).

**Description**: `withdraw()` enforces a dust guard that forces a full exit when the remaining
position would fall below `MINIMUM_STAKE`, upholding INV-6 (the first-depositor / precision
mitigation). `pauseWithdraw` omits this guard, so during a pause a user can leave a
sub-`MINIMUM_STAKE` position and dust `totalStaked`. This makes the low-stake / low-APY dust regime
reachable, where `_updatePhUSDEmissionRate` / per-share math can floor phUSD emission to 0
(under-emission). The catastrophic accumulator-overflow facet originally hypothesized was **refuted**
by symbolic analysis (out of realistic range); the confirmed consequence is degraded precision /
under-emission, a low-severity effect. No theft.

**Recommendation**: Apply the same dust / `MINIMUM_STAKE` guard in `pauseWithdraw` that `withdraw()`
uses (force a full exit when the remaining amount would be below `MINIMUM_STAKE`), so INV-6 holds on
every exit path.

---

### [L-03] Stable reward stranding via per-share rounding floor in `_updatePool` <!-- id: pe4l3 -->

**Severity**: Low

**Location**: [Phlimbo.sol#L409-L417](lib/phlimbo-ea/src/Phlimbo.sol#L409) (`_updatePool`); credit at [#L410](lib/phlimbo-ea/src/Phlimbo.sol#L410), full debit at [#L413](lib/phlimbo-ea/src/Phlimbo.sol#L413).

**Description**: Each pool update debits `rewardBalance` by `toDistribute` in **full** (L413) but
credits `accStablePerShare` with `floor(toDistribute * PRECISION / totalStaked)` (L410). The floored
sub-share remainder is never credited to any share and becomes permanently uncreditable (though it
remains owner-recoverable via `emergencyTransfer`). The per-update strand is bounded
(`< totalStaked / PRECISION` + 1 wei) and there is **no over-distribution** (INV-4 preserved and
proved). Frequent small updates — amplified by the re-anchoring of M-01 / M-03 — accumulate many
small strands.

**Recommendation**: Carry the floored remainder forward: track the undistributed dust
(`toDistribute * PRECISION mod totalStaked`, or debit `rewardBalance` only by the amount actually
credited) and roll it into the next update so no stable reward is permanently stranded.

---

### [L-04] `setPauser` emits no event on rotation of the security-critical pauser role <!-- id: pe4l4 -->

**Severity**: Low (observability)

**Location**: [Phlimbo.sol#L206-L208](lib/phlimbo-ea/src/Phlimbo.sol#L206) (`setPauser`).

**Description**: `setPauser` rotates the security-critical pauser role but emits no event, so
off-chain monitors cannot detect the role change without polling storage — hindering incident
response on a sensitive role. (The companion missing-zero-check on `setPauser` was deliberately not
raised: `setPauser(0)` is documented-intentional to "disable pausing"; its operational hazard is
covered by C-01.)

**Recommendation**: Emit an event (e.g. `PauserUpdated(oldPauser, newPauser)`) on every `setPauser`
call so the role rotation is observable off-chain.

```solidity
event PauserUpdated(address indexed oldPauser, address indexed newPauser);

function setPauser(address newPauser) external onlyOwner {
    emit PauserUpdated(pauser, newPauser);
    pauser = newPauser;
}
```

---

### [L-05] `pendingPhUSD` / `pendingStable` revert (Panic 0x11) instead of returning 0 <!-- id: pe4l5 -->

**Severity**: Low (off-chain integration availability)

**Location**: [Phlimbo.sol#L479-L514](lib/phlimbo-ea/src/Phlimbo.sol#L479) (`pendingPhUSD` / `pendingStable`); underflow at [#L489](lib/phlimbo-ea/src/Phlimbo.sol#L489) and the `pendingStable` analogue.

**Description**: After a partial `pauseWithdraw` leaves stale debt (same precondition as M-02),
`pendingPhUSD` / `pendingStable` compute `(amount * accPerShare) / PRECISION - debt` where the
debt term now exceeds the accrual term, reverting with Panic 0x11 (arithmetic underflow) instead of
returning 0. Off-chain consumers (dashboards, integrators) expecting a `uint256` get a revert —
an integration DoS. No on-chain asset impact from the view itself; the underlying on-chain account
brick is carried separately by M-02.

**Recommendation**: Clamp the views — return 0 when `(amount * accPerShare) / PRECISION < debt`
instead of subtracting unconditionally (saturating subtraction). Pairs with the M-02 on-chain
debt-rebase fix.

---

### [L-06] Partial `pauseWithdraw` leaves reward debt anchored to pre-withdraw stake → claim/withdraw/stake underflow-brick <!-- id: pe4l6 -->

**Severity**: Low (account-level availability; reclassified from Medium)

**Location**: [Phlimbo.sol#L245-L261](lib/phlimbo-ea/src/Phlimbo.sol#L245) (`pauseWithdraw` mutates `user.amount`/`totalStaked` but never rebases `phUSDDebt`/`stableDebt`); underflow lands in `_claimRewards` at [#L432-L455](lib/phlimbo-ea/src/Phlimbo.sol#L432) (subtractions at #L440 / #L446).

**Description**: `pauseWithdraw` is the only balance-mutating path that decrements `user.amount`
and `totalStaked` **without** calling `_updatePool()` and **without** rebasing the user's reward
debt. After a *partial* `pauseWithdraw`, the debt still encodes the larger pre-withdraw stake. On
the next normal interaction `_claimRewards` computes `user.amount * accPerShare / PRECISION - debt`
where the minuend is now sized to the smaller stake while `debt` is still sized to the old one, so
the subtraction reverts with `Panic(0x11)` (arithmetic underflow). This bricks `claim()`,
`withdraw()`, and `stake()` for the account, and the `pendingPhUSD` / `pendingStable` views revert
too. The remaining principal is recoverable only by re-pausing and calling `pauseWithdraw` again
(which skips `_claimRewards`); if no re-pause ever occurs the residual is stranded — that
permanent-strand corner is captured by C-01. No theft, no attacker profit; the trigger is
`msg.sender`-only (self-inflicted) and multi-gated (requires a pause plus a *partial*
`pauseWithdraw`), which is why it is filed at Low rather than Medium. The documented known issue
("pauseWithdraw does NOT claim rewards or update pool") covers reward **forfeiture** only — it does
not cover this downstream stale-debt brick of the *remaining* principal, so the finding stays in
scope.

**Recommendation**: Keep reward-debt accounting consistent with the new principal inside
`pauseWithdraw`. Preferred: call `_updatePool()` then re-anchor debt to the post-decrement
`user.amount` (`user.phUSDDebt = user.amount * accPhUSDPerShare / PRECISION` and the stable
analogue) before transferring out — rewards may still be forfeited, but a later `_claimRewards`
can no longer underflow. Alternatively, forbid partial emergency exits (force a full drain so the
`amount == 0` early-return in `_claimRewards` is always reached).

**Detailed report + PoC**: This is a high-quality Low with a **passing** PoC (asserts the exact
`Panic(0x11)` on `claim`/`withdraw`/`stake`/`pendingPhUSD`/`pendingStable` after a partial
`pauseWithdraw`, then recovery via re-pause). Full write-up, severity rationale, and mitigation
diff: [`./L-06-pauseWithdraw-stale-debt-brick.md`](./L-06-pauseWithdraw-stale-debt-brick.md). PoC:
`workspace/phlimbo-ea/test/poc-2004-M-02-pausewithdraw-stale-debt-brick.t.sol`. Ledger: M-01
(still-open carryover).

---

### [L-07] Permissionless `collectReward` / free non-staker `claim()` poke re-anchors the depletion window — griefing <!-- id: pe4l7 -->

**Severity**: Low (reward-stream availability; reclassified from Medium, **folded into M-01**)

**Location**: [Phlimbo.sol#L270-L286](lib/phlimbo-ea/src/Phlimbo.sol#L270) (`collectReward`, permissionless); shared root cause is the `rewardPerSecond` re-anchor in `_updatePool` at [#L416](lib/phlimbo-ea/src/Phlimbo.sol#L416); the free non-staker poke path is `claim()` at [#L374-L381](lib/phlimbo-ea/src/Phlimbo.sol#L374).

**Description**: `collectReward` is permissionless and `claim()` is callable by an address that has
never staked — `_claimRewards` returns early when `amount == 0` but `_updatePool` still runs first.
Because `_updatePool` recomputes `rewardPerSecond` from the *residual* balance over a *full*
`depletionDuration` on every distribution, each poke re-anchors the depletion window, so distributing
more frequently delivers less of the balance within any fixed horizon
(`delivered(N) = 1 - (1 - T/(N*D))^N`, decreasing in N → ~63.2%). An unprivileged actor holding zero
stake, zero reward tokens, and zero approvals can drive the stream onto its worst-case decay curve at
gas-only cost, and once the residual drops below ~`depletionDuration/12` reward-wei the per-poke
distribution floors to 0 while `lastRewardTime` still advances — permanently stalling the dust tail.
Attacker payoff is exactly zero (pure value-denial). This shares M-01's L416 re-anchor root cause and
the identical ~63.4% figure; its only **independent** impact is the dust tail-stall (~300 wei for an
18-decimal token at `depletionDuration = 3600`), which is why it is reclassified from Medium to Low
and folded into M-01 as the access-control / tail-stall angle. **See M-01** for the primary
re-anchor / reward-decay treatment.

**Recommendation**: Fix the shared root cause (also fixes M-01) — stop recomputing `rewardPerSecond`
from the residual balance on every distribution; anchor to a fixed window end set at funding time so
poke frequency cannot affect delivery (PhlimboV2 already removes this recompute). Defense-in-depth:
gate `collectReward` to authorized funders and make `_updatePool` a no-op for callers that neither
change `totalStaked` nor fund the pool (kills the free non-staker `claim()` poke). Close the tail
stall by advancing `lastRewardTime` only when `toDistribute > 0`.

**Detailed report + PoC**: Full write-up, decay derivation, and the zero-cost griefing PoC (100 free
non-staker pokes suppress realized reward to ~63.4% at zero token cost):
[`./L-07-permissionless-collectReward-griefing.md`](./L-07-permissionless-collectReward-griefing.md).
PoC: `workspace/phlimbo-ea/test/poc-2004-M-03-permissionless-collectreward-grief.t.sol`.
Cross-reference: **M-01** (shared root cause). Ledger: M-02 (still-open carryover).

---

## Centralization Risks

### [C-01] `setPauser(0)` + `emergencyTransfer` permanently bricks withdrawals — owner footgun <!-- id: pe4c1 -->

**Severity**: Centralization (non-obvious owner footgun, Law 3 — **not** a malicious-owner vector)

**Location**: [Phlimbo.sol#L214-L227](lib/phlimbo-ea/src/Phlimbo.sol#L214) (`emergencyTransfer`); interacts with `setPauser` at [#L206-L208](lib/phlimbo-ea/src/Phlimbo.sol#L206) and `unpause` at [#L197-L198](lib/phlimbo-ea/src/Phlimbo.sol#L197).

**Description**: `setPauser(0)` is documented as "disable pausing" (L204) and reads as a benign,
deliberate configuration. The non-obvious hazard is the **interaction** with `emergencyTransfer`: a
later emergency call sweeps all phUSD + reward (L218-223) and then **unconditionally** `_pause()`s
the contract (L226). `unpause()` requires `msg.sender == pauser` (L197-198), so with `pauser == 0`
**no account can ever unpause** — the contract is permanently paused. The `pauseWithdraw` escape
hatch still passes `whenPaused` but its `safeTransfer` reverts (the balance was already drained), and
`user.amount` / `totalStaked` were never zeroed — so the escape hatch is dead and accounting is left
permanently inconsistent.

**Why this is a footgun, not a malicious-owner finding**: A competent, non-malicious owner would be
**surprised** that the documented "disable pausing" toggle silently converts `emergencyTransfer`'s
auto-pause into an irreversible lock with stranded, non-zeroed accounting. The fund **drain** itself
is an obvious, trusted owner power and is suppressed under Law 3; what is reported is the *marginal*
non-obvious consequence — the permanent-paused state, dead escape hatch, and inconsistent accounting
— not asset loss beyond the trusted sweep. It is capped at Centralization for exactly that reason.

**Impact**: Irreversible paused/locked state with inconsistent on-chain accounting and a
non-functional `pauseWithdraw` escape hatch.

**Recommendation / safe-config guidance**:
- Do **not** operate with `pauser == address(0)` while `emergencyTransfer` is usable and funds are
  staked.
- In `emergencyTransfer`, either drop the unconditional auto-`_pause()`, or zero
  `user.amount` / `totalStaked` on drain so the post-drain state is consistent.
- Alternatively, allow the `owner` to `unpause` when `pauser == address(0)` so the lock is never
  irreversible.

---

## Appendix A — Automated QA/Gas Report (4naly3er)

The canonical C4-style automated report was generated with **4naly3er** over the phlimbo-ea source
(`workspace/phlimbo-ea/src` — Phlimbo.sol, PhlimboV2.sol, MigratorV1V2.sol, IFlax.sol, and the
`interfaces/`). Full output is attached at
[`./4naly3er-report.md`](./4naly3er-report.md). High-level counts:

**Low Issues (10 categories)**
| ID | Issue |
|----|-------|
| L-1 | Use a 2-step ownership transfer pattern |
| L-2 | Some tokens may revert when zero-value transfers are made |
| L-3 | Missing checks for `address(0)` when assigning address state variables |
| L-4 | Division by zero not prevented |
| L-5 | Owner can renounce while system is paused |
| L-6 | Possible rounding issue |
| L-7 | Loss of precision |
| L-8 | Solidity 0.8.20+ may not work on other chains due to `PUSH0` |
| L-9 | Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership` |
| L-10 | A year is not always 365 days |

**Non-Critical**: 22 categories. **Gas Optimizations**: 16 categories. See the attached file for the
full instance-level listings.

> Note: the 4naly3er Low/NC/Gas items are the automated bot baseline. Where they overlap a manual
> finding above they are corroborating, not independent — e.g. 4naly3er L-6/L-7 (rounding / loss of
> precision) corroborate manual L-03; the automated "missing event / missing address(0) check" items
> corroborate manual L-04 and the C-01 configuration hazard.
