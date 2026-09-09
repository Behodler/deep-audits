# [CARRYOVER] M-01 — Idle-pool strategy adoption discards `strategy.deposit` creditedPrincipal (last-withdrawer FCFS shortfall)

> **This is a carryover stub, not new analysis.** This finding was reported and
> submitted in a prior run and is **still open** (not fixed, not triaged). It is
> reproduced here so it is not lost between runs. Triage it with `/ledger stable-staker`.

- **Severity:** Medium
- **Status:** open (still-open; re-confirmed LIVE this run)
- **Location:** `src/StableStaker.sol` — `setYieldStrategy` adoption sweep (~L213-216), `_routeDeposit` (~L656-662)
- **First seen:** stable-staker-06  ·  **Still present as of:** stable-staker-07 (HEAD `7e9ef80`)
- **Original report:** [reports/stable-staker/06/submissions/M-01-idle-pool-adoption-discards-credited.md](../../../06/submissions/M-01-idle-pool-adoption-discards-credited.md)
- **Fingerprint:** `dab5a656`

## Status this run

Re-confirmed **LIVE** at HEAD `7e9ef80` with a passing proof of concept:
`workspace/stable-staker/test/PoC_M01_AdoptionHaircut.t.sol` (demonstrates A = 100 deposited /
B = 98 booked / **2.0 shortfall** when a haircutting strategy is adopted over a populated idle pool).

**No fix has landed.** The finding is **not** re-reported with a full submission this run to avoid a
duplicate submission of an already-submitted ledger Medium; this stub is the visibility pointer.

See the [original report](../../../06/submissions/M-01-idle-pool-adoption-discards-credited.md)
for the full description, impact, attack path, PoC, and recommendation.
