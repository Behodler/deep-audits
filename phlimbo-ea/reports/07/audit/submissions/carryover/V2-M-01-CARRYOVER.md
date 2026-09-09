# [CARRYOVER] V2-M-01 — MigratorV1V2 strict-equality balance precondition lets any third party brick the chunkable migration with 1 wei

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phlimbo-ea`.

- **Severity:** Low (contract-level Medium retained for any redeploy/reuse)
- **Status:** open (still-open)
- **Location:** `src/MigratorV1V2.sol#L155-L239` (`settleDebt` / `migrateDeposits`)
- **First seen:** phlimbo-ea-06  ·  **Still present as of:** phlimbo-ea-07
- **Original report:** none (V2-M-01 has no standalone report; see ledger entry and `reports/phlimbo-ea/06/` V2 audit)
- **Fingerprint:** `e11518b645cf2c6d630a6cf5e24830d4b08b4d31d86cd8400ee4d71f05a46f73`

**Why it re-surfaces this run:** the phlimbo-ea-07 scan (V3 subsystem — `PhlimboV3.sol`,
`MigratorV2V3.sol`) strict-fingerprint-matched this OPEN ledger entry on the **unchanged, retired**
`src/MigratorV1V2.sol`. It is not re-discovered and not re-analyzed. `lastSeenRun` bumped to
`phlimbo-ea-07`; no new report generated.

**Deployment caveat (from the ledger):** the on-chain V1→V2 migration is complete (iterators at
`-1`), so the 1-wei strict-`==` DoS surface is **closed for this deployment** — informational here.
It remains a contract-level Medium for any redeployment/reuse of MigratorV1V2 (fix: use `>=` as the
lower-bound balance check).

See the ledger entry (`reports/phlimbo-ea/ledger.json`, label `V2-M-01`) for the full description,
impact, and recommendation.
