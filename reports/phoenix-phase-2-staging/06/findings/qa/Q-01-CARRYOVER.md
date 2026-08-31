# [CARRYOVER] Q-01 — StableStaker deployed with `migrator == address(0)`: terminal-migration path is permanently unreachable

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phoenix-phase-2-staging`.

- **Severity:** QA
- **Status:** open (still-open)
- **Entry point:** `dev`
- **Location:** `lib/phoenix-phase-2-staging/script/DeployMocks.s.sol#L654-L685` (`run` / Phase 3.7)
- **First seen:** phoenix-phase-2-staging-05  ·  **Still present as of:** phoenix-phase-2-staging-06 (HEAD `bd2290c`)
- **Original report:** [reports/phoenix-phase-2-staging/05/findings/qa/Q-01-stablestaker-migrator-zero.json](../../../05/findings/qa/Q-01-stablestaker-migrator-zero.json)
- **Fingerprint:** `0b497be32114147aa44ea7328329eaab2f024fd22b3208804fe604b84cca86b3`

STILL-LIVE confirmed @bd2290c: the deploy still wires `migrator == address(0)`, leaving the terminal-migration path permanently unreachable. See the original report for the full description, impact, attack path, and recommendation.
