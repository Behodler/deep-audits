# [CARRYOVER] V3-M-02 — PhlimboV3 emergencyTransfer leaves promo bookkeeping stale → resume bricks stake/withdraw/claim (owner footgun)

> **This is a carryover stub, not new analysis.** This finding was reported in a prior run and is
> **still open** (not fixed, not triaged). It is reproduced here so it is not lost between runs.
> Triage it with `/ledger phlimbo-ea`.

- **Severity:** Medium **(unchanged — the widening below does NOT move the severity)**
- **Status:** open (still-open, re-detected this run as `08-07`)
- **Location:** `src/PhlimboV3.sol#L307-L325` (`emergencyTransfer`)
- **First seen:** phlimbo-ea-07 · **Still present as of:** phlimbo-ea-08
- **Original report:** [reports/phlimbo-ea-07/audit/submissions/M-02-emergencytransfer-stale-promo-brick.md](../../../../phlimbo-ea-07/audit/submissions/M-02-emergencytransfer-stale-promo-brick.md)
- **Fingerprint:** `d3a5b3ec…`

---

## ⚠ WIDENING — the original entry is FALSIFIED in the direction that UNDERSTATES harm

**Read this before acting on the original report.** The prior-run text is not merely incomplete;
one of its central claims is **wrong in the dangerous direction**.

### What the original entry says

The entry reads **"recoverable, no fund loss"** and names the sequence
**`beginFlush → batchClaim → finalizePromotion`** as **THE RECOVERY**.

### What is actually true

**A PoC shows that exact sequence DESTROYS the whole staker base's promo — 500e18 of 1000e18 —
while reporting success.**

The "recovery" the entry recommends is the **destruction path**.

### ⚠ INVERTED RECOVERY ADVICE — this replaces the original's guidance

| Action | Outcome |
| --- | --- |
| **Return the tokens FIRST**, then rotate | **FULL RECOVERY** |
| **Rotate FIRST** (`beginFlush → batchClaim → finalizePromotion`) | **IRREVERSIBLE DESTRUCTION** of staker promo |

**Do not follow the original report's recovery sequence.** Return tokens before any rotation.

### Face (a) vs face (b) — weight them correctly

- **Face (a) — promo leg:** PoC'd. **Independently defused** by the `:448` fix that closes
  `08-02` / run-label **M-01** (the unconditional `promoDebt` alignment). One fix, two Mediums
  defused. *A fix aimed at `finalizePromotion` L487 MISSES entirely* — once the debt is aligned,
  `pendingPromo` reads 0 permanently and `abortFlush` does not undo it.
- **Face (b) — stable leg:** **NOT PoC'd. ZERO severity weight.** Routed to Tier-3 for the next
  run rather than credited here. Do not treat face (b) as established.

### Why the ceiling stays Medium

The widening is real and PoC'd, but the **entry point remains a deliberate owner emergency
action with no unprivileged trigger**. That holds the ceiling at Medium. The ledger **text** was
corrected; the **severity** was not moved.

---

## ⚠ Fingerprint caveat (scheme defect, not a finding about this contract)

This run's re-detection (`08-07`) hashes to **`818884de`**, **not** this entry's **`d3a5b3ec`** —
because `rootCauseClass` is free text and the widened wording drifted. **The semantic carryover
is correct and accepted**; the entry identity is **preserved as `d3a5b3ec`** and was deliberately
**not** re-fingerprinted (re-fingerprinting would fork the entry).

**The scheme defect this exposes:** a real **REGRESSION could be MISSED** if a `fixed` entry's
wording drifts. Recorded in the run metadata for the human.

---

See the original report for the full description, impact, attack path, PoC, and recommendation —
**subject to the inverted recovery advice above.**
