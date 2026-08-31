# [CARRYOVER] V3-M-03 — PhlimboV3 batchClaim aligns promoDebt BEFORE the transfer: any transfer failure destroys a staker's EARNED promo, and finalizePromotion sweeps the bank to leftoverRecipient (no claimUnclaimable analogue)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phlimbo-ea`.

- **Severity:** Medium
- **Status:** open (still-open)
- **Location:** `src/PhlimboV3.sol#L448-L487` (`batchClaim/finalizePromotion`)
- **First seen:** phlimbo-ea-08  ·  **Still present as of:** phlimbo-ea-11
- **Original report:** [reports/phlimbo-ea/08/audit/submissions/M-01-submission.md](../../../08/audit/submissions/M-01-submission.md)
- **Fingerprint:** `01953624…`

## Run-11 notice — routed to manual review, deliberately NOT adjudicated

> **NO PROPOSAL.** Remains `open`. Routed to `audit/manual-review.json` → **MR-11-003** for human
> adjudication.

**Premise question (evidence for the human, not an adjudication):** this entry's title asserts
*“no `claimUnclaimable` analogue”* exists, but `claimUnclaimablePromo(address token)` **is** present
at `:596`, and `finalizePromotion` **does** reserve the bank from its sweep at `:552-556` (verified
in source this run, plus an explicit NOTE that the bank is deliberately not cleared). That part of
the premise **may be stale** (likely closed by story-027).

**Why not adjudicated here:** the root cause (debt-aligned-before-transfer) is **outside this diff's
scope**, and the entry carries no description field to check the claim against. This is a re-read
target for a human or a scoped `/recheck`, not a dedup decision.

**Do not auto-close.** The entry's `interimOperationalRule` (*“NEVER ROTATE A SHORT PROMO BANK”*) is
explicitly marked *“KEEP THE RULE UNTIL A HUMAN APPLIES THIS CLOSURE”*. Its own `fixNote` warns a fix
aimed at `:487` **misses entirely** — the target is the `:448` alignment. Its **unapplied run-09 note
forecloses** reading the surviving `:448` alignment as an incomplete fix.

**Unaffected by this range:** `batchClaim` is untouched by story-031 — it touches only promo state and
never reads/writes `unclaimablePhUSDOf`, `totalUnclaimablePhUSD` or any stable field. Neither worsened
nor mitigated.

---

See the original report for the full description, impact, attack path, PoC, and recommendation.
