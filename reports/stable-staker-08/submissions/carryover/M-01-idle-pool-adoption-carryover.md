# [CARRYOVER] M-01 — Idle-pool strategy adoption discards `strategy.deposit` creditedPrincipal (last-withdrawer FCFS shortfall)

> **This is a carryover stub, not new analysis.** This finding was reported and submitted in a prior
> run and is **still live** at the current HEAD. It is reproduced here so it is not lost between runs.
> Triage it with `/ledger stable-staker`.

- **Severity:** Medium
- **Status:** submitted (still-live; re-confirmed this run)
- **Location:** `src/StableStaker.sol` — `setYieldStrategy` adoption sweep (~L213-216, now L231-233), `_routeDeposit` (~L674-680)
- **First seen:** stable-staker-06  ·  **Still present as of:** stable-staker-08 (HEAD `f85450b`)
- **Original report:** [reports/stable-staker-06/submissions/M-01-idle-pool-adoption-discards-credited.md](../../../stable-staker-06/submissions/M-01-idle-pool-adoption-discards-credited.md)
- **Fingerprint:** `dab5a656`

## Status this run

Still **live** at HEAD `f85450b`: `setYieldStrategy` still discards the `strategy.deposit` return at
L231-233. The story-006/007 changes (the `!active` guard at L203 and the `relinquishPrincipal`
buffer-branch reconciliation at L703) did **not** address the healthy-pool adoption-haircut desync.
PoC `workspace/stable-staker/test/PoC_M01_AdoptionHaircut.t.sol` (A = 100 deposited / B = 98 booked /
2.0 shortfall over a populated idle pool).

> **Distinct from this run's new M-06 (`dbdc3ac9`):** M-01 is the **healthy-pool** adoption-haircut
> desync (discarded deposit-credit return over a non-empty idle pool). M-06 is the **underwater-swap**
> path (under-recovering drain + stale `totalStaked` re-arms the withdraw block on a still-shortfalled
> pool). Same function, different root cause; separate fingerprints.

Not re-reported with a full submission to avoid duplicating an already-submitted ledger Medium; this
stub is the visibility pointer. See the [original report](../../../stable-staker-06/submissions/M-01-idle-pool-adoption-discards-credited.md)
for the full description, impact, attack path, PoC, and recommendation.
