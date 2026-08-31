# Consolidated Findings — yield-claim-nft run-19

- **Project:** `yield-claim-nft` @ `d4cc563` (stories 046 / 047 — four donor dispatchers routed through `INudgeStreamer`)
- **Stage:** deduplication / consolidation (Tier-1 + Tier-2 + Tier-3 + story-faithfulness)
- **Machine-readable:** `consolidated-findings.json`; parked items also in `manual-review.json`
- **Severity is NOT assigned here.** `severity-classifier` owns that. Impact statements below are deliberately unclassified.

## Counts

| | |
|---|---|
| Raw scanner inputs | **61** (25 SA · 8 PATTERN · 5 PATTERN-M · 8 CODE · 6 ECON · 3 F-* · 6 Tier-3) |
| **Consolidated findings out** | **12** (4 security · 3 owner-footgun · 5 QA/hardening) |
| Refuted (recorded, not dropped) | 7 |
| Clean verdicts recorded | 9 |
| Manual-review (parked, visible) | 7 |
| Tool-noise bucketed for QA | 14 groups |

**No silent drops.** Every one of the 61 inputs appears in exactly one bucket. The only outright removals were exact/near duplicates (traceable via `mergedFrom`) and pure style noise, each logged.

---

## Ranked consolidated findings

### Security

#### DEDUP-19-01 — Nudge token that becomes the payment token: the whole nudge pot is swept to an arbitrary `batchMint` caller
`lib/phoenix-nft-staking/.../BatchNFTMinterMultiToken.sol:_snapshotRewards:558` + `batchMint:479-486` (root cause) · first-party contribution: `NudgeRatchet` / `Uniboost` / `PromotionUniV2_Eth`, all USDC-prime donors
**Root-cause class:** config-coupled value misdirection across contracts
**Evidence: Tier 3, PoC** — `Run19_T1_PaymentTokenCollision`, 4/4 pass. 1-wei payment, `count=1`, unprivileged caller extracts **190.0 of a 200 USDC pot**; repeatable (a second call took another 100 USDC); control arm before the repoint extracts **0**.
**Merged from:** CODE-002 · ECON-002 · T1

Two amplifiers Tier-2 did not state, both observed: the mint is funded **out of the pot itself** (step-6 unbounded allowance), so extraction is exactly `pot − mintPrice` and the caller needs no budget; and `_payRewards` never runs (`count 1 < nudgeSize 5` ⇒ `qualifies == false`) — value leaves through the **step-10 dust sweep, which is not gated on `qualifies`**.

*Impact (unclassified):* the entire standing pot, funded by prior minters, transferable to whoever calls `batchMint` next for 1 wei, bypassing the `nudgeSize` gate the pot exists to reward. Permissionless first-come race, repeatable on every refill, continuous while misconfigured. Trigger is one ordinary owner tx on a topology where three of four in-scope dispatchers prime in USDC.

> **Scope caveat (MR-03) — sanitizer/human decision required.** Root-cause lines are in the project's own nested `lib/`. Counter-argument preserved: the collision is created entirely by first-party dispatcher topology. Do **not** silently drop under the OOS rule — if excluded here, re-file on the `phoenix-nft-staking` ledger.

#### DEDUP-19-03 — `NudgeRatchetDelayRelease.release()` lump is 100% back-runnable; the anti-burst invariant is not enforced on the fifth donor
`src/dispatchers/NudgeRatchetDelayRelease.sol:release:107-110`
**Root-cause class:** incomplete invariant coverage / MEV on a cross-contract value handoff
**Evidence: Tier 3, PoC** — `Run19_T4_DelayReleaseBackrun`, 3/3 pass. A 50,000 USDC lump captured **100%** in the same block (no `vm.warp`) by `batchMint(count=5, minRewards=[50000e6])`; the next honest batcher receives **0**. **Contrast arm:** the same 50,000 USDC routed through the streamer by `NudgeRatchet` yields the same-block back-runner **exactly 0** — direct empirical proof the invariant holds on the four streamed donors and not on the fifth.
**Merged from:** CODE-003 · T4 · **cross-ref F-03-046**

*F-03-046 is the Law-2 framing of the same root cause.* It stays in the spec-conformance report and is cross-linked; **one** security finding arises here, not two. Note F-03-046's own instruction: do **not** collapse it into phoenix-nft-staking ledger `858e9e80` — different contract, different repo, different fingerprint.

*Impact (unclassified):* the entire released lump is capturable by a single same-block back-runner; `release()` is `onlyReleaser` and therefore mempool-visible. Loss falls on the honest batchers. Design-coverage gap, not a regression — the finding is that four contracts' NatSpec advertise the property as system-wide while the most exposed path is uncovered.

#### DEDUP-19-02 — `NudgeRatchet`'s mandatory streamer wedges every mint **and** makes resident USDC unreachable; the L-08 fix is intact but its rationale expired
`src/dispatchers/NudgeRatchet.sol:_dispatch:156-161` (rationale `:112-133`) · no `rescueERC20` anywhere on the contract
**Root-cause class:** liveness coupling across a trust boundary + escape-hatch rationale invalidated by a later change
**Evidence: Tier 3, PoC** — `Run19_T2_RatchetWedge`, 4/4 pass, exact revert data:
- `nudgeStreamer == address(0)` (the post-deploy default) ⇒ `Error("NudgeRatchet: nudgeStreamer unset")`
- `(batchMinter, USDC)` unregistered ⇒ `NudgeStreamer__NotRegistered()` (selector-matched)
- `test_T2c` — with 500 USDC resident, an **owner** raw call to `rescueERC20(address,address,uint256)` returns `false` (selector absent); positive control on a freshly deployed `NudgeRatchetDelayRelease` returns `true`. The only forwarding path is itself reverting.
- `test_T2d` (beyond the Tier-2 claim) — blacklisting the **streamer** bricks `NudgeRatchet` *and* `Uniboost`, and **permanently strands the already-buffered pooled funds**: `pullPendingStream` reverts on `_settle`'s outbound transfer and `NudgeStreamer` has no owner rescue.

**Merged from:** CODE-001 · ECON-003 · PATTERN-004 · T2

> **Ledger reconciliation — L-08, EXPIRED CLOSURE (not a regression, not an incomplete fix).**
> L-08 (`0b97f155…`, *"NudgeRatchet has no rescueERC20; out-of-band USDC is permanently stranded"*) is status **`fixed`** via story-038, on the owner's alternative: a full-balance sweep in `_dispatch`. **That code is intact at `d4cc563`** (verified in source). The closure was explicitly judged *"on whether out-of-band USDC becomes recoverable, NOT on literal rescueERC20 presence"*. Story-046 made the sweep's only delivery leg an external cross-repo call that can revert — so the recoverability property the closure rested on no longer holds. **The rationale expired; the patch did not regress.** Do not send reviewers to restore the sweep. Reconcile against L-08 (reopen candidate, human-applied only — see MR-07); do not mint a fresh fingerprint for the strand half.

*Impact (unclassified):* while the streamer path is broken, (1) every user mint at that index reverts — `NudgeRatchet` is the only one of five donors with no try/catch, no `donationSplit`, and a `batchMinter` that cannot be zeroed — and (2) any resident USDC is unreachable by any actor. The trigger set is a strict superset of the pre-change surface and now includes a third-party failure that did not previously exist (a USDC blacklist on the shared streamer).

*The NatSpec pre-declares the wedge "NOT an audit finding".* Per Law 1 the author's say-so does not auto-suppress. That declaration covers the deliberate liveness coupling; it does **not** cover the second-order consequence — the escape hatch was omitted on a rationale that no longer holds — which is the load-bearing half here.

#### DEDUP-19-04 — `PromotionUniV2_Eth._legB` swaps the whole ETH balance, so `minPromoOut` no longer bounds the swap
`src/dispatchers/PromotionUniV2_Eth.sol:_legB:509-512` · `receive():589` · `rescueETH:582-586`
**Root-cause class:** unbounded input to a slippage-floored swap
**Evidence: Tier 3, mainnet-fork PoC** — `Run19_T5_LegBUnboundedEth`, 3/3 pass, fork @ block 25,550,000, live UniV2/Sky PSM/sUSDS/Balancer V3, no mocked AMM, current 6-arg `pool()`.

| arm | stray ETH | outcome (identical `minPromoOut` = 478.315e18, identical 12 ETH sandwich) |
|---|---|---|
| T5b | 0 | `pool()` **REVERTS** `UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT` — the floor does its job |
| T5c | 1.61794 ETH | `pool()` **SUCCEEDS**; sandwicher exits **+0.29677 ETH** |

Floor dilution **11.00×**; `address(disp).balance == 0` after — the entire balance was swapped, not the leg output.
**Merged from:** CODE-007 · T5 · PATTERN-M05 · SA-016 (adjacent)

> **RECONCILE TO L-13 — do not file a new finding.** L-13 (`ac8eadef…`) is **wont-fix** (owner triage 2026-07-18), twin F-01-044 also wont-fix. Quoted basis: *"…a DESIRED FEATURE the owner intends to keep… **Non-theft (Tier-3 INV-4 fork-proved donated ETH only ever reaches protocol-owned LP, never a third party).**"*
> **Re-file basis (material):** the T5 evidence directly contradicts that load-bearing clause. T5c shows a **third party** extracting +0.29677 ETH in a scenario identical but for the stray balance, and T5b shows the honest floor would have rejected that same sandwich. The loss channel is not the donated ETH's *destination* (which is indeed protocol-owned LP) — it is the **11× dilution of the pooler's slippage floor**, which INV-4 never tested. The stale-residual case needs no attacker at all; `rescueETH`'s own NatSpec concedes a partial Leg B leaves resident ETH.
> Recommend surfacing to the owner for re-triage of L-13/F-01-044 with the T5b/T5c differential attached. **Never silently override the owner's decision** — the owner re-decides.

---

### Owner footguns (Law 3 — kept in a separate lane so Law-3 triage applies cleanly)

All three are *non-obvious consequences of routine, well-intentioned owner actions*. None is a malicious-owner vector.

#### DEDUP-19-05 — Retiring a `(batchMinter, token)` stream permanently strands one duration's donations; four routine tidy-up actions each close the only recovery path
All four dispatchers' `setBatchMinter` / `setRecipient` / `setNudgeStreamer`, acting on `NudgeStreamer` buffer state
**Merged from:** ECON-001 · PATTERN-002 · **Tier-3 T3 sizes it empirically**

`NudgeStreamer` has **no owner rescue or sweep** (verified exhaustively against its complete function list). Buffered value leaves only via `_settle`: either a donor calling `collectNudge` for that pair, or the batchMinter calling `pullPendingStream` — which `BatchNFTMinterMultiToken` does in exactly one place, inside `batchMint`. At retirement path 1 stops, and path 2 requires **all** of: not paused · `tokenMinter != 0` · `dispatcherIndex != 0` · token still whitelisted · someone paying for ≥1 real mint. `pause()`, `setTokenMinter(0)`, `setDispatcherIndex(0)`, or unwhitelisting each destroys it — and `_resolvePaymentPath` runs at **step 2, before the step-3.5 flush**, so unsetting either pointer reverts `batchMint` before the flush is reached.

Exposure `B* = ρ·D` — one duration's flow, cadence-independent. T3 measured it: convergence to **99.98%** of one window's inflow at 8 windows, `delivered + resident == donated` on every row, drains to **exactly 0** one window after donations stop. At the observed ~77.6 USDC per 40-batch (15% donation size), that is **11 → 4,656 USDC** across the `D` × cadence grid.

Not hypothetical topology: the existing `MigrateBatchNFTMinter.s.sol` retirement step recovers the pot via `balanceOf(oldBatchMinter)` — **structurally blind to the streamer buffer**, and it predates the streamer.

*Why footgun, not loss:* recovery in the right order is cheap (wait ≥ `D`, one `batchMint(1)` flushes the whole buffer, then `rescueERC20`; ~13 USDS plus gas). The owner must simply **know** — and nothing surfaces the buffer: no event at retirement, no dispatcher view, and the only read is `pendingStream(oldBatchMinter, token)`, which a migration operator has no reason to call.

**Safe-config guidance (belongs in the dispatchers' ops NatSpec):** repoint the donor first → wait ≥ `duration` → read `pendingStream` and confirm → one `batchMint(1, …)` on the old instance → `rescueERC20` → **only then** pause / unset `tokenMinter` / unset `dispatcherIndex` / unwhitelist.

#### DEDUP-19-06 — A repoint (or enabling a dormant donation) silently arms `NudgeStreamer__NotRegistered` on every subsequent mint
`NudgeRatchet:155-160` · `Uniboost:246-250` · `PromotionUniV2_Eth:392-396`
**Merged from:** F-02-046 · PATTERN-004 (non-Ratchet instances) · **Tier-3 Q-17 incidental (fourth independent reproduction, on `PromotionUniV2_Eth`)**

The **deploy-ordering** case is correctly out of scope (fails loudly on the first dispatch, before user traffic — obvious). The **repoint** case is not: `setBatchMinter(new)` / `setRecipient(new)` on a live dispatcher succeeds silently, and clearing the armed revert requires `setNudgeTokenWhitelist` on the batchMinter **then** `registerStream` on a contract in a **different repository** that may not share the owner key. No local view or guard surfaces the missing registration before it bites.

**Deliberately kept separate from DEDUP-19-02.** Same pattern, different consequence and different fix: here it is availability-only, tx-atomic, owner-recoverable, with a `config.disabled` backstop at `NFTMinterV2`; on `NudgeRatchet` it additionally strands funds with no rescue at all. *Same vulnerability type, different attack vector, separate mitigation ⇒ keep both.*

The Q-17 harness reproduction on `PromotionUniV2_Eth` is an **instance** of this finding (same root cause, same fix), not a distinct one. Its harness-side consequence is filed separately as DEDUP-19-12.

*A story cannot pre-declare a hazard out of scope.* The shipped "NOT an audit finding" NatSpec is correct for deploy-ordering and over-broad for repoint. Correct disposition: known, accepted, recorded as an operational hazard with safe-config guidance. **No Law-1 escalation** — no exploit, no value loss, no unrecoverable state.

#### DEDUP-19-07 — `BalancerPoolerV2`: disabling the donation removes parked USDS from the retry loop; `psm.gem()` is read live
`_dispatch:287-295` · `_psmDonate:345` · `setPSM:227-231` · **Merged from:** CODE-005 · PATTERN-008 · ECON-005 (adjacent note)

**(a)** The sweep-and-retry that recovers parked USDS lives **inside** `if (donationEnabled)`. Disable the donation while USDS is parked and that USDS is never re-swept, never wrapped to sUSDS, stops being productive collateral, and does not contribute to `pool()` — recoverable only via `rescueERC20:437`, while the NatSpec presents re-sweeping as *the* recovery mechanism without noting it is conditional.
**(b)** `gem` is read live from `ISkyPSM(psm).gem()` on every call and `psm` is owner-settable. A `setPSM` repoint to a different-gem PSM yields an unregistered pair ⇒ `NotRegistered` ⇒ caught ⇒ USDS parks behind one `DonationSkipped`. Fully recoverable but silent — and per DEDUP-19-08 that event is the only signal. **`BalancerPoolerV2` is the sole live-read of the four** (`PromotionUniV2_Eth` pins USDC `constant`, `NudgeRatchet` pins a 6-dp immutable).

---

### QA / hardening / observability

#### DEDUP-19-12 — The repo's entire test tree did not compile at `d4cc563` (Q-17 escalation)
`test/Tier3PromotionInvariants.t.sol:120` — 5-arg `pool()` against the current 6-arg signature. **Evidence: Tier 3** — `forge build` failed until run-19 repaired the arity in the **workspace clone** (`// run-19: Q-17 bit-rot repair`; `lib/` untouched). Q-17 remains only **partially** addressed: the guided-sequence test now compiles and fails at runtime with `PromotionUniV2_Eth: nudgeStreamer unset` (the harness predates story-046 and uses a plain EOA as `batchMinter`); left unrepaired deliberately since T5 covers the same property against live state.
**Ledger:** Q-17 stays **open**, but its blast radius is larger than the entry states — for the duration of the bit-rot the project had **zero executable regression coverage**; every prior finding's guard test was silently not running. Update the note; do not file new. The repair exists only in `workspace/`, not upstream.

#### DEDUP-19-08 — The dust branch went event-silent exactly as `DonationSkipped` became the sole signal for a wider failure set
`BalancerPoolerV2._psmDonate:329-350` · `_dispatch:287-295` · **Merged from:** CODE-004 · F-01-047 · PATTERN-007 · PATTERN-006 · ECON-004 (observability half)

```solidity
- require(gemAmt > 0, "BalancerPoolerV2: donation dust");
+ if (gemAmt > 0) {
```
The `require` reverted into the caller's `catch`, which emitted `DonationSkipped`. The `if` returns normally and emits **nothing**. Simultaneously the caught region's *contents* widened to PSM + streamer wiring + the streamer's own outbound settle transfer, so every distinct wiring failure collapses into one undifferentiated `DonationSkipped`. The guard itself is **load-bearing and correct** (it keeps `NudgeStreamer__ZeroAmount()` out of the catch); the defect is that the documented observability contract was not updated in the same commit — which doubles down by telling operators to *"watch `DonationSkipped` and the contract's USDS balance"*.

*Impact:* observability, not value — `_psmDonate` is atomic, parked USDS is re-swept, and **phUSD backing is not impaired**. What silently dies is the batch-minter reward while `hook.onDispatch` keeps accruing gross mint-debt. The same event-silent shape exists **natively** at `Uniboost.sol:246` and `PromotionUniV2_Eth.sol:392`.
**Cross-ref:** F-01-047 is the Law-2 framing of the same root cause — stays in spec-conformance, not double-counted. The code change itself is authorised by story-047 bullet 4.

#### DEDUP-19-09 — `Uniboost`'s prime token is unconstrained and now transits a foreign `transferFrom` + `transfer` pair with no failure isolation
`Uniboost._dispatch:246-251` · constructor `:115-130` · **Merged from:** CODE-006 · PATTERN-M02 · PATTERN-M03

`NudgeRatchet` and `NudgeRatchetDelayRelease` enforce `decimals() == 6` at construction; `Uniboost` takes `primeToken_` free with no guard. Post-story-046 the donation branch has no try/catch, so a live donation depends on **two** token movements inside a foreign contract instead of one leaf transfer. It converts three premises from contract-level guarantees into **deployment policy** simultaneously: the read-only-reentrancy "hook-free token" clearance (CV-06), blacklist isolation, and the streamer's shared-balance solvency invariant (**MR-02** — two tiers disagree on where that loss lands; parked, not resolved). No exploit at the live USDC topology. *Remedy: mirror `NudgeRatchet`'s constructor guard, or scope-document the acceptable prime-token set.*

#### DEDUP-19-10 — `PromotionUniV2_Eth` burns against the leg output but pools against the whole balance
`pool:451-454` · `_addPhusdPromoLiquidity:463-467` · **Merged from:** CODE-008
`phusdBurned = phusdAcquired / 2` uses Leg A's return value; `_addPhusdPromoLiquidity` reads `balanceOf(address(this))`. Residual or donated phUSD is pooled without a matching burn, so the documented "half burned, halves value-matched" property holds only for a contract starting each `pool()` at zero. `minLP` bounds the outcome ⇒ documentation-fidelity, not a value leak.
**Kept separate from DEDUP-19-04** despite the identical whole-balance shape: different asset, different consequence, different fix. Folding it into the L-13 wont-fix would silently retire it under an owner decision never made about it.

#### DEDUP-19-11 — The streamer `forceApprove` is the sole unpaired approval in these contracts
`BalancerPoolerV2:346` (asymmetric with the PSM allowance zeroed eleven lines earlier at `:336`), plus `NudgeRatchet:160`, `Uniboost:250`, `PromotionUniV2_Eth:396` · **Merged from:** PATTERN-M01 · ECON cross-cutting note
Every *other* `forceApprove` in these contracts is paired with a zeroing reset. **Exploitability refuted (R-03)** — `collectNudge:149` pulls exactly `amount` in the same call and any failure rolls back atomically. Retained purely as hardening because the safe-today property rests entirely on an **external, cross-repo** contract's implementation detail rather than any local invariant. Cheap fix: pair each approve with a zeroing reset.

---

## REFUTED (recorded so they are not re-derived; residues preserved)

| # | Original | Refuted by | Why | Surviving residue |
|---|---|---|---|---|
| R-01 | SA-001 — `buyGem` return discarded | ECON-005 | `buyGem` is **exact-output** by construction (DssLitePsm transfers exactly `gemAmt`, returns the USDS *pulled*). Sizing on the local `gemAmt` is correct, not an assumption. A short-delivering PSM **fails closed**: the streamer's `safeTransferFrom(donor, …, gemAmt)` reverts, `_psmDonate` rolls back atomically, the catch parks the USDS. | The adjacent **live `psm.gem()` read** is real ⇒ DEDUP-19-07(b) |
| R-02 | SA-017 — `addLiquidity(…,0,0,…)` | ECON-006 | `minLP` is the **stronger** guard: `liquidity = min(amountA·ts/reserveA, amountB·ts/reserveB)`, so ratio skew mechanically reduces LP minted and a fresh-quote `minLP` bounds the loss in the unit that matters. `pool()` is `onlyAuthorizedPooler`; the legs already carry their own floors; the sides are value-matched post-burn. | **L-06 / L-15 calculus unchanged** — `amountIn` still MEV-neutral, L-06 stays Low; if anything better supported by the 6th param |
| R-03 | PATTERN-M01 / profiling anomaly 3 — residual streamer allowance | code-scan Lead 4 | Exact approve, exact pull, **same call**; rolled back on failure. A residual needs an under-pulling `collectNudge`, reachable only by an owner repointing at a hostile contract — an obvious owner action (Law 3, suppress). | Style asymmetry ⇒ hardening item DEDUP-19-11 |
| R-04 | PATTERN-003 — two-pointer divergence, "never flushed" | ECON + code-scan Lead 5 | **Not correct.** `collectNudge` calls `_settle` on *every* donor deposit and pays the accrued stream to the batchMinter regardless of the batchMinter's own pointer. Step-3.5 is a freshness optimisation, not the delivery mechanism. **One-batch delay, not a strand**; throughput and steady state unchanged; no windfall-on-repair and no back-run MEV on fixing the pointer. | Downgraded to **informational**; retirement residue ⇒ DEDUP-19-05 |
| R-05 | PATTERN-001 — caller-side rate-drift, "~168 donations permanently resident" | ECON §1 (closed form) **and** Tier-3 T3 (measured) | Over-stated on three counts. Cadence is per **batch** not per mint (a 40-batch is one arrival, `dt=0` between legs). Steady-state throughput is **100%**: `B* = ρ·D` is a *working balance*, and by Little's Law mean latency is exactly `D` — every dollar arrives, one duration late, which is the mechanism the streamer exists to provide. "Permanently" is wrong: the rate is frozen at the last deposit (`pullPendingStream` never recomputes — the load-bearing phlimbo-V1 fix), so `accrued` reaches `B` at `elapsed = D` and the `min(accrued, buffer)` cap stops it. **T3 measured:** `delivered + resident == donated` every row; drains to **exactly 0**; **no rate drift** — the phlimbo-V1 linear-depletion pathology does not reproduce. | Record as **measured-and-clean, not a finding**. Only live residue is the retirement edge ⇒ DEDUP-19-05 |
| R-06 | code-scan Lead 3 / ECON-004 — accrued-debt vs delivered-value gap | ECON-004 | phUSD backing not impaired in any failure mode; value never leaves the system (streamed = relocation; caught = USDS stays on the pooler; dust = stays put). Worst case bounded by the 15% donation size ⇒ well inside the ≥2:1 cushion. | Observability half is real ⇒ DEDUP-19-08. **No unbacked-phUSD path found.** |
| R-07 | SA-013 — `abi.encodePacked` hash collision, `NFTMinterV2:263` | deduplicator source read | **There is no hash.** The site is `string(abi.encodePacked(…))` building a JSON metadata literal for `uri()`, the dynamic strings are separated by non-empty JSON delimiters, and the result is never hashed or keyed. Detector class does not apply. | Also an **exact duplicate** of ledger **Q-03** (qa-bundled). Reconcile; do not re-file. |

---

## CLEAN VERDICTS (so standing watches can be updated)

| # | Class | Verdict | Basis |
|---|---|---|---|
| CV-01 | **M-03 decimal under-mint** | **CLEAN** — confirmed by three tiers | No new conversion on any of the four paths: the amount handed to `collectNudge` is byte-identical to the amount computed one line earlier (`NudgeRatchet:160` `bal`; `Uniboost:250` / `PromoEth:396` `donationAmount`; `BalancerPoolerV2:347` the same `gemAmt`). No `decimals()` read on the streamer path. `PRECISION = 1e18` cancels exactly; truncation would need `duration > 1e24` s. **M-03 drift-watch (3 literals) can be marked clean for this range.** |
| CV-02 | **M-04 unwired-hook zero-debt** | **CLEAN** — does not re-fire | `NudgeRatchet:137-140` still enforces `hookTypeId() == keccak256("NudgeRatchetMintDebtHook.v1")` (verified in source at `d4cc563`) ⇒ a missing/wrong hook is a **loud revert**, not silent zero-debt. `setHook` still rejects zero. Stories 046/047 touched no hook wiring. |
| CV-03 | **L-09 / L-10 hook-scale** | **CLEAN in range** | `hook.onDispatch` still fires with the gross amount (`ATokenDispatcherV2:125`), unchanged; no new hook-side scaling anywhere. Entries stay open on their own merits — this range neither worsens nor fixes them. |
| CV-04 | `REWARD-ACCRUAL-ORDER` (phlimbo-port anchor) | **CLEAN** | `collectNudge:146` settles at the **old** rate before the buffer mutation (`:150`) and before the rate recompute (`:153`); `registerStream` likewise. phoenix-nft-staking run-24's "port is faithful" holds against source and is confirmed empirically by T3. |
| CV-05 | `ROUNDING-DIRECTION` (standing watch) | **CLEAN** | Every rounding decision floors *against* the recipient and *for* the protocol (`gemAmt`, `usdsSpent`, `donationAmount`, `rewardPerSecond`, `accrued` + cap). No asymmetric pair, no profitable loop. These are one-way donors with **no redemption leg**, so the round-trip drain has no surface. Also closes PATTERN-M04. |
| CV-06 | **Reentrancy, all classes** | **CLEAN** — full checklist walked | Classic / cross-contract / cross-function all covered by the contract-wide OZ guard (so `pool()` shares the lock). Read-only cleared: **no inbound callback window at all** — USDC/USDS have no transfer hooks. ERC1155 receive cleared non-trivially (the live unbounded allowance is not exploitable — `_executeMint:183` always pulls via `safeTransferFrom(msg.sender, …)`, and the batcher's payout is snapshotted pre-loop). ERC777 cleared — no ERC-1820 registration on any of the three parties. **Stated precondition:** the read-only clearance rests on the token being hook-free — pinned for three of four donors, deployment policy for `Uniboost` (DEDUP-19-09). |
| CV-07 | **DEDUP-001 phUSD over-backing cushion** | **HOLDS** under the new quiet-skip surface | Worst case bounded by the 15% `batchDonationSize`; the other 85% is pooled regardless. Comfortably inside ≥2:1. Suppression stands; no re-escalation. |
| CV-08 | **donate-forward / self-refund** (phStaging story-057) | **STRENGTHENED, not weakened** | Step-3.5 flush precedes the pre-loop snapshot, and a batcher's own donations enter the streamer only during the step-7 loop at `elapsed == 0` — a batch cannot settle its own in-loop donations back to itself. T3: claimable-right-now is always ≈ one donation (~8.65 USDC) regardless of cadence or buffer size. |
| CV-09 | **PATTERN-005 mitigation framing** | **CORRECTED: a rate cap — delay, not denial** | Not a cap on what one caller can *eventually* take (the batchMinter flushes then snapshots its whole balance, winner-take-all), but a hard cap on the **rate**: a flush yields `min(elapsed/D, 1)·buffer`. Story-faithfulness independently confirms **no** NatSpec, story line, or CLAUDE.md text claims it is a value cap — the code was not written under a wrong model, so no Law-2 defect. **Do not read this range as closing any pre-existing phoenix-nft-staking nudge over-funding / aggregate-pot finding.** |

---

## MANUAL REVIEW (parked, visible — mirrored in `manual-review.json`)

| # | Item | Reason parked | Ask of human |
|---|---|---|---|
| MR-01 | Mainnet stream `duration` is unset in every reviewed repo | Unknown live ops parameter that **sizes** DEDUP-19-05 (11 → 4,656 USDC across the grid); linearly scaling | Supply the live `duration` + batch cadence; pin `duration` in the deploy runbook |
| MR-02 | Cross-stream FoT contamination via `Uniboost`'s unrestricted prime | **Two tiers disagree** on where the loss lands (whole-streamer solvency vs the last claimant of that pair). Generic FoT stays C4-invalid; the shared-balance solvency claim is a different claim | Does it need its own entry, or does DEDUP-19-09's constructor guard close it? |
| MR-03 | DEDUP-19-01's root-cause lines sit in the nested `lib/` | Scope-boundary call, not a validity question (PoC'd) | Report against `yield-claim-nft` as an integration hazard, or transfer to the `phoenix-nft-staking` ledger. Disappearing is not an option |
| MR-04 | `StableYieldAccumulator.claim()`'s 30% `nudgeSplit` still pays the batch-minter **directly, unbuffered** | Cross-project — the anti-burst throttle covers one of two funding sources; a `claim()`-funded spike is still instantaneously capturable | Route as a carryover lead to the `stable-yield-accumulator` ledger, or accept as intended |
| MR-05 | SA-005 divide-before-multiply, `_psmDonate :322→:331` | Static hit no reasoning tier adjudicated directly; documented as an intentional protocol-favouring floor and consistent with CV-05 | Confirm the intentional-floor reading, then close |
| MR-06 | SA-006 strict balance equality, `getIdealBPT:407` | Static hit no reasoning tier adjudicated; source read shows a benign early return in an external query helper | Confirm as noise, bundle to QA |
| MR-07 | **Ledger-integrity alert: L-08 `fixed` on an expired rationale** | The patch is intact; the closure basis is not. Status changes are **human-applied only** | Apply or decline an L-08 reopen via `/ledger`. `finding-manager` must **append**, not clobber, the existing `fixNote` |

---

## TOOL NOISE — bucketed for the QA / 4naly3er report (not dropped)

Several already exist on the ledger — **reconcile, do not re-file**.

| SA ids | Item | Existing ledger entry |
|---|---|---|
| SA-002 | Unchecked ERC4626 `deposit` return, `BalancerPoolerV2._dispatch:282` | **Q-02** (qa-bundled) |
| SA-003, SA-004 | Unchecked external returns, `pool:361` / `unlockCallback:394-395` | — |
| SA-014 | Unchecked external returns ×3, `Uniboost.pool:276/289/302` (swaps *do* carry `minPairOut`/`minTargetOut`/`minLP`) | — |
| SA-016 | Unchecked UniV2 swap returns, `PromoEth._legB:504/510` | **Q-13** (qa-bundled) |
| SA-018 | Unchecked Balancer settle return, `unlockCallback:561-562` | **Q-14** (qa-bundled) |
| SA-015, SA-025 | `block.timestamp` deadlines on router calls | **Q-12** (qa-bundled) — retained rather than filtered because this protocol is time-driven |
| SA-024 | `nonReentrant` not the first modifier (3 sites) | **Q-05** (open) |
| SA-019 | Raw ETH `.call{value:}` in `rescueETH:584` — value-transfer carve-out, owner-only | — |
| SA-023 | State change without event, `:182` | — (borderline; kept for the DEDUP-19-08 observability theme) |
| SA-007, SA-008, SA-021, SA-022 | `reentrancy-events` (emit after external call) | — informational only; no vector (CV-06) |
| SA-009 – SA-012 | `state-change-after-external-call` in **constructors** (Aderyn HIGH) — four false positives | — retained at low confidence per no-silent-drop |
| SA-020 | External call in a loop, `MultiPooler.pool:60` | — bounded, `onlyAuthorizedPooler` |
| SA-013 | `abi.encodePacked` in `uri():263` | **Q-03** — exact duplicate **and** refuted (R-07). Do not re-file |
| Semgrep ×197 | `use-custom-error-not-require` (107), `use-short-revert-string` (55), `non-payable-constructor` (13), `use-ownable2step` (7), misc (15) | 4naly3er bundle. **Semgrep produced zero security findings** — Solidity security coverage this run rests entirely on Slither + Aderyn; do not read "Semgrep clean" as coverage |

**Filtered upstream at Tier 1 (229 raw hits), recorded for auditability:** naming-convention · solc-version/unspecific-pragma · assembly · missing-zero-check (22) · unused-state · dead-code · missing-inheritance · PUSH0 · literal-instead-of-constant · modifier-invoked-once · unused-import · public-fn-not-used-internally · large-numeric-literal · empty-block · **centralization-risk (69 — suppressed per Law 3, owner trusted)** · all 197 Semgrep gas/style.
