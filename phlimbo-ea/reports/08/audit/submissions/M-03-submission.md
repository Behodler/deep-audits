<!--
ID: pe8m3
C4 Submission Metadata
Title: [M-03] After emergencyTransfer, the documented recovery (beginFlush -> batchClaim -> finalizePromotion) silently destroys the entire staker base's earned promo; the safe ordering is return-then-rotate
Root Cause Link: https://github.com/Behodler/phlimbo-ea/blob/bf42c12e3ad9d834373e8439f0e992aa8870aca4/src/PhlimboV3.sol#L444-L458
Fingerprint: d3a5b3ecc5e3c959731a144a7132de8933fd589f71cb60bcacbbff7aab78275a
Finding: 08-07 (DEDUP-08-07 / CLASS-08-07)
Ledger: V3-M-02 (carryover, open) — ledger text falsified, see mandatory corrections
Commit: bf42c12
Severity: Medium
PoC: workspace/phlimbo-ea/test/probe-08-code2.t.sol
-->

---

# ⛔ SUPERSEDED / CLOSED — DO NOT RE-FILE. NOT A LIVE FINDING.

> **This document is retained ONLY as a reasoning trail. Do not act on it, do not
> re-file it, and do not re-derive a finding from it.** The header block above is
> preserved as-written and is now STALE: it says `Ledger: V3-M-02 (carryover, open)`.
> That is no longer true — see below.

**Status:** This document's parent fingerprint `d3a5b3ec…` (ledger entry **V3-M-02**, internal ID `pe7m2`) was closed **wont-fix / INVALID on 2026-07-15** by owner decision, after a 3-agent re-review (validity-checker, severity-auditor, poc-validator all independently concurring).

### Why the premise is dead

This document argues from a **post-`emergencyTransfer` recovery/resume scenario**. That scenario does not arise. `emergencyTransfer` is a **terminal ejector seat by design** — it is not a state you resume from. Per `SolvencyDetermination.md` §1 ([story-022], commit `1dfda82`, which **predates** this finding):

> "emergencyTransfer is the owner-gated exception that deliberately breaks this invariant (it drains and pauses the contract; recovery is out-of-band)."

There is no supported resume path, so the scenario this document is scoped to never occurs. The "stale promo bookkeeping after emergencyTransfer" shape is **expected behaviour**, not a defect.

### What survived, and where it went

The **destruction MECHANISM described here is real and is still live** — it was never the falsified part. It is tracked elsewhere:

- **`batchClaim` L448** aligns `promoDebt` unconditionally *before* the transfer attempt, and
- **`finalizePromotion` L487** zeroes `unclaimablePromo` with no `claimUnclaimable` analogue.

That mechanism is tracked as **V3-M-03** — fingerprint `019536247d6a…`, status **open**, **top-of-band Medium**, report **[`M-01-submission.md`](M-01-submission.md)**.

The generalised **interim operational rule** derived here was also **ported** to V3-M-03 (its `interimOperationalRule` ledger field and its submission markdown, both on 2026-07-15), re-framed generally so it did not die with this entry:

> **Never rotate a short promo bank — top up first.** A short bank rotated is
> irreversibly destroyed, and the path **never reverts: it reports success.**

### 👉 Read this instead

Anyone who arrived here looking for the **promo-destruction issue** should read **V3-M-03 / [`M-01-submission.md`](M-01-submission.md)**. Everything below this banner is superseded context.

---

## Finding description and impact

### Summary

`emergencyTransfer` moves promo tokens out of PhlimboV3 without resetting any promo accounting: `accPromoPerShare` and every `promoDebt` stay exactly as they were, so every staker's `pendingPromo` remains intact but unbacked. The contract is now insolvent against a live promotion.

This state is **fully recoverable** — right up until the owner tries to recover it the documented way.

Rotating out of the broken promotion (`beginFlush` → `batchClaim` → `finalizePromotion`) **destroys the entire staker base's earned promo entitlement, irreversibly and silently** — the flush reports success at every level: the cursor reaches full coverage, `finalizePromotion` accepts, no revert, no warning, no residual on-chain claim. Yet simply **returning the tokens first** would have restored solvency completely and made every pending payable again.

The finding is the **ordering constraint**, and it is a textbook non-obvious owner footgun.

### Why this report exists: the ledger entry is falsified in the direction that understates harm

Ledger entry `d3a5b3ec` (V3-M-02) currently reads **"recoverable, no fund loss"** and names `beginFlush → batchClaim → finalizePromotion` as **the recovery**.

The PoC shows that exact sequence destroys 500e18 of earned promo across the whole staker base. **The ledger entry's recovery advice is the destruction path.** An owner following this audit's own prior advice would destroy every staker's entitlement — the highest possible degree of surprise. The Law-3 footgun exception applies squarely.

This is why the finding is re-published rather than left as a carryover: the severity does not move, but a Medium that reads as benign is worse than an honest one, and the remediation advice must be **inverted into a warning**.

### Vulnerability details

`emergencyTransfer` removes promo tokens but resets no accounting. Because `accPromoPerShare` and all `promoDebt` values are untouched, each staker's `pendingPromo` still reads its full earned amount — the accounting is *correct*, merely unbacked. That is the crucial property: **the state is recoverable by balance restoration alone.** Returning the swept tokens restores the invariant and every pending becomes payable, with no accounting surgery required.

The natural next step for an owner facing a broken promotion is to rotate out of it. That path runs through [`PhlimboV3.batchClaim#L444-L458`](https://github.com/Behodler/phlimbo-ea/blob/bf42c12e3ad9d834373e8439f0e992aa8870aca4/src/PhlimboV3.sol#L444-L458), which aligns `promoDebt` **unconditionally, before** attempting the transfer:

```solidity
uint256 pending = (userDetails.amount * accPromoPerShare) / PRECISION - userDetails.promoDebt;

// Align the debt unconditionally: ...
userDetails.promoDebt = (userDetails.amount * accPromoPerShare) / PRECISION;   // L448

if (pending > 0) {
    if (_tryTransfer(promoToken, staker, pending)) { ... }
    else {
        unclaimablePromo += pending;                                            // L454, aggregate only
        emit PromoClaimFailed(staker, pending);
    }
}
```

With the balance swept, `_tryTransfer` fails for **every** staker on insufficient balance. Each staker's debt is aligned at L448 anyway — `pendingPromo` becomes `0` permanently — and each amount is banked into the aggregate `unclaimablePromo`, which has no per-user record and no claim path. `finalizePromotion` then zeroes the counter at [`#L487`](https://github.com/Behodler/phlimbo-ea/blob/bf42c12e3ad9d834373e8439f0e992aa8870aca4/src/PhlimboV3.sol#L487).

The transition from "recoverable" to "destroyed" happens at L448, and it is silent. `abortFlush` does not undo it — the loss locks in at the alignment, not at the sweep.

### Impact

The entire staker base's earned promo entitlement is destroyed and unrecoverable on-chain. Measured in the PoC: alice's 125e18 and bob's 375e18 both go to zero; 500e18 banked, then zeroed. User phUSD principal is untouched.

The consequential harm is that the state was **fully recoverable immediately before the rotation** and is **irrecoverable immediately after** — a one-way door with no signal in front of it.

### Severity: Medium

**Why not High.** The fund loss requires `emergencyTransfer` to have already been called. That is a deliberate owner action whose token-draining consequence is entirely obvious, and under Law 3 the owner is trusted for knowing actions — the sweep itself is not the finding. There is no unprivileged trigger for this path.

**Why not downgraded, and why it is not "reckless admin".** The non-obvious part is the **ordering constraint**, and that is a genuine footgun in the strict sense: a competent, non-malicious owner would be decisively surprised. The state *is* recoverable — the accumulator and debts are intact, so returning the tokens fully restores solvency. The one remediation that reads as natural, and that this audit's own ledger explicitly recommends, is precisely the one that destroys the entitlements. Nothing in the code, the events, or the return values warns of it; the flush succeeds. "Recoverable, no fund loss" is now provably false.

**Ceiling.** The entry point remains a deliberate owner emergency action with no unprivileged trigger, which holds this at Medium.

### Face (b) — stable leg: recorded, but carrying zero severity weight

`emergencyTransfer` resets no accounting on the **stable** leg either, and there is no setter that can decrease `rewardBalance`/`promoRewardBalance`. The hypothesis is that if the owner sweeps and returns *less* than swept, `_updatePool` keeps advancing `accStablePerShare` against a phantom `rewardBalance`; `_claimRewards` then reverts on the shortfall, and because `withdraw` calls `_claimRewards` unconditionally ([`PhlimboV3.sol#L631`](https://github.com/Behodler/phlimbo-ea/blob/bf42c12e3ad9d834373e8439f0e992aa8870aca4/src/PhlimboV3.sol#L631)), withdraw would revert for every user with pending stable rewards.

**This is not PoC'd.** It contributes **nothing** to this finding's Medium and must not be read as proven. It is recorded here only so the widening stays visible rather than vanishing into a carryover, and is routed to manual-review / Tier-3 for the next run.

### Relationship to M-01 (`01953624`)

Face (a) reaches the same disposal point **through M-01's L448 alignment defect**, but the root cause class differs — stale accounting after an owner sweep, versus debt-align-before-transfer — so the separate filing is correct.

**Either fix independently defuses the other's worst case.** A per-user bank plus a permissionless pull at L448 (M-01's recommended fix) means a post-`emergencyTransfer` rotation banks **recoverably** instead of destroying: stakers would retain a per-user on-chain claim, payable once the owner returns the tokens. This is the strongest argument for prioritising the L448 fix.

### Proof of Concept

**File:** `/home/justin/code/audits/workspace/phlimbo-ea/test/probe-08-code2.t.sol`
**Test:** `test_P7_emergencyTransfer_then_rotation_mass_confiscation`

Assertion-style: the test **fails** to prove the confiscation — the `[FAIL: ...]` line is the finding.

```
$ forge test --match-path test/probe-08-code2.t.sol --match-test test_P7 -vv

[FAIL: P7: alice's earned promo silently confiscated: 0 <= 0] test_P7_emergencyTransfer_then_rotation_mass_confiscation() (gas: 726807)
Logs:
  alice pending before: 125000000000000000000
  alice promo balance after flush: 0
  bob   promo balance after flush: 0
  unclaimablePromo banked: 500000000000000000000
  flushCursor: 2
  unclaimablePromo after finalize: 0
  alice pendingPromo after finalize: 0
```

Reading the output:

- **`alice pending before: 125000000000000000000`** — after `emergencyTransfer`, alice's entitlement is still fully intact in the accounting. This is the recoverable state: returning the tokens here pays her.
- **`flushCursor: 2`** — the flush reports **complete success**. Full coverage of the frozen staker set, no revert. `finalizePromotion` accepts it.
- **`alice promo balance after flush: 0` / `bob promo balance after flush: 0`** — nobody was paid.
- **`unclaimablePromo banked: 500000000000000000000`** — the entire staker base's earned promo (alice 125e18 + bob 375e18), banked into the aggregate counter with no per-user record.
- **`unclaimablePromo after finalize: 0` / `alice pendingPromo after finalize: 0`** — counter zeroed, entitlements gone. Nothing on-chain records that anyone was owed anything.

The documented "recovery" sequence, executed exactly as the ledger prescribes, produced total silent destruction of the promo entitlement it was supposed to recover.

## Recommended mitigation steps

### 1. Invert the remediation advice — this is the immediate, zero-code action

The current guidance is actively harmful and must be replaced. Correct operational procedure after `emergencyTransfer`:

> **Return the swept promo tokens FIRST.** Balance restoration alone fully restores solvency — `accPromoPerShare` and all `promoDebt` values are intact, so every `pendingPromo` becomes payable again with no accounting surgery.
>
> **Only then rotate.** Never run `beginFlush → batchClaim → finalizePromotion` against an under-funded promo balance: doing so aligns every staker's debt at [`PhlimboV3.sol#L448`](https://github.com/Behodler/phlimbo-ea/blob/bf42c12e3ad9d834373e8439f0e992aa8870aca4/src/PhlimboV3.sol#L448) while the transfers fail, permanently destroying every entitlement — silently, with the flush reporting success.

Ledger entry `d3a5b3ec` must have "recoverable, no fund loss" struck (falsified by `test_P7`) and the recovery sequence replaced with this warning.

### 2. Code fix — the shared L448 repair

Apply M-01's fix at [`PhlimboV3.sol#L448`](https://github.com/Behodler/phlimbo-ea/blob/bf42c12e3ad9d834373e8439f0e992aa8870aca4/src/PhlimboV3.sol#L448): a per-user bank keyed by retired token plus a permissionless `claimUnclaimable` pull, exactly as `MigratorV2V3` already implements ([`#L93`](https://github.com/Behodler/phlimbo-ea/blob/bf42c12e3ad9d834373e8439f0e992aa8870aca4/src/MigratorV2V3.sol#L93), [`#L227`](https://github.com/Behodler/phlimbo-ea/blob/bf42c12e3ad9d834373e8439f0e992aa8870aca4/src/MigratorV2V3.sol#L227)). This converts the destruction into a recoverable bank and closes both findings' worst cases with one change. See M-01 for the full patch.

### 3. Defence in depth — make the one-way door visible

Add a solvency guard so a flush against an under-funded balance cannot silently succeed:

```solidity
function beginFlush() external onlyOwner {
    ...
    // A flush against an under-funded balance destroys entitlements at L448.
    // Fail loudly rather than silently confiscating.
    require(
        promoToken.balanceOf(address(this)) >= _totalPendingPromo(),
        "Promo underfunded: return tokens before rotating"
    );
    ...
}
```

If maintaining `_totalPendingPromo()` on-chain is too costly, an equivalent cheaper guard is to have `finalizePromotion` revert when `unclaimablePromo > 0` — forcing the owner to confront banked failures instead of sweeping them. Note this is a **backstop only**: with the L448 fix in place the bank is recoverable, and without it the entitlements are already destroyed by the time `finalizePromotion` is reached. It must not be treated as a substitute for the L448 fix.

