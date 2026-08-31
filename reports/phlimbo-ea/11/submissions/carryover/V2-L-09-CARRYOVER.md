# [CARRYOVER] V2-L-09 — Reverting/gas-heavy IPhlimboHook bricks stake/withdraw/claim (no try/catch); pauseWithdraw is hook-exempt

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phlimbo-ea`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/PhlimboV2.sol#L353-L429` (`stake/withdraw/claim`)
- **First seen:** phlimbo-ea-06  ·  **Still present as of:** phlimbo-ea-11
- **Original report:** [reports/phlimbo-ea/06/audit/submissions/qa-report.md](../../../06/audit/submissions/qa-report.md)
  - _Pointer resolved at run-11 by verified label match; no `reportPath` was recorded on this entry._
- **Fingerprint:** `08da5bba…`

## Run-11 notice — unapplied severity re-weigh proposal (Low → **Medium**)

> **PROPOSAL ONLY — NOT APPLIED.** Re-weighing an existing open entry requires human triage.

**UNDERSTATEMENT FOUND.** V2-L-09 and the new **V3-M-08** are the *same mechanism*. The basis for
rating V3 higher was that story-030 deleted V2's `pauseWithdraw` escape — but V2's `pauseWithdraw`
is `whenPaused` (`PhlimboV2.sol:280`) and `pause()` is pauser-gated (`:270`), so **V2 users could
never self-rescue from a reverting hook either**. The V2/V3 delta is *“two privileged remedies vs
one”*, not *“escape vs none”*. Consistency forces either V3-M-08 → Low or V2-L-09 → Medium;
**V3-M-05** (an owner-ratified Medium for freezing *one* staker's principal on an external trigger)
settles it upward — a pool-wide freeze is strictly worse.

**Materiality — not academic:** **PhlimboV2 is LIVE ON MAINNET** at `0x6084a02c…2aee0` with real
stakers **currently being migrated**. This entry is `open` and was **never human-triaged down**, so
no triage decision is being overridden.

**Mitigating fact a human may weigh:** V2 does retain `pauseWithdraw`, so it has a second
pauser-held remedy V3 lacks. That is a real if narrow advantage — which is why this is flagged for
re-weigh rather than asserted as a reclass.

### This entry's V3-instance rationale is now verbatim FALSE

> V2-L-09's rationale *“pauseWithdraw is hook-exempt so a principal exit survives”* is **verbatim
> FALSE for PhlimboV3** — story-030 deleted the function (**zero occurrences** in `PhlimboV3.sol` at
> `f279c62`, full-file untruncated grep). It remains **TRUE for PhlimboV2 itself**, which retains it.
> If PhlimboV2 is ever stripped of `pauseWithdraw`, re-weigh again on the same reasoning.

**Do NOT collapse** V3-M-08 into this entry: same mechanism, different contracts, different
fingerprints. Note the deduplicator cautioned against inheriting V3-M-08's Medium; the
severity-auditor's basis is **not** V3-M-08 but V3-M-05's independent owner-ratified Medium — the
two stages agree the entries must not be collapsed.

---

See the original report for the full description, impact, attack path, PoC, and recommendation.
