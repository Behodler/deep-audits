# Economic Scan — `src/StableStaker.sol` (regression, story-007)

- **Project:** stable-staker
- **Submodule HEAD:** `f85450b6d73a728f530a97854ecc882151695cd8` (`[story-007] Relinquish strategy principal on buffer withdrawal`)
- **Scan type:** economic / value-flow (Tier 2, regression)
- **Profile consumed:** `reports/stable-staker/08/profiles/StableStaker.md`
- **Scope:** withdrawal / buffer / yield-strategy-principal / migration value flow
- **Read-only:** yes (no source modified)
- **Strategy invariant relied on:** `strategy.principalOf(token,this) == poolInfo[token].totalStaked` (profile-VERIFIED), `principalOf >= totalStaked` maintained, `relinquishPrincipal` caps to `clientBalances[holder]` (reflax `AYieldStrategy.sol:643-651`, confirmed).

---

## ECON-001 — Under-custody via capped relinquish on the buffer path — **REFUTED** (no new leak; identical to wont-fix KI#6)

**Concern:** On the buffer path `totalStaked -= amount` (full) but `relinquishPrincipal` caps to available principal; when the strategy is underwater, does the buffer-path withdrawer get paid at par while later stakers/migrants eat a larger socialized loss than under KI#6?

**Verdict: REFUTED.** Story-007 does NOT widen the FCFS-at-par socialization, does not change who-pays, and does not introduce a new value leak. It is strictly an accounting reconciliation.

**Value-flow proof:**

1. The buffer branch (`_routeExit` L697-704) fires only when `guardUnderwater && _isUnderwater && t.balanceOf(this) >= amount`. The payout is `amount` drawn **from the contract's idle buffer**, NOT from redeeming strategy shares (L701-704). The underwater shares are untouched. This is exactly the pre-story-007 cash-flow — story-007 added only the `relinquishPrincipal(token, amount)` book-keeping call at L703.

2. The cap in `relinquishPrincipal` (`amount > clientBalances[holder] ? clientBalances[holder]`, reflax L643-646) **cannot trigger on this path.** The argument `amount` satisfies `amount <= user.amount <= totalStaked` (enforced by `require(user.amount >= amount)` at L284 and the `totalStaked` accumulation invariant). The maintained relation is `principalOf == totalStaked` pre-call (profile-VERIFIED) — never `principalOf < totalStaked` on any reachable path — so `amount <= totalStaked == principalOf == clientBalances[this]`. The relinquish therefore decrements by the **full** `amount`, and `principalOf == totalStaked` is preserved exactly (profile Section 2, independently re-derived). "Under-custody via capped relinquish" requires `clientBalances[this] < amount`, which is unreachable here.

3. **Who absorbs the underwater difference?** The same party as under KI#6 and as the documented "stakers get principal + phUSD only" invariant: the **strategy's surplus / co-clients / protocol**, NOT a new staker victim. After story-007, the relinquished shares (previously backing principal) are repurposed as protocol-owned over-collateralization (`totalValue` unchanged, `totalDeposited` drops, surplus rises by `amount` — confirmed in the M-04 triage and reflax `_relinquishInternal` semantics). The buffer-path withdrawer was already made whole at par before story-007; the only change is that the strategy ledger now correctly reflects the reduced principal instead of leaving a phantom `principalOf > totalStaked` desync.

4. **Magnitude / who-pays delta vs KI#6: zero.** Pre-story-007, the buffer withdrawer got full `amount` at par AND the strategy still booked their principal (the M-04 desync). Post-story-007, the buffer withdrawer still gets full `amount` at par and the strategy correctly drops the principal. No staker's payout changed; no migrant's `min(R,P)/P` credit changed (the credit denominator `P = totalStaked` and the realized `R` both already exclude buffer-withdrawn principal under either version). Story-007 *narrows* harm: it un-bricks the migration post-check (M-04) without moving the loss onto anyone new.

**Economic impact:** none introduced by story-007. The residual underwater FCFS-at-par is the pre-existing, owner-confirmed **intended design** (`69c7666e` / KI#6, wont-fix). Per instruction, NOT re-reported.

**Severity:** N/A (refuted). **Confidence:** high (static; matches profile-VERIFIED invariant + reflax cap semantics).

---

## ECON-002 — `emergencyWithdraw` FCFS-at-par over-redemption still live (`0dca43f3` / M-05) — **CONFIRMED (status note: fix dependency now AVAILABLE)**

**Concern:** Confirm `emergencyWithdraw` still over-redeems shares at par FCFS when underwater; confirm the reflax `relinquishPrincipal` dependency that blocked the pro-rata fix has now landed (so the fix is unblocked). Do NOT re-escalate severity (owner-accepted Medium).

**Verdict: CONFIRMED still live; fix dependency CONFIRMED available.** This is a carryover status note only — severity unchanged (owner-accepted Medium).

**Still-live proof (HEAD `f85450b`):** `emergencyWithdraw` (L322-337) calls `_routeExit(token, amount, false)` at **L334** — `guardUnderwater == false`. With the guard off, `_routeExit` skips the buffer/relinquish branch entirely (L697 short-circuits on `guardUnderwater == false`) and takes the strategy-redeem path L708-710: `strategy.withdraw(token, amount, this)` redeems the **requested** principal `amount` at the depressed underwater price. First callers over-redeem shares and receive full nominal principal; the position drains; late callers receive `< amount` or revert, absorbing the entire pre-existing shortfall. Root cause and code shape are unchanged from `0dca43f3`/M-05 (only line numbers shifted: L304-318 → L322-337). Fingerprint stable.

**Fix-dependency now available (the point of this note):** The pro-rata-haircut fix for M-05 was DEFERRED pending a client-callable `relinquishPrincipal` primitive on the yield strategy (ledger `0dca43f3.triageNote` / `fixDependency`). That primitive **has now landed**:
- Interface: `IYieldStrategy.relinquishPrincipal(address,uint256)` declared (reflax `interfaces/IYieldStrategy.sol:41`).
- Implementation: `AYieldStrategy.relinquishPrincipal` → `_relinquishInternal` (reflax `AYieldStrategy.sol:620-654`), `onlyAuthorizedClient nonReentrant`, caps to `clientBalances[holder]`, decrements `clientBalances` + `totalDeposited` without touching shares.
- StableStaker already consumes it on the `withdraw` buffer path (L703, story-007), proving the wiring/authorization is live.

So the upstream blocker is removed. A pro-rata `emergencyWithdraw` (pay caller `amount * realizableValue / principal`, then `relinquishPrincipal` the difference so books stay in accord) is now implementable entirely within stable-staker against shipped reflax primitives. **The fix is UNBLOCKED.**

**Severity:** Medium (unchanged, owner-accepted — NOT re-litigated). **Confidence:** high. **Action:** carryover — recommend re-opening the deferred fix now that `fixDependency` is satisfied. No new ledger entry; annotate `0dca43f3` with "dependency landed at f85450b; fix unblocked."

---

## ECON-003 — `setYieldStrategy` underwater drain bakes an under-funded position into the new strategy — **CONFIRMED (Low; non-obvious owner footgun; relocation of haircut, no new theft)**

**Concern (story-006):** When the owner swaps strategies and the old strategy is underwater, `_routeExit(totalStaked, guard=false)` (L216) realizes a loss into the new strategy with no post-check. Does this silently bake an under-funded position into the new strategy so the NEXT withdrawer/migrant eats a loss they didn't incur?

**Verdict: CONFIRMED as a real value-relocation footgun, but it is a *relocation* of the already-documented underwater haircut, not a new leak or theft.** Honest severity **Low** (config/owner-gated, bounded by the old strategy's underwater depth).

**Value-flow proof:**

1. `setYieldStrategy` drain at L214-217: `staked = totalStaked`; `_routeExit(token, staked, false)` with guard OFF. Underwater ⇒ strategy-redeem branch (L708-710) returns the **balance delta** `recovered = R_old <= staked` (caps at realizable value). The drained tokens land in idle balance.

2. Re-custody at L231-234: `idleBalance = balanceOf(this)` (now `~= R_old < staked`) is re-deposited via `strategy.deposit(token, idleBalance, this)`, and **the return value is discarded** (see ECON-004 — compounding). Critically, `poolInfo[token].totalStaked` is **never adjusted** across the whole swap — it stays at the full pre-drain nominal `staked`.

3. **Result:** after the swap, `poolInfo.totalStaked == staked` (full nominal) but the new strategy holds only `~R_old < staked` of backing. The realized underwater loss `staked - R_old` is silently baked into the new position. The new strategy is **not** underwater by its own `totalBalanceOf < principalOf` test (it freshly booked `idleBalance` as principal), so the `withdraw` underwater guard (`_isUnderwater`, L666-668) is **blind** to it — exactly the blindness pattern of submitted M-01 (`dab5a656`), but here the shortfall comes from the *drain* rather than from deposit slippage.

4. **Who eats it:** the NEXT healthy `withdraw`/`emergencyWithdraw`/migrant from the **new** strategy. Because the new strategy reads healthy, `withdraw` is NOT blocked; FCFS withdrawers redeem at full nominal until the (now smaller) backing runs out, and the **last** withdrawer(s) / migrant absorbs `staked - R_old`. They did not incur the original underwater loss — it was relocated from the old-strategy underwater dip onto them at par.

5. **Is it new value leak or relocation?** Relocation. Total value out never exceeds realizable backing (no protocol theft, no mint). The loss `staked - R_old` already existed inside the old strategy (the underwater dip). The footgun is that the swap **launders an *underwater* (withdraw-blocked) position into a *healthy-looking* (withdraw-enabled) one**, converting a transient, withdraw-guarded, mean-reverting dip (which KI#6's buffer design deliberately rides out) into a permanently-realized FCFS shortfall on the healthy path. That conversion is the surprise.

**Law-3 classification:** non-obvious owner **footgun** (in scope). A competent non-malicious owner swapping strategies would NOT expect that doing so while the old strategy is transiently underwater permanently bakes the dip-loss into the new position and re-enables unguarded withdrawals against under-backed principal. The source comment (L207-211) documents that *above-par yield* is left behind, but is silent on the *underwater* (R_old < staked) direction. Safe-config guidance: only call `setYieldStrategy` while `!withdrawDisabled(token)` (old strategy at/above par), or pause + migrate instead.

**Relationship to existing findings:** distinct from M-01 (`dab5a656`, deposit-slippage adoption) and from M-02 (`678e6fa2`, `setYieldStrategy` during *active migration*). This is the **healthy-pool swap-while-underwater** sibling on the same function — different root cause (drain-realized loss, not deposit haircut, not missing `!active` guard). KI#7 covers HEALTHY-pool rewire and does NOT bless the underwater-drain conversion. Should be tracked as a new entry (distinct `rootCauseClass`: `swap-while-underwater-bakes-realized-loss`), not folded into M-01/M-02/KI#6.

**Economic impact:** value relocation `<= staked - R_old` (= old strategy's underwater depth at swap time) onto the new strategy's last withdrawer/migrant; transient dip silently converted to permanent par-FCFS realization on the healthy path. **Severity: Low** (owner-gated trigger; bounded magnitude; no theft; mitigated by safe-config). Flag honestly as a footgun, not Medium.

**Confidence:** high on the mechanism (static, profile Section 3 deferred this exact item to Tier 2); Low severity is the honest weight. A PoC would mirror `PoC_M01_AdoptionHaircut.t.sol` with an underwater old strategy — recommend NEEDS-POC only if escalation beyond Low is ever sought.

---

## ECON-004 — Idle-sweep deposit return discarded at L233 — **CONFIRMED (subsumed by submitted M-01 `dab5a656`; not a new finding)**

**Concern (L233):** If `strategy.deposit` haircuts on the `setYieldStrategy` re-custody sweep, the discarded return means booked `totalStaked` over-states custody. Economic impact?

**Verdict: CONFIRMED as a live over-statement, but it is the SAME defect already submitted as M-01 (`dab5a656`).** Not a new finding — confirm-and-link only.

**Proof:** L231-234: `strategy.deposit(token, idleBalance, this)` return value is discarded. For a haircutting (market/AMM) strategy, `deposit` books `credited = idleBalance * (1 - slip) < idleBalance`, so `strategy.principalOf(this) == credited` while `poolInfo.totalStaked` was never reduced and stays at full nominal. This is verbatim the submitted M-01 root cause: "the `setYieldStrategy` adoption sweep `strategy.deposit(...)` discards the return (L215 [now L233]) ... leaves `poolInfo.totalStaked` at full nominal while `strategy.principalOf(this) = idleBalance*(1-slip)`, producing a silent last-withdrawer FCFS shortfall; the underwater guard is blind." (ledger `dab5a656`, status `submitted`, PoC passing).

**Interaction with ECON-003:** on a strategy *swap* while the old strategy is underwater, BOTH defects stack: drain recovers `R_old < staked` (ECON-003), then the haircutting re-deposit books `R_old*(1-slip)` while `totalStaked` stays at full `staked` (ECON-004 / M-01). Combined shortfall on the new-strategy last withdrawer = `staked - R_old*(1-slip)`. Worth noting in the M-01 / ECON-003 writeups as a compounding path, but it does not create a third distinct finding.

**Economic impact:** `totalStaked` over-states custody by the deposit haircut `idleBalance * slip`; last withdrawer FCFS shortfall (= submitted M-01 impact). **Severity:** Medium (inherited from M-01, already submitted). **Confidence:** high. **Action:** none new — covered by `dab5a656`.

---

## Summary table

| id | concern | verdict | severity | disposition |
|---|---|---|---|---|
| ECON-001 | capped-relinquish under-custody / widened FCFS | **REFUTED** | N/A | story-007 reconciles books; identical who-pays/magnitude to wont-fix KI#6 `69c7666e`; relinquish cap unreachable on buffer path. Not reported. |
| ECON-002 | `emergencyWithdraw` FCFS still live (M-05) | **CONFIRMED** (still live) | Medium (owner-accepted, unchanged) | Carryover status note: reflax `relinquishPrincipal` dependency LANDED at `f85450b`; M-05 pro-rata fix now UNBLOCKED. Recommend annotating ledger `0dca43f3`. |
| ECON-003 | `setYieldStrategy` swap-while-underwater bakes realized loss into new strategy | **CONFIRMED** | **Low** (non-obvious owner footgun) | NEW entry candidate (distinct rootCauseClass `swap-while-underwater-bakes-realized-loss`); relocation of documented underwater haircut, no theft; safe-config = swap only at/above par. |
| ECON-004 | idle-sweep deposit return discarded (L233) | **CONFIRMED** | Medium (inherited) | Subsumed by submitted M-01 `dab5a656`; same root cause/line. Compounds with ECON-003. Not a new finding. |

**Net new for this run:** 1 candidate (ECON-003, Low footgun) + 1 carryover status note (ECON-002 / M-05 fix unblocked). No new High/Medium. Story-007 itself introduces no new value leak (ECON-001 refuted) and correctly remediates the M-04 desync without moving loss onto any new party.
