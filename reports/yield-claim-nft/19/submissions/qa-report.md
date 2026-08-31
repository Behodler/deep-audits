# QA Report — yield-claim-nft

- **Project:** `yield-claim-nft` @ [`d4cc563`](https://github.com/Behodler/yield-claim-nft/tree/d4cc563264c7d57cf4c22e9ba561743484a305cd) (stories 046 / 047)
- **Run:** `reports/yield-claim-nft/19/`
- **Scope of this document:** every Low and QA finding of run-19. High/Medium findings are submitted individually (`H-01`, `M-01`); Law-2 spec deviations are filed in the spec-conformance report, not here.
- **Re-severity note:** the finding drafted as `M-03` was re-severed **Medium → Low** after two successive walk-backs and now appears here as **`L-06`**. Submission `M-03.md` has been deleted so no stale Medium survives; the ledger entry (**M-06**, fingerprint `25a9ab3e…`) is unchanged apart from severity.
- **Retraction notice (third walk-back of this run):** two drafted QA items, `Q-02` and `Q-03`, have been **withdrawn as invalid** — both targeted **audit-authored test files that do not exist in the sponsor's repository at `d4cc563`**. See **Appendix D**, where the retraction evidence is recorded in full and the surviving audit-harness substance is preserved as tooling hygiene. Their labels are **retired, not reused**; no other label was renumbered.
- **Retraction notice (fourth walk-back of this run):** `M-02` has been **withdrawn as a Medium**, re-severed **Medium → Low**, and **folded into `L-01`** below as the `NudgeRatchet`-specific rider. Its stranding argument is refuted by mint atomicity — `NFTMinterV2._executeMint` transfers the payment and dispatches in one transaction, so no user payment can ever be resident on the dispatcher, and only out-of-band strays can be. The proposed reopen of ledger entry **L-08** (`0b97f155…`) is **DECLINED**; L-08 stays `fixed`. `M-02.md` is retained as the retraction record (it is not a submission). The label `M-02` is **retired, not reused**; no ledger entry was minted for it, because its surviving half was already filed as ledger **L-16** = `L-01` here.

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 6 |
| QA / hardening | 1 |
| Centralization | 0 |
| **Total** | **7** |
| *Withdrawn as invalid (Appendix D)* | *2* |
| *Re-severed Medium → Low (`M-03` → `L-06` as its own label; `M-02` folded into `L-01`, no new label)* | *2* |

**Centralization: none this run.** All 69 Tier-1 `centralization-risk` hits were suppressed under Law 3 (the owner is trusted for *knowing* actions). The three owner footguns this run (`L-06`, `L-01`, `L-02`) are **not** centralization findings — they are non-obvious operational hazards classified by the impact they unlock, and `H-01` is not centralization either because the value is taken by an *unprivileged third party*.

**Label note.** Labels in this document are **run-scoped C4 labels**. The continuing per-project ledger sequence differs and is given per finding; the ledger is keyed on the ledger label, never on the C4 label.

| C4 | Ledger | Fingerprint |
|---|---|---|
| L-01 | L-16 (also absorbs the withdrawn `M-02`; **no** entry minted under `03864c76`) | `b0aa0f58` |
| L-02 | L-17 | `79a2cd4a` |
| L-03 | L-18 | `482cefc3` |
| L-04 | L-19 | `9fdcb0c6` |
| L-05 | L-20 | `1c1e0001` |
| L-06 | M-06 (re-severed Medium → Low; ledger label and fingerprint **unchanged**) | `25a9ab3e` |
| Q-01 | Q-18 | `11d8b865` |
| ~~Q-02~~ | **WITHDRAWN — invalid (Appendix D).** Ledger `Q-17` (`696cc345`) stays at its **original** scope; **no note expansion, no new entry** | — |
| ~~Q-03~~ | **WITHDRAWN — invalid (Appendix D).** **Do not file a ledger entry** | — |

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

---

## Appendix A — REFUTED (recorded so silence is not misread as unchecked)

Each of the following was raised by a scanner or reasoning tier this run and **affirmatively disproved**. They are listed so a later reviewer does not re-derive them, and so their surviving residues are traceable.

| # | Claim | Why refuted | Surviving residue |
|---|---|---|---|
| R-01 | `SA-001` — `buyGem` return value discarded | `buyGem` is **exact-output** by construction: DssLitePsm transfers exactly `gemAmt` and returns the USDS *pulled*. Sizing on the local `gemAmt` is correct, not an assumption. A short-delivering PSM **fails closed** — the streamer's `safeTransferFrom(donor, …, gemAmt)` reverts, `_psmDonate` rolls back atomically, and the catch parks the USDS. | The adjacent live `psm.gem()` read is real ⇒ **L-02(b)** |
| R-02 | `SA-017` — `addLiquidity(…, 0, 0, …)` unguarded | `minLP` is the **stronger** guard: `liquidity = min(amountA·ts/reserveA, amountB·ts/reserveB)`, so ratio skew mechanically reduces LP minted and a fresh-quote `minLP` bounds the loss in the unit that matters. `pool()` is `onlyAuthorizedPooler`; both legs already carry their own floors; the sides are value-matched post-burn. | L-06 / L-15 calculus unchanged; `amountIn` remains MEV-neutral and **L-06 stays Low** |
| R-03 | Residual streamer allowance is exploitable | Exact approve, exact pull, **same call**, rolled back on failure. A residual requires an under-pulling `collectNudge`, reachable only by an owner repointing at a hostile contract — an obvious owner action (Law 3, suppressed). | Style asymmetry ⇒ **Q-01** |
| R-04 | `PATTERN-003` — two-pointer divergence, "donations never flushed" | **Not correct.** `collectNudge` calls `_settle` on *every* donor deposit and pays the accrued stream to the batch minter regardless of the batch minter's own pointer. Step-3.5 is a freshness optimisation, not the delivery mechanism. This is a **one-batch delay, not a strand**; throughput and steady state are unchanged, with no windfall-on-repair and no back-run MEV on fixing the pointer. | Downgraded to informational; the retirement residue is `L-06` |
| R-05 | `PATTERN-001` — caller-side rate drift, "~168 donations permanently resident" | Over-stated on three counts. Cadence is per **batch**, not per mint (a 40-mint batch is one arrival, `dt = 0` between legs). Steady-state throughput is **100%**: `B* = ρ·D` is a *working balance*, and by Little's Law mean latency is exactly `D` — every dollar arrives, one duration late, which is precisely what the streamer exists to provide. "Permanently" is wrong: the rate is frozen at the last deposit (`pullPendingStream` never recomputes — the load-bearing phlimbo-V1 fix), so `accrued` reaches `B` at `elapsed = D` and the `min(accrued, buffer)` cap stops it. **Tier-3 measured:** `delivered + resident == donated` on every row, drains to **exactly 0**, **no rate drift** — the phlimbo-V1 linear-depletion pathology does not reproduce. | Measured-and-clean, not a finding; the only live residue is the retirement edge ⇒ `L-06` |

---

## Appendix B — CLEAN VERDICTS (standing drift-watches)

All four standing drift-watches carried into this run were **independently confirmed clean across three tiers** for this commit range. They neither worsened nor were fixed by stories 046/047; the entries remain open on their own merits where applicable.

| Watch | Verdict | Basis |
|---|---|---|
| **M-03 (ledger, run-11)** — decimal under-mint — *unrelated to this run's former `M-03` draft, now `L-06`* | **CLEAN** (three tiers) | No new conversion on any of the four paths: the amount handed to `collectNudge` is byte-identical to the amount computed one line earlier (`NudgeRatchet:160` `bal`; `Uniboost:250` / `PromotionUniV2_Eth:396` `donationAmount`; `BalancerPoolerV2:347` the same `gemAmt`). No `decimals()` read on the streamer path. `PRECISION = 1e18` cancels exactly; truncation would require `duration > 1e24` seconds. The 3-literal drift-watch can be marked clean for this range. |
| **M-04** — unwired-hook zero-debt | **CLEAN** — does not re-fire | `NudgeRatchet:137-140` still enforces `hookTypeId() == keccak256("NudgeRatchetMintDebtHook.v1")` (verified in source at `d4cc563`), so a missing or wrong hook is a **loud revert**, not a silent zero-debt. `setHook` still rejects zero. Stories 046/047 touched no hook wiring. |
| **L-09 / L-10** — hook-scale | **CLEAN in range** | `hook.onDispatch` still fires with the gross amount (`ATokenDispatcherV2:125`), unchanged; no new hook-side scaling anywhere in the range. |

---

## Appendix C — Automated analysis (4naly3er)

The full automated SAST/gas report is attached as [`4naly3er-report.md`](./4naly3er-report.md) — generated at `d4cc563` over the 34 first-party `src/**.sol` files, using the repo's own `foundry.toml` remappings.

It is kept as a separate appendix **deliberately**: C4 discourages non-critical noise, and none of its output is counted toward this bundle's finding total. Nothing in it rises above the automated-tool baseline, and the items it raises that *do* matter were already promoted into the numbered findings above.

| Category | Issue classes | Instances |
|---|---|---|
| Gas optimizations | 20 | 543 |
| Non-critical | 32 | 518 |
| Low (tool heuristics) | 14 | 90 |
| Medium (tool heuristics) | 1 | 74 |

Reviewer notes on the automated output:

- **Reconcile, do not re-file.** Several tool hits already exist on the ledger and must not be duplicated — all labels below are **ledger** labels from earlier runs, *not* this run's C4 labels: unchecked ERC4626 `deposit` return (ledger `Q-02`), unchecked UniV2 swap returns in `_legB` (ledger `Q-13`), unchecked Balancer settle return (ledger `Q-14`), `block.timestamp` router deadlines (ledger `Q-12`), `nonReentrant` modifier ordering (ledger `Q-05`), and `abi.encodePacked` in `uri()` (ledger `Q-03` — additionally refuted as R-07: there is no hash at that site, the result is a JSON metadata literal that is never hashed or keyed).
- **The tool's sole "Medium" is `M-1` Centralization Risk for trusted owners (74 instances) — not adopted.** Under Law 3 the owner is trusted for *knowing* actions, so "the owner has privileged rights" is not a finding on this project; this is the same class as the 69 Tier-1 `centralization-risk` hits suppressed at sanitization, and is why this bundle reports zero `C-XX` findings. The *non-obvious* owner footguns that survive that filter were promoted to `L-06`, `L-01`, and `L-02` on their own merits.
- **Tool "Low" ≠ audit Low.** The tool's `L-2` (zero-value transfer reverts), `L-5` (`decimals()` not in ERC-20), `L-12` (PUSH0), and `L-14` (multi-address tokens) are heuristic classes with no demonstrated path on this codebase's pinned token topology, and are not adopted as findings.
- **`NC-2` / `L-3` missing zero-address checks (11 instances)** overlap the setter-hygiene theme behind `L-01` and `L-02`; the numbered findings there describe the *consequential* subset (silent arming, silent parking) rather than the whole heuristic list.
- **Semgrep produced zero security findings** this run (197 hits, all gas/style: `use-custom-error-not-require` ×107, `use-short-revert-string` ×55, `non-payable-constructor` ×13, `use-ownable2step` ×7, misc ×15). **Do not read "Semgrep clean" as security coverage** — Solidity security coverage this run rests entirely on Slither + Aderyn plus the reasoning tiers.
- **Tooling note for reproduction**: 4naly3er's third argument is a **scope list**, not a remappings file. `remappings.txt` resolves relative to `basePath`, so `basePath` must point at the submodule root. The run was performed against the writable `workspace/yield-claim-nft` clone (at `d4cc563`); `lib/` is read-only.

---

## Appendix D — WITHDRAWN findings (retraction record)

Two drafted QA items were **pulled as invalid** after adversarial validity review. Both made the same
mistake: they targeted **files authored by this audit**, not files in the sponsor's repository, while
carrying upstream permalinks that implied otherwise. The retraction is recorded here rather than
performed silently, matching the other walk-backs this run (`L-06`'s severity history, and `M-02`'s
withdrawal — its expired-closure basis was itself refuted; see `M-02.md`).

### ~~[Q-02]~~ WITHDRAWN — "the entire test suite did not compile at the audited commit"

**The central claim was false.** Re-verified independently against the pristine upstream tree:

| Check | Result |
|---|---|
| `git archive d4cc563` → clean scratch dir → `forge build --force` | **exit 0**, `Compiling 114 files with Solc 0.8.30` → `Compiler run successful with warnings` — **zero** `Error` / `Compiler run failed` lines |
| `git ls-tree -r --name-only d4cc563 test/` | **23 files**; `Tier3PromotionInvariants.t.sol` is **not among them** |
| Where the file actually lives | `workspace/yield-claim-nft/test/Tier3PromotionInvariants.t.sol` only — an **audit-authored** Tier-3 harness carried over from a prior run |

The build failure was real but occurred **in our harness**, not in the sponsor's release. The sponsor
shipped stories 046/047 with a **compiling test tree**, and the assertion of "zero executable regression
coverage for this release" was unfounded. The finding was additionally ranked *first* in this bundle on
the strength of a blast radius it never had. Corroborating contemporaneous evidence: this run's own
workspace-sync step listed the file among 86 untracked **local** additions and reported that *"source
compiles cleanly with the local Tier-3 files quarantined."*

**Ledger consequence — Q-17 is NOT widened.** Existing entry `Q-17` (`696cc345…`) was filed at
exactly the right scope — *"Tier-3 stateful-fuzz harness calls the pre-story-045 5-arg `pool()`"*, an
**audit-tooling hygiene** note about our own harness. The proposed re-scoping to "the whole suite was
unrunnable" was an accuracy regression and is **rescinded**; `Q-17` stands unmodified, and **no new
ledger entry** is filed.

**Surviving substance (audit-tooling only, not a project finding):** our Tier-3 harness still needs the
6-arg `pool()` arity fix landed durably and updating for the story-046 topology (deploy and register a
real `NudgeStreamer`; use a real batch-minter, not an EOA). Run-19 repaired the arity in the workspace
clone only. That work belongs to `Q-17`, unchanged.

### ~~[Q-03]~~ WITHDRAWN — "fork test reads `MAINNET_RPC_URL` with a silent public-node fallback"

**Correct observation, wrong target.** `test/run19-T5-LegBUnboundedEth.t.sol` is **this run's own PoC
file** — the `run19-` prefix is our naming convention. It is absent from the 23-file upstream `test/`
tree at `d4cc563` and present only under `workspace/yield-claim-nft/test/`. It was nonetheless filed
with an upstream permalink. **It is not a finding against `yield-claim-nft`** and is removed as a
project finding; no ledger entry is created.

**Surviving substance — audit-harness hygiene, to be fixed in our own tooling.** The defect in *our*
test is genuine and worth correcting, because a silent fallback can change fork state underneath a
block-pinned test and quietly alter measured quantities (slippage floors, extracted amounts):

1. This repo's convention supplies the archive endpoint as **`RPC_MAINNET`** (repo-root `.envrc`); the
   PoC reads `MAINNET_RPC_URL`, which is simply unset in the standard environment.
2. On a miss it falls back **silently** to a public node, which does not reliably serve historical
   state for a pinned `FORK_BLOCK` — so a run that should fail loudly on a missing/expired key instead
   produces plausible-looking numbers from different chain state.

```solidity
string memory rpc = vm.envOr("RPC_MAINNET", string(""));
require(bytes(rpc).length > 0, "RPC_MAINNET unset - archive endpoint required for pinned fork");
```

**Process note for future runs.** Both defects share one root cause: a finding was written against a
path under `test/` without first checking that the path exists in `git ls-tree <commit> test/`. Any
finding whose location is a test file must be confirmed present in the audited commit — and carry an
upstream permalink — before it is filed against the project.

---

## Parked, not dropped

Seven items remain in the visible manual-review channel awaiting a human decision at `/ledger` triage: **MR-01** (live stream `duration`, which sizes `L-06`), **MR-02** (cross-stream shared-balance solvency — *not* closed by `L-04`), **MR-03** (scope boundary for `H-01`'s nested-`lib/` root cause), **MR-04** (`StableYieldAccumulator.claim()`'s unbuffered nudge split — a cross-project lead), **MR-05** / **MR-06** (two unadjudicated static hits, both likely benign), and **MR-07** (the ledger-integrity alert behind the `M-02` expired-closure claim — **now adjudicated**: the reopen of ledger `L-08` was declined and the expired-closure basis refuted, see `M-02.md`). None were quality-filtered out; see `manual-review.json`.
