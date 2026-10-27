# Carryover QA report — originating audit 08 (carried into yield-claim-nft-23)

> **Carryover QA report — audit 08** (pruned copy of `yield-claim-nft/reports/08/submissions/qa-report.md`, taken from the run-22 pruned carryover `reports/22/submissions/carryover/qa-report-08.md` — whose finding text is itself the verbatim original — re-checked against the ledger at run 23). Carried at `c5ad56d` (`c5ad56df5b5dc3f68a6f6a5e4e5f95ef532a2238`), run 23, branch `master`.
> Retained (still live in the ledger: `open` / `qa-bundled` / `fix-pending`): **L-01, L-02, Q-03, Q-04, Q-09, C-01**.
> Removed as no longer live: **none since run 22** (no ledger status changed). Parked for human triage (still live in the ledger, not shown in the body): **Q-02** — see § Human triage proposals at the end of this file.
> Labels are the originals — gaps in the sequence are removals (named above or in the originating/earlier carryover headers), not omissions. Global issue IDs in `<!-- id: -->` stamps are the originating run's, copied verbatim (never restamped).
> **Why still valid:** the source changes in this run's range `0fd6bdf..c5ad56d` are the new `src/NFTBonfire.sol` (story-053), the deletion of `src/dispatchers/BalancerPoolerV2.sol` and the Balancer interfaces (story-050), and comment/NatSpec-only renames in `NudgeRatchetDelayRelease.sol`, `Uniboost.sol` and `IUniboostPooler.sol`. No retained entry's code logic changed (`NFTMinterV2.sol`, `src/hooks/**` and `src/migration/**` are unchanged), no fix landed for any of them, and no human triage disposed of them, so each is still live exactly as last reported. Not being re-observed by a run-23 tool is **not** a fix.
> Line numbers and links are as written at the originating commit; relative links resolve from the **original** report's directory (`reports/08/submissions/`), not from this `carryover/` folder. Original report: [`reports/08/submissions/qa-report.md`](../../../08/submissions/qa-report.md). Re-verify every location against `c5ad56d` before acting.
> *The finding text below is a verbatim copy of the originating report. `Carryover status (run 21 …)` blocks are kept as history; the run-23 status of every entry is the table below.*
>
> | Ledger label | issueId | Fingerprint | Status | First seen | Last seen (after run 23) | Re-observed in run 23 | Contract |
> |---|---|---|---|---|---|---|---|
> | L-01 | — | `a25137b12fded6680f3844bfd61dda7d1e661a72f78c3230916e684b3b5ce37c` | `qa-bundled` | yield-claim-nft-08 | yield-claim-nft-22 | no (carried; code unchanged) | `src/NFTMinterV2.sol` |
> | L-02 | — | `5425119cae0a2f9f6ad13a7f088bbb95839689032afab295eb60c536775d9d43` | `qa-bundled` | yield-claim-nft-08 | yield-claim-nft-16 | no (carried; code unchanged) | `src/hooks/BalancerPoolerMintDebtHook.sol` |
> | Q-03 | — | `162f28d564585a15c4ab614364f5f8ba69b776c829a8ea4535325d7f9096863e` | `qa-bundled` | yield-claim-nft-08 | yield-claim-nft-22 | no (carried; code unchanged) | `src/NFTMinterV2.sol` |
> | Q-04 | — | `daada310d0ca5ed90d4b8d06748afd430d2a70dbad2ce53351ffd5e90a5623c0` | `qa-bundled` | yield-claim-nft-08 | yield-claim-nft-22 | no (carried; code unchanged) | `src/dispatchers/ATokenDispatcherV2.sol` |
> | Q-09 | — | `3a5c5221a5b4b617f1acbe3569f6819c4b7984fc98c11e6da890b5c05910c56b` | `qa-bundled` | yield-claim-nft-08 | yield-claim-nft-12 | no (carried; code unchanged) | `src/dispatchers/BurnerV2.sol` |
> | C-01 | — | `d1c5aa860f49b410927354b798af4e4a54c8f311bfd033413875409910c61487` | `qa-bundled` | yield-claim-nft-08 | yield-claim-nft-08 | no (carried; code unchanged) | `src/NFTMinterV2.sol` |

<details><summary>Provenance: run-22 carryover header (kept verbatim, including the nested run-21 provenance notes)</summary>

> **Carryover QA report — audit 08** (pruned copy of `yield-claim-nft/reports/08/submissions/qa-report.md`, taken from the run-21 pruned carryover `reports/21/submissions/carryover/qa-report-08.md` — whose finding text is itself the verbatim original — re-checked against the ledger at run 22). Carried at `0fd6bdf` (`0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630`), run 22, branch `master`.
> Retained (still live in the ledger: `open` / `qa-bundled` / `fix-pending`): **L-01, L-02, Q-02, Q-03, Q-04, C-01, Q-09**.
> Removed as no longer live: **none since run 21** (the retained set is unchanged; entries disposed before run 21 are named in the provenance notes below).
> Labels are the originals — gaps in the sequence are removals (named above or in the originating/earlier carryover headers), not omissions. Global issue IDs in `<!-- id: -->` stamps are the originating run's, copied verbatim (never restamped).
> **Why still valid:** the only source change in this run's range `267660b..0fd6bdf` is the new file `src/migration/UniPoolerCutoverEscrow.sol` (plus its tests and `test/mocks/MockV3ExitRouter.sol`). None of the contracts under the entries below changed, no fix landed for any of them, and no human triage has disposed of them, so each is still live exactly as last reported. Not being re-observed by a run-22 tool is **not** a fix.
> Line numbers and links are as written at the originating commit; relative links resolve from the **original** report's directory (`reports/NN/submissions/`), not from this `carryover/` folder. Re-verify every location against `0fd6bdf` before acting.
> *The finding text below is a verbatim copy of the originating report. `Carryover status (run 21 …)` blocks were added by the run-21 qa-bundler and are kept as history; the run-22 status of every entry is the table below.*
>
> | Ledger label | issueId | Fingerprint | Status | First seen | Last seen (after run 22) | Re-observed in run 22 | Contract |
> |---|---|---|---|---|---|---|---|
> | L-01 | — | `a25137b12fded6680f3844bfd61dda7d1e661a72f78c3230916e684b3b5ce37c` | `qa-bundled` | yield-claim-nft-08 | yield-claim-nft-22 | yes | `src/NFTMinterV2.sol` |
> | L-02 | — | `5425119cae0a2f9f6ad13a7f088bbb95839689032afab295eb60c536775d9d43` | `qa-bundled` | yield-claim-nft-08 | yield-claim-nft-16 | no (carried; code unchanged) | `src/hooks/BalancerPoolerMintDebtHook.sol` |
> | Q-02 | — | `261859a435e78cbf521d40b15d448242f1f33cc8501bff97f296f075977a637f` | `qa-bundled` | yield-claim-nft-08 | yield-claim-nft-22 | yes | `src/dispatchers/BalancerPoolerV2.sol` |
> | Q-03 | — | `162f28d564585a15c4ab614364f5f8ba69b776c829a8ea4535325d7f9096863e` | `qa-bundled` | yield-claim-nft-08 | yield-claim-nft-22 | yes | `src/NFTMinterV2.sol` |
> | Q-04 | — | `daada310d0ca5ed90d4b8d06748afd430d2a70dbad2ce53351ffd5e90a5623c0` | `qa-bundled` | yield-claim-nft-08 | yield-claim-nft-22 | yes | `src/dispatchers/ATokenDispatcherV2.sol` |
> | C-01 | — | `d1c5aa860f49b410927354b798af4e4a54c8f311bfd033413875409910c61487` | `qa-bundled` | yield-claim-nft-08 | yield-claim-nft-08 | no (carried; code unchanged) | `src/NFTMinterV2.sol` |
> | Q-09 | — | `3a5c5221a5b4b617f1acbe3569f6819c4b7984fc98c11e6da890b5c05910c56b` | `qa-bundled` | yield-claim-nft-08 | yield-claim-nft-12 | no (carried; code unchanged) | `src/dispatchers/BurnerV2.sol` |

<details><summary>Provenance notes from the run-21 carryover header (kept verbatim: label-collision warnings, facet and instance notes)</summary>

> **Carryover QA report — audit 08** (pruned copy of `yield-claim-nft/reports/08/submissions/qa-report.md`; originating commit `bc99ee3`; carried at `267660b`, run 21).
> Retained (still `qa-bundled`/open in the ledger): **L-01, L-02, Q-01→ledger Q-09 (BurnerV2/GatherV2 facet only), Q-02, Q-03, Q-04, C-01**.
> Removed as disposed: **L-03** (`e29ae08ed9`, `fixed`) and the **NFTMigrator facet of Q-01** (ledger Q-01 `98c9fc4523`, `fixed` — NFTMigrator deleted in story-039; the surviving BurnerV2/GatherV2 facet was re-keyed in run 12 as ledger **Q-09** `3a5c5221a5`). "Appendix A — Automated QA/Gas Report (4naly3er)" is not copied (tool output, regenerated each run).
> Later-run instance notes for these entries (run-13 Uniboost instance of L-02) are appended under the parent entry so every live facet of a run-08 finding lives in this one file.
> ⚠ **Label-collision warning:** ledger L-01/L-02 here are **not** run-19's C4 labels L-01/L-02 (ledger L-16/L-17) — see `qa-report-19.md`.
> Line numbers and links are as written at the originating commit; relative links resolve from the **original** report's directory (`reports/NN/submissions/`), not from this `carryover/` folder, and many point at the retired `lib/yield-claim-nft/...` reference tree. Re-verify every location against `267660b` before acting.
> Global issue IDs in the `<!-- id: -->` stamps are the originating run's, copied verbatim (never restamped). Where an originating report minted an ID inconsistently (run 08 stamped QA items with `l`), the original stamp is kept and the discrepancy is noted, not corrected.
> *The finding text below each heading is a verbatim copy of the originating report; the `Carryover status` block after each section is added by the run-21 qa-bundler.*

</details>

</details>

---

## Low Risk Findings

### [L-01] NFTMinterV2._executeMint lacks ReentrancyGuard (cross-index re-entry not blocked) <!-- id: ycn8l1 -->

**Location**: [`src/V2/NFTMinterV2.sol#L170-L201`](../../../lib/yield-claim-nft/src/V2/NFTMinterV2.sol#L170)

**Description**: The `nonReentrant` guard lives on the dispatcher (`ATokenDispatcherV2.sol:118-126`), not on `NFTMinterV2` itself, so re-entry into `_executeMint` targeting a *different* dispatcher index is not blocked at the minter level. No in-scope dispatcher makes a re-entrant external call today (in-scope hooks make no external calls in `onDispatch`, and `BalancerPoolerV2._dispatch` only does `forceApprove` + `ERC4626.deposit`), so this is a latent defense-in-depth gap, not exploitable in the current code.

**Recommendation**: Add a `nonReentrant` modifier to `NFTMinterV2._executeMint` (or the public entrypoints that reach it) so cross-index re-entry is blocked at the minter level regardless of any future dispatcher that may be added.

> **Carryover status (run 21, `267660b`).** Ledger **L-01** · fingerprint `a25137b12fded6680f3844bfd61dda7d1e661a72f78c3230916e684b3b5ce37c` · status **`qa-bundled`** · severity `low` · first seen `yield-claim-nft-08` · last seen `yield-claim-nft-20` · re-observed by run-21 inputs: **yes**.

---

### [L-02] setRatio accepts ratio == MAX_RATIO, contradicting documented strict-less-than invariant <!-- id: ycn8l2 -->

**Location**: [`src/V2/hooks/BalancerPoolerMintDebtHook.sol#L93`](../../../lib/yield-claim-nft/src/V2/hooks/BalancerPoolerMintDebtHook.sol#L93)

**Description**: `setRatio` guards with `if (newRatio > MAX_RATIO) revert` while the NatSpec/invariant (lines 29, 47, 91) states the ratio must be *strictly less than* `MAX_RATIO` (= 50). The value `ratio == 50` is therefore accepted in contradiction of the documented bound. No asset impact: the downstream `added = amount * ratio / 100` truncation rounds in the harmless direction.

**Recommendation**: Change the guard to `if (newRatio >= MAX_RATIO) revert` to match the documented strictly-less-than invariant, or update the NatSpec to permit equality if equality is actually intended.

```solidity
if (newRatio >= MAX_RATIO) revert RatioTooHigh();
```

> **Carryover status (run 21, `267660b`).** Ledger **L-02** · fingerprint `5425119cae0a2f9f6ad13a7f088bbb95839689032afab295eb60c536775d9d43` · status **`qa-bundled`** · severity `low` · first seen `yield-claim-nft-08` · last seen `yield-claim-nft-16` · re-observed by run-21 inputs: **no (not re-raised; absence of a re-raise is not a fix)**.

#### Later instance (run 13, verbatim from `reports/13/submissions/qa-report.md`)

#### Instance note — [L-02] `setRatio` accepts `ratio == MAX_RATIO` vs "strictly <" NatSpec (Uniboost instance)

**Location:** [`src/hooks/UniboostMintDebtHook.sol#L96-L97`](../../../../lib/yield-claim-nft/src/hooks/UniboostMintDebtHook.sol#L96)
(`if (newRatio > MAX_RATIO) revert RatioTooHigh();`); NatSpec at L30 / L95 says "strictly less than
`MAX_RATIO`".

This is a **second instance** of already-open ledger **L-02** (`5425119c`, qa-bundled) on the new
`UniboostMintDebtHook`; annotated under the existing L-02 entry, **not** a new label. `setRatio` uses
`> MAX_RATIO` (not `>=`), so `ratio == MAX_RATIO` (50) is accepted, contradicting the NatSpec
"strictly less than `MAX_RATIO`". Impact is none: the effective max debt is exactly 50% instead of
< 50%, still within the safe ≥ 2:1 buffer — a pure spec-vs-code boundary nit. This item is **also routed
to the spec-conformance (faithfulness) report** as an F-tagged Law-2 deviation; it is cross-referenced
here and intentionally not omitted from the QA bundle. Recommendation (same as L-02): use `>=` (revert on
`ratio == MAX_RATIO`) to match the strict-less-than NatSpec invariant, or correct the NatSpec.

---

## QA / Non-Critical Findings

### [Q-01] Missing zero-address validation in constructors (NFTMigrator, BurnerV2, GatherV2) <!-- id: ycn8l4 -->

**Location**: [`src/V2/NFTMigrator.sol`](../../../lib/yield-claim-nft/src/V2/NFTMigrator.sol), [`src/V2/dispatchers/BurnerV2.sol`](../../../lib/yield-claim-nft/src/V2/dispatchers/BurnerV2.sol), [`src/V2/dispatchers/GatherV2.sol`](../../../lib/yield-claim-nft/src/V2/dispatchers/GatherV2.sol)

**Description**: The constructors of `NFTMigrator`, `BurnerV2`, and `GatherV2` accept critical addresses without zero-address checks. A zero address would brick the flow at use time (downstream calls revert). Deployment-misconfiguration hardening only.

**Recommendation**: Add `require(addr != address(0))` validation for each critical constructor argument.

> **Carryover status (run 21, `267660b`).** Ledger **Q-09** · fingerprint `3a5c5221a5b4b617f1acbe3569f6819c4b7984fc98c11e6da890b5c05910c56b` · status **`qa-bundled`** · severity `qa` · first seen `yield-claim-nft-08` · last seen `yield-claim-nft-12` · re-observed by run-21 inputs: **no (not re-raised; absence of a re-raise is not a fix)**.
> Scope narrowed: this section is carried **as ledger Q-09** (`3a5c5221a5`), title "Missing zero-address validation in BurnerV2/GatherV2 constructors (token_, burnRecorder_, initialOwner; GatherV2 token_/initialOwner)". The NFTMigrator facet is moot (contract deleted, story-039) and closed under ledger Q-01 `98c9fc4523`.

---

_[Q-02] (ledger **Q-02**) is not shown here: parked for human triage — see § Human triage proposals at the end of this file. Still live in the ledger._

---

### [Q-03] abi.encodePacked used to build dynamic-string metadata in uri() (cosmetic) <!-- id: ycn8l6 -->

**Location**: [`src/V2/NFTMinterV2.sol#L262-L273`](../../../lib/yield-claim-nft/src/V2/NFTMinterV2.sol#L262)

**Description**: `uri()` builds dynamic-string metadata via `abi.encodePacked`. The packed output is returned as a metadata JSON string and is never hashed, so the classic `encodePacked` collision concern does not apply (no `keccak256` on this output). Cosmetic/style note only.

**Recommendation**: Prefer `abi.encode` or `string.concat` for dynamic-string concatenation clarity.

> **Carryover status (run 21, `267660b`).** Ledger **Q-03** · fingerprint `162f28d564585a15c4ab614364f5f8ba69b776c829a8ea4535325d7f9096863e` · status **`qa-bundled`** · severity `qa` · first seen `yield-claim-nft-08` · last seen `yield-claim-nft-20` · re-observed by run-21 inputs: **yes**.

---

### [Q-04] setMinter emits no event (and V2 uses single-step Ownable) <!-- id: ycn8l7 -->

**Location**: [`src/V2/dispatchers/ATokenDispatcherV2.sol#L85`](../../../lib/yield-claim-nft/src/V2/dispatchers/ATokenDispatcherV2.sol#L85)

**Description**: `setMinter` changes a privileged role without emitting an event, hindering off-chain detection/monitoring. Separately, V2 `Ownable` is single-step (`Ownable2Step` would guard a transfer mistake, but reckless-admin transfer mistakes are otherwise treated as known-invalid). Monitorability/operational-hygiene only.

**Recommendation**: Emit an event (e.g. `MinterUpdated(oldMinter, newMinter)`) in `setMinter`. Optionally adopt `Ownable2Step` for ownership transfers (minor note).

> **Carryover status (run 21, `267660b`).** Ledger **Q-04** · fingerprint `daada310d0ca5ed90d4b8d06748afd430d2a70dbad2ce53351ffd5e90a5623c0` · status **`qa-bundled`** · severity `qa` · first seen `yield-claim-nft-08` · last seen `yield-claim-nft-20` · re-observed by run-21 inputs: **yes**.

---

## Centralization Risks

### [C-01] Owner can replaceDispatcher at an existing index, re-pointing token/metadata under existing holders <!-- id: ycn8c1 -->

**Location**: [`src/V2/NFTMinterV2.sol#L227-L247`](../../../lib/yield-claim-nft/src/V2/NFTMinterV2.sol#L227)

**Description**: `replaceDispatcher` is `onlyOwner` and changes the dispatcher/token/metadata mapping for an index that may already have holders. Existing holders' `tokenId` then maps to a different dispatcher/token underneath them. Any "redemption honored against the new token" impact lives in an external redemption layer that is out of scope; no in-scope on-chain redemption keys off this mapping, so no in-scope value impact is demonstrable.

**Impact**: None demonstrable in scope (assumes a trusted owner per the project trust model). A real impact would require an external redemption layer that depends on the mapping.

**Recommendation**: Consider restricting `replaceDispatcher` to indexes with no existing holders, or document and time-lock the power, so holders cannot have their token/metadata re-pointed underneath them.

> **Carryover status (run 21, `267660b`).** Ledger **C-01** · fingerprint `d1c5aa860f49b410927354b798af4e4a54c8f311bfd033413875409910c61487` · status **`qa-bundled`** · severity `centralization` · first seen `yield-claim-nft-08` · last seen `yield-claim-nft-08` · re-observed by run-21 inputs: **no (not re-raised; absence of a re-raise is not a fix)**.

---

## Human triage proposals (parked — NOT live carryover)

> The entries below are still **live in the ledger** (status unchanged). They are moved out of the live carryover body because the sanitizer proposes a closure that only a human may apply with `/ledger yield-claim-nft`. Their full text is kept verbatim below so nothing is silently dropped (Law 1).

| Ledger label | Run-scoped heading | Fingerprint | Ledger status | Proposal |
|---|---|---|---|---|
| Q-02 | Q-02 | `261859a435` | `qa-bundled` | close `wont-fix` (obsolete): `src/dispatchers/BalancerPoolerV2.sol` deleted by story-050 in `0fd6bdf..c5ad56d`; deployed `0x7f687433` unregistered, paused and drained (faithfulness chain evidence, block 26280480). Not `fixed` (no fix made), not `abandoned` (merged code, not a discarded branch). **Human-applied only; status unchanged in the ledger (still live).** ⚠ The run-21 location note in its text records a re-observation of the unchecked ERC4626 `deposit` return on **`UniPoolerV2._dispatch` (:366)**, a live contract. Re-key that facet before closing Q-02 as obsolete. |

<details><summary>Q-02 (Q-02) — verbatim text as carried at run 22</summary>

### [Q-02] Unchecked ERC4626 deposit return value in BalancerPoolerV2._dispatch <!-- id: ycn8l5 -->

**Location**: [`src/V2/dispatchers/BalancerPoolerV2.sol#L183`](../../../lib/yield-claim-nft/src/V2/dispatchers/BalancerPoolerV2.sol#L183)

**Description**: The `IERC4626(sUSDS).deposit` return value (shares minted) is ignored at line 183. The gap is bounded and harmless because `pool()` re-reads `balanceOf(address(this))` (line 192) rather than the deposit return, so accounting uses the actual held sUSDS.

**Recommendation**: Capture and assert the ERC4626 `deposit` return value for accounting hygiene, even though the current `balanceOf` re-read makes the gap harmless.

> **Carryover status (run 21, `267660b`).** Ledger **Q-02** · fingerprint `261859a435e78cbf521d40b15d448242f1f33cc8501bff97f296f075977a637f` · status **`qa-bundled`** · severity `qa` · first seen `yield-claim-nft-08` · last seen `yield-claim-nft-20` · re-observed by run-21 inputs: **yes**.
> Run-21 location note: UniPoolerV2._dispatch ERC4626.deposit return ignored at :366 (SLITHER-001 reports :348): re-observed.

</details>

