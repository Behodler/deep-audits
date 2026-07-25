# Carryover QA Report — originating audit 10 (carried into yield-claim-nft-19)

> **Carryover QA report — audit 10** (cut down from `reports/yield-claim-nft-10/submissions/qa-report.md`).
> Retained below (still open / untriaged as of audit 19): **L-04, L-05, L-06, L-07, Q-05**.
> Removed as no longer live: **none** — every finding in audit 10's QA report is still open. Structural sections not copied (they carry no findings of their own): the report's own "Still-Open Carryover (reference only)" block (run-08 `L-02`/`Q-04`, recall-only pointers) and "Appendix A — Automated QA/Gas Report (4naly3er)" (third-party tool output, regenerated each run).
> Labels are the originals — gaps in the sequence are the removals above, not omissions.
> Line numbers and links were accurate at the originating commit (`b8322ee (run-10)`); re-verify against current HEAD (`d4cc563`).
> These entries were **not re-examined** in the run-19 range (stories 046/047, dispatcher/streamer surface); they are carried for recall (Law 1), and their `lastSeenRun` was deliberately **not** bumped.
>
> ⚠ **Label-collision warning:** run-19's own C4 labels `L-04`/`L-05` are **new, unrelated findings** (ledger `L-19` / `9fdcb0c6…` and `L-20` / `1c1e0001…`). The `L-04`/`L-05` below are the **ledger** entries `674c799b…` / `e527a712…`. Do not conflate.
>
> *The text below is a verbatim copy of the retained sections of the original report.*

---

## Low Risk Findings

### [L-04] Privileged `mintFor()`/`burn()` ignore global `paused` + per-index `disabled` flags <!-- id: ycn10l4 -->

**Severity:** Low

**Location:** [`lib/yield-claim-nft/src/V2/NFTMinterV2.sol#L206-L214`](../../../lib/yield-claim-nft/src/V2/NFTMinterV2.sol#L206-L214) (`mintFor`), [`#L341-L345`](../../../lib/yield-claim-nft/src/V2/NFTMinterV2.sol#L341-L345) (`burn`)

**Description:** The privileged supply-changing entry points `mintFor()` and `burn()` do not re-apply the global `paused` guard nor the per-index `configs[index].disabled` guard that the permissionless `_executeMint` path enforces. When the owner sets `configs[index].disabled = true` (documented as *"new mints are blocked"*) or the contract is paused, the trusted migrator can still mint/burn that index. The pause-exempt leg is deliberate-by-design (a pause-exempt migration primitive, justified by the reverted story-033) and is faithful; the residual defect is the **disabled-bypass**, a documented-semantics deviation from *"new mints are blocked"* with no authorizing story.

**Impact:** No asset theft or net inflation. `mintFor()` mints exactly one claim NFT 1:1 against a burned V1 NFT and is gated to `authorizedMinters` (only the trusted `NFTMigrator` is wired); `burn()` is gated to `authorizedBurners`. The defect is a kill-switch completeness gap (incorrect state-handling / spec conformance), not an asset path, and there is no permissionless trigger. It is a non-obvious owner footgun: an owner who disables an index would reasonably be surprised that the migrator path can still mint it. (This item also carries faithfulness tag **F-03** and is routed to the spec-conformance report.)

**Recommendation:** Re-apply the per-index `disabled` check (and, if pause-exemption is not actually required for migration, the `paused` check) on `mintFor()`/`burn()`; or explicitly document the privileged path as `disabled`/pause-exempt so the *"new mints are blocked"* semantics are not silently violated.

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

---

### [L-06] Single-sided LP-add relies solely on off-chain keeper `minBPT` (MEV sandwich) <!-- id: ycn10l6 -->

**Severity:** Low *(borderline Low/Medium — held at Low; see resolution below)*

**Location:** [`lib/yield-claim-nft/src/V2/dispatchers/BalancerPoolerV2.sol#L269-L275`](../../../lib/yield-claim-nft/src/V2/dispatchers/BalancerPoolerV2.sol#L269-L275) (`pool`), [`#L278-L314`](../../../lib/yield-claim-nft/src/V2/dispatchers/BalancerPoolerV2.sol#L278-L314) (`unlockCallback`)

**Description:** `pool()` and its `unlockCallback` perform a single-sided `AddLiquidityKind.UNBALANCED` join into the Balancer V3 sUSDS/phUSD pool whose only slippage protection is an off-chain, keeper-supplied `minBPT` floor passed through to `minBptAmountOut`. There is no on-chain price reference (e.g. a `getIdealBPT()` / `queryAddLiquidityUnbalanced` quote) to tighten that floor at call time.

**Impact:** Bounded protocol-treasury value leak. BPT minted to the dispatcher (protocol treasury) on the single-sided join can be less than fair if the sUSDS/phUSD pool is skewed around the join. An authorized keeper broadcasts `pool(minBPT)` to the public mempool (`pool()` is `onlyAuthorizedPooler whenNotPaused nonReentrant`, so an external attacker cannot *initiate* it); an attacker observes the pending tx, skews the pool immediately before the join, lets the join execute at the skewed price (`bptAmountOut >= minBPT` but below the unskewed-fair amount), then reverses the skew — capturing up to `(idealBPT - minBPT)`. Loss falls on the protocol treasury, **not** on minters/users, and is bounded by the keeper-supplied floor; the accumulate-then-dump design enlarges the single join and thus the extractable imbalance.

> **Borderline resolution (held at Low).** C4 Medium admits a value leak gated by external
> conditions, so external requirements alone do not disqualify Medium. This is held at Low because:
> (1) a functioning slippage control already exists — `minBPT` is a mandatory caller-supplied floor
> (which a careless keeper could set to 0), so its tightness is the keeper's responsibility and the
> defect is the *absence of an on-chain price cross-check* on an already-present off-chain bound (a
> hardening gap, not a missing control); (2) the trigger is
> permissioned — an attacker can only opportunistically sandwich a tx the keeper voluntarily
> broadcasts, defeatable entirely by a private relay; (3) the magnitude is fully bounded by
> `(idealBPT - minBPT)` and is directly under protocol control; (4) the value at risk is
> protocol-treasury BPT, not user funds; and (5) the structurally-identical prior `L-03` (old
> AMM-swap leg) and the econ-scanner both rated this surface Low. *(Confidence: medium — this is
> the run's sole Low/Medium borderline.)*

**Recommendation:** Note that an in-transaction `getIdealBPT()` / `queryAddLiquidityUnbalanced` clamp does **not** defend against an atomic same-block sandwich: that quote reads the **same** pool reserves the attacker skews within the same transaction, so a floor derived from it tracks the manipulated price and lets the join proceed at the skewed rate. The robust mitigations are (a) derive the `minBPT` floor from an **external / oracle price reference** (not the manipulable in-pool spot), and/or (b) submit the keeper's `pool()` tx via **private / MEV-protected** routing (e.g. a private relay such as Flashbots). Setting a **tight `minBPT` tolerance** remains good operator guidance, but a tolerance derived from the in-pool spot is not by itself a substitute for (a) or (b).

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

---

## QA / Non-Critical Findings

### [Q-05] `nonReentrant` is not the first modifier on `pool()` <!-- id: ycn10q5 -->

**Severity:** QA (defense-in-depth)

**Location:** [`lib/yield-claim-nft/src/V2/dispatchers/BalancerPoolerV2.sol#L269`](../../../lib/yield-claim-nft/src/V2/dispatchers/BalancerPoolerV2.sol#L269) (`pool` — `onlyAuthorizedPooler whenNotPaused nonReentrant`)

**Description:** On `pool()` the modifier order is `[onlyAuthorizedPooler whenNotPaused nonReentrant]`; `nonReentrant` is placed last, so the preceding modifiers run before the reentrancy guard engages.

**Impact:** None demonstrated. No exploitable reentrancy was found this run (CEI invariant PASS; the `NFTMinterV2` reentrancy lead was refuted again as `L-01`). Neither preceding modifier makes an external call on the current code, so there is no concrete attack surface — this is purely preventative code-quality / hardening.

**Recommendation:** Reorder `nonReentrant` to be the **first** modifier on `pool()` (and the hook-guarded entry) so the guard is established before any preceding modifier that could, now or in future, make an external call.

---
