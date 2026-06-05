# [CARRYOVER] L-01 — slippageToleranceBps default-0 plus setter missing sane cap (missing validation)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger reflax-yield-vault`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L190-L195` (`setSlippageTolerance`)
- **First seen:** reflax-yield-vault-05  ·  **Still present as of:** reflax-yield-vault-08
- **Original report:** [reports/reflax-yield-vault-05/submissions/qa-report.md](../../reflax-yield-vault-05/submissions/qa-report.md)
- **Fingerprint:** `6460e353…`

**Run-08 update (no new finding):** story-043 ("conservative principal crediting")
added a NEW deposit-side haircut, `creditedPrincipal = amount * (MAX_BPS -
slippageToleranceBps) / MAX_BPS` (`_creditedPrincipal` L204-214). The crediting
itself is documented intended design and was suppressed (DEDUP-001; classifier Low,
auditor REFUTED), but it widens this Low's blast radius: the haircut magnitude is
bounded only by the still-missing `slippageToleranceBps` upper cap. Recommend a hard
sane cap (e.g. a few hundred bps) in `setSlippageTolerance` and a deposit-side
`designDecisions` registry entry. Severity/status unchanged.

See the original report for the full description, impact, attack path, and recommendation.
