# Carryover QA report — originating audit 13 (carried into yield-claim-nft-23)

> **Carryover QA report — audit 13** (pruned copy of `yield-claim-nft/reports/13/submissions/qa-report.md`, taken from the run-22 pruned carryover `reports/22/submissions/carryover/qa-report-13.md` — whose finding text is itself the verbatim original — re-checked against the ledger at run 23). Carried at `c5ad56d` (`c5ad56df5b5dc3f68a6f6a5e4e5f95ef532a2238`), run 23, branch `master`.
> Retained (still live in the ledger: `open` / `qa-bundled` / `fix-pending`): **L-09, L-10, Q-10**.
> Removed as no longer live: **none since run 22** (no ledger status changed). 
> Labels are the originals — gaps in the sequence are removals (named above or in the originating/earlier carryover headers), not omissions. Global issue IDs in `<!-- id: -->` stamps are the originating run's, copied verbatim (never restamped).
> **Why still valid:** the source changes in this run's range `0fd6bdf..c5ad56d` are the new `src/NFTBonfire.sol` (story-053), the deletion of `src/dispatchers/BalancerPoolerV2.sol` and the Balancer interfaces (story-050), and comment/NatSpec-only renames in `NudgeRatchetDelayRelease.sol`, `Uniboost.sol` and `IUniboostPooler.sol`. No retained entry's code logic changed (`NFTMinterV2.sol`, `src/hooks/**` and `src/migration/**` are unchanged), no fix landed for any of them, and no human triage disposed of them, so each is still live exactly as last reported. Not being re-observed by a run-23 tool is **not** a fix.
> Line numbers and links are as written at the originating commit; relative links resolve from the **original** report's directory (`reports/13/submissions/`), not from this `carryover/` folder. Original report: [`reports/13/submissions/qa-report.md`](../../../13/submissions/qa-report.md). Re-verify every location against `c5ad56d` before acting.
> *The finding text below is a verbatim copy of the originating report. `Carryover status (run 21 …)` blocks are kept as history; the run-23 status of every entry is the table below.*
>
> | Ledger label | issueId | Fingerprint | Status | First seen | Last seen (after run 23) | Re-observed in run 23 | Contract |
> |---|---|---|---|---|---|---|---|
> | L-09 | — | `563df2e64a72b125fab353630c059e37f9ecddffe229b205d71730c378165854` | `open` | yield-claim-nft-13 | yield-claim-nft-19 | no (carried; code unchanged) | `src/dispatchers/Uniboost.sol` |
> | L-10 | — | `e064b2de7a307fceec8b21249bba7805e2c9ee29faf54756620b5a7e13cf6c4a` | `open` | yield-claim-nft-13 | yield-claim-nft-19 | no (carried; code unchanged) | `src/hooks/UniboostMintDebtHook.sol` |
> | Q-10 | — | `7c4bcba272c5f22b36cba788b013cdb1582b55f6e6bf1661e8633636574a667d` | `open` | yield-claim-nft-13 | yield-claim-nft-13 | no (carried; code unchanged) | `src/dispatchers/Uniboost.sol` |

<details><summary>Provenance: run-22 carryover header (kept verbatim, including the nested run-21 provenance notes)</summary>

> **Carryover QA report — audit 13** (pruned copy of `yield-claim-nft/reports/13/submissions/qa-report.md`, taken from the run-21 pruned carryover `reports/21/submissions/carryover/qa-report-13.md` — whose finding text is itself the verbatim original — re-checked against the ledger at run 22). Carried at `0fd6bdf` (`0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630`), run 22, branch `master`.
> Retained (still live in the ledger: `open` / `qa-bundled` / `fix-pending`): **L-09, L-10, Q-10**.
> Removed as no longer live: **none since run 21** (the retained set is unchanged; entries disposed before run 21 are named in the provenance notes below).
> Labels are the originals — gaps in the sequence are removals (named above or in the originating/earlier carryover headers), not omissions. Global issue IDs in `<!-- id: -->` stamps are the originating run's, copied verbatim (never restamped).
> **Why still valid:** the only source change in this run's range `267660b..0fd6bdf` is the new file `src/migration/UniPoolerCutoverEscrow.sol` (plus its tests and `test/mocks/MockV3ExitRouter.sol`). None of the contracts under the entries below changed, no fix landed for any of them, and no human triage has disposed of them, so each is still live exactly as last reported. Not being re-observed by a run-22 tool is **not** a fix.
> Line numbers and links are as written at the originating commit; relative links resolve from the **original** report's directory (`reports/NN/submissions/`), not from this `carryover/` folder. Re-verify every location against `0fd6bdf` before acting.
> *The finding text below is a verbatim copy of the originating report. `Carryover status (run 21 …)` blocks were added by the run-21 qa-bundler and are kept as history; the run-22 status of every entry is the table below.*
>
> | Ledger label | issueId | Fingerprint | Status | First seen | Last seen (after run 22) | Re-observed in run 22 | Contract |
> |---|---|---|---|---|---|---|---|
> | L-09 | — | `563df2e64a72b125fab353630c059e37f9ecddffe229b205d71730c378165854` | `open` | yield-claim-nft-13 | yield-claim-nft-19 | no (carried; code unchanged) | `src/dispatchers/Uniboost.sol` |
> | L-10 | — | `e064b2de7a307fceec8b21249bba7805e2c9ee29faf54756620b5a7e13cf6c4a` | `open` | yield-claim-nft-13 | yield-claim-nft-19 | no (carried; code unchanged) | `src/hooks/UniboostMintDebtHook.sol` |
> | Q-10 | — | `7c4bcba272c5f22b36cba788b013cdb1582b55f6e6bf1661e8633636574a667d` | `open` | yield-claim-nft-13 | yield-claim-nft-13 | no (carried; code unchanged) | `src/dispatchers/Uniboost.sol` |

<details><summary>Provenance notes from the run-21 carryover header (kept verbatim: label-collision warnings, facet and instance notes)</summary>

> **Carryover QA report — audit 13** (pruned copy of `yield-claim-nft/reports/13/submissions/qa-report.md`; originating commit `aa86be6`; carried at `267660b`, run 21).
> Retained (still `open` in the ledger): **L-09, L-10, Q-10**.
> Removed: the instance note for **L-06** (parent `342075dfba` is `wont-fix`). The instance notes for **L-05** and **L-02** are not lost — they are carried under their parent entries in `qa-report-10.md` and `qa-report-08.md`. Preamble/Summary and the 4naly3er appendix are not copied.
> Later-run instance note for L-09 (run-17, PromotionUniV2_Eth — the 4th dispatcher carrying the class) is appended under the parent entry. Note also that run-20's **L-21** (`6867d791`, UniPoolerV2, same fail-open class) is FIX-COMPLETE at `267660b` (see the run-21 QA report) — that fix is per-concrete and does **not** close L-09 on Uniboost/PromotionUniV2_Eth.
> Line numbers and links are as written at the originating commit; relative links resolve from the **original** report's directory (`reports/NN/submissions/`), not from this `carryover/` folder, and many point at the retired `lib/yield-claim-nft/...` reference tree. Re-verify every location against `267660b` before acting.
> Global issue IDs in the `<!-- id: -->` stamps are the originating run's, copied verbatim (never restamped). Where an originating report minted an ID inconsistently (run 08 stamped QA items with `l`), the original stamp is kept and the discrepancy is noted, not corrected.
> *The finding text below each heading is a verbatim copy of the originating report; the `Carryover status` block after each section is added by the run-21 qa-bundler.*

</details>

</details>

---

## Low Risk Findings

### [L-09] Uniboost has no `hookTypeId` guard: an unwired/wrong dispatch hook silently accrues zero phUSD debt <!-- id: ycn13l9 -->

**Location:** [`src/dispatchers/Uniboost.sol#L184`](../../../../lib/yield-claim-nft/src/dispatchers/Uniboost.sol#L184) (dispatch path) →
base `src/dispatchers/ATokenDispatcherV2.sol#L125` (`hook.onDispatch(minter, amount, extraData)`),
default hook seeded at `ATokenDispatcherV2.sol#L51` (`hook = new DefaultDispatchHook()`),
empty no-op at [`src/hooks/DefaultDispatchHook.sol#L12`](../../../../lib/yield-claim-nft/src/hooks/DefaultDispatchHook.sol#L12).

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

> **Carryover status (run 21, `267660b`).** Ledger **L-09** · fingerprint `563df2e64a72b125fab353630c059e37f9ecddffe229b205d71730c378165854` · status **`open`** · severity `low` · first seen `yield-claim-nft-13` · last seen `yield-claim-nft-19` · re-observed by run-21 inputs: **no (not re-raised; absence of a re-raise is not a fix)**.

#### Later instance (run 17, verbatim from `reports/17/submissions/qa-report.md`)

##### [L-09] Unwired dispatch hook has no `hookTypeId` guard — fail-open zero-debt accrual (carryover, 4th dispatcher) <!-- id: ycn17l9 -->

**Location:** [`PromotionUniV2_Eth.sol` `_dispatch`](../../../../lib/yield-claim-nft/src/dispatchers/PromotionUniV2_Eth.sol#L255) → base `ATokenDispatcherV2._dispatch → hook.onDispatch(GROSS)`
**Original report:** [reports/yield-claim-nft/13/submissions/qa-report.md](../../13/submissions/qa-report.md) · **Carryover stub:** [`carryover/L-09-CARRYOVER.md`](./carryover/L-09-CARRYOVER.md) · **Fingerprint:** `563df2e6…`

**Status:** carryover, still-open — confirmed **Low**; kept OPEN and DISTINCT from the wont-fix Q-08 (BalancerPoolerV2, a separate contract/fingerprint) and NOT re-filed.

**Description (this-run instance):** `PromotionUniV2_Eth` reuses the base `ATokenDispatcherV2._dispatch → hook.onDispatch(GROSS)` path with **no `hookTypeId`/`keccak256` guard** (source-confirmed: the file declares no such literal), and the constructor defaults `hook` to the no-op `DefaultDispatchHook`. If the owner forgets to `setHook`, NFTs mint while **zero phUSD mint-debt accrues**. This is the fourth dispatcher to carry the M-04 fail-open class (M-04 NudgeRatchet = fixed with a guard; Q-08 BalancerPoolerV2 = wont-fix; L-09 Uniboost = open; now PromotionUniV2_Eth). The hook *call* itself is faithful (gross amount passed) — the gap is the fail-open. Story-044 faithfulness record **F-02-044 reconciles here**; no separate finding minted.

**Recommendation / safe-config guidance:** Apply the M-04-fixed NudgeRatchet `hookTypeId()` marker guard to this dispatch path (fail-closed on a default/unwired hook). Operationally: always `setHook` before opening dispatches, and verify debt accrual on the first dispatch.

---

### [L-10] `UniboostMintDebtHook.scale` derived from the hook's own ctor `primeToken_`, not tied to the dispatcher's prime <!-- id: ycn13l10 -->

**Location:** [`src/hooks/UniboostMintDebtHook.sol#L81-L89`](../../../../lib/yield-claim-nft/src/hooks/UniboostMintDebtHook.sol#L81-L89)
(`scale = 10 ** (18 - d)` baked immutable at L89, `d` read from `primeToken_` at L85);
dispatcher's true prime returned by [`src/dispatchers/Uniboost.sol#L97`](../../../../lib/yield-claim-nft/src/dispatchers/Uniboost.sol#L97) (`primeToken()`).

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

> **Carryover status (run 21, `267660b`).** Ledger **L-10** · fingerprint `e064b2de7a307fceec8b21249bba7805e2c9ee29faf54756620b5a7e13cf6c4a` · status **`open`** · severity `low` · first seen `yield-claim-nft-13` · last seen `yield-claim-nft-19` · re-observed by run-21 inputs: **no (not re-raised; absence of a re-raise is not a fix)**.

---

## QA Findings

### [Q-10] `setPool` repoints `_pairToken` without re-validating the stored custom `_primeToPairPath` <!-- id: ycn13q10 -->

**Location:** [`src/dispatchers/Uniboost.sol#L118-L131`](../../../../lib/yield-claim-nft/src/dispatchers/Uniboost.sol#L118)
(`setPool` / `_setPool`, `_pairToken = pairToken_` at L131); stored path validated only in
`setPrimeToPairPath` at [`Uniboost.sol#L159-L161`](../../../../lib/yield-claim-nft/src/dispatchers/Uniboost.sol#L159).

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

> **Carryover status (run 21, `267660b`).** Ledger **Q-10** · fingerprint `7c4bcba272c5f22b36cba788b013cdb1582b55f6e6bf1661e8633636574a667d` · status **`open`** · severity `qa` · first seen `yield-claim-nft-13` · last seen `yield-claim-nft-13` · re-observed by run-21 inputs: **no (not re-raised; absence of a re-raise is not a fix)**.
