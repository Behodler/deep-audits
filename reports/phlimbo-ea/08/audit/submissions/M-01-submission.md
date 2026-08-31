<!--
ID: pe8m1
C4 Submission Metadata
Title: [M-01] PhlimboV3.batchClaim aligns promoDebt before the transfer, permanently destroying a staker's earned promo on any transfer failure; finalizePromotion sweeps it to leftoverRecipient
Root Cause Link: https://github.com/Behodler/phlimbo-ea/blob/bf42c12e3ad9d834373e8439f0e992aa8870aca4/src/PhlimboV3.sol#L444-L458
Fingerprint: 019536247d6a63a91e90ee6b679530d608ef7bee71df59dcb3cc303d42c2915c
Finding: 08-02 (DEDUP-08-02 / CLASS-08-02)
Commit: bf42c12
Severity: Medium (top-of-band)
PoC: workspace/phlimbo-ea/test/EconProbe.t.sol
-->

## Finding description and impact

### Summary

`PhlimboV3.batchClaim` aligns each staker's `promoDebt` to the current accumulator **unconditionally and before** attempting the promo transfer. If the transfer then fails, the staker's earned entitlement has already been erased from the accounting — `pendingPromo(staker)` reads `0` forever. The failed amount is banked into the **aggregate** `unclaimablePromo` counter, which is write-only: it is incremented in `batchClaim`, zeroed in `finalizePromotion`, and read nowhere in contract logic. There is no per-user record and no claim path. `finalizePromotion` then transfers the contract's **entire** promo-token balance — the bank included — to the owner-supplied `leftoverRecipient`.

The result: a staker who was unable to receive during the flush window loses promo she had already earned, permanently and irrecoverably on-chain, with the tokens delivered to a different address.

### Vulnerability details

The defect is at [`PhlimboV3.sol#L444-L458`](https://github.com/Behodler/phlimbo-ea/blob/bf42c12e3ad9d834373e8439f0e992aa8870aca4/src/PhlimboV3.sol#L444-L458):

```solidity
uint256 pending = (userDetails.amount * accPromoPerShare) / PRECISION - userDetails.promoDebt;

// Align the debt unconditionally: the next promotion continues on the
// same accumulator, so every debt must sit exactly at it (§2.1).
userDetails.promoDebt = (userDetails.amount * accPromoPerShare) / PRECISION;   // <-- L448

if (pending > 0) {
    if (_tryTransfer(promoToken, staker, pending)) {
        emit PromoClaimed(staker, pending);
    } else {
        unclaimablePromo += pending;                                            // <-- L454, aggregate only
        emit PromoClaimFailed(staker, pending);
    }
}
```

Because the debt is written at L448 *before* the L451 transfer is attempted, the `else` branch at L454 is reached with the entitlement already gone from user accounting. The only surviving per-user record is the `PromoClaimFailed` event — off-chain data, not an on-chain claim.

`finalizePromotion` at [`PhlimboV3.sol#L473-L487`](https://github.com/Behodler/phlimbo-ea/blob/bf42c12e3ad9d834373e8439f0e992aa8870aca4/src/PhlimboV3.sol#L473-L487) then sweeps the whole balance:

```solidity
IERC20 retiredToken = promoToken;
uint256 leftover = retiredToken.balanceOf(address(this));   // <-- L479, whole balance incl. the bank
if (leftover > 0) {
    retiredToken.safeTransfer(leftoverRecipient, leftover);
}
...
unclaimablePromo = 0;                                       // <-- L487
```

`abortFlush` ([`PhlimboV3.sol#L498`](https://github.com/Behodler/phlimbo-ea/blob/bf42c12e3ad9d834373e8439f0e992aa8870aca4/src/PhlimboV3.sol#L498)) does **not** undo the damage: the loss locks in at L448, not at L487. Aborting the flush leaves the aligned debts in place, so the entitlement is gone whether or not the rotation completes.

### Precondition

The trigger is a promo-token transfer failure — a blocklisted staker, or a token-wide transfer pause. This is not an attacker action, but it is not hypothetical either: `_tryTransfer` exists **solely** to survive this case, and the project's own test harness ships a mock for it. [`test/Mocks.sol#L96-L100`](https://github.com/Behodler/phlimbo-ea/blob/bf42c12e3ad9d834373e8439f0e992aa8870aca4/test/Mocks.sol#L96-L100) documents `MockBlocklistToken` as *"ERC20 with a **USDT-style** recipient blocklist"*. USDT is the explicit exception to C4's weird-ERC20 known-invalid rule, so this precondition is in scope and realistic.

`batchClaim` is permissionless — any caller can advance the flush and complete the destruction that the token condition set up.

### The team already wrote the fix — for the sibling contract

`MigratorV2V3` was given exactly this treatment during story-025, after audit-07 M-01. Commit `ef98cd9` states:

> *"Copy house `_tryTransfer` helper from **PhlimboV3**; add `_forward` that banks failed forwards into per-user `unclaimable` mapping and emits `RewardForwardFailed` instead of reverting, so the cursor always advances — Add permissionless `claimUnclaimable` pull"*

The idiom was taken *from* PhlimboV3; the team recognized in the sibling that banking alone was insufficient, built the per-user mapping ([`MigratorV2V3.sol#L93`](https://github.com/Behodler/phlimbo-ea/blob/bf42c12e3ad9d834373e8439f0e992aa8870aca4/src/MigratorV2V3.sol#L93)) and the pull ([`MigratorV2V3.sol#L227`](https://github.com/Behodler/phlimbo-ea/blob/bf42c12e3ad9d834373e8439f0e992aa8870aca4/src/MigratorV2V3.sol#L227)) — and never back-applied it to the contract they copied it from.

### The specification contradicts itself three ways

1. **`SolvencyDetermination.md` §4 counts the bank as a liability the balance must cover:**
   ```
   promoToken.balanceOf(phlimbo) >= promoRewardBalance + Σ_user pendingPromo(user) + unclaimablePromo
   ```
   with the stated justification *"Failed transfers stay inside. ... the tokens never left, so the invariant is undisturbed"* — framing the bank as **preserved** value.

2. **The Rotation-solvency section calls the same quantity unencumbered and sweeps it:** *"the entire remaining balance (undistributed remainder + rounding dust + `unclaimablePromo`) is unencumbered and is swept to `leftoverRecipient`."*

3. **The NatSpec promises a recovery that does not exist.** [`PhlimboV3.sol#L141-L142`](https://github.com/Behodler/phlimbo-ea/blob/bf42c12e3ad9d834373e8439f0e992aa8870aca4/src/PhlimboV3.sol#L141-L142): *"Promo tokens whose transfer to a user failed during flush (**banked for out-of-band handling**; swept at finalizePromotion)."* No out-of-band mechanism exists anywhere in PhlimboV3.

**The rotation-solvency argument is circular.** It reasons: *"`finalizePromotion` is only reachable when `flushCursor == stakerCount()` ... after every staker's pending was either paid or banked and every `promoDebt` aligned ... At that moment `Σ pendingPromo == 0`, so the entire remaining balance ... is unencumbered."* But `Σ pendingPromo` is zero **precisely because L448 destroyed the entitlement**. The document cites the consequence of the defect as proof there is no defect.

The project's own test [`PhlimboV3Test.t.sol#L1670-L1687`](https://github.com/Behodler/phlimbo-ea/blob/bf42c12e3ad9d834373e8439f0e992aa8870aca4/test/PhlimboV3Test.t.sol#L1670-L1687) pins this behaviour as intended (`assertEq(phlimbo.pendingPromo(alice), 0, "debt still aligned on failure")`, then asserts the full sweep to `0x99`). That establishes **intent, not safety** — it is why this is filed as an unsafe design rather than an implementation slip.

### Impact

Already-earned promo entitlement is destroyed permanently and swept to `leftoverRecipient`. User phUSD principal is never touched and the loss is bounded by the funded promotion. Measured in the PoC:

- A single blocked staker loses **375e18** of earned promo (75% of a 500e18 accrual across two stakers).
- Under a token-wide pause, **100% of a 1000e18 funded promotion** is confiscated from the entire staker base and delivered to `leftoverRecipient`.

Accrued promo is *matured* yield — already allocated to the staker's account, awaiting only the pull — so it weighs similar to capital loss, not as unmatured or in-motion value.

### Severity: Medium (top of band)

**Why not High.** The precondition is external and attacker-uncausable. An attacker cannot *cause* the transfer to fail: a gas sweep from 20k to 1M (500-gas steps) found **no** OOG path in which the outer frame survives the inner failure — the EIP-150 63/64 reserve leaves too little gas for the ~30k of post-call work, so the outer frame OOGs too and the transaction unwinds the alignment. The permissionless `batchClaim` only completes a destruction the token condition already set up; the attacker gains nothing, since `leftoverRecipient` is owner-controlled. And because `leftoverRecipient` is owner-controlled, the loss is irreversible **on-chain** but recoverable **socially** — the owner holds the tokens and can reimburse off-chain.

**Why not Low.** The mechanism destroys already-earned user value permanently and on-chain-unrecoverably, and both PoCs land the loss with no attacker and no gas trick. The one argument for Low — "the project's test blesses it" — asserts intent, and that intent is documented three ways, inconsistently, with the design doc's central argument circular and the contract's own NatSpec promising a recovery that does not exist.

**Owner footgun.** The sweep presents as entirely routine: `finalizePromotion` reads as collecting the undistributed remainder at the end of a promotion. Every artifact a competent, non-malicious owner would consult says the entitlement survives — the NatSpec says "banked for out-of-band handling", §4 counts it as a covered liability and says "the tokens never left", and the sibling contract written in the same story wave gives blocked users a permissionless pull. Nothing warns that finalizing confiscates.

**Escalation triggers — treat as operationally High-priority:**
- If `leftoverRecipient` is ever set to a burn address or any unrecoverable sink, the social-recovery ceiling disappears and this becomes a **High**.
- If the partner promo token is a blocklist-capable stablecoin (USDT-class), the likelihood rises materially — the precondition becomes an ordinary operational event rather than a tail case.

### Proof of Concept

**File:** `/home/justin/code/audits/workspace/phlimbo-ea/test/EconProbe.t.sol`
Both tests re-run independently by two agents and reproduced at commit `bf42c12`.

#### `test_probe_B_finalize_confiscates_unclaimable` — single blocked staker

```
$ forge test --match-path test/EconProbe.t.sol --match-test test_probe_B_finalize_confiscates_unclaimable -vv

[PASS] test_probe_B_finalize_confiscates_unclaimable() (gas: 571032)
Logs:
  bob banked unclaimablePromo  : 375000000000000000000
  bob promo token balance      : 0
  alice promo token balance    : 125000000000000000000
  unclaimablePromo after final : 0
  leftoverRecipient balance    : 875000000000000000000
  bob pendingPromo post-final  : 0
  contract promo balance       : 0
```

Bob earned 375e18 and is blocklisted during the flush. After `finalizePromotion`: bob's balance is `0`, his `pendingPromo` is `0`, the contract holds `0`, and `leftoverRecipient` holds `875e18` — bob's 375e18 plus the 500e18 undistributed remainder. Nothing on-chain records that bob was owed anything.

#### `test_probe_B2_all_recipients_blocked` — token-wide pause

```
$ forge test --match-path test/EconProbe.t.sol --match-test test_probe_B2_all_recipients_blocked -vv

[PASS] test_probe_B2_all_recipients_blocked() (gas: 566042)
Logs:
  ALL banked unclaimablePromo  : 500000000000000000000
  leftoverRecipient got        : 1000000000000000000000
  of promo funded              : 1000000000000000000000
```

With every recipient blocked, the entire staker base's 500e18 of earned promo is banked and then swept. `leftoverRecipient` receives **100%** of the 1000e18 funded promotion.

#### Refutation probes (the basis of the whyNotHigh)

**File:** `/home/justin/code/audits/workspace/phlimbo-ea/test/probe-08-code.t.sol` and `probe-08-code2.t.sol`

```
[PASS] test_P1_gas_grief_batchClaim() (gas: 15825926)
Logs:
  grief succeeded (1=yes): 0
  gas value: 0

[PASS] test_P1b_gas_grief_fine_sweep() (gas: 163410410)
Logs:
  first gas where batchClaim succeeds: 80000
  gas where grief lands (0=none): 0
```

These are our own refutations, reported against our own High argument: no attacker-forced gas-OOG trigger exists across a 20k–1M sweep. They cap this finding at Medium. They do **not** reach the token-freeze path, which needs no gas trick — the transfer fails on the token's own condition, as probes B and B2 demonstrate.

## Recommended mitigation steps

**The fix belongs at [`PhlimboV3.sol#L448`](https://github.com/Behodler/phlimbo-ea/blob/bf42c12e3ad9d834373e8439f0e992aa8870aca4/src/PhlimboV3.sol#L448), not at `finalizePromotion` L487.**

This is the headline. A fix aimed at the sweep misses the bug entirely: once L448 has aligned the debt, `pendingPromo` reads `0` permanently, and `abortFlush` does not undo it. The entitlement is already gone before the sweep is ever reached — restricting or redirecting the sweep at L487 leaves the destruction fully intact.

**Preferred fix — mirror the sibling.** Replace the aggregate counter with a per-user bank keyed by retired token, plus a permissionless pull, exactly as `MigratorV2V3` already implements ([`#L93`](https://github.com/Behodler/phlimbo-ea/blob/bf42c12e3ad9d834373e8439f0e992aa8870aca4/src/MigratorV2V3.sol#L93), [`#L227`](https://github.com/Behodler/phlimbo-ea/blob/bf42c12e3ad9d834373e8439f0e992aa8870aca4/src/MigratorV2V3.sol#L227)):

```solidity
// storage: token => user => amount
mapping(address => mapping(address => uint256)) public unclaimablePromoOf;

if (pending > 0) {
    if (_tryTransfer(promoToken, staker, pending)) {
        userDetails.promoDebt = (userDetails.amount * accPromoPerShare) / PRECISION;
        emit PromoClaimed(staker, pending);
    } else {
        // Debt must still align (§2.1: the accumulator carries into the next
        // promotion), but the entitlement is preserved per-user, not destroyed.
        userDetails.promoDebt = (userDetails.amount * accPromoPerShare) / PRECISION;
        unclaimablePromoOf[address(promoToken)][staker] += pending;
        unclaimablePromo += pending;
        emit PromoClaimFailed(staker, pending);
    }
} else {
    userDetails.promoDebt = (userDetails.amount * accPromoPerShare) / PRECISION;
}
```

with a pull:

```solidity
function claimUnclaimablePromo(address token) external nonReentrant {
    uint256 amount = unclaimablePromoOf[token][msg.sender];
    require(amount > 0, "Nothing to claim");
    unclaimablePromoOf[token][msg.sender] = 0;
    IERC20(token).safeTransfer(msg.sender, amount);
    emit UnclaimablePromoClaimed(msg.sender, token, amount);
}
```

`finalizePromotion` must then sweep only `balanceOf(address(this)) - <total still banked for the retired token>`, so banked claims stay backed after the rotation. Track the outstanding total per retired token rather than zeroing `unclaimablePromo` at L487.

**Simpler alternative** (if the per-user bank is judged too large): make the alignment conditional on transfer success, leaving `pendingPromo` intact for the failed staker. This is a smaller change but conflicts with §2.1's cross-promotion accumulator carry, since an unaligned debt against a retired token can underflow on the next promotion. The per-user bank is the correct fix and is the one the team has already written.

**Also fix the specification.** `SolvencyDetermination.md` must resolve the §4-vs-Rotation contradiction and drop the circular argument. The NatSpec at L141-142 must either name a real out-of-band mechanism or stop promising one.

**Leverage.** This is the highest-leverage fix in this run: repairing L448 also independently defuses the worst case of finding M-03 (`d3a5b3ec`), whose face (a) reaches the same disposal point through this same alignment defect. One fix, two Mediums defused — roughly 20 lines, already written once in `MigratorV2V3`.


---

## Interim operational rule (mitigation in force until this finding is fixed)

> **Added 2026-07-15.** This section is an **operating instruction for the owner**, not new analysis of
> the defect above. It is the **only mitigation in force** while this finding remains open and the
> `PhlimboV3.sol:448` fix has not landed.

### NEVER ROTATE A SHORT PROMO BANK

If `promoToken.balanceOf(phlimbo)` is short of the outstanding pending promo **for any reason**, top the
bank up **before** calling `beginFlush`.

| Operator action | Outcome |
| --- | --- |
| **TOP UP FIRST**, then rotate (`beginFlush` -> `batchClaim` -> `finalizePromotion`) | `_tryTransfer` succeeds, every staker is paid, debts align behind a real payment. **FULL RECOVERY.** |
| **ROTATE WHILE SHORT** | `batchClaim` L448 aligns `promoDebt` **unconditionally, before** the transfer attempt, so `pendingPromo` reads `0` permanently; the failed pending is banked into `unclaimablePromo` (L454); `finalizePromotion` then **zeroes** `unclaimablePromo` (L487) with no `claimUnclaimable` analogue to ever pay it out. **IRREVERSIBLE DESTRUCTION of earned promo.** |

The rule is stated generally on purpose: it applies to a short promo bank arising from **any** cause, not
to any one operation that can cause the shortfall.

### Why this is easy to miss

The destructive path **never reverts** — by design. The NatSpec at L425-428 states that *"the flush must
never brick"*, which is correct behaviour for a blocklisted recipient. So the rotation runs to
completion, emits `PromoClaimFailed` + `FlushProgress`, finalizes cleanly, and **reports success**.
`abortFlush` does **not** undo the debt alignment. **Nothing signals the loss to the operator.**

### Provenance

Ported from V3-M-02 / `pe7m2`'s `WIDENING_phlimbo_ea_08.INVERTED_RECOVERY_ADVICE` when `pe7m2` was closed
**INVALID** on 2026-07-15. Law 1: the destruction *mechanism* was already covered by this finding (see the
`fixNote` targeting L448 and the probe-B2 evidence above), but this **interim operational rule** was not
recorded here, and must not die with the closed entry.
