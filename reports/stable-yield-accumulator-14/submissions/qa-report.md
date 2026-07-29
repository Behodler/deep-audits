# QA Report — stable-yield-accumulator (run-14)

**Commit audited**: `f7041304e4a71cc2325cf406974f5cc16a5b5322`
**Scope**: `src/StableYieldAccumulator.sol`, `src/interfaces/IStableYieldAccumulator.sol`
**Run**: `reports/stable-yield-accumulator-14`

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 5 |
| QA / Hardening | 1 |
| Centralization | 0 |
| **Total** | **6** |

**Not in this bundle** (filed separately, do not read this report as the full run output):

- The run's Medium — `setRewardToken` silently re-keys the nudge stream — is submitted individually as `submissions/M-01.md`.
- Two faithfulness findings (F-01, F-02) are in `submissions/spec-conformance.md` per Law 2. They are story/spec deviations, not QA items, and are deliberately not absorbed here.
- Nine pre-existing open ledger entries carry over from earlier runs and are **not** restated here as new. Two of them are cross-referenced below where the relationship is load-bearing (ledger `L-02` at L-04; phoenix-nft-staking `858e9e80` at L-05).

**Provenance note (honesty)**: every PoC and test file referenced below lives under `workspace/stable-yield-accumulator/` and is **audit-authored and untracked upstream**. The only test file tracked at `f704130` is `test/StableYieldAccumulator.t.sol`. Nothing below should be read as a result produced by the project's own test suite.

---

## Low Risk Findings

### [L-01] Sink-retirement gate is structurally blind to the NudgeStreamer buffer and returns a false all-clear <!-- id: sya14l1 -->

**Location**:
- Gate: `lib/phoenix-phase-2-staging/script/ReplaceBatchNFTMinter.s.sol:486`, `lib/phoenix-phase-2-staging/script/MigrateBatchNFTMinter.s.sol:500`
- SYA leg: `src/StableYieldAccumulator.sol:442-446` (`setNudgeAddress`), ops-ordering NatSpec `:82-90`

**Description**: The documented batch-minter retirement procedure asserts that the outgoing sink is drained with:

```solidity
require(IERC20(USDC).balanceOf(OLD_BATCH_MINTER) == 0, "old contract still holds USDC");
```

Post-story-026 this check no longer describes where the value is. Nudge donations are held in `NudgeStreamer`, keyed on the pair `(nudge, rewardToken)`, and are not part of `balanceOf(OLD_BATCH_MINTER)`. An operator following the documented flow — `registerStream(B_new, USDC, d)` then `setNudgeAddress(B_new)` — leaves the `(B_old, USDC)` buffer orphaned, while the script's own safety assertion reports clean. The SYA ops NatSpec at `:82-90` prescribes registering the new pair and says nothing about draining the old one.

The outstanding amount converges to `donationRate × duration`, i.e. roughly 30 days of donations at the documented parameters. A PoC run showed the gate passing with 4,108 USDC still in the streamer, and the converged float measured at 14,982,961,180 against a predicted 15,000,000,000.

**The value is not lost, and this finding must not be read as a loss.** `NudgeStreamer._settle` **pushes** (`safeTransfer(recipient, settled)`, `NudgeStreamer.sol:186`). An owner `registerStream`, or a 1-wei `collectNudge` by *any* address, shoves the entire buffer into the retired sink, where `rescueERC20` recovers it in full — callable even while paused. The defect is **false assurance**: the gate certifies clean while the value is outstanding and while every *automatic* delivery route to it is dead (pause, de-whitelist, and zero-streamer each independently sever the designed `batchMint` step-3.5 flush). The operator has a working manual remedy but no reason to know they need it.

Two rationales considered earlier in this audit were tested and refuted, and are recorded here so they are not re-derived: "`batchMint` is permissionless so anyone drains the orphan indefinitely" is false at retirement, which is exactly when it matters; and "the buffer is permanently unrecoverable" is false because `_settle` pushes.

**Recommendation**:

1. **Primary** — extend the gate to also assert the streamer side is empty:

```solidity
require(IERC20(USDC).balanceOf(OLD_BATCH_MINTER) == 0, "old contract still holds USDC");
require(INudgeStreamer(streamer).pendingStream(OLD_BATCH_MINTER, USDC) == 0, "streamed nudge outstanding");
// and assert the (OLD_BATCH_MINTER, USDC) buffer itself is zero
```

2. **Secondary** — document the manual recovery route in the ops runbook: a 1-wei `collectNudge`, or an owner `registerStream`, pushes the buffer to the retired sink; `rescueERC20` then recovers it.
3. **Ordering (important)** — **drain before de-whitelisting.** `registerStream` re-checks `isNudgeToken` (`NudgeStreamer.sol:112-114`), so de-whitelisting first removes the owner's own `registerStream` lever and leaves only the outsider 1-wei route.
4. Add a "step 0 — drain the old `(sink, token)` stream" to the SYA ops-ordering NatSpec at `:82-90`.

**Escalation triggers**: reopen at Medium if the retired sink can ever reach a state where `rescueERC20` is unavailable (ownership renounced, contract upgraded/destructed away), or if a decommissioning procedure is adopted that revokes owner control of the retired sink. Neither is evidenced at `f704130`.

---

### [L-02] Standing undelivered nudge float converges to `donationRate × duration` <!-- id: sya14l2 -->

**Location**: `src/StableYieldAccumulator.sol:595-600` (`claim`, nudge leg)

**Description**: `NudgeStreamer.collectNudge` recomputes `rewardPerSecond` over the **full** `duration` on every deposit, and SYA's `claim()` *is* the deposit. Under any claim cadence `T < D` the stream never depletes:

```
B_{n+1} = B_n·(1 − T/D) + d   ⇒   B* = d·D/T = donationRate × duration
```

The fixed point is independent of claim cadence, verified this run: 14,982,961,180 observed against 15,000,000,000 predicted, holding at both 1-day and 6-hour cadences and fuzz-confirmed within 1% for `T ∈ [D/100, D/4]`. Notably the float *grows* with claim throughput — it is largest exactly when the protocol is working best. At illustrative parameters (nudgeSplit 20%, $10k/day throughput, `D` = 30 days) it is on the order of $60k, which is not dust.

**This is work-in-progress float in permanent transit to its intended recipient, not a loss.** Shrinking `duration` accelerates delivery to the sink and drains the streamer to zero; re-registering re-spreads the same buffer with the owner's balance unchanged. It is, however, un-redirectable and sits in a contract with no rescue function of its own. Realised loss requires an exceptional trigger — the streamer address being blacklisted by a USDC-shaped issuer, the sink being retired without a flush (L-01), or claims/`nudgeSplit` going to zero so the tail never settles.

**Recommendation**: size `duration` against the *expected claim cadence* rather than intuition, and treat `r × D` as an accepted uninsured in-transit float. The upstream cure — recompute the rate over the *remaining* window rather than the full duration, and add an owner rescue — belongs to `phoenix-nft-staking` and is routed there as PARK-001, not filed against SYA.

**Escalation triggers**: reopen at Medium if `rewardToken` is a blacklist-capable asset and the deployed streamer address is judged to carry realistic blacklist exposure; or if `duration` is configured long enough relative to claim cadence that `r × D` exceeds what the protocol will leave uninsured.

---

### [L-03] Nudge-token whitelist is checked only at registration; `collectNudge` never re-checks <!-- id: sya14l3 -->

**Location**: `src/StableYieldAccumulator.sol:595-600` (`claim`, donor leg); upstream `NudgeStreamer.sol:112-114` vs `:137-156`

**Description**: `NudgeStreamer.registerStream` enforces `isNudgeToken(token)` on the batch minter — the structural "this sink can actually distribute this token" guard. `collectNudge` does not re-assert it, and neither does SYA. If the `BatchNFTMinterMultiToken` owner later calls `setNudgeTokenWhitelist(USDC, false)` (for instance to rotate the reward pot), the token leaves `_nudgeTokens` via swap-and-pop, but SYA's claims keep succeeding and keep pushing USDC into the streamer and, via `_settle`, into the sink's balance. `batchMint`'s step-3.5 flush loop iterates `_nudgeTokens`, which no longer contains USDC — so the streamer buffer loses its flusher and the already-settled balance sits undistributed.

Value is **paused, not leaked**: re-whitelisting the token recovers both pools in full. The weak link is **detection**, not recovery — SYA emits nothing and reverts nothing, so the condition surfaces only when someone notices `batchMint` has stopped paying that token out.

This is filed on the **donor leg**: SYA is the contract that keeps donating into a sink that can no longer distribute. It is in scope under Law 3 as a non-obvious footgun — an owner de-whitelisting a token would not expect it to silently strand an active donor's ongoing flow.

**Recommendation**: have `NudgeStreamer.collectNudge` re-assert `isNudgeToken` so the value path fails loud, or expose an owner-callable flush on `NudgeStreamer` keyed by `(batchMinter, token)`. The missing re-check is upstream (`phoenix-nft-staking`) and is routed as the recommended cure, not filed as an SYA defect. SYA-side interim: probe the sink's whitelist pre-claim and emit (or revert) when it fails.

---

### [L-04] Standing phlimbo allowance is never revoked on `setPhlimbo` or `setRewardToken` repoint <!-- id: sya14l4 -->

**Location**: `src/StableYieldAccumulator.sol:405-411` (`setPhlimbo`), `:417-420` (`setRewardToken`)

**Description**: `approvePhlimbo(largeAmount)` grants a standing `rewardToken` allowance to phlimbo. Neither `setPhlimbo(newPhlimbo)` nor `setRewardToken(newToken)` touches that allowance — verified first-hand at `f704130`. A repointed-away phlimbo therefore retains spending rights over SYA's `rewardToken` balance indefinitely, and after `setRewardToken` the surviving allowance is denominated in the *old* token, so the phlimbo leg breaks independently of the streamer leg.

Practical exposure is limited: SYA holds approximately zero `rewardToken` between claims, so a stale grantee could only skim mid-claim balances, and `claim` is `nonReentrant`. This is state hygiene, not an attack path — there is no malicious-owner assumption in play.

The C4 "approve race condition / `safeApprove` front-running" exclusion was considered and **rejected**: this is an allowance that *outlives its grantee across a repoint*, not the ERC-20 approve race. Separately, the story-026 inline `forceApprove` at `:598` is exact-amount and fully consumed in-transaction with no external call between grant and consumption (Tier-3 `test_P3_C` confirms allowance `== 0` after a claim), so no interception window exists there.

**Cross-reference — ledger `L-02` (`8c48864824…`, open) is the opposite failure of the same variable and must not be read as the same issue.** Ledger `L-02` is allowance **under-supply**: the allowance depletes and bricks `claim`; the function is `approvePhlimbo`; the fix is re-approval / auto-top-up. This finding is allowance **over-persistence**: the allowance survives its grantee; the functions are `setPhlimbo`/`setRewardToken`; the fix is zeroing it on repoint. Opposite direction, opposite fix, different setter.

This must also not be collapsed into run-14 `M-01` (`setRewardToken`, submitted separately). Both are consequences of `setRewardToken`, but `M-01` concerns **availability** of `claim()`; this is residual **allowance hygiene**.

**Recommendation**:

```solidity
function setPhlimbo(address newPhlimbo) external onlyOwner {
    if (newPhlimbo == address(0)) revert ZeroAddress();
    IERC20(rewardToken).forceApprove(phlimbo, 0);   // revoke the outgoing grantee
    phlimbo = newPhlimbo;
    emit PhlimboUpdated(phlimbo, newPhlimbo);
}

function setRewardToken(address newToken) external onlyOwner {
    IERC20(rewardToken).forceApprove(phlimbo, 0);   // zero the OLD token's allowance
    rewardToken = newToken;
}
```

This is pre-existing behaviour, not introduced by story-026; age is not a suppression ground.

---

### [L-05] NatSpec `:62` restates the streamer as a capture cap; it is a timing throttle <!-- id: sya14l5 -->

**Location**: `src/StableYieldAccumulator.sol:60-64` (contract NatSpec, claim at `:62`)

**Description**: SYA's contract NatSpec restates the upstream claim that the batch-minter "receives a smooth linear stream instead of a lumpy push", framed such that batchers "can no longer capture a disproportionate share of the reward pot". To an integrator reading SYA, that reads as a **structural** guarantee against burst capture. It is not one.

The streamer caps the **rate at which value arrives** at the sink; it never caps the **size any single `batchMint` caller sweeps** from it. Streaming converts an instantaneous winner-take-all capture into a *delayed* winner-take-all capture of the same total — it does not divide the pot. Capture becomes profitable at cadence `t* = n·p/r`, which is parameter-independent.

There is no impact on SYA assets or availability. The loss is to the documented *intent* (proportionate distribution), and the affected parties are honest or small batchers crowded out of the race.

**Counterweight, stated deliberately**: story-026's narrow, literal goal — killing the same-block claimer self-rebate — **is** achieved, and that is a genuine and material improvement. This finding is about the NatSpec over-claiming beyond that goal, not about story-026 achieving nothing.

**Recommendation**: soften `:62` to state that the streamer is a **timing throttle with no value cap**, and cross-reference the upstream entries so an SYA reader is not left believing burst capture is structurally prevented.

**Scope note**: filed strictly on the SYA NatSpec leg. The mechanism leg (`batchMint` sweeping the sink's whole balance) is out of scope here and is routed to `phoenix-nft-staking`, where it bears on ledger entry `858e9e80` (wont-fix) as evidence on that entry's residual and on `6f46ec80` (Low, open). **`858e9e80` is not relitigated or reopened from here.** It is also distinct from `phoenix-nft-staking` run-22 `M-01` (aggregate-nudge over-funding, Σ pots > cost) — that is aggregate over-funding, this is single-pot capture concentration.

---

## QA / Hardening

### [QA-01] Interface and dead-code hygiene <!-- id: sya14q1 -->

**Location**: `src/interfaces/IStableYieldAccumulator.sol:119`, `:156`; `src/StableYieldAccumulator.sol:682`

**Description**: Four instances, none with impact on assets or availability:

1. `error NotImplemented()` — declared, never thrown; a self-described red-phase TDD stub left in a **shipped** interface (`IStableYieldAccumulator.sol:119`).
2. `error InsufficientPending()` — declared, never thrown (`:156`). Its presence implies a pending-rewards check that was specced but never wired, which is misleading to a reader trying to infer intended behaviour from the interface.
3. The interface omits public implementation members: `setRewardToken`, `approvePhlimbo`, `setPauser`, `pauser()`, `discountRate()`, `isRegisteredStrategy()`, `yieldStrategies(uint256)`. An integrator typed through this interface cannot perform reward-token or allowance operations. No live integration is broken — the members `ClaimArbitrage` actually depends on are all present.
4. The `decimals > 18` branches in `_normalizeAmount`/`_denormalizeAmount` are **unreachable**: `setTokenConfig:339` reverts `InvalidDecimals()` first (`StableYieldAccumulator.sol:682`). This instance is retained deliberately — it is the evidence behind dropping SLITHER-001 as a false positive, and it is the decimal-handling surface adjacent to the ledger's acknowledged decimal fail-open (`ecc2d126dd`).

**Recommendation**: delete the two unused errors or wire them; add the missing public members to the interface; delete the unreachable `decimals > 18` branches or replace them with an explicit `assert`.

**Mitigating**: story-026 correctly added `setNudgeStreamer()`, `nudgeStreamer()`, `NudgeStreamerUpdated` and `NudgeStreamerNotConfigured` to the interface — the interface is faithful to this run's delta. The items above are pre-existing drift.

---

## Parked Items (visible channel, not dropped)

Five items were parked for human adjudication at `/ledger` triage rather than filed as findings. They are recorded in full in `reports/stable-yield-accumulator-14/manual-review.json` and are listed here so none of them is invisible.

| ID | Estimate | Subject | Disposition |
|----|----------|---------|-------------|
| **PARK-001** | potential-low | `NudgeStreamer.collectNudge` is permissionless and recomputes `rewardPerSecond` over the **full** duration on every deposit — a 1-wei donor can reset the streaming window at will (Linear-Depletion / rate-drift class). Root cause `NudgeStreamer.sol:137-156`, recompute at `:150-153`. | **Routed to `phoenix-nft-staking`.** Reconcile **into** ledger entry `aaebb4b9` (Low, open) — do not mint a new entry. Re-weigh against run-24's "port faithful, no rate-drift" conclusion, which was reached where the depositor is privileged; in the SYA integration the depositor is permissionless and high-frequency, so rate-drift is present in practice. Do not silently override run-24. Econ ruling: pure griefing, strictly negative-EV — the griefer's own `batchMint` take shrinks by exactly what they delay. The in-scope consequence is filed above as L-02. |
| **PARK-003** | potential-low | `nudgeSplit` is silently unhonored below the rounding threshold: `nudgeAmount = (actualPayment * nudgeSplit) / 100` floors to 0, the `> 0` guard skips the streamer branch, and phlimbo takes 100%. | Byte-for-byte identical to pre-story-026 behaviour; dust magnitude; not attacker-repeatable for profit. Distinct from ledger `L-01` (`actualPayment` itself flooring) and from `ecc2d126dd`. |
| **PARK-004** | potential-low / qa | `claim` (`:538`) and `calculateClaimAmount` (`:742`) loop over the caller-supplied `exemptStrategies` array — `O(n·m)` with `m` caller-controlled and duplicates not rejected. | Collapse into ledger `L-05` **declined**: folding it in would overwrite that entry's central scoping qualifier with a contradicting fact. |
| **PARK-005a** | potential-low | `canClaim` loops `i = 1..nextIndex()-1`, issuing one external `balanceOf` staticcall per dispatcher index. | Victim is a downstream on-chain integrator; not covered by any existing ledger entry. |
| **PARK-005b** | potential-low | Value-reporting views are readable mid-claim while the strategy set is transiently half-skimmed. | Cannot be closed on the merits at this tier — the victim (`ClaimArbitrage`) is outside this run's scope. |

---

## Audit-Tooling Note (PROC-001) — not a contract defect

**This is a defect in the audit harness, not in `stable-yield-accumulator`.** It is recorded here for process traceability only and should not be triaged as a project issue.

The pre-existing Tier-3 invariant harness `test/Invariant_SYA.t.sol` had gone **vacuous** under story-026: only 1 of 60 claim attempts was succeeding, the nudge leg was never exercised at all, and the invariants were consequently passing against near-empty state. A green run from that harness carried no information.

Fixed during this run by adding tripwires — a minimum-successful-claim floor and an abort-on-unexercised-leg assertion — so the harness fails loudly rather than passing vacuously. All Tier-3 results cited in L-02 and L-04 above were produced *after* that repair.

The repaired harness lives in the writable `workspace/` clone and is audit-authored; it is not part of the project's tracked test suite.

---

## Appendix A — Automated Report (4naly3er)

Generated with 4naly3er against `lib/stable-yield-accumulator` at `f704130`, scope `src/StableYieldAccumulator.sol` + `src/interfaces/IStableYieldAccumulator.sol`:

```bash
cd tools/4naly3er && yarn analyze ../../lib/stable-yield-accumulator <scope-file>
```

The full tool output is attached as a companion file: **`reports/stable-yield-accumulator-14/submissions/4naly3er-report.md`** (1,508 lines).

This appendix is **automated output, separate from the reasoned findings above**. It has not been triaged, deduplicated against the ledger, or severity-checked; C4 treats bot output as a baseline, not as findings. Where a bot item overlaps a reasoned finding above, the reasoned finding governs. Nothing in this appendix was used as evidence for any L-XX or QA-XX item.

### Low Risk (automated)

| ID | Issue | Instances |
|----|-------|:---------:|
| L-1 | Use a 2-step ownership transfer pattern | 1 |
| L-2 | Some tokens may revert when zero value transfers are made | 1 |
| L-3 | Missing checks for `address(0)` when assigning values to address state variables | 3 |
| L-4 | Division by zero not prevented | 3 |
| L-5 | Owner can renounce while system is paused | 3 |
| L-6 | Solidity version 0.8.20+ may not work on other chains due to `PUSH0` | 1 |
| L-7 | Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership` | 1 |

### Non-Critical (automated)

| ID | Issue | Instances |
|----|-------|:---------:|
| NC-1 | Missing checks for `address(0)` when assigning values to address state variables | 3 |
| NC-2 | `constant`s should be defined rather than using magic numbers | 12 |
| NC-3 | Control structures do not follow the Solidity Style Guide | 32 |
| NC-4 | Consider disabling `renounceOwnership()` | 1 |
| NC-5 | Event missing indexed field | 2 |
| NC-6 | Events that mark critical parameter changes should contain both the old and the new value | 8 |
| NC-7 | Function ordering does not follow the Solidity style guide | 1 |
| NC-8 | Functions should not be longer than 50 lines | 47 |
| NC-9 | Lack of checks in setters | 3 |
| NC-10 | Missing Event for critical parameters change | 1 |
| NC-11 | Use a `modifier` instead of a `require`/`if` statement for a special `msg.sender` actor | 2 |
| NC-12 | Consider using named mappings | 3 |
| NC-13 | Owner can renounce while system is paused | 3 |
| NC-14 | Take advantage of Custom Error's return value property | 23 |
| NC-15 | Contract does not follow the Solidity style guide's suggested layout ordering | 2 |
| NC-16 | Use underscores for number literals | 3 |
| NC-17 | Event is missing `indexed` fields | 5 |
| NC-18 | Constants should be defined rather than using magic numbers | 2 |
| NC-19 | Variables need not be initialized to zero | 14 |

### Gas Optimizations (automated)

| ID | Issue | Instances |
|----|-------|:---------:|
| GAS-1 | `a = a + b` is more gas effective than `a += b` for state variables | 4 |
| GAS-2 | Use assembly to check for `address(0)` | 18 |
| GAS-3 | Using bools for storage incurs overhead | 1 |
| GAS-4 | Cache array length outside of loop | 9 |
| GAS-5 | State variables should be cached in stack variables rather than re-read from storage | 5 |
| GAS-6 | For operations that will not overflow, `unchecked` could be used | 39 |
| GAS-7 | Use custom errors instead of revert strings | 4 |
| GAS-8 | Avoid contract existence checks by using low level calls | 2 |
| GAS-9 | Stack variable used as a cheaper cache for a state variable is only used once | 7 |
| GAS-10 | Functions guaranteed to revert for normal users can be marked `payable` | 15 |
| GAS-11 | `++i` costs less gas than `i++` | 11 |
| GAS-12 | Increments/decrements can be unchecked in for-loops | 10 |
| GAS-13 | Use `!= 0` instead of `> 0` for unsigned integer comparison | 11 |

Per-instance line references for every item above are in the companion file.
