# [CARRYOVER] L-04 — setAsideBufferSize persists after a client is deauthorized and silently resurrects on re-auth

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger reflax-yield-vault`.

- **Severity:** Low
- **Status:** open (carryover — not re-triggered in run-11)
- **Location:** `src/AYieldStrategy.sol#L183-L259` (`setClient / setSetAsideBuffer`)
- **First seen:** reflax-yield-vault-07  ·  **Still present as of:** reflax-yield-vault-11
- **Original report:** [reports/reflax-yield-vault/07/findings/low/L-04.json](../../../07/findings/low/L-04.json)
- **Fingerprint:** `b51876fec3edfc303682a48c22d8156e763ccc5f5650a91d6bb69972d8395550`

**Carryover note:** L-04 was not re-triggered by any finding in this scan run. The setClient / setSetAsideBuffer interaction was not in the changed-files scope for this run (story-043 focused on ERC4626MarketYieldStrategy.sol conservative-crediting; story-044 changes need verification). None of the 22 deduped findings address the setAsideBufferSize persistence after deauth. Last confirmed open at run-07. Use `/recheck reflax-yield-vault L-04` if targeted verification is needed.

See the original report for the full description, impact, attack path, and recommendation.
