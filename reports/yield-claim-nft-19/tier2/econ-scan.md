# Tier-2 Economic / Design Scan — yield-claim-nft run-19

- **Commit:** `d4cc563` (stories 046 / 047)
- **Scope:** the four donor dispatchers changed by 046/047 — `BalancerPoolerV2`, `NudgeRatchet`,
  `Uniboost`, `PromotionUniV2_Eth`. Read as dependencies (not as finding targets):
  `lib/phoenix-nft-staking/src/NudgeStreamer.sol`, `BatchNFTMinterMultiToken.sol`.
- **Tier:** 2 (protocol-wide value-flow reasoning over Tier-1 profiles). No C4 severity assigned.
- **Machine-readable:** `econ-scan.json`

---

## 0. Executive answer to the primary lead

**The resident streamer buffer is intended smoothing, not a value sink. It is self-liquidating.**
The pattern tier's headline ("~168 donations permanently resident") over-states it on two counts and
the correction matters, so it is stated plainly before anything else:

1. **Throughput at steady state is 100%.** The buffer converges to a *working balance*, not a
   growing sink. Inflow equals outflow at the fixed point. The nudge pot is not systematically
   under-funded.
2. **The buffer drains to exactly zero in exactly one `duration` after the last donation.** The rate
   is frozen at the last deposit (`pullPendingStream` never recomputes — the load-bearing phlimbo-V1
   fix), so `accrued = B·elapsed/D` reaches `B` at `elapsed = D` and the `min(accrued, buffer)` cap
   stops it there. There is no asymptotic tail.

What *is* a finding is the **retirement edge**: that last duration's worth of value is reachable only
through one narrow path, and four separate routine, well-intentioned owner actions each close that
path permanently. See **ECON-001**. ⚠️ **[RETRACTED — "permanently" is false; see the retraction banner
on ECON-001. Re-severed to Low as `L-06` in `submissions/qa-report.md`.]**

Two Tier-1 claims are also corrected below (§5): PATTERN-003's "never flushed" is **not correct**,
and PATTERN-005's "not a value cap" is **half right**.

---

## 1. The math (primary lead, quantified)

### 1.1 Model

`NudgeStreamer.collectNudge` (`NudgeStreamer.sol:137-156`) does, in order: settle at the **old** rate,
pull `amount`, then `s.rewardPerSecond = s.buffer * 1e18 / s.duration`. So with donations of size `d`
arriving every `dt`, and stream duration `D`:

```
B_{n+1} = B_n · (1 − dt/D) + d          (dt < D)
```

Fixed point:

```
B*  =  d · D / dt  =  ρ · D             where ρ = d/dt is the donation RATE (value per second)
```

**The steady-state resident buffer is exactly one `duration`'s worth of donation flow — independent
of cadence.** Simulation over 4000 arrivals matches the closed form to the cent at every
(D, dt) tested, with throughput → 100%.

By Little's Law the mean delivery latency is `W = B*/ρ = D`. **Every donated dollar reaches the
batch-minter, on average one full `duration` late.** That is precisely the mechanism the streamer was
built to provide.

### 1.2 Real parameters

Cadence must be modelled per **batch**, not per mint — `BatchNFTMinterMultiToken.batchMint` runs
`count` mints in one transaction, so the 40 `collectNudge` calls of a 40-batch land in the *same
block* with `dt = 0` between them and simply sum. The arrival unit is the batch. (This is why the
per-mint framing in the brief over-states the resident balance.)

Observed mainnet figures (phStaging `docs/BatchNFTMint/self-refund-fix-and-migration-plan.md`,
tx `0x6d71d6fd…f14996`, block 25242986):

| Parameter | Value | Source |
|---|---|---|
| `nudgeSize` | 40 | migration plan §"Config" |
| `batchDonationSize` | 15% (raised from 10% on 2026-06-10) | `MigrateBatchNFTMinter.s.sol` |
| Donation per 40-batch | 51.77 USDC @10% ⇒ **≈ 77.6 USDC @15%** | observed `BatchDonatedViaPSM` ×40 |
| Donation per mint | ≈ 1.94 USDC @15% | derived |
| NFT mint price | ≈ 12.94 USDS | derived from the same batch |
| Observed prior pot | 88.07 USDC | migration plan |
| Stream `duration` | **not yet set on mainnet** — tests use 1000 s | ops parameter |

### 1.3 Steady-state resident buffer, `d = 77.6 USDC/batch`

| `duration` \ batch cadence | 1 batch / week | 1 batch / day | 2 batches / day |
|---|---|---|---|
| **D = 1 day**  | 11 USDC | 78 USDC | 155 USDC |
| **D = 3 days** | 33 USDC | 233 USDC | 466 USDC |
| **D = 7 days** | 78 USDC | 543 USDC | 1,086 USDC |
| **D = 30 days**| 333 USDC | 2,328 USDC | 4,656 USDC |

This is the working balance in normal operation **and** the exact amount exposed at retirement
(ECON-001). Choosing `D` is therefore choosing how much value sits one config-mistake away from being
stranded; `D` should be set no longer than the smoothing actually needed. ⚠️ **[Language corrected:
"stranded" → *left behind and invisible*; the value remains recoverable. See the ECON-001 retraction.]**

### 1.4 Delta versus the pre-change behaviour

| | Pre-change (`safeTransfer(sink, amt)`) | Post-change (streamed) |
|---|---|---|
| Cumulative delivered to pot by time `T` | `ρ·T` | `ρ·(T − D)` approx. |
| Standing pot balance | full | lower by `B* = ρ·D` |
| Per-batch capture at steady state | `ρ·dt` | `ρ·dt` — **identical** |
| Mean donation latency | 0 | `D` |
| First batchers after go-live | full pot | reduced (ramp transient, one `D` long) |

**The pot is not systematically under-funded.** Per-batch payout at steady state is unchanged; the
change is a one-off deferral of one duration's flow plus a permanent reduction in the *standing*
balance by the same amount. Stories 046/047's stated intent ("paid over time rather than in a lump")
is faithfully implemented and economically neutral in the steady state.

One genuine, positive side effect worth recording: the flush at `batchMint` step 3.5 happens
**before** the pre-loop snapshot (`BatchNFTMinterMultiToken.sol:445-453`), and a batcher's own
donations enter the streamer only during the step-7 mint loop — *after* that flush. The
"donate-forward" property that story-057's self-refund fix restored is therefore **strengthened**,
not weakened, by the streamer hop. No regression of that class.

---

## 2. Findings

### ECON-001 — ⚠️ SEVERITY LANGUAGE RETRACTED — Retiring a `(batchMinter, token)` stream leaves one duration's worth of donations behind on the old pair

> ## ⚠️ RETRACTION (2026-07-25)
>
> **The irrecoverability language in this section is WITHDRAWN. It is wrong.** The original heading
> read *"permanently strands … four routine owner actions each close the only recovery path"*; the text
> below still contains *"`B*` is now unreachable forever"* (step 4) and *"high on irrecoverability"*
> (Confidence). **None of that is true.** It is preserved unedited rather than deleted so the walk-back
> is auditable, but **no downstream document may cite it.**
>
> **Disproof.** Two passing tests, in sequence:
>
> 1. `reports/yield-claim-nft-19/pocs/M-03-retirement-strand.patch` (5 contracts, 11/11 pass) — arm
>    `6a` recovers **100%** of the buffer after `setDispatcherIndex(0)` via the
>    `registerStream(old, token, 1)` ×2 settle-before-reset route (`NudgeStreamer.sol:118-119`), with
>    no `batchMint` and no payment. That already refutes "any one of the four actions closes the only
>    path". The submission draft then retreated to a weaker claim — that the *ordered pair*
>    `setNudgeTokenWhitelist(false)` → `setDispatcherIndex(0)` was terminal (arm `6c`).
> 2. `workspace/yield-claim-nft/test/val-M03-terminal-reversal.t.sol` —
>    `test_terminalPairIsReversibleByRestoringThePointer` (passing) refutes the retreat as well.
>    Restoring `setDispatcherIndex(PAY_INDEX)` **first** — a plain unguarded owner setter — re-enables
>    re-whitelisting and both exits, and 100% of the buffer is evacuated out of the state arm `6c`
>    called terminal. The `6c` revert was an **ordering artifact of that arm**, not a lock.
>
> **Corrected position.** Recovery is TOTAL in 4/4 single-action retirement sequences and from the
> claimed pair; every step is an owner call with no timing race, no counterparty and no cost beyond
> gas. **No state here is terminal, irreversible or unrecoverable.** What survives is that the value is
> *invisible* (no event, no view, no rescue on `NudgeStreamer`) and the recovery route is *undocumented*
> — and that the `setNudgeTokenWhitelist(USDC, false)` variant is entirely silent.
>
> **Disposition.** Re-severed **Medium → Low** and folded into
> `reports/yield-claim-nft-19/submissions/qa-report.md` as **`L-06`** (ledger `M-06`, fingerprint
> `25a9ab3e…` — unchanged). Submission `M-03.md` has been deleted. **Read `L-06`, not this section.**
>
> Also retracted here: the sizing must always carry its `duration` dependence (`~11` to `~4,656` USDC);
> no point estimate stands alone. And `MigrateBatchNFTMinter.s.sol` is **not this repo's script** — it
> lives in `phoenix-phase-2-staging` @ `c5956a9` and targets the streamer-less single-token
> `BatchNFTMinter` (0 hits for `NudgeStreamer`), so run literally it cannot leave anything behind. It
> is **template precedent for a future MultiToken migration, not a live default.**

- **Contracts:** all four dispatchers (`setBatchMinter` / `setRecipient` / `setNudgeStreamer`), acting
  on `NudgeStreamer` buffer state.
- **Type:** cross-contract stranded value / owner footgun (Law 3 — non-obvious consequence).

`NudgeStreamer` has **no owner rescue or sweep** — verified exhaustively against its complete function
list (`registerStream`, `collectNudge`, `pullPendingStream`, `pendingStream`, `_settle`, `_accrued`).
Buffered value is addressable only as `streams[batchMinter][token].buffer` and leaves only via
`_settle`, which is reachable two ways:

1. a **donor** calling `collectNudge` for that same pair (settles at the old rate first), or
2. the **batchMinter itself** calling `pullPendingStream` — and
   `BatchNFTMinterMultiToken` calls that in exactly **one** place, inside `batchMint`
   (`BatchNFTMinterMultiToken.sol:449`).

While donations keep flowing, path (1) carries the load and nothing is at risk. The exposure is at
**retirement**: once the dispatcher is repointed or disabled, path (1) stops and the residual
`B* = ρ·D` (§1.3 — order 10²–10³ USDC at observed rates) depends entirely on path (2).

**Path (2) requires all of the following to still hold on the OLD batch-minter:**

| Requirement | Enforced at | Destroyed by |
|---|---|---|
| not paused | `batchMint` `whenNotPaused` (:392) | `pause()` on retirement |
| `tokenMinter != 0` | `_resolvePaymentPath` (:500) | `setTokenMinter(0)` |
| `dispatcherIndex != 0` and resolves non-zero | `_resolvePaymentPath` (:505-508) | `setDispatcherIndex(0)` |
| token still on `_nudgeTokens` | flush loop iterates the whitelist (:447-450) | `setNudgeTokenWhitelist(USDC, false)` |
| someone pays for ≥ 1 real mint | `BatchMint__ZeroCount` + step 5/7 | — (cost ≈ 12.94 USDS) |

Note the ordering: `_resolvePaymentPath` runs at **step 2 (:405)**, *before* the step-3.5 flush
(:445). Unsetting either pointer reverts `batchMint` before the flush is ever reached.

**Attack/loss scenario (no attacker required — this is a maintenance sequence):**

1. Streamer accumulates `B* ≈ ρ·D` for `(oldBatchMinter, USDC)`.
2. Owner migrates: `pooler.setBatchMinter(newBatchMinter)`. Donations now feed the new pair.
3. Owner tidies up the retired instance — any one of: `pause()`, `setTokenMinter(0)`,
   `setDispatcherIndex(0)`, or unwhitelisting USDC.
4. ⚠️ **[RETRACTED — FALSE, see banner above; recovery is total via `registerStream` ×2]** `B*` is now unreachable forever. The dispatchers' `rescueERC20` cannot see it (the value left the
   dispatcher); `NudgeRatchet` has no `rescueERC20` at all; the batch-minter's `rescueERC20`
   (:312) only reaches tokens already **in** the batch-minter, not the streamer buffer.

This is not hypothetical topology: the project has already executed a batch-minter migration
(`MigrateBatchNFTMinter.s.sol`) whose documented retirement step is *"neutralize the old instance"*,
and whose pot recovery is `rescueERC20(USDC, new, balanceOf(old))` — a call that reads
`balanceOf(oldBatchMinter)` and is structurally blind to the streamer buffer. That script predates
the streamer, so a future migration written to the same template silently drops `B*`.

**Recoverability — and why it is a footgun rather than a loss.** Done in the right order, recovery is
*cheap*: after `≥ D` has elapsed since the last donation, `_accrued` saturates at the full buffer, so a
**single** `batchMint(1, …)` on the old instance flushes the entire buffer into it, and `rescueERC20`
then extracts it. Total cost ≈ one NFT mint (~13 USDS) plus gas. The problem is exclusively that the
owner must *know* to do this, must do it **before** any of the four tidy-up actions, and must wait out
`D` first. Nothing in the system surfaces the buffer: no event fires at retirement, no dispatcher
view exposes it, and the only read is `NudgeStreamer.pendingStream(oldBatchMinter, token)` — which a
migration operator has no reason to call.

**Safe-config guidance (should be written into the dispatchers' ops NatSpec):**
> Before retiring a batch-minter or repointing a dispatcher's `batchMinter`/`recipient`:
> (a) repoint the donor first so donations stop; (b) wait `≥ duration`; (c) call
> `pendingStream(oldBatchMinter, token)` and confirm it equals the whole buffer; (d) run one
> `batchMint(1, …)` on the old instance to flush it; (e) `rescueERC20` the proceeds;
> **only then** pause / unset `tokenMinter` / unset `dispatcherIndex` / unwhitelist the token.

**Affected parties:** the nudge pot, i.e. future batch-minters — the protocol's own incentive budget.
**Impact size:** `ρ·D`, one duration of donation flow (§1.3).
**Confidence:** high on mechanism, ⚠️ **[RETRACTED: "high on irrecoverability" — disproved twice; corrected to *recovery is total but undocumented*]**, medium on whether an operator would
actually trip it (they would have to skip a step nobody has documented — which is the definition of
the footgun).

---

### ECON-002 — A `dispatcherIndex` repoint makes the nudge token become the payment token; the accumulated pot is then swept to the next `batchMint` caller, not merely skipped

- **Root cause location:** `BatchNFTMinterMultiToken` (nested dep — root cause OOS as a *finding*),
  but the collision is created entirely by **first-party dispatcher topology**, and the streamer keeps
  feeding it. Recorded as an operational hazard, not filed against the dep.

`setNudgeTokenWhitelist` refuses to whitelist the derived payment token at admin time, and
`_snapshotRewards` (:558) `continue`s any entry equal to it at runtime. The brief asks whether value
then "accumulates with no payout path". It is worse than that:

```solidity
// BatchNFTMinterMultiToken.sol:479-486  — step 10, dust sweep
uint256 remaining = paymentToken.balanceOf(address(this));
if (remaining / DUST_THRESHOLD != 0) {
    paymentToken.safeTransfer(msg.sender, remaining);   // WHOLE balance, incl. the skipped pot
```

So the skipped token's entire accumulated balance is handed to `msg.sender` of the **next**
`batchMint` — a caller who needs only `count = 1` and does **not** have to clear `nudgeSize`. And
because `collectNudge` settles into the batch-minter on every donation, the leak is **continuous**
while misconfigured, not a one-off.

**Likelihood is materially higher than it looks.** The whitelist is `{USDC}` and the payment token is
derived from the pinned dispatcher's `primeToken()`. Of the four in-scope dispatchers, **three prime
in USDC**: `NudgeRatchet` (constructor enforces a 6-dp token, i.e. USDC), `PromotionUniV2_Eth`
(`USDC` is a `constant`), and `Uniboost` (unrestricted `_primeToken`, USDC in the live topology).
A single `setDispatcherIndex` to any of those NFT products — an ordinary product change, not an
error — creates the collision immediately.

**What is and is not already documented.** The dep's NatSpec (:335-343) documents the runtime skip
and even says the balance "follows the normal dust-sweep path". What is nowhere stated is the
economic consequence: that the sweep is a *transfer to an arbitrary caller* of a pot funded by prior
minters, bypassing the `nudgeSize` gate the pot exists to reward. That gap is the reportable part.

**Loss:** the full standing pot at the time of the repoint, plus everything the streamer settles in
afterwards. **Affected parties:** prior minters who funded the pot; the incentive design.
**Guidance:** treat "`primeToken()` of the newly pinned dispatcher ∉ `getNudgeTokens()`" as a
pre-condition of every `setDispatcherIndex` / `setTokenMinter`; unwhitelist first if it is violated
(and drain the streamer per ECON-001 before unwhitelisting).
**Confidence:** high on mechanism (read from source), medium on likelihood.

---

### ECON-003 — `NudgeRatchet` couples mint liveness to unenforced cross-contract config, with no isolation and no off switch

`NudgeRatchet._dispatch` is the only one of the four with **no** try/catch and **no** disable path:
`batchMinter` cannot be zeroed (constructor and `setBatchMinter` both require non-zero), there is no
`donationSplit`, and `bal >= amount` is already required — so any non-zero balance takes the streamer
branch unconditionally (`NudgeRatchet.sol:156-160`).

Consequently `nudgeStreamer == 0`, an unregistered `(batchMinter, USDC)` pair, or **any** revert
inside `collectNudge` — including `_settle`'s outbound USDC transfer to the batch-minter
(`NudgeStreamer.sol:187`), e.g. a USDC blacklist on the batch-minter — reverts `dispatch`, which
reverts `NFTMinterV2.mint`. **The whole NFT sale bricks, not just the donation.** The pre-change
`safeTransfer` made the deploy-to-wire window unreachable; it is now a live window, and the required
ordering (whitelist → `registerStream` → `setNudgeStreamer`) is enforced by convention only.

Economic impact is availability, not theft: no value is lost, but the product cannot be sold until
config is corrected. The asymmetry against `BalancerPoolerV2` (which parks quietly) is deliberate per
the NatSpec; the NatSpec also pre-declares this "NOT an audit finding". Recorded regardless — Law 1
does not let an author's say-so suppress a liveness coupling, and the reasoning tier, not the author,
adjudicates. Reasonable mitigation: mirror the other three and give `NudgeRatchet` a donation-disable
(or wrap the hop) so a mis-wire degrades rather than bricks.
**Confidence:** high.

---

### ECON-004 — Accrued-debt vs delivered-value gap: no new backing risk; the DEDUP-001 cushion still holds

Re-derived from source rather than assumed. `hook.onDispatch` fires with the **gross** dispatched
amount (`ATokenDispatcherV2.sol:125`) regardless of donation outcome, and `BalancerPoolerV2`'s
`try/catch` envelope now swallows a wider set of failures (streamer unset, `NudgeStreamer__NotRegistered`,
`NudgeStreamer__NotWhitelisted`, a failure inside `_settle`'s outbound transfer, a non-conforming
streamer), plus the new `if (gemAmt > 0)` dust branch which returns successfully and emits nothing.

**phUSD backing is not impaired, in either failure mode, and the value never leaves the system:**

- *Streamed successfully:* the donation sits in the streamer buffer, still on-chain, still owned by
  the `(batchMinter, token)` stream. Relocation, not loss.
- *Caught and skipped:* the USDS never leaves `BalancerPoolerV2` — it parks on the dispatcher and is
  re-swept by the next dispatch (or `rescueERC20`'d). Relocation, not loss.
- *Dust branch:* sub-1-unit `gemAmt` only; the USDS stays put.

Sizing the worst case: the donation is `batchDonationSize` = **15%** of the dispatched amount; the
other 85% is wrapped to sUSDS and pooled regardless of the donation path. So even a total, permanent
loss of every donation could not move backing by more than 15% of dispatched value — comfortably
inside the ≥2:1 over-backing cushion that prior runs established for DEDUP-001. **The cushion holds
under the new quiet-skip surface.** The only real regression here is observability: the dust branch
lost its `DonationSkipped` event, and every distinct wiring failure now collapses into one
undifferentiated `DonationSkipped`, while the contract's own NatSpec still instructs operators to
"watch `DonationSkipped` and the contract's USDS balance" — advice that no longer covers the dust
branch. That is a monitoring/QA-grade issue, not a solvency one.
**Confidence:** high.

---

### ECON-005 — `buyGem` return discarded (static SA-001): benign, fails closed

`ISkyPSM.buyGem(usr, gemAmt)` is **exact-output** by construction (DssLitePsm transfers exactly
`gemAmt` of gem to `usr` and returns the *DAI/USDS amount pulled*, not the gem amount). Sizing the
downstream `forceApprove(streamer, gemAmt)` + `collectNudge(…, gemAmt)` on the locally computed
`gemAmt` is therefore correct, not an assumption.

Should a non-conforming PSM ever deliver less, the failure is **not** a silent shortfall: the
streamer's `safeTransferFrom(donor, …, gemAmt)` (`NudgeStreamer.sol:149`) reverts on insufficient
balance, the whole `_psmDonate` rolls back atomically, and `_dispatch`'s catch parks the USDS and
emits `DonationSkipped`. Fails closed. No finding.

One adjacent note kept from Tier 1: `address gem = ISkyPSM(psm).gem()` is read **live** on every call
and `psm` is owner-settable, so a `setPSM` to a PSM with a different gem silently changes the token
identity handed to `collectNudge` ⇒ unregistered pair ⇒ swallowed ⇒ USDS parks behind one
`DonationSkipped`. `BalancerPoolerV2` is the only one of the four with this exposure (`NudgeRatchet`
pins a 6-dp immutable, `PromotionUniV2_Eth` pins USDC `constant`). Minor operational hazard: pair a
`setPSM` with a `registerStream` for the new gem.

---

### ECON-006 — `addLiquidity(…, 0, 0, …)` with post-hoc `minLP` (static SA-017): adequate; prior L-06 calculus unchanged

`_addPhusdPromoLiquidity` (`PromotionUniV2_Eth.sol:463-473`) passes zero for both `amountAMin` and
`amountBMin`, guarded only by `require(liquidity >= minLP)`.

`minLP` is the *stronger* guard here, not a weaker substitute. For a UniV2 pair,
`liquidity = min(amountA·ts/reserveA, amountB·ts/reserveB)`; a sandwich that skews the reserve ratio
mechanically reduces the LP minted for a fixed pair of input balances, so a `minLP` floor derived from
a fresh quote bounds ratio-skew loss directly in the unit that matters (shares of the pool), whereas
`amountMin` would only bound the router's refund leg. Three further mitigations verified:

- `pool()` is `onlyAuthorizedPooler` — `minLP` is supplied by a permissioned caller, not the public.
- The individual swap legs already carry `minPhusdOut` / `minEthOut` / `minPromoOut` / `minWbtcOut`.
- The sides are value-matched post-burn (~30% phUSD vs ~30% promotion of `amountIn`), so the router
  refund is small and any residual stays on the dispatcher for the next `pool()`.

The project's prior conclusion — `amountIn` is MEV-neutral, so this stays Low — is **unchanged** by
the 6th `minLP` parameter; if anything it is now better supported. No new finding.

---

## 3. Rounding-direction checklist (system-level)

Walked as mandated, on the composed round-trip rather than per-leg. These are one-way donor paths
with **no redemption leg** — there is no user-facing conversion to invert, so the classic round-trip
drain has no surface here. Every rounding decision on the changed paths floors *against* the
recipient and *for* the protocol:

| Site | Direction | Verdict |
|---|---|---|
| `gemAmt = usdsAmount·WAD / (conv·(WAD+tout))` | floors | never over-buys; residual USDS re-swept |
| `usdsSpent = gemAmt·conv·(WAD+tout)/WAD` | floors, `≤ usdsAmount` | protocol keeps the dust |
| `donationAmount = amount·split/100` | floors | donates less, retains more |
| `rewardPerSecond = buffer·1e18/duration` | floors | under-emits |
| `accrued = rate·elapsed/1e18`, capped at `buffer` | floors + capped | streamer can never pay more than it holds |

No asymmetric pair, no profitable loop, no symmetric/half rounding anywhere. `PRECISION = 1e18`
cancels exactly (`rate·elapsed/1e18 = buffer·elapsed/duration`), so 6-dp USDC is carried in native
units — the M-03 decimal class does **not** re-fire. **CLEAN.**

---

## 4. Cross-cutting notes

- **Only the dispatcher donation path is streamed.** The second funding path — `StableYieldAccumulator`'s
  30% `nudgeSplit` on each `claim()` — still transfers USDC **directly** to the batch-minter,
  unbuffered. So the anti-burst throttle covers one of two funding sources; a `claim()`-funded spike
  remains instantaneously capturable by the next 40-batcher. Worth stating so the mitigation is not
  miscredited as protocol-wide.
- **Residual streamer allowance.** All four `forceApprove(streamer, exactAmount)` and none reset to
  zero — in `BalancerPoolerV2` this is directly asymmetric with the PSM allowance eleven lines
  earlier, which *is* zeroed. Safe today because `collectNudge:149` pulls exactly `amount` in the same
  transaction; but that safety rests entirely on an **external, cross-repo** contract's implementation
  detail rather than any local invariant. A `setNudgeStreamer` to an under-pulling implementation
  leaves a live residual allowance on USDC. Cheap fix: pair each approve with a zeroing reset, as
  every other `forceApprove` in these contracts already does.
- **Reentrancy on the new hop.** `collectNudge` fires an **outbound** transfer to the batch-minter
  (`_settle`, :187) *before* pulling the donor's tokens (:149), inside the dispatcher's own `dispatch`.
  Defences verified adequate: `dispatch` is contract-wide `nonReentrant`, `collectNudge` and
  `pullPendingStream` are `nonReentrant`, `_settle` is CEI-correct, and the token is pinned for three
  of four. `Uniboost` is the exception — `_primeToken` is an unrestricted constructor arg with no
  allowlist or decimal guard, so the "hook-free token" premise is a deployment policy there, not a
  contract guarantee. No exploit today; recorded as an assumption the deployment must keep true.

## 5. Corrections to Tier-1 claims

| Tier-1 claim | Correction |
|---|---|
| **PATTERN-001** — "~168 donations permanently resident" | Over-stated twice. (a) Cadence is per *batch*, not per mint — a 40-batch is one arrival, so the multiplier is `D/dt_batch`, not `D/dt_mint`. (b) "Permanently" is wrong: the buffer drains to exactly zero in exactly `D` after the last donation, and throughput at steady state is 100%. The correct statement is `B* = ρ·D`, one duration's flow, self-liquidating. Intended smoothing — **not** a finding on its own; the finding is the retirement edge (ECON-001). |
| **PATTERN-003** — "every donation accumulates but is **never flushed** if the batch-minter's pointer is unset" | **Not correct.** `collectNudge` calls `_settle` on *every* donation (`NudgeStreamer.sol:146`), which pays the accrued stream to the batch-minter regardless of the batch-minter's own `nudgeStreamer` pointer. The step-3.5 flush is a freshness optimisation, not the delivery mechanism. With a divergent pointer, throughput and steady state are **unchanged**; the batcher's snapshot is merely one donation staler, and that value goes to a later batcher rather than being lost. There is also therefore **no** windfall-on-repair and no back-run MEV on fixing the pointer. The only residue is the retirement case, already covered by ECON-001. Downgraded to informational. |
| **PATTERN-005** — "the streamer is a timing throttle, not a value cap" | Half right, and the half that is wrong matters. It is correctly *not* a cap on what one caller can eventually take. But it **is** a hard cap on the *rate*: a batcher's step-3.5 flush yields `min(elapsed/D, 1)·buffer`, so capturing the whole buffer requires waiting a full `D` with no intervening claimant. Framing it as "no cap at all" understates the mitigation; framing it as an anti-over-funding value cap overstates it. Correct framing: **a rate cap — delay, not denial.** |
| **PATTERN-M04 / ROUNDING-DIRECTION** | Confirmed CLEAN independently (§3). |
| **SA-001** (`buyGem` return discarded) | Benign — exact-output semantics; fails closed (ECON-005). |
| **SA-017** (`addLiquidity(0,0)`) | Adequate — `minLP` is the stronger guard for ratio skew; L-06 calculus unchanged (ECON-006). |

## 6. Assumptions & gaps

- The mainnet stream `duration` is **not set anywhere in the reviewed repos** — it is a live ops
  parameter passed to `registerStream`. Every quantity in §1.3 scales linearly with it. This is the
  single unknown that sizes ECON-001, and it should be pinned in the deploy runbook.
- Batch cadence is not observable from source; §1.3 gives a scenario grid instead of a point estimate.
- `NudgeStreamer` and `BatchNFTMinterMultiToken` are nested third-party deps. Their internal bugs are
  out of scope; they were read only to establish the semantics the first-party dispatchers now depend
  on, and every claim above is filed against the first-party caller or as an operational hazard.
