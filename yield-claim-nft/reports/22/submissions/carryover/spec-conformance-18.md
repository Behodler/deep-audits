# Carryover Spec-Conformance report — originating audit 18 (carried into yield-claim-nft-22)

> **Carryover Spec-Conformance report — audit 18** (pruned copy of `yield-claim-nft/reports/18/submissions/spec-conformance.md`, taken from the run-21 pruned carryover `reports/21/submissions/carryover/spec-conformance-18.md`, re-checked against the ledger at run 22. Faithfulness (Law-2) records belong to the spec-conformance channel, not the QA bundle). Carried at `0fd6bdf` (`0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630`), run 22, branch `master`.
> Retained (still live in the ledger: `open` / `qa-bundled` / `fix-pending`): **F-01-045**.
> Removed as no longer live: **none since run 21**.
> Labels are the originals — gaps in the sequence are removals (named above or in the originating/earlier carryover headers), not omissions. Global issue IDs in `<!-- id: -->` stamps are the originating run's, copied verbatim (never restamped).
> **Why still valid:** the only source change in this run's range `267660b..0fd6bdf` is the new file `src/migration/UniPoolerCutoverEscrow.sol` (plus its tests and `test/mocks/MockV3ExitRouter.sol`). None of the contracts under the entries below changed, no fix landed for any of them, and no human triage has disposed of them, so each is still live exactly as last reported. Not being re-observed by a run-22 tool is **not** a fix.
> Line numbers and links are as written at the originating commit; relative links resolve from the **original** report's directory (`reports/NN/submissions/`), not from this `carryover/` folder. Re-verify every location against `0fd6bdf` before acting.
> *The finding text below is a verbatim copy of the originating report. `Carryover status (run 21 …)` blocks were added by the run-21 qa-bundler and are kept as history; the run-22 status of every entry is the table below.*
>
> | Ledger label | issueId | Fingerprint | Status | First seen | Last seen (after run 22) | Re-observed in run 22 | Contract |
> |---|---|---|---|---|---|---|---|
> | F-01-045 | — | `25212e80eef98ec3619636caee5f37b7c420f98df662b9e59db6473e5c2e8367` | `open` | yield-claim-nft-18 | yield-claim-nft-18 | no (carried; code unchanged) | `src/dispatchers/PromotionUniV2_Eth.sol` |

<details><summary>Provenance notes from the run-21 carryover header (kept verbatim: label-collision warnings, facet and instance notes)</summary>

> Pruned copy of `yield-claim-nft/reports/18/submissions/spec-conformance.md` (commit `e4de393`), carried at `267660b`. Retained (still `open`): **F-01-045**. Removed: **F-01-044** (`3e638eb926`, `wont-fix`); the carried F-01-043 reference lives in `spec-conformance-15.md`.
> Relative links resolve from the original report's directory. *Text below each heading is a verbatim copy; the `Carryover status` block is added by the run-21 qa-bundler.* These are faithfulness (Law-2) records: they belong to the spec-conformance channel, not the QA bundle, and are carried here only so the run-21 carryover set is complete per `ledger-reconciliation.json`.

</details>

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

> **Carryover status (run 21, `267660b`).** Ledger **F-01-045** · fingerprint `25212e80eef98ec3619636caee5f37b7c420f98df662b9e59db6473e5c2e8367` · status **`open`** · severity `informational` · first seen `yield-claim-nft-18` · last seen `yield-claim-nft-18` · re-observed by run-21 inputs: **no (not re-raised; absence of a re-raise is not a fix)**.
