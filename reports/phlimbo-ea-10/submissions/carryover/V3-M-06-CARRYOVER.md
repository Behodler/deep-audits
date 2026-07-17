# [CARRYOVER] V3-M-06 — PhlimboV3 pauseWithdraw skips _updatePhUSDEmissionRate → uncapped phUSD over-emission

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is triaged **fix-pending**. Run-10 re-verification finds it
> **FULLY FIXED** and *proposes* closing it — but `fix-pending` is human-set and
> never auto-closed, so it is reproduced here until a human applies the flip.
> Close it with `/ledger phlimbo-ea fixed efdc3c4f08ee7e371b6d4fb2de6f7a8a527fc938eb863b74fb9d8a68343598bc`.

- **Severity:** Medium
- **Status:** fix-pending (fix owed) — **PROPOSED `fixed` (awaiting human confirmation)**
- **Location:** `src/PhlimboV3.sol#L596-L611` (`pauseWithdraw`)
- **First seen:** phlimbo-ea-09  ·  **Still present as of:** phlimbo-ea-10
- **Original report:** [reports/phlimbo-ea-09/submissions/M-02.md](../../../phlimbo-ea-09/submissions/M-02.md)
- **Fingerprint:** `efdc3c4f…`

**Run-10 re-verification:** story-030 **removed `pauseWithdraw` entirely** at HEAD `e32588d` —
function + `PauseWithdraw` event + interface declaration all gone, zero residual (concurred by
contract-profiler, pattern-matcher, story-faithfulness). This eliminates the missing
`_updatePhUSDEmissionRate` over-emission path at its root. Finding-manager therefore **proposes
`fixed`** (unapplied). On apply, this removal **also moots sibling V3-Q-02** (`93cdca59…`, same
function, leg 1 / missing `_updatePool`) — confirm and close it too, and verify the removal does
not strand stakers who could previously escape during a `beginFlush` pause.

See the original report for the full description, impact, attack path, PoC, and recommendation.
