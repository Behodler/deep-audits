# [CARRYOVER] M-07 — `setYieldStrategy` underwater guard is rate-based, bypassed by AMM execution slippage

> **Carryover stub, not new analysis.** Reported in a prior run; status is acknowledged with a
> **propose-fixed @ `125f585`** (story-010 empty-pool gate) **awaiting human `/ledger` confirmation**.
> This run (`125f585..c3ec65b`, story-011 `depositFor` guard) did **not** touch `setYieldStrategy` and
> did **not** re-verify this proposal. Reproduced for visibility. Triage with `/ledger stable-staker`.

- **Fingerprint:** `969722dc`  ·  **ID:** `ss9m7`
- **Title:** `setYieldStrategy` underwater guard is rate-based, bypassed by AMM execution slippage (incomplete fix of M-06)
- **Severity:** Medium
- **Status:** acknowledged
- **Proposed status:** **fixed @ `125f585`** (run-10 — story-010 empty-pool gate), awaiting human confirmation
- **Location:** `src/StableStaker.sol` — `setYieldStrategy` (L202-238; gated by `require(totalStaked == 0)` at L228 post-story-010)
- **Original report:** [reports/stable-staker/09/submissions/M-07-setyieldstrategy-rate-vs-execution-residual.md](../../../09/submissions/M-07-setyieldstrategy-rate-vs-execution-residual.md)

## Why still open

story-008's underwater guard rejects a swap only by a **rate** comparison (`totalBalanceOf <
principalOf`), which is blind to **AMM execution slippage**: a strategy that reads solvent by rate can
still return less than principal when its position is actually unwound through an AMM. `setYieldStrategy`
then drains `R_exec < totalStaked` with the rate guard satisfied, redeposits, never rewrites
`totalStaked`, and re-arms the exact M-06 silent-block-lift + FCFS-loss-concentration for AMM-priced
strategies. PoC-proven against the real `ERC4626MarketYieldStrategy`. Run-10's story-010 empty-pool
gate reverts any in-place swap on a live pool **before** any rate/execution path runs, making the
residual structurally unreachable (profile G-5, verified) — hence **propose-fixed @ `125f585`**
(superseding the prior operational won't-fix). Human-acknowledged, so proposed-not-auto-flipped; this
run's scoped story-011 change did not re-verify it. Stays a visible carryover until a human confirms.

## Resolve

```
/ledger stable-staker fixed 969722dc --commit 125f585
```
