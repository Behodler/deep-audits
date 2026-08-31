# Story-faithfulness scan — yield-claim-nft run-19

- Project: `yield-claim-nft`
- Range: `e4de393..d4cc563`
- HEAD: `d4cc563`
- Mode: regression (stories in range)
- Law: 2 (faithfulness), with Law-1 override checks and Law-3 footgun triage

## Stories checked

| Tag | Commit | Verdict |
|---|---|---|
| story-046 (impl) | `1745e83` | **Faithful** — all five stated intent items land verbatim; 2 scope/hazard notes |
| story-046 (tests) | `ef5fd64`, `7792619` | **Faithful** — test claims verified against the suites named |
| story-047 | `d4cc563` | **Faithful with one doc deviation** (F-01-047) |
| untagged | `eb15bcd` | Build/dependency flatten only — no `src/` behaviour change; not a Law-2 subject |

Spec sources used: the four commit bodies (`git log --format=%B`), contract-level NatSpec in
`src/dispatchers/*.sol`, `lib/yield-claim-nft/CLAUDE.md` (its diff in this range is dependency-management
process only — it states no behavioural criteria), and the dependency's own NatSpec in
`lib/yield-claim-nft/lib/phoenix-nft-staking/src/NudgeStreamer.sol`. There is no `docs/` directory in this repo.

---

## story-046 — "Route nudge donations through INudgeStreamer in three V2 dispatchers" (`1745e83`)

### Intent items and verdicts

| # | Quoted intent | Verdict |
|---|---|---|
| 1 | "NudgeRatchet, Uniboost and PromotionUniV2_Eth each gain a setter-only `nudgeStreamer`" | PASS — `NudgeRatchet.sol:63`, `Uniboost.sol:86`, `PromotionUniV2_Eth.sol:155`; no constructor arg in any of the three |
| 2 | "a `NudgeStreamerUpdated` event" | PASS — declared and emitted in all three |
| 3 | "an owner-gated `setNudgeStreamer` rejecting address(0)" | PASS — `onlyOwner` + `require(newStreamer != address(0), ...)` in all three |
| 4 | "The donation `safeTransfer` is replaced (**not fallback-wrapped**) with forceApprove + collectNudge" | PASS — no `safeTransfer` donation path survives in any of the three; no try/catch, no legacy fallback. Exact-amount `forceApprove` then `collectNudge` |
| 5 | "Contract-level @dev documents the mandatory streamer, the `NudgeStreamer__NotRegistered` failure mode and the ops wiring order" | PASS — all three carry the 3-step ordering block (whitelist → registerStream → setNudgeStreamer) and name `NudgeStreamer__NotRegistered` / `NudgeStreamer__NotWhitelisted` |

### "Which three?" — resolved

The three are **NudgeRatchet, Uniboost, PromotionUniV2_Eth**, named explicitly in the commit subject line's body.
**`PromotionUniV2_Eth` is inside story-046, not an uncovered fourth.** The fourth dispatcher touched in the
range, `BalancerPoolerV2`, is covered by story-047. **There is no uncovered-dispatcher Law-2 gap** among the four
that changed.

There *is* a fifth donor into the same sink that was left un-routed — `NudgeRatchetDelayRelease` — see F-01-046.

### Dependency mental-model check — the streamer is a timing throttle, not a value cap

Checked every new NatSpec line in all four dispatchers against `NudgeStreamer`'s actual semantics
(`lib/phoenix-nft-staking/src/NudgeStreamer.sol`). The dispatchers describe it consistently and **correctly** as
"buffers … releases it linearly … paid over time rather than in a lump". **No dispatcher NatSpec, story line, or
CLAUDE.md text claims it is a cap, a ceiling, or an anti-over-funding control.** The code was therefore *not*
written under a wrong model of the dependency — no Law-2 defect on this axis, and no Law-1 concern arising from it.

Carry-forward note for report readers (informational, not a finding): because the streamer changes *when* value
lands and never *how much*, none of the pre-existing nudge over-funding / aggregate-pot findings on the
phoenix-nft-staking side are closed by stories 046/047. Do not read this range as fixing them.

---

## story-047 — "Route BalancerPoolerV2's PSM donation through INudgeStreamer" (`d4cc563`)

### Intent items and verdicts

| # | Quoted intent | Verdict |
|---|---|---|
| 1 | "the pooler forceApproves the exact `gemAmt` to the nudgeStreamer and calls `collectNudge(batchMinter, gem, gemAmt)`" | PASS — `BalancerPoolerV2.sol:345-347`; `buyGem` recipient changed to `address(this)` (`:335`) |
| 2 | "add nudgeStreamer field, NudgeStreamerUpdated event and owner-gated setNudgeStreamer(address) rejecting zero, **matching the other three donors**" | PASS — identical shape to the story-046 three |
| 3 | "resolve the gem (USDC) from `ISkyPSM(psm).gem()` rather than a constant" | PASS — `:346`; `gem()` exists on `src/interfaces/ISkyPSM.sol:48` |
| 4 | "guard the whole PSM+streamer body behind `if (gemAmt > 0)` so a dust sweep is a clean no-op instead of a caught revert" | PASS on the code; **see F-01-047** for the un-updated observability contract |
| 5 | "require a non-zero streamer only on the live-donation branch, so a donation-disabled pooler stays deployable and dispatchable without one" | PASS — the `require(streamer != address(0))` sits inside `if (gemAmt > 0)`, itself inside `if (donationEnabled)` |
| 6 | "leave the `try this._psmDonate{} catch` envelope and its parked-USDS bookkeeping untouched" | PASS — `_dispatch` catch block is byte-identical; still `emit DonationSkipped(remainingUSDS)` |
| 7 | "document the widened set of caught failures, the quiet-misconfiguration caveat and the ops ordering in contract NatSpec" | PASS — the contract-level block names all three new swallowed reverts and states "a streamer misconfiguration is quiet: watch `DonationSkipped` and the contract's USDS balance" |
| 8 | "ATokenDispatcherV2 and all sibling dispatchers untouched; no lib/ changes" | PASS — `git show --stat d4cc563` touches exactly `src/dispatchers/BalancerPoolerV2.sol` + two test files |

### Is the shipped catch region exactly what the story describes, or wider?

**Exactly what the story describes.** The `try`/`catch` boundary is unmoved — it still wraps precisely
`this._psmDonate(remainingUSDS)`. What widened is the *contents* of `_psmDonate`, by exactly the three reverts
the story enumerates (`"nudgeStreamer unset"`, `NudgeStreamer__NotRegistered()`, `NudgeStreamer__NotWhitelisted()`).
No additional external call was pulled inside the envelope beyond the `gem()` read and the approve/collectNudge
pair the story announces. The story's disclosure is complete on this point.

### Does the story acknowledge the specific consequences?

- **Silent USDS parking on unset/unregistered streamer — YES, fully acknowledged**, in both the commit body
  ("the quiet-misconfiguration caveat") and the shipped NatSpec, together with the recovery property (the next
  dispatch re-sweeps, so nothing is lost) and the monitoring instruction. Faithful; not a finding.
- **The dust branch losing its `DonationSkipped` event — NO.** Neither the commit body nor the NatSpec
  acknowledges it, and the `DonationSkipped` NatSpec still advertises dust as a trigger. → **F-01-047**.

---

## Findings

### F-01-047 — `DonationSkipped` still documented as a dust signal, but the dust branch no longer emits it

- Type: `faithfulness` (documented-behaviour deviation) · Law 2 · severity **potential-low / QA**
- Contract: `src/dispatchers/BalancerPoolerV2.sol`, `_psmDonate` (event decl. `:134`, guard `:329`)
- Spec text (event NatSpec, present in the tree at `d4cc563`, unchanged by this commit):
  > "Emitted when a donation attempt is silently skipped (PSM outage / fee spike / **dust**). `usdsParked` USDS
  > stays on the contract for the next dispatch to retry."
- Spec text (same commit's new contract NatSpec, ops guidance):
  > "This means a **streamer misconfiguration is quiet**: watch `DonationSkipped` and the contract's USDS balance."
- Spec source: `git commit d4cc563` + contract NatSpec, `src/dispatchers/BalancerPoolerV2.sol`
- Actual behaviour: under `e4de393`, `require(gemAmt > 0, "BalancerPoolerV2: donation dust")` reverted into the
  caller's `catch`, which emitted `DonationSkipped(remainingUSDS)`. Under `d4cc563` the `if (gemAmt > 0)` guard
  returns normally, so a dust sweep emits **nothing at all** — no `DonationSkipped`, no `BatchDonatedViaPSM`.
- Deviation: the *code change* is authorised by story-047 bullet 4 ("a clean no-op instead of a caught revert"),
  so this is not an unauthorised behaviour change. The deviation is that the contract's own documented
  observability contract was not updated in the same commit, and the same commit doubles down by telling
  operators to monitor `DonationSkipped`. Dust-driven skips are now invisible in logs.
- Impact: bounded and low. The condition requires `usdsAmount * WAD / (conv * (WAD + tout))` to floor to zero,
  i.e. a sub-1e-6-USDC sweep; the USDS parks and is re-swept, so no value is at risk. This is a monitoring-
  fidelity defect, not a loss path.
- Suggested resolution: either emit `DonationSkipped(usdsAmount)` from inside the `else` of the guard, or strike
  "dust" from the event's NatSpec and say so in the contract-level ops note. `lawImpacted: 2`, confidence high.

### F-02-046 — the mandatory-streamer brick is real; the NatSpec's blanket "NOT an audit finding" is over-broad for the *repoint* case

- Type: `story-unsafe` (Law-1 override check applied) · `securityEscalation: false` after assessment ·
  severity **potential-low (operational hazard / Law-3 footgun)**
- Contracts: `src/dispatchers/NudgeRatchet.sol:155-160`, `src/dispatchers/Uniboost.sol:246-250`,
  `src/dispatchers/PromotionUniV2_Eth.sol:392-396`
- Spec text (story-046, shipped in all three contracts' NatSpec):
  > "If the streamer is set but ops forgot `registerStream(batchMinter, _token, duration)` on it, every
  > `dispatch` reverts `NudgeStreamer__NotRegistered()`. **This is the accepted consequence of the
  > mandatory-streamer decision, NOT an audit finding.** … Repointing `batchMinter` to an address with no
  > registered stream re-arms the same failure mode; register the new pair first."
- Spec source: `git commit 1745e83` body + contract NatSpec
- Assessment of the "NOT an audit finding" claim, on its merits:
  - The revert path is confirmed: `NFTMinterV2._executeMint` (`src/NFTMinterV2.sol:191`) calls
    `dispatch` with no try/catch, so a `NudgeStreamer__NotRegistered()` bubbles all the way out and **user mints
    at that dispatcher index revert**. `NudgeRatchet` has no donation-disable switch and no `bal == 0` escape
    once it holds any balance, so the brick is total for that index.
  - **No value is at risk.** The user's `safeTransferFrom` of `price` happens inside the same reverting tx
    (`NFTMinterV2.sol:183`), so nothing is stranded and no NFT is minted against a lost payment.
  - **Recovery exists and is cheap**: the minter owner can set `config.disabled` on the index, or the streamer
    owner can call `registerStream`. Availability-only, owner-fixable, no residual state damage.
  - **Deploy-ordering case — the claim is CORRECT (Law 3, suppress).** A freshly deployed dispatcher with
    `nudgeStreamer == address(0)` fails loudly and immediately on the very first dispatch, before any user
    traffic. That consequence is obvious to a competent operator; not a finding.
  - **Repoint case — the claim is NOT correct (Law 3, in scope as a footgun).** `setBatchMinter(new)` /
    `setRecipient(new)` on a *live* dispatcher succeeds silently and arms `NudgeStreamer__NotRegistered()` on
    every subsequent user mint. Clearing it requires calls on two *other* contracts —
    `batchMinter.setNudgeTokenWhitelist(token, true)` then `NudgeStreamer.registerStream(...)`, the latter
    `onlyOwner` of a contract in a **different repository** (`phoenix-nft-staking`) that may not share the
    dispatcher's owner key. The dispatcher exposes no view and no guard that would surface the missing
    registration before it bites, and `setBatchMinter` does not check it. A competent, non-malicious owner
    would be surprised. The same shape applies to `Uniboost`/`PromotionUniV2_Eth` when the owner *enables* a
    previously-dormant donation (`setDonationSplit(>0)` / `setRecipient(x)`) without a wired streamer.
  - A story cannot pre-declare a hazard out of scope. The correct disposition is not "not a finding" but
    "known, accepted, and recorded as an operational hazard with safe-config guidance" — which is what this
    entry does. **No Law-1 escalation**: no exploit, no value loss, no unrecoverable state.
- Suggested resolution (non-blocking): have `setBatchMinter`/`setRecipient` optionally probe
  `INudgeStreamer(nudgeStreamer).pendingStream(newSink, token)` — a registered pair is a cheap positive signal —
  or ship a runbook item binding the sink repoint to the registerStream call. `lawImpacted: 3`, confidence high.

### F-03-046 — `NudgeRatchetDelayRelease` still pays the sink directly, outside the streamer

- Type: `faithfulness` (coverage gap) · Law 2 · severity **potential-low / informational**
- Contract: `src/dispatchers/NudgeRatchetDelayRelease.sol:109` — `IERC20(_token).safeTransfer(batchMinter, amount)`
- Spec text (the dependency's stated purpose, adopted by stories 046/047):
  > "Buffers bursty donations per `(batchMinter, token)` and streams them linearly to zero over a configured
  > `duration`, **so that whoever calls `batchMint` right after a burst can no longer capture a
  > disproportionate share of the reward pot.**"
  > — `lib/phoenix-nft-staking/src/NudgeStreamer.sol`, contract NatSpec
- Spec source: dependency NatSpec + story-046/047 commit bodies
- Actual behaviour: `release(amount)` delivers a lump of USDC straight to `batchMinter`, bypassing the streamer
  entirely. All four *other* donors into the same sink are now metered; this one is not.
- Deviation: **strictly speaking, none against the story text** — story-046 scopes itself to "three V2
  dispatchers" and story-047 to `BalancerPoolerV2`, and neither mentions `NudgeRatchetDelayRelease`. Per
  "don't invent criteria", the implementation is faithful. Recorded because the *goal* the two stories import
  from the dependency is only partially achieved: a mempool-visible `release(X)` remains front-runnable /
  back-runnable by a `batchMint` caller, which is exactly the burst-capture the streamer exists to prevent.
- Mitigating context (why this is Low, not Medium): `release` is `onlyReleaser`, so the burst timing is
  admin-chosen rather than attacker-chosen, and the contract is *itself* a rate-control throttle by design —
  a manual one instead of a linear one. The residual is the single-block capture window around each `release`
  tx, which is the same MEV class already triaged as wont-fix on the phoenix-nft-staking side (nudge
  front-running, ledger `858e9e80`). Do **not** collapse this entry into that one — different contract,
  different repo, different fingerprint.
- Suggested resolution: either route `release()` through `collectNudge` too (one-line change, same shape as
  `NudgeRatchet`), or add an explicit NatSpec line stating that this dispatcher is deliberately outside the
  streamer because it already provides admin rate control. `lawImpacted: 2`, confidence high.

---

## Law-1 override checks — outcomes

| Check | Outcome |
|---|---|
| Would faithful execution of story-046's intent introduce an exploit? | **No.** The mandatory-streamer decision creates an availability precondition, not a value path. Assessed in F-02-046: no loss, tx-atomic, owner-recoverable, `config.disabled` backstop at `NFTMinterV2`. Stays Law-3 footgun, does not escalate. |
| Would faithful execution of story-047's intent introduce an exploit? | **No.** The widened catch region only converts three config-failure reverts into parked USDS on the pooler; funds are never sent before the failing leg (the `buyGem` and the `collectNudge` are in the same atomic sub-call), and the parked USDS is re-swept. |
| Does routing through an external, owner-controlled contract create a new value path? | **No.** Every approval is exact-amount and fully consumed in the same call (verified against `NudgeStreamer.collectNudge`, which pulls exactly `amount` via `safeTransferFrom`). No infinite approvals; no residual allowance. |
| Does the fee-on-transfer / decimal story hold across the hop? | **Yes.** `NudgeStreamer.PRECISION` cancels out (`buffer * elapsed / duration`), so 6-dp USDC keeps native-unit fidelity; the `min(accrued, buffer)` cap in `_accrued` prevents over-transfer. Confirmed against `NudgeStreamer.sol:_accrued`. |
| Is `batchMint`'s step-3.5 flush safe against an unregistered token? | **Yes.** `pullPendingStream` returns early on `duration == 0`, so `BatchNFTMinterMultiToken.sol:449`'s blind loop over `_nudgeTokens` cannot revert `batchMint`. |

## Not reported (and why)

- The extra gas / extra external-call dependency of the streamer hop — disclosed by the stories, deliberate,
  Law-3 owner design.
- `NudgeRatchet`'s full-balance sweep and its debt/transfer decoupling — pre-existing, explicitly marked
  accepted in NatSpec, unchanged by this range.
- The `eb15bcd` lib flatten — build/dependency hygiene; no `src/` behaviour changed, no story criteria to test.
- The CLAUDE.md rewrite — removes a dependency *process*, states no behavioural criteria; nothing to conform to.
