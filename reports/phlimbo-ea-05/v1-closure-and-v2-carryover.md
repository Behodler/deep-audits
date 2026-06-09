# PhlimboEA V1 Closure & V2 Carryover

**Project:** phlimbo-ea
**Date:** 2026-06-08
**Triaged by:** owner (authoritative `/ledger`-style triage)
**Action:** All 25 open V1 findings (`src/Phlimbo.sol`, the sole audited contract) set to
`acknowledged`. PhlimboEA V1 is **deprecated** — all users have been migrated to **PhlimboV2**,
and V1 is retired. No finding below threatens the retired V1 contract any longer.

> **pe4m1 = run-04 M-01 = ledger M-04 = the "Linear-Depletion" finding.** This is the one
> finding **resolved** by V2: PhlimboV2 deliberately **removes the depletion-rate recompute from
> `_updatePool`** (V2 change #1), which was the exact root cause of the exponential-decay
> under-delivery. It is a clean close and does **not** carry into V2.

## PhlimboV2 — the three deliberate changes (authoritative, from `lib/phlimbo-ea/CLAUDE.md`)
PhlimboV2 is "same shape as V1" with exactly three changes:
1. **Depletion-rate recompute REMOVED** from `_updatePool` (the window no longer resets on user interaction).
2. `stake` / `withdraw` / `claim` take an explicit `user` param + a new **`migrator` role** can act on behalf of any user (`pauseWithdraw` stays `msg.sender`-only).
3. An **optional `IPhlimboHook`** is invoked after `stake` / `withdraw` / `claim` (zero-address guarded).

Everything else in V2 is the same shape as V1 — which is why ~20 of these findings carry forward.

---

## Disposition categories

| Category | Meaning | Count |
|---|---|---|
| RESOLVED-IN-V2 | Fixed by V2 change #1; clean close, does NOT carry | 1 |
| LARGELY-RESOLVED-IN-V2 | Primary lever removed by #1; verify residual in V2 | 1 |
| CHANGED-VERIFY-IN-V2 | Touched by #1; mechanics altered, re-review in V2 | 4 |
| AMPLIFIED / NEW-SURFACE-IN-V2 | V2's changes make these worse; HIGH PRIORITY for V2 audit | 2 |
| CARRIES-INTO-V2 | Same shape — present in production V2, needs a V2 audit | 18 |
| **Total unique fingerprints** | | **25** |

(26 ledger label rows — the dual-listed fingerprint `745678e0…` is counted once but listed as both **C-04** and **L-05**.)

---

## RESOLVED-IN-V2 (clean close — does NOT carry)

| Ledger label | Severity | Title | v2Disposition |
|---|---|---|---|
| **M-04** | Medium | "Linear Depletion" implemented as exponential decay: `rewardPerSecond` re-anchored on every interaction (~63% delivered in-window, stranded tail) | RESOLVED-IN-V2: rate-recompute removed from `_updatePool` (change #1). |
| **M-02** | Low (was Medium) | `collectReward` permissionless: any wallet can re-anchor `rewardPerSecond` at gas-only cost, forcing worst-case decay and a permanent D/12 tail-stall | LARGELY-RESOLVED-IN-V2: re-anchor lever removed by change #1; verify any residual permissionless-poke in V2. |

---

## CHANGED-VERIFY-IN-V2 (touched by #1 — re-review in V2)

| Ledger label | Severity | Title | v2Disposition |
|---|---|---|---|
| **L-07** | Low | `collectReward` is mempool-visible: searchers can sandwich a funding deposit to capture rewards intended for long-term stakers | CHANGED-IN-V2: re-anchor removed (#1) alters dynamics; re-verify in V2. |
| **L-08** | Low | `collectReward` with zero `totalStaked` silently leaks funder value: rate anchored but depletion clock does not advance | CHANGED-IN-V2: depletion-clock behaviour altered by #1; re-verify in V2. |
| **L-16** | Low | Stable reward stranding via per-share rounding: `rewardBalance` debited in full while `accStablePerShare` floors → floored remainder permanently uncredited | VERIFY-IN-V2: `_updatePool` changed by #1; rounding math likely same shape — re-verify. |
| **C-01** | Centralization | `setDepletionDuration` has no minimum-duration floor and no two-step gate; one-tx flash drain of `rewardBalance` | VERIFY-IN-V2: depletion mechanics changed by #1; confirm whether `setDepletionDuration`/floor still exists in V2. |

---

## AMPLIFIED / NEW-SURFACE-IN-V2 (V2 makes these worse — HIGH PRIORITY for a V2 audit)

| Ledger label | Severity | Title | v2Disposition |
|---|---|---|---|
| **L-09** | Low | `claim()` / `stake()` / `withdraw()` violate CEI; cross-function reentrancy lever conditional on hooked-token semantics | AMPLIFIED-IN-V2: change #3 adds an external `IPhlimboHook` call into exactly these paths — reentrancy/CEI must be re-reviewed in V2 (priority). |
| **L-10** | Low | `stake(amount, recipient)` lets anyone forcibly re-anchor a victim's reward-debt clock | BROADENED-IN-V2: change #2 (explicit `user` param + `migrator` acting on behalf of any user) widens this on-behalf surface — re-review in V2. |

---

## CARRIES-INTO-V2 (same shape — present in production V2, needs a V2 audit)

| Ledger label | Severity | Title | v2Disposition |
|---|---|---|---|
| **M-01** | Low (was Medium) | `_claimRewards` underflows and reverts after `pauseWithdraw → unpause → claim` sequence | CARRIES-INTO-V2: `pauseWithdraw` + reward-debt math same shape (`pauseWithdraw` still `msg.sender`-only). |
| **M-03** | Medium | phUSD mint authority is load-bearing for solvency; revocation/pause/supply-cap bricks `claim`/`stake`/`withdraw` without graceful degradation | CARRIES-INTO-V2: phUSD minting still load-bearing for solvency. |
| **M-05** | Medium | `pause → pauseWithdraw → unpause` OVER-MINTS phUSD: stale `phUSDPerSecond` accrues over the shrunken stake on unpause (conditional-High footgun) | CARRIES-INTO-V2: `pauseWithdraw` + `phUSDPerSecond` emission same shape; re-assess severity under any non-zero-APY V2 config. |
| **C-02** | Centralization | `emergencyTransfer` sweeps all funds without zeroing accounting, bricking `pauseWithdraw`; with `setPauser(0)` the auto-pause becomes a permanent, unrecoverable lock | CARRIES-INTO-V2: `emergencyTransfer`/pause/`setPauser` same shape. |
| **C-03** | Centralization | Uncapped `desiredAPYBps` converts directly into unbounded phUSD mint pressure; the two-step gate is delay-only | CARRIES-INTO-V2: APY→mint-pressure path same shape. |
| **C-04** | Centralization | Pauser can sandwich `pause`/`unpause` cycles to selectively deny yield to specific stakers *(dual-listed as **L-05**, same fingerprint `745678e0…`)* | CARRIES-INTO-V2: pause/unpause same shape. |
| **L-01** | Low | Declared event `RateUpdated` is never emitted | CARRIES-INTO-V2 (minor): verify event set in V2. |
| **L-02** | Low | `setDesiredAPY` commit is mempool-visible; stakers front-run to capture rate-change delta | CARRIES-INTO-V2 (minor). |
| **L-03** | Low | `setDesiredAPY` commit branch does not clear `pendingAPYBps` / `pendingAPYBlockNumber` | CARRIES-INTO-V2 (minor). |
| **L-04** | Low | `setPauser` emits no event | CARRIES-INTO-V2 (minor). |
| **L-05** | Low | Pauser can sandwich `pause`/`unpause` to selectively deny yield *(dual-listed with **C-04**, same fingerprint `745678e0…`)* | CARRIES-INTO-V2: pause/unpause same shape. |
| **L-06** | Low | `pauseWithdraw` silently forfeits accrued rewards with no event and orphans per-share-accumulator residue | CARRIES-INTO-V2 (blessed KI-4 forfeiture framing). |
| **L-11** | Low | phUSD-is-stake-AND-reward tokenomic compounding spiral | CARRIES-INTO-V2: tokenomics same shape. |
| **L-12** | Low | Contract publishes no cumulative-distribution audit trail | CARRIES-INTO-V2 (minor). |
| **L-13** | Low | `_updatePhUSDEmissionRate` truncates `phUSDPerSecond` to zero at low `totalStaked` × low APY | CARRIES-INTO-V2: emission-rate floor math same shape. |
| **L-14** | Low | `pendingPhUSD()` / `pendingStable()` view-helpers underflow for users with stale debt after `pauseWithdraw` | CARRIES-INTO-V2: `pauseWithdraw` stale-debt view underflow same shape. |
| **L-15** | Low | `pauseWithdraw` bypasses the `MINIMUM_STAKE` / dust-forces-full-exit rule (INV-6 weakening) | CARRIES-INTO-V2: `pauseWithdraw` same shape. |
| **F-01** | Low (faithfulness) | FAITHFULNESS: `emergencyTransfer` breaks story-008 HIGH-5's promise of a safe `pauseWithdraw` exit after a drain | CARRIES-INTO-V2: story-008 promise + `emergencyTransfer` same shape; faithfulness deviation persists. |

---

## Recommended next step

V1 is closed, but the bulk of these findings describe behaviour that is **same-shape in
production PhlimboV2** — and two are **made worse** by V2's own changes:

- **PhlimboV2 (`src/PhlimboV2.sol`)** and **MigratorV1V2 (`src/MigratorV1V2.sol`)** are
  **unaudited and in production.** They are not currently in audit scope.
- **Add both to scope** and carry forward the **CARRIES-INTO-V2**, **AMPLIFIED/NEW-SURFACE-IN-V2**,
  and **CHANGED-VERIFY-IN-V2** findings as **V2 candidates**.
- **Priority for the V2 audit:**
  - **L-09 (AMPLIFIED)** — V2 change #3 introduces an external `IPhlimboHook` call into exactly
    the `stake`/`withdraw`/`claim` paths that already violate CEI. Re-review reentrancy first.
  - **L-10 (BROADENED)** — V2 change #2 (explicit `user` param + `migrator` role acting on
    behalf of any user) widens the on-behalf griefing surface.
  - **MigratorV1V2** itself — the migration mechanism is entirely new code with no prior review.
- The four **CHANGED-VERIFY-IN-V2** findings (L-07, L-08, L-16, C-01) all hinge on `_updatePool`
  / depletion mechanics that change #1 alters; re-verify whether each still reproduces.
- **M-04** (Linear-Depletion) is the only finding **resolved** by V2 (change #1) and should be
  marked closed for V2 as well.

A scoped **`/full-audit` of PhlimboV2 + MigratorV1V2** is recommended.
