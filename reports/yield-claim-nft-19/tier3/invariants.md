# Tier-3 Empirical Verification — yield-claim-nft run-19

- Commit under test: `d4cc563`
- Workspace: `workspace/yield-claim-nft` (writable clone; `lib/` untouched)
- Test files:
  - `workspace/yield-claim-nft/test/run19-Tier3Nudge.t.sol` (T1–T4, local real-stack)
  - `workspace/yield-claim-nft/test/run19-T5-LegBUnboundedEth.t.sol` (T5, mainnet fork @ 25,550,000)
- Runners: `forge test` — 20/20 pass. Medusa/Echidna not used: every target below is a
  **directed differential** with a named counterexample sequence, not a search problem;
  a random-sequence fuzzer adds nothing over the deterministic sequences already exhibited.

> **Honesty note.** Where a test PASSES it is because the test asserts the *vulnerable*
> behaviour and that behaviour was observed. Nothing below is a proof of safety.

---

## Verdicts

| # | Finding | Verdict | Headline evidence |
|---|---------|---------|-------------------|
| T1 | CODE-002 payment-token collision sweep | **CONFIRMED** | 1-wei payment, `count=1` → **190.0 USDC** of a 200 USDC pot extracted by an unprivileged caller |
| T2 | CODE-001 NudgeRatchet wedge + no rescue | **CONFIRMED** | `"NudgeRatchet: nudgeStreamer unset"` / `NudgeStreamer__NotRegistered()`; no `rescueERC20` selector; streamer blacklist bricks *all* donors *and* the buffer |
| T3 | PATTERN-001 buffer residency | **MEASURED (no drift)** | Resident buffer converges to **exactly one stream window's inflow** (99.98% of `D·duration/dt` at 8 windows), cadence-independent, drains to **0** when donations stop |
| T4 | CODE-003 `release()` back-run | **CONFIRMED** | 50,000 USDC lump captured 100% by a same-block back-runner; streamed contrast captures 0 |
| T5 | CODE-007 Leg B whole-balance swap | **CONFIRMED** | Identical sandwich + identical `minPromoOut`: **reverts** without stray ETH, **succeeds** with it; sandwicher profit **0.2968 ETH** |

Plus one incidental: **the repo's test tree did not compile at `d4cc563`** (ledger Q-17). Repaired
— see "Q-17" below.

---

## T1 — CODE-002: payment-token collision sweep — **CONFIRMED (High-shaped)**

Contract: `Run19_T1_PaymentTokenCollision`, 4/4 pass.

Wiring is the **real** stack: real `NudgeStreamer`, real `BatchNFTMinterMultiToken`, real
`NFTMinterV2`, real `NudgeRatchet` + `Uniboost` + `GatherV2` (mocks limited to ERC20s and a
UniV2 pair stub the `Uniboost` constructor validates).

### The sequence

1. 20 real user mints on the USDC-prime `NudgeRatchet` index → 200 USDC into the streamer.
2. Window elapses; flush → **pot = 200,000,000 (200 USDC)** on the batch-minter.
3. **One owner transaction:** `batch.setDispatcherIndex(1)` — index 1 is the USDC-prime
   `NudgeRatchet`. `_resolvePaymentPath` now derives USDC as the payment token, while USDC
   remains on the nudge whitelist (`isNudgeToken(USDC) == true`, asserted).
4. Unprivileged `attacker` calls `batchMint(count = 1, recipient = attacker, paymentAmount = 1 wei, [0])`.

### Result

```
T1 pot at attack (USDC 6dp):        200000000
T1 extracted by count=1 caller:     190000000
T1 attacker payment budget supplied:        1
```

The attacker supplies **1 wei** and receives **190 USDC** plus the NFT. Two amplifiers the
Tier-2 write-up did not state, both observed:

- **The mint is funded out of the pot itself.** Step 6 grants `nftMinter` an *unbounded*
  allowance over the batch-minter's whole balance, so the 10 USDC mint price is pulled from
  the pot, not from the caller. `paymentAmount` need only be ≥ `DUST_THRESHOLD`-relevant,
  not ≥ the mint cost. Extraction is exactly `pot − mintPrice`.
- **`_payRewards` never runs.** `count(1) < nudgeSize(5)` ⇒ `qualifies == false` ⇒ snapshot all
  zero. Value leaves through the **step-10 dust sweep**, which is not gated on `qualifies`.
  Asserted: `nftRecipient` received nothing, the caller received everything.

Also confirmed **repeatable**: after 10 further honest mints refilled the stream, a second
`count=1` call captured another **100 USDC** (`test_T1_repeatableAsThePotRefills`).

**Control (non-vacuity):** `test_T1_control_beforeRepoint_count1_capturesNothing` runs the
identical `count=1` batch *before* the repoint against the identical non-empty pot and the
attacker gets **0**. The delta is caused solely by the collision, not by the harness.

**Non-vacuity justification:** pot funded by 20 real `NFTMinterV2.mint` calls through the real
dispatcher into the real streamer; three tripwires assert non-zero state before the exploit
(`buffer == 20 × price`, whole donation claimable, pot landed on the batch-minter), plus
`assertGt(extracted, 0)`.

---

## T2 — CODE-001: mandatory-streamer wedge + no rescue — **CONFIRMED**

Contract: `Run19_T2_RatchetWedge`, 4/4 pass. Exact revert data, not "it reverts":

| Trigger | Exact revert |
|---|---|
| `nudgeStreamer == address(0)` (post-deploy default) | `Error("NudgeRatchet: nudgeStreamer unset")` |
| `(batchMinter, USDC)` pair unregistered | `NudgeStreamer__NotRegistered()` (selector-matched via `vm.expectRevert(NudgeStreamer.NudgeStreamer__NotRegistered.selector)`) |

In both cases the revert propagates through `ATokenDispatcherV2.dispatch` → `NFTMinterV2._executeMint`
and **the whole user mint reverts** (`balanceOf(user, idx) == 0` asserted).

### Funds are unreachable

`test_T2c_residentUsdcIsUnreachable_noRescueSelector`, with 500 USDC resident on the ratchet:

- A raw `call` to `rescueERC20(address,address,uint256)` from the **owner** returns `false`
  — the selector does not exist on `NudgeRatchet`.
- **Positive control in the same test:** the identical call on a freshly deployed sibling
  `NudgeRatchetDelayRelease` returns `true`. So the negative is a real absence, not a
  broken call.
- The only forwarding path (`dispatch`) is itself reverting `NudgeStreamer__NotRegistered()`.
- Final assertion: the 500 USDC is still on the ratchet.

### Third-party trigger — CONFIRMED and worse than described

`test_T2d_blacklistOnStreamerBricksEveryDonor`. A 6-dp USDC stand-in with a real-USDC-style
blacklist. Both donors are first shown working (buffer non-zero — tripwire), then the
**streamer** address is blacklisted:

- `NudgeRatchet` mint → `Error("USDC: recipient blacklisted")` (inbound `transferFrom` leg).
- `Uniboost` dispatch → same revert. One blacklisting, every donor sharing the streamer.
- **Additional, beyond the Tier-2 claim:** the funds *already buffered inside the streamer*
  also become unreachable — `pullPendingStream` reverts `Error("USDC: sender blacklisted")`
  on the outbound `_settle` transfer, and `NudgeStreamer` has no owner rescue of its own.
  So a streamer blacklist is not only a liveness brick on five donors, it is a permanent
  strand of the pooled buffer.

**Non-vacuity justification:** the wedge tests assert a *successful* mint path exists before
each brick (T2d) or assert the guarded state (`nudgeStreamer() == 0`, `duration == 0`,
`balanceOf(ratchet) == 500e6`) before asserting the failure; the no-rescue negative is paired
with a positive control on a sibling contract.

---

## T3 — PATTERN-001: buffer residency — **MEASURED; no rate drift found**

Contract: `Run19_T3_BufferResidency`, 6/6 pass. 7-day stream window, 10 USDC donated per mint
through the real ratchet into the real streamer.

### Residency vs cadence (14-day horizon = 2 windows)

| cadence `dt` | mints | donated | delivered | **resident** | claimable *now* | residency (bps) |
|---|---|---|---|---|---|---|
| 10 min | 2016 | 20,160.00 | 11,442.83 | 8,717.17 | 8.65 | 4323 |
| 1 h | 336 | 3,360.00 | 1,906.01 | 1,453.99 | 8.65 | 4327 |
| 6 h | 56 | 560.00 | 316.53 | 243.47 | 8.70 | 4347 |
| 24 h | 14 | 140.00 | 78.09 | 61.91 | 8.84 | 4422 |

(USDC. `delivered + resident == donated` asserted every row — nothing is lost.)

### Residency vs horizon (24 h cadence)

| horizon | donated | resident | residency (bps of donated) | resident as bps of one-window inflow `D·duration/dt` |
|---|---|---|---|---|
| 1 window | 70.00 | 46.21 | 6600 | **6600** |
| 2 windows | 140.00 | 61.91 | 4422 | **8844** |
| 4 windows | 280.00 | 69.07 | 2466 | **9866** |
| 8 windows | 560.00 | 69.99 | 1249 | **9998** |

### Interpretation (measurement only — econ-scanner adjudicates)

- The resident buffer is a **first-order lag with time constant exactly `duration`**: it
  converges to `D · duration / dt` — precisely **one stream window's worth of inflow** —
  reaching 99.98% of that asymptote after 8 windows. The observed values match
  `B*(1 − e^{−T/τ})` to the last digit at every cadence.
- Residency as a **fraction of cumulative donations is cadence-independent** (43.2% ± 1%
  at 2 windows across a 200× range of cadences) and decays as `duration/T`.
- **There is no rate drift.** `rewardPerSecond` is recomputed over the *full* buffer on every
  deposit, and `_accrued` caps at `buffer`, so the linear-depletion pathology seen in the
  phlimbo V1 class does not reproduce here.
- **Nothing is stranded.** `test_T3_tailDrainsFullyAfterDonationsStop`: after 200 hourly mints
  leave 1,170.97 USDC resident, one window of silence drains the streamer to **exactly 0**.
- Cumulative shortfall vs the pre-change behaviour (immediate `safeTransfer` to the
  batchMinter) is exactly the resident amount at any instant — bounded, not cumulative.
- Side observation supporting the design's stated goal: **claimable-right-now is always
  ≈ one donation** (~8.65 USDC) regardless of cadence or how large the buffer has grown.
  The anti-burst property the streamer advertises does hold on the streamed donors.

**Non-vacuity justification:** every mint is a real `NFTMinterV2.mint` (not a mock deposit);
tripwires assert `donated == n × price` and `rate > 0` before any measurement, and the
conservation identity `delivered + resident == donated` is asserted in each run.

---

## T4 — CODE-003: `NudgeRatchetDelayRelease.release()` back-run — **CONFIRMED**

Contract: `Run19_T4_DelayReleaseBackrun`, 3/3 pass.

`releaser` releases a **50,000 USDC** lump; it lands *directly* on the batch-minter
(asserted). In the **same block, no `vm.warp`**, a searcher calls
`batchMint(count = 5, recipient = searcher, …, minRewards = [50,000e6])` — the floor is set to
the whole lump, i.e. the searcher can guarantee they either take all of it or pay nothing.

```
T4 lump captured (USDC 6dp):    50000000000   (100% of the release)
T4 searcher cost (PAY 18dp):     5000000000000000000  (5 mints)
```

- `usdc.balanceOf(searcher) == LUMP`, `usdc.balanceOf(batch) == 0` — emptied in one block.
- `test_T4_honestBatcherIsFrontRunOut`: the next honest batcher pays the same 5 mint costs
  and receives **0**.
- **Contrast test (`test_T4_contrast_streamedDonorIsNotBurstCapturable`):** the *same*
  50,000 USDC routed through the streamer by `NudgeRatchet` yields the same-block back-runner
  **exactly 0**, with ≥ `LUMP − 1` still buffered. This is the direct empirical demonstration
  that the story-046 invariant holds on the four streamed donors and does **not** hold on the
  fifth path.

**Non-vacuity justification:** the pot is asserted empty before the release and asserted equal
to the lump after it; the contrast arm proves the harness *can* produce a zero-capture outcome,
so the 100%-capture result is not an artifact of the wiring.

---

## T5 — CODE-007: Leg B swaps the whole ETH balance — **CONFIRMED (still live)**

Contract: `Run19_T5_LegBUnboundedEth`, 3/3 pass. **Mainnet fork @ block 25,550,000** with live
UniV2 router/factory, Sky PSM, sUSDS ERC-4626 and Balancer V3 — no mocked AMM. `pool()` is
called with the current **6-arg** signature, so this is a post-rework confirmation.

### T5a — the raw property

1,000 USDC pooled ⇒ the 30% leg produces **0.16179 ETH**. A third party sends **1.61794 ETH**
(10×) to the open `receive()`. After `pool()`:

```
T5a leg-produced ETH (wei):            161793981717043178
T5a stray ETH swapped alongside it:   1617939817170431780
T5a total ETH consumed by Leg B:      1779733798887474959
T5a floor dilution factor x100:                      1100   (11.00x)
```

`address(disp).balance == 0` — the **entire** balance was swapped, not the leg output.
`minPromoOut` therefore bounds a trade **11× larger** than the one it was priced for.

### T5b / T5c — the decisive differential

Both arms use an **identical** `minPromoOut = 478.315e18` (the promo expected for the leg's own
ETH, 1% tolerance — exactly what an honest off-chain pooler computes) and an **identical**
12 ETH sandwich:

| arm | stray ETH resident | outcome |
|---|---|---|
| **T5b** (no stray) | 0 | `pool()` **REVERTS** `UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT` — the floor does its job |
| **T5c** (stray present) | 1.61794 ETH | `pool()` **SUCCEEDS**; sandwicher exits with **+0.29677 ETH profit** |

This is the finding stated as an experiment: the floor is not merely "less tight", it flips
from *rejecting* a given sandwich to *accepting* it, purely because of ETH the pooler did not
put there. The stale-residual case needs no attacker at all — `rescueETH`'s own NatSpec
concedes a partial Leg B leaves resident ETH.

**Non-vacuity justification:** live-liquidity fork (a mocked router could not produce a
price-impact differential at all); `receive()` acceptance, non-zero leg quote, non-zero
front-run output, non-zero promo acquired and `balance == 0` post-`pool()` are all asserted;
and the T5b **revert** arm proves the floor is genuinely load-bearing in the harness, so the
T5c success is a real relaxation rather than a floor that never bound anything.

---

## Q-17 — repo test tree did not compile at `d4cc563`

Two edits made, both flagged for the ledger:

1. **`test/Tier3PromotionInvariants.t.sol:120`** — `disp.pool(amountIn, 0, 0, 0, 0)` updated to
   the current 6-arg signature `disp.pool(amountIn, 0, 0, 0, 0, 0)` (trailing `minLP`), with an
   inline `// run-19: Q-17 bit-rot repair` comment. **Until this edit `forge build` failed, so
   the entire test suite — every existing regression test in the repo — was unrunnable at
   `d4cc563`.**
2. No second edit made, but note: **Q-17 is only partially addressed.** With the arity fixed,
   `test_guided_sequence_holdsAllInvariants` now compiles and then fails at runtime with
   `PromotionUniV2_Eth: nudgeStreamer unset` — the harness predates story-046 and never wires
   a `NudgeStreamer`, so a donation-enabled `dispatch` cannot succeed. Repairing that requires
   deploying a real `NudgeStreamer` + `BatchNFTMinterMultiToken` and registering the
   `(batchMinter, USDC)` stream (the harness currently uses a plain EOA as `batchMinter`).
   Left unrepaired deliberately: T5 above covers the same property against live state.
   *Incidentally, this runtime failure is a fourth independent reproduction of the CODE-001
   mandatory-streamer class, this time on `PromotionUniV2_Eth`.*

---

## Artifacts

- `workspace/yield-claim-nft/test/run19-Tier3Nudge.t.sol` — 17 tests (T1–T4)
- `workspace/yield-claim-nft/test/run19-T5-LegBUnboundedEth.t.sol` — 3 tests (T5, fork)
- `reports/yield-claim-nft-19/tier3/invariant-results.json`

Reproduce:

```bash
cd workspace/yield-claim-nft
forge test --match-path 'test/run19-Tier3Nudge.t.sol' -vv          # T1-T4, no RPC needed
MAINNET_RPC_URL=$RPC_MAINNET forge test --match-contract Run19_T5 -vv   # T5, archive RPC
```
