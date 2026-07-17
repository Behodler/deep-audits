# [CARRYOVER] V3-L-15 — MigratorV2V3 lacks a self-pull forwarder: PhlimboV3-side unclaimable bank owned by the migrator is stranded, owner-recoverable only

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phlimbo-ea`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/MigratorV2V3.sol` (`migrate/seedUsers`)
- **First seen:** phlimbo-ea-10  ·  **Still present as of:** phlimbo-ea-11
- **Original report:** [reports/phlimbo-ea-10/audit/findings/low/V3-L-15-migrator-banked-funds-stranded.json](../../../phlimbo-ea-10/audit/findings/low/V3-L-15-migrator-banked-funds-stranded.json)
- **Fingerprint:** `166e6393…`

## Run-11 notice — recommendation widening proposed (no status change)

> **PROPOSAL ONLY — NOT APPLIED.**

### ⚠ CRITICAL FIX NOTE — fixing this entry as written does NOT fix V3-L-16

> V3-L-15's forwarder **as written** (*“calls `claimUnclaimableStable/Promo`”*) closes the **stable**
> and **promo** banks and would leave the **phUSD** bank **stranded** — an **incomplete fix that reads
> as done**, the failure mode ranked second only to a regression.

**Proposed widening:** extend the recommendation to **also** cover `claimUnclaimablePhUSD`.
**V3-L-16** (new in run-11) extends the same structural hole to a third asset.

**Do NOT collapse** with V3-L-16: this entry's Low rests on *“value is NOT lost (owner
`emergencyTransfer` sweeps it)”*, which is **token-specific and provably false** for the un-minted
phUSD bank — PoC'd: the bank **survives** `emergencyTransfer` untouched (see **V3-L-17**).

Do not close V3-L-15 as complete while V3-L-16 remains live.

---

See the original report for the full description, impact, attack path, PoC, and recommendation.
