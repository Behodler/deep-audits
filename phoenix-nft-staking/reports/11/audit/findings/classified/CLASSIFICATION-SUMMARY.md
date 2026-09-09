# Classification Summary - phoenix-nft-staking-11

**Mode:** C4 Regular Audit
**Input:** 3 sanitized findings (all sanitizer-tagged Low)
**Output:** 3 classified findings, all confirmed Low / Centralization
- High: 0
- Medium: 0
- Low/QA: 2 (L-01, L-02)
- Centralization: 1 (C-01)

## C4 Criteria Applied

- **High (3):** Assets stolen/lost/compromised directly or via valid attack path without hypotheticals.
- **Medium (2):** Assets not at direct risk; protocol function/availability impacted, or value leak with stated assumptions and external requirements.
- **Low/QA:** State handling, spec deviations, centralization risks. Non-critical issues are discouraged.

## Parent CLAUDE.md Constraint Applied

> Centralization risks (owner-set role with broad powers) belong in QA. The migrator role is owner-set. Even though DEDUP-01 lets the migrator drain NFTs + phUSD, the trust model puts this firmly in the centralization-QA bucket UNLESS there is a path where a non-owner / non-migrator actor causes the loss.

This rule was the decisive constraint for DEDUP-01. The drain capability is gated by owner action (setMigrator to an unsafe address) plus a privileged role-holder going rogue. No non-owner / non-migrator path exists. Classified as C-01.

## Per-Finding Classification

### C-01 - Combined migrator powers yield single-key drain of NFTs and phUSD
**Source:** DEDUP-01 (sanitized 01-migrator-drain-via-unstakeFor-and-withdrawRewardToken.json)
**Sanitizer severity:** Low
**Classified severity:** Low (Centralization)
**C4 label:** C-01
**Output:** `low/01-migrator-drain-via-unstakeFor-and-withdrawRewardToken.json`

**Rationale.** The migrator role is owner-set via `setMigrator()`. The attack scenario as documented requires the owner to assign the role to a buggy, compromised, or repurposed contract (step 3: "Owner calls `setMigrator(newHelper)` in good faith"). Under the documented deployment (stateless `MigrationHelper`), the attack is structurally impossible. No non-owner / non-migrator path causes the loss. This is the canonical centralization framing called out in the parent CLAUDE.md constraint.

The two underlying plan deviations are real and worth surfacing:
1. `withdrawRewardToken` is `onlyOwnerOrMigrator` rather than plan-spec `onlyOwner`.
2. `unstakeFor` exists at all (not enumerated in plan NFTStakerV2 deltas) and routes principal to `msg.sender`.

These are documented in the centralization writeup so the audit consumer can act on them, but their exploitable impact is bounded by trust in the owner-assigned migrator. C4 ceiling for this class is QA / Centralization (label C-01).

**Sanitizer's own framing supports the classification:** "the current deployed migrator (MigrationHelper, stateless, single-purpose) does not exhibit this behaviour - the concern is the role's powers as encoded in the staker, not the current role-holder."

### L-01 - withdrawRewardToken debt accounting (dispatcher sync, committedDebt force-zero)
**Source:** DEDUP-03 (sanitized 03-withdrawRewardToken-debt-accounting.json)
**Sanitizer severity:** Low
**Classified severity:** Low (QA)
**C4 label:** L-01
**Output:** `low/03-withdrawRewardToken-debt-accounting.json`

**Rationale.** Squarely in C4's QA bucket ("state handling, function incorrect as to spec, issues with comments"). Three sub-issues, all QA-class:
1. Sweep does not call `_syncBudget()` / pull dispatcher `mintDebt` first - operational silent-failure footgun. Magnitude: a few mint events of stranded phUSD requiring a follow-up sweep cycle. Recoverable.
2. `committedDebt` force-zero without verification - eliminates an invariant trip-wire and accepts O(wei) dust loss from `emergencyWithdraw` floor-division.
3. NatSpec ("committedDebt should already be 0" framed as "defence in depth") does not match runtime behaviour (unverified overwrite).

The finding's own impact section says "Operational and defensive, not directly exploitable" and "Not exploitable by an outsider - only the owner/migrator can call `withdrawRewardToken`." No direct asset risk, no protocol availability impact, no external attacker path. L-01.

### L-02 - stakeFor onlyMigrator inverts plan
**Source:** DEDUP-04 (sanitized 04-stakeFor-onlyMigrator-inverts-plan.json)
**Sanitizer severity:** Low
**Classified severity:** Low (QA)
**C4 label:** L-02
**Output:** `low/04-stakeFor-onlyMigrator-inverts-plan.json`

**Rationale.** C4 QA bucket: "function incorrect as to spec." The plan literally states `stakeFor` should have "no authorisation gate"; the implementation gates it with `onlyMigrator`. Verbatim spec-vs-code deviation, but in the *more restrictive* direction - no security weakening, no asset-loss path, no availability impact (users still have the standard `stake()` path).

The finding's own attack_scenario reads: "Not an attack scenario per se - this is an intent-vs-implementation mismatch." Pure documentation deviation. L-02.

The value of keeping this finding (beyond the spec deviation itself) is the directional pattern with C-01: on adjacent functions, the implementation deviates from plan in opposite directions, both concentrating power at the migrator address.

## Classification Decisions: Why Nothing Escalated

All three findings were verified against C4 H/M criteria and confirmed at Low.

**Why not High?**
- High requires "assets stolen/lost/compromised directly or via valid attack path without hypotheticals."
- DEDUP-01 attack path requires: owner mis-assigns migrator role + migrator goes rogue + pauser cooperates. That is a hypothetical assumption stack gated by owner trust, not a permissionless attack. Per parent CLAUDE.md, the centralization framing is QA.
- DEDUP-03 is not exploitable by any outsider - "only the owner/migrator can call withdrawRewardToken."
- DEDUP-04 has no attack scenario; the finding text explicitly says so.

**Why not Medium?**
- Medium requires "protocol function/availability impacted, OR value leak with stated assumptions and external requirements."
- DEDUP-01 does not impact protocol function under the documented role-holder (MigrationHelper). The value-leak path is gated by owner action which is the centralization carve-out, not a Medium external-requirement framing.
- DEDUP-03 has bounded O(wei) dust magnitude and operational workflow recoverability. No availability impact (the staker still functions; decommissioning hygiene only).
- DEDUP-04 has zero magnitude (implementation is more restrictive than plan; users have alternate path via `stake()`). No function/availability impact.

**Plausibility note (for completeness):** If DEDUP-01 were re-framed without the parent-CLAUDE.md centralization constraint, it would still be Implausible High at best (requires owner mis-assignment + rogue role-holder + pauser cooperation - the canonical "validator collusion / extraordinary circumstances" pattern). The constraint resolves the ambiguity decisively to QA.

## Output Inventory

```
findings/
  high/                                              (empty)
  medium/                                            (empty)
  low/
    01-migrator-drain-via-unstakeFor-and-withdrawRewardToken.json  (C-01)
    03-withdrawRewardToken-debt-accounting.json                    (L-01)
    04-stakeFor-onlyMigrator-inverts-plan.json                     (L-02)
  classified/
    CLASSIFICATION-SUMMARY.md                        (this file)
```

## Submission Implications

All three findings will be bundled into a single QA report per C4 convention:
- Centralization section: C-01
- Low / state-handling section: L-01, L-02

No individual H or M submissions are warranted from this project's findings. The QA bundle should call out the directional pattern across C-01 and L-02 (migrator privilege concentration via plan deviations in both directions on adjacent functions) as a meta-observation worth the project team's attention.
