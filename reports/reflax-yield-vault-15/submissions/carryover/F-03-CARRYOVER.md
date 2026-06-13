# [CARRYOVER] F-03 — Integration assumption for deferred stable-staker M-05 wiring of relinquishPrincipal (pay-out-then-relinquish / no-double-credit)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger reflax-yield-vault`.

- **Severity:** Faithfulness (spec-conformance channel; gates a **Medium re-evaluation**)
- **Status:** open (still-open)
- **Location:** `src/AYieldStrategy.sol#L638` (`relinquishPrincipal`)
- **First seen:** reflax-yield-vault-14  ·  **Still present as of:** reflax-yield-vault-15
- **Original report:** [reports/reflax-yield-vault-14/findings/faithfulness/F-03-stable-staker-m05-integration-assumption.json](../../../reflax-yield-vault-14/findings/faithfulness/F-03-stable-staker-m05-integration-assumption.json)
- **Fingerprint:** `52f9b84a…`

**Annotated this run (FAITH-15-007 / DEDUP-15-005):** F-03's recorded premise "no callsite at this commit" is now STALE on the consumer side — `lib/stable-staker/src/StableStaker.sol:786` (`_routeExit` underwater path) now calls `strategy.relinquishPrincipal(token, amount)`. story-047 is a different leg of the same M-05 program (it funds the consumer-side buffer) and neither satisfies nor violates F-03's invariant. Whether the live wiring honors the pay-out-then-relinquish / no-double-credit invariant is a stable-staker-side conformance question: **F-03's Medium re-evaluation gate fires in the next stable-staker regression run**, together with the DEDUP-15-005 buffer-inflow attribution check and FAITH-15-006's rescue-footgun note. Status unchanged (open).

See the original report (and run-14's spec-conformance.md) for the full integration invariant, impact, and recommendation.
