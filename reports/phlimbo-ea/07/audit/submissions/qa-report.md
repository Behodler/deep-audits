# QA Report for phlimbo-ea

**Project**: phlimbo-ea
**Run**: reports/phlimbo-ea/07
**Commit**: `7045a96` (`7045a96ecaf15e9443cc969664278b51a9a9c046`)
**Scope**: `src/PhlimboV3.sol`, `src/MigratorV2V3.sol`

This report bundles the Low-severity and QA-level findings from run 07. High and Medium
findings (H-01, M-01, M-02) are submitted separately. Spec-conformance / carryover items
(DEDUP-03b, DEDUP-04, DEDUP-10) are handled in their own channels and are not repeated here.

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 3 |
| QA | 1 |
| **Total** | **4** |

| Label | Title | Contract |
|-------|-------|----------|
| L-01 | Permissionless `collectReward` re-anchors the stable `rewardPerSecond` over a fresh depletion window | PhlimboV3 |
| L-02 | `_tryTransfer` `abi.decode` reverts on short return-data, bricking a `batchClaim` flush chunk | PhlimboV3 |
| L-03 | Zombie `_stakers` entries from full `pauseWithdraw` exits monotonically inflate owner flush gas | PhlimboV3 |
| Q-01 | `withdrawAll` escape hatch omits a `promoToken` sweep | MigratorV2V3 |

> **Informational note (not a submitted Low):** Consider relaxing the strict promo-funding
> balance-delta assertion (`balanceOf(after) - balanceBefore == amount` in `startPromotion` /
> `topUpPromotion`) if a fee-on-transfer or rebasing promo token is ever intended to be supported.
> This was evaluated as a candidate Low (former L-04) but is suppressed as a C4 known-invalid
> (owner-vetted fee-on-transfer / non-standard ERC-20; the revert is retryable, owner-invoked, and
> carries no fund risk). Recorded here for visibility only; not a submitted finding.

---

## Low Risk Findings

### [L-01] Permissionless `collectReward` re-anchors the stable `rewardPerSecond` over a fresh depletion window <!-- id: pe7l1 -->

**Location**: [`PhlimboV3.sol#L559`](../../lib/phlimbo-ea/src/PhlimboV3.sol#L559) (`collectReward`), recompute at [`L570`](../../lib/phlimbo-ea/src/PhlimboV3.sol#L570)

**Description**: `collectReward` is permissionless and, after topping up the reward balance,
recomputes the stable payout rate as `rewardPerSecond = (rewardBalance * PRECISION) / depletionDuration`
over a full, fresh `depletionDuration` (L570). A third party can therefore repeatedly restart
the stable-reward decay schedule, stretching the payout curve for existing stakers. This is the
same class as the V1 finding (ledger V1-M-02, acknowledged and downgraded to Low) now recurring
on the V3 stable-rate window. It is distinct from H-01, which concerns the *promo* accumulator
advance during Flushing; this finding concerns the *stable* rate window only.

**Impact**: Griefing of the stable-reward schedule with no fund theft. The `amount > 0` gate at
[`L560`](../../lib/phlimbo-ea/src/PhlimboV3.sol#L560) forces each call to contribute a real,
non-zero reward deposit, so the attack is costly and self-limiting — the free-poke availability
angle present in V1 is neutralised. Reward accounting stays correct; only the disbursement rate
is perturbed.

**Recommendation**: When `collectReward` tops up an already-active depletion window, extend or
blend the remaining schedule rather than resetting `depletionDuration` from scratch — e.g. compute
the new rate over the *remaining* window, or gate the rate-recompute path so it cannot be driven by
an unprivileged caller. Consistent with the V1-M-02 acknowledgement, at minimum document the
permissionless re-anchor as accepted behaviour.

---

### [L-02] `_tryTransfer` `abi.decode` reverts on short return-data, bricking a `batchClaim` flush chunk <!-- id: pe7l2 -->

**Location**: [`PhlimboV3.sol#L816`](../../lib/phlimbo-ea/src/PhlimboV3.sol#L816) (`_tryTransfer`), decode at [`L819`](../../lib/phlimbo-ea/src/PhlimboV3.sol#L819); called from `batchClaim` at [`L459`](../../lib/phlimbo-ea/src/PhlimboV3.sol#L459)

**Description**: `_tryTransfer` returns `callSuccess && (returndata.length == 0 || abi.decode(returndata, (bool)))`
(L819). The `returndata.length == 0` branch handles no-return tokens, but a token that returns
*non-empty* return-data shorter than 32 bytes causes `abi.decode(returndata, (bool))` to revert
rather than yield `false`. Because `_tryTransfer` is invoked inside the `batchClaim` flush loop
(L459), such a revert bubbles up and reverts the entire flush chunk. Since `finalizePromotion`
requires `flushCursor == _stakers.length()` ([`L483`](../../lib/phlimbo-ea/src/PhlimboV3.sol#L483)),
the promo cannot be finalized for that token class.

**Impact**: Token-assumption-gated availability edge; no fund loss. The trigger requires the owner
to configure a promo with a non-standard token whose `transfer` returns malformed short data. Promo
tokens are owner-vetted per promotion, so the trigger is narrow, but the `_tryTransfer` wrapper
exists precisely to uphold the stated "flush must never brick" guarantee, and this edge undermines
it.

**Recommendation**: Treat malformed/short return-data as a failed transfer (return `false`) instead
of reverting — e.g. gate the decode on `returndata.length >= 32` and otherwise return `false`:

```solidity
if (!callSuccess) return false;
if (returndata.length == 0) return true;
if (returndata.length < 32) return false;
return abi.decode(returndata, (bool));
```

This keeps the flush non-bricking for any transfer-return shape.

---

### [L-03] Zombie `_stakers` entries from full `pauseWithdraw` exits monotonically inflate owner flush gas <!-- id: pe7l3 -->

**Location**: [`PhlimboV3.sol#L537`](../../lib/phlimbo-ea/src/PhlimboV3.sol#L537) (`pauseWithdraw`); contrast the normal `withdraw` full-exit removal at [`L658-L660`](../../lib/phlimbo-ea/src/PhlimboV3.sol#L658)

**Description**: The normal `withdraw` path removes a staker from the `_stakers` EnumerableSet on
full exit (`if (remaining == 0) { _stakers.remove(user); }`, L658-660). `pauseWithdraw`
(L537-552) reduces `user.amount` to zero (L542) and refreshes reward debts but never calls
`_stakers.remove(msg.sender)`. A staker who fully exits via `pauseWithdraw` during a pause window
is left as a zero-value residual entry, breaking the implicit `membership ⟺ amount > 0` invariant.

**Impact**: Correctness-harmless (zombie entries are visited with `pending == 0`), but operationally
the `_stakers` set grows monotonically with such zero-value zombies. `batchClaim` must iterate to
`flushCursor == _stakers.length()`, so every zombie permanently inflates the owner's chunked-flush
gas cost. The cost is owner-borne and accumulation is slow — not cheaply attacker-driven, since each
zombie requires a prior `>= MINIMUM_STAKE` stake plus a pause window — but the growth is unbounded
over the contract's lifetime.

**Recommendation**: Mirror the `withdraw` full-exit logic in `pauseWithdraw`: when the post-withdraw
`user.amount == 0`, call `_stakers.remove(msg.sender)` so set membership tracks a live stake.

```solidity
user.amount -= amount;
totalStaked -= amount;
if (user.amount == 0) {
    _stakers.remove(msg.sender);
}
```

---

## QA Findings

### [Q-01] `withdrawAll` escape hatch omits a `promoToken` sweep <!-- id: pe7q1 -->

**Location**: [`MigratorV2V3.sol#L216`](../../lib/phlimbo-ea/src/MigratorV2V3.sol#L216) (`withdrawAll`); promo handling in `migrate` at [`L149`, `L182-L193`](../../lib/phlimbo-ea/src/MigratorV2V3.sol#L149)

**Description**: `migrate` reads `promoToken` from PhlimboV3 (L149) and forwards any promo rewards to
each migrated user (L182-193), so `promoToken` balances can transit through the migrator. The owner
`withdrawAll` escape hatch (L216-228) sweeps only `phUSD` (L221-222) and `rewardToken` (L224-225);
it does not sweep `promoToken`. Any promo-token balance stranded in the migrator at escape time is
not covered by the escape hatch.

**Impact**: No user-fund risk in the normal migration flow — this is a completeness gap in the
recovery path. Stranded promo tokens would require a separate, ad-hoc recovery mechanism.

**Recommendation**: Extend `withdrawAll` to also sweep `promoToken` when it is set, mirroring the
per-token handling already present in `migrate`:

```solidity
IERC20 promoToken = phlimboV3.promoToken();
if (address(promoToken) != address(0)) {
    uint256 promoBal = promoToken.balanceOf(address(this));
    if (promoBal > 0) {
        promoToken.safeTransfer(ownerAddr, promoBal);
    }
}
```

---

## Appendix: Automated SAST / Gas Report (4naly3er)

**4naly3er automated output unavailable — tool stalls in solc-js compilation and never emits a report body.**

4naly3er was run against the phlimbo-ea `src/` tree (commit `7045a96`) across four attempts.
The known foundry.toml remappings gap was addressed per the documented workaround: because
`4naly3er` resolves the submodule's root `remappings.txt` with paths relative to the analyzed
`src/` dir (not the repo root), a scratchpad staging dir was created with a `src` symlink to the
submodule source plus a `remappings.txt` rewritten to **absolute** paths for `@openzeppelin/`,
`forge-std/`, `@reflax-yield-vault/`, `@flax-token/`, and `lib/mutable/`. With that staging, import
resolution succeeded cleanly — **zero "import not found" errors** on stderr.

However, 4naly3er then hangs indefinitely inside the solc-js compilation step (bundled compiler,
no network dependency): every run enumerates the 12-file scope, pegs a core at ~100% CPU, and never
advances to emit the QA/gas findings section (output frozen at the scope listing) before hitting the
time budget. This matches the recurring 4naly3er reliability gap noted on prior runs in this repo
against these OZ-heavy contracts. The automated bot-report baseline is therefore **omitted** for run 07.

The manual Low/QA findings above are unaffected — they were sourced from the full Tier-1/2/3
pipeline, not from 4naly3er. If an automated baseline is required, retry with a native-`solc`
4naly3er build or a longer compile budget than this session allowed.
