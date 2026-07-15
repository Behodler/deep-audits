# [CARRYOVER] V3-F-01 — FAITHFULNESS: MigratorV2V3 documented in-contract recovery path is unreachable while bricked (story-023)

> **This is a carryover stub, not new analysis.** This finding was reported in a prior run and is
> **still open** (not fixed, not triaged). It is reproduced here so it is not lost between runs.
> Triage it with `/ledger phlimbo-ea`.

- **Severity:** Low (faithfulness — Law 2; routed to spec-conformance, **not** the QA bundle)
- **Status:** open — **⚠ CONFLICTED: two agents recommend opposite dispositions. HUMAN DECIDES.**
- **Location:** `src/MigratorV2V3.sol#L114-L229` (`migrate` / `seedUsers`)
- **First seen:** phlimbo-ea-07 · **Still present as of:** phlimbo-ea-08
- **Original report:** [reports/phlimbo-ea-07/audit/submissions/spec-conformance.md](../../../../phlimbo-ea-07/audit/submissions/spec-conformance.md)
- **Fingerprint:** `3f241c3a…`

---

## ⚠ CONFLICT — no recommendation is made. Both positions are recorded verbatim.

This entry is **stubbed as still-open** because **no closure decision was reached**. It is **not**
an assertion that the finding is unresolved.

### Position A — `story-faithfulness`: propose `fixed` @ `ef98cd9`

**Verdict: GENUINELY RESOLVED. This is NOT a comment-only paper-over.** The "rewriting a comment
is not the same as fixing a code deviation" trap was **tested explicitly and does not apply** —
**both sides of the deviation moved**:

- **DOC side:** the false promise — *"As with MigratorV1V2, the operational escape is to exclude
  such addresses from the seed list"* — is **deleted** from the header.
- **CODE side:** F-01's deviation was "doc promises in-contract recovery the code lacks".
  story-025 gave the code **real in-contract recovery** on two axes: (1) `_forward` banking means
  a bad recipient **no longer pins the cursor**, so the straggler-exclusion escape is no longer
  **needed**; (2) **`claimUnclaimable` is an actual in-contract recovery path that did not
  previously exist**. **The doc is now weaker than the code, not stronger.**

The L126 reseed guard (`require(!seeded || migrateIterator == -1, "Pass in progress")`) is
unchanged — but is **no longer load-bearing for F-01**, because the pass no longer gets pinned by
the recipient class F-01 was about.

*Narrow residual, disclosed for honesty:* the `abi.decode` path in **F-08-01** can still pin the
cursor mid-pass, and in that state the reseed guard still blocks reseeding **and** the rewritten
doc no longer mentions any escape at all. **That residual is carried by F-08-01 (new entry), not
by F-01** — F-01's specific cited deviation is closed.

### Position B — `contract-profiler` + `sanitizer`: do NOT close

**F-01 is COUPLED — it is only safe to close once `08-03` and `08-04` land.** Closing a
**"false recovery promise"** entry **while three brick paths remain** re-creates **the exact
reads-as-done shape** the entry exists to prevent. An incomplete fix that reads as done is ranked
second only to a regression.

---

**Both positions turn on the same facts and disagree on disposition, not evidence.** Per the
absolute rule for this run, **no status change was applied**. See the original report for the
full description and recommendation.
