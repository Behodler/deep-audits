# [CARRYOVER] M-01 — Idle-pool strategy adoption discards `strategy.deposit` creditedPrincipal (last-withdrawer FCFS shortfall)

> **This is a carryover stub, not new analysis.** This finding was reported and submitted in a prior
> run and is **still live** at the current HEAD `93b7ce6`. It is reproduced here so it is not lost
> between runs. Triage it with `/ledger stable-staker`.

- **Severity:** Medium
- **Status:** submitted (still-live; re-confirmed this run)
- **Location:** `src/StableStaker.sol` — `setYieldStrategy` adoption sweep (~L256-259), `_routeDeposit`
- **First seen:** stable-staker-06  ·  **Still present as of:** stable-staker-09 (HEAD `93b7ce6`)
- **Original report:** [reports/stable-staker-06/submissions/M-01-idle-pool-adoption-discards-credited.md](../../../stable-staker-06/submissions/M-01-idle-pool-adoption-discards-credited.md)
- **Fingerprint:** `dab5a656`

## Status this run

Still **live** at HEAD `93b7ce6`. `setYieldStrategy` still adopts a strategy over a non-empty idle
pool by calling `strategy.deposit(...)` and **discarding** the `creditedPrincipal` return (the
idle-sweep discarded-deposit-return at ~L256-259), leaving `poolInfo.totalStaked` at full nominal
value while the strategy books only the haircut amount. The resulting `totalStaked > principalOf`
desync is paid silently by the last withdrawer.

**story-008 did NOT fix this.** story-008 added an underwater guard to `setYieldStrategy`, but that
guard only inspects the **OLD** strategy. First adoption from an idle pool has **no old strategy**, so
the guard does not engage and the discarded-credit desync is wholly unguarded. story-008/009 did not
touch the idle-sweep deposit-return discard. (story-008 instead fixes the separate underwater in-place
swap of M-06 `dbdc3ac9`; story-009 introduced the PoolState enum + `finalizeAndReset` revival — neither
addresses this healthy-pool adoption-haircut path.)

> **Distinct from M-06 (`dbdc3ac9`, acknowledged) and the new M-07 (`969722dc`):** M-01 is the
> **healthy-pool** adoption-haircut desync (discarded deposit-credit return over a non-empty idle
> pool). M-06/M-07 are the **underwater-swap** family (under-recovering drain + stale `totalStaked`
> re-arms the withdraw block). Same function, different root cause; separate fingerprints.

Not re-reported with a full submission to avoid duplicating an already-submitted ledger Medium; this
stub is the visibility pointer. See the
[original report](../../../stable-staker-06/submissions/M-01-idle-pool-adoption-discards-credited.md)
for the full description, impact, attack path, PoC (`workspace/stable-staker/test/PoC_M01_AdoptionHaircut.t.sol`),
and recommendation.
