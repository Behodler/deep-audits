# Carryover QA Report — originating audit 19 (carried into yield-claim-nft-20)

> **Carryover QA report — audit 19** (cut down from `yield-claim-nft/reports/19/submissions/qa-report.md`).
> Retained below (still open / untriaged as of audit 20): **Q-01, L-01, L-02, L-03, L-04, L-05, L-06 (run-19 C4 labels)**.
> Removed as no longer live: none of the filed findings. Withdrawn retraction records ~~Q-02~~ and ~~Q-03~~ (Appendix D; never ledgered) are not copied.
> Structural sections not copied (they carry no live findings of their own): title block + Summary, Appendix A (refuted), Appendix B (clean drift-watch verdicts), Appendix C (4naly3er), Appendix D (withdrawn), "Parked, not dropped" (manual-review pointers MR-01..MR-07).
> Retained counts: Low 6 · QA 1.
> Labels are the originals — gaps in the sequence are the removals above, not omissions.
> Re-observed in run 20: Q-01 (=Q-18), L-02 (=L-17), L-03 (=L-18) (`lastSeenRun` → yield-claim-nft-20), each gaining a UniPoolerV2 second location (`_psmDonate` L333 / `_dispatch` L290). L-05 (=L-20) was not re-flagged but its mechanism is unchanged — stays open. L-01 (=L-16), L-04 (=L-19), L-06 (=M-06) carried for recall only.
> Line numbers and links were accurate at the originating commit, and relative links reflect the repository
> layout of that run (`reports/yield-claim-nft/NN/`, `lib/yield-claim-nft/src/...`); the source now lives at
> `yield-claim-nft/src/src/...`. Re-verify every location against current HEAD `2bfa090`.
>
> ⚠ **Run-19 used run-scoped C4 labels that differ from the ledger.** Mapping: `Q-01` = ledger **Q-18** (`11d8b865…`), `L-01` = **L-16** (`b0aa0f58…`), `L-02` = **L-17** (`79a2cd4a…`), `L-03` = **L-18** (`482cefc3…`), `L-04` = **L-19** (`9fdcb0c6…`), `L-05` = **L-20** (`1c1e0001…`), `L-06` = **M-06** (`25a9ab3e…`, ledger label retained though severity is Low). Use the ledger label/fingerprint with `/ledger`.
>
> Triage any of these with `/ledger yield-claim-nft`.
>
> *The text below is a verbatim copy of the retained sections of the original report.*

---

## QA / Hardening

### [Q-01] Streamer `forceApprove` is the sole unpaired approval across all four dispatchers <!-- id: ycn19q1 -->

**Location**: [`BalancerPoolerV2.sol#L346`](https://github.com/Behodler/yield-claim-nft/blob/d4cc563264c7d57cf4c22e9ba561743484a305cd/src/dispatchers/BalancerPoolerV2.sol#L346) · also `NudgeRatchet.sol:160`, `Uniboost.sol:250`, `PromotionUniV2_Eth.sol:396`

**Description**: Every **other** `forceApprove` in these contracts is paired with a zeroing reset after the external call — including the PSM approval eleven lines earlier in the same function. The `forceApprove(nudgeStreamer, amount)` preceding `collectNudge` is the only one left unpaired, in all four dispatchers.

**Exploitability is affirmatively refuted (R-03)**: the approval is for an exact amount, `NudgeStreamer.collectNudge:149` pulls exactly that amount, it happens in the **same call**, and any failure rolls the whole thing back atomically. No residual allowance can survive a successful call, and a partial pull would require the owner to repoint the dispatcher at a hostile streamer — an obvious owner action, suppressed under Law 3.

**This is not the C4 known-invalid approve-race / `safeApprove` front-running pattern.** That pattern concerns a non-zero-to-non-zero allowance change being front-run by the spender. Nothing here is front-runnable: the approve and the pull are in one transaction. The item is filed purely as consistency hardening, because the safe-today property rests on an **external, cross-repo** contract's implementation detail rather than on any invariant local to this repo — if `collectNudge` ever under-pulls, the residual becomes real with no local guard to catch it.

**Recommendation**: pair the approve with a zeroing reset, matching the surrounding style.

```solidity
IERC20(token).forceApprove(nudgeStreamer, amount);
INudgeStreamer(nudgeStreamer).collectNudge(batchMinter, token, amount);
IERC20(token).forceApprove(nudgeStreamer, 0); // add: match the PSM approval 11 lines above
```

---

## Low Risk Findings

### [L-01] Repointing a live dispatcher silently arms `NudgeStreamer__NotRegistered` on every subsequent mint <!-- id: ycn19l1 -->

**Location**: [`NudgeRatchet.sol#L155-L160`](https://github.com/Behodler/yield-claim-nft/blob/d4cc563264c7d57cf4c22e9ba561743484a305cd/src/dispatchers/NudgeRatchet.sol#L155-L160) · `Uniboost.sol:246-250` · `PromotionUniV2_Eth.sol:392-396`

**Description**: Calling `setBatchMinter(new)` / `setRecipient(new)` on an already-live dispatcher **succeeds silently** and arms `NudgeStreamer__NotRegistered()` on every subsequent user mint at that index. The dispatcher has no way to know the new `(batchMinter, token)` pair was never registered, and emits nothing to say so.

Clearing the condition requires two calls in sequence: `setNudgeTokenWhitelist` on the batch minter, **then** `registerStream` on the `NudgeStreamer` — a contract in a **different repository**, potentially behind a different owner key.

**Impact: availability, plus temporarily unsweepable out-of-band funds on `NudgeRatchet`.** No *user* value is at risk: the revert is transaction-atomic, so the user's payment rolls back in full; the failure is loud and visible on the very first mint after the repoint; and `NFTMinterV2`'s `config.disabled` is an owner backstop for taking the index out of service while the registration is arranged. The one value-adjacent consequence is confined to strays already sitting on the contract — see the `NudgeRatchet`-specific rider below.

**Why this stays in the report — and what was correctly suppressed**: the **repoint** sub-case is genuinely surprising (silent arming, cure in another repo), which is the Law-3 keep test. The **deploy-ordering** sub-case — a freshly deployed dispatcher whose stream was never registered — was **correctly suppressed as obvious under Law 3** (SUB-02): it fails on the very first dispatch, before any user traffic exists, so a competent non-malicious owner is not surprised by it. The shipped NatSpec pre-declaring this "NOT an audit finding" is accurate for deploy-ordering and over-broad for repoint.

**Re-weigh trigger**: promote to Medium if the cross-repo `registerStream` key is genuinely held by a different party with a slow process, since the outage then extends well past one transaction.

**Recommendation**: make the repoint atomic with re-registration, or refuse to repoint into an unregistered pair.

```solidity
function setBatchMinter(address newMinter) external onlyOwner {
    require(
        INudgeStreamer(nudgeStreamer).isRegistered(newMinter, primeToken),
        "stream not registered for new minter"
    );
    emit BatchMinterUpdated(batchMinter, newMinter);
    batchMinter = newMinter;
}
```

**`NudgeRatchet`-specific rider (folded in from the withdrawn `M-02`).** Of the three repointable dispatchers, `NudgeRatchet` is the only one with **no `rescueERC20`** (`BalancerPoolerV2`, `Uniboost`, `PromotionUniV2_Eth` and `NudgeRatchetDelayRelease` each have one). While the wedge is armed, the contract's `_dispatch` full-balance sweep — its only outbound path — cannot run, so any **out-of-band** USDC sitting on it (mis-send, airdrop, ops pre-funding) is unsweepable for the duration.

That rider does **not** raise this above Low, and the reason is worth stating because a Medium was drafted on the opposite reading and withdrawn:

- **No user payment can ever be resident.** `NFTMinterV2._executeMint` does the `safeTransferFrom(user, dispatcher, price)` and the `dispatch(...)` **in one transaction** (`src/NFTMinterV2.sol:181-190`); a reverting streamer leg reverts the inbound transfer with it.
- **No successful dispatch leaves a remainder.** The sweep approves the full `bal` and `NudgeStreamer.collectNudge:149` pulls exactly that in a single `safeTransferFrom` — no partial pull.
- **Out-of-band strays are therefore the only residency path, and they are not permanently stranded** — the owner cures the registration and the next dispatch sweeps them, exactly as ledger entry `L-08`'s story-038 closure intended.

Permanent unreachability needs the shared streamer to fail permanently (e.g. a USDC blacklist on the streamer address, PoC `test_T2d`), which is out-of-protocol, unaffected by anything in this repo, and **owner-accepted**: `NudgeStreamer`'s liveness and registration promises are universal across every donor, not a `NudgeRatchet` defect. A `NudgeRatchet`-local `rescueERC20`, a `donationEnabled` degraded mode, and a streamer-side owner rescue were all considered and declined on that basis (see `M-02.md` §5).

**Do not merge** with `L-06` (same `contract:function`, different root-cause class, different fingerprint). The previous "do not merge with `M-02`" instruction is **void** — `M-02` was withdrawn and its surviving substance is the rider above.

---

### [L-02] Disabling donations drops parked USDS from the retry loop; a `setPSM` repoint parks it silently <!-- id: ycn19l2 -->

**Location**: [`BalancerPoolerV2.sol#L287-L295`](https://github.com/Behodler/yield-claim-nft/blob/d4cc563264c7d57cf4c22e9ba561743484a305cd/src/dispatchers/BalancerPoolerV2.sol#L287-L295) · `_psmDonate:345` · `setPSM:227-231`

**Description**: Two independent silent failures on the same value path.

**(a) Donation-disable drops the recovery loop.** The sweep-and-retry that recovers previously parked USDS lives **inside** `if (donationEnabled)`. Disable the donation while USDS is parked and that USDS is never re-swept and never wrapped to sUSDS — it stops being productive collateral and stops contributing to `pool()`. The contract's own NatSpec (`:257-261`) presents re-sweeping as *the* recovery mechanism and **does not note that it is conditional on `donationEnabled`**, so the documentation actively misdirects an operator who disables donations as a mitigation.

**(b) `gem` is read live and `psm` is owner-settable.** `ISkyPSM(psm).gem()` is read fresh on every call. A `setPSM` repoint to a PSM with a different `gem` silently produces a `(batchMinter, gem)` pair that was never registered on the streamer ⇒ `NotRegistered` ⇒ caught ⇒ USDS parks behind **one** `DonationSkipped` event — which, per `L-03`, is now the *only* signal and no longer distinguishes this from any other wiring failure. `BalancerPoolerV2` is the **sole live-gem-read of the four** dispatchers (`PromotionUniV2_Eth` pins USDC as a `constant`, `NudgeRatchet` pins a 6-decimal immutable), so the asymmetry is first-party.

**Impact**: no theft, no permanent loss, no user-facing availability impact — dispatch still succeeds and only the donation is skipped. Recovery via `rescueERC20:437` remains available throughout, and **phUSD backing is not impaired** in either sub-instance (CV-07 / R-06). Held at Low rather than suppressed as an obvious misconfiguration because both failures are **silent and single-event** rather than loud: the Law-3 surprise test is met.

**Recommendation**:
1. Move the parked-USDS sweep-and-retry **outside** the `donationEnabled` guard, or emit a distinct event when a disable leaves USDS parked; correct the NatSpec at `:257-261` to state the dependency.
2. In `setPSM`, validate the new PSM's `gem` against the registered stream pair, or emit the old and new `gem` so a repoint that changes it is visible on-chain.

---

### [L-03] Dust branch went event-silent exactly as `DonationSkipped` became the sole signal for a widened failure set <!-- id: ycn19l3 -->

**Location**: [`BalancerPoolerV2.sol#L329-L350`](https://github.com/Behodler/yield-claim-nft/blob/d4cc563264c7d57cf4c22e9ba561743484a305cd/src/dispatchers/BalancerPoolerV2.sol#L329-L350)

**Cross-reference**: also filed as **F-01-047** in the spec-conformance report — one root cause, two framings, counted once.

**Description**: `require(gemAmt > 0, …)` became `if (gemAmt > 0) { … }`. The old `require` reverted into the caller's `catch`, which emitted `DonationSkipped`; the `if` returns normally and emits **nothing**.

This happened in the same change that **widened** the caught region to cover PSM wiring, streamer wiring, and the streamer's own outbound settle — collapsing several distinct wiring failures into one undifferentiated event, at the moment that event lost its dust case. The documentation was not updated and doubles down, instructing operators to *"watch `DonationSkipped` and the contract's USDS balance."* The same event-silent shape exists **natively** at `Uniboost:246` and `PromotionUniV2_Eth:392`.

The guard itself is **correct and load-bearing** — it keeps `NudgeStreamer__ZeroAmount()` out of the catch — and story-047 bullet 4 explicitly authorises the change. Authorising a change is not the same as disposing of its consequence.

**Why Low rather than pure QA**: `_psmDonate` is atomic, parked USDS is re-swept, and R-06 found **no unbacked-phUSD path in any failure mode** (CV-07 confirms the ≥2:1 cushion) — so on its own this is observability, not value. It is placed at Low because the degraded signal is **load-bearing for L-02**, where a silent value-parking condition is now detectable only through the one event that has been made ambiguous.

**Recommendation**: keep the guard, restore the signal, and differentiate the causes.

```solidity
if (gemAmt > 0) {
    // ... donate
} else {
    emit DonationSkippedDust(usdsAmount);   // distinct from the catch-path event
}
```
…and give the `catch` distinct events (or an included reason) for PSM-wiring vs streamer-wiring vs settle failure, then correct the operator documentation.

---

### [L-04] `Uniboost` accepts an unconstrained prime token and, post-story-046, has no failure isolation <!-- id: ycn19l4 -->

**Location**: [`Uniboost.sol#L246-L251`](https://github.com/Behodler/yield-claim-nft/blob/d4cc563264c7d57cf4c22e9ba561743484a305cd/src/dispatchers/Uniboost.sol#L246-L251) · constructor `:115-130`

**Description**: Two first-party weaknesses on one path.

**(a) Constructor guard asymmetry.** `NudgeRatchet:84` and `NudgeRatchetDelayRelease:76` both enforce `decimals() == 6` on their prime token at construction. `Uniboost` takes `primeToken_` **free, with no guard at all** — an asymmetry against its own siblings, not against some external ideal. This is the whole of the constructor claim: a **sibling-consistency** gap, deliberately *not* a claim about any token behaviour.

**(b) Lost failure isolation.** Post-story-046 the donation branch has **no try/catch**, so a live donation now depends on **two** token movements inside a foreign contract rather than one leaf transfer. The consequence claimed here is narrow and purely structural: a revert anywhere in the donation leg now **reverts the whole dispatch** instead of degrading it, where previously the leaf transfer was isolated. *No claim is made about token semantics* — hooks, transfer callbacks and fee-on-transfer behaviour are **out of scope** for this finding (see Impact).

> **Cross-reference:** sub-part (b) overlapped the degraded-mode recommendation of the withdrawn `M-02`. That recommendation has been **declined** (the mandatory-streamer coupling is accepted as universal), so this sub-part now stands on its own — `BalancerPoolerV2` already *has* the `try/catch` and the `donationEnabled` switch; the issue here is that the switch also disables the recovery sweep.

**Impact**: no exploit at the live USDC topology, and none is asserted. The generic malicious-token vector (KI-2) and the fee-on-transfer claim (KI-3 / the C4 known-invalid rule) were **removed at sanitisation** (SUB-03 / SUB-04) and are **not** reintroduced here in any form. What survives is exactly two things, both independent of token semantics: the first-party constructor guard asymmetry against the two siblings, and the structural loss of revert isolation.

> **MR-02 is NOT closed by this finding.** The cross-stream shared-balance solvency claim remains parked, with two reasoning tiers disagreeing about where the loss lands (whole-streamer solvency vs. only the last claimant of that pair). If MR-02 resolves in favour of the whole-streamer-solvency reading, that is a **separate finding at a higher severity**, not a re-weigh of this one.

**Recommendation**: mirror the siblings' constructor guard, and restore try/catch around the donation branch so a donation failure degrades instead of reverting the dispatch.

```solidity
require(IERC20Metadata(primeToken_).decimals() == 6, "Uniboost: prime token must be 6dp");
```

---

### [L-05] `PromotionUniV2_Eth` burns against the leg output but pools against the whole balance <!-- id: ycn19l5 -->

**Location**: [`PromotionUniV2_Eth.sol#L451-L454`](https://github.com/Behodler/yield-claim-nft/blob/d4cc563264c7d57cf4c22e9ba561743484a305cd/src/dispatchers/PromotionUniV2_Eth.sol#L451-L454) · `_addPhusdPromoLiquidity:463-467`

**Description**: `phusdBurned = phusdAcquired / 2` is computed from Leg A's **return value**, while `_addPhusdPromoLiquidity` sizes its contribution from `balanceOf(address(this))`. Residual or donated phUSD is therefore pooled **without a matching burn**, so the documented *"half burned, halves value-matched"* property holds only for a contract that starts every `pool()` at a zero phUSD balance.

**Impact**: documentation fidelity and a drifting burn ratio, **not a value leak** — `minLP` bounds the outcome. Mild doubt vs. pure QA; held at Low because the deviation is in a value-accounting property the economics documentation asserts, not merely in a code comment.

> **Explicitly NOT folded into L-13 / DEDUP-19-04**, despite the identical whole-balance shape. Different asset (phUSD, not ETH), different consequence (documentation fidelity, not slippage-floor dilution), different fix. Folding it in would silently retire it under an owner `wont-fix` decision that was **never made about it**. It is also distinct from **L-15** (same `contract:function`, different root-cause class).

**Recommendation**: compute both legs from the same basis — either burn against the balance, or pool against the leg output.

```solidity
uint256 phusdForPool = phusdAcquired - phusdBurned;   // not balanceOf(address(this))
```

---

### [L-06] Retiring a batch-minter leaves one stream duration of donated USDC behind in `NudgeStreamer`, invisible and recoverable only by an undocumented route <!-- id: ycn19l6 -->

> **Severity history — the walk-back is deliberately visible.** This was drafted as Tier-2 `ECON-001` ("unreachable forever"), re-drafted as submission `M-03` (Medium, "terminal ordered pair"), and is now **Low**. Both stronger claims were disproved by passing tests, the controlling one being `workspace/yield-claim-nft/test/val-M03-terminal-reversal.t.sol` (`test_terminalPairIsReversibleByRestoringThePointer`), which evacuates 100% of the buffer out of the state the Medium draft called terminal. The ledger entry is **M-06**, fingerprint `25a9ab3e…` — **unchanged**; only the severity moved.

**Location**: [`NudgeRatchet.sol#L96-L112`](https://github.com/Behodler/yield-claim-nft/blob/d4cc563264c7d57cf4c22e9ba561743484a305cd/src/dispatchers/NudgeRatchet.sol#L96-L112) · [`NudgeStreamer.sol#L110-L128`](https://github.com/Behodler/phoenix-nft-staking/blob/d75229df902b5e53e5e6b55a34db76d687fc1a52/src/NudgeStreamer.sol#L110-L128) · [`BatchNFTMinterMultiToken.sol#L437-L451`](https://github.com/Behodler/phoenix-nft-staking/blob/d75229df902b5e53e5e6b55a34db76d687fc1a52/src/BatchNFTMinterMultiToken.sol#L437-L451)

**Description**

Donations from the four first-party dispatchers land in `NudgeStreamer` and are released to the batch-minter over a `duration` window, so normal operation keeps a resident working balance of `B* = ρ·D` on the streamer, keyed to the `(batchMinter, token)` pair. Measured in the PoC at `ρ = 80 USDC/day`, `D = 7 days`, driven by 400 real user mints across 50 simulated days: **559.748325 USDC** resident, 99.955% of the closed form `ρ·D = 560.000000`.

That balance does not follow a migration. When the batch-minter is retired it is left behind on the old pair, and **nothing in the system reports it**: no event fires at retirement, no dispatcher view exposes it, and `NudgeStreamer` has no rescue, no sweep, and no buffer view of its own. The absence is proved rather than merely unobserved — an 8-selector probe (`rescueERC20` ×2 arities, `rescue`, `sweep`, `withdraw`, `emergencyWithdraw`, `recoverERC20`, `skim`) returns false against the streamer while the **byte-identical** battery returns true against two positive controls, `BatchNFTMinterMultiToken` and `NudgeRatchetDelayRelease`, both of which actually move funds. `pullPendingStream` is keyed on `msg.sender`, so a third-party pull is a silent no-op.

**The silent retirement variant.** Of the ordinary tidy-up actions on the old instance, three fail loudly on a subsequent `batchMint` — `setDispatcherIndex(0)` reverts `BatchMint__DispatcherNotConfigured()`, `setTokenMinter(0)` reverts `BatchMint__MinterNotConfigured()`, `pause()` reverts `EnforcedPause()`. `setNudgeTokenWhitelist(USDC, false)` is **completely silent**: `batchMint` succeeds, the NFT mints, the step-3.5 flush loop iterates the now-empty whitelist and skips USDC, the buffer is untouched, and there is no revert and no event. *Caveat: the no-revert result holds for a length-adapted call; a stale `minRewards` array hits `BatchMint__ArrayLengthMismatch`.*

**Recovery is total, but undocumented.** `NudgeStreamer.registerStream` settles the accrued stream to the batch-minter **before** resetting the window (`NudgeStreamer.sol:118-119`). An owner who knows this can call `registerStream(old, token, 1)`, wait one second, call it again, and the whole buffer is pushed onto the retired batch-minter, from where its own `rescueERC20` extracts it — no `batchMint` and no payment required. This route appears in **no doc, runbook or NatSpec**, and `registerStream` has **no call site in any reviewed repo**. Recovery holds in 4/4 single-action retirement sequences and also from the two-action sequence the Medium draft claimed was terminal.

**Migration angle — template precedent, not live default.** `MigrateBatchNFTMinter.s.sol` is **not this repo's script**: it lives in `phoenix-phase-2-staging` @ `c5956a9` and targets the streamer-less single-token `BatchNFTMinter` (grepping it for `NudgeStreamer` returns 0 hits), so run literally it cannot leave anything behind. The concern is forward-looking only: that script recovers the pot as `IERC20(USDC).balanceOf(OLD)`, so a **future** MultiToken migration written to the same template would be structurally blind to the streamer buffer.

**Sizing carries a live-parameter dependence.** The stream `duration` is set nowhere in any reviewed repository — it is a `registerStream` argument, a live ops parameter — and it sizes the exposure linearly. Across the plausible `duration` × batch-cadence grid at the observed ~77.6 USDC per batch, the amount left behind ranges from **~11 USDC** (`D = 1 day`, one batch/week) to **~4,656 USDC** (`D = 30 days`, two batches/day). No point estimate should be quoted without the `duration`. This is tracked as **MR-01**.

**Why Low, and why retained rather than dropped**

The C4 Medium test fails at **both** doors. *Protocol function and availability are unimpaired*: the retired pair's buffer is load-bearing for nothing — minting, the dispatchers and the pot all continue to operate normally. *There is no value leak*: recovery exists in 4/4 single-action sequences **and** from the sequence previously claimed terminal, every step an owner call with no timing race, no counterparty, and no cost beyond gas.

It is **retained rather than dropped** because the whitelist variant's silence means an operator can misplace a four-figure sum with zero feedback — the Law-3 surprise test is met even though the consequence is fully reversible.

**Superseded hypotheses, recorded so they are not re-derived.** PoC arm `6c` observed that after `setNudgeTokenWhitelist(false)` then `setDispatcherIndex(0)`, re-whitelisting reverts on `_resolvePaymentPath`. That is an **ordering artifact of the arm**, not a system property and not a lock: the revert occurs only when re-whitelisting is attempted with the pointer still unset. Restoring `setDispatcherIndex(PAY_INDEX)` **first** — a plain unguarded owner setter — re-enables re-whitelisting and both exits, and the validator test recovers 100% from that state. No state here is terminal, irreversible or unrecoverable.

**Proof of Concept**: `reports/yield-claim-nft/19/pocs/M-03-retirement-strand.patch` — 5 contracts, **11/11 pass**, on the real-stack `Run19Base` (real `NudgeStreamer`, `BatchNFTMinterMultiToken`, `NFTMinterV2`, `NudgeRatchet` and hook; only the ERC20s mocked). Each arm runs a live-path control before rolling back via `vm.snapshotState` so a later failure is attributable to the tidy-up, not the harness; two mutation tests fired. Note that the `M03_MigrationScriptStrandsIt` arm proves the streamer-blind `balanceOf` recovery **pattern** — it is not a replay of a script that would run against this stack.

**Recommendation** (priority order):

1. **Make the value visible** — add a view (or a rescue) to `NudgeStreamer`, since the problem is invisibility rather than inaccessibility:

```solidity
/// @notice Resident buffer for a (batchMinter, token) pair, including
///         accrued-but-unsettled value. Read this before retiring a minter.
function bufferOf(address batchMinter, address token) external view returns (uint256) {
    return streams[batchMinter][token].buffer;
}
```

2. **Document BOTH recovery routes**, including the undocumented back-door: (a) *standard* — repoint the donor, wait `≥ duration`, read `pendingStream(old, token)`, one `batchMint(1, …)` flushes it, `rescueERC20` the proceeds; (b) *back-door* — `registerStream(old, token, 1)`, wait one second, call again, then `rescueERC20`.
3. **Document a safe retirement ordering**: confirm `pendingStream(old, token) == 0` before any tidy-up action, and unwhitelist the token last.
4. **Forward-looking guard** in any future MultiToken migration script:

```solidity
require(INudgeStreamer(STREAMER).pendingStream(OLD_BATCH_MINTER, USDC) == 0, "streamer buffer not drained - see L-06");
```

