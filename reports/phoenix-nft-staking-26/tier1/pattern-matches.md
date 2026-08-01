# Tier-1 Pattern Matching — phoenix-nft-staking run-26

- **Target**: `lib/phoenix-nft-staking` @ `9611312` (read-only)
- **Mode**: REGRESSION (ledger present, 78 entries)
- **Pattern DB**: `patterns/vulnerability-patterns.json` v1.1
- **patternsChecked**: 35
- **patternsSkipped**: 1 — `FRONTRUN-APPROVE` (`note` field: "C4 typically considers this QA/known issue"). No HM twist observed; `forceApprove` in `batchMint` sets an absolute per-mint target and is revoked at :655. Not routed to manualReview.
- **Scope scanned**: `src/BatchNFTMinterMultiToken.sol` (837 L), `src/NudgeStreamer.sol` (272 L), `src/INudgeStreamer.sol` (43 L)
- **errors[]**: none — all three in-scope files read in full.

Commit range under review: `2ba764e` (story-031, `collectNudge` credits RECEIVED) and `9611312` (story-032, removal of the admin-time payment-token whitelist rejection).

---

## MATCH — finding candidates

### PATTERN-001 — `DOS-UNBOUNDED-LOOP` (+ recurring class 6, 7)
**`src/BatchNFTMinterMultiToken.sol:528-536`** (loop body :533), interacting with `NudgeStreamer.sol:220-225` and `:238-246`.

The step-3.5 streamer flush is **unconditional on `qualifies`**, while every other reward-token
interaction in `batchMint` is gated on it. `qualifies` is computed at :510-514, but the flush loop
at :528-536 does not read it; `_snapshotRewards` gates its `balanceOf` behind
`qualifies ? ... : 0` at :801, and `_payRewards` skips zero entries at :831.

Consequence: story-028's streamer wiring widened the reward-token blast radius from *qualifying*
batches to **every** batch, including `count < nudgeSize` batches and batches made while the nudge
feature is **fully disabled** (`nudgeSize == 0`). The documented disable lever does not disable the
flush.

There is no `try/catch`. `pullPendingStream` reverts whenever a registered stream has
`settled > 0` and the token's `safeTransfer` at `NudgeStreamer.sol:243` reverts — a paused
token, a token that has blacklisted the batchMinter address, or any transfer hook that reverts.
One such token anywhere on the whitelist bricks **all** `batchMint` calls.

> Exploit sketch: any single registered nudge token that pauses or blacklists the batchMinter
> address makes every `batchMint` revert — including non-qualifying, `nudgeSize == 0` batches that
> have no interest in the nudge at all — with no `try/catch` and no per-token bypass.

Amplifier: `_nudgeTokens` is owner-extensible with **no cap** (`setNudgeTokenWhitelist` :328-349),
and the flush adds a **third** O(n) pass over it, this one costing an external `CALL` per element
rather than an `SLOAD`.

**Law-3 side**: in scope. The owner registering a real-world pausable/blacklisting ERC20 as a
stream would not expect it to be able to brick a batch that does not touch the nudge at all — the
`qualifies` gate at :801 actively suggests the opposite. **Non-obvious footgun**, not an
obvious misconfiguration.

**Precedent for filing**: ledger `966e717669` (L-02, open) is the same class one contract over —
"`NFTStakerDepletion._syncBudget` un-`try/catch`'d `dispatcherHook.pull()` lets an unauthorized
hook DoS". Distinct contract and entry point, so a distinct fingerprint; disclose the sibling.

Confidence: **high** (signatures + conditions confirmed by read; no mitigation present).
Severity: `potential-medium` (protocol function/availability impacted, no direct asset loss).

---

### PATTERN-002 — `CENTRALIZATION-ADMIN` / recurring class 7 (silent-brick on an owner setter)
**`src/BatchNFTMinterMultiToken.sol:297-300`** (`setNudgeStreamer`).

`setNudgeStreamer` accepts any address with **no structural probe of the target**. This is
asymmetric with its counterparty: `NudgeStreamer.registerStream` deliberately probes the
batchMinter with `isNudgeToken` at `NudgeStreamer.sol:127` precisely to confirm "the target is
actually a MultiToken batchMinter" (documented at `NudgeStreamer.sol:10-17`). The reverse
direction has no equivalent check.

Partial defeat, stated precisely so it is not overclaimed: for an **EOA** the pattern is
**DEFEATED** — solc 0.8.20 retains the `extcodesize` check for external calls to
void-returning functions, so `INudgeStreamer(eoa).pullPendingStream(...)` reverts loudly rather
than no-op'ing. The residual is a **contract** with a permissive fallback (a Safe, a proxy with
an unset implementation, another Phoenix contract): the flush then succeeds and does nothing,
forever.

> Exploit sketch: `nudgeStreamer` mis-pointed at a fallback-bearing contract makes the flush a
> permanent silent no-op — donor buffers accumulate unreachably in the real streamer, the pot
> under-funds, and nothing reverts or emits a failure signal.

Aggravating: `setNudgeStreamer` emits `NudgeStreamerChanged` *before* assignment (:298-299), so
the event is well-formed and a mis-point looks like a clean success in logs.

**Law-3 side**: in scope, **non-obvious footgun**. Same class as run-21 M-02 (`setNudgeStreamer`,
phStaging) and the stable-yield-accumulator `setRewardToken` brick. Not present in this project's
ledger — nearest entry is `cf332bf46c` (Q-01, open), which is about `INudgeStreamer`
under-documentation, not the unvalidated setter.

Confidence: **medium** (pattern shape confirmed; the reachable residual is narrower than the
signature suggests, as stated above).
Severity: `potential-low`.

---

## Regression reconcile — recurring classes that are ALREADY LEDGER'D and STILL LIVE

These are the checks the task asked for explicitly. All three remain live at `9611312`; none is a
new finding, and none should be re-filed.

| Class | Ledger | Status | Verdict at `9611312` |
|---|---|---|---|
| 1 — Linear-Depletion / rate-drift | `aaebb4b9b0` L-02 | open | **STILL LIVE**, untouched by story-031/032 |
| — no-rescue / stranded buffers | `4a1d8edc92` L-01 | open | **STILL LIVE** |
| — time-throttle not value-cap | `6f46ec80f1` L-03 | open | **STILL LIVE** |
| 2 — balance-delta vs stated-amount | `2d34673536` L-04 | fixed | **STILL FIXED** (see DEFEATED-3) |

**Class 1 detail (the one the task flagged to check hard).** `NudgeStreamer`'s docstring
(`:26-33`) claims the load-bearing invariant is "recompute-`rewardPerSecond`-on-deposit-only",
and that V1's bug was "resetting the streaming window on every touch". The recompute is indeed
absent from `_settle` (:238-246) and from `pendingStream` (:230-233) — that half holds. But
`collectNudge` is **permissionless** and its recompute at `:206` re-spreads the *entire remaining
buffer* over a fresh full `duration`. A deposit is a touch, and anyone can make one for 1 wei
(`amount == 0` reverts at :163, 1 wei does not).

Modelled: with deposits of ε every Δ seconds, `buffer_{n+1} = buffer_n·(1 − Δ/D) + ε`, so the
burst decays **geometrically**, not linearly. At the nominal window end `t0 + D` roughly
`e^-1 ≈ 36.8%` of the burst is still buffered where the design says 0%; ~13.5% at `2D`, ~1.8%
at `4D`. This is the same *decelerating* shape as the PoC'd 63.26% drift in
`b58b172e2a` (M-01, `NFTStakerDepletion`, fixed), and it is what `aaebb4b9b0` already records.

Worth carrying forward to the reasoning tiers as an **honest strengthening** of that Low: the
mechanism does not require a griefer. Legitimate cadenced seeding (cf. story-073
"Seed phUSD/Kendu nudge streams") resets the window on every top-up, so the pot systematically
under-releases relative to the documented "streams linearly to zero over `duration`" under
**normal operation**. That is a Law-2 faithfulness angle the existing entry frames only as
griefing. Not a re-file — a re-weigh input.

---

## DEFEATED — pattern shape present, specific guard defeats it

Each entry names the defeating guard and quotes the line. No entry here rests on "looks fine".

1. **`FEE-ON-TRANSFER-ACCOUNTING` / `YIELD-PRINCIPAL-ACCOUNTING-SKEW` at `NudgeStreamer.sol:193-199`.**
   Defeated by the bracketed, capped measurement:
   `uint256 received = IERC20(token).balanceOf(address(this)) - heldBefore;` then
   `if (received > amount) received = amount;`. `heldBefore` is read at :193 — *after* `_settle`'s
   outbound transfer, so the bracket spans exactly one transfer. The `min` closes the
   donation-inflation direction the task asked about (`MockDonatingOnPullERC20` exists for it).
   This is the story-031 fix; it is correct as landed.

2. **Same pair at `BatchNFTMinterMultiToken.sol:580-604`** (the mirror site the task asked me to
   look for). Defeated by `budget = credited < paymentAmount ? credited : paymentAmount;` (:604)
   bracketing only the :581 `safeTransferFrom`. I found **no remaining site that credits a stated
   amount**: `_payRewards` (:833) transfers the contract's own snapshotted balance, so there is no
   requested-vs-received gap to mis-attribute.

3. **`BATCH-PAYOUT-FIXED-POT` "pot snapshotted AFTER an external loop (donation self-refund)"
   limb.** Defeated by ordering: `snapshot` is captured at :538 into **memory** before the mint
   loop and is not re-read at the payout (:827-836). A reentrant donation during the loop cannot
   enter it. This also confirms `2d34673536` STILL FIXED: a flushed payment-token stream reaches
   only a *qualifying* recipient, because `_snapshotRewards` pins non-qualifying entries to 0
   at :801, and it cannot leak through the refund because `refund = min(budget, available)` with
   `budget <= paymentAmount` (:604, :709).

4. **`REENTRANCY-ERC721-RECEIVE` via `nftMinter.mint(_dispatcherIndex, recipient)` (:650).**
   `recipient` is caller-chosen and the ERC1155 receive hook fires mid-loop. Defeated for
   *value* by (a) `nonReentrant` on `batchMint` (:467) and (b) the pre-loop memory `snapshot`
   above — a hook re-entering `NudgeStreamer.collectNudge` (a *different* contract's guard, so
   reachable) credits the streamer buffer, which `snapshot` cannot see. Note ledger `d0ed2cf440`
   (Q-02, wont-fix) already records the surface as real-but-held.

5. **`REWARD-ACCRUAL-ORDER` (settle-at-OLD-rate).** Defeated at both mutation sites:
   `registerStream` calls `_settle(s, batchMinter, token);` at :134 *before* writing
   `s.duration`/`s.rewardPerSecond`, and `collectNudge` calls it at :161 before `s.buffer +=`.
   `_settle` provably never recomputes the rate (:238-246).

6. **Recurring class 3 (un-recomputed accrual on an early-exit path).**
   `pullPendingStream`'s `if (s.duration == 0) return;` (:222) exits without settling. Defeated
   because `buffer > 0 ⟹ duration > 0`: the only two credit sites are `collectNudge`, guarded by
   `if (s.duration == 0) revert NudgeStreamer__NotRegistered();` (:158), and `registerStream`,
   guarded by `if (duration == 0) revert NudgeStreamer__ZeroDuration();` (:126). The early exit
   can therefore only skip a zero buffer.

7. **Recurring class 4 (un-banked leg of a two-leg operation).** `_settle` banks both legs
   together — `s.buffer -= settled;` immediately precedes the transfer (:242-243) — and
   `collectNudge` banks `s.buffer += received` before deriving the rate from it (:201-206).
   No asymmetric leg found.

8. **`ROUNDING-DIRECTION`.** Both divisions floor in the protocol's favour:
   `(s.buffer * PRECISION) / duration` (:206) under-states the rate, and
   `(s.rewardPerSecond * elapsed) / PRECISION` (:268) under-states the payout; the residue stays
   in `buffer`. The rate-truncates-to-zero trap is defeated by `PRECISION = 1e18` — reaching
   `rate == 0` needs `duration > buffer · 1e18`, i.e. >1e18 seconds for a 1-wei buffer.

9. **`DIVISION-PRECISION`.** Both expressions above are multiply-before-divide. Defeated.

10. **`REENTRANCY-READONLY` on `pendingStream` (:230-233).** Defeated by CEI inside `_settle`:
    `s.lastUpdate` and `s.buffer` are both written (:240, :242) before the `safeTransfer` at :243,
    so a view read during that callback sees a settled, consistent stream and returns 0 accrued.

11. **`RETURN-VALUE-IGNORE`.** `SafeERC20` on every transfer path in both contracts
    (`using SafeERC20 for IERC20`, `NudgeStreamer.sol:64`, `BatchNFTMinterMultiToken.sol:160`).

12. **`MISSING-SLIPPAGE`.** A per-token floor exists (`minRewards`, checked at :803-805) and it
    runs ahead of the pull and the mint loop. Its known limitation — a floor on the pre-transfer
    balance rather than the delivered amount — is already ledger'd as `bfdb50105e` (Q-03,
    wont-fix) and documented at :429-433.

13. **`INCORRECT-OPERATOR`.** `if (refund / DUST_THRESHOLD != 0)` (:710) is an idiomatic
    `refund >= 1e6`; the boundary semantics match the documented intent at :139. The
    decimals-blindness of the threshold is already ledger'd (`51aed27661`, merged;
    `38ea47b14c`, wont-fix).

14. **N/A (no code signature present in scope)**: `ERC4626-INFLATION`, `ORACLE-STALE`,
    `ORACLE-ROUNDID`, `SIGNATURE-REPLAY`, `PERMIT-FRONTRUN`, `CROSS-CHAIN-REPLAY`,
    `TIMELOCK-BYPASS`, `DOUBLE-VOTING`, `UNPROTECTED-INIT`, `STORAGE-COLLISION`,
    `FIRST-DEPOSITOR-ATTACK`, `UNSAFE-DOWNCAST` (no casts), `SELFDESTRUCT-FORCE-ETH` (no ETH
    path, no `receive`/`fallback`), `FLASH-LOAN-PRICE` (no price derivation), `WEAK-PRNG`
    (`block.timestamp` drives accrual, not a value-bearing random outcome),
    `MINT-ON-DEMAND-OVERMINT` (no mint authority in scope),
    `REWARD-RUNWAY-DEPLETION` / `EMISSION-WINDOW-BOUNDARY` (no `windowEnd`/budget model in the
    streamer — the per-stream cap at :266-271 is the whole bound),
    `TWO-STEP-COMMIT-WINDOW`, `REENTRANCY-ERC777`, `REENTRANCY-CROSS-FUNCTION` (contract-wide
    `nonReentrant` on both mutating streamer entry points).

---

## manualReview — low confidence, routed not dropped

Per Law 1 these are uncertainty about whether the pattern *applies*, not about severity.

- **MR-26-01 — sub-wei truncation forfeiture on every flush.** `NudgeStreamer.sol:240` sets
  `s.lastUpdate = block.timestamp` **unconditionally**, including when `settled == 0`, so each
  flush discards the fractional accrual. Because PATTERN-001's flush is unconditional on
  `qualifies`, any `batchMint` cadence triggers it: ≤1 wei per stream per call, ≤~50k wei over a
  7-day window at 12s blocks. Dust, and each call costs a real paid mint. **Keep separate from
  `aaebb4b9b0`** — that entry is the window-*reset* mechanism, this is *truncation*; collapsing
  them would lose one.
- **MR-26-02 — `registerStream` lacks `nonReentrant`** while `_settle` (:134) makes an outbound
  transfer, unlike its two siblings. Analysis suggests benign: state written after `_settle`
  reads the post-reentry `s.buffer` at :139, so a reentrant credit folds in correctly. `onlyOwner`
  + malicious-token precondition. Flagged only for the guard asymmetry.
- **MR-26-03 — `recipient` unvalidated beyond non-zero** (:472); `recipient == address(this)`
  would route `_payRewards` to self. Probably unreachable (ERC1155 receiver requirement on the
  mint at :650). Needs the `yield-claim-nft` minter to confirm — out of this tier's scope.
- **MR-26-04 — `rewardPerSecond * elapsed` overflow** (:268) at absurd `buffer` with
  `duration == 1`. Would brick `collectNudge` *and* `pullPendingStream` for the pair, and hence
  `batchMint` via PATTERN-001's loop. Needs ~1e50 buffer; recorded for the overflow-bricks-the-loop
  coupling only.

---

## Not re-filed (settled — per task instruction)

- `paymentToken == nudgeToken` collision and its arbitrage — owner-PERMITTED, decided 2026-07-25.
  Story-032 removes the last admin-time trace of the old rejection; the budget-sourced refund
  (:604, :709) is the actual guard and it is intact. Confirmed, not filed.
- Fee-on-transfer / weird-ERC20 as a standalone finding — C4 known-invalid.
- Winner-take-all / value-blind count gate — `858e9e807a` (H-01, wont-fix), `521c20ad48`
  (M-01, wont-fix).
- Aggregate over-funding across pots (class 5) — `43e8c48626` (M-01, wont-fix).
- Class 3 `emergencyWithdraw` over-emission — `911c54fd6d` (M-02, wont-fix); no
  `emergencyWithdraw`-shaped path exists in either in-scope contract this run.
- "A malicious owner could…" vectors. Both MATCHes above are argued explicitly on the
  **non-obvious footgun** side of the Law-3 line.
