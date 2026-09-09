# Spec-Conformance Report (Law-2 Faithfulness) — yield-claim-nft, run 19

**Project:** yield-claim-nft
**Run:** yield-claim-nft-19
**Commit:** `d4cc563`
**Range:** `e4de393..d4cc563`
**Stories under review:** `[story-046]` (commit `1745e83`, tests `ef5fd64` / `7792619`) and `[story-047]` (commit `d4cc563`)

---

## Purpose (Law-2 framing)

This report is the **faithfulness / spec-conformance** channel and is **separate from the QA
bundle**. Under the Three-Law hierarchy, faithfulness to stories is **Law 2** — a feature must do
what the `[story-NNN]` it derives from says — and it is tracked in its own visible channel so a
story deviation is never lost in gas/style noise.

A deviation that *also* carries asset, value, or availability impact gets an H/M label and its own
report, with the `F-XX` record here as its faithfulness cross-reference. **Each such issue is
counted once and cross-referenced, never double-filed.** Two of this run's three records are the
Law-2 framing of findings already carried elsewhere (M-01, L-01, L-03); they are recorded
here for spec-conformance continuity, not as additional findings.

Consistent with prior-run practice (F-01-043 in run-15, F-01-044 in run-17, F-01-045 in run-18), a
**fully-faithful story is still recorded here** — the faithfulness channel documents continuity,
not just deviations. Omitting a clean pass would erase the audit trail that the story was actually
verified.

---

## Verdicts

| Story | Commit | Verdict |
|---|---|---|
| `[story-046]` — route nudge donations through `INudgeStreamer` in three V2 dispatchers | `1745e83` | **FAITHFUL — 5/5 intent items pass** |
| `[story-046]` (tests) | `ef5fd64`, `7792619` | **FAITHFUL** — test claims verified against the suites named |
| `[story-047]` — route `BalancerPoolerV2`'s PSM donation through `INudgeStreamer` | `d4cc563` | **FAITHFUL — 8/8 code items pass**, one documentation deviation (**F-01-047**) |
| untagged | `eb15bcd` | Build/dependency flatten only; no `src/` behaviour change — not a Law-2 subject |

Spec sources used: the four commit bodies (`git log --format=%B`), contract-level NatSpec in
`src/dispatchers/*.sol`, `lib/yield-claim-nft/CLAUDE.md` (whose diff in this range is
dependency-management process only and states no behavioural criteria), and the dependency's own
NatSpec in `lib/yield-claim-nft/lib/phoenix-nft-staking/src/NudgeStreamer.sol`. There is no `docs/`
directory in this repository.

### story-046 — item-by-item conformance

| # | Quoted `[story-046]` intent | Evidence | Conforms |
|---|---|---|---|
| 1 | "NudgeRatchet, Uniboost and PromotionUniV2_Eth each gain a setter-only `nudgeStreamer`" | `NudgeRatchet.sol:63`, `Uniboost.sol:86`, `PromotionUniV2_Eth.sol:155`; no constructor arg in any of the three | PASS |
| 2 | "a `NudgeStreamerUpdated` event" | declared and emitted in all three | PASS |
| 3 | "an owner-gated `setNudgeStreamer` rejecting address(0)" | `onlyOwner` + `require(newStreamer != address(0), …)` in all three | PASS |
| 4 | "The donation `safeTransfer` is replaced (**not fallback-wrapped**) with forceApprove + collectNudge" | no `safeTransfer` donation path survives in any of the three; no try/catch, no legacy fallback; exact-amount `forceApprove` then `collectNudge` | PASS |
| 5 | "Contract-level @dev documents the mandatory streamer, the `NudgeStreamer__NotRegistered` failure mode and the ops wiring order" | all three carry the 3-step ordering block (whitelist → registerStream → setNudgeStreamer) and name `NudgeStreamer__NotRegistered` / `NudgeStreamer__NotWhitelisted` | PASS |

**"Which three?" — resolved.** The three are `NudgeRatchet`, `Uniboost`, `PromotionUniV2_Eth`,
named explicitly in the commit body. `PromotionUniV2_Eth` is *inside* story-046, not an uncovered
fourth; the fourth dispatcher touched in the range, `BalancerPoolerV2`, is covered by story-047.
There is **no uncovered-dispatcher Law-2 gap among the four that changed**. There is, however, a
**fifth donor into the same sink** that was left un-routed — see **F-03-046**.

### story-047 — item-by-item conformance

| # | Quoted `[story-047]` intent | Evidence | Conforms |
|---|---|---|---|
| 1 | "the pooler forceApproves the exact `gemAmt` to the nudgeStreamer and calls `collectNudge(batchMinter, gem, gemAmt)`" | `BalancerPoolerV2.sol:345-347`; `buyGem` recipient changed to `address(this)` (`:335`) | PASS |
| 2 | "add nudgeStreamer field, NudgeStreamerUpdated event and owner-gated setNudgeStreamer(address) rejecting zero, **matching the other three donors**" | identical shape to the story-046 three | PASS |
| 3 | "resolve the gem (USDC) from `ISkyPSM(psm).gem()` rather than a constant" | `:346`; `gem()` exists on `src/interfaces/ISkyPSM.sol:48` | PASS |
| 4 | "guard the whole PSM+streamer body behind `if (gemAmt > 0)` so a dust sweep is a clean no-op instead of a caught revert" | guard present at `:329` | PASS on the code — **see F-01-047** for the un-updated observability contract |
| 5 | "require a non-zero streamer only on the live-donation branch, so a donation-disabled pooler stays deployable and dispatchable without one" | the `require(streamer != address(0))` sits inside `if (gemAmt > 0)`, itself inside `if (donationEnabled)` | PASS |
| 6 | "leave the `try this._psmDonate{} catch` envelope and its parked-USDS bookkeeping untouched" | `_dispatch` catch block byte-identical; still `emit DonationSkipped(remainingUSDS)` | PASS |
| 7 | "document the widened set of caught failures, the quiet-misconfiguration caveat and the ops ordering in contract NatSpec" | contract-level block names all three new swallowed reverts and states the monitoring instruction | PASS |
| 8 | "ATokenDispatcherV2 and all sibling dispatchers untouched; no lib/ changes" | `git show --stat d4cc563` touches exactly `src/dispatchers/BalancerPoolerV2.sol` + two test files | PASS |

#### The catch region is exactly what story-047 describes — not wider

This was checked explicitly, because a silently-widened `try`/`catch` is the classic way a
"documented" swallow grows past its disclosure.

**The `try`/`catch` boundary is unmoved.** It still wraps precisely `this._psmDonate(remainingUSDS)`.
What widened is the *contents* of `_psmDonate`, by **exactly the three reverts the story
enumerates** — `"nudgeStreamer unset"`, `NudgeStreamer__NotRegistered()`, and
`NudgeStreamer__NotWhitelisted()`. No additional external call was pulled inside the envelope beyond
the `gem()` read and the approve/`collectNudge` pair the story announces. The story's disclosure is
complete on this point.

**The silent-USDS-parking consequence IS fully acknowledged.** Both the commit body (the
"quiet-misconfiguration caveat") and the shipped NatSpec state it, together with the recovery
property (the next dispatch re-sweeps, so nothing is lost) and the monitoring instruction. That is
faithful disclosure and is **not** a finding.

#### Throttle-vs-cap mental model: CLEAN (negative result, recorded deliberately)

Going into this run there was a specific joint Law-1 / Law-2 concern: that the dispatchers might
have been written under the belief that `NudgeStreamer` *caps* donation value — i.e. that routing
through it would close the pre-existing nudge over-funding findings on the `phoenix-nft-staking`
side. It does not: the streamer is a **timing throttle**, changing *when* value lands, never *how
much*.

**Every new NatSpec line in all four dispatchers was checked against `NudgeStreamer.sol`'s actual
semantics.** All four describe it consistently and **correctly** as buffering value and releasing it
linearly over time — "buffers … releases it linearly … paid over time rather than in a lump".
**No dispatcher NatSpec, no story line, and no `CLAUDE.md` text anywhere claims it is a cap, a
ceiling, or an anti-over-funding control.** The code was therefore **not** written under a wrong
model of its dependency. There is no Law-2 defect on this axis and no Law-1 concern arising from it.

This negative result is recorded explicitly because the absence of a finding here is itself
load-bearing: it is the difference between "we did not look" and "we looked and it is clean".

> **Carry-forward note for readers (informational, not a finding):** because the streamer changes
> only *when* value lands, **none** of the pre-existing nudge over-funding / aggregate-pot findings
> on the `phoenix-nft-staking` side are closed by stories 046/047. Do not read this range as fixing
> them.

### Law-1 override check — NO escalation

Before blessing a faithful implementation, Law 1 requires confirming that no story's *own intent*
would introduce an exploit. **No escalation was raised this run.**

| Check | Outcome |
|---|---|
| Would faithful execution of story-046's intent introduce an exploit? | **No.** The mandatory-streamer decision creates an availability precondition, not a value path — no loss, transaction-atomic, owner-recoverable, with a `config.disabled` backstop at `NFTMinterV2`. Assessed in F-02-046; stays a Law-3 footgun. |
| Would faithful execution of story-047's intent introduce an exploit? | **No.** The widened catch region converts three config-failure reverts into parked USDS on the pooler; funds are never sent before the failing leg (`buyGem` and `collectNudge` are in the same atomic sub-call) and the parked USDS is re-swept. |
| Does routing through an external, owner-controlled contract create a new value path? | **No.** Every approval is exact-amount and fully consumed in the same call (verified against `NudgeStreamer.collectNudge`, which pulls exactly `amount` via `safeTransferFrom`). No infinite approvals, no residual allowance. |
| Does the decimal story hold across the hop? | **Yes.** `NudgeStreamer.PRECISION` cancels out (`buffer * elapsed / duration`), so 6-dp USDC keeps native-unit fidelity; the `min(accrued, buffer)` cap in `_accrued` prevents over-transfer. |
| Is `batchMint`'s step-3.5 flush safe against an unregistered token? | **Yes.** `pullPendingStream` returns early on `duration == 0`, so `BatchNFTMinterMultiToken.sol:449`'s blind loop over `_nudgeTokens` cannot revert `batchMint`. |

---

## F-01-047 — `DonationSkipped` is still documented as a dust signal, but the dust branch no longer emits it

- **Type:** faithfulness — documented-behaviour / monitoring-fidelity deviation · **Law 2**
- **Severity:** informational (QA-level); **cross-references QA finding L-03** (ledger **L-18**)
- **Contract:** `src/dispatchers/BalancerPoolerV2.sol` — `_psmDonate` (event declaration `:134`, guard `:329`)
- **Story:** `[story-047]` (commit `d4cc563`)
- **Counting:** counted **once**, in the QA bundle as L-03. This record is its Law-2 framing, **not** a second finding.

### Spec text

The event's own NatSpec, present in the tree at `d4cc563` and **unchanged** by this commit:

> "Emitted when a donation attempt is silently skipped (PSM outage / fee spike / **dust**).
> `usdsParked` USDS stays on the contract for the next dispatch to retry."

The **same commit's** new contract-level NatSpec, giving operators their monitoring instruction:

> "This means a **streamer misconfiguration is quiet**: watch `DonationSkipped` and the contract's
> USDS balance."

And the authorising story bullet:

> "guard the whole PSM+streamer body behind `if (gemAmt > 0)` so a dust sweep is a clean no-op
> instead of a caught revert"

### Shipped behaviour

Under `e4de393`, `require(gemAmt > 0, "BalancerPoolerV2: donation dust")` reverted into the caller's
`catch`, which emitted `DonationSkipped(remainingUSDS)`. Under `d4cc563` the `if (gemAmt > 0)` guard
returns normally, so **a dust sweep emits nothing at all** — no `DonationSkipped`, no
`BatchDonatedViaPSM`.

### The deviation

The *code change itself is story-authorised* — bullet 4 asks for "a clean no-op instead of a caught
revert" and that is exactly what shipped. This is **not** an unauthorised behaviour change.

The deviation is that **the resulting event loss is acknowledged nowhere**. The contract's own
documented observability contract was not updated in the same commit, and the same commit **doubles
down** by telling operators to monitor `DonationSkipped` — at precisely the moment that event became
the sole signal for a widened failure set. The `DonationSkipped` NatSpec still advertises **dust**
as a trigger it can no longer signal. Dust-driven skips are now invisible in logs while the
documentation says otherwise.

### Impact

Bounded and low. The condition requires `usdsAmount * WAD / (conv * (WAD + tout))` to floor to zero
— a sub-1e-6-USDC sweep. The USDS parks and is re-swept, so **no value is at risk**. This is a
monitoring-fidelity defect, not a loss path.

### Suggested resolution

Either emit `DonationSkipped(usdsAmount)` from the `else` of the guard, or strike "dust" from the
event's NatSpec and say so in the contract-level ops note. Confidence: high.

---

## F-02-046 — a story cannot pre-declare a hazard out of scope: the mandatory-streamer NatSpec's "NOT an audit finding" is correct for deploy-ordering, over-broad for repoint

- **Type:** story-unsafe (Law-1 override check applied; `securityEscalation: false` after assessment) · **Law 3** disposition
- **Severity:** accepted **operational hazard** (Law-3 footgun); **cross-references QA finding L-01** (ledger **L-16**), which is now the sole security-side carrier — the Medium drafted as `M-02` was **withdrawn** and folded into `L-01` (see `M-02.md`)
- **Contracts:** `src/dispatchers/NudgeRatchet.sol:155-160`, `src/dispatchers/Uniboost.sol:246-250`, `src/dispatchers/PromotionUniV2_Eth.sol:392-396`
- **Story:** `[story-046]` (commit `1745e83`)
- **Counting:** the availability impact is counted **once**, as QA `L-01` (ledger `L-16`). It was previously counted as `M-02`; that Medium was withdrawn on 2026-07-25 when its stranding argument was refuted by mint atomicity, and `L-01` absorbed it. This record is the Law-2/Law-3 framing and remains a single, non-double-counted cross-reference.

### Spec text

`[story-046]`, shipped verbatim into all three contracts' NatSpec:

> "If the streamer is set but ops forgot `registerStream(batchMinter, _token, duration)` on it,
> every `dispatch` reverts `NudgeStreamer__NotRegistered()`. **This is the accepted consequence of
> the mandatory-streamer decision, NOT an audit finding.** … Repointing `batchMinter` to an address
> with no registered stream re-arms the same failure mode; register the new pair first."

### Assessment of the "NOT an audit finding" claim, on its merits

A story is a specification of intent, not a scoping authority over the audit. The claim was
therefore assessed rather than accepted, and it **splits**.

**The revert path is confirmed.** `NFTMinterV2._executeMint` (`src/NFTMinterV2.sol:191`) calls
`dispatch` with **no try/catch**, so a `NudgeStreamer__NotRegistered()` bubbles all the way out and
**every user mint at that dispatcher index reverts**. `NudgeRatchet` has no donation-disable switch
and no `bal == 0` escape once it holds any balance, so the brick is total for that index.

**No value is at risk.** The user's `safeTransferFrom` of `price` happens inside the same reverting
transaction (`NFTMinterV2.sol:183`), so nothing is stranded and no NFT is minted against a lost
payment. Recovery is cheap in principle: the minter owner can set `config.disabled` on the index, or
the streamer owner can call `registerStream`. Availability-only, owner-fixable, no residual state
damage.

**Deploy-ordering case — the claim is CORRECT (Law 3, suppress).** A freshly deployed dispatcher
with `nudgeStreamer == address(0)` fails **loudly and immediately** on the very first dispatch,
before any user traffic. That consequence is obvious to a competent operator. Not a finding.

**Repoint case — the claim is NOT correct (Law 3, in scope as a footgun).** `setBatchMinter(new)` /
`setRecipient(new)` on a **live** dispatcher **succeeds silently** and arms
`NudgeStreamer__NotRegistered()` on every subsequent user mint. Clearing it requires calls on **two
other contracts** — `batchMinter.setNudgeTokenWhitelist(token, true)`, then
`NudgeStreamer.registerStream(...)`, the latter `onlyOwner` on a contract in a **different
repository** (`phoenix-nft-staking`) that may not share the dispatcher's owner key. The dispatcher
exposes **no view and no guard** that would surface the missing registration before it bites, and
`setBatchMinter` does not check it. **A competent, non-malicious owner would be surprised** — which
is exactly the Law-3 footgun test. The same shape applies to `Uniboost` / `PromotionUniV2_Eth` when
an owner *enables* a previously-dormant donation (`setDonationSplit(>0)` / `setRecipient(x)`)
without a wired streamer.

### Disposition

**No Law-1 escalation** — no exploit, no value loss, no unrecoverable state. But the correct
disposition is **not** "not a finding": it is **known, accepted, and recorded as an operational
hazard with safe-config guidance**, which is what this entry does. The blanket NatSpec disclaimer is
retained as owner intent for the deploy-ordering half and **overridden for the repoint half**.

### Suggested resolution (non-blocking)

Have `setBatchMinter` / `setRecipient` optionally probe
`INudgeStreamer(nudgeStreamer).pendingStream(newSink, token)` — a registered pair is a cheap
positive signal — or ship a runbook item binding every sink repoint to the corresponding
`registerStream` call. Confidence: high.

---

## F-03-046 — a fifth donor was left un-routed: `NudgeRatchetDelayRelease` still pays the sink directly

- **Type:** faithfulness — **coverage gap** (not a literal deviation) · **Law 2**
- **Severity:** informational; this is the **Law-2 framing of security finding M-01**
- **Contract:** `src/dispatchers/NudgeRatchetDelayRelease.sol:109` — `IERC20(_token).safeTransfer(batchMinter, amount)`
- **Stories:** `[story-046]` (commit `1745e83`) and `[story-047]` (commit `d4cc563`)
- **Counting:** counted **once**, as **M-01**. **Do NOT double-count as a second security finding.**

### Spec text

`[story-046]` scopes itself to **"three V2 dispatchers"** — `NudgeRatchet`, `Uniboost`,
`PromotionUniV2_Eth` — and `[story-047]` adds a fourth, `BalancerPoolerV2`. Neither mentions
`NudgeRatchetDelayRelease`.

The **purpose** both stories import from the dependency, per `NudgeStreamer`'s contract NatSpec
(`lib/phoenix-nft-staking/src/NudgeStreamer.sol`):

> "Buffers bursty donations per `(batchMinter, token)` and streams them linearly to zero over a
> configured `duration`, **so that whoever calls `batchMint` right after a burst can no longer
> capture a disproportionate share of the reward pot.**"

### Shipped behaviour

`release(amount)` delivers a **lump** of USDC straight to `batchMinter`, bypassing the streamer
entirely. All four *other* donors into the same sink are now metered; this one is not.

### The deviation

**Strictly against the story text, there is none.** Story-046 scopes itself to three named
dispatchers and story-047 to `BalancerPoolerV2`; neither names `NudgeRatchetDelayRelease`. Per
"don't invent criteria", the implementation is faithful to what was asked.

It is recorded here because **the goal the two stories import from the dependency is only partially
achieved**. A mempool-visible `release(X)` remains front-runnable / back-runnable by a `batchMint`
caller — which is precisely the burst-capture the streamer exists to prevent. The stated purpose was
adopted; the coverage was not completed.

### Empirical result (why this carries a security label as M-01)

This is not a theoretical gap. The M-01 PoC (`reports/yield-claim-nft/19/pocs/run19-Tier3Nudge.patch`,
contract `Run19_T4_DelayReleaseBackrun`) captured a **50,000 USDC lump at 100% in the same block**,
while the streamed contrast arm captured **0**. The un-routed leg reproduces exactly the behaviour
the routed legs now prevent.

### Mitigating context

`release` is `onlyReleaser`, so the burst *timing* is admin-chosen rather than attacker-chosen, and
the contract is *itself* a rate-control throttle by design — a manual one instead of a linear one.
The residual is the single-block capture window around each `release` transaction.

> **Do not collapse this into the `phoenix-nft-staking` nudge-front-running entry (ledger
> `858e9e80`, wont-fix).** Different contract, different repository, different fingerprint. The MEV
> class is related; the finding is not the same finding.

### Suggested resolution

Either route `release()` through `collectNudge` as well (a one-line change, same shape as
`NudgeRatchet`), or add an explicit NatSpec line stating that this dispatcher is **deliberately**
outside the streamer because it already provides admin rate control. Confidence: high.

---

## Not reported (and why)

Recorded so that silence is not misread as an unchecked area.

- The extra gas and extra external-call dependency introduced by the streamer hop — disclosed by the
  stories, deliberate, Law-3 owner design.
- `NudgeRatchet`'s full-balance sweep and its debt/transfer decoupling — pre-existing, explicitly
  marked accepted in NatSpec, unchanged by this range.
- The `eb15bcd` lib flatten — build/dependency hygiene only; no `src/` behaviour changed, no story
  criteria to test.
- The `CLAUDE.md` rewrite — removes a dependency *process*; states no behavioural criteria, so there
  is nothing to conform to.

---

## Summary

| Record | Story | Verdict | Severity / channel | Cross-ref | New/Carried |
|---|---|---|---|---|---|
| **story-046** | `1745e83` | **FAITHFUL — 5/5 intent items** | — | — | verified this run |
| **story-047** | `d4cc563` | **FAITHFUL — 8/8 code items**, 1 doc deviation | — | — | verified this run |
| **F-01-047** | story-047 | Documentation / monitoring-fidelity deviation | informational | QA **L-03** (ledger L-18) | NEW |
| **F-02-046** | story-046 | Story's blanket "NOT an audit finding" over-broad for the repoint case | accepted operational hazard | QA **L-01** (ledger L-16) — `M-02` withdrawn, folded into `L-01` | NEW |
| **F-03-046** | story-046/047 | Coverage gap — fifth donor un-routed | informational (Law-2 framing of a Medium) | **M-01** | NEW |
| F-01-045 | story-045 | FULLY FAITHFUL across 8 intent items; Law-1 safe | open (info) | — | **carried (full copy below)** |
| F-01-043 | story-043 | FAITHFUL across 6 ACs | open (info) | — | **carried (full copy below)** |

**Headline:** both stories in this range are faithful. The catch region in `BalancerPoolerV2` is
exactly what story-047 describes and no wider, and the silent-USDS-parking consequence is fully
acknowledged in both the commit body and the NatSpec. The throttle-vs-cap mental model is **clean**
— the code was not written under a wrong model of `NudgeStreamer`. **No Law-1 escalation:** no
story's own intent introduces an exploit. The three records above are a documentation deviation, an
over-broad in-story scope disclaimer, and a coverage gap — the latter two cross-referencing findings
already counted as QA `L-01` (formerly `M-02`, withdrawn and folded in) and M-01.

---
---

# Carryover — prior open faithfulness records (verbatim full copies)

The two prior faithfulness records below remain **open** in the ledger and were **not disturbed by
stories 046/047**. Under Law 1 an open finding is never dropped from view and never reduced to a
pointer, so each is reproduced **in full** rather than linked. Line numbers and links were accurate
at their originating commits; re-verify against current HEAD before acting.

---

## [C] F-01-045 — story-045 PromotionUniV2_Eth rework is FULLY FAITHFUL and Law-1 safe

> **Carryover — copied in full from `yield-claim-nft-18`.** This record originally appeared in
> **audit 18**, was **not triaged**, and is **still valid** as of audit 19. Stories 046/047 did not
> touch `PromotionUniV2_Eth`'s `pool()` split/burn/reserve logic. Triage it with
> `/ledger yield-claim-nft`.

- **Original label:** F-01-045 (run `yield-claim-nft-18`)
- **Status:** open (informational faithfulness record; NOT a security finding)
- **Original fingerprint:** `25212e80…`
- **First seen:** yield-claim-nft-18 · **Still present as of:** yield-claim-nft-19
- **Location:** `src/dispatchers/PromotionUniV2_Eth.sol` (`pool`)
- **Original report:** [reports/yield-claim-nft/18/submissions/spec-conformance.md](../../18/submissions/spec-conformance.md)

*The text below is a verbatim copy of the original record.*

---

- **Status:** open (informational faithfulness record; NOT a security finding)
- **Contract:** `src/dispatchers/PromotionUniV2_Eth.sol` (`pool`)
- **Story:** `[story-045]` (commit a7ab9db)
- **Fingerprint:** `25212e80…`
- **Verdict:** **FAITHFUL and Law-1 safe** across all 8 intent items.

### Story text

The `[story-045]` commit (a7ab9db) directs the PromotionUniV2_Eth rework to a
**"60/30/10 split, burn-half phUSD, WBTC insurer reserve."**

### Behavior vs. intent — item-by-item conformance

| # | story-045 intent | Contract evidence | Conforms |
|---|---|---|---|
| 1 | **60/30/10 pool split** | split computed at `PromotionUniV2_Eth.sol#L383-L385` | ✅ |
| 2 | **Burn half of the pooled phUSD leg** | half-burn at `#L395-L396` | ✅ |
| 3 | **WBTC insurer-reserve leg** | reserve wiring at `#L108`, `#L162`, `#L267`, `#L275` | ✅ |
| 4 | **Settable `_legC` path** | insurer/reserve leg settable | ✅ |
| 5 | **Insurer role** | insurer role present and enforced on the reserve leg | ✅ |
| 6 | **Consolidated `Pooled` event** | single consolidated `Pooled` emission | ✅ |
| 7 | **`rescueERC20` WBTC-exclusion** | WBTC excluded from rescue at `#L521` (reserve cannot be swept out via rescue) | ✅ |
| 8 | **Donation-split computed on gross** | donation-split taken on the gross amount, not net | ✅ |

All eight items implement the story action exactly as written. There is **no story deviation** and
**no Law-1 concern** — the reworked flow is backing-accretive and intra-protocol, with no theft or
drain vector introduced by the rework.

### Empirical clearance (coverage caveat CLEARED)

The Tier-3 **fork run executed 70/70 pass** and all four rework invariants — **60/30/10 split**,
**burn-half**, **WBTC-reserve**, and **LP-accrual** — were **empirically confirmed on a mainnet
fork** (block 25,550,000). The faithfulness verdict therefore rests on direct on-chain-fork
observation, not static reasoning alone.

> **Separate coverage note (not a faithfulness defect):** the run-16 **stateful-fuzz** harness is
> stale — it calls the pre-story-045 5-arg `pool()` and no longer compiles against the 6-arg
> signature, so Medusa/Foundry invariant *campaigns* do not exercise the reworked flow. That gap is
> tracked as **Q-17** in the QA bundle. It does not weaken this record: the deterministic fork unit
> tests provide direct coverage of the same invariants this run.

### Faithfulness caveats (carried alongside the FAITHFUL verdict)

**Caveat 1 — carried footgun (L-13 / F-01-044), UNCHANGED by story-045.**
The whole-balance ETH sweep in `_legB` plus the open `receive()` (Leg B, `#L453`; open
`receive()`, `#L533`) **survives the story-045 rework unchanged**. Story-faithfulness confirms the
rework did not touch that path. Both twins remain **wont-fix** — the owner has affirmatively
declared the whole-balance sweep an intended feature — and the framing is **sweep +
`rescueETH`-front-run**, *not* accidental-send; Tier-3 INV-4 fork-proved the swept value only ever
reaches protocol-owned LP (non-theft). See F-01-044 and the L-13 carryover stub.

**Caveat 2 — NatSpec under-explains the burn's dual role (cross-ref Q-16).**
The story **action** ("burn half") is faithfully implemented (item 2 above), and the NatSpec's
*justification* — that the burn exists "so pooled values match" — is **correct**, not misleading:
because Leg A is deliberately over-sized to **60%** of capital, burning half of it is **precisely**
what pulls the pooled phUSD from 60% down to the ~30% that value-matches the ~30% pooled-promotion
leg, so the burn genuinely **is** part of the value-match mechanism. What the NatSpec **omits** is
that this same burn is simultaneously an intentional **~30%-of-every-`pool()`-capital permanent
deflationary spend** that produces zero LP. The **story is faithful; the in-code rationale is
correct but under-explains** (it documents the value-match half of the burn's role and is silent on
the deflationary-spend half). This is recorded here in the Law-2 channel for visibility, and is the
basis for **Q-16** in the QA bundle — retained so a maintainer, reading only the value-match half,
does not delete or resize the burn as "redundant to the leg sizing" (which would break both the
value-match and the intended deflationary economics). Fork-confirmed: 5,000e6 USDC → 1,359e18 phUSD
burned, backing-accretive and Law-1 clean.

### Disposition

**KEEP visible** as a faithfulness / spec-conformance record (informational), consistent with
F-01-043 / F-01-044. **Do NOT** promote to a security finding; **do NOT** bury.

---

## [C] F-01-043 — Intended debt/release decoupling (story-unsafe note; RESOLVED out-of-scope)

> **Carryover — copied in full from `yield-claim-nft-15`.** This record originally appeared in
> **audit 15**, was **not triaged**, and is **still valid** as of audit 19.
> `NudgeRatchetDelayRelease.sol` *was* touched conceptually this run — see **F-03-046 / M-01**, a
> distinct issue about the same contract's `release()` path — but the decoupling record below is
> unchanged. Triage it with `/ledger yield-claim-nft`.

- **Original label:** F-01-043 (run `yield-claim-nft-15`)
- **Status:** open (informational faithfulness record; NOT a security Medium)
- **Original fingerprint:** `6753c76b…`
- **First seen:** yield-claim-nft-15 · **Still present as of:** yield-claim-nft-19
- **Location:** `src/dispatchers/NudgeRatchetDelayRelease.sol` (`_dispatch` / `release`)
- **Original report:** [reports/yield-claim-nft/15/submissions/spec-conformance.md](../../15/submissions/spec-conformance.md)

*The text below is a verbatim copy of the original record.*

---

**Classification:** story-unsafe note, **NOT** a security finding. Faithful code;
the question is about the story's *own* design, escalated under Law 1 and resolved.

**Story / NatSpec intent text deviated-toward**

The contract's NatSpec header makes the decoupling an explicit, accepted design
property (`src/dispatchers/NudgeRatchetDelayRelease.sol:20-36`):

> KNOWN / ACCEPTED DESIGN PROPERTIES — these are intentional; DO NOT re-flag as findings:
>   * Debt/release timing is DECOUPLED ON PURPOSE. phUSD mint-debt accrues (and the
>     downstream staker may realise phUSD via the hook's `pull()`) at DISPATCH time, while
>     the USDC backing it can still be sitting on this contract, un-released. There is
>     therefore an intended, admin-controlled window in which phUSD has been realised but
>     the corresponding USDC has NOT yet reached the batchMinter. This is the whole point
>     of the contract (rate-controlled release), not an accounting bug.
>   * No unbacked phUSD is created by this. The USDC that backs the accrued debt is HELD on
>     this contract from dispatch onward; `release` only RELOCATES that existing backing to
>     the batchMinter (it never mints or burns), so total system backing is conserved at
>     all times. The only thing the release schedule changes is WHERE the backing sits
>     (dispatcher vs. sink), never WHETHER it exists.
>   * Release rate is a trusted admin lever. `release` is gated to an owner-managed
>     `releasers` whitelist; the owner deliberately controls how fast held USDC flows to
>     the batchMinter. Slow/withheld releases are an operational choice, not a liveness bug.
>   * `rescueERC20` can withdraw held `_token` (USDC). This is an accepted owner power with
>     the same trust assumption as `setBatchMinter`; see its NatSpec.

**Actual behavior** (`_dispatch` L131-143 + `release` L108-111)

The implementation faithfully realises the decoupling: mint-debt accrues against
`amount` in `hook.onDispatch` at dispatch time (base `ATokenDispatcherV2.dispatch`,
unchanged), while the backing USDC is held on the dispatcher and can only be moved
to the `batchMinter` sink by a whitelisted releaser calling `release(amount)` at an
admin-controlled rate. There is no implementation-vs-intent gap.

**The Law-1 escalation that was raised**

story-faithfulness flagged the *story's own* safety argument. The NatSpec rests on
"total **system** backing is conserved" (USDC exists somewhere), but the solvency
invariant relevant to a holder who has *realised* phUSD is "the **sink** the claim
redeems against is funded when the claim is realised." During the intended hold
window, phUSD can be realised via `hook.pull()` while the `batchMinter` sink holds
**0 USDC**, and the dispatcher-held USDC is unreachable to anyone but the releaser —
a transient (and, if releases lag, unbounded) under-funded-sink window set by an
admin lever. This is **not** the `rescueERC20` owner-footgun (an acknowledged Law-3
owner power, out of scope): the window exists under *normal* operation of the core
feature even with a benign releaser, because realisation and sink-funding are
separated by design.

**econ-scanner resolution — OUT OF SCOPE (DEDUP-001)**

econ-scanner resolved the escalation: **no in-scope contract couples
USDC-at-`batchMinter` to phUSD minting or redemption.** The phUSD redemption-backing
model is the **external** one already suppressed in the ledger as **DEDUP-001
(owner-driven external backing / unbacked-phUSD)**. The under-funded-sink concern
only bites if phUSD redeems specifically against the `batchMinter` sink's
instantaneous USDC balance; within the audited boundary it does not, and prior
Tier-3 work (run-13) showed the NudgeRatchet/hook path runs ≥2:1 over-backed with no
over-mint (double-mint/under-backing REFUTED). The implementation faithfully
realises the story, and the story's own design is acceptable **within the audited
boundary**. Recorded here, not promoted to a Medium.
