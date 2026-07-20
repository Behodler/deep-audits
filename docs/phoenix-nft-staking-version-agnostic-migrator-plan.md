# Plan — version-agnostic NFT staker migrators (settlement-capture forwarding)

**Date:** 2026-07-20
**Project:** `phoenix-nft-staking`
**Driving finding:** `pns20h1` / fingerprint `1c222d5485…` — *"NFTStakerDepletion.depositFor settles a staker's pending phUSD with `_safePay`, paying the migrator instead of the user"* (run `phoenix-nft-staking-20`, commit `0d1a0b2`)
**Status:** proposal — not implemented. Implementation belongs in the **source repo** (`Behodler/phoenix-nft-staking`) and deployment in the **staging repo**; the audit repo holds only this plan and the proving harness.

---

## 1. Goal

Make one migrator codebase correct against **every** staker that exposes `depositFor`, whether that staker settles the incoming user's pending reward to the *user* (`_safePayTo`) or to the *migrator* (`_safePay`). The migrator must not need to know which variant it is pointed at, must not be re-audited per staker version, and must deliver each user exactly their own owed phUSD — once, never twice, never someone else's.

This is the remediation route for `pns20h1` when the affected staker is already deployed and therefore immutable. It is **not** a substitute for fixing `_safePay` → `_safePayTo` in any staker not yet deployed; see §8.

## 2. Applicability — which stakers this covers

`depositFor` exists in exactly two of the four staker copies. The other two have no migration surface at all (`grep migrator` returns zero hits).

| Staker | `depositFor` | Settlement call | Migrator captures? | Needs forwarding |
|---|---|---|---|---|
| `NFTStaker.sol` | absent | — | — | n/a — no migration surface |
| `NFTStakerPriceScaled.sol` | absent | — | — | n/a — no migration surface |
| `NFTStakerDepletion.sol` | `:748` | `_safePay(pending)` `:756` | **yes — the bug** | **yes** |
| `NFTStakerPriceScaledMigrateReady.sol` | `:879` | `_safePayTo(user, pending)` `:887` | no | no-op (delta is 0) |

The same design therefore covers both live variants and any future clone, because the forwarding branch is *self-disabling*: against a correct staker the measured capture is zero and no transfer occurs.

Both target stakers expose the two accessors the design depends on:

- `IERC20 public immutable rewardToken` — `NFTStakerDepletion.sol:95`, `NFTStakerPriceScaledMigrateReady.sol:116`
- `function pendingReward(address) external view` — `NFTStakerDepletion.sol:799`, `NFTStakerPriceScaledMigrateReady.sol:947`

Neither is on `INFTStakerMigratable`, so the migrator declares a small local extension interface (§4.1) rather than widening the shared one.

## 3. Contracts in scope for change

Both orchestrators, identically:

- `src/NFTStakerMigrator.sol` — cross-staker (old → new). Loop at `:100-105`.
- `src/InPlaceNFTStakerMigrator.sol` — same-staker rewire. Loop at `:210-227`.

## 4. Design

### 4.1 Capture-and-forward, bounded by a pre-call pending snapshot

Around every `depositFor` call, in the same loop iteration:

1. snapshot `owed = staker.pendingReward(user)` **before** the call;
2. snapshot `pre = rewardToken.balanceOf(address(this))`;
3. call `depositFor(user, amount)`;
4. `captured = balanceOf(this) - pre`;
5. `require(captured <= owed)` — the anti-over-credit bound;
6. if `captured > 0`, `rewardToken.safeTransfer(user, captured)` and emit `RewardForwarded(user, captured)`.

### 4.2 Why the bound is exact, not conservative

`_syncBudget()` runs `_updatePool()` **first** and only then `dispatcherHook.pull()` (`NFTStakerDepletion.sol:424-429`). So the accrual `depositFor` settles is computed against the *pre-pull* `rewardBudget` — precisely the quantity `pendingReward(user)` projects at the same block timestamp, using the same `windowEnd` clamp, the same `reward > rewardBudget` clamp, and the same floor division. Snapshot and settlement are equal, not merely ordered.

Consequences:

- `require(captured <= owed)` cannot revert on a legitimate migration. It is a tripwire, not a haircut.
- Against `NFTStakerPriceScaledMigrateReady`, `captured == 0 <= owed` holds trivially. Version-agnostic by construction.
- A pull firing mid-`depositFor` mints to the hook's `recipient` (the staker, per spec) and does not move the migrator's balance — confirmed empirically, see §6 `testE`.

Without the bound, a raw balance delta mis-attributes *any* mid-call inflow to whichever user the loop is on. That is a proved 50,000e18 over-credit when the hook's `recipient` is mispointed at the migrator (§6 `testE2`) — real minted value, landing on a user, unrecoverable by `rescueERC20`. **The bound is mandatory, not optional hardening.**

### 4.3 Delivery failure must not brick the batch

A bare `safeTransfer` to a reverting or blocklisted recipient takes the entire batch down with it, healthy users included (§6 `testG`). That is a better failure mode than silent stranding but it is a new liveness risk introduced by the fix, and it is avoidable.

**Adopt escrow-on-failure:** attempt the transfer inside `try`/`catch`; on failure credit `unforwarded[user] += captured` and emit `RewardForwardFailed`. Expose a permissionless, self-only `claimForwarded()` that pays `unforwarded[msg.sender]` under CEI. The batch always completes; the value is always attributed on-chain to its owner; no owner discretion is introduced.

`Σ unforwarded[*]` becomes a floor `rescueERC20` must not cross for the reward token — mirroring how `totalParked` floors `rescueERC1155` in `InPlaceNFTStakerMigrator:281-289`.

### 4.4 Rescue primitives (TRAP-6 from the finding)

`NFTStakerMigrator` today declares exactly two functions and has no `rescueERC20`, no `rescueERC1155`, no `receive`, no `fallback` — anything delivered to it is permanently stranded, which is what makes `pns20h1` a High rather than a Medium. Add owner-only `rescueERC20` (floored by `Σ unforwarded` for the reward token) and `rescueERC1155`, mirroring `InPlaceNFTStakerMigrator:268-289`. This ships **with** the forwarding change, not after it: the point is to remove the permanence property itself, not only the one known path into it.

### 4.5 Constructor wiring checks

- `rewardToken` as a constructor arg, `require(_rewardToken != address(0))`;
- cross-check against each wired staker's own getter — `require(address(IStakerRewardToken(staker).rewardToken()) == address(_rewardToken))`, for **both** stakers in the cross-staker migrator. A mismatch means the forwarding logic would be measuring the wrong token and silently never fire.

### 4.6 Reentrancy

phUSD is a plain ERC20 with no transfer callback, `InPlaceNFTStakerMigrator.migrateIn` is already `nonReentrant` and zeroes `parked[user]` before `depositFor`, and both entry points are `onlyOwner`. The forwarding transfer is nonetheless a new external call in a loop: add `nonReentrant` to `NFTStakerMigrator.migrate` (it currently lacks it, and the contract does not inherit `ReentrancyGuard`). Cheap, and it pre-closes the hole if the reward token is ever swapped for a callback-bearing one.

## 5. Reference implementation

Proven working code sits in the audit workspace and should be lifted into the source repo, not copied blind:

- `workspace/phoenix-nft-staking/test/patched/PatchedNFTStakerMigrator.sol`
- `workspace/phoenix-nft-staking/test/patched/PatchedInPlaceNFTStakerMigrator.sol`
- `workspace/phoenix-nft-staking/test/patched/IStakerRewardToken.sol`

The workspace versions implement §4.1 steps 2-4 and 6, plus §4.4 and §4.5. **They do not yet implement the §4.2 bound or the §4.3 escrow** — those are the two additions this plan adds on top of what was proved. Shape of the loop body after both additions:

```solidity
uint256 owed = IStakerViews(address(newStaker)).pendingReward(users[i]);
uint256 pre  = rewardToken.balanceOf(address(this));

newStaker.depositFor(users[i], amounts[i]);

uint256 captured = rewardToken.balanceOf(address(this)) - pre;
require(captured <= owed, "Migrator: capture exceeds owed");   // §4.2 tripwire

if (captured > 0) {
    try IERC20(rewardToken).transfer(users[i], captured) returns (bool ok) {
        if (ok) { emit RewardForwarded(users[i], captured); }
        else    { unforwarded[users[i]] += captured; totalUnforwarded += captured;
                  emit RewardForwardFailed(users[i], captured); }
    } catch {
        unforwarded[users[i]] += captured; totalUnforwarded += captured;
        emit RewardForwardFailed(users[i], captured);
    }
}
```

Use raw `transfer` inside `try` (SafeERC20's `safeTransfer` reverts rather than returning, defeating the catch on non-reverting-false tokens); handle both the `false`-return and the revert branch as shown.

## 6. Test plan

Nine tests already pass at `0d1a0b2` in `workspace/phoenix-nft-staking/test/PoC_Drift01_MigratorSidePatch.t.sol` (9/9). Port them to the source repo's suite as the regression baseline:

| Test | Asserts | Status |
|---|---|---|
| `testA_Control_UnpatchedMigratorStrandsReward` | unpatched strands 82,191.78 phUSD, 100% | PASS |
| `testB_PatchedCrossStakerDeliversExactPending` | user receives 164,383.56 across both legs; migrator residual 0 | PASS |
| `testC_PatchedInPlaceMigrateInDeliversExactPending` | 8,219.178 delivered exactly; residual 0 | PASS |
| `testD_MultiUserBatchNoCrossAttribution` | 3 users incl. a zero-pending user; each gets own owed | PASS |
| `testE_HookPullMintsToStakerNotMigrator` | 50k minted mid-call lands on the staker; delta unaffected | PASS |
| `testE2_HOLE_HookRecipientPointedAtMigrator` | documents the 50k over-credit the §4.2 bound must kill | PASS |
| `testF_PreExistingDonationNotMisattributed` | 1,234e18 pre-donation untouched by the baseline | PASS |
| `testG_HOLE_RevertingRecipientBricksWholeBatch` | documents the liveness risk §4.3 must kill | PASS |
| `testH_ConstructorRejectsWrongRewardToken` | both ctor sanity checks fire | PASS |

Tests to **add** for the two new mechanisms:

1. `testE2` must **invert**: with the §4.2 bound, the mispointed-hook scenario reverts on `capture exceeds owed` instead of over-crediting. Keep the old assertion as a commented record of what it used to do.
2. `testG` must **invert**: the batch completes, `unforwarded[bob] == bob's owed`, alice is paid, and `bob` recovers via `claimForwarded()`.
3. **Version-agnostic pair test:** run the *same* patched migrator against `NFTStakerDepletion` and against `NFTStakerPriceScaledMigrateReady` in one test file, asserting identical final user balances and `captured == 0` on the latter. This is the assertion that actually earns the phrase "works for all stakers with `depositFor`".
4. `rescueERC20` must revert when it would dip below `totalUnforwarded`.
5. Fuzz/invariant: for any batch, `Σ (user reward-balance delta) == Σ (owed at call time)` and migrator reward residual `== totalUnforwarded`.

## 7. Rollout (staging repo)

Deployments happen in the staging repo, so the audit repo's `broadcast/` sweep proves nothing about what is live. Before writing an address into `setMigrator`, confirm from staging:

1. Which staker instances are live, and for each, whether it is a `_safePay` or `_safePayTo` variant — read the deployed bytecode/source, do not infer from the class name.
2. The current `migrator` value on each live instance.
3. The dispatcher hook's `recipient` on each — §4.2's tripwire will *revert migrations* if a hook is mispointed at the migrator. That is the correct behaviour, but it should be discovered in staging, not mid-batch on mainnet.

Then: deploy patched migrator → `setMigrator` → `initiateMigration` → migrate one canary user with a known non-zero position on the target → verify the canary's phUSD balance moved by exactly their `pendingReward` snapshot → proceed with full batches.

## 8. Residual risks — what this plan does **not** fix

1. **It binds only the contract you deploy.** `setMigrator` (`NFTStakerDepletion.sol:311-314`) does no validation whatsoever — no code-size check, no interface probe, no lifecycle gate. An EOA migrator, a future third orchestrator, or a hot-fix script calling `depositFor` directly all reproduce `pns20h1` at full severity, and the immutable staker cannot stop them. Ledger `L-04` (`066eccff…`, *"setMigrator has no lifecycle gate"*) becomes the load-bearing control and should be re-weighed on that basis rather than left at Low by inertia. **Treat this plan as a deployment-discipline control, not a source fix.**
2. **Any staker not yet deployed must still take the one-line source fix** — `_safePay(pending)` → `_safePayTo(user, pending)` at `NFTStakerDepletion.sol:756`. Shipping the migrator patch is not a reason to leave the defect in source; a future deployment of the current source would re-introduce it for anyone who wires a non-patched migrator.
3. **`Claimed(user, pending)` still fires from the staker** before the forward completes. Indexers keying on `Claimed` alone will mis-source the payment (staker→migrator→user, two transfers, one event). Off-chain reconciliation must join `Claimed` with `RewardForwarded` / `RewardForwardFailed`.
4. **Fork drift is untouched.** The defect exists because a fix landed in one clone and was never back-ported (WATCH-17, now four-way). This plan routes around one instance of that failure; it does not reduce the number of clones or add a parity test between them. Any `depositFor` settlement-line change must still be diffed across all four copies as part of the same review.

## 9. Decision log

| # | Decision | Rationale |
|---|---|---|
| D-1 | Patch the migrator rather than redeploy the staker | Premise: the affected staker is already deployed and immutable. `depositFor` is `onlyMigrator`, so the migrator is both the sole trigger and the sole recipient — a closed loop the migrator can service. |
| D-2 | Bound the capture by a pre-call `pendingReward` snapshot | A raw delta mis-attributes mid-call inflow; proved 50,000e18 over-credit. The bound is exact because `_updatePool()` precedes `pull()`. |
| D-3 | Escrow-on-failure rather than bare `safeTransfer` | A bare transfer converts a value-loss into a whole-batch liveness failure; escrow keeps the batch live and the attribution on-chain, with no owner discretion. |
| D-4 | Ship rescue primitives in the same change | The permanence property — not the misroute — is what makes `pns20h1` a High. Removing one path into it while leaving the property intact under-fixes the finding. |
| D-5 | Local `IStakerViews` interface, do not widen `INFTStakerMigratable` | The shared interface is deliberately minimal; widening it would force a change on every implementer for a migrator-local concern. |
| D-6 | Same design for both orchestrators | `InPlaceNFTStakerMigrator.migrateIn` captures identically (proved, `testC`); a fix on one only would recreate the exact fork-drift failure that produced `pns20h1`. |
