# [CARRYOVER] V3-F-02 — FAITHFULNESS: PhlimboV3 "the flush must never brick" invariant undermined by unchecked abi.decode (story-022)

> **This is a carryover stub, not new analysis.** This finding was reported in a prior run and is
> **still open** (not fixed, not triaged). It is reproduced here so it is not lost between runs.
> Triage it with `/ledger phlimbo-ea`.

- **Severity:** Low (faithfulness — Law 2; routed to spec-conformance, **not** the QA bundle)
- **Status:** open (still-open — **re-verified STILL ACCURATE** at `bf42c12`)
- **Location:** `src/PhlimboV3.sol#L812-L820` (`batchClaim` / `_tryTransfer`) — **line range updated, see below**
- **First seen:** phlimbo-ea-07 · **Still present as of:** phlimbo-ea-08
- **Original report:** [reports/phlimbo-ea-07/audit/submissions/spec-conformance.md](../../../../phlimbo-ea-07/audit/submissions/spec-conformance.md)
- **Fingerprint:** `6027f256…`

## Re-verified this run — the premise did NOT shift

story-024 rewrote three comment blocks in this file, so the premise was **re-read against the
current code rather than assumed**. All three rewrites were about the `accPromoPerShare` freeze
(header §2(b), `accPromoPerShare` state-var docstring, `beginFlush` `@dev`). **None of them
touched this finding's premise.**

- **Cited invariant text — verbatim intact** at `src/PhlimboV3.sol:427`:
  > "banked into `unclaimablePromo` — **the flush must never brick**."
- **Cited code — behaviourally identical** at `src/PhlimboV3.sol:818-820`: the unchecked
  `abi.decode` with no length check **survives**. The only delta in the range is `forge fmt`
  joining a two-line statement into one.

**The deviation holds exactly as originally described.**

## Line range updated: 816 → 812

`lineStart` moves **816 → 812** so the range includes the **NatSpec block start**. This finding is
**doc-vs-code**, so the range must cover the doc half of the deviation, not just the code half.
`lineEnd` is unchanged at 820.

## Relationship to siblings (not double-counted)

- **V3-L-02** (open, also carried over) — the **security twin**; owns this contract's DoS severity.
- **F-08-01** (new this run) — the **replication of the same class into `src/MigratorV2V3.sol`** by
  `story-025`, which copied the helper while this defect was live and open, then **upgraded the
  prose to a stronger guarantee than the helper can honour**.

See the original report for the full description and recommendation.
