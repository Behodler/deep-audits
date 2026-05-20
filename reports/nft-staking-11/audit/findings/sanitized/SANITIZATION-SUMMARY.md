# Sanitization Summary - nft-staking-11

**Input:** 5 deduplicated findings
**Kept:** 3 findings (DEDUP-01, DEDUP-03, DEDUP-04)
**Dropped:** 2 findings (DEDUP-02, DEDUP-05)
**Flagged:** 0

## Filters Applied

1. **Centralization framing filter (parent CLAUDE.md):** owner/migrator privilege findings that do not (a) identify a specific behaviour violating project documentation, (b) identify a state-machine/invariant bug independent of role good-faith, or (c) identify an operational silent-failure footgun are dropped.
2. **Paid-customer-as-attacker framing (user memory):** none of the 5 findings used this framing; no action taken.
3. **Plan-as-spec:** the plan IS the known-issues surface. Deviations from the plan are findings; plan-accepted behaviours (double-reward window during migration, stranded phUSD at sunset, 30% APY old-staker tail) are not.
4. **Source-repo read-only rule:** kept findings reference `lib/phoenix-nft-staking/src/NFTStakerV2.sol`. No fix can be applied to that submodule directly — fixes must be coordinated upstream (Behodler-org). All kept findings respect this constraint (recommendations are described, not patched).

## Per-Finding Dispositions

### DEDUP-01 - Combined migrator drain (unstakeFor + onlyOwnerOrMigrator on withdrawRewardToken)

**Disposition:** KEPT
**Path:** `sanitized/01-migrator-drain-via-unstakeFor-and-withdrawRewardToken.json`

**Justification:** Survives the centralization filter on two independent grounds:
- **Plan deviation (specific):** The plan's NFTStakerV2 deltas section literally specifies `withdrawRewardToken(address to, uint256 amount) external onlyOwner` (plan line 188). The implementation uses `onlyOwnerOrMigrator`. This is a verbatim spec-vs-code mismatch.
- **Plan deviation (omission):** `unstakeFor` is not in the plan's enumeration of NFTStakerV2 deltas at all. The plan models migration as one-way (V1.unstake by users; V2.stakeFor by helper).
The combination produces a single-key drain path that the plan never authorised. Severity remains Low (the current deployed migrator is the stateless `MigrationHelper`, so the risk is structural/future-incident rather than immediate), but the finding survives because the bar for keeping a migrator finding is plan deviation, which is satisfied twice over.

### DEDUP-02 - setMigrator no in-flight guard

**Disposition:** DROPPED
**Path:** `sanitized/dropped/02-setMigrator-no-inflight-guard.dropped.json`

**Justification:** Centralization framing without new privilege:
- The owner already controls migrator assignment. Rotating the role does not create a power that did not already exist — by design, the new migrator inherits the role's full power set.
- The plan does not specify any setMigrator timing invariant, so there is no plan deviation to anchor the finding.
- No state-machine bug holds with the owner acting in good faith — the "asymmetry" is the expected behaviour of a role pointer.
- The underlying capability (migrator can drain in-flight `stakeFor`-deposited NFTs via `unstakeFor`) is already captured by DEDUP-01. Adding DEDUP-02 only describes a sub-scenario triggered by rotation; it does not change the privilege envelope.
- Falls squarely under "the owner could do X" without a concrete loss-of-funds path beyond documented role power.

### DEDUP-03 - withdrawRewardToken debt accounting (dispatcher sync, committedDebt force-zero)

**Disposition:** KEPT
**Path:** `sanitized/03-withdrawRewardToken-debt-accounting.json`

**Justification:** Survives the centralization filter on the **operational silent-failure** carve-out:
- **Sub-issue 1 (dispatcher hook mintDebt):** `withdrawRewardToken` does not call `_syncBudget()` or `pull()` before sweeping. If `BalancerPoolerMintDebtHook.mintDebt() > 0` at sweep time, that obligation is stranded at the hook with no on-chain signal. A subsequent `pull()` from any caller deposits fresh phUSD into the paused, empty staker — exactly the orphaning scenario the plan claims this function was designed to prevent (plan line 205-206). This is the "operational footgun that would silently fail without the role noticing" case.
- **Sub-issues 2 and 3 (committedDebt dust force-zero):** the function force-writes `committedDebt = 0` without verifying the invariant, hiding any pre-existing breach. The NatSpec claims this is "defence in depth" on an invariant the code doesn't verify. The dust magnitude is O(wei) but the NatSpec-vs-behaviour mismatch is real.
Keep as QA hardening. Severity Low.

### DEDUP-04 - stakeFor onlyMigrator inverts plan

**Disposition:** KEPT (as documentation-vs-code note)
**Path:** `sanitized/04-stakeFor-onlyMigrator-inverts-plan.json`

**Justification:** This is a borderline case. The plan explicitly states `stakeFor` should have "no authorisation gate — anyone can call `stakeFor` provided they own the NFTs to deposit." The implementation gates it with `onlyMigrator`. This is a plan deviation, satisfying the kept-finding bar.

However, the deviation is *more restrictive* than the plan — it removes capability rather than adding it, so no security weakening occurs. Two reasons to keep anyway:
1. The "plan is the spec" rule applies symmetrically: a more-restrictive implementation still mismatches the documented design. Users reading on-chain code will see a different trust model than the plan documents.
2. The finding pairs with DEDUP-01 to surface a directional pattern: on adjacent functions, the implementation is more restrictive than plan in one direction (`stakeFor`) and less restrictive in the other (`withdrawRewardToken`), both concentrating power at the migrator. The pattern itself is a useful signal.

Keep as a low-severity / documentation-vs-code finding. The fix is symmetric: either remove `onlyMigrator` from `stakeFor` (match plan) or update the plan (match code).

### DEDUP-05 - Migrator trust model undocumented

**Disposition:** DROPPED
**Path:** `sanitized/dropped/05-migrator-trust-model-undocumented.dropped.json`

**Justification:** Below the sanitization bar:
- Pure documentation finding. The recommendation is to expand NatSpec describing the role-holder profile.
- No specific code behaviour violates project documentation — the on-chain NatSpec accurately describes the migrator's capabilities; the gap is only that it does not describe the assumed role-holder profile.
- No state-machine bug, no invariant break, no silent-failure footgun.
- The substantive concern (the migrator's powers exceed what the plan's helper actually uses) is already actionable through DEDUP-01, which targets the code surface directly. Once DEDUP-01 is applied, the trust-model question is largely moot because the role's powers shrink to match the plan.
- This is "the owner could do X" rephrased as "we should warn future readers that the owner could do X". Either the code is fixed (DEDUP-01) or it isn't; an additional NatSpec paragraph is not a separate finding.

## Cross-Submodule Dependency Note

None of the 3 kept findings require changes outside `lib/phoenix-nft-staking`. DEDUP-03 mentions `lib/yield-claim-nft/src/V2/hooks/BalancerPoolerMintDebtHook.sol:pull()` but only as a reference — the fix lives in `NFTStakerV2.withdrawRewardToken`. No cross-submodule fix is implied. Read-only rule respected.

## Output Inventory

```
sanitized/
  SANITIZATION-SUMMARY.md                                          (this file)
  01-migrator-drain-via-unstakeFor-and-withdrawRewardToken.json    (kept)
  03-withdrawRewardToken-debt-accounting.json                      (kept)
  04-stakeFor-onlyMigrator-inverts-plan.json                       (kept)
  dropped/
    02-setMigrator-no-inflight-guard.dropped.json                  (dropped)
    05-migrator-trust-model-undocumented.dropped.json              (dropped)
```
