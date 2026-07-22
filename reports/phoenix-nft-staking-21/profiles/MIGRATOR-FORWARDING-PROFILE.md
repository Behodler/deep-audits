# MIGRATOR-FORWARDING-PROFILE — story-023 settlement-capture forwarding

- Run: `phoenix-nft-staking-21`
- Submodule HEAD: `c881a42`; mechanism landed at `f3b92c0`
  (`[story-023] Version-agnostic migrator settlement-capture forwarding (pns20h1)`)
- Subjects: `src/NFTStakerMigrator.sol` (+184), `src/InPlaceNFTStakerMigrator.sol` (+149),
  `src/IStakerViews.sol` (new, 31 LOC)
- Purpose: remediate `pns20h1` — a `depositFor` that settles the incoming user's re-accrued
  pending reward to `msg.sender` (the migrator) instead of to the user, permanently stranding
  it because neither migrator had any rescue primitive.

---

## 1. The mechanism, exactly as written

`NFTStakerMigrator.sol:214-241` / `InPlaceNFTStakerMigrator.sol:311-338`:

```solidity
function _depositForAndForward(address user, uint256 amount) private {
    uint256 owed = IStakerViews(address(newStaker)).pendingReward(user);   // STATICCALL
    uint256 pre  = rewardToken.balanceOf(address(this));                   // STATICCALL

    newStaker.depositFor(user, amount);                                    // CALL

    uint256 captured = rewardToken.balanceOf(address(this)) - pre;         // STATICCALL
    require(captured <= owed, "Migrator: capture exceeds owed");

    if (captured > 0) {
        try rewardToken.transfer(user, captured) returns (bool ok) {
            if (ok) { emit RewardForwarded(user, captured); }
            else    { unforwarded[user] += captured; totalUnforwarded += captured;
                      emit RewardForwardFailed(user, captured); }
        } catch {     unforwarded[user] += captured; totalUnforwarded += captured;
                      emit RewardForwardFailed(user, captured); }
    }
}
```

Four discrete parts: **(a)** the pre-call `pendingReward` / `balanceOf` snapshot, **(b)** the
per-iteration delta measurement, **(c)** the `require(captured <= owed)` tripwire, **(d)** the
`try`/`catch` escrow-on-failure. Recovery is `claimForwarded()`
(`NFTStakerMigrator.sol:247` / `InPlaceNFTStakerMigrator.sol:345`); the escrow is protected
from the owner by the `totalUnforwarded` floor in `rescueERC20`
(`NFTStakerMigrator.sol:268-276` / `InPlaceNFTStakerMigrator.sol:390-398`).

---

## 2. D-6 parity — VERIFIED

Plan decision D-6 claims the two `_depositForAndForward` bodies are "line-for-line identical".
Mechanically checked by extracting each function (comments stripped) and `diff -u`:

```diff
 function _depositForAndForward(address user, uint256 amount) private {
-    uint256 owed = IStakerViews(address(newStaker)).pendingReward(user);
+    uint256 owed = IStakerViews(address(staker)).pendingReward(user);
     uint256 pre = rewardToken.balanceOf(address(this));

-    newStaker.depositFor(user, amount);
+    staker.depositFor(user, amount);

     uint256 captured = rewardToken.balanceOf(address(this)) - pre;
     require(captured <= owed, "Migrator: capture exceeds owed");
     ... (remaining 18 lines byte-identical, including the revert string
          "Migrator: capture exceeds owed" in BOTH files)
```

**Two changed lines, both the staker-reference rename that D-6 explicitly contemplates
(`newStaker` → `staker`, because source and target are the same contract in the in-place
case).** The tripwire string, the escrow arithmetic, the event emissions, and both `catch`
branches are byte-identical. **D-6 CLAIM VERIFIED.**

`claimForwarded` parity: identical except the revert-string prefix
(`"Migrator: nothing unforwarded"` vs `"InPlace: nothing unforwarded"`). Cosmetic, consistent
with each file's existing prefix convention.

`rescueERC20` reward-token floor: structurally identical
(`balance - totalUnforwarded`; `require(amount <= surplus, …)`), differing only in the revert
prefix. **Parity holds across the whole mechanism.**

---

## 3. What IS guaranteed

| # | Guarantee | Basis | Confidence |
|---|---|---|---|
| G1 | The migrator can never forward MORE than the destination staker owed the user at that instant | `require(captured <= owed)`, `owed` read pre-call on the destination | **verified** |
| G2 | Against a correct staker (`_safePayTo(user, …)`) the mechanism is a no-op: `captured == 0`, no transfer, no event | `NFTStakerPriceScaledMigrateReady.sol:887` pays the user, so the migrator balance does not move | **verified** |
| G3 | Against the buggy staker (`_safePay` → `msg.sender`) the full settlement is measured and re-routed | `NFTStakerDepletion.sol:756`; delta equals the settled `pending` | **verified**, see §4 |
| G4 | A reverting **or** `false`-returning recipient cannot take the batch down | raw `transfer` inside `try`, both branches escrow | **verified** — raw `transfer` (not `safeTransfer`) is deliberate and correct; SafeERC20 would bubble the revert past the `catch` for `false`-returning tokens |
| G5 | Escrowed value is recoverable by, and only by, its owner | `claimForwarded` indexes `msg.sender`; no owner path writes `unforwarded` | **verified** |
| G6 | No owner path can redirect escrowed value | `rescueERC20` floors at `totalUnforwarded` in both files | **verified** |
| G7 | `claimForwarded` cannot be double-drained | strict CEI (`=0` then `-=` then transfer) under `nonReentrant` | **verified** |
| G8 | Per-iteration snapshotting prevents cross-user attribution in a batch | `pre` is re-read each iteration (`:216`/`:313`); prior iterations' forwards-out and escrows-in are absorbed into the next `pre` | **verified**; pinned by `testD_MultiUserBatchNoCrossAttribution` |
| G9 | A pre-existing donation sitting in the migrator is never mis-attributed | a donation lands in a prior transaction, so it is inside `pre` and outside the delta | **verified**; pinned by `testF_PreExistingDonationNotMisattributed` |
| G10 | A mispointed dispatcher-hook `recipient` reverts rather than over-crediting | `require(captured <= owed)` | **verified**; pinned by `testE2_MispointedHookRecipientRevertsInsteadOfOverCrediting` |
| G11 | A wrong-reward-token deployment cannot silently disable the mechanism | ctor cross-check vs `IStakerViews.rewardToken()` — **both** stakers checked in `NFTStakerMigrator.sol:133-140`, the single staker in `InPlaceNFTStakerMigrator.sol:167-170` | **verified**; pinned by `testH_ConstructorRejectsWrongRewardToken` |
| G12 | `captured` cannot underflow | `balanceOf(this) - pre` requires the balance to fall during `depositFor`; the migrator grants no ERC20 allowance to the staker, and phUSD has no pull path | **verified** for a standard ERC20 |

---

## 4. The tripwire is EXACT EQUALITY, not slack — proof and consequence

The NatSpec (`NFTStakerMigrator.sol:48-57`) argues that `require(captured <= owed)` "cannot
fire on a legitimate migration". Verified, and the relationship is stronger than the docs say:
on both in-repo stakers `captured` equals `owed` **exactly**, with zero slack.

Derivation, for `NFTStakerDepletion` (`NFTStakerPriceScaledMigrateReady` is identical modulo
the rate model):

- `pendingReward(account)` (`:799-813`) computes
  `acc' = accRewardPerShare + min(elapsed·rewardRate, rewardBudget)·ACC / totalStaked`
  with `elapsed = min(now, windowEnd) − lastRewardTime`, and returns
  `user.amount·acc'/ACC − user.rewardDebt`.
- `depositFor` (`:748`) calls `_syncBudget()` (`:423`), which calls `_updatePool()` **first**
  (`:424`), *before* `dispatcherHook.pull()` (`:429`). `_updatePool` (`:448-472`) computes the
  **same** `elapsed`, the **same** `reward`, applies the **same** `rewardBudget` clamp
  (`:465`), and folds it into `accRewardPerShare` with the **same** floor division (`:469`).
- If `pull()` produced inflow, `_recomputeSchedule()` (`:512`) runs — it rewrites
  `rewardRate`, `rewardBudget`, `windowEnd`, `lastRewardTime`, but **never
  `accRewardPerShare`**. No further accrual occurs.
- `depositFor` then computes
  `pending = info.amount·accRewardPerShare/ACC − info.rewardDebt` (`:754`) with the same
  `info.amount` (the new stake is added later, at `:761-762`).

Both sides therefore evaluate the **identical expression on identical operands in the same
transaction**. `captured == owed`, bit for bit. The ordering `_updatePool()` **before**
`pull()` inside `_syncBudget` is the load-bearing fact; a reordering would break equality.

**Consequence — brittleness, worth flagging:** because the bound is met with equality, the
mechanism has *no tolerance whatsoever*. A future or third-party staker whose `pendingReward`
view under-reports by a single wei relative to what `depositFor` settles will trip
`require(captured <= owed)` and **revert the entire batch**. The contract advertises itself as
"version-agnostic across every staker exposing `depositFor`"
(`NFTStakerMigrator.sol:44-46`); that advertisement is safe only for stakers whose
`pendingReward` is an exact mirror of `_updatePool`. Record as an **interface assumption**, not
a bug in today's code.

Consistency check for the `Migrating` state: `_updatePool` early-returns while
`poolState == Migrating` (`:453-456`) and `pendingReward` skips its projection unless `Active`
(`:805`). Consistent. Moot in practice — `depositFor` requires `Active` (`:750`).

---

## 5. What is NOT guaranteed

### 5.1 Under-forwarding is possible; over-forwarding is not

The mechanism is **one-sided by construction**. `captured` is a measured balance delta capped
by `owed`, so it can never exceed what was owed. But nothing forces it to be *complete*: any
capture occurring outside the `[pre, post]` window of a `depositFor` call is invisible to it
and is silently absorbed into the next iteration's `pre`. §6 is the concrete instance.

No arithmetic path was found that under- or over-forwards *within* the measured window. The
subtraction at `:220`/`:317` is exact; there is no scaling, no division, no rounding anywhere
in the mechanism.

### 5.2 `totalUnforwarded` CAN desynchronize from the held balance — one path

The invariant the design relies on is `rewardToken.balanceOf(migrator) >= totalUnforwarded`.
It is maintained because every `unforwarded` credit is backed by tokens the contract just
measured itself receiving, and the only owner egress is floored. Paths checked:

| Path | Desync? | Notes |
|---|---|---|
| Successful forward | no | `unforwarded` untouched |
| Reverting `transfer` (`catch`) | no | tokens stayed; escrow credited |
| `false`-returning `transfer` that moved **nothing** | no | tokens stayed; escrow credited |
| **`false`-returning `transfer` that DID move the tokens** | **YES** | balance drops, escrow still credited ⇒ `balance < totalUnforwarded` |
| `rescueERC20` of the reward token | no | floored at `:272`/`:394` |
| `rescueERC20` of any other token | no | cannot reach the reward balance |
| `claimForwarded` | no | decrements both sides by the same amount |
| Fee-on-transfer reward token | **YES** | `captured` measures net-in; the forward pays a fee, so a later escrow could exceed the held balance |

Consequences of the desync branch: `rescueERC20(rewardToken, …)` **underflow-reverts** at
`balance - totalUnforwarded` (`NFTStakerMigrator.sol:272`,
`InPlaceNFTStakerMigrator.sol:394`), permanently disabling reward-token rescue, and
`claimForwarded` reverts on insufficient balance. **Both recovery paths brick simultaneously.**

**Reachability: none with phUSD**, which is a standard ERC20 (revert-on-failure, no fee, no
rebase). Marked **token-conditional and unverified for any future reward token**.
Recommended hardening: clamp rather than revert —
`uint256 surplus = balance > totalUnforwarded ? balance - totalUnforwarded : 0;` — applied
identically to both files to preserve D-6 parity.

### 5.3 Permanently-unpayable escrow is permanently stuck, by design

If a user's address can never receive phUSD (e.g. a contract that reverts on receipt, or a
token-level blocklist), `_depositForAndForward` escrows the amount and `claimForwarded`'s
`safeTransfer` (`:254`/`:352`) fails for the same reason. The `totalUnforwarded` floor then
prevents the owner from ever reclaiming it. The floor that protects honest users also makes
genuinely-unrecoverable escrow **permanent and unrecyclable**.

This is a deliberate trade — the alternative (an owner override) reintroduces exactly the
"owner can redirect user value" property G6 exists to prevent. Surfaced as an **operational
hazard / owner footgun**, not a vulnerability: an operator would be surprised that a single
unpayable address permanently locks a slice of phUSD with no administrative remedy. Severity
call deferred; local weight **QA**.

### 5.4 Batch-level availability

`require(captured <= owed)` sits inside the migration loop
(`NFTStakerMigrator.sol:189-194`, `InPlaceNFTStakerMigrator.sol:277-295`), so a trip aborts the
whole batch/slice, not just the offending user. Fail-closed and intended (the alternative is
mis-attributing foreign value); recovery is owner re-slicing plus fixing the hook wiring.

---

## 6. THE RESIDUAL GAP — the fix covers the `depositFor` leg only

`NFTStakerMigrator.migrate` (`:170`) begins with:

```solidity
uint256[] memory amounts = oldStaker.batchMigrate(users);   // :171 — NO SNAPSHOT
```

`batchMigrate` is where the **source** staker settles each exiting user's frozen pending
reward. It is called **once, before the loop, with no `pre`/`post` measurement around it**.

If a source staker ever settled that exit payment to `msg.sender` (the migrator) rather than to
the user, the value would land *before* the first per-iteration `pre` snapshot at `:216`, be
absorbed into `pre`, never be measured as `captured`, never be forwarded, and end up as
**owner-sweepable surplus** — it sits above the `totalUnforwarded` floor, so `rescueERC20`
would move it freely. That is `pns20h1` reproduced on the sibling leg.

**Not exploitable against either in-repo staker today.** Both migration-exit paths correctly
use `_safePayTo(account, pending)`:

- `NFTStakerDepletion.sol:733`
- `NFTStakerPriceScaledMigrateReady.sol:855`

(The same census in `FORK-PARITY-5WAY.md` §A.2 confirms `:756` is the *only* divergent site,
and it is on the `depositFor` leg, which the fix does cover.)

The finding is therefore a **documentation-vs-implementation mismatch, not a live bug**: the
contract claims to be "version-agnostic across every staker exposing `depositFor`"
(`:44-46`), and the protection is narrower than that claim. The claim would be accurate if it
read *"version-agnostic with respect to the `depositFor` settlement leg; the `batchMigrate`
exit leg is assumed to pay the user directly."*

Recommendation (cheap, symmetric): either wrap `batchMigrate` in the same
snapshot/delta/forward treatment, or state the assumption explicitly and add a regression test
asserting `rewardToken.balanceOf(migrator)` is unchanged across `batchMigrate`.

`InPlaceNFTStakerMigrator` has the same shape at `migrateOut:220`, with the same
non-reachability today.

---

## 7. Structural no-op on the primary in-place path

In `InPlaceNFTStakerMigrator._depositForAndForward:312`, `owed` is read on the **same** staker
the user was migrated out of. While parked, `users[user].amount == 0` and `rewardDebt == 0`,
so `pendingReward` returns `0`; symmetrically `depositFor` settles nothing because
`info.amount > 0` is false (`NFTStakerDepletion.sol:753`). `captured == owed == 0` — the
tripwire holds trivially and nothing is forwarded. **Correct, not broken.**

The mechanism becomes live only on a partial round-trip: a parked user who re-stakes directly
after `finalizeAndReset` returns the pool to `Active`, and is then re-injected by `migrateIn`.
That path is covered (`testC_InPlaceMigrateInDeliversExactPending`,
`testVersionAgnosticInPlaceAgainstPriceScaled`). Recorded so a reviewer does not misread
`owed == 0` as a mis-wired bound.

---

## 8. `IStakerViews.sol` (new)

31 LOC, two `external view` declarations: `rewardToken() returns (IERC20)` `:26` and
`pendingReward(address) returns (uint256)` `:30`. Both `view`, so both call sites compile to
**STATICCALL** — a staker cannot mutate migrator state at the snapshot read.

Design decision D-5 (`:11-22`) keeps these off `INFTStakerMigratable` because that interface is
the deliberately-minimal migration contract. Sound: widening it would force every implementer
to change for a migrator-local concern. The trade-off is that conformance is **unchecked at
compile time** — the migrators hard-cast (`IStakerViews(address(staker))`), so a staker lacking
`pendingReward` fails only at runtime, mid-batch. Partially mitigated by the constructor's
`rewardToken()` cross-check (`NFTStakerMigrator.sol:133-140`), which probes one of the two
methods at deploy time; **`pendingReward` itself is never probed in the constructor.** Local
weight **informational**; a one-line ctor probe (`pendingReward(address(0))`) would close it.

The NatSpec's claim that both stakers satisfy the shape is verified: `rewardToken` at
`NFTStakerDepletion.sol:95` / `NFTStakerPriceScaledMigrateReady.sol:116`, `pendingReward` at
`:799` / `:947` — matching the line references in the comment exactly.

---

## 9. Test coverage map (`test/MigratorRewardForwarding.t.sol`, 16 tests)

Covered: control/no-strand, cross-staker exact delivery, in-place delivery, multi-user
no-cross-attribution, hook-pull-to-staker, mispointed-hook revert, pre-existing donation,
reverting recipient, `false`-returning recipient, ctor wrong-token, both version-agnostic
pairings, both `rescueERC20` floors, `claimForwarded` self-only/pays-once, and a fuzz test
`testFuzz_BatchConservesOwedAndResidualEqualsEscrow`.

**Gaps observed (for `invariant-generator` / `code-scanner`):**
- No test covering the §6 `batchMigrate`-leg capture.
- No test covering the §5.2 `balance < totalUnforwarded` desync (both recovery paths bricking).
- No test covering §5.3 permanently-unpayable escrow.
- No test asserting the §4 exact-equality property directly (the fuzz test asserts
  conservation, which is weaker).
