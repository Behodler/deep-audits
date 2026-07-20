# Spec-Conformance Report (Law-2 Faithfulness) — yield-claim-nft, run 18

**Project:** yield-claim-nft
**Run:** yield-claim-nft-18
**Commit:** e4de393
**Story under review this run:** `[story-045]` — PromotionUniV2_Eth rework (commit a7ab9db)

---

## Purpose (Law-2 framing)

This report is the **faithfulness / spec-conformance** channel and is **separate from the QA
bundle**. Under the Three-Law hierarchy, faithfulness to stories is **Law 2** — features must do
what the `[story-NNN]` they derive from says — and it is tracked in its own visible channel so a
story deviation is never lost in gas/style noise. A story deviation with asset/value/availability
impact would ALSO carry an H/M label and its own report; the records below carry no such impact
(the headline record is a fully-FAITHFUL confirmation), so they live here as informational
faithfulness records only.

Consistent with prior-run practice (F-01-043 in run-15, F-01-044 in run-17), a **fully-faithful
story is still recorded here** — the faithfulness channel documents continuity, not just
deviations. Omitting a clean pass would erase the audit trail that the story was actually
verified.

This run contains **one new faithfulness record** (F-01-045, the headline) and **two carried
references** (F-01-044, F-01-043) that story-045 did not disturb.

---

## F-01-045 — story-045 PromotionUniV2_Eth rework is FULLY FAITHFUL and Law-1 safe (NEW, informational — headline record)

- **Status:** open (informational faithfulness record; NOT a security finding)
- **Contract:** `src/dispatchers/PromotionUniV2_Eth.sol` (`pool`)
- **Story:** `[story-045]` (commit a7ab9db)
- **Fingerprint:** `25212e80…`
- **Verdict:** **FAITHFUL and Law-1 safe** across all 8 intent items.

### Story text

The `[story-045]` commit (a7ab9db) directs the PromotionUniV2_Eth rework to a
**"60/30/10 split, burn-half phUSD, WBTC insurer reserve."**

### Behavior vs. intent — item-by-item conformance

| # | story-045 intent | Contract evidence | Conforms |
|---|---|---|---|
| 1 | **60/30/10 pool split** | split computed at `PromotionUniV2_Eth.sol#L383-L385` | ✅ |
| 2 | **Burn half of the pooled phUSD leg** | half-burn at `#L395-L396` | ✅ |
| 3 | **WBTC insurer-reserve leg** | reserve wiring at `#L108`, `#L162`, `#L267`, `#L275` | ✅ |
| 4 | **Settable `_legC` path** | insurer/reserve leg settable | ✅ |
| 5 | **Insurer role** | insurer role present and enforced on the reserve leg | ✅ |
| 6 | **Consolidated `Pooled` event** | single consolidated `Pooled` emission | ✅ |
| 7 | **`rescueERC20` WBTC-exclusion** | WBTC excluded from rescue at `#L521` (reserve cannot be swept out via rescue) | ✅ |
| 8 | **Donation-split computed on gross** | donation-split taken on the gross amount, not net | ✅ |

All eight items implement the story action exactly as written. There is **no story deviation** and
**no Law-1 concern** — the reworked flow is backing-accretive and intra-protocol, with no theft or
drain vector introduced by the rework.

### Empirical clearance (coverage caveat CLEARED)

The Tier-3 **fork run executed 70/70 pass** and all four rework invariants — **60/30/10 split**,
**burn-half**, **WBTC-reserve**, and **LP-accrual** — were **empirically confirmed on a mainnet
fork** (block 25,550,000). The faithfulness verdict therefore rests on direct on-chain-fork
observation, not static reasoning alone.

> **Separate coverage note (not a faithfulness defect):** the run-16 **stateful-fuzz** harness is
> stale — it calls the pre-story-045 5-arg `pool()` and no longer compiles against the 6-arg
> signature, so Medusa/Foundry invariant *campaigns* do not exercise the reworked flow. That gap is
> tracked as **Q-17** in the QA bundle. It does not weaken this record: the deterministic fork unit
> tests provide direct coverage of the same invariants this run.

### Faithfulness caveats (carried alongside the FAITHFUL verdict)

**Caveat 1 — carried footgun (L-13 / F-01-044), UNCHANGED by story-045.**
The whole-balance ETH sweep in `_legB` plus the open `receive()` (Leg B, `#L453`; open
`receive()`, `#L533`) **survives the story-045 rework unchanged**. Story-faithfulness confirms the
rework did not touch that path. Both twins remain **wont-fix** — the owner has affirmatively
declared the whole-balance sweep an intended feature — and the framing is **sweep +
`rescueETH`-front-run**, *not* accidental-send; Tier-3 INV-4 fork-proved the swept value only ever
reaches protocol-owned LP (non-theft). See F-01-044 below and the L-13 carryover stub.

**Caveat 2 — NatSpec under-explains the burn's dual role (cross-ref Q-16).**
The story **action** ("burn half") is faithfully implemented (item 2 above), and the NatSpec's
*justification* — that the burn exists "so pooled values match" — is **correct**, not misleading:
because Leg A is deliberately over-sized to **60%** of capital, burning half of it is **precisely**
what pulls the pooled phUSD from 60% down to the ~30% that value-matches the ~30% pooled-promotion
leg, so the burn genuinely **is** part of the value-match mechanism. What the NatSpec **omits** is
that this same burn is simultaneously an intentional **~30%-of-every-`pool()`-capital permanent
deflationary spend** that produces zero LP. The **story is faithful; the in-code rationale is
correct but under-explains** (it documents the value-match half of the burn's role and is silent on
the deflationary-spend half). This is recorded here in the Law-2 channel for visibility, and is the
basis for **Q-16** in the QA bundle — retained so a maintainer, reading only the value-match half,
does not delete or resize the burn as "redundant to the leg sizing" (which would break both the
value-match and the intended deflationary economics). Fork-confirmed: 5,000e6 USDC → 1,359e18 phUSD
burned, backing-accretive and Law-1 clean.

### Disposition

**KEEP visible** as a faithfulness / spec-conformance record (informational), consistent with
F-01-043 / F-01-044. **Do NOT** promote to a security finding; **do NOT** bury.

---

## F-01-044 — PromotionUniV2_Eth `_legB` whole-balance ETH sweep (CARRIED reference, wont-fix)

- **Status:** wont-fix (intended-by-design; under-specification basis closed by owner 2026-07-18)
- **Contract:** `src/dispatchers/PromotionUniV2_Eth.sol` (`_legB`)
- **Story:** `[story-044]`
- **Fingerprint:** `3e638eb9…`
- **Cross-ref:** L-13 (security/footgun twin, also wont-fix)
- **Original report:** [reports/yield-claim-nft-17/submissions/spec-conformance.md](../../yield-claim-nft-17/submissions/spec-conformance.md)

**Story-045 impact:** UNCHANGED. This faithfulness twin of the L-13 whole-balance ETH sweep is the
spec-conformance record for the same behavior flagged in Caveat 1 above. Story-faithfulness confirms
the story-045 rework did **not** alter the `_legB` whole-balance sweep or the open `receive()`.
Verdict from run-17 stands: **FAITHFUL-with-nuance** — a deliberate, tested (post-pool balance == 0),
intended-but-was-under-specified whole-balance sweep; the owner has since declared the sweep the
intended spec, closing the under-specification basis. No Law-1 escalation (Tier-3 INV-4 HELD: value
never reaches a third party). Carryover stub: `submissions/carryover/F-01-044-CARRYOVER.md`.

---

## F-01-043 — story-043 debt-realisation / release decouple (CARRIED reference, open informational)

- **Status:** open (informational faithfulness record; NOT a security Medium)
- **Contract:** `src/dispatchers/NudgeRatchetDelayRelease.sol` (`_dispatch` / `release`)
- **Story:** `[story-043]`
- **Fingerprint:** `6753c76b…`
- **Original report:** [reports/yield-claim-nft-15/submissions/spec-conformance.md](../../yield-claim-nft-15/submissions/spec-conformance.md)

**Story-045 impact:** NONE — story-043 is unrelated to the PromotionUniV2_Eth rework and its
contract (`NudgeRatchetDelayRelease.sol`) was **untouched** this run. Carried here purely for
Law-2 continuity. Verdict from run-15 stands: story-043 is a **FAITHFUL** implementation across all
six acceptance criteria; it intentionally decouples phUSD-debt-realisation (at dispatch) from
USDC-release (later), opening an admin-rate-controlled under-funded-sink window whose Law-1 security
escalation was econ-resolved **out-of-scope** under the suppressed external-backing model
(DEDUP-001). The faithfulness record remains visible (Law-1: parked in a visible channel, never
silently dropped); it is not promoted to a security Medium.

---

## Summary

| Record | Story | Verdict | Status | New/Carried |
|---|---|---|---|---|
| **F-01-045** | story-045 | **FULLY FAITHFUL** across 8 intent items; Law-1 safe; fork 70/70 | open (info) | NEW (headline) |
| F-01-044 | story-044 | FAITHFUL-with-nuance (ETH-sweep, owner-intended) | wont-fix | carried (unchanged) |
| F-01-043 | story-043 | FAITHFUL across 6 ACs (untouched this run) | open (info) | carried (untouched) |

**Two caveats attach to the headline FAITHFUL verdict:** (1) the carried L-13 / F-01-044 ETH-sweep
footgun survives story-045 unchanged (wont-fix); (2) the burn-half NatSpec rationale is correct on
value-matching but under-explains — it omits that the same burn is also a ~30%-of-capital
deflationary spend — story-action faithful, in-code justification accurate-but-incomplete — tracked
as **Q-16** in the QA bundle.
