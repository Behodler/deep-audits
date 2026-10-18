# Carryover QA report — originating audit 10 (carried into yield-claim-nft-22)

> **Carryover QA report — audit 10** (pruned copy of `yield-claim-nft/reports/10/submissions/qa-report.md`, taken from the run-21 pruned carryover `reports/21/submissions/carryover/qa-report-10.md` — whose finding text is itself the verbatim original — re-checked against the ledger at run 22). Carried at `0fd6bdf` (`0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630`), run 22, branch `master`.
> Retained (still live in the ledger: `open` / `qa-bundled` / `fix-pending`): **L-04, L-05, L-07, Q-05**.
> Removed as no longer live: **none since run 21** (the retained set is unchanged; entries disposed before run 21 are named in the provenance notes below).
> Labels are the originals — gaps in the sequence are removals (named above or in the originating/earlier carryover headers), not omissions. Global issue IDs in `<!-- id: -->` stamps are the originating run's, copied verbatim (never restamped).
> **Why still valid:** the only source change in this run's range `267660b..0fd6bdf` is the new file `src/migration/UniPoolerCutoverEscrow.sol` (plus its tests and `test/mocks/MockV3ExitRouter.sol`). None of the contracts under the entries below changed, no fix landed for any of them, and no human triage has disposed of them, so each is still live exactly as last reported. Not being re-observed by a run-22 tool is **not** a fix.
> Line numbers and links are as written at the originating commit; relative links resolve from the **original** report's directory (`reports/NN/submissions/`), not from this `carryover/` folder. Re-verify every location against `0fd6bdf` before acting.
> *The finding text below is a verbatim copy of the originating report. `Carryover status (run 21 …)` blocks were added by the run-21 qa-bundler and are kept as history; the run-22 status of every entry is the table below.*
>
> | Ledger label | issueId | Fingerprint | Status | First seen | Last seen (after run 22) | Re-observed in run 22 | Contract |
> |---|---|---|---|---|---|---|---|
> | L-04 | — | `674c799b2058057e89e6a3bc06a4870e2fe2beac766487902439f78fb164a580` | `open` | yield-claim-nft-10 | yield-claim-nft-12 | no (carried; code unchanged) | `src/NFTMinterV2.sol` |
> | L-05 | — | `e527a712118b9cff5ccda89bd645f68078b0509711781369ef8a09785d954822` | `open` | yield-claim-nft-10 | yield-claim-nft-20 | no (carried; code unchanged) | `src/dispatchers/BalancerPoolerV2.sol` |
> | L-07 | — | `ac91a046b297df79136825b5446d76e74368e175351e7a306bb3051b36a82a76` | `open` | yield-claim-nft-10 | yield-claim-nft-12 | no (carried; code unchanged) | `src/NFTMinterV2.sol` |
> | Q-05 | — | `13fe448d0eb09c383e7b6cbb92fcdb57425ecfa5a7802f2174458c46d566e243` | `open` | yield-claim-nft-10 | yield-claim-nft-22 | yes | `src/dispatchers/BalancerPoolerV2.sol` |

<details><summary>Provenance notes from the run-21 carryover header (kept verbatim: label-collision warnings, facet and instance notes)</summary>

> **Carryover QA report — audit 10** (pruned copy of `yield-claim-nft/reports/10/submissions/qa-report.md`; originating commit `cf75ec9`; carried at `267660b`, run 21).
> Retained (still `open` in the ledger): **L-04, L-05, L-07, Q-05**.
> Removed as disposed: **L-06** (`342075dfba`, `wont-fix`). Structural sections not copied: the "Still-Open Carryover (reference only)" block (run-08 L-02/Q-04 pointers — now carried in full in `qa-report-08.md`) and "Appendix A — Automated QA/Gas Report (4naly3er)".
> Later-run instance notes for these entries (run-13 Uniboost instance of L-05; run-17 PromotionUniV2_Eth instance of Q-05) are appended under the parent entry.
> ⚠ **Label-collision warning:** ledger L-04/L-05 here are **not** run-19's C4 labels L-04/L-05 (ledger L-19/L-20) — see `qa-report-19.md`.
> Line numbers and links are as written at the originating commit; relative links resolve from the **original** report's directory (`reports/NN/submissions/`), not from this `carryover/` folder, and many point at the retired `lib/yield-claim-nft/...` reference tree. Re-verify every location against `267660b` before acting.
> Global issue IDs in the `<!-- id: -->` stamps are the originating run's, copied verbatim (never restamped). Where an originating report minted an ID inconsistently (run 08 stamped QA items with `l`), the original stamp is kept and the discrepancy is noted, not corrected.
> *The finding text below each heading is a verbatim copy of the originating report; the `Carryover status` block after each section is added by the run-21 qa-bundler.*

</details>

---

## Low Risk Findings

### [L-04] Privileged `mintFor()`/`burn()` ignore global `paused` + per-index `disabled` flags <!-- id: ycn10l4 -->

**Severity:** Low

**Location:** [`lib/yield-claim-nft/src/V2/NFTMinterV2.sol#L206-L214`](../../../lib/yield-claim-nft/src/V2/NFTMinterV2.sol#L206-L214) (`mintFor`), [`#L341-L345`](../../../lib/yield-claim-nft/src/V2/NFTMinterV2.sol#L341-L345) (`burn`)

**Description:** The privileged supply-changing entry points `mintFor()` and `burn()` do not re-apply the global `paused` guard nor the per-index `configs[index].disabled` guard that the permissionless `_executeMint` path enforces. When the owner sets `configs[index].disabled = true` (documented as *"new mints are blocked"*) or the contract is paused, the trusted migrator can still mint/burn that index. The pause-exempt leg is deliberate-by-design (a pause-exempt migration primitive, justified by the reverted story-033) and is faithful; the residual defect is the **disabled-bypass**, a documented-semantics deviation from *"new mints are blocked"* with no authorizing story.

**Impact:** No asset theft or net inflation. `mintFor()` mints exactly one claim NFT 1:1 against a burned V1 NFT and is gated to `authorizedMinters` (only the trusted `NFTMigrator` is wired); `burn()` is gated to `authorizedBurners`. The defect is a kill-switch completeness gap (incorrect state-handling / spec conformance), not an asset path, and there is no permissionless trigger. It is a non-obvious owner footgun: an owner who disables an index would reasonably be surprised that the migrator path can still mint it. (This item also carries faithfulness tag **F-03** and is routed to the spec-conformance report.)

**Recommendation:** Re-apply the per-index `disabled` check (and, if pause-exemption is not actually required for migration, the `paused` check) on `mintFor()`/`burn()`; or explicitly document the privileged path as `disabled`/pause-exempt so the *"new mints are blocked"* semantics are not silently violated.

> **Carryover status (run 21, `267660b`).** Ledger **L-04** · fingerprint `674c799b2058057e89e6a3bc06a4870e2fe2beac766487902439f78fb164a580` · status **`open`** · severity `low` · first seen `yield-claim-nft-10` · last seen `yield-claim-nft-12` · re-observed by run-21 inputs: **no (not re-raised; absence of a re-raise is not a fix)**.

---

### [L-05] No on-chain invariant couples `batchDonationSize` and `Hook.ratio` <!-- id: ycn10l5 -->

**Severity:** Low

**Location:** [`lib/yield-claim-nft/src/V2/dispatchers/BalancerPoolerV2.sol#L160-L164`](../../../lib/yield-claim-nft/src/V2/dispatchers/BalancerPoolerV2.sol#L160-L164) (`setBatchDonationSize`) ↔ [`lib/yield-claim-nft/src/V2/hooks/BalancerPoolerMintDebtHook.sol#L77-L82`](../../../lib/yield-claim-nft/src/V2/hooks/BalancerPoolerMintDebtHook.sol#L77-L82) (`setRatio`)

**Description:** story-034 introduced a donation→PSM-export mechanism whose safe envelope is the coupling `batchDonationSize + ratio <= 100`. Two owner setters in two separate contracts — `BalancerPoolerV2.setBatchDonationSize` (cap 100) and `BalancerPoolerMintDebtHook.setRatio` (cap 50) — have **no on-chain linking invariant**, so the owner can silently configure `batchDonationSize + ratio > 100`, crossing the documented coupling boundary with nothing on-chain to reject or link the two values. This finding is framed **strictly as the operator guardrail / missing on-chain invariant**.

**Impact:** Missing on-chain invariant and a non-obvious cross-contract owner footgun: a competent, non-malicious owner would be surprised that two separately-capped knobs in two contracts can silently sum past the intended boundary, leaving the configuration outside its safe envelope until manually corrected. There is no permissionless trigger (both setters are `onlyOwner`). (This item carries faithfulness tag **F-02** and is routed to the spec-conformance report.)

> **Scope guard.** The downstream "phUSD is unbacked / value can leak from the backing model"
> security claim is **out of scope and suppressed** (tracked separately as DEDUP-001 under the
> project's known-issues backing model; the backing arithmetic was proven unchanged from the
> pre-story-034 baseline). It is **not** re-introduced or asserted here; this Low covers only the
> missing operator guardrail.

**Recommendation:** Add an on-chain invariant coupling the two knobs — reject any `setBatchDonationSize`/`setRatio` that would make `batchDonationSize + ratio > 100` — or surface the combined value through a shared validation path so the boundary cannot be silently crossed.

> **Carryover status (run 21, `267660b`).** Ledger **L-05** · fingerprint `e527a712118b9cff5ccda89bd645f68078b0509711781369ef8a09785d954822` · status **`open`** · severity `low` · first seen `yield-claim-nft-10` · last seen `yield-claim-nft-20` · re-observed by run-21 inputs: **no (not re-raised; absence of a re-raise is not a fix)**.
> Run-21 location note: UniPoolerV2 secondary locations still present at 267660b: setBatchDonationSize :288; _dispatch :348-380 (run-20 recorded :234-238 / :290-320; lines shifted). Not re-raised by run-21 inputs; absence != fix.

#### Later instance (run 13, verbatim from `reports/13/submissions/qa-report.md`)

#### Instance note — [L-05] `donationSplit` ↔ hook `ratio` cross-contract decoupling (Uniboost instance)

**Location:** [`src/dispatchers/Uniboost.sol#L138`](../../../../lib/yield-claim-nft/src/dispatchers/Uniboost.sol#L138)
(`setDonationSplit`) ↔ [`src/hooks/UniboostMintDebtHook.sol#L96`](../../../../lib/yield-claim-nft/src/hooks/UniboostMintDebtHook.sol#L96) (`setRatio`).

This is a **second instance** of already-open ledger **L-05** (`e527a712`) on the new Uniboost
dispatcher/hook pair; annotated under the existing L-05 entry, **not** a new label or regression. The
Uniboost `donationSplit` and the `UniboostMintDebtHook.ratio` are set on two different contracts with no
on-chain coupling invariant. No solvency break: `ratio` is hard-capped at `MAX_RATIO = 50`, so worst-case
accrued debt is ≤ 50% of dispatched prime while retained value is ~100% at dispatch (Tier-3 confirms
≥ 2:1 backing; 0%/100% edges verified safe). Impact is a transparency/config-coupling gap, not value at
risk. Recommendation (same as L-05): introduce an on-chain guardrail tying `donationSplit` and
`hook.ratio` together.

---

### [L-07] `replaceDispatcher()` carries stale price across differing `primeToken` decimals <!-- id: ycn10l7 -->

**Severity:** Low

**Location:** [`lib/yield-claim-nft/src/V2/NFTMinterV2.sol#L227-L247`](../../../lib/yield-claim-nft/src/V2/NFTMinterV2.sol#L227-L247) (`replaceDispatcher`)

**Description:** `replaceDispatcher()` (`onlyOwner`) swaps the dispatcher bound to an index. `configs[index].price` is a raw number whose denomination is defined by whichever dispatcher's `primeToken` is currently bound, but it persists unchanged across the swap. Swapping in a dispatcher whose `primeToken` has different decimals silently re-denominates the carried-over price until a corrective `setPrice` is issued.

**Impact:** Mis-scaled mint charge during the window between `replaceDispatcher` and a corrective `setPrice`. `_executeMint` transfers `price` units of the **new** `primeToken` (`safeTransferFrom(msg.sender, dispatcher, price)`):

- **Lower-decimals new token** (e.g. 18-dp → 6-dp): a stored 18-dp price is astronomically large in the new token's units → `safeTransferFrom` reverts → minting for that index is bricked until `setPrice` (availability impact).
- **Higher-decimals new token** (e.g. 6-dp → 18-dp): a stored 6-dp price is dust in 18-dp units → near-free mints, under-backing the dispatcher until the owner calls `setPrice`.

There is no attacker path (the setter is `onlyOwner`) and the worst case is a self-inflicted, owner-fixable revert or a brief near-free-mint window. It is a non-obvious owner footgun: the name `replaceDispatcher` implies a like-for-like swap and gives no hint that `price` persists in `NFTMinterV2` while its denomination is owned by the bound dispatcher's `primeToken`.

> **Human-review note (C-01 fold).** This is a **distinct** aspect from the existing `C-01`
> centralization item, which tracks the general re-pointing of token/metadata under existing
> holders and does **not** cover the price re-denomination sub-issue (distinct fingerprint).
> It is carried here as a standalone Low footgun, but a reviewer may alternatively choose to
> **fold it as a sub-item under the `C-01` centralization entry** when triaging — flagged for that
> human decision rather than resolved unilaterally.

**Recommendation:** Re-set the price atomically within `replaceDispatcher` (require a fresh price argument and write it in the same call), or restrict swaps to dispatchers whose `primeToken` has the same decimals as the outgoing one. Document that price denomination is owned by the bound dispatcher.

> **Carryover status (run 21, `267660b`).** Ledger **L-07** · fingerprint `ac91a046b297df79136825b5446d76e74368e175351e7a306bb3051b36a82a76` · status **`open`** · severity `low` · first seen `yield-claim-nft-10` · last seen `yield-claim-nft-12` · re-observed by run-21 inputs: **no (not re-raised; absence of a re-raise is not a fix)**.

---

## QA / Non-Critical Findings

### [Q-05] `nonReentrant` is not the first modifier on `pool()` <!-- id: ycn10q5 -->

**Severity:** QA (defense-in-depth)

**Location:** [`lib/yield-claim-nft/src/V2/dispatchers/BalancerPoolerV2.sol#L269`](../../../lib/yield-claim-nft/src/V2/dispatchers/BalancerPoolerV2.sol#L269) (`pool` — `onlyAuthorizedPooler whenNotPaused nonReentrant`)

**Description:** On `pool()` the modifier order is `[onlyAuthorizedPooler whenNotPaused nonReentrant]`; `nonReentrant` is placed last, so the preceding modifiers run before the reentrancy guard engages.

**Impact:** None demonstrated. No exploitable reentrancy was found this run (CEI invariant PASS; the `NFTMinterV2` reentrancy lead was refuted again as `L-01`). Neither preceding modifier makes an external call on the current code, so there is no concrete attack surface — this is purely preventative code-quality / hardening.

**Recommendation:** Reorder `nonReentrant` to be the **first** modifier on `pool()` (and the hook-guarded entry) so the guard is established before any preceding modifier that could, now or in future, make an external call.

> **Carryover status (run 21, `267660b`).** Ledger **Q-05** · fingerprint `13fe448d0eb09c383e7b6cbb92fcdb57425ecfa5a7802f2174458c46d566e243` · status **`open`** · severity `qa` · first seen `yield-claim-nft-10` · last seen `yield-claim-nft-20` · re-observed by run-21 inputs: **yes**.
> Run-21 location note: UniPoolerV2.pool:450-454 nonReentrant not first: re-observed (ADERYN-002).

#### Later instance (run 17, verbatim from `reports/17/submissions/qa-report.md`)

##### [Q-05] `nonReentrant` is not the first modifier on `pool()` (carryover) <!-- id: ycn17q5 -->

**Location:** [`PromotionUniV2_Eth.sol` `pool` L277-282](../../../../lib/yield-claim-nft/src/dispatchers/PromotionUniV2_Eth.sol#L277)
**Original report:** [reports/yield-claim-nft/10/submissions/qa-report.md](../../10/submissions/qa-report.md) · **Carryover stub:** [`carryover/Q-05-CARRYOVER.md`](./carryover/Q-05-CARRYOVER.md) · **Fingerprint:** `13fe448d…`

**Status:** carryover, still-open (de-dup-against-ledger, kept visible in this bundle — not a suppression).

**Description (this-run instance):** The class recurs byte-identically on `PromotionUniV2_Eth.pool` — modifier order is `onlyAuthorizedPooler, whenNotPaused, nonReentrant`. Defense-in-depth style only: the preceding modifiers merely read state, so ordering `nonReentrant` last is inert here, but placing it first is the safer convention. See the original report for full detail.
