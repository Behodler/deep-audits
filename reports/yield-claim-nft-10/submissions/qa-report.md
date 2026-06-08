# QA Report — yield-claim-nft (run-10)

| | |
|---|---|
| **Project** | yield-claim-nft |
| **Run** | yield-claim-nft-10 |
| **Audited commit** | `cf75ec9520fd16b19e20c4b77ada2be28d7d4382` |
| **Scope** | `src/V2/**` (NFTMinterV2, BalancerPoolerV2, BalancerPoolerMintDebtHook and adjacent V2 dispatchers/hooks) |

This document bundles all Low-severity and QA findings from this run. High/Medium findings (none this run) are submitted individually. Source links use the `lib/yield-claim-nft/...` read-only reference tree.

## Summary

| Severity | Count |
|----------|-------|
| Low Risk (this run) | 4 |
| QA / Non-Critical (this run) | 1 |
| Centralization (new, this run) | 0 |
| **Total (new this run)** | **5** |
| Still-open carryover (prior runs) | 2 (L-02 Low, Q-04 QA) |

| Label | Severity | Title |
|-------|----------|-------|
| [L-04](#l-04-privileged-mintforburn-ignore-global-paused--per-index-disabled-flags) | Low | Privileged `mintFor()`/`burn()` ignore global `paused` + per-index `disabled` flags |
| [L-05](#l-05-no-on-chain-invariant-couples-batchdonationsize-and-hookratio) | Low | No on-chain invariant couples `batchDonationSize` and `Hook.ratio` (missing `batchDonationSize + ratio <= 100` guardrail) |
| [L-06](#l-06-single-sided-lp-add-relies-solely-on-off-chain-keeper-minbpt-mev-sandwich) | Low | `pool()` single-sided LP-add relies solely on off-chain keeper `minBPT` (MEV sandwich) |
| [L-07](#l-07-replacedispatcher-carries-stale-price-across-differing-primetoken-decimals) | Low | `replaceDispatcher()` carries stale per-index price to a dispatcher with different `primeToken` decimals |
| [Q-05](#q-05-nonreentrant-is-not-the-first-modifier-on-pool) | QA | `nonReentrant` is not the first modifier on `pool()` (defense-in-depth) |

> **Centralization note.** No *new* centralization finding is emitted this run. The existing
> `C-01` (owner can `replaceDispatcher` at an existing index, re-pointing token/metadata under
> existing holders) remains an open ledger item from a prior run and is not re-described here.
> `L-07` is an adjacent — but distinct — aspect of that same setter; see the human-review note
> under `L-07`.

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

## Still-Open Carryover (reference only)

These were reported in a prior run, are still present at this commit, and are reproduced as
carryover stubs so they are not lost between runs. They are **not** re-analyzed here — see the
linked stubs and the original run-08 report for full descriptions, impact, and recommendations.
Triage them with `/ledger yield-claim-nft`. Their canonical IDs remain those from first report
(run-08): `ycn8l2` (L-02) and `ycn8l7` (Q-04).

- **[CARRYOVER] L-02 (Low)** — `setRatio` accepts `ratio == MAX_RATIO`, contradicting the documented strict-less-than invariant. Location `src/V2/hooks/BalancerPoolerMintDebtHook.sol#L77-L82`. Stub: [`carryover/L-02-CARRYOVER.md`](./carryover/L-02-CARRYOVER.md). First seen run-08; still present at run-10. *(This run's DD-02 reconciles to the same root cause; Halmos proved the reachable set bounded to [0,50]. Not a regression — never marked fixed.)*
- **[CARRYOVER] Q-04 (QA)** — `setMinter` emits no event, and V2 uses single-step `Ownable`. Location `src/V2/dispatchers/ATokenDispatcherV2.sol#L85`. Stub: [`carryover/Q-04-CARRYOVER.md`](./carryover/Q-04-CARRYOVER.md). First seen run-08; still present at run-10. *(This run's DD-07 single-step-Ownable observation reconciles to Q-04, which already bundles both the missing-event note and the single-step-Ownable item. Owner-trust is an explicit known issue, so it stays QA-only.)*

---

## Appendix A — Automated QA/Gas Report (4naly3er)

> **The content below is automated, third-party tool output, not authored findings.** It is the
> canonical C4-style 4naly3er baseline, generated over the in-scope source as the same "bot report"
> baseline used in C4 audits. The full report (4,558 lines: every instance + code link) is attached
> alongside this bundle at [`4naly3er-report.md`](./4naly3er-report.md). 4naly3er's own `M-1`
> ("Centralization Risk for trusted owners") is the tool's generic owner-trust heuristic and is
> **not** a Medium under this audit's owner-trust law — it is retained verbatim below only for
> completeness. The summary tables are reproduced here for at-a-glance reference.

- **Tool:** 4naly3er (`tools/4naly3er`), solc 0.8.26
- **Target:** `yield-claim-nft/src/**` @ `cf75ec9` (run from the writable `workspace/` clone with a 4naly3er-style `remappings.txt`, since the project keeps its remappings in `foundry.toml`, which 4naly3er does not read; the temporary file was removed after the run — the read-only `lib/` source was never modified)
- **Totals:** 18 Gas categories · 30 Non-Critical categories · 12 Low categories · 1 Medium category (generic owner-trust heuristic)

### 4naly3er — Low Issues

| | Issue | Instances |
|-|:-|:-:|
| L-1 | Use a 2-step ownership transfer pattern | 8 |
| L-2 | Some tokens may revert when zero value transfers are made | 11 |
| L-3 | Missing checks for `address(0)` when assigning values to address state variables | 13 |
| L-4 | `abi.encodePacked()` should not be used with dynamic types when passing the result to a hash function such as `keccak256()` | 14 |
| L-5 | Division by zero not prevented | 1 |
| L-6 | Prevent accidentally burning tokens | 18 |
| L-7 | Owner can renounce while system is paused | 2 |
| L-8 | Loss of precision | 2 |
| L-9 | Solidity version 0.8.20+ may not work on other chains due to `PUSH0` | 13 |
| L-10 | Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership` | 7 |
| L-11 | Sweeping may break accounting if tokens with multiple addresses are used | 1 |
| L-12 | Upgradeable contract not initialized | 6 |

> 4naly3er L-1/L-10 (2-step ownership) corroborate the carried-over **Q-04**; L-3 corroborates the
> known zero-address NC items. None of the automated Low rows surface a new HM exploit path beyond
> the manually-analysed findings above.

### 4naly3er — Medium Issues

| | Issue | Instances |
|-|:-|:-:|
| M-1 | Centralization Risk for trusted owners | 54 |

> Suppressed as a Medium under this audit's Law 3 (trusted, non-malicious owner). The non-obvious
> owner *footguns* among these are the ones surfaced manually above (L-04, L-05, L-07).

### 4naly3er — Non-Critical Issues (categories)

| | Issue | Instances |
|-|:-|:-:|
| NC-1 | Replace `abi.encodeWithSignature`/`abi.encodeWithSelector` with `abi.encodeCall` | 2 |
| NC-2 | Missing checks for `address(0)` when assigning values to address state variables | 13 |
| NC-3 | Array indices should be referenced via `enum`s rather than numeric literals | 12 |
| NC-4 | Use `string.concat()` / `bytes.concat()` instead of `abi.encodePacked` | 2 |
| NC-5 | `constant`s should be defined rather than using magic numbers | 5 |
| NC-6 | Control structures do not follow the Solidity Style Guide | 8 |
| NC-7 | Consider disabling `renounceOwnership()` | 7 |
| NC-8 | Duplicated `require()`/`revert()` checks should be refactored | 22 |
| NC-9 | Events should use parameters to convey information | 1 |
| NC-10 | Event missing indexed field | 10 |
| NC-11 | Events for critical parameter changes should contain old and new value | 30 |
| NC-12 | Function ordering does not follow the style guide | 4 |
| NC-13 | Functions should not be longer than 50 lines | 146 |
| NC-14 | Change `int` to `int256` | 4 |
| NC-15 | Lack of checks in setters | 14 |
| NC-16 | Missing event for critical parameter change | 4 |
| NC-17 | Incomplete NatSpec: `@param` missing | 3 |
| NC-18 | Use a `modifier` instead of `require/if` for a special `msg.sender` actor | 16 |
| NC-19 | Consider using named mappings | 15 |
| NC-20 | Owner can renounce while system is paused | 2 |
| NC-21 | Redundant `return` when a named return variable is defined | 1 |
| NC-22 | Take advantage of Custom Error's return value property | 4 |
| NC-23 | Strings should use double quotes rather than single quotes | 8 |
| NC-24 | Contract does not follow the style guide's suggested layout ordering | 3 |
| NC-25 | Use underscores for number literals | 2 |
| NC-26 | Internal/private names should begin with an underscore | 2 |
| NC-27 | Event is missing `indexed` fields | 33 |
| NC-28 | Constants should be defined rather than using magic numbers | 2 |
| NC-29 | `public` functions not called internally should be `external` | 3 |
| NC-30 | Variables need not be initialized to zero | 2 |

> Gas-optimization categories (18, e.g. custom errors over revert strings, `immutable` for
> constructor-only state, `unchecked` for non-overflowing ops) are in the attached full report.
