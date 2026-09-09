# Tier-2 Code Interaction Scan — yield-claim-nft run-19

- Commit: `d4cc563`
- Scope: `src/dispatchers/{NudgeRatchet,Uniboost,PromotionUniV2_Eth,BalancerPoolerV2,NudgeRatchetDelayRelease,ATokenDispatcherV2}.sol`, `src/NFTMinterV2.sol`
- Cross-repo read-only context: `lib/phoenix-nft-staking/src/{NudgeStreamer,BatchNFTMinterMultiToken}.sol`
- Change under review: stories 046/047 — four donor dispatchers replaced `safeTransfer(sink, amount)`
  with `forceApprove(streamer, amount)` + `INudgeStreamer.collectNudge(sink, token, amount)`.

Severity is deliberately NOT assigned (severity-classifier owns that). Impact is stated plainly.

---

## Findings

### CODE-001 — NudgeRatchet: mandatory streamer wedges the mint AND strands funds, because the missing `rescueERC20` was justified by a property story-046 invalidated

- Contract/function/line: `src/dispatchers/NudgeRatchet.sol:_dispatch:156-161`; rationale at `:112-133`
- Root cause class: liveness-coupling across a trust boundary + invalidated escape-hatch rationale
- Confidence: high (code-verified)

`_dispatch` is unconditional — `batchMinter` cannot be zeroed (`:82`, `:97`), there is no
`donationSplit`, and there is no `try/catch`. Any non-zero balance therefore forces the streamer
path, and any revert inside `collectNudge` propagates through `ATokenDispatcherV2.dispatch:124`
to `NFTMinterV2._executeMint:191` and reverts the whole user mint.

This is the only donor of the four with **no disable switch** and **no `rescueERC20`**
(verified: `BalancerPoolerV2:437`, `Uniboost:338`, `PromotionUniV2_Eth:575`,
`NudgeRatchetDelayRelease:118` all have one; `NudgeRatchet` does not).

The two facts compound. The contract's own NatSpec (`:114-120`) justifies the absent rescue hatch
with a "self-cleaning" argument: *"any USDC sent here out-of-band is forwarded on the next
dispatch, so no rescueERC20 escape hatch is needed."* Before story-046 that argument held on a
single leaf `safeTransfer`. It is now conditional on the state of a **different contract in a
different repository with a potentially different owner key**. While the streamer path is broken:

1. every mint through this dispatcher index reverts, and
2. any USDC resident on the ratchet is unreachable by **any** actor — no rescue, and the only
   forwarding path is the dispatch that is itself reverting.

Trigger set (superset of the pre-change `safeTransfer` failure surface):
- `nudgeStreamer == address(0)` — the post-deploy default (setter-only, not a constructor arg).
  Re-armed silently by `NFTMinterV2.replaceDispatcher` swapping a fresh NudgeRatchet into a live index.
- `NudgeStreamer__NotRegistered()` — `streams[batchMinter][USDC].duration == 0`. Re-armed by
  `setBatchMinter` (`:96`) to any address without a pre-registered stream. `registerStream` is
  `onlyOwner` **on the streamer**, and itself requires `batchMinter.isNudgeToken(token)` — so
  recovery spans three contracts and up to three owner keys.
- **NEW third-party trigger:** `NudgeStreamer._settle`'s *outbound* `safeTransfer(batchMinter, settled)`
  (`NudgeStreamer.sol:187`) now runs inside the donor's dispatch. A USDC blacklist on **the streamer**
  is a failure point that did not exist pre-change, and the streamer holds pooled buffers for
  multiple donors, so one blacklisting bricks every donor at once.

Footgun test (Law 3): a competent non-malicious owner running one runbook across four
structurally-identical-looking donors would be surprised that three of them degrade gracefully and
the fourth halts minting. The NatSpec pre-declares the wedge "NOT an audit finding"; that
declaration covers the *deliberate* liveness coupling, but it does not cover the second-order
consequence — that the rescue hatch was omitted on a rationale that no longer holds. That part is
reportable on its merits.

Suggested remedies (non-binding): add `rescueERC20`; or add a disable switch mirroring the other
three; or accept the wedge but restore the escape hatch.

---

### CODE-002 — A whitelisted nudge token that becomes the payment token converts the entire accumulated nudge pot into an ungated dust refund to the next `batchMint` caller

- Contract/function/line (root cause, cross-repo): `lib/phoenix-nft-staking/src/BatchNFTMinterMultiToken.sol:_snapshotRewards:558` and `batchMint:479-486`
- First-party contribution: `src/dispatchers/{NudgeRatchet,Uniboost,PromotionUniV2_Eth}.sol` are all USDC-prime donors feeding a USDC stream
- Root cause class: config-coupled value misdirection across contracts
- Confidence: high (code-verified); root cause line is out-of-repo — filed as an integration hazard

Preconditions, all reachable by a single owner transaction on the batchMinter:
1. `USDC` is on the batchMinter's nudge whitelist (required — `NudgeStreamer.registerStream:112`
   will not register a pair unless `isNudgeToken(token)` is true).
2. The owner later calls `setDispatcherIndex` (or `setTokenMinter`) so `_resolvePaymentPath:509`
   derives `USDC` as the payment token. **This is not exotic**: three of the four donors in this
   repo (`NudgeRatchet`, `Uniboost`, `PromotionUniV2_Eth`) are USDC-prime dispatchers, so pinning
   the batchMinter to any of them triggers it. `setNudgeTokenWhitelist` only checks the collision
   at *add* time (`:253-256`); nothing re-validates on repoint.

Failure chain:
- `_snapshotRewards:558` `continue`s the entry → `snapshot[i] == 0` → `_payRewards` never pays it.
  The NatSpec calls this "keeps batchMint live instead of bricking it".
- But `batchMint` step 3.5 (`:445-451`) still calls `pullPendingStream(USDC)`, and the four donors
  still call `collectNudge(batchMinter, USDC, amount)` on every mint — the stream is still
  registered, so donations keep flowing in and keep settling onto the batchMinter.
- The accumulated USDC is now indistinguishable from payment-token residue, and step 10
  (`:480-486`) sweeps **`paymentToken.balanceOf(address(this))` in full** to `msg.sender` whenever
  it exceeds `DUST_THRESHOLD = 1e6` (1 USDC).

Impact: the whole accumulated nudge pot is handed to whoever calls `batchMint` next. The sweep is
**not gated on `qualifies`** (`:434`) — `count = 1` with a 1-wei payment suffices, so the
`nudgeSize` earn-your-nudge gate is bypassed entirely, and the pot is captured as a "refund" rather
than paid to `recipient`. It is a permissionless first-come race, repeatable every time the pot
refills.

Not created by stories 046/047 (the pre-change `safeTransfer` landed USDC on the batchMinter the
same way), but the change makes the quiet-accumulation window structurally larger and the funds
harder to intercept: value now transits a streamer with **no owner rescue of its own**
(`NudgeStreamer.sol` has no sweep), so the owner's only remedy is `BatchNFTMinterMultiToken.rescueERC20`
racing against batchMint callers, and only for the portion already settled.

---

### CODE-003 — The anti-burst invariant introduced by stories 046/047 is not enforced on the fifth donor path; `NudgeRatchetDelayRelease.release()` still lump-transfers and is back-runnable

- Contract/function/line: `src/dispatchers/NudgeRatchetDelayRelease.sol:release:107-110`
- Root cause class: incomplete invariant coverage / MEV on a cross-contract value handoff
- Confidence: medium-high (code-verified; assumes DelayRelease and the streamed donors share a batchMinter, which the identical `batchMinter` field and 6-dp USDC guard strongly imply)

`NudgeStreamer`'s stated purpose (`NudgeStreamer.sol:20-23`) is that *"whoever calls `batchMint`
right after a burst can no longer capture a disproportionate share of the reward pot."* Stories
046/047 route four donors through it. `NudgeRatchetDelayRelease` — the one donor whose entire
design is to emit **discrete admin-timed lumps** — was left on a direct
`IERC20(_token).safeTransfer(batchMinter, amount)`.

Attack: `release(amount)` is `onlyReleaser` and therefore an identifiable, publicly-visible
mempool transaction. Because `batchMint` snapshots the pot **pre-loop** (`:453`), a searcher
back-runs `release()` with a qualifying `batchMint` in the same block and captures the entire lump
— exactly the burst-capture the streamer was built to prevent. The value at risk is the whole
released amount, and the intended recipients are the honest batchers who would otherwise have
shared it over the stream window.

Note this is a *design-coverage* gap, not a regression: DelayRelease behaves as it always did. The
finding is that the new invariant is advertised as system-wide in four contracts' NatSpec while the
one path most exposed to it is uncovered. A reviewer reading only the four changed files would
conclude the property holds.

---

### CODE-004 — BalancerPoolerV2's dust branch went event-silent while `DonationSkipped` became the sole signal for a much wider failure set

- Contract/function/line: `src/dispatchers/BalancerPoolerV2.sol:_psmDonate:329-350` (dust branch), `_dispatch:287-295` (catch)
- Root cause class: observability regression / quiet misconfiguration
- Confidence: high (code-verified against the pre-change source)

Story-047 replaced `require(gemAmt > 0, "donation dust")` with `if (gemAmt > 0) { ... }`. The
`require` used to revert into the caller's `catch`, which emitted `DonationSkipped(remainingUSDS)`.
The `if` returns successfully and emits **nothing** — neither `BatchDonatedViaPSM` nor
`DonationSkipped`. The contract's own NatSpec (`:56-58`) still directs operators to *"watch
`DonationSkipped` and the contract's USDS balance"*, and that instruction is now wrong for the dust
branch.

Simultaneously the caught region widened from PSM-only to PSM + streamer wiring + the streamer's
own outbound settle transfer (`:52-54` enumerates it). So `DonationSkipped` is now the only signal
for a strictly larger set of failures at the exact moment it stopped covering one of them.

Impact is observability, not value: `_psmDonate` is atomic, so nothing is stranded mid-route, and
the parked USDS is re-swept by the next successful dispatch. But a streamer misconfiguration can
run indefinitely while the nudge incentive is dead and `hook.onDispatch` keeps accruing mint-debt
on the gross amount. Note that the phUSD backing is *not* impaired — the un-donated USDS stays on
the pooler and is still protocol-held collateral; what silently dies is the batch-minter reward.

---

### CODE-005 — Disabling the donation, or repointing `setPSM` to a different-gem PSM, moves parked USDS out of the automatic retry loop

- Contract/function/line: `src/dispatchers/BalancerPoolerV2.sol:_dispatch:287-295`, `_psmDonate:345`, `setPSM:227-231`
- Root cause class: config-coupling / recoverability
- Confidence: high

Two related paths:

(a) The sweep-and-retry that recovers parked USDS lives **inside** `if (donationEnabled)` (`:287`).
If the owner disables the donation (`setBatchDonationSize(0)` or `setBatchMinter(0)`) while USDS is
parked from earlier skips, that USDS is never re-swept and never wrapped into sUSDS, so it stops
being productive collateral and does not contribute to `pool()`. It is recoverable only via
`rescueERC20:437`, which the owner must know to call — the NatSpec presents re-sweeping as *the*
recovery mechanism (`:257-261`) without noting it is conditional on the donation staying enabled.

(b) `gem` is read live from `ISkyPSM(psm).gem()` on every call (`:345`), not pinned. A `setPSM`
repoint to a PSM with a different gem yields an unregistered `(batchMinter, newGem)` pair →
`NudgeStreamer__NotRegistered` → caught → USDS parks quietly with only a `DonationSkipped` event.
Fully recoverable (repoint back, or register the new pair), but silent until someone reads the
event stream — and per CODE-004 the event stream is the only signal.

---

### CODE-006 — Uniboost's prime token is unconstrained and now transits a third-party contract's `transferFrom` + `transfer` pair with no failure isolation

- Contract/function/line: `src/dispatchers/Uniboost.sol:_dispatch:246-251`; constructor `:115-130` (no decimal/standard guard)
- Root cause class: widened trust surface on an unvalidated token
- Confidence: medium

`NudgeRatchet` and `NudgeRatchetDelayRelease` both enforce `decimals() == 6` at construction.
`Uniboost` takes `primeToken_` as a free constructor argument with no guard at all. Post-story-046
the donation branch has no `try/catch`, so on a live donation the mint's success now depends on
**two** token movements inside a foreign contract — `safeTransferFrom(Uniboost → streamer)` and
`safeTransfer(streamer → recipient)` (`NudgeStreamer.sol:149,187`) — instead of one leaf transfer.

Consequences for a non-plain prime token: a blacklisting token that blocks either the streamer or
the recipient bricks every mint through this dispatcher; a fee-on-transfer token makes
`collectNudge`'s `buffer += amount` over-state the held balance for that stream (though
`_accrued` caps at `buffer`, so the shortfall lands on the *last* claimant of that pair, not on
solvency of other pairs). FoT is a C4 known-invalid class and is noted only for completeness; the
in-scope point is the missing deploy-time guard plus the removal of failure isolation, on the one
donor whose token identity is not pinned.

Remedy: mirror NudgeRatchet's constructor guard, or scope-document the acceptable prime-token set.

---

### CODE-007 — PromotionUniV2_Eth Leg B swaps the contract's whole ETH balance, so the caller-supplied slippage floors do not bound the swap (run-17 L-13 confirmed still live after the 6-arg `pool()` rework)

- Contract/function/line: `src/dispatchers/PromotionUniV2_Eth.sol:_legB:509-512`; `receive():589`
- Root cause class: unbounded input to a slippage-floored swap
- Confidence: high (code-verified)

`_legB` computes `uint256 ethBal = address(this).balance;` and swaps **all of it**, not the ETH the
preceding `swapExactTokensForETH` produced. `receive()` is open to anyone, and `rescueETH`'s own
NatSpec (`:581`) acknowledges that a *"failed/partial Leg B"* can leave resident ETH.

`minPromoOut` is calibrated off-chain by the authorized pooler for the expected 30%-leg ETH.
Resident or third-party-donated ETH inflates the swapped amount without inflating the floor, so the
floor stops being a meaningful bound on that swap and the trade is exposed to a larger sandwich
than the pooler priced. A griefer must fund the excess themselves (so this is cost-bearing, not
free), but a *stale* residual from a prior partial pool reaches the same state with no attacker at
all. Also note `rescueETH:582-586` is the only way to remove residual ETH, and it competes with the
next `pool()`.

Broad first-pass note: this contract was absent from the cached scope array and has now had a full
read. Aside from this item and CODE-008, the structure holds up — `unlockCallback:547` is
vault-gated, `withdrawWBTC` is correctly `onlyInsurer` with `insurer` starting at zero,
`rescueERC20:577` correctly excludes WBTC, and the constructor's infinite phUSD self-allowance
(`:218`) is not reachable as a drain (no function on the contract performs a
`phUSD.transferFrom(address(this), <caller-controlled>, x)`).

---

### CODE-008 — PromotionUniV2_Eth burns against the leg output but pools against the whole balance, so residual or donated phUSD drifts the 30/30 value match

- Contract/function/line: `src/dispatchers/PromotionUniV2_Eth.sol:pool:451-454`, `_addPhusdPromoLiquidity:463-467`
- Root cause class: accounting basis mismatch
- Confidence: high (code-verified); impact small

`phusdBurned = phusdAcquired / 2` uses Leg A's return value, but `_addPhusdPromoLiquidity` reads
`IERC20(phUSD).balanceOf(address(this))` and `IERC20(promotionToken).balanceOf(address(this))`.
Any phUSD resident from a prior `pool()`'s router refund — or donated by a third party — is pooled
without a matching burn, so the "half burned, halves value-matched" property documented at
`:448-450` holds only for a contract that starts each `pool()` at a zero phUSD balance. Same for
donated promotion token on the other side. `minLP` bounds the outcome, so this is an accounting /
documentation-fidelity issue rather than a value leak.

---

## Hypotheses examined and REFUTED (recorded so they are not re-derived)

**Lead 4 — residual streamer allowance. REFUTED as exploitable; untidy only.**
All four donors `forceApprove(streamer, exactAmount)` and `collectNudge` pulls exactly that amount
via `safeTransferFrom(msg.sender, address(this), amount)` (`NudgeStreamer.sol:149`) in the same
call, so the standing allowance is zero on success. On any failure the approve is rolled back —
atomically inside `_psmDonate`'s try/catch for BalancerPoolerV2, and by the reverting mint for the
other three. A non-zero residual requires an under-pulling `collectNudge` implementation, which
only an owner repointing `nudgeStreamer` at a hostile contract could produce; that is an obvious
owner action (Law 3, suppress). The asymmetry with the adjacent `forceApprove(psm, 0)` is a style
inconsistency, not a vector. No finding.

**Lead 5 — batchMinter's own `nudgeStreamer` pointer unset ⇒ funds never flush. LARGELY REFUTED.**
`collectNudge` calls `_settle` on **every** donor deposit (`NudgeStreamer.sol:146`), and `_settle`
transfers the accrued amount to the batchMinter regardless of whether the batchMinter knows about
the streamer. So with `BatchNFTMinterMultiToken.nudgeStreamer == 0` the step-3.5 flush (`:445-451`)
is skipped but the funds still arrive — they simply land *after* the current batch's pre-loop
snapshot instead of before it. Net effect is a **one-batch delay**, not a strand. A true strand
requires donor dispatches to cease entirely *and* the pointer to stay zero, and is cured by one
`setNudgeStreamer` call. Downgraded to an ops note, not filed as a finding.

**Lead 3 — accrued mint-debt vs delivered value gap. PARTIALLY REFUTED.**
`hook.onDispatch` fires on the gross `amount` (`ATokenDispatcherV2:125`) whether or not the donation
lands, but the un-donated USDS **stays on the pooler**, so phUSD backing is not impaired — the
protocol still holds the asset, just as raw USDS rather than sUSDS or a nudge payout. The real gap
is incentive availability, folded into CODE-004/CODE-005. No unbacked-phUSD path found.

**M-03 decimal under-mint class — CLEAN, independently confirmed.** No new conversion is introduced
on any of the four donation paths: the amount handed to `collectNudge` is byte-identical to the
amount computed/received one line earlier in every case (`NudgeRatchet:160` passes `bal`;
`Uniboost:250` and `PromotionUniV2_Eth:396` pass `donationAmount`; `BalancerPoolerV2:347` passes the
same `gemAmt` `buyGem` produced). `NudgeStreamer.PRECISION = 1e18` cancels between
`rewardPerSecond = buffer*1e18/duration` and `accrued = rate*elapsed/1e18`, so buffers and transfers
stay in native units.

**M-04 unwired-hook zero-debt class — CLEAN on the changed code.** `NudgeRatchet:137-140` and
`NudgeRatchetDelayRelease` retain the `hookTypeId()` guard; `ATokenDispatcherV2.setHook:95` still
rejects zero and `hook` is never null. Stories 046/047 touched no hook wiring.
**L-09/L-10 hook-scale classes — no new hook-scaled arithmetic in this range.**

---

## Reentrancy-class checklist (all rows walked)

| Class | Verdict | Basis |
|---|---|---|
| Classic single-fn | Cleared | No donor writes local state after `collectNudge`; only an `emit` follows (`BalancerPoolerV2:349`). `dispatch` is `nonReentrant` (`ATokenDispatcherV2:120`). |
| Cross-contract A→B→A | Cleared | Re-entry from the streamer into any donor is blocked by OZ `ReentrancyGuard`, which is **contract-wide**, so `pool()` (`BalancerPoolerV2:356`, `Uniboost:266`, `PromotionUniV2_Eth:429`) is locked for the duration of `dispatch`. `_psmDonate` is `external` but self-gated (`:310`) and unreachable except from `_dispatch`. |
| Cross-function siblings | Cleared | Same contract-wide guard; `getIdealBPT`, `primeToken`, `withdrawBPT`, `rescueERC20` mutate no shared accounting. |
| Read-only reentrancy | Cleared, with a stated precondition | No donor exposes a price/share view that a third party consumes as an oracle; `NudgeStreamer.pendingStream` is the only value view in the flow and is read only by UI. More importantly there is **no inbound callback window at all** in the donation path: USDC/USDS have no transfer hooks, so `_settle`'s outbound transfer and `collectNudge`'s pull never yield control. This clearance rests entirely on the token being hook-free — see CODE-006 for `Uniboost`, the one donor whose token is unpinned. |
| ERC721 receive hook | N/A | No ERC721 anywhere in the flow. |
| ERC1155 receive hook | Cleared, non-trivially | `NFTMinterV2._executeMint:196` calls OZ `_mint`, which invokes `onERC1155Received` on an attacker-controlled `recipient` — **after** `dispatch` (`:191`) and, inside `batchMint`, in the middle of the mint loop while `paymentToken.forceApprove(nftMinter, type(uint256).max)` is live (`BatchNFTMinterMultiToken:459`). That approval is **not** exploitable: `_executeMint:183` always pulls via `safeTransferFrom(msg.sender, ...)`, so an attacker re-entering `mint` spends their own funds, and `mintFor` is `authorizedMinters`-gated. `batchMint` is `nonReentrant`. The hook *can* reach the permissionless `NudgeStreamer.collectNudge`, but the batcher's payout was snapshotted pre-loop (`:453`), so a mid-loop donation cannot be recovered by the attacker in that same batch. No leak found. |
| ERC777 tokensReceived / tokensToSend | Cleared | Neither donor nor recipient nor streamer registers an ERC-1820 interface, so the hooks would not fire even with an ERC777 prime token. Recorded rather than assumed. |

## Notes on cross-contract CEI

`NudgeStreamer._settle` updates `buffer`/`lastUpdate` before its outbound transfer (`:182-190`) and
`collectNudge` pulls funds before recomputing the rate (`:149-153`) — CEI is correct on the
dependency side. The rate is recomputed on deposit only, never on flush or view, matching the
phlimbo port; the `collectNudge`-at-`t=0`-after-`pullPendingStream` sequencing inside `batchMint`
means a batch cannot settle its own in-loop donations back to itself (`elapsed == 0`), so the
"donate forward" incentive survives the change intact. Verified, no finding.
