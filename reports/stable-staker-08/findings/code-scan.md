# Tier-2 Code Scan — stable-staker (regression)

- **Target:** `lib/stable-staker/src/StableStaker.sol` @ HEAD `f85450b`
- **Cross-contract surface:** reflax `AYieldStrategy` / `ERC4626YieldStrategy` (`lib/stable-staker/lib/reflax-yield-vault/src/`)
- **Scope:** confirm/refute residuals A–D surfaced by Tier 1 after story-006 (`setYieldStrategy` guard+drain) and story-007 (buffer-path `relinquishPrincipal`); find any fix-introduced regression.
- **Scan type:** interaction-level (cross-contract). Local properties trusted from profile where tagged `verified`.

---

## Ground facts (established from source)

Lockstep deposit invariant (the base relation everything rests on), `StableStaker.stake` L266-270 / `depositFor` L548-551:
```solidity
uint256 received = _pullToken(token, msg.sender, amount);
uint256 credited = _routeDeposit(token, received);   // == strategy.deposit(...) booked principal
user.amount   += credited;
pool.totalStaked += credited;                          // SAME `credited` value
```
`_routeDeposit` (L674-680) returns the strategy's booked `creditedPrincipal`, and `totalStaked` is incremented by exactly that. So along the deposit path `ΔtotalStaked == Δ clientBalances[this] == Δ principalOf`. **The healthy steady-state invariant is `principalOf(token,this) == totalStaked`** (asserted across the integration suite, e.g. `YieldStrategyIntegration.t.sol:260,342,351,360`).

Strategy-side primitives (reflax `AYieldStrategy`):
- `relinquishPrincipal` → `_relinquishInternal` (L638-654): caps `amount` to `clientBalances[this]` (= `principalOf`), then decrements `clientBalances[this]` and `totalDeposited` by the capped value. No share movement.
- `withdraw` → `_withdrawInternal` (L703-723): caps `amount` to `clientBalances[this]`, disposes shares for the capped amount, decrements `clientBalances[this]`/`totalDeposited` by the **requested (capped)** amount. Shortfall stays as protocol-owned yield.
- `principalOf` (L494-496) == `clientBalances[token][account]`.

`initiateMigration` post-check (`StableStaker.sol:410-413`): after `R = _routeExit(token, P=totalStaked, false)` (strategy-redeem, guard OFF), requires `strategy.principalOf(token,this) == 0`. Because the redeem branch caps the `P` request to `principalOf` and decrements by that capped value, **the post-check passes iff `principalOf <= P == totalStaked` going in**, i.e. iff `principalOf <= totalStaked`. It is bricked iff `principalOf > totalStaked` (the original M-04 `dc361b7d`).

---

## RESIDUAL A — incomplete buffer-desync fix (buffer `relinquishPrincipal` under-decrement re-bricks migration)

**VERDICT: REFUTED.**

The premise is "can the buffer branch be entered with `amount > principalOf`, leaving `totalStaked` lower than `principalOf` and re-bricking migration." I traced both halves and the direction of every divergence the buffer path can produce.

**Buffer branch entry (`_routeExit` L697-704):** strategy set, `guardUnderwater==true` (only `withdraw` L300), `_isUnderwater` true, and `t.balanceOf(this) >= amount`. On entry:
- `withdraw` has already done `totalStaked -= amount` (L289), gated by `user.amount >= amount` (L284).
- L703 calls `relinquishPrincipal(token, amount)` → decrements `principalOf` by `min(amount, principalOf)`.

**Direction analysis.** The buffer path moves `totalStaked` down by `amount` and `principalOf` down by `min(amount, principalOf) <= amount`. So the buffer path can only make `principalOf` **larger relative to** `totalStaked`, never smaller — it pushes toward `principalOf >= totalStaked`, the *safe* side of the migration post-check (which is bricked only by `principalOf > totalStaked`).

- If `amount <= principalOf` (the healthy-invariant case `totalStaked == principalOf`): no cap, both drop by `amount`, `principalOf == totalStaked` preserved. This is the in-scope story-007 fix, asserted in `test_withdraw_underwater_bufferCovers...` (L260) and the sequential test (L342-360). **Migration remains satisfiable.**
- If `amount > principalOf` (only reachable after RESIDUAL B has already made `totalStaked > principalOf`): the cap fires, `principalOf` → 0 (or to `principalOf - amount` floored at the cap), and `totalStaked` → `totalStaked - amount`. Result is still `totalStaked >= principalOf` (the cap can never push `principalOf` *above* `totalStaked`).

**Migration re-bricking check.** `initiateMigration` is bricked only when `principalOf > totalStaked == P`. Neither the buffer path nor the rewire produces that:
- Buffer path: shown above, always lands on `principalOf <= totalStaked`.
- Rewire (RESIDUAL B): produces `totalStaked > principalOf` — the *opposite* inequality.

I constructed the candidate bricking sequence and it does not brick: stake 100+100 → YS1 underwater 90% → swap to YS2 (recovers 180, `totalStaked=200`, `YS2.principalOf=180`) → YS2 underwater, buffer-funded → Alice `withdraw(100)` buffer branch: `totalStaked=100`, `relinquishPrincipal(100)` (180>=100, no cap) → `principalOf=80`. State `totalStaked=100 > principalOf=80`. Then `initiateMigration`: `P=100`, `withdraw(100)` caps to `principalOf=80`, zeroes it, post-check `principalOf==0` **passes**. The strategy-redeem cap-and-zero in `initiateMigration` always clears `principalOf` whenever `P >= principalOf`, which holds for all `totalStaked >= principalOf`.

**Conclusion.** Story-007 removed the *only* path that produced `principalOf > totalStaked` (the pre-fix buffer branch that decremented `totalStaked` without touching `principalOf`). No path under HEAD `f85450b` re-creates `principalOf > totalStaked`, so `initiateMigration`'s post-check is no longer brickable by buffer-path desync. **M-04 (`dc361b7d`) is genuinely remediated, not merely narrowed.** Tier-1's `storyInvariantRestored: verified` is upheld for the single-strategy buffer path.

(Note: the cap-to-available *does* fire in the post-RESIDUAL-B state, but it heals toward the safe inequality rather than re-bricking. The real defect in that state is RESIDUAL B's stranded principal, below — not a migration brick.)

---

## RESIDUAL B — `setYieldStrategy` rewire desync (under-recovery strands principal; pool silently underwater on new strategy)

**VERDICT: CONFIRMED (real, reachable, demonstrated by the project's own test).** Severity: **Medium** (value leak / availability under a stated owner-operation precondition; non-obvious owner footgun).

**Mechanism.** `setYieldStrategy` (story-006, L202-238) drains the old strategy with `_routeExit(token, staked, false)` — **guard OFF**, strategy-redeem branch (L216) — then re-deposits whatever landed in idle balance into the new strategy (L231-234) and **discards `strategy.deposit(...)`'s return** (RESIDUAL D), while **never rewriting `totalStaked`** and **never running an `initiateMigration`-style `principalOf==0` post-check**.

When the old strategy is underwater, the guard-OFF redeem returns less than the requested `staked` (reflax `_withdrawInternal` pays the haircut value while decrementing principal by the requested amount). The recovered idle balance is `< totalStaked`. That short amount is what gets deposited into the new strategy, so:

```
totalStaked  (unchanged)  >  new strategy principalOf  (= recovered, haircut)
```

**Demonstrated by the in-repo test** `test_setYieldStrategy_swap_fromUnderwaterVault_recoversWhatItCan_noRevert` (`YieldStrategyIntegration.t.sol:622-639`), which *asserts this desync as expected behaviour*:
```solidity
strategy.setValueFactorBps(9_000);                 // YS1 90% underwater
staker.setYieldStrategy(usdc, strategy2);          // swap
assertEq(strategy2.principalOf(usdc, staker), 90e6);   // new strategy got 90e6
(,,, uint256 totalStaked) = staker.poolInfo(usdc);
assertEq(totalStaked, 100e6);                          // but totalStaked still 100e6
```
So `totalStaked (100e6) > principalOf (90e6)` after one owner call.

**Impact.** State sequence and consequences:
1. Users stake 100e6 → YS1 holds 100e6, `totalStaked=100e6`.
2. YS1 dips below par (e.g. depeg / negative-yield window). `withdrawDisabled` is true (good — non-migrating users are protected by the underwater guard).
3. Owner, intending a benign infra move (swap YS1 → YS2), calls `setYieldStrategy`. The drain realizes the loss at par-debit/haircut-credit (guard OFF), recovers 90e6, and deposits 90e6 into YS2. `totalStaked` still reads 100e6.
4. The pool is now **silently underwater on YS2 at par**: `totalBalanceOf == principalOf == 90e6 < totalStaked == 100e6`. But `_isUnderwater` compares `totalBalanceOf` vs `principalOf` (both 90e6) → returns **false**. So `withdrawDisabled` now reports **false** and `withdraw` takes the **strategy-redeem** branch, not the protective buffer branch.
5. **FCFS at par over a 90e6 pile against 100e6 of book:** the first 90e6 of withdrawals redeem in full from YS2; the last 10e6 of stakers' book has no backing and their `strategy.withdraw` caps to the now-zero `principalOf`, returning ~0. The underwater guard that was protecting them *before* the swap is gone, because the swap "laundered" the below-par position into an at-par position whose principal was written down to match the recovered tokens. The loss is silently socialized onto whoever exits last (same class of harm as `0dca43f3`/M-05, but here *triggered by an owner config action that masks the underwater state*, not by an explicit emergency exit).

This is distinct from the acknowledged `678e6f` (`setYieldStrategy` lacks `!active` guard) — that was fixed by L203. It is also distinct from the profile's deferred "swap-while-underwater realizes a loss" note: the novel, reportable part is that the rewire **erases the underwater signal** (`withdrawDisabled` flips to false, the buffer branch becomes unreachable) so subsequent ordinary `withdraw`s are no longer loss-protected and become FCFS-at-par — the very protection story-002/007 added is bypassed by a single owner call over an impaired old strategy.

**Footgun classification (Law 3).** A competent, non-malicious owner swapping strategies would be **surprised** that doing so over a temporarily-impaired old strategy (a) crystallizes the loss against users rather than waiting for recovery, and (b) flips off the underwater withdraw-protection so the loss becomes a silent FCFS bank-run on the new strategy. Surprise ⇒ footgun ⇒ in scope. Safe-config guidance: only `setYieldStrategy`-swap while `withdrawDisabled(token) == false` (old strategy at/above par) or while `totalStaked == 0`; if the old strategy is impaired, route the move through terminal `initiateMigration` (which snapshots `R<P` and pays pro-rata `min(R,P)/P`, sharing the haircut fairly) instead of an at-par rewire.

**Why not High.** Requires an owner action (the swap) as the trigger, and the precondition is a below-par old strategy — assets are not directly stealable by an unprivileged attacker. The leak/availability impact under a stated operational precondition fits Medium.

**Recommended fix (one of):**
- Block the swap while the old strategy is underwater: `require(!_isUnderwater(token, old), ...)` before the drain (forces the owner toward terminal migration for an impaired position); or
- After the drain + sweep, run the same realization-completeness reconciliation as migration and write `totalStaked` down to the actually-credited principal (booking the haircut as a recorded loss so the pool is not silently underwater and the buffer protection stays armed). Capture `credited` from L233's discarded return for this.

---

## RESIDUAL C — `emergencyWithdraw` not migrated to pro-rata (FCFS over-redemption at par)

**VERDICT: CONFIRMED unchanged (carryover, status preserved). Severity: existing acknowledged `0dca43f3` (Medium / M-05), no change from story-006/007.**

`emergencyWithdraw` (L322-337) still calls `_routeExit(token, amount, false)` (L334, **guard OFF**). With guard OFF the buffer/relinquish branch (L697-704) is unreachable — it falls straight to the strategy-redeem branch (L708-710). When the strategy is below par, `strategy.withdraw(amount)` redeems shares worth `amount * factor` (haircut) but the *first* exiters get capped against full principal and walk away closer to whole, while late exiters absorb the shortfall — the FCFS-at-par bank-run captured by `0dca43f3` / M-05.

Story-007 touched only the `guardUnderwater==true` buffer branch; story-006 touched only `setYieldStrategy`. Neither changed the `emergencyWithdraw` exit path or its guard-OFF argument. The behaviour is byte-for-byte the M-05 behaviour. **No regression, no new finding — confirm the existing acknowledged/wont-fix status (`ss7m3`/`ss7m5` triage in memory) stands.**

---

## RESIDUAL D — unused `deposit` return value

**VERDICT: CONFIRMED meaningful, but only harmful via the `setYieldStrategy` sweep (folds into RESIDUAL B). Stake/depositFor paths are SAFE.**

`strategy.deposit(...)` returns the actually-booked `creditedPrincipal`, which the reflax docs and `Deposited` event explicitly note can be **less than the nominal amount** (the AMM market strategy applies a slippage haircut; `ERC4626YieldStrategy._acquireShares` credits full nominal, but `MockYieldStrategy` models a `depositSlippageBps` haircut, confirming the interface contract allows `credited < amount`).

- **`stake` / `depositFor`:** SAFE. They capture the return as `credited` and book `totalStaked += credited` (L267-270 / L549-551), with `require(credited > 0)` on stake (L268). So a haircutting strategy keeps `totalStaked == principalOf` — no desync. (Tier-1's `depositFor` missing-`credited>0` is a separate, already-ledgered Low `eae10d6`; not re-raised here.)
- **`setYieldStrategy` sweep (L231-234):** UNSAFE — `strategy.deposit(token, idleBalance, address(this))` **discards the return**. Combined with the unwritten `totalStaked`, a haircutting **new** strategy would book `principalOf < idleBalance <= totalStaked`, another route to `totalStaked > principalOf`. With the standard `ERC4626YieldStrategy` (full-credit) this is benign; with an AMM-backed `ERC4626MarketYieldStrategy` it compounds RESIDUAL B's desync on the *deposit* side too.

This is not an independent finding of its own severity — it is the deposit-side contributor to RESIDUAL B and is fixed by the same remedy (capture `credited` from L233 and reconcile `totalStaked`). Flagged here for completeness so the RESIDUAL B fix addresses both the redeem-side (drain) and deposit-side (sweep) under-credit.

---

## CEI / reentrancy pass on the new external-call surface

**VERDICT: no new reentrancy finding. CEI holds on the in-scope paths.**

- **`withdraw` → `_routeExit` buffer branch (L300 → L703 `relinquishPrincipal`):** `withdraw` is `nonReentrant`. All StableStaker state (`user.amount`, `totalStaked`, `rewardDebt`, staker-set) is mutated **before** the external `relinquishPrincipal` call (L288-293 vs L703), and the only post-call action is `safeTransfer` (L301). `relinquishPrincipal` itself is `onlyAuthorizedClient nonReentrant` on the reflax side and touches no shares. CEI respected; the `nonReentrant` guard closes any cross-contract A→B→A loop. Consistent with Tier-1 `796f775` (the only reentrancy-ordering note is on `initiateMigration`, which is guard- and trust-mitigated and already ledgered).
- **`setYieldStrategy` (L202-238): NOT `nonReentrant`** (Tier-1 `reentrancyGuarded` list excludes it; correct). It performs external calls in order: `_routeExit`→`strategy.withdraw` (drain, L216), `forceApprove(old,0)` (L220), `forceApprove(new,max)` (L227), `strategy.deposit` (sweep, L233). It is `onlyOwner`, so re-entry requires the owner to wire a malicious strategy — excluded by Law 3 (owner trusted for knowing actions; a malicious strategy is the owner's own choice). The *non-malicious* risk here is the accounting desync (RESIDUAL B), not reentrancy. The function reads `yieldStrategy[token]` (old) before the L223 reassignment, so drain ordering is correct (profile §3 confirmed). No state is left mutated-then-callable-back in a way an honest strategy could exploit. **No reentrancy finding.**
- **`rescueERC20` (L725-732): NOT `nonReentrant`** — intentional, trailing `safeTransfer`, no post-transfer state. Existing `0790a76` (rescue can sweep the buffer) is a separate ledgered finding, out of this scan's residual set.

---

## Summary of verdicts

| Residual | Verdict | Severity | Note |
|---|---|---|---|
| A — buffer `relinquishPrincipal` re-bricks migration | **REFUTED** | — | Buffer path only heals toward `principalOf <= totalStaked`; cannot create `principalOf > totalStaked`. Story-007 genuinely fixes M-04. |
| B — `setYieldStrategy` rewire under-recovery desync | **CONFIRMED** | **Medium (new)** | Underwater swap leaves `totalStaked > principalOf`, erases the underwater signal, re-enables FCFS-at-par on the new strategy. Owner footgun. Proven by in-repo test L622-639. |
| C — `emergencyWithdraw` FCFS over-redemption | **CONFIRMED unchanged** | existing M-05 `0dca43f3` | Carryover; story-006/007 did not touch it. No regression. |
| D — discarded `deposit` return | **CONFIRMED (folds into B)** | part of B | Safe on stake/depositFor; unsafe only on the `setYieldStrategy` sweep with a haircutting strategy. Fix with B. |
| CEI/reentrancy on new surface | **clean** | — | `nonReentrant` + CEI hold on `withdraw`/`relinquishPrincipal`; `setYieldStrategy`/`rescueERC20` unguarded by design, owner-gated / trailing-transfer. |

**Net new Tier-2 finding for the pipeline: RESIDUAL B** (Medium, owner footgun — `setYieldStrategy` rewire over an impaired old strategy desyncs `totalStaked > principalOf` and silently disarms the underwater withdraw protection on the new strategy). RESIDUALS A/C/D produce no new standalone finding (A refuted; C is an unchanged carryover; D is the deposit-side facet of B).
