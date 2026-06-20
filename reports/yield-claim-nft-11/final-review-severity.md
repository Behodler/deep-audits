# Final Severity Review — yield-claim-nft run-11 (story-035, NudgeRatchet @ b8322ee)

Independent second-opinion severity audit. C4 criteria applied strictly:

- **High** = assets stolen/lost/compromised via a valid attack path, no hypotheticals.
- **Medium** = no direct asset risk, but protocol function/availability impaired, OR a value leak with stated assumptions / external requirements.
- **Low/QA** = state-handling, spec deviation, centralization; no security impact.

Both findings were verified against source: `NudgeRatchetMintDebtHook.sol:112-118` / `pull()` L123-130, `NudgeRatchet.sol:38,59-61`, `ATokenDispatcherV2.sol:50-52,118-126`, and the DEDUP-001 / phUSD-backing context (run-10 notes). The PoCs are coherent with the code.

---

## M-03 — Decimal under-mint (~1e12x) — VERDICT: CONFIRM MEDIUM (confidence: high)

**Claimed: Medium. Assessed: Medium. Agreement: yes.**

### Not High (overstatement check passes)
- **No direct asset theft or loss.** The error direction is an **under**-mint of phUSD reward-debt. No funds leave a vault, no user balance is taken, no unbacked phUSD is created. The USDC continues to flow correctly to `batchMinter`; only the *downstream phUSD reward accrual* for the owner-controlled `recipient` is miscalculated low.
- The "value lost" is **owner-driven reward accrual**: `recipient` is owner-set (`setRecipient`, owner-only) and `pull()` is owner/recipient-only. Nobody outside the trust boundary is shorted — the protocol owner is shorting its own reward ledger. There is no attacker, no external victim, no executable extraction. This is squarely outside High.
- The High *over*-mint counterpart (unbacked phUSD) is correctly **not** claimed here and remains the suppressed DEDUP-001 concern. The `MANDATORY-RE-AUDIT-ON-FIX` latent-hazard flag is the right disposition — flagging the sign-flip risk without inflating the current finding.

### Not Low (under-statement check passes)
- This is **not** a cosmetic spec deviation. The mint-debt accounting is the *entire purpose* of `NudgeRatchetMintDebtHook` (story-035). A ~1e12x scale error renders that function economically inert: `$1M` of dispatched USDC accrues `0.000001 phUSD`, and sub-~`100/ratio` USDC dispatches hit the `if (added == 0) return;` no-op outright. The protocol function the contract exists to provide does not work.
- C4 Medium explicitly covers "protocol function/availability impacted." A core accounting feature producing results 12 orders of magnitude wrong is a function-impairment, not a state-handling nit. The story-faithfulness deviation (F-02-035) corroborates: the implemented behaviour does not match the story it derives from.

### Skeptic's note (does not change the label)
The submission's phrase **"silent *total* no-op"** is slightly overstated. The `added == 0` hard no-op only triggers for very small amounts (`amount * ratio < 100`); for realistic/large amounts the debt is non-zero but ~1e12x too small (the PoC's `$1M → 1e12 wei` case proves a non-zero-but-dust result, not a literal zero). The *economic* conclusion (feature is effectively broken / massively under-credits) is sound, but the report should say "rounds to a no-op for small amounts and to economically negligible dust for large amounts" rather than implying a universal zero. Recommend tightening the wording; severity is unaffected.

**Verdict: Medium is correct.** Protocol-function-impaired, fails safe on solvency, no asset risk. Do not escalate to High (no theft/unbacked-mint), do not drop to Low (core feature defeated, not a spec nit).

---

## M-04 — Unwired-dispatch zero-debt footgun — VERDICT: CONFIRM MEDIUM (confidence: medium)

**Claimed: Medium. Assessed: Medium. Agreement: yes — but it is a genuine borderline Medium/Low, held at Medium for specific reasons below.**

### Not High
- Recoverable going forward (wire the hook), fails safe on solvency (no unbacked phUSD), no theft/drain, and gated behind an operator action. No valid High attack path. Correctly not claimed High.

### The Medium-vs-Low tension (the real question)
The case *for Low*: this requires an **external precondition** (owner deploys the debt hook but never calls `setHook`). Conditionality on an owner step is exactly the kind of thing C4 often docks to Low, and the Three-Law hierarchy normally treats owner misconfiguration as out of scope (Law-3) unless it is a *non-obvious* footgun.

The case *for Medium* — and why it holds:
1. **C4 Medium explicitly permits "value leak with stated assumptions and external requirements."** This finding is precisely that shape: a stated assumption (hook unwired) producing a one-directional value leak (USDC ships, debt never accrues, no backfill). It is the textbook Medium-with-external-requirement, not a hypothetical.
2. **The non-obviousness is independently evidenced, not asserted.** The project's *own* integration test (`NudgeRatchet.t.sol:160-182`) exercises this exact path **without** `setHook` and passes green, asserting only the USDC flow. A footgun that the protocol's own test suite fails to catch is, by the Law-3 test ("would a competent non-malicious owner be surprised?"), a genuine in-scope hazard — surprise is demonstrated, not speculated.
3. **Silent + irreversible.** No revert, no event, and no retroactive backfill for the unwired window. A misconfig that screams (reverts) would be Low; one that succeeds silently and cannot be repaired for already-dispatched amounts is materially worse and earns the Medium.

### Why it is *not* a slam-dunk Medium (honest skepticism)
- The leak is bounded entirely by an operator omission that a one-line probe (`dispatch a test amount, assert mintDebt() > 0`) would surface immediately, and the safe-config guidance in the finding itself is trivial. A reviewer who weights "conditional on owner step" heavily could defensibly land this at **Low**. I would not overturn a triage decision that downgraded it to Low on those grounds; but on the documented C4 "value-leak-with-external-requirement + own-test-misses-it + silent + no-backfill" combination, **Medium is the better-supported label**, so I confirm Medium.

**Verdict: Medium (borderline; defensible Low floor).** The silent/no-revert/no-backfill nature plus the own-test-blind-spot evidence keep it above a pure spec-deviation Low. Hold at Medium; if the report needs to trim Medium count, this is the single most reasonable downgrade candidate of the two — but it is *correctly* Medium as written.

---

## Summary

| Finding | Claimed | Assessed | Agreement | Confidence | Note |
|---------|---------|----------|-----------|------------|------|
| M-03 | Medium | **Medium** | yes | high | Protocol-function-impaired under-mint; fails safe; not High (no theft), not Low (core feature defeated). Tighten "total no-op" wording. |
| M-04 | Medium | **Medium** | yes | medium | Value-leak footgun w/ external requirement; silent + no-backfill + own-test-misses-it keep it above Low. Borderline; defensible Low floor. |

Neither finding is overstated. M-03 is a solid Medium. M-04 is a correctly-justified but borderline Medium and is the only plausible downgrade candidate if Medium count must be trimmed. Crucially, **neither should be escalated to High** — both fail safe on solvency, and the High (unbacked-phUSD over-mint) counterpart is correctly left suppressed under DEDUP-001 with M-03 carrying the `MANDATORY-RE-AUDIT-ON-FIX` flag to catch a fix that over-corrects.
