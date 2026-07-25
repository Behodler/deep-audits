# Carryover QA Report — originating audit 13 (carried into yield-claim-nft-19)

> **Carryover QA report — audit 13** (cut down from `reports/yield-claim-nft-13/submissions/qa-report.md`).
> Retained below (still open / untriaged as of audit 19): **L-09, L-10, Q-10**.
> Removed as no longer live: **none** — every finding in audit 13's QA report is still open. Structural sections not copied: the preamble/summary and "Appendix: Automated QA / Gas Report (4naly3er)".
> Labels are the originals — gaps in the sequence are the removals above, not omissions.
> Line numbers and links were accurate at the originating commit (`run-13 commit`); re-verify against current HEAD (`d4cc563`).
> These entries were **not re-examined** in the run-19 range (stories 046/047, dispatcher/streamer surface); they are carried for recall (Law 1), and their `lastSeenRun` was deliberately **not** bumped.
>
> ⚠ **Label-collision warning:** run-19's own C4 labels `L-04`/`L-05` are **new, unrelated findings** (ledger `L-19` / `9fdcb0c6…` and `L-20` / `1c1e0001…`). The `L-04`/`L-05` below are the **ledger** entries `674c799b…` / `e527a712…`. Do not conflate.
>
> *The text below is a verbatim copy of the retained sections of the original report.*

---

## Low Risk Findings

### [L-09] Uniboost has no `hookTypeId` guard: an unwired/wrong dispatch hook silently accrues zero phUSD debt <!-- id: ycn13l9 -->

**Location:** [`src/dispatchers/Uniboost.sol#L184`](../../../lib/yield-claim-nft/src/dispatchers/Uniboost.sol#L184) (dispatch path) →
base `src/dispatchers/ATokenDispatcherV2.sol#L125` (`hook.onDispatch(minter, amount, extraData)`),
default hook seeded at `ATokenDispatcherV2.sol#L51` (`hook = new DefaultDispatchHook()`),
empty no-op at [`src/hooks/DefaultDispatchHook.sol#L12`](../../../lib/yield-claim-nft/src/hooks/DefaultDispatchHook.sol#L12).

**Trajectory (read this before triaging):** this is the same fail-open class that was first reported as a
**Medium (M-04)** on the original dispatcher and subsequently recurred and was **owner-accepted won't-fix
as Q-08** (`96c60b72`, BalancerPoolerV2). Uniboost is the **third** dispatcher to copy the
unconditional-hook pattern, and it is the one most analogous to the **M-04-fixed NudgeRatchet**, which
*does* carry the `hookTypeId` marker guard. Because it sits on a distinct contract/function, it has a
distinct fingerprint and is therefore not auto-suppressed under the Q-08 precedent — it is surfaced here
for an explicit owner decision rather than pre-set to won't-fix.

**Description:** `Uniboost` routes dispatched prime through a configurable mint-debt hook, but the base
`ATokenDispatcherV2._dispatch` calls `hook.onDispatch` **unconditionally** — there is no `hookTypeId()`
marker check (unlike the M-04-fixed `NudgeRatchet`). The constructor defaults `hook` to a freshly
deployed `DefaultDispatchHook`, whose `onDispatch` is an empty no-op. If the owner opens dispatches
**without** first calling `setHook(uniboostMintDebtHook)` (or wires a mismatched hook), every Uniboost
dispatch forwards prime with **zero phUSD mint-debt accrued**, with no revert and no event.

**Impact:** Backing-integrity feature failure — no theft, no removal of held assets. phUSD that should
have been backed by accrued debt is simply never accrued during the unwired window. Recoverable
(`setHook` can be corrected at any time), but debt that should have accrued during the window is
lost-not-accrued: there is **no retroactive backfill**. The prime itself is retained on-chain. Trigger is
owner-config dependent; there is no external/permissionless trigger.

**Recommendation:** Apply the same `hookTypeId()` marker guard used by the M-04-fixed `NudgeRatchet` to
the Uniboost dispatch path — assert `hook.hookTypeId() == EXPECTED_HOOK_TYPE_ID` and fail **closed** on
the default/unwired hook, mirroring story-037. Operationally, always `setHook` before opening dispatches
and verify debt accrual on the first dispatch.

```solidity
// in _dispatch, before hook.onDispatch(...)
require(hook.hookTypeId() == EXPECTED_HOOK_TYPE_ID, "Uniboost: hook not wired");
```

---

### [L-10] `UniboostMintDebtHook.scale` derived from the hook's own ctor `primeToken_`, not tied to the dispatcher's prime <!-- id: ycn13l10 -->

**Location:** [`src/hooks/UniboostMintDebtHook.sol#L81-L89`](../../../lib/yield-claim-nft/src/hooks/UniboostMintDebtHook.sol#L81-L89)
(`scale = 10 ** (18 - d)` baked immutable at L89, `d` read from `primeToken_` at L85);
dispatcher's true prime returned by [`src/dispatchers/Uniboost.sol#L97`](../../../lib/yield-claim-nft/src/dispatchers/Uniboost.sol#L97) (`primeToken()`).

**Description:** `UniboostMintDebtHook` takes `dispatcher_` and `primeToken_` as **two separate,
same-typed `address` arguments** and bakes `scale = 10 ** (18 - primeToken_.decimals())` as an immutable
in the constructor. There is **no on-chain cross-validation** that `primeToken_` equals the dispatcher's
actual `_primeToken`. If the owner passes a `primeToken_` whose `decimals()` differ from the dispatcher's
real prime, every `onDispatch` accrues debt at the wrong scale. This is non-obvious precisely because the
M-03/M-04 fixes would lead a competent owner to assume the scale is bound to the dispatcher.

**Impact:** Two directions:
- **Under-scale** (hook `primeToken_` has *more* decimals than the real prime): debt is under-stated →
  fails safe (over-backed, no loss).
- **Over-scale** (hook `primeToken_` has *fewer* decimals than the real prime): debt is over-stated → a
  later `pull()` mints **more phUSD than `ratio * amount` warrants → unbacked phUSD over-mint.** This
  over-scale tail is the Law-1 reason this finding is **kept** even at Low rather than dropped.

The decimal **math itself** is correct and guarded (`d <= 18`, the M-03 generalization) and is explicitly
*not* re-raised here. Mis-scale is detectable on the first dispatch (`DebtAccrued` amounts off by orders
of magnitude). Tier-3 confirmed the math cannot over-mint under a correct deployment (backing ≥ 2:1).

**Classification (borderline Low/Medium, deliberately scrutinized):** Kept Low — no external requirement,
no attacker, no runtime trigger; a single atomic owner deploy error; detectable pre-`pull()`. Partially
recoverable: `scale` is immutable, so an over-scaled hook must be replaced (deploy new hook + re-wire);
phUSD already over-minted via `pull()` during the window is the irrecoverable portion.

**Recommendation:** Add a constructor assertion tying the hook's scale to the dispatcher's real prime,
removing the dual-argument ambiguity:

```solidity
require(IUniboost(dispatcher_).primeToken() == primeToken_, "primeToken != dispatcher prime");
// or derive d directly: uint8 d = IERC20Metadata(IUniboost(dispatcher_).primeToken()).decimals();
```

> **Cross-reference:** open ledger **L-07** (`ac91a046`) is the same decimal-config family on a different
> surface (`replaceDispatcher` stale price). Distinct fingerprint — do **not** merge.

#### Instance note — [L-06] `pool()` buy-and-pool single-sided LP-add MEV (Uniboost instance)

**Location:** [`src/dispatchers/Uniboost.sol#L244-L245`](../../../lib/yield-claim-nft/src/dispatchers/Uniboost.sol#L244)
(`addLiquidity(..., 0, 0, address(this), block.timestamp)` — 0/0 mins, `deadline = block.timestamp`).

This is a **second instance** of already-open ledger **L-06** (`342075df`) on the new Uniboost dispatcher;
it is annotated under the existing L-06 entry and is **not** a new label or a regression (L-06 is open,
not fixed). Uniboost `pool()` performs a single-sided LP add relying solely on off-chain keeper-supplied
`minPairOut`/`minTargetOut` floors plus a post-call `minLP` floor, with **no on-chain oracle/TWAP
reference**; the `addLiquidity` call itself passes `0/0` mins and `deadline = block.timestamp`. Impact is
bounded MEV slippage on **protocol-owned liquidity** (not user funds), operator-triggered, bounded by the
supplied floors + `minLP`. Recommendation (same as L-06): introduce an on-chain price reference
(oracle/TWAP) to bound the single-sided add beyond the off-chain keeper floors.

#### Instance note — [L-05] `donationSplit` ↔ hook `ratio` cross-contract decoupling (Uniboost instance)

**Location:** [`src/dispatchers/Uniboost.sol#L138`](../../../lib/yield-claim-nft/src/dispatchers/Uniboost.sol#L138)
(`setDonationSplit`) ↔ [`src/hooks/UniboostMintDebtHook.sol#L96`](../../../lib/yield-claim-nft/src/hooks/UniboostMintDebtHook.sol#L96) (`setRatio`).

This is a **second instance** of already-open ledger **L-05** (`e527a712`) on the new Uniboost
dispatcher/hook pair; annotated under the existing L-05 entry, **not** a new label or regression. The
Uniboost `donationSplit` and the `UniboostMintDebtHook.ratio` are set on two different contracts with no
on-chain coupling invariant. No solvency break: `ratio` is hard-capped at `MAX_RATIO = 50`, so worst-case
accrued debt is ≤ 50% of dispatched prime while retained value is ~100% at dispatch (Tier-3 confirms
≥ 2:1 backing; 0%/100% edges verified safe). Impact is a transparency/config-coupling gap, not value at
risk. Recommendation (same as L-05): introduce an on-chain guardrail tying `donationSplit` and
`hook.ratio` together.

---

## QA Findings

### [Q-10] `setPool` repoints `_pairToken` without re-validating the stored custom `_primeToPairPath` <!-- id: ycn13q10 -->

**Location:** [`src/dispatchers/Uniboost.sol#L118-L131`](../../../lib/yield-claim-nft/src/dispatchers/Uniboost.sol#L118)
(`setPool` / `_setPool`, `_pairToken = pairToken_` at L131); stored path validated only in
`setPrimeToPairPath` at [`Uniboost.sol#L159-L161`](../../../lib/yield-claim-nft/src/dispatchers/Uniboost.sol#L159).

**Description:** `setPool` repoints `_pairToken` without clearing or re-asserting the stored custom
`_primeToPairPath`. The setter `setPrimeToPairPath` enforces `path[path.length - 1] == _pairToken`, but
`_setPool` does not re-check that invariant when the pair token changes. A stored path whose end token no
longer matches the repointed `_pairToken` therefore silently violates the setter's own advertised
invariant (path end == pairToken).

**Impact:** No theft, no silent value leak. A stale path would route the next `pool()` swap toward the
wrong token — but the failure is **loud**: the next `pool()` reverts or under-funds against its on-chain
`minPairOut`/`minTargetOut` floors, and any stranded dust is sweepable via `rescueERC20`. This is a
state-handling QA item (revert/dust ceiling), not a value-leak Low. Surfaced because a non-malicious
owner could be surprised the stored path is not re-validated on a pair-token change.

**Recommendation:** Clear or re-assert `_primeToPairPath` inside `_setPool` when the pair token changes.

```solidity
function _setPool(address newPool) internal {
    // ... existing pair-token resolution ...
    _pairToken = pairToken_;
    delete _primeToPairPath; // drop stale custom path; falls back to direct [prime, pair]
}
```

#### Instance note — [L-02] `setRatio` accepts `ratio == MAX_RATIO` vs "strictly <" NatSpec (Uniboost instance)

**Location:** [`src/hooks/UniboostMintDebtHook.sol#L96-L97`](../../../lib/yield-claim-nft/src/hooks/UniboostMintDebtHook.sol#L96)
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
