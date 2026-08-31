# Spec-Conformance Report (Law 2 — Faithfulness)

**Project:** phoenix-nft-staking
**Run:** phoenix-nft-staking-16
**Audited commit (HEAD):** `5f863d27ebbab5df20131a4592996537cd8bf503` (`5f863d2`)
**Scope:** Law-2 story / spec / invariant conformance — *does the shipped code do what the
documented stories and Critical Invariants say it does?*

> This report is **separate from the QA bundle**. It tracks deviations between the *stated spec*
> (`[story-NNN]` commits, `lib/phoenix-nft-staking/docs/`, and the project `CLAUDE.md` "Critical
> Invariants") and the *shipped behavior*. A faithfulness deviation is **additive**: where a
> deviation also carries asset/value/availability impact it ALSO holds its own H/M label and
> individual submission under Law 1 — the F-XX entry is the faithfulness cross-reference, **not**
> a downgrade of the security severity.

---

## Conformance verdict

The bulk of this codebase ships **faithfully**. In particular:

- **The entire BatchNFTMinter hardening arc — story-009 / story-013 / story-014 / story-015 /
  story-016 — conforms.** Each story's intended behavior is reflected in the shipped minter; no
  conformance gap was found across that arc.
- **NFTStaker M-01 and M-03 ship faithfully.** The M-03 total-staked APY-as-policy model
  (per-NFT emission sized against the staked subset `S = totalStaked * latestPrice`) is
  implemented as specified in the steady-state staking/unstaking/claim paths, and M-01 conforms.
  There is **no** conformance gap in the core reward-accounting code itself.

Only **three** spec-conformance deviations were found, all listed below:

| ID | Cross-ref | Classification | Law impacted | Carries security severity? |
|----|-----------|----------------|--------------|----------------------------|
| **F-01** | **M-02** | faithful-but-invariant-broken | **Law 1 + Law 2** | **YES — live Medium (M-02)** |
| F-02 | L-06 | spec-precision | Law 2 | No (Low / wording) |
| F-03 | L-07 | doc-drift | Law 2 | No (QA / docs) |

> **Reader note on F-01:** F-01 is **not** documentation noise. It is the faithfulness face of a
> **live Medium security finding (M-02)** — a value-leak / over-emission path. It appears in this
> report *additionally*, because the same root cause also breaks a stated Critical Invariant. Its
> security severity is governed by the M-02 individual submission, not by this report.

---

## F-01 — `emergencyWithdraw` violates the M-03 "no participation multiplier" Critical Invariant

- **Classification:** faithful-but-invariant-broken
- **Law impacted:** **Law 1 (security — live Medium)** *and* Law 2 (faithfulness)
- **Cross-reference:** **M-02 (live Medium — individual submission)** · fingerprint `911c54fd…b029e5a70`
- **Status:** OPEN — carries a live security impact; **do not collapse into QA**

### The stated spec / invariant (violated)

From `lib/phoenix-nft-staking/CLAUDE.md`, "Critical Invariants to Preserve in Tests" —
*APY-as-floor for latest minter*:

> "With `R = totalStaked * latestPrice * targetAPY / SECONDS_PER_YEAR`, per-NFT emissions are
> `latestPrice * targetAPY / SECONDS_PER_YEAR`. The most-recent minter (who paid `latestPrice`)
> earns exactly `targetAPY`. … **There is no participation multiplier** — a lone staker earns
> `targetAPY` (or the geometric-growth multiple), not `N * targetAPY`."
> (See `NFTStakerSustainability.t.sol::test_M03_LowParticipationDoesNotInflateAPY`.)

The invariant is an explicit spec promise: per-NFT emission must be **participation-independent**,
because the emission rate `R` is continuously re-sized against the staked subset
`S = totalStaked * latestPrice`. Per the partnered Solvency invariant text, the contract is
designed so that `R` tracks `totalStaked` — `stake`/`unstake` "re-size `R` against the new
`totalStaked` … invoke `_recomputeSchedule()` *after* the `totalStaked` mutation."

### The actual shipped behavior (deviation)

`emergencyWithdraw` decrements `totalStaked` but **does not** call `_updatePool` or
`_recomputeSchedule`, and never advances `lastRewardTime`:

- [`src/NFTStaker.sol#L538-L561`](https://github.com/Behodler/phoenix-nft-staking/blob/5f863d27ebbab5df20131a4592996537cd8bf503/src/NFTStaker.sol#L538-L561) — `emergencyWithdraw`
- [`src/NFTStaker.sol#L545`](https://github.com/Behodler/phoenix-nft-staking/blob/5f863d27ebbab5df20131a4592996537cd8bf503/src/NFTStaker.sol#L545) — `totalStaked -= amount;` with no schedule recompute

Because `rewardRate` stays sized for the **pre-exit (larger)** pool while `totalStaked` has
shrunk, the next `_updatePool` (fired by any later stake/unstake/claim via `_syncBudget`, or by
`topUp`/`setTargetAPY`) settles `elapsed * R_old` over the **smaller** `totalStaked`, inflating
`accRewardPerShare` for survivors by `oldTotal / newTotal` across the whole
`[lastRewardTime, now]` window (PoC: 1000 → 10 = **100x**). That `oldTotal / newTotal` factor is
**exactly the participation multiplier the M-03 invariant forbids** — survivors earn
`oldTotal/newTotal` more per NFT than the `targetAPY` policy authorizes.

This is faithful in form (the escape hatch returns principal and stays dispatcher-independent as
designed) but **invariant-broken** in effect: a stated Critical Invariant no longer holds after an
emergency exit.

### Security impact (Law 1)

This deviation carries a **live Medium** (over-emission / runway drain of real protocol phUSD,
redistributed to surviving stakers). It is **not** insolvency — the Solvency invariant holds
throughout and over-draw is clamped to `rewardBudget` — and it is **not** principal theft.
Full attack path, plausibility analysis, severity dispute, PoC, and recommendation are in the
**M-02 individual submission** (`submissions/M-02-*.md`). Triage M-02, not this entry, for the
security fix.

---

## F-02 — "Solvency holds at ALL times" Critical Invariant is only eventually-consistent

- **Classification:** spec-precision (wording too strong; no exploit)
- **Law impacted:** Law 2 (faithfulness — spec precision)
- **Cross-reference:** L-06 (Low / QA) · fingerprint `f293859f…84ea5453`

### The stated spec / invariant (imprecise)

From `lib/phoenix-nft-staking/CLAUDE.md`, "Critical Invariants to Preserve in Tests" — *Solvency*:

> "**Solvency (always):** `balance == rewardBudget + committedDebt` holds at *all* times. …
> `_recomputeSchedule` resizes `rewardBudget` to `V - committedDebt` where `V = balance + mintDebt`
> … `pull()` swaps `mintDebt` for `balance` 1:1 and is invariant-neutral …"

The wording "holds at *all* times" asserts **strict, continuous** equality against the on-chain
balance.

### The actual shipped behavior (deviation)

`_recomputeSchedule` sizes the budget on `V = balance + dispatcherHook.mintDebt()`, but `topUp`
and `setTargetAPY` recompute **without a preceding `pull()`**:

- [`src/NFTStaker.sol#L264-L284`](https://github.com/Behodler/phoenix-nft-staking/blob/5f863d27ebbab5df20131a4592996537cd8bf503/src/NFTStaker.sol#L264-L284) — `_recomputeSchedule` (reached via `topUp` / `setTargetAPY`)

So in the window where `mintDebt > 0` is un-pulled, `rewardBudget + committedDebt` over-states the
on-chain `balance` by **exactly the un-pulled `mintDebt`** — the literal invariant is transiently
**false**. It self-heals on the next `_syncBudget`/`pull()` (strict equality restored). The
over-statement is phantom and **never payable**: `_safePay` gates every payout on the actual
`balanceOf` and reverts on a real shortfall.

The faithful statement is `balance + mintDebt == rewardBudget + committedDebt`, or equivalently
"strict on-balance equality holds **only post-`_syncBudget`** (eventually-consistent)." This is a
**spec-precision** deviation — the implementation is sound; the invariant prose over-claims. No
value is extractable; see L-06 for the full self-healing analysis and the recommended re-wording.

---

## F-03 — Docs label a superseded reward model as the "current spec"

- **Classification:** doc-drift (documentation describes behavior other than what shipped)
- **Law impacted:** Law 2 (faithfulness — doc-vs-code conformance)
- **Cross-reference:** L-07 (QA) · fingerprint `c3cda1d8…b30e9595e4`

### The stated spec (stale / contradicts shipped code)

`lib/phoenix-nft-staking/docs/runway-dynamics-and-apy-as-policy.md` labels the **total-supply `T`**
model as the live spec:

> Line ~96: "The analysis above is the **total-supply** formulation (**current spec**). The
> total-staked alternative (see §3) adds a second feedback channel …"
>
> Line ~142: "**Current spec** defines `T` from `nftMinter.totalSupply(stakedId)` — the entire
> minted cohort. An alternative is `T` computed from `totalStaked` …"

`lib/phoenix-nft-staking/docs/design.md` is fully stale — it still describes the abandoned
**540-day fixed-window** model:

> Line 37: "funds a single emission schedule over `windowDuration` (default **540 days**)."
> Line 54: `uint256 public windowDuration;              // default 540 days`
> Line 72: `uint256 public constant DEFAULT_WINDOW = 540 days;`

### The actual shipped behavior (deviation)

The shipped code implements the **total-staked** model (audit M-03): per-NFT emission is sized
against the staked subset `S = totalStaked * latestPrice`, not the total-supply notional `T`, and
there is **no** fixed 540-day window — the schedule is recomputed dynamically (`runway = V / R`).
The on-chain event field name `totalNFTValue` is even documented in `CLAUDE.md` item 10 as having
"shifted in audit M-03 from aggregate `T` to staked-subset `S`."

The documents therefore describe **different behavior than what ships**: `runway-dynamics…md`
calls a superseded model the "current spec", and `design.md` describes a model (540-day fixed
window) that no longer exists in code. **Security impact is nil** (the *code* is the M-03 model and
is correct); this is surfaced here only so the deviation is not lost (Law 2). The downstream
operational hazard — an owner consulting stale runway tables to mis-size `targetAPY` — and the
doc-update recommendation are tracked in L-07.

---

## Summary

Three Law-2 deviations, no broader conformance gap. **F-01 is a live-Medium cross-reference
(M-02), presented additively and explicitly not collapsed into QA.** F-02 (spec-precision) and
F-03 (doc-drift) carry no security severity. The BatchNFTMinter hardening arc
(story-009/013/014/015/016) and NFTStaker M-01/M-03 ship faithfully.
