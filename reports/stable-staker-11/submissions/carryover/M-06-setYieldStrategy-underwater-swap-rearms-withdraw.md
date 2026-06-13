# [CARRYOVER] M-06 — `setYieldStrategy` underwater swap silently lifts the withdraw block and FCFS-concentrates the loss

> **Carryover stub, not new analysis.** Reported in a prior run; status is acknowledged with a
> **propose-fixed @ `125f585`** (story-010 empty-pool gate) **awaiting human `/ledger` confirmation**.
> This run (`125f585..c3ec65b`, story-011 `depositFor` guard) did **not** touch `setYieldStrategy` and
> did **not** re-verify this proposal. Reproduced for visibility. Triage with `/ledger stable-staker`.

- **Fingerprint:** `dbdc3ac9`
- **Title:** `setYieldStrategy` underwater-swap silently lifts the underwater-withdraw block and FCFS-concentrates the realized loss on the last withdrawer
- **Severity:** Medium
- **Status:** acknowledged (will-fix)
- **Proposed status:** **fixed @ `125f585`** (run-10 — story-010 empty-pool gate), awaiting human confirmation
- **Location:** `src/StableStaker.sol` — `setYieldStrategy` (L202-238; gated by `require(totalStaked == 0)` at L228 post-story-010)
- **Original report:** [reports/stable-staker-08/submissions/M-06-setYieldStrategy-underwater-swap-rearms-withdraw.md](../../../stable-staker-08/submissions/M-06-setYieldStrategy-underwater-swap-rearms-withdraw.md)

## Why still open

Swapping a token's strategy while the OLD strategy is underwater drained only the recoverable
principal `R_old < totalStaked` (underwater guard OFF), redeposited `R_old` into the new strategy
(deposit return discarded), and never rewrote `pool.totalStaked`. The new strategy reads at par, so
`_isUnderwater` flips false and `withdrawDisabled` flips `true → false`: the protective block is
silently erased while a real `totalStaked - R_old` shortfall remains, realized FCFS-at-par on the last
withdrawer. story-008 closed only the **rate**-underwater case (residual carried as M-07 `969722dc`).
Run-10's story-010 empty-pool gate makes any in-place swap on a live pool revert before the rate
guard is reached, **structurally subsuming** this path (profile G-5, verified) — hence
**propose-fixed @ `125f585`**. Human-acknowledged (will-fix), so proposed-not-auto-flipped; this run's
scoped story-011 change did not re-verify it. Stays a visible carryover until a human confirms.

## Resolve

```
/ledger stable-staker fixed dbdc3ac9 --commit 125f585
```
