# QA Report for phoenix-nft-staking (run-22)

**Project**: phoenix-nft-staking
**Commit**: `bb4fea02ceecce879bab15122b1f378f76d2a0b6` (`bb4fea0`)
**Mode**: regression / fix-wave (stories 026 / 027)

**Scope note**: This run's one High/Medium finding — the multi-token nudge over-funding
issue — was **escalated to Medium (M-01)** and carries its own individual submission
(`M-01-multitoken-aggregate-nudge-overfund.md`); it is **not** part of this QA bundle. The
findings below are the run's genuine Low-severity items. Carryover from earlier audits is
copied forward (pruned to still-open entries) by finding-manager under
`submissions/carryover/qa-report-<NN>.md` and is **not** restated here; this run's L-01..L-04
sequence covers only run-22's new findings.

## Summary

| Severity            | Count |
|---------------------|-------|
| Low Risk            | 3     |
| Centralization Risk | 0     |
| **Total**           | **3** |

> **Label note:** `L-02` is a **deliberate gap** — the finding previously drafted at L-02
> (multi-token nudge aggregate over-funding) was escalated out of the Low band to **Medium
> M-01** and submitted individually. The three Low findings below are labeled L-01, L-03, and
> L-04 (the last carrying finding-record id `MR-001`, a manual-review item requiring an
> explicit human disposition — see the finding).

---

## Low Risk Findings

### [L-01] Swap-and-pop whitelist removal reorders `_nudgeTokens`; positional `minRewards[i]` can bind to the wrong token <!-- id: pns22l1 -->

**Location**: [BatchNFTMinterMultiToken.sol#L224](https://github.com/Behodler/phoenix-nft-staking/blob/bb4fea0/src/BatchNFTMinterMultiToken.sol#L224) (`setNudgeTokenWhitelist` / `batchMint`)

**Fingerprint**: `6b8faaf6`

**Description**: Removing a whitelisted token via `setNudgeTokenWhitelist(token, false)` uses
swap-and-pop — the **last** token in `_nudgeTokens` is moved into the removed slot — so
`getNudgeTokens()` ordering changes. A caller who fetched the token order **before** the
reorder submits `batchMint` with a positional `minRewards[]` array now mapped to the wrong
tokens, and the per-token floor check compares each stale `minRewards[i]` against a different
token's snapshot.

**Impact**: **None to protocol funds.** `minRewards[]` is a **floor check only** — the whole
prior pot is paid regardless of the floor — so no over- or under-payment of assets results.
Worst case for a caller is an unexpected revert (their token's floor applied to a different
token after the reorder = spurious self-DoS), or a floor guarantee silently bound to a
different token than intended (positional / UI mismatch). CODE-VER-07 confirms index
integrity and length checks (no out-of-bounds read, no wrong-token payout). This is a
non-obvious owner/caller ordering footgun (Law 3).

**Recommendation**: Callers/UI must re-fetch `getNudgeTokens()` immediately before every
`batchMint` (already stated in NatSpec). Consider a token-keyed `minRewards` mapping, or an
expected-ordering hash argument, so positional drift **fails closed** against the intended
token rather than silently rebinding to another.

**Distinction**: Kept distinct from ledger `990d8c37` (L-05, wont-fix, `minRewards`
zero-default opt-out) and `cabd4a3d` (Q-01, open) per dedup — different root cause; do not
collapse.

---

### [L-03] `NFTStakerDepletionV2.depositFor` carries the unconditional tail `_recomputeSchedule` (run-19 L-01 class reproduced on the V2 file) <!-- id: pns22l3 -->

**Location**: [NFTStakerDepletionV2.sol#L793](https://github.com/Behodler/phoenix-nft-staking/blob/bb4fea0/src/NFTStakerDepletionV2.sol#L793) (`depositFor`)

**Fingerprint**: `8db31a6b`

**Description**: `depositFor` carries an unconditional tail `_recomputeSchedule` that sets
`windowEnd = now + windowSeconds` on **every** migrator-driven deposit. The story-026 V2
clone reproduced the run-19 L-01 emission-window-restart tail verbatim.

**Impact**: **None to total value.** Every `depositFor` restarts the depletion window; this
**conserves budget** but **shifts emission timing** (slows emission), and is therefore a
non-leak. The depletion rate is `budget / window` and `totalStaked`-**independent**, so there
is no over-emission and no survivor re-rate (ECON-VER-01 confirms V2 solvent). Access-gated:
`onlyMigrator` + Active-gated `depositFor`. Low footgun / informational.

**Recommendation**: As with the run-19 L-01 original, gate the schedule recompute so a
migrator-driven deposit does not unconditionally restart the emission window. Timing-only and
access-gated; remediate together with the V1 class if/when addressed.

**Linked ledger entry**: Same class as
`ced20f2e93493ac86505892c4038fbe58edf00d660a0d4c1ff588c65226de31c` (**L-01, run-19, open**)
on `NFTStakerDepletion.depositFor`. Filed as a **new linked instance** (new first-party file,
new fingerprint — dedup will not auto-match), not a duplicate and not a suppression. Do **not**
bump `ced20f2e`'s `lastSeenRun` (its V1 site was not re-observed this run) and do **not**
close either against the other.

---

### [L-04] `NFTStakerDepletionV2.emergencyWithdraw` skips `_syncBudget`/`_updatePool` (M-02 over-emission class) on the new, undeployed V2 clone — HUMAN DISPOSITION REQUIRED <!-- id: pns22l4 -->

**Location**: [NFTStakerDepletionV2.sol#L639](https://github.com/Behodler/phoenix-nft-staking/blob/bb4fea0/src/NFTStakerDepletionV2.sol#L639) (`emergencyWithdraw`)

**Fingerprint**: `425ef6e3` · **Finding-record id**: `MR-001` (manual-review)

**Description**: `emergencyWithdraw` (:639) decrements `totalStaked` but skips
`_syncBudget`/`_updatePool` (per its own NatSpec) and recycles forfeited pending from
`committedDebt` back into `rewardBudget` without a schedule recompute — the same code shape as
ledger **M-02** (`911c54fd`) on V1 `NFTStaker`, reproduced verbatim on the new V2 clone.

**Impact**: Over-emission M-02 class present on the V2 clone. **Attenuated / likely benign**:
the depletion rate is `budget / window` and `totalStaked`-**independent**, so the
`oldTotal/newTotal` survivor re-rate that makes M-02 bite on `NFTStaker` does not directly
apply (`911c54fd` itself notes the shape is "BENIGN on the NFTStakerDepletion copy").
ECON-VER-01 verified it present-verbatim / not a regression. Filed at Low reflecting the
attenuation — but the **disposition is a human call** (see below).

**Recommendation**: Resize `rewardRate` inside `emergencyWithdraw` (or call
`_syncBudget`/`_updatePool`) as with the M-02 arithmetic fix. The fix is **cheap here because
the V2 clone is not yet deployed.** Operator **must re-affirm disposition before V2 deploys**;
do **not** auto-inherit the V1 wont-fix.

**⚠ HUMAN-DECISION DISCLOSURE (do NOT close as `acknowledged`)**: The V1 instance is ledger
**M-02** (`911c54fd`), **wont-fix** (owner triage 2026-06-09). That wont-fix rests on two
load-bearing premises — quoted: *"NFTStaker is deployed and non-upgradeable … exposes NO
migrate-on-behalf mechanism … so a migration would force every staker to self-exit and
re-stake. Owner accepts the residual over-emission rather than force a migration."* **Both
premises are FALSE on `NFTStakerDepletionV2`**: (a) it is **not deployed** (the fix is cheap),
and (b) it **does** expose migrate-on-behalf (`depositFor` + migrator role). The
"migration prohibitively costly" ground that carried the V1 wont-fix therefore **does not
transfer**. New file → new fingerprint (`425ef6e3`), which dedup will not auto-match. The V1
entry `911c54fd` stands untouched; this is filed **OPEN** (not `acknowledged`, not
suppressed). The operator must make an explicit call — extend the wont-fix to V2 with a
V2-scoped rewritten rationale, land the cheap fix on the undeployed file, or record a linked
Low/QA disposition — **before any V2 deploy**.

---

## Centralization Risks

None identified this run. (No new C-XX findings.)

---

## Appendix — automated QA report (4naly3er)

The C4-style automated QA/gas baseline was regenerated this run with **4naly3er** over the
first-party `lib/phoenix-nft-staking/src` contracts (12 files, scope-listed; `basePath` set to
the submodule root so `remappings.txt` resolves correctly — no symlink workaround). It ran
**cleanly** and its full markdown output is attached alongside this bundle at:

- **`submissions/4naly3er-report.md`** (14 Gas-optimization families + NC/Low tool notes over
  the run-22 source at `bb4fea0`).

The tool output is the automated bot baseline for the Low/QA layer and does not override any
manual finding above.
