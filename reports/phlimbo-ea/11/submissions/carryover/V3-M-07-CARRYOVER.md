# [CARRYOVER] V3-M-07 — PhlimboV3._claimRewards phUSD mint leg (:863) un-wrapped freezes principal on mint-authorization revocation

> **⚠ STATUS ANOMALY — a `wont-fix` that got fixed anyway.** This is a carryover stub,
> not new analysis. `wont-fix` entries are **not** normally stubbed; this one is, by
> exception, because run-11 found the owner **implemented its recommendation verbatim
> one day after triaging it `wont-fix`**. It carries an unapplied `fixed` proposal and
> must stay visible until a human acts. Triage it with `/ledger phlimbo-ea`.

- **Severity:** Medium
- **Status:** wont-fix (STATUS ANOMALY — unapplied `fixed` proposal, see below)
- **Location:** `src/PhlimboV3.sol#L863` (`_claimRewards`)
- **First seen:** phlimbo-ea-10  ·  **Still present as of:** phlimbo-ea-11
- **Original report:** [reports/phlimbo-ea/10/audit/findings/medium/V3-M-07-phUSD-mint-leg-unwrapped-freezes-principal.json](../../../10/audit/findings/medium/V3-M-07-phUSD-mint-leg-unwrapped-freezes-principal.json)
- **Fingerprint:** `27e83ab2…`

## Run-11 notice — STATUS ANOMALY + unapplied `fixed` proposal

> **PROPOSAL ONLY — NOT APPLIED.** `wont-fix` is human-set and requires a human to move.

**What happened:** V3-M-07 was triaged WONT-FIX by a human on 2026-07-16 under Law-3 owner-trust reasoning. story-031 (e04136d, 2026-07-17) implements V3-M-07's recommendation VERBATIM ('Wrap the phUSD.mint leg at :863 in the same _tryTransfer+bank pattern as the stable (:876) and promo (:902) legs') -- the owner fixed a finding they had declined to fix, ONE DAY LATER.

**Why it matters:** The code is correct and this is a GOOD outcome. The hazard is procedural: wont-fix entries are NOT normally rescanned for fix verification, so a wont-fix silently becoming fixed is a ledger-reconciliation blind spot. This run detected it ONLY because it was diff-anchored on story-031 and V3-M-07 sits in the diff. Had story-031 touched a different file, the ledger would now carry a permanently stale wont-fix on code that no longer has the defect.

Run-11 proposes **wont-fix → fixed** at `e04136d`, on 3 independent
confirmations (PoC replay no longer reproduces while compiling cleanly; the described condition
is mutation M1, absent at HEAD; new suite 5/5, full suite 365/365).

Apply with:

```
/ledger phlimbo-ea fixed 27e83ab27be4abb142f259f554a61142a592989b180054d1bd3c9dde1904d5c8
```

### The standing run-10 triage question is now CLOSED

> Is the phUSD/Flax mint authority the same trusted entity as PhlimboV3's owner, AND is revokeAllMintPrivileges() expected to be short-lived? If YES to both -> Low is defensible (self-inflicted, self-cured freeze). If the Flax authority is a separate ecosystem operator (as the mutable-dependency structure suggests) or the freeze is unbounded -> Medium is correct. The user can finalize via /ledger phlimbo-ea.

**Answered — SAME PARTY**, from executed mainnet broadcast receipts: one EOA
(`0xcad1a786…`) successfully calls `setMinter` on phUSD (`onlyOwner` on FlaxToken) **and**
`emergencyTransfer`/`setMigrator`/`setPauser` on Phlimbo, same run, all receipts `0x1`. This
**closes the question and vindicates the owner's wont-fix reasoning** — the *“YES to both”*
branch is taken, under which the Low/self-cured framing was defensible. The entry is proposed
`fixed` on separate grounds: the code was fixed anyway. Residual: PhlimboV3 is undeployed, so
same-owner for V3 is an evidence-backed **projection** → a one-line deploy-time runbook check.
Full evidence on **V3-L-16**.

### Do not over-read this closure

- The fix is COMPLETE for V3-M-07's OWN STATED SCOPE (the mint leg). It does NOT establish the broader 'principal can never freeze' property -- see V3-M-08 (hook leg). Nor does it extend its wont-fix precedent to the migrator leg -- see V3-L-16.
- KEEP STRICTLY SEPARATE from V3-M-05 per this entry's own triageReason: 'Distinct from V3-M-05, whose trigger is an EXTERNAL blocklisted recipient, not an owner action -- do not conflate or collapse.' Two distinct entries, two distinct triggers, verified INDEPENDENTLY by two separate PoC replays. Apply order does not matter here (unlike run-09's M-04-before-M-01), but the two proposals must NOT be merged into one.

---

See the original report for the full description, impact, attack path, PoC, and recommendation.
