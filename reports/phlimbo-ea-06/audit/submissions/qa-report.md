# QA Report — PhlimboV2 / MigratorV1V2

- **Project:** phlimbo-ea
- **Run:** phlimbo-ea-06
- **Commit:** `6cb0bc0c2c26982a09d9dba2a01a9819bf65190c`
- **Scope:** `src/PhlimboV2.sol`, `src/MigratorV1V2.sol`
- **Note on V1:** `src/Phlimbo.sol` (V1) is deprecated; all 25 V1 findings are `acknowledged` and out of scope for this bundle.

This report bundles the Low-severity and Centralization-risk findings for the V2 surface, plus two
QA items and one contract-level informational note. The three Mediums (V2-M-02, V2-M-03) and the
strict-`==` migrator DoS are tracked elsewhere; the faithfulness deviation (V2-F-01) is routed to the
spec-conformance report, not here. The automated 4naly3er QA/gas report is attached as Appendix A.

## Summary

| Severity | Count |
|----------|-------|
| Centralization Risk | 4 |
| Low Risk | 10 |
| Informational (contract-level) | 1 |
| QA | 2 |
| **Total** | **17** |

---

## Centralization Risks

### [C-01] emergencyTransfer drains funds without zeroing accounting; with setPauser(0) the auto-pause becomes a permanent lock <!-- id: pe6c1 -->

**Severity:** Centralization (footgun)

**Location:** [src/PhlimboV2.sol#L251](../../../../lib/phlimbo-ea/src/PhlimboV2.sol#L251) (`emergencyTransfer`), feeds from [src/PhlimboV2.sol#L224](../../../../lib/phlimbo-ea/src/PhlimboV2.sol#L224) (`setPauser`)

**Description:** `emergencyTransfer` sweeps the entire phUSD + rewardToken balance and then calls `_pause()`, but it never zeroes `userInfo`/`totalStaked`, so the stake accounting is left stale. Because `unpause()` requires `msg.sender == pauser` and `setPauser` has no zero-guard, a prior `setPauser(address(0))` makes the post-drain auto-pause irreversible: no account can ever unpause, and the `pauseWithdraw` escape hatch reverts because the balance is gone. The result is a permanently locked contract. This is a non-obvious owner footgun (the `setPauser(0)` "disable pausing" choice silently converts an emergency drain into an unrecoverable lock).

**Recommendation:** Add a zero-guard to `setPauser`, and have `emergencyTransfer` zero out stake accounting (or avoid auto-pausing into an unrecoverable state).

---

### [C-02] Uncapped desiredAPYBps converts directly into unbounded phUSD mint pressure <!-- id: pe6c2 -->

**Severity:** Centralization

**Location:** [src/PhlimboV2.sol#L172](../../../../lib/phlimbo-ea/src/PhlimboV2.sol#L172) (`setDesiredAPY`)

**Description:** `setDesiredAPY` places no magnitude cap on the `bps` value. The two-step commit/apply gate only introduces a time delay; it imposes no upper bound on the resulting APY, which flows directly into `_updatePhUSDEmissionRate` and therefore into unbounded phUSD mint pressure. A delay-only gate does not constrain how large the eventual emission becomes.

**Recommendation:** Add a hard upper bound (e.g. `MAX_APY_BPS`) on `desiredAPYBps` in addition to the existing two-step delay.

---

### [C-03] setDepletionDuration has no minimum-duration floor and no two-step gate; one-tx flash distribution of rewardBalance <!-- id: pe6c3 -->

**Severity:** Centralization

**Location:** [src/PhlimboV2.sol#L196](../../../../lib/phlimbo-ea/src/PhlimboV2.sol#L196) (`setDepletionDuration`)

**Description:** `setDepletionDuration` accepts any value with no minimum floor and no two-step gate. Setting `_duration` to `1` makes `rewardPerSecond` enormous, so the next `_updatePool` distributes the entire `rewardBalance` (capped at `rewardBalance`, L457) to whoever happens to be staked at that instant — a single-transaction flash distribution that bypasses the intended streaming schedule.

**Recommendation:** Enforce a minimum-duration floor and apply the same two-step gate used for APY changes.

---

### [C-04] Residual migrator custody: migrator role is not auto-revoked post-migration and can route any user's principal + rewards to itself <!-- id: pe6c4 -->

**Severity:** Centralization (footgun)

**Location:** [src/PhlimboV2.sol#L232](../../../../lib/phlimbo-ea/src/PhlimboV2.sol#L232) (`setMigrator`), [src/PhlimboV2.sol#L363](../../../../lib/phlimbo-ea/src/PhlimboV2.sol#L363) (`withdraw`) / [src/PhlimboV2.sol#L407](../../../../lib/phlimbo-ea/src/PhlimboV2.sol#L407) (`claim`)

**Description:** The migrator role is not automatically revoked once migration completes. While set, the migrator can call `withdraw`/`claim` on behalf of any user, and the tokens are routed to `msg.sender` (the migrator), not the user (L373/L392/L424). This is faithful to story-020 ("tokens land in the caller"), but it leaves standing authority over every user position with whatever address holds the role — a non-obvious footgun if the role is ever assigned to an EOA. **Actionable now:** since migration is complete, call `PhlimboV2.setMigrator(address(0))` to revoke the retired migrator's standing authority.

**Recommendation:** Call `setMigrator(address(0))` after migration completes; never assign the migrator role to an EOA — it must always be the migrator contract.

---

## Low Risk Findings

### [L-01] pauseWithdraw stale-debt underflow brick <!-- id: pe6l1 -->

**Severity:** Low

**Location:** [src/PhlimboV2.sol#L280](../../../../lib/phlimbo-ea/src/PhlimboV2.sol#L280) (`pauseWithdraw` / `_claimRewards`)

**Description:** A `pauseWithdraw` leaves the caller with stale reward debt; a subsequent normal claim/withdraw path then underflows and reverts, bricking those paths for that user. The condition is self-inflicted (`pauseWithdraw` is `msg.sender`-only) and the principal remains recoverable via a re-pause + `pauseWithdraw`, so only the rewards and normal entry paths get stuck. The severity-auditor confirmed Low here; the code-scanner's initial High was overstated because the impact is self-inflicted and the principal is recoverable.

**Recommendation:** Reset the user's `rewardDebt` consistently inside `pauseWithdraw` so the normal claim/withdraw paths do not underflow afterward.

---

### [L-02] pendingPhUSD / pendingStable view-helpers underflow after pauseWithdraw <!-- id: pe6l2 -->

**Severity:** Low

**Location:** [src/PhlimboV2.sol#L526](../../../../lib/phlimbo-ea/src/PhlimboV2.sol#L526) (`pendingPhUSD`) / [src/PhlimboV2.sol#L542](../../../../lib/phlimbo-ea/src/PhlimboV2.sol#L542) (`pendingStable`)

**Description:** For a user left with stale reward debt after `pauseWithdraw`, the `pendingPhUSD()` and `pendingStable()` view helpers compute a subtraction that underflows and reverts. Integrations and front-ends that call these views for the affected user will see reverts rather than a value. This is the read-side manifestation of the same stale-debt condition as L-01.

**Recommendation:** Guard the subtraction (saturate to zero) in both view helpers so they return `0` instead of reverting for stale-debt users.

---

### [L-03] pauseWithdraw bypasses the MINIMUM_STAKE dust rule <!-- id: pe6l3 -->

**Severity:** Low

**Location:** [src/PhlimboV2.sol#L280](../../../../lib/phlimbo-ea/src/PhlimboV2.sol#L280) (`pauseWithdraw`)

**Description:** The normal `withdraw` path enforces a `MINIMUM_STAKE` dust rule (a remaining balance below the minimum forces a full exit), but `pauseWithdraw` contains no such handler. A user can therefore leave a sub-minimum residual position via `pauseWithdraw`, weakening the invariant that no position sits below `MINIMUM_STAKE` and contributing to dusted-`totalStaked` regimes where emission math can floor (see L-08).

**Recommendation:** Apply the same `MINIMUM_STAKE` dust-forces-full-exit handler in `pauseWithdraw` that `withdraw` uses.

---

### [L-04] setPauser emits no event and has no zero-guard <!-- id: pe6l4 -->

**Severity:** Low

**Location:** [src/PhlimboV2.sol#L224](../../../../lib/phlimbo-ea/src/PhlimboV2.sol#L224) (`setPauser`)

**Description:** `setPauser` changes a security-critical role without emitting an event, making off-chain monitoring of pauser rotation impossible, and it accepts `address(0)` without a guard. The missing zero-guard directly feeds the C-01 permanent-lock footgun.

**Recommendation:** Emit a `PauserUpdated(oldPauser, newPauser)` event and reject `address(0)`.

---

### [L-05] setDesiredAPY commit branch does not clear pendingAPYBps / pendingAPYBlockNumber <!-- id: pe6l5 -->

**Severity:** Low

**Location:** [src/PhlimboV2.sol#L182](../../../../lib/phlimbo-ea/src/PhlimboV2.sol#L182) (`setDesiredAPY`)

**Description:** When the two-step `setDesiredAPY` commit is applied, the function does not clear the `pendingAPYBps` / `pendingAPYBlockNumber` staging fields. The stale pending values linger after a successful commit, which can mislead off-chain readers and confuse the gate's state on a subsequent change.

**Recommendation:** Zero out `pendingAPYBps` and `pendingAPYBlockNumber` once the committed APY is applied.

---

### [L-06] Stable per-share rounding strands rewardBalance <!-- id: pe6l6 -->

**Severity:** Low

**Location:** [src/PhlimboV2.sol#L459](../../../../lib/phlimbo-ea/src/PhlimboV2.sol#L459) (`_updatePool`)

**Description:** In `_updatePool`, `rewardBalance` is debited in full while `accStablePerShare` is incremented by a floored per-share quotient. The floored remainder is never credited to any share, so a small amount of stable reward is permanently stranded on each update; frequent small updates amplify the cumulative strand. No over-distribution occurs (proved), but value is left uncreditable.

**Recommendation:** Carry the floored remainder forward (e.g. only debit `rewardBalance` by the amount actually distributed per share) so the strand is not lost.

---

### [L-07] phUSD is both the stake token and the minted reward -> compounding spiral <!-- id: pe6l7 -->

**Severity:** Low

**Location:** [src/PhlimboV2.sol#L486](../../../../lib/phlimbo-ea/src/PhlimboV2.sol#L486) (`_claimRewards`)

**Description:** phUSD serves simultaneously as the staked principal token and as a minted reward. Claimed phUSD rewards can be re-staked, which increases the staked base that future emissions are computed against, producing a tokenomic compounding spiral. Under a non-zero-APY configuration this amplifies mint pressure beyond the naive APY expectation.

**Recommendation:** Account for the self-referential token in emission sizing, or document and cap the compounding behavior so the realized emission stays bounded.

---

### [L-08] _updatePhUSDEmissionRate truncates phUSDPerSecond to zero at low stake x APY <!-- id: pe6l8 -->

**Severity:** Low

**Location:** [src/PhlimboV2.sol#L512](../../../../lib/phlimbo-ea/src/PhlimboV2.sol#L512) (`_updatePhUSDEmissionRate`)

**Description:** At low `totalStaked` combined with a low APY, the integer division in `_updatePhUSDEmissionRate` floors `phUSDPerSecond` to `0`, so the phUSD reward stream silently stops accruing even though a non-zero APY is configured. Stakers in this regime receive no phUSD emissions until stake or APY rises past the truncation threshold.

**Recommendation:** Use higher-precision intermediate scaling (or a minimum-rate floor) so small but non-zero rates are not truncated to zero.

---

### [L-09] Reverting / gas-heavy IPhlimboHook bricks stake/withdraw/claim (no try/catch) <!-- id: pe6l9 -->

**Severity:** Low (footgun)

**Location:** [src/PhlimboV2.sol#L353](../../../../lib/phlimbo-ea/src/PhlimboV2.sol#L353) (`stake`) / [src/PhlimboV2.sol#L398](../../../../lib/phlimbo-ea/src/PhlimboV2.sol#L398) (`withdraw`) / [src/PhlimboV2.sol#L429](../../../../lib/phlimbo-ea/src/PhlimboV2.sol#L429) (`claim`)

**Description:** `stake`, `withdraw`, and `claim` invoke the external `IPhlimboHook` without a `try/catch`, so a hook that reverts or consumes excessive gas unwinds the entire outer call and bricks those paths pool-wide. This is a non-obvious owner footgun if a misbehaving hook is ever wired in. `pauseWithdraw` is hook-exempt, so a principal exit still survives even when the hook is broken.

**Recommendation:** Wrap the hook call in `try/catch` (bounding gas) so a faulty hook degrades gracefully rather than bricking core flows; at minimum, monitor the configured hook.

---

### [L-10] Migrator auto-claims a pre-existing V2 staker's rewards to itself during migrateDeposits <!-- id: pe6l10 -->

**Severity:** Low

**Location:** [src/PhlimboV2.sol#L336](../../../../lib/phlimbo-ea/src/PhlimboV2.sol#L336) (`stake`)

**Description:** If a user self-staked into V2 before the migrator acted, `migrateDeposits -> stake` triggers an auto-claim of that user's pending rewards, and those rewards are routed to `msg.sender` (the migrator) rather than to the user. This is a migration-window finding: the window is now CLOSED per owner confirmation (migration complete), so it is historical, not future. If desired, verify on-chain that no pre-migration self-stake had rewards diverted to the migrator.

**Recommendation:** Complete migration before users can self-stake (already done for this deployment); for any reuse, settle existing rewards to the user before the migrator stakes on their behalf.

---

## Informational / contract-level

### [I-01] MigratorV1V2 strict-`==` balance precondition DoS (1 wei bricks chunkable migration) <!-- id: pe6m1 -->

**Severity:** Informational for THIS deployment; remains a contract-level **Medium** for any redeployment/reuse.

**Location:** [src/MigratorV1V2.sol#L155](../../../../lib/phlimbo-ea/src/MigratorV1V2.sol#L155) (`settleDebt`, balance checks L159-163) / [src/MigratorV1V2.sol#L203](../../../../lib/phlimbo-ea/src/MigratorV1V2.sol#L203) (`migrateDeposits`, balance check L207-210)

**Description:** Both `settleDebt` and `migrateDeposits` gate on strict `==` balance preconditions (`usdc.balanceOf(this) == totalUSDC`, `phUSD.balanceOf(this) == totalPHUSD_deposited`). Any third party can transfer 1 wei of USDC/phUSD to the migrator to break the equality and permanently brick the chunkable migration; `withdrawAll` does not reset totals/iterators, so the contract is re-griefable. This is an availability DoS, not theft. For THIS deployment the surface is CLOSED — the owner confirmed the V1->V2 migration is complete (both iterators at `-1`), so `settleDebt`/`migrateDeposits` revert on the `iterator >= 0` guard before the balance check is ever reached. It is downgraded to informational here, but it is flagged so it is not lost: it is a genuine contract-level Medium for any future redeployment or reuse of MigratorV1V2.

**Recommendation:** For any redeployment/reuse, replace the strict `==` balance checks with a `>=` lower bound (donated surplus does not break the precondition).

---

## QA

### [Q-01] pauseWithdraw silent reward forfeiture + orphan residue (blessed by KI-4) <!-- id: pe6q1 -->

**Severity:** QA / Low (by design)

**Location:** [src/PhlimboV2.sol#L280](../../../../lib/phlimbo-ea/src/PhlimboV2.sol#L280) (`pauseWithdraw`)

**Description:** `pauseWithdraw` silently forfeits the caller's accrued rewards (no event) and orphans the per-share-accumulator residue. This forfeiture-by-design is explicitly blessed by the project's KI-4 known issue, so it is reported as QA-only rather than a defect. (The non-obvious escalations of the same mechanism — the stale-debt brick and the over-mint — are tracked separately as L-01 and the V2-M-03 Medium.)

**Recommendation:** Emit an event documenting the forfeited amount on `pauseWithdraw` so the intentional loss is observable off-chain.

---

### [Q-02] Declared event RateUpdated is never emitted <!-- id: pe6q2 -->

**Severity:** QA / Low

**Location:** [src/PhlimboV2.sol#L126](../../../../lib/phlimbo-ea/src/PhlimboV2.sol#L126) (event declaration)

**Description:** The contract declares `event RateUpdated(uint256 newRate, uint256 newBalance)` but never emits it anywhere, so the intended rate-change signal is unavailable to off-chain consumers and the declaration is dead code.

**Recommendation:** Emit `RateUpdated` at the points where the rate/balance actually changes, or remove the declaration if it is obsolete.

---

## Appendix A — Automated QA / Gas Report (4naly3er)

The canonical C4-style automated QA/gas report was generated with **4naly3er** over `lib/phlimbo-ea/src`
(which includes `PhlimboV2.sol` and `MigratorV1V2.sol` alongside the deprecated V1 and the interfaces;
4naly3er scans by directory). The full markdown output is attached alongside this report at:

`reports/phlimbo-ea-06/audit/submissions/4naly3er-report.md`

It contains the standard Gas Optimizations (GAS-1..GAS-16), Low Issues, and Non-Critical Issues
(NC-1..NC-22) tables. Notable bot findings that corroborate the manual items above: NC-1 (missing
`address(0)` checks — overlaps L-04 / C-01), NC-6 (event never emitted — overlaps Q-02), and NC-8 /
NC-12 (critical-parameter changes missing events / old+new values — overlaps L-04 / L-05). The bot
output is provided as a baseline; the manual findings above are the prioritized, deduplicated set.
