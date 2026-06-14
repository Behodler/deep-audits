# [CARRYOVER] YS-05 (5c9f1cee) — Leg2 re-deposit haircuts each user's principal (~0.026% DOLA / ~0.016% USDC); intent doc states 1:1 preservation

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phoenix-phase-2-staging`.

- **Severity:** Low
- **Status:** open (still-open)
- **Entry point:** `migrate:ys-swap-leg2`
- **Location:** `lib/stable-staker/src/StableStaker.sol#L616-L638` (`depositFor` / `_routeDeposit`)
- **First seen:** phoenix-phase-2-staging-12  ·  **Still present as of:** phoenix-phase-2-staging-13
- **Re-verified:** STILL-LIVE on fork at e935a05 — unchanged by the stable-staker bump c3ec65b->212a6d2 (getStakersRange / migration-credit semantics unchanged). Magnitude unchanged on fork (~0.006% observed this run, consistent with run-12 ~0.026% DOLA / 0.016% USDC).
- **Original report:** [reports/phoenix-phase-2-staging-12/findings/low/YS-05-leg2-redeposit-haircut.json](../../phoenix-phase-2-staging-12/findings/low/YS-05-leg2-redeposit-haircut.json)
- **Fingerprint:** `5c9f1cee`

See the original report for the full description, impact, attack path, and recommendation.
