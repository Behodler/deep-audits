# Tier-3 invariant verification — stable-yield-accumulator @ f704130

Story-026: the nudge share of every `claim()` is routed through `NudgeStreamer` instead of a
direct `safeTransfer`.

- Workspace: `/home/justin/code/audits/workspace/stable-yield-accumulator`
- New harness: `test/NudgeStreamerLiveness_SYA.t.sol`
- Extended harness: `test/Invariant_SYA.t.sol`, `test/mocks/SYAMocks.sol`
- Fuzzer config: `medusa-tier3.json`
- Streamer under test: the **real** `lib/phoenix-nft-staking/src/NudgeStreamer.sol` @ `5015f1b`

| Property | Result |
|---|---|
| 1. CLAIM-LIVENESS (CODE-001 / F-01 / F-02) | **VERIFIED (finding confirmed)** |
| 2. STREAM-FLOAT-CONVERGENCE (ECON-002 / CODE-003) | **VERIFIED (finding confirmed)** |
| 3. NO-VALUE-EXTRACTION (confirmatory) | **VERIFIED (no issue — claim is atomic)** |
| Bonus: pre-existing invariant harness had gone vacuous | **REFUTED as sound — fixed** |

Reproduce everything:

```bash
cd /home/justin/code/audits/workspace/stable-yield-accumulator
forge test --match-path test/NudgeStreamerLiveness_SYA.t.sol -vv
forge test --match-contract SYAInvariants -vv
medusa fuzz --config medusa-tier3.json
```

## Positive control (gates everything below)

`test_P1_A_PositiveControl_ConfiguredClaimSucceeds` — a system wired in the exact order of the
in-source ops runbook (`StableYieldAccumulator.sol:81-88`) claims successfully and moves non-zero
value on every leg:

```
[PASS] test_P1_A_PositiveControl_ConfiguredClaimSucceeds() (gas: 542524)
  POSITIVE CONTROL: nudge deposited into streamer: 500000000
  POSITIVE CONTROL: phlimbo received: 500000000
  POSITIVE CONTROL: yield delivered to claimer: 1000000000
```

Anti-vacuity discipline applied throughout:

- `_assertNotVacuous()` aborts on empty state (no successful claim / no streamer deposit / no yield
  delivered / empty stream buffer). `test_P0_TripwireFiresOnEmptyState` is a meta-test proving the
  tripwire actually fires rather than being decorative.
- Properties 1 and 2 use the real `NudgeStreamer`, never a mock. The only mock in the nudge path is
  the sink, whose sole streamer-facing surface is `isNudgeToken` (a plain membership set in the real
  `BatchNFTMinterMultiToken`, reproduced verbatim).
- Every negative test seeds a real successful claim first, so the revert is a state transition from
  working to broken, not an artefact of an unconfigured fixture.

---

## Property 1 — CLAIM-LIVENESS: **VERIFIED (the finding is real)**

`test/NudgeStreamerLiveness_SYA.t.sol` → `ClaimLivenessTest`

```
[PASS] test_P0_TripwireFiresOnEmptyState()
[PASS] test_P1_A_PositiveControl_ConfiguredClaimSucceeds()
[PASS] test_P1_B_setRewardToken_BricksClaim_NotRegistered()
  REVERT SELECTOR: 0xd62cbfe800000000000000000000000000000000000000000000000000000000
[PASS] test_P1_C_setNudgeAddress_BricksClaim_NotRegistered()
[PASS] test_P1_D_UnsetStreamer_Reverts_NudgeStreamerNotConfigured()
[PASS] test_P1_E_Remediation_RequiresWhitelistThenRegister()
[PASS] test_P1_F_ZeroSplit_SurvivesBrokenStreamKey()
```

Exact selectors (`cast sig`):

| Selector | Error |
|---|---|
| `0xd62cbfe8` | `NudgeStreamer__NotRegistered()` |
| `0xb94406b2` | `NudgeStreamerNotConfigured()` |
| `0x0dc85695` | `NudgeStreamer__NotWhitelisted(address,address)` |

**Confirmed.** On a system that was fully and correctly configured per the documented runbook, a
single owner call to `setRewardToken(newToken)` makes **every** `claim()` carrying a payable nudge
share revert `NudgeStreamer__NotRegistered()` (`0xd62cbfe8`). `claim()` is the only permissionless
entry point, so the decentralized-conversion rail is fully down until the owner intervenes on a
*different* contract.

The test isolates the cause: the new reward token is given a token config, a phlimbo approval, and a
funded/approved claimer, so nothing else can be blamed. It also asserts the storage state directly —
the old `(sink, oldReward)` stream is still registered with `duration == DURATION`, while
`(sink, newReward)` has `duration == 0`. Nothing broke; the **key moved**. `setRewardToken`
(`:417-420`) does a bare assignment with no guard and no event. Warping 365 days forward and retrying
reverts identically, so this is permanent, not a transient.

Comparison with the sibling trigger: `setNudgeAddress` produces the *identical* revert via the
identical mechanism (`test_P1_C`). The difference is purely documentation — the ops NatSpec
(`:74-79`) lists `setNudgeAddress` as a re-arm trigger and does **not** list `setRewardToken`. That
asymmetry is the finding: the same footgun, with the warning attached to only one of the two setters.

Post-deploy default is also confirmed (`test_P1_D`): `nudgeStreamer` is a setter-only field defaulting
to `address(0)`, and a payable-nudge claim in that state reverts `NudgeStreamerNotConfigured()`.

Remediation is verified and carries its own ordering trap (`test_P1_E`): calling
`registerStream(sink, newReward, duration)` before whitelisting the new token reverts
`NudgeStreamer__NotWhitelisted(sink, newReward)`. The full two-step
(`setNudgeTokenWhitelist` → `registerStream`) restores liveness and the re-armed stream receives the
500e6 nudge share. Note this remediation requires the **streamer owner** and the **batch-minter
owner**, not the SYA owner who caused the outage.

The only mitigation reachable without touching the streamer is `setNudgeSplit(0)`
(`test_P1_F`), which restores claims at the cost of 100% of the nudge routing.

## Property 2 — STREAM-FLOAT-CONVERGENCE: **VERIFIED (the finding is real)**

`test/NudgeStreamerLiveness_SYA.t.sol` → `StreamFloatConvergenceTest`

```
[PASS] testFuzz_P2_C_FloatLimit(uint256,uint256) (runs: 33)
[PASS] test_P2_A_FloatConvergesTo_DonationRateTimesDuration_CadenceIndependent()
  expected float (donationRate * duration): 15000000000
  observed float @ 1-day cadence:           14999980659
  observed float @ 6-hour cadence:          14999977086
[PASS] test_P2_B_StreamNeverDepletes_UnderSubDurationCadence()
  standing undelivered float after 200 daily claims: 14982961180
[PASS] test_P2_D_NoOwnerSweep_FloatIsUnrescuable()
```

**Confirmed.** `NudgeStreamer.collectNudge` recomputes `rewardPerSecond = buffer * PRECISION / duration`
over the FULL duration on every deposit (`NudgeStreamer.sol:153`), and SYA's `claim()` *is* the deposit.
Under any claim cadence `T < D` the stream never depletes, and the standing undelivered float converges
to the fixed point:

```
B_{n+1} = B_n(1 - T/D) + d   =>   B* = d * D / T = donationRate * duration
```

Cadence-independence is demonstrated directly: 500 USDC/claim at a 1-day cadence and 125 USDC/claim at a
6-hour cadence carry the same 500 USDC/day donation rate and park the same ~15,000 USDC
(14,999.98 vs 14,999.98, within 0.01%). Fuzzed over T ∈ [D/100, D/4] and d ∈ [100e6, 10 000e6], the
float lands within 1% of `d·D/T` on every run.

`test_P2_B` confirms the buffer is strictly positive and monotonically non-decreasing at every
post-claim sample across 200 daily claims — the stream is a permanently-standing balance, not a
transient.

**The float is unrescuable.** `test_P2_D` probes ten sweep/rescue/withdraw/recover signatures against
the real `NudgeStreamer` — all revert (no such function; the contract has no fallback). The complete
external surface is `registerStream`, `collectNudge`, `pullPendingStream`, `pendingStream`, plus
`Ownable`. The owner's only lever is `registerStream`, which settles at the old rate and re-spreads the
**same** buffer over a new window; the test asserts the owner's balance is unchanged across it. Shrinking
`duration` to 1 second only accelerates delivery **to the sink** (verified: the flush drains the streamer
to zero and the sink receives ≥ the full float). So the float is not lost — it is permanently in transit
to the intended recipient — but it is un-redirectable and cannot be reclaimed by anyone.

Scale note for severity: at a 30-day duration, the standing float equals **30 days of nudge donations**.

## Property 3 — NO-VALUE-EXTRACTION: **VERIFIED (no issue)**

`test/NudgeStreamerLiveness_SYA.t.sol` → `NoValueExtractionTest`

```
[PASS] test_P3_A_NudgeLegFailure_RevertsWholeClaim()
[PASS] test_P3_B_PhlimboLegFailure_RevertsWholeClaim()
[PASS] test_P3_C_NoResidualAllowanceOrBalance()
```

Both legs are downstream of the `transferFrom` and un-enveloped (no try/catch), so a leg revert
reverts the entire claim. Confirmed empirically for both directions: with the nudge leg broken
(`NudgeStreamer__NotRegistered`) and with the phlimbo leg broken (`collectReward` reverting), the
claimer's skimmed surplus, the claimer's payment, the NFT burn, and the streamer deposit are all rolled
back to their pre-call values. A claimer cannot retain skimmed surplus while suppressing either leg.

No standing allowance survives a claim: the inline `forceApprove` is fully consumed by `collectNudge`
in the same transaction (`allowance == 0` afterwards), and no reward-token residual is stranded in the
accumulator.

---

## Additional finding: the pre-existing invariant harness had silently gone vacuous

This is a **harness** defect in the audit tooling, not a contract defect, but it invalidated the
prior run's Tier-3 result for this project and is exactly the failure mode the anti-vacuity
discipline exists to catch.

`test/Invariant_SYA.t.sol` predates story-026. It used `nudge = makeAddr("nudge")` (an EOA) and never
set a `nudgeStreamer`. Since story-026 a payable nudge share requires a configured streamer, and the
sink can never be an EOA (`registerStream` calls `isNudgeToken` on it). Measured on the unmodified
harness across 60 driven claims:

```
successful claims:      1        <-- only the split == 0 case
total nudge received:   0        <-- nudge leg NEVER exercised
total phlimbo received: 2000000000
```

`invariant_splitConservation` and `invariant_globalConservation` were therefore passing on
essentially empty state — 59 of 60 claims reverted and were swallowed by the handler's `catch`.

Fixed by wiring a real `NudgeStreamer` and a `SyaNudgeSinkMock` into `SYAHandler` in the documented ops
order, measuring the nudge leg as the combined (streamer + sink) delta, and adding an `advanceTime`
action so the linear depletion actually settles. Two tripwires added:

- `afterInvariant()` → `_assertNotVacuous()` (end-of-campaign, Foundry). Deliberately not an
  `invariant_`, because the ghosts are legitimately zero at the initial-state check.
- `property_noUnexpectedClaimFailure()` (Medusa-compatible, inverted into a failure counter that is
  true at genesis). This is the guard that would have caught the original vacuity.

Result after the fix — 60/60 claims succeed and the nudge leg carries value:

```
successful claims:      60
total nudge received:   35400000679
total phlimbo received: 84600001091
```

## Runner results and depth

```
runners: forge = yes, medusa = 1.5.1 yes, echidna = NOT INSTALLED (not attempted; Medusa is primary)
```

**Foundry invariant campaign** — `forge test --match-contract SYAInvariants`, 256 runs × 500 depth =
**128,000 calls**, all 6 invariants pass, `afterInvariant` tripwire satisfied on every sequence:

```
[PASS] invariant_callSummary()        (runs: 256, calls: 128000, reverts: 0)
  successful claims: 123
  failed claims: 0
  claims with a PAYABLE nudge share: 123
  total nudge value routed: 53448130467953
  zero-pay-with-yield events (diagnostic): 0
[PASS] invariant_globalConservation() (runs: 256, calls: 128000, reverts: 0)
[PASS] invariant_nftCostExactlyOne()  (runs: 256, calls: 128000, reverts: 0)
[PASS] invariant_noResidual()         (runs: 256, calls: 128000, reverts: 0)
[PASS] invariant_registrySync()       (runs: 256, calls: 128000, reverts: 0)
[PASS] invariant_splitConservation()  (runs: 256, calls: 128000, reverts: 0)
```

**Medusa campaign** — `medusa fuzz --config medusa-tier3.json`, `testLimit = 50 000`, 4 workers,
`callSequenceLength = 100`, assertion + property testing enabled: **49 passed, 0 failed**.

Medusa non-vacuity confirmed from its own lcov coverage rather than asserted:

| Line | Code | Hits |
|---|---|---|
| `StableYieldAccumulator.sol:583` | `safeTransferFrom(claimer -> this)` | 13,850 |
| `StableYieldAccumulator.sol:598` | `forceApprove(streamer, nudgeAmount)` | 13,469 |
| `StableYieldAccumulator.sol:599` | `collectNudge(nudge, rewardToken, ...)` | 13,469 |
| `NudgeStreamer.sol:149` | `safeTransferFrom(donor -> streamer)` | 13,469 |
| `NudgeStreamer.sol:153` | `rewardPerSecond` recompute | 13,469 |

The nudge leg was driven **13,469 times through the real streamer**, so the clean Medusa result is
about exercised code, not skipped code.

## Honesty statement

The **positive** results (Properties 1 and 2) are constructive: a concrete, minimal, deterministic
state transition from a working system to a bricked one / to a permanently-standing float. Those do
not depend on fuzz depth and are proofs of existence.

The **clean** results (Property 3, and the six structural invariants) are "no counterexample found in
128,000 Foundry calls and a 50,000-sequence Medusa campaign". That is **absence of evidence, not
proof of safety**. Nothing here was verified symbolically; no Halmos `[PASS]` was obtained. If the
claim-atomicity property (Property 3) is load-bearing for a finding's disposition, it should be handed
to the symbolic-analyzer for an actual proof rather than relied on from this fuzz result.

One harness bound worth stating plainly: `testFuzz_P2_C_FloatLimit` lower-bounds the cadence at
`D/100` purely so the geometric approach (ratio `1 - T/D`) can settle inside a runnable step count.
That is a budget limit, not a limit on the property — `test_P2_A` exercises `T = D/120` explicitly. An
earlier run of that fuzz test failed at 6.2% deviation; that was my step cap truncating the series
mid-convergence, not a refutation, and it resolved once the step count was scaled to 8 time constants.
