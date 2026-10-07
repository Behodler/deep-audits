# Carryover Spec-Conformance Report — originating audit 19 (carried into yield-claim-nft-21)

> Pruned copy of `yield-claim-nft/reports/19/submissions/spec-conformance.md` (commit `d4cc563`), carried at `267660b`. Retained (still `open`): **F-01-047, F-02-046, F-03-046**. Removed: none; verdict tables, "Not reported", summary and the run-19 carryover block (F-01-045/F-01-043, carried in their own files) not copied.
> F-01-047 (BalancerPoolerV2) is deliberately **not** closed by the run-21 F-01-048 documentation fix on UniPoolerV2 (story-050 scope).
> Relative links resolve from the original report's directory. *Text below each heading is a verbatim copy; the `Carryover status` block is added by the run-21 qa-bundler.* These are faithfulness (Law-2) records: they belong to the spec-conformance channel, not the QA bundle, and are carried here only so the run-21 carryover set is complete per `ledger-reconciliation.json`.

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

> **Carryover status (run 21, `267660b`).** Ledger **F-01-047** · fingerprint `5d6538f76fbe2018c1a1bbcd0bbc4130e730b3f49d2951d3c02e1a06ed8bae67` · status **`open`** · severity `informational` · first seen `yield-claim-nft-19` · last seen `yield-claim-nft-20` · re-observed by run-21 inputs: **no (not re-raised; absence of a re-raise is not a fix)**.

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

> **Carryover status (run 21, `267660b`).** Ledger **F-02-046** · fingerprint `26baeb3e77d7ae79803b614ddabc1f382a525fcc532b9513532844df6a6b1ea6` · status **`open`** · severity `informational` · first seen `yield-claim-nft-19` · last seen `yield-claim-nft-19` · re-observed by run-21 inputs: **no (not re-raised; absence of a re-raise is not a fix)**.

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

> **Carryover status (run 21, `267660b`).** Ledger **F-03-046** · fingerprint `38151cebd72ff17b57d3f901f2e20ad14d6128338b5b18f38efbd12ce21fa2ac` · status **`open`** · severity `informational` · first seen `yield-claim-nft-19` · last seen `yield-claim-nft-19` · re-observed by run-21 inputs: **no (not re-raised; absence of a re-raise is not a fix)**.
