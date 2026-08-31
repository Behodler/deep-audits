# Tier-2 Economic / Design-Intent Scan — phoenix-nft-staking run-26

- **Target**: `lib/phoenix-nft-staking` @ `9611312` (read-only)
- **Mode**: REGRESSION. Ledger present (78 entries).
- **Changed range**: `src/BatchNFTMinterMultiToken.sol`, `src/NudgeStreamer.sol`, `src/INudgeStreamer.sol` (stories 030 / 031 / 032)
- **Inputs consumed**: all 6 profiles in `reports/phoenix-nft-staking/26/profiles/`, `tier1/static-analysis.md`, `tier1/pattern-matches.md`
- **Stories retrieved (Law 2, external tree)**:
  - `~/code/product-owner/stories/nft-staking/complete/documentation/030-documentation-accuracy-stop-asserting-unenforced-guarantees.md` (state: **complete**)
  - `~/code/product-owner/stories/nft-staking/complete/audit-21/031-nudgestreamer-collectnudge-balance-delta-credit.md` (state: **complete**)
  - `~/code/product-owner/stories/nft-staking/review/whitelist-liberation/032-remove-payment-token-whitelist-gate.md` (state: **review** — landed at HEAD while the story is still open; noted, not itself a finding)
  - Design ancestor: `.../complete/nudge-streamer/028-create-nudgestreamer-and-wire-multitoken-batchminter.md`
  - Cadence source: `~/code/product-owner/stories/phStaging2/complete/phStaging2-nudge-streamer/073-deploymocks-...md` (pins **mainnet stream duration = 7 days**, local = 6 h)
- **Cross-repo read at top-level HEAD** (never a nested pin): `lib/yield-claim-nft` @ `d4cc563` —
  `src/dispatchers/NudgeRatchet.sol`, `src/dispatchers/BalancerPoolerV2.sol`, `src/hooks/NudgeRatchetMintDebtHook.sol`

**Framing honoured throughout**: nudge pots are funded by externally-derived yield on protocol-owned
capital. Pot mis-sizing is misallocation / marketing spend, never economic loss. The minted NFT has
no redemption value, so "acquire NFTs cheaply" has no value path. `paymentToken == nudgeToken` and
its arbitrage are owner-PERMITTED (2026-07-25); aggregate over-funding is `43e8c48626`. None of these
is re-litigated below.

---

## Summary

| ID | Subject | Type | Severity read | Disposition |
|---|---|---|---|---|
| ECON-26-01 | The streamer is a first-order low-pass filter, not a linear-to-zero drain. No griefer required; a griefer's marginal contribution is **0.11 pp**. | intent gap (Law 2, in-source docs) + bounded timing effect | **Low** | **RE-WEIGH input for `aaebb4b9b0` — do NOT re-file** |
| ECON-26-02 | `nudgeSize == 0` disables the payout but not the inflow or the flush: a "disabled" nudge keeps migrating reward tokens into an un-metered pot with no return path. | operator-expectation gap / non-obvious footgun | **Low (QA)** | New — distinct from PATTERN-001's availability limb |
| ECON-26-03 | `NudgeCollected.amount` repointed request → receipt under a byte-identical ABI. | accounting semantics change | **QA** | New, **no on-chain desync** — verified against the real donor |
| ECON-26-M1 | Magnitude input: the permanently-buffered float is `duration × inflow` (7 days' worth), structurally, always. | magnitude upgrade | — | Feeds `4a1d8edc92` (open), not a new finding |
| ECON-26-M2 | Magnitude input for `LOCAL-BM-01`: pre-commission stranding is unbounded in principle, bounded in practice by donor throughput. | magnitude | — | Feeds profile `LOCAL-BM-01` |

Five explicit **negative results** are recorded in §6. Per Law 1 they are stated, not dropped —
each one is a lever a future reader might otherwise assume is live.

---

## ECON-26-01 — The stream is an exponential low-pass filter, not "linear to zero over `duration`"; and it needs no adversary

- **Type**: design-intent / documentation mismatch with a bounded timing consequence
- **Contracts**: `src/NudgeStreamer.sol` (`:19-23`, `:152-212`, `:206`, `:266-271`); consumed by
  `src/BatchNFTMinterMultiToken.sol:528-536`
- **Confidence**: high (closed-form model, matches numeric simulation to 4 dp)
- **Ledger**: mechanism already recorded as **`aaebb4b9b0` (L-02, open)**. This section is the
  re-weigh input requested, not a re-file.

### Mechanism (established, restated only as far as the numbers need)

`collectNudge` is permissionless (profile §1.1: "**none (permissionless)**"). Its recompute at
`:206` re-spreads the **entire remaining buffer** over a **fresh full `duration`** measured from now:

```solidity
s.buffer += received;
s.rewardPerSecond = (s.buffer * PRECISION) / s.duration;   // :201, :206
```

With deposits of `ε` arriving every `Δ` seconds and window `D`, each period settles `B·Δ/D` and then
restarts the clock, so `B_{n+1} = B_n·(1 − Δ/D) + ε`. Two consequences follow, and they are
different from each other:

**(a) The transient is exponential with time constant `D`, not linear over `D`.**
Remaining fraction of a burst after time `t` is `(1 − Δ/D)^{t/Δ}`, which **increases** monotonically
toward `e^{−t/D}` as `Δ → 0`. `e^{−t/D}` is therefore a **hard upper bound** on what any depositor —
honest or hostile — can leave un-released. Simulated (`D = 7 days`):

| Deposit cadence `Δ` | left at `t=D` | `2D` | `3D` | `4D` |
|---|---|---|---|---|
| **12 s** (griefer, every block) | **36.79 %** | 13.53 % | 4.98 % | 1.83 % |
| **1 h** (routine per-mint donor cadence) | **36.68 %** | 13.45 % | 4.93 % | 1.81 % |
| 6 h | 36.12 % | 13.05 % | 4.71 % | 1.70 % |
| 1 day | 33.99 % | 11.55 % | 3.93 % | 1.34 % |
| continuous limit `e^{−t/D}` | 36.79 % | 13.53 % | 4.98 % | 1.83 % |

Worked number for the intent gap: **99 % delivery takes `D·ln 100` = 32.2 days against a configured
`duration` of 7 days — a 4.6× stretch**; 95 % takes 21.0 days. 100 % delivery never occurs while
deposits continue.

**(b) In steady state the throughput is CORRECT; what is wrong is a permanent float.**
In continuous form `dB/dt = i − B/D`, so `B* = i·D` and the release rate is `B*/D = i` — exactly the
inflow. There is no permanent under-release. What there *is* is a float of **one full `duration`
worth of inflow parked in the buffer forever**: at `D = 7 days`, 1 000 units/day of nudge inflow
implies **7 000 units permanently buffered**; 10 000/day implies 70 000. During the cold-start ramp
(first `D`, 1 h cadence) only **36.7 %** of inflow is released and **63.3 %** accumulates into that
float — the same decelerating shape and almost exactly the same figure as the PoC'd **63.26 %** drift
in ledger `b58b172e2a`.

### Q1 — Does it need a griefer? **No, and that is the decisive fact.**

The production donors fire on **every dispatch**, not on an ops schedule:
`NudgeRatchet.dispatch` calls `collectNudge(batchMinter, _token, bal)` unconditionally
(`lib/yield-claim-nft/src/dispatchers/NudgeRatchet.sol:156-161`), and `BalancerPoolerV2._donate`
does the same at `:347`. `BatchNFTMinterMultiToken.batchMint` mints in a loop, so a single batch of
`N` can produce `N` dispatches — i.e. `N` window resets — and the streamer is additionally fed by
`StableYieldAccumulator` and three `Uniboost` dispatchers (phStaging2 story-073 registers
`{USDC, phUSD, Kendu}` for the same batchMinter). Real cadence is *per mint*, not per top-up.

At an hourly effective cadence the buffer already sits at **36.68 %** at `t = D`. A griefer poking
every block reaches **36.79 %**. **The adversary's entire marginal contribution is 0.11 percentage
points.** Same-block deposits contribute nothing at all (`elapsed = 0` ⇒ `_accrued = 0` ⇒ no decay
factor), so the intra-batch `N`-reset burst is harmless. The griefing frame in `aaebb4b9b0` therefore
*over*-states the attacker and *under*-states normal operation: this is a design property of routine
seeding, reached with no adversary present.

### Q2 — The intent gap, with citations

**What the docs claim.** `NudgeStreamer.sol:19-23`:

> "Buffers bursty donations per `(batchMinter, token)` and streams them **linearly to zero over a
> configured `duration`**…"

Story-028's own overview repeats it (`:19`: "streams them linearly to zero over a configured
`duration`"). `docs/multi-token-nudge.md:463` and `:568-572` restate the metering claim.

**What the code does.** Linear-to-zero holds for exactly one case: a single deposit followed by
silence for `≥ D`. Under any repeated deposit — which is the only regime that exists in production —
release is exponential with time constant `D` and the buffer never reaches zero.

**The discrepancy is already conceded elsewhere in the same story.** Story-028 §Concerns:

> "**Rate resets the window on deposit**: like phlimbo, a new deposit recomputes
> `rewardPerSecond = buffer * PRECISION / duration` over the *full* duration from *now*, extending
> the tail. This is the accepted phlimbo behaviour (smooths bursts) and is deliberate."

So the *behaviour* is Law-2 **faithful** — the story blessed it explicitly. The gap is entirely
between that accepted behaviour and the **in-contract headline claim at `:19-23`**, which asserts a
guarantee the story's own Concerns section contradicts.

**This is what raises the doc limb above tidiness.** Story-030 exists *specifically* to
"stop asserting unenforced guarantees", and it rebuilt the owner acceptance of the winner-take-all
MEV posture — the stated suppression basis behind `858e9e807a` and `521c20ad48` — on two grounds,
one of which is the streamer (story-030 `:67`, mirrored into `docs/multi-token-nudge.md:343`):

> "`NudgeStreamer` **meters release so the market can find a clearing price** against the pot rather
> than racing a lump sum."

Story-030 swept `docs/multi-token-nudge.md` §1/§5 and left `NudgeStreamer.sol:19-23` standing;
story-031 §Review-Results item 4 records that the three metering sentences were deliberately left
untouched. Per repo policy, in-source NatSpec carries no suppression authority, and a
falsely-exhaustive claim raises rather than lowers severity — the more so when a *sibling* sentence
from the same doc-accuracy story is load-bearing for an audit suppression.

**Direction check (this is why it stays Low).** The metering ground itself **survives**. Nobody can
*accelerate* release: after any deposit `rate = buffer/D`, accrual is `rate·elapsed` capped at
`buffer` (`:266-271`), and the fastest possible full drain remains "wait `D`". The failure direction
is *slower* release, i.e. a **smaller** pot at any instant — which under story-030's own
clearing-price argument is better price discovery and less over-payment, not worse. Combined with
yield funding, no value is lost and none is misdirected: the withheld tokens sit in the streamer and
stream out later.

### Q3 — Is permissionless `collectNudge` a viable timing weapon? **No — bounded, and already saturated.**

Run-24 established the streamer is a **timing throttle, not a value cap**, so a timing attack does
attack the thing it is. Three separate facts defeat it anyway:

1. **Hard bound.** `e^{−t/D}` is the maximum any poking cadence can withhold (§(a)). Suppression is
   *decelerating and self-limiting*, never indefinite: 1.83 % left at `4D`, 0.03 % at `8D`.
2. **Already saturated by honest traffic.** Routine per-mint cadence reaches 36.68 % vs the
   attacker's 36.79 %. The attacker buys 0.11 pp for unbounded gas.
3. **Each poke pays the victim.** `collectNudge` runs `_settle` **first** (`:161`), which
   `safeTransfer`s the accrued amount **to the batchMinter** (`:243`). Every poke therefore *delivers*
   funds into the pot before stretching the tail, and a poke front-running a competitor's `batchMint`
   makes that competitor's pot **larger**. There is no targeted-suppression variant.

Cost side, for completeness: a poke needs a registered pair, 1 wei of the nudge token
(`amount == 0` reverts at `:163`; 1 wei does not), an allowance, and ~80–100 k gas
(2× `balanceOf`, `transferFrom`, 3 SSTOREs). Griefer payoff: **zero** — push-only custody
(profile §2.3), no withdrawal, no acceleration, and the NFT has no redemption value.

### Q4 — Committed severity read for the RE-WEIGH

**Case for Medium.** (i) A load-bearing in-contract guarantee is false under every production
regime, and the sibling sentence it shares a story with is the stated basis for suppressing two
findings. (ii) The distortion is 4.6× on the configured window and needs no adversary, so it is
*certain*, not conditional. (iii) `collectNudge` is permissionless, which is normally a severity
multiplier. (iv) The float is not dust: `D × inflow`, permanently.

**Case for Low.** (i) **No value leaves the protocol and none is misdirected** — yield-funded pot,
withheld tokens remain in the streamer and stream out later; the ledger framing forbids filing this
as a leak. (ii) The error direction *favours* the protocol: a smaller instantaneous pot is less
over-payment and better clearing-price discovery, which is the doc's own stated purpose. (iii) The
mechanism is **Law-2 faithful** — story-028 explicitly blessed window-reset-on-deposit as intended
phlimbo behaviour; only the headline NatSpec overstates it. (iv) The adversary is *irrelevant*
(0.11 pp) and unprofitable, so the permissionless surface is not a severity multiplier here — it is
an availability non-event. (v) Suppression is hard-bounded by `e^{−t/D}`; there is no indefinite
denial. (vi) C4 Medium requires assets at value-leak risk or protocol function/availability
impacted; neither obtains — the function performs, just on an exponential rather than linear
schedule that no on-chain consumer depends on.

**COMMITTED: stays LOW.** The no-griefer-needed + permissionless combination does **not** justify
Medium, because the two limbs cancel rather than compound: precisely *because* no griefer is needed,
the permissionless surface adds nothing (0.11 pp), and precisely *because* nothing is lost and the
error favours the protocol, the certainty of the distortion has no impact to attach to.

**But the entry must be RE-FRAMED, and that re-framing is the substance of this re-weigh:**

1. **Drop the griefing frame as the primary characterisation.** "`collectNudge` dust window-reset
   griefing" describes an attack whose marginal effect is 0.11 pp. Filed that way, a reader will fix
   it by permissioning `collectNudge` — which changes nothing, and would break both production donors
   (`NudgeRatchet.dispatch`, `BalancerPoolerV2._donate`).
2. **Promote the intent-gap limb.** The reportable defect is the claim at `NudgeStreamer.sol:19-23`
   (and story-028 `:19`, `docs/multi-token-nudge.md:463`, `:568-572`): the streamer is a first-order
   low-pass filter with time constant `duration`, and "linearly to zero over `duration`" is
   unachievable under any repeated-deposit regime. Recommended remediation is **documentation, not
   code** — restate as "smooths bursts with an exponential tail of time constant `duration`; 99 % of
   a burst clears in ≈ `4.6 × duration`" — plus a runbook note that `duration` should be sized
   against the desired *time constant*, not the desired drain time (a 7-day `duration` implies a
   ~32-day 99 % window).
3. **Attach the float number** (see ECON-26-M1) so `4a1d8edc92`'s magnitude is not read as dust.
4. **Keep `MR-26-01` (sub-wei truncation) separate**, as pattern-matching already instructed —
   different mechanism (truncation, not window reset).

- **Who bears the cost**: nobody in value terms. In timing terms, early `batchMint` callers receive
  a smaller pot and later ones a larger one; the protocol's marketing spend is spread over ~4.6×
  longer than the operator configured. Cost is **opportunity cost and mis-set expectations**, not loss.
- **Preconditions**: any repeated deposit cadence with `Δ ≪ duration`. Satisfied by default in
  production; no adversary, no permission, no unusual token.

---

## ECON-26-02 — `nudgeSize == 0` disables the payout but neither the inflow nor the flush: a "disabled" nudge accumulates an un-metered pot with no return path

- **Type**: operator-expectation gap / non-obvious owner footgun (Law 3 in-scope)
- **Contract**: `src/BatchNFTMinterMultiToken.sol` — `qualifies` computed `:510-514`, flush loop
  `:528-536` (does **not** read `qualifies`), `_snapshotRewards` pins non-qualifying entries to 0 at
  `:801`, `_payRewards` skips zeros at `:831`
- **Confidence**: high (control flow read in full)

### What the operator is told they are switching off

- Contract header `:40-41`: "`nudgeSize` gates *who* qualifies (batch size >= threshold; `0`
  **disables the feature outright**)."
- `setNudgeSize` `:269-270`: "Setting `0` **disables the feature**."

### What actually keeps running

Step 3.5 is gated **only** on `nudgeStreamer != address(0)`. With `nudgeSize == 0`, every
`batchMint` — including a `count == 1` batch made by anyone — still executes
`pullPendingStream(token)` for every whitelisted token, settling accrued buffer out of the
metered streamer and into the batchMinter's raw balance. `_snapshotRewards` then pins the entry to
`0`, so nothing is paid out. Net: the "disabled" feature has been switched from
*meter-and-pay* into *accumulate-forever*.

Economic consequences, in the order that matters:

1. **The value migrates from a metered container into an un-metered one.** Tokens in the streamer are
   rate-limited by `rewardPerSecond`; tokens sitting in the batchMinter are fully liquid and are
   swept **in their entirety** by the first caller who clears the gate once `nudgeSize` is restored
   (`_payRewards` transfers the whole `snapshot[i]`). The operator who "turned the nudge off" has, in
   effect, been assembling the lump sum the streamer exists to prevent.
2. **There is no return path.** The streamer has no withdrawal, no pause and no deregistration
   (profile §1.6, §2.3), and the batchMinter cannot push tokens back. The only exits are re-enabling
   `nudgeSize` (paying the accumulation to one winner) or `rescueERC20`. An operator disabling the
   nudge to *stop* distributing has instead committed the accumulation to a single future claimant.
3. **UI/accounting divergence.** `pendingStream` is documented as what "UI reports … as already
   landed in the pot" (`NudgeStreamer.sol:227-228`). During a disable it reads ~0 while the real
   un-payable accumulation sits in the batchMinter, invisible to both surfaces.
4. **The disable does not reduce external dependency.** Every `batchMint` still makes
   `_nudgeTokens.length` external calls into the streamer while the feature is nominally off — the
   coupling that PATTERN-001 turns into an availability finding.

**Worked magnitude.** `D = 7 days`, aggregate nudge inflow `i`. With the nudge disabled for `T` days
and at least one `batchMint` per `~D`, the batchMinter accumulates essentially all inflow over `T`,
i.e. `i·T` — for `i = 1 000/day` and a 30-day disable, **30 000 units** delivered as a single
un-metered lump to whoever wins the first re-enabled qualifying batch, against a streamer designed
to cap instantaneous release at `i`.

**Honest limits — stated so this is not overclaimed.** No value is lost (yield-funded, and the tokens
remain in protocol-controlled contracts). And the flush is *not* the cause of the lump: even without
it, a quiet period longer than `D` makes `_accrued` hit its `buffer` cap (`:270`), so the first
post-disable flush pulls the whole buffer anyway. The flush's distinct contribution is that the
accumulation happens **during** the disabled period, in the wrong container, invisibly, and cannot be
undone.

**Law-3 test**: would a competent non-malicious owner be surprised? Yes — two NatSpec sites say
"disables the feature", `_snapshotRewards` gates its own balance read on `qualifies`, and the flush
sits immediately above it doing the opposite. **Non-obvious footgun ⇒ in scope.**

- **Severity read**: **Low / QA.** No asset loss, no availability impact on its own path, fully
  reversible by the owner; the harm is mis-set operator expectation plus an un-metered lump on
  re-enable. (PATTERN-001's *availability* limb on the same lines — one pausing/blacklisting stream
  token bricking every `batchMint` — is the code tier's Medium and is **not** duplicated here; the two
  should be filed as separate limbs of the same unconditional flush.)
- **Recommendation**: gate the step-3.5 loop on `qualifies` (or on `nudgeSize != 0`), so the disable
  lever is symmetric and a non-qualifying batch takes no streamer dependency; or, if the flush must
  stay unconditional to keep the pot warm, say so at `:40-41` and `:269-270` — "`0` disables the
  payout; streamed funds continue to accumulate in this contract".
- **Adjacent, do not collapse**: `43e8c48626` (aggregate over-funding, wont-fix) is about the size of
  a *paid* pot; this is about accumulation while the feature is *off*.

---

## ECON-26-03 — `NudgeCollected.amount` repointed from request to receipt under a byte-identical ABI

- **Type**: accounting/event semantics change without an ABI signal
- **Contract**: `src/NudgeStreamer.sol:108-114` (declaration), `:211` (emit); documented at
  `src/INudgeStreamer.sol:14-18`
- **Confidence**: high (cross-repo donor read at top-level HEAD)

`emit NudgeCollected(recipientBatchMinter, token, msg.sender, received, s.rewardPerSecond)` — same
topic, same four fields, same types; the third non-indexed value now means the **credited receipt**
rather than the **requested amount**. Story-031 §Concerns-3 accepts this explicitly ("any consumer
summing that field sees a smaller number for taxed tokens — which is the true credited value"), and
its own Review-Results item 3 records that the event *declaration* still does not say so. So this is
Law-2 faithful and self-disclosed; the question I was asked is what it costs.

**On-chain: nothing. Verified, not assumed.**

- `grep -rn "NudgeCollected" lib/yield-claim-nft/src` → **no hits**. No sibling contract consumes it.
- The production donor `NudgeRatchet.dispatch`
  (`lib/yield-claim-nft/src/dispatchers/NudgeRatchet.sol:142-161` @ `d4cc563`) keeps **no cumulative
  sent-amount counter**. It reads `bal = balanceOf(this)`, asserts `bal >= amount`, `forceApprove`s
  exactly `bal`, and forwards `bal` — stateless, per-dispatch.
- The mint-debt ledger that *does* accumulate is entirely independent of the event:
  `NudgeRatchetMintDebtHook.onDispatch(minter, amount, …)` computes
  `added = (amount * USDC_TO_PHUSD_SCALE * ratio) / 100` from the **NFTMinter's `amount`**
  (`:122-130`), never from the streamer credit. Story-031 cannot desynchronise it.
- `BalancerPoolerV2._donate` (`:324-347`) is likewise stateless w.r.t. the credit — it sweeps
  `gemAmt` from the PSM and forwards it.
- **Unreachable for the production assets anyway**: both donors forward **USDC** (`NudgeRatchet:54`
  "Must be USDC (6 decimals)"; `BalancerPoolerV2` forwards the PSM `gem`). Receipt ≠ request only for
  a fee-on-transfer / reflection / donating token, which USDC is not.

**Residual: off-chain only, and it is a silent under-count.** An indexer that reconciles
`Σ NudgeCollected.amount` against donor-side sent totals will disagree with itself across the
deployment boundary, with no compile-time, ABI-level or topic-level signal — and the disagreement is
in the *under*-reporting direction for the pot, which is the direction an operator is least likely to
investigate. There is also no on-chain way to learn the credited value: `collectNudge` returns
`void` (`INudgeStreamer.sol:20-23`, signature deliberately frozen).

- **Who bears the cost**: off-chain reporting consumers / the operator reading a nudge-distribution
  dashboard. No on-chain party.
- **Severity read**: **QA.** Correct semantics, deliberate, documented in the interface, unreachable
  for the deployed asset set, no on-chain consumer.
- **Recommendation**: state the repoint on the `NudgeCollected` declaration itself
  (`NudgeStreamer.sol:107-114`) — the line an indexer author reads first — and note in the ops
  runbook that the field is the credited receipt. A version bump / renamed event is warranted only if
  an indexer spans both deployments.

---

## Magnitude inputs to already-open entries (not new findings)

### ECON-26-M1 → `4a1d8edc92` (L-01, open — "no rescue; buffers strand")

That entry should not be read as dust. §ECON-26-01(b) shows the steady-state buffer is
`B* = duration × inflow_rate`, **structurally and permanently**: at the pinned mainnet `duration` of
7 days, the streamer holds seven days of aggregate nudge inflow at all times, across
`{USDC, phUSD, Kendu}` for every registered batchMinter. This is the *magnitude* of what
`4a1d8edc92` says is unrecoverable if a pair is ever decommissioned or permanently de-whitelisted —
no withdrawal, no deregistration, `duration == 0` unreachable (`:126`). Sizing the stranding risk at
`7 × daily inflow × number of registered pairs` rather than "leftover dust" is the correction.

### ECON-26-M2 → profile `LOCAL-BM-01` (story-032 pre-commission ordering footgun)

Economic magnitude of that hazard: the two production donors are **stateless sweepers** that forward
their entire balance on every dispatch and revert only on `NudgeStreamer__NotRegistered`
(`NudgeRatchet:33-43`, `:156-161`). Once `registerStream` succeeds — which after story-032 needs only
the whitelist entry, no configured `tokenMinter`/`dispatcherIndex` — donations begin buffering
immediately and continue on every mint, while `batchMint` (the buffer's only drain) reverts
`BatchMint__DispatcherNotConfigured` at `:479`. So the amount at risk is **all donor throughput
between `registerStream` and completed minter configuration**, not a fixed sum, held by a contract
with no rescue. Fully recoverable by completing configuration ⇒ runbook hazard, not a loss.
Do not collapse with `4a1d8edc92` (that is the decommission mirror; this is pre-commission).

---

## §6 — Negative results (checked and cleared; recorded per Law 1)

1. **Nobody can accelerate the stream.** After any deposit `rate = buffer/duration`, and `_accrued`
   caps at `buffer` (`:266-271`). The fastest achievable full drain is "wait `duration`" — the same
   as the design intends. Story-030's load-bearing metering ground for suppressing `858e9e807a` /
   `521c20ad48` ("meters release so the market can find a clearing price rather than racing a lump
   sum", `docs/multi-token-nudge.md:343`) therefore **survives** the permissionless `collectNudge`
   lever. I looked for this specifically because that sentence is a suppression basis.
2. **No targeted-timing MEV weapon.** A poke immediately before a victim's `batchMint` settles
   accrual **into** the victim's pot (`:161` → `:243`), making it larger. Reducing a specific batch's
   pot is impossible: step 3.5 flushes accrual regardless.
3. **Poking gives the poker no advantage either.** Post-poke `rate = buffer/D`; waiting `D` then
   yields the full buffer — identical to not poking. The anti-burst property is intact in both
   directions.
4. **The intra-batch reset burst is harmless.** `N` mints in one `batchMint` produce `N`
   `collectNudge` calls in one block; `elapsed == 0` ⇒ `_accrued == 0` ⇒ decay factor `1`. Same-block
   repetition costs nothing.
5. **Story-032 introduces no new economic value path.** It deletes a defence-in-depth admin check
   only; `batchMint` is byte-unchanged. The budget-sourced refund (`:604`, `:709`) is the actual
   guard and is intact, and `2d34673536` remains fixed. The collision it makes one call cheaper is
   owner-PERMITTED (2026-07-25). Its only live consequence is the ordering footgun already captured
   as `LOCAL-BM-01` (+ ECON-26-M2 above).

### Assumption gaps / could not verify

- **Live `duration` values and per-pair inflow rates.** `duration = 7 days` is taken from phStaging2
  story-073's stated user decision, not from chain. All magnitudes above are parameterised in
  `inflow_rate`, so they scale; the 4.6× window-stretch ratio is `duration`-independent.
- **Live `nudgeSize`, whitelist contents and `nudgeStreamer` address** on any deployed instance.
  Per prior-run notes for this family, deploy records have been unreliable and addresses should be
  resolved from chain before acting on ECON-26-02.
- **Whether any off-chain indexer sums `NudgeCollected.amount`.** ECON-26-03's residual is entirely
  contingent on this; I can rule out on-chain consumers, not off-chain ones.
