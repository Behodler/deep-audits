## QA Report — phoenix-nft-staking (NFTStakerV2)

This QA report covers the new `NFTStakerV2` surface introduced for the BalancerPoolerV3 + NFTStakerV2 migration (story-012). The audit scope was: validate that `NFTStakerV2` correctly implements *its piece* of the broader migration plan at `scratchpad/planning-docs/phoenix/phase2/phoenix-nft-staking/v2/balancer-pooler-v3-and-staker-v2-migration-plan.md`. The piece the staker owns is:

- Add `stakeFor(beneficiary, amount)` and `withdrawRewardToken(to, amount)`.
- Keep all `totalStaked == 0` decommissioning guards intact.

The contract diverges from the plan in three small ways, all clustering around the new `migrator` role:

1. `stakeFor` is gated by `onlyMigrator` (plan said no gate).
2. `unstakeFor` was added (not in plan).
3. `withdrawRewardToken` is gated by `onlyOwnerOrMigrator` (plan said `onlyOwner`).

The combined effect is a single privileged role (migrator) that can both withdraw any staker's NFT principal AND drain all reward tokens when the contract is paused with `totalStaked` at zero. Because the migrator is owner-set, the failure mode requires owner misbehaviour and falls under centralization (Low) under C4 rules — but it is recorded here because it is a documented deviation from the plan that motivated this redesign.

Canonical paths:
- Source: `lib/phoenix-nft-staking/src/NFTStakerV2.sol` (commit 9d71401)
- Plan: `scratchpad/planning-docs/phoenix/phase2/phoenix-nft-staking/v2/balancer-pooler-v3-and-staker-v2-migration-plan.md`
- Tests: `lib/phoenix-nft-staking/test/NFTStakerV2*.sol`

### Plan compliance summary

| Plan-spec | Implementation | Direction |
|---|---|---|
| `stakeFor(beneficiary, amount)` — no authorisation gate; "anyone can call provided they own the NFTs" | `stakeFor` gated by `onlyMigrator` (line 521) | Tighter than plan |
| `stakeFor` + `withdrawRewardToken` are the only additions; no `unstakeFor` | `unstakeFor(beneficiary, amount) onlyMigrator whenNotPaused` exists at lines 543-562 and transfers principal to `msg.sender` | Looser than plan (new privileged write) |
| `withdrawRewardToken(address to, uint256 amount) external onlyOwner` | `withdrawRewardToken` gated by `onlyOwnerOrMigrator` (line 564) | Looser than plan |

---

## [C-01] Combined migrator powers (`unstakeFor` + `onlyOwnerOrMigrator` on `withdrawRewardToken`) yield a single-key drain of all NFTs and all phUSD

**Severity rationale**: Low (Centralization). The migrator address is owner-set via `setMigrator` and revocable. The drain capability is conditional on the owner assigning the role to a misbehaving address (good-faith mis-assignment of a future helper, or compromise/repurposing of an existing one) — there is no path where a non-owner / non-migrator actor causes loss of funds. Under C4 rules this is the canonical centralization framing and the severity ceiling is QA. Promotion to Medium/High would require either (a) a path from a non-privileged actor to migrator status, or (b) demonstrating that the documented helper itself (the current stateless `MigrationHelper`) exhibits the drain behaviour — neither holds today.

**Description**: The plan's NFTStakerV2 deltas section enumerates exactly two surgical additions: `stakeFor(beneficiary, amount)` and `withdrawRewardToken(to, amount) external onlyOwner`. The implementation deviates in three reinforcing ways that, together, hand the migrator role full control of the staker's economic surface:

1. **`unstakeFor` exists at all and routes principal to the migrator.** `unstakeFor(beneficiary, amount)` is gated by `onlyMigrator` and `whenNotPaused`, but performs no check that the position it is unstaking was originally deposited via `stakeFor`. The `users[beneficiary]` ledger co-mingles positions created by `stake(amount)` (direct staker) and `stakeFor(beneficiary, amount)` (migrator-deposited). The only precondition is `users[beneficiary].amount >= amount`. Crucially, line 558 — `stakedToken.safeTransferFrom(address(this), msg.sender, stakedId, amount, "")` — transfers the ERC1155 principal to `msg.sender` (the migrator), not to the beneficiary. The migrator can therefore enumerate any address with a non-zero stake (via `Staked`/`StakedFor` events and the public `users(address)` getter) and call `unstakeFor(victim, users[victim].amount)` to pull the victim's NFTs into the migrator's own wallet. Pending phUSD is correctly routed to the beneficiary by `_safePay(beneficiary, pending)`, but the principal is gone. The function is not mentioned anywhere in the plan; the documented migration is one-way (V1 unstake by users, V2 `stakeFor` by helper).

2. **`withdrawRewardToken` access is widened from plan-spec `onlyOwner` to `onlyOwnerOrMigrator`.** The plan explicitly specifies `withdrawRewardToken(address to, uint256 amount) external onlyOwner`. The implementation uses `onlyOwnerOrMigrator`, letting the migrator address drain the full phUSD balance to an arbitrary recipient `to` once `totalStaked == 0 && paused()` hold. The plan models the helper as a stateless single-purpose contract that "has no admin, no upgrade path. Holds no funds between txs." Granting it (or any future migrator) drain rights expands the authorisation surface beyond the plan.

3. **The two powers compose.** The migrator can: (a) call `unstakeFor(beneficiary_i, users[beneficiary_i].amount)` for each known beneficiary until `totalStaked == 0` — NFTs land at the migrator, each beneficiary's pending phUSD is paid out but the bulk of the reward budget remains in the contract; (b) with `totalStaked == 0`, cooperate with the pauser (or be the pauser) to call `pause()`; (c) call `withdrawRewardToken(migratorAddr, fullBalance)` to drain the remaining phUSD. End state: migrator holds every id-6 NFT that was deposited and the residual phUSD reward budget. The plan models the migrator as orchestrating only the deposit direction of a one-way migration; the implementation gives the same role the ability to undo every deposit AND sweep the reward pool.

**Code reference**:
- `lib/phoenix-nft-staking/src/NFTStakerV2.sol:521-541` — `stakeFor` creates positions credited to `users[beneficiary]` with no migrator-association marker (https://github.com/Behodler/phoenix-nft-staking/blob/9d71401/src/NFTStakerV2.sol#L521-L541).
- `lib/phoenix-nft-staking/src/NFTStakerV2.sol:458-483` — `stake` writes to `users[msg.sender]`, indistinguishable in storage from `stakeFor`-created positions (https://github.com/Behodler/phoenix-nft-staking/blob/9d71401/src/NFTStakerV2.sol#L458-L483).
- `lib/phoenix-nft-staking/src/NFTStakerV2.sol:543-562` — `unstakeFor`, transfers principal to `msg.sender` (migrator) on line 558 (https://github.com/Behodler/phoenix-nft-staking/blob/9d71401/src/NFTStakerV2.sol#L543-L562).
- `lib/phoenix-nft-staking/src/NFTStakerV2.sol:564-578` — `withdrawRewardToken`, `onlyOwnerOrMigrator`, sweeps to arbitrary `to` (https://github.com/Behodler/phoenix-nft-staking/blob/9d71401/src/NFTStakerV2.sol#L564-L578).

**Recommended mitigation**: Three reinforcing changes collapse the trust surface back to what the plan describes:

- Remove `unstakeFor` (and the `UnstakedFor` event) entirely. It is not required by the migration plan; beneficiaries can use the standard `unstake` path themselves. If the function must remain, route the NFT transfer to the beneficiary (`stakedToken.safeTransferFrom(address(this), beneficiary, ...)`) instead of `msg.sender`, eliminating the principal-redirection vector; or tag positions at creation with a `migrator-deposited` flag and constrain `unstakeFor` to only operate on that subset.
- Revert `withdrawRewardToken` to the plan-spec `onlyOwner`. If migrator drain access is genuinely required, update the plan to document the rationale and consider constraining the migrator's allowed `to` parameter to `owner()` — so the migrator can trigger the sweep but cannot redirect funds.
- Document the migrator's intended trust model explicitly on-chain (NatSpec on `setMigrator`, `unstakeFor`, `withdrawRewardToken`) so any future role-holder can be evaluated against the documented authority envelope.

With those three changes, the migrator's only remaining power is the documented `stakeFor` — which itself does not transfer beneficiary funds out of the staker.

---

## [L-01] `withdrawRewardToken` sweeps without syncing dispatcher `mintDebt` or asserting `committedDebt`

**Severity rationale**: Low (QA). Three sub-issues, all in QA territory: (i) the sweep does not first realise dispatcher `mintDebt`, an operational silent-failure footgun bounded to a few mint events of stranded phUSD requiring a follow-up cycle; (ii) `committedDebt` is force-zeroed without verification, eliminating an invariant trip-wire — magnitude bounded to O(wei) dust from `emergencyWithdraw` floor-division rounding; (iii) the NatSpec ("`committedDebt` should already be 0", framed as "defence in depth") does not match runtime behaviour (force-zero without check). Not exploitable by an outsider — only the owner/migrator can call `withdrawRewardToken`. Promotion would require demonstrating a non-trivial fund-loss path; the current state is operator workflow risk and state-handling precision.

**Description**: `withdrawRewardToken` requires `totalStaked == 0 && paused()` but otherwise sweeps the on-chain reward-token balance and unconditionally rewrites `rewardBudget` and `committedDebt` after the transfer (lines 575-576). It does NOT call `_syncBudget()` or `_updatePool()` before the transfer, and it force-zeros `committedDebt` regardless of its pre-call value. The NatSpec (lines 570-574) describes this as "defence in depth" on the assumption that `totalStaked == 0 ==> committedDebt == 0`, but the function does not actually verify that assumption. Three distinct correctness/operational gaps follow:

1. **Dispatcher hook `mintDebt` is not realised before sweep.** If `BalancerPoolerMintDebtHook` still has a non-zero `mintDebt()` at the moment of withdrawal (e.g. a final `onDispatch` accrued debt after the last `_syncBudget` call, or continued V3 pooler activity on the shared hook), that obligation persists at the hook side but is not pulled into the staker before the sweep. After the sweep the staker has zero phUSD balance but the hook still owes the staker `mintDebt`. The protocol must remember to call `pullAndRefresh()` (owner-only) first, or call `withdrawRewardToken` a second time after a follow-up `pull()`. The plan frames `withdrawRewardToken` as "the decommissioning sweep that would have prevented the ~910 phUSD orphaning in the current incident" — a single-call sweep that misses `mintDebt` does not fully prevent the orphaning class. Note: `pullAndRefresh` is `onlyOwner`, so the migrator alone (without owner) cannot drain `mintDebt` — they can only sweep on-chain balance. If the trust model assumes the migrator can fully decommission the contract, this is a gap.

2. **`committedDebt` force-zero masks `emergencyWithdraw` dust residual.** `emergencyWithdraw` (lines 628-651) computes each user's `pending` via two floor divisions: `pending = (amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt`. Floor truncation can produce a per-user `pending` whose sum across all users is strictly less than `committedDebt` (because dust truncates downward per user). When the last staker emergency-withdraws, the residual `committedDebt > 0` persists. `withdrawRewardToken` then force-sets `committedDebt = 0` at line 576, eliminating an outstanding (tiny) obligation rather than recognising it. Magnitude: bounded by O(N) wei where N is the number of historical stakers; in practice a handful of wei. The documented invariant `totalStaked == 0 ==> committedDebt == 0` is not actually maintained.

3. **Force-zero hides any future upstream invariant breach.** Although in current code paths `totalStaked == 0` implies `committedDebt` is at most floor-division dust, the function does not verify that — a future code change (or unanticipated interaction with `emergencyWithdraw` ordering) that left `committedDebt > 0` would be silently absorbed by the `committedDebt = 0` write, with no event/revert to surface the inconsistency. The strong invariant `balance == rewardBudget + committedDebt` is re-established by the assignment, but any prior breach is hidden rather than reported.

**Code reference**:
- `lib/phoenix-nft-staking/src/NFTStakerV2.sol:564-578` — `withdrawRewardToken` body (https://github.com/Behodler/phoenix-nft-staking/blob/9d71401/src/NFTStakerV2.sol#L564-L578).
- `lib/phoenix-nft-staking/src/NFTStakerV2.sol:326-339` — `_syncBudget` (not called) (https://github.com/Behodler/phoenix-nft-staking/blob/9d71401/src/NFTStakerV2.sol#L326-L339).
- `lib/phoenix-nft-staking/src/NFTStakerV2.sol:347-363` — `_updatePool` (not called) (https://github.com/Behodler/phoenix-nft-staking/blob/9d71401/src/NFTStakerV2.sol#L347-L363).
- `lib/phoenix-nft-staking/src/NFTStakerV2.sol:628-651` — `emergencyWithdraw` (source of dust residual) (https://github.com/Behodler/phoenix-nft-staking/blob/9d71401/src/NFTStakerV2.sol#L628-L651).
- `lib/yield-claim-nft/src/V2/hooks/BalancerPoolerMintDebtHook.sol:127-134` — `pull()` is the only way to realise `mintDebt`.

**Recommended mitigation**: Apply three small changes at the top of `withdrawRewardToken`:

- Call `_syncBudget()` (or directly invoke the `dispatcherHook.pull()` leg) before the transfer so the sweep always operates against the full `V = balance + mintDebt`. `_syncBudget` is idempotent and cheap when `totalStaked == 0`. Alternative: add a `require(address(dispatcherHook) == address(0) || dispatcherHook.mintDebt() == 0, "NFTStakerV2: pending mint debt")` guard so the sweep cannot run with stranded debt, forcing the operator to pull first.
- Replace `committedDebt = 0` with `require(committedDebt == 0, "committedDebt nonzero")` so a real invariant breach reverts rather than being hidden. If the dust residual from `emergencyWithdraw` is considered acceptable, document it explicitly in the NatSpec — e.g. "`committedDebt` may carry sub-wei dust when `totalStaked` reaches zero via `emergencyWithdraw` paths; force-zero accepts this rounding loss to the protocol."
- Update the NatSpec to reflect whichever option is chosen, so the on-chain documentation matches what the code actually maintains.

---

## [L-02] `stakeFor` adds an `onlyMigrator` gate that the plan explicitly says should not exist

**Severity rationale**: Low (QA). Verbatim spec-vs-code deviation — the plan's NFTStakerV2 deltas section states "No authorisation gate — anyone can call `stakeFor` provided they own the NFTs to deposit"; the implementation gates it with `onlyMigrator`. The deviation is in the more restrictive direction, so no security weakening occurs in isolation and there is no asset-loss path. Recorded as QA because: (a) the documented trust model does not match what users can verify on-chain, and (b) the deviation pairs with C-01 in the *opposite* direction on the adjacent function `withdrawRewardToken` — together they concentrate migrator power. Promotion would require an exploitation path; none exists.

**Description**: The plan's "NFTStakerV2 deltas / `stakeFor`" section states verbatim: *"No authorisation gate — anyone can call `stakeFor` provided they own the NFTs to deposit. The deposit requirement (`safeTransferFrom` from `msg.sender`) prevents griefing."* The implementation gates `stakeFor` with `onlyMigrator` (line 521). This is a tightening of access, not a loosening, but it remains a deviation from the documented design and produces two concrete effects:

1. It blocks any third party (a future helper, a UI batch contract, an EOA donating NFTs to a beneficiary) from staking on someone's behalf — the plan modelled this as permissionless because the caller pays the NFTs, so there is no economic griefing vector.
2. It introduces the same migrator-role trust surface flagged in C-01.

Once the migration window closes (no helper needed) the staker retains a `migrator` slot that is the sole address able to call `stakeFor`. Owner can clear it via `setMigrator(address(0))`. If the owner forgets, the migrator retains write access to the staker's user mapping even though no helper is needed anymore. Magnitude: no direct fund loss; the issue is that the on-chain trust model does not match the documented trust model. Anyone who calls `stakeFor` from a non-migrator address gets a misleading "caller is not migrator" revert, suggesting an authorisation rule the plan did not intend.

Secondary: with `onlyMigrator` gating, the plan's "restrict `stakeFor` to brand-new beneficiaries" open question is closed by trust rather than by code. A buggy migrator that calls `stakeFor` for an existing user still settles the pending at the OLD price (correct routing per `test_stakeFor_existingBeneficiary_paysPendingToBeneficiaryNotMigrator`), but the on-chain check the open question contemplated does not exist.

Wider pattern: the implementation diverges from the plan on two adjacent functions in opposite directions — `stakeFor` is more restrictive than plan (`onlyMigrator` gate the plan does not authorise), `withdrawRewardToken` is less restrictive than plan (`onlyOwnerOrMigrator` instead of `onlyOwner`). Both deviations concentrate power at the migrator address.

**Code reference**:
- `lib/phoenix-nft-staking/src/NFTStakerV2.sol:521-541` — `stakeFor` with `onlyMigrator` gate (https://github.com/Behodler/phoenix-nft-staking/blob/9d71401/src/NFTStakerV2.sol#L521-L541).
- Plan: `scratchpad/planning-docs/phoenix/phase2/phoenix-nft-staking/v2/balancer-pooler-v3-and-staker-v2-migration-plan.md` — NFTStakerV2 deltas / `stakeFor`.

**Recommended mitigation**: Pick one of:

- Remove `onlyMigrator` from `stakeFor` to match the plan ("anyone with the NFTs can deposit on a beneficiary's behalf"). The `safeTransferFrom` precondition is sufficient anti-griefing per the plan's reasoning.
- Keep the gate and update the plan to reflect the implemented restriction. Document why permissionless `stakeFor` was rejected, and add an operational requirement to call `setMigrator(address(0))` when the migration window closes so the role does not linger.

Either way, the documented trust model and the on-chain trust model should agree.
