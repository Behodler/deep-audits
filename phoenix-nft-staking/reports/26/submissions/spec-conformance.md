# Spec Conformance (Law 2) — `phoenix-nft-staking` run 26

**Target:** `lib/phoenix-nft-staking` @ `9611312` (`96113129b57ebf7a7c45c65996f792a92c71cdce`)
**Range audited:** `5015f1b..9611312`, 13 commits · **Mode:** regression
**Cross-repo verification point:** `yield-claim-nft` @ `d4cc563`
**Date:** 2026-07-30

## Why this report is the run's primary deliverable

Run 26 produced **0 High and 0 Medium**. Every substantive result of the run is a Law-2
finding: three stories landed in the audited range, and all three deviate from their own
documents — in each case by *asserting a guarantee the code does not establish*, or by
*clearing a dependency that the change did in fact move*. Two of the three stories were
themselves written to remove exactly that class of defect. That is the finding of the run,
and it is recorded here rather than as an appendix to the QA bundle.

Three of the five sections below are **dual-routed**: the same underlying defect also has a
code-side limb in `qa-report.md` (`Q-01`, `L-04`, `Q-02`, `L-06`). The dual routing is
deliberate and the ledger carries one entry per finding — the Law-2 limb grades the *story*,
the QA limb grades the *code*. Neither may be collapsed into the other.

**Stories checked** (documents are read-only, under `~/code/product-owner/stories/nft-staking/`):

| Story | Document | State folder | Commits |
|---|---|---|---|
| story-030 | `complete/documentation/030-documentation-accuracy-stop-asserting-unenforced-guarantees.md` | `complete` | 11 (`a72e650`..`d2506c1`) |
| story-031 | `complete/audit-21/031-nudgestreamer-collectnudge-balance-delta-credit.md` | `complete` | 1 (`2ba764e`) |
| story-032 | `review/whitelist-liberation/032-remove-payment-token-whitelist-gate.md` | **`review`** | 1 (`9611312`, HEAD) |

**Findings:** `F-01-031`, `F-02-032`, `F-03-031`, `F-04-030` (Low) and `F-05-032`
(Informational). No `story-unsafe` finding — see §6.

---

## F-01-031 — story-031's own acceptance criterion instructed the unconditional pooled-custody guarantee, and its own review pass caught the defect without amending the shipped text

- **Severity:** Low · **Story:** story-031 · **Doc state:** `complete`
- **Story document:** `~/code/product-owner/stories/nft-staking/complete/audit-21/031-nudgestreamer-collectnudge-balance-delta-credit.md`
- **Location:** `src/NudgeStreamer.sol:250-265` (`_accrued` NatSpec, primary) and `src/NudgeStreamer.sol:55-62` (contract-level NatSpec)
- **Fingerprint:** `c4c09ae36671aad5a5f69c9062480f74f0b311d314991c58076acd982082cb5b`
- **Cross-reference:** `Q-01` in `qa-report.md` (the code limb of the same text)

This is the strongest finding of the run, because the root cause is not a slipped comment in
an implementation. **The story's own acceptance criterion asked for the over-claim.**

### VERBATIM QUOTE — story-031, Documentation checklist, `031-…md:168`

> - [x] Correct the false NatSpec at `NudgeStreamer.sol:192-194`: the buffer cap is
> **per-stream** and guarantees nothing about pooled per-token custody. State the real
> invariant that now holds (`Σ buffer_i <= balanceOf(this)`, established at the credit site)
> and where it is established.

The next checklist line compounds it (`031-…md:169`):

> - [x] Review contract NatSpec `:44-53` — the "dust always accrues in the protocol's favour"
> claim is now TRUE by construction; confirm the wording matches and amend if it overclaims.

The story's Background states *why* the story exists, and the standard it holds itself to
(`031-…md:24-32`):

> **Per this repo's standing principle, falsely-exhaustive documentation raises severity
> rather than lowering it — it is the reason an operator would never think to check.**

### VERBATIM QUOTE — story-031's own review pass, non-blocking Issue 1, `031-…md:421-427`

> 1. **Invariant statement has no rebase carve-out.** `src/NudgeStreamer.sol:55-62`, the
> `_accrued` NatSpec at `:248-265`, and `docs/multi-token-nudge.md:477` all state
> `Σ buffer_i <= balanceOf(this)` unconditionally. A token that shrinks
> `balanceOf(streamer)` *after* credit breaks it again — nothing at the credit site can
> prevent that. Meanwhile §4.4's own heading still names rebasing tokens. **The fix defends
> the credit site, not post-credit balance shrinkage.**

The observation was recorded as non-blocking and the story shipped without amending the
NatSpec, so the over-claim is live at HEAD.

### ⚠ SCOPE OF THIS FINDING — the rebase mechanism above is NOT its basis

Review Issue 1, quoted directly above, frames the gap as a **rebase carve-out**: post-credit shrinkage
of `balanceOf(streamer)`, which is a **token-side property**. **That mechanism is C4-invalid
standalone** under the non-standard-ERC20 rule, and **this finding does not rest on it.** The quote is
reproduced because it is the evidence that the story's own review *caught* the defect — its
value here is evidentiary, not mechanical. Were the rebase framing imported as this finding's
substance, `F-01-031` would become a weird-token finding and would be dismissible under the very rule
the validity check exists to enforce.

`F-01-031` is pinned to two **token-independent** limbs, and to nothing else:

1. **The documented basis for the invariant is wrong.** The acceptance criterion at `:168` instructed
   an **unconditional** claim, attributed to a **construction at one site**, about a property that is
   in fact a **two-site conjunction** — the measured-receipt credit in `collectNudge` *and* the
   per-stream cap in `_accrued` that bounds each `_settle` debit. "By construction at one site" is not
   why the invariant holds. That error is present in the shipped text at named lines, requires no token
   property to observe, and is the same defect `Q-01` carries on the code side.
2. **The story's own review caught it and the story shipped unamended** — neither the NatSpec nor the
   acceptance criterion was corrected. That is a **process** defect, not an implementer slip, and it is
   the reason this is a Law-2 finding at all.

Everything below is to be read against those two limbs. Where post-credit erosion is mentioned, it is
illustrating *what the single-site framing fails to describe*, never asserting a reachable exploit.

### Actual behaviour at `src/NudgeStreamer.sol:250-265`

```solidity
///          Σ buffer_i  <=  IERC20(token).balanceOf(address(this))
///
///      summed over every `(batchMinter, token)` pair on one token. That
///      invariant is established at ONE site — the balance-delta credit in
///      `collectNudge`, which credits `min(received, amount)` measured
///      across the pull.
```

and at `src/NudgeStreamer.sol:55-62`:

```solidity
///         That direction holds at the credit site too, and by construction
///         rather than by convention. `collectNudge` credits the MEASURED
///         receipt capped at the quoted amount, ... The
///         resulting invariant — `Σ buffer_i <= balanceOf(this)` over every
///         pair on one token — is what makes the per-stream cap in `_accrued`
///         affordable out of the pooled per-token balance.
```

### The gap

Both statements are unconditional, and both attribute the invariant to a *construction* at a
*single site*. The credit at `src/NudgeStreamer.sol:193-196` is a **one-shot measurement
bracketing a single `transferFrom`**. It is therefore **one-directional**: it closes the
fee-underpay direction (a taxed token credits less than was sent, never more) and says
nothing about erosion of `balanceOf(streamer)` *after* credit — negative rebase,
burn-on-hold, a token zeroing a blacklisted holder, a token-side admin sweep. "Established at
ONE site" describes where the *measurement* happens, not what sustains the invariant over
time; and "by construction rather than by convention" is precisely the sentence that would
stop a maintainer from checking.

### What this finding does NOT claim

**It does not claim the code is broken.** The invariant does in fact hold for plain ERC20s,
and that was machine-confirmed this run:

- **Fuzzing:** no counterexample across **~640,000 fuzzed calls on the Foundry engine** (5 invariants x 128,000 calls, 0 reverts, anti-vacuity tripwire live). [CORRECTED 2026-07-30: an earlier draft said "452,000+ calls on two independent engines"; the Medusa leg is **retracted as not substantiated** - see `tier3/invariants.md` verification note. Single engine, plus the reproduced Halmos proof.]
  with the harness demonstrably able to fail (the 1-wei over-credit mutant is caught)
  (`tier3/invariants.md`).
- **Symbolic:** Halmos **proved** the 2-stream aggregate inductively over a very wide domain
  (values < 2^96, rates < 2^128, elapsed < 2^40, symbolic durations), including the
  **no-brick property** — `pullPendingStream` cannot revert for insufficient custody. The
  3-stream case is proved only for values < 2^32 and is **INCONCLUSIVE-timeout** above that;
  `N > 2` in general rests on a hand-checked reduction argument, not a machine proof
  (`tier3/symbolic.md` §7). A timeout is not evidence of safety and is not treated as one.
- **⚠ THE `N > 2` RESIDUAL IS TRACKED AS A CODE INVARIANT, NOT AS A SOLVER LIMITATION
  (`WATCH-26-05`).** "Halmos timed out above 2^32 for N ≥ 3" describes the tool, not the contract,
  and decays the moment the solver, the bounds, or the version changes. The property the hand-checked
  reduction **actually depends on** is structural and watchable:

  > **`NudgeStreamer` must never read or write more than one `Stream` struct per state transition,
  > and must never introduce aggregate state.** Any cross-stream read, any loop over streams, or any
  > per-token running total **invalidates the `N > 2` reduction** and **demotes INV-1 to
  > proved-at-2-streams-only.**

  It holds at `9611312` — every write site touches exactly one `Stream`, which is why the aggregate
  follows from the per-stream property by summation and why two machine-proved streams generalise at
  all. Watching that invariant is checkable from a diff; re-checking a solver timeout is not. This
  does not discharge the owed machine proof of the ≥ 3-stream aggregate at wide bounds — it makes the
  reduction's precondition auditable in the meantime.

The defect is that the documented **basis** for the guarantee is wrong — and that is the whole of
the claim. "By construction at one site" is not why the property holds: what holds it is a
**conjunction of two sites**, the measured-receipt credit *and* the per-stream cap in `_accrued`, and
naming one of them as sufficient is substantively incomplete on a property the contract's own text
calls load-bearing. A maintainer trusting the shipped sentence would conclude no guard is needed and
would not add one they may later require — and falsely-exhaustive documentation raises risk even while
the underlying property is currently true. That principle is the repo's own, and it is the principle
story-031 invoked to justify its own existence.

**Restated once more so it cannot be mis-cited:** the finding is the *documented-basis error*, which is
token-independent. It is **not** "the invariant can be broken by a rebasing token". The correct
remediation is to state the real basis (credit **plus** the `_accrued` cap), or add the clamp the text
implies — neither of which is a weird-token defence.

### Severity note

Walked back from the faithfulness agent's `potential-medium` to **Low**. The Medium reading
rested on a reachable brick chain; that chain was killed by the Tier-3 work above and its
residual is carried separately at Low by `L-01`. The Medium premise no longer exists.

### Recommendation

**State the real basis at both sites**: the aggregate `Σ buffer_i <= balanceOf(this)` is sustained by a
**conjunction** — the measured-receipt credit in `collectNudge` **and** the per-stream cap in
`_accrued` that bounds each `_settle` debit — **or** add the clamp the current text implies. Do not
describe it as established at a single site, and do not describe it as holding "by construction". A
secondary, optional refinement is to scope the credit site to the direction it actually closes
(under-delivery *during* the pull); that is a completeness nicety, **not** the finding. Close story-031
review Issue 1 rather than leaving it recorded-but-unactioned, and **fix the acceptance criterion at
`031-…md:168`** so the same wording is not re-instructed by the next story that cites it.

---

## F-02-032 — story-032 twice clears `NudgeStreamer` as "unaffected"; the mechanism claim is true and the conclusion is false

- **Severity:** Low · **Story:** story-032 · **Doc state:** **`review`** (see `F-05-032`)
- **Story document:** `~/code/product-owner/stories/nft-staking/review/whitelist-liberation/032-remove-payment-token-whitelist-gate.md`
- **Location:** `src/BatchNFTMinterMultiToken.sol:328-336` (`setNudgeTokenWhitelist`); consequence sites `src/NudgeStreamer.sol:127`, `src/BatchNFTMinterMultiToken.sol:479`, `:532-534`
- **Fingerprint:** `400ed7f55ee0d79c93087b0c42840ee38849d9abfee6c970e8d37c477439531f`
- **Cross-reference:** `L-04` in `qa-report.md` (the code limb); `F-05-032` (same story, still open)

### First: the deviation is NOT the gate removal — that hypothesis was tested and REFUTED

The removal deleted four admin-time reverts, not one: the payment-token identity check plus
`MinterNotConfigured`, `DispatcherNotConfigured` (index unset) and `DispatcherNotConfigured`
(resolved zero), all incidental to the `_resolvePaymentPath()` call the gate sat behind. An
over-reach hypothesis was put to the story document and **refuted**: the wider blast radius is
authorised, disclosed and faithful. Story-032 devotes a dedicated section to it.

**VERBATIM QUOTE — story-032, "The load-bearing side effect", `032-…md:155-178`:**

> ### The load-bearing side effect: `_resolvePaymentPath()` reverts when unconfigured
>
> … **today a token cannot be whitelisted before `setTokenMinter` and `setDispatcherIndex`
> have both been set.** That ordering constraint is a pure accident of where the gate happens
> to sit — it is not a deliberate invariant anywhere. Three tests pin it: … **Decision: remove
> the call too.** See Concerns §1 — **this is the one consequence of this story that reaches
> beyond the literal request.**

**VERBATIM QUOTE — story-032, Concerns §1, `032-…md:562-574`:**

> **Decision: remove the derivation too**, and invert the three `Core.t.sol` tests that pin
> the old ordering (`:1007`, `:1016`, `:1025`). This is the honest reading of "liberate the
> whitelist", but it is **a genuine behavioural change beyond the one-line ask and is called
> out here for that reason.** If the human wants the ordering constraint kept, the gate can be
> replaced with a bare `_resolvePaymentPath();` call — ugly, but it preserves it. **Not
> recommended.**

The checklist authorises inverting the three pinning tests by name, and the Documentation
checklist requires recording the deployment-ordering change for downstream runbooks. Under
Law 3, removal of the payment-token opinion is additionally a registered intentional owner
decision. **A reader must not come away thinking the removal was unsanctioned. It was
sanctioned, disclosed, and faithfully executed.**

### The actual deviation — the story adjudicated `NudgeStreamer` on mechanism and got the reachable-state answer wrong

**VERBATIM QUOTE — story-032, `032-…md:126-128`:**

> Also not touched: `src/NudgeStreamer.sol`. `NudgeStreamer.registerStream` calls
> `isNudgeToken(token)`, **which is unaffected** — it reads `_nudgeTokenIndex`, and this story
> does not change how entries are added to it, **only what is refused.**

**VERBATIM QUOTE — story-032, "Not a dependency", `032-…md:382-385`:**

> ### Not a dependency
> - `NudgeStreamer` (`nft-staking:028`, `031`) — `registerStream` → `isNudgeToken` reads
>   `_nudgeTokenIndex` and **is unaffected**.

### Actual behaviour

The mechanism claim is **true** of `_nudgeTokenIndex` and **false** of the reachable state.
What changed is not how the index is written but **what a `true` from `isNudgeToken`
transitively witnesses**.

Before `9611312`, `isNudgeToken(token) == true` implied
`tokenMinter != 0 && dispatcherIndex != 0 && dispatcher != 0`, because no entry could be added
without `_resolvePaymentPath()` succeeding. After the change at
`src/BatchNFTMinterMultiToken.sol:328-336`, the add branch checks only zero-address and
already-whitelisted:

```solidity
    function setNudgeTokenWhitelist(address token, bool allowed) external onlyOwner {
        if (allowed) {
            if (token == address(0)) revert BatchMint__ZeroNudgeToken();
            if (_nudgeTokenIndex[token] != 0) {
                revert BatchMint__NudgeTokenAlreadyWhitelisted(token);
            }
            _nudgeTokens.push(token);
            _nudgeTokenIndex[token] = _nudgeTokens.length;
```

And `src/NudgeStreamer.sol:127` gates on **nothing else** — that single duck-typed call is its
entire admission check:

```solidity
        if (!IMultiTokenNudgeWhitelist(batchMinter).isNudgeToken(token)) {
            revert NudgeStreamer__NotWhitelisted(batchMinter, token);
        }
```

`registerStream` was therefore relying on the deleted preconditions as a free
configuration-completeness proof. **"Only what is refused" *is* the change to the reachable
state set.** Traced end to end:

1. Owner whitelists a token while `tokenMinter == 0` — now permitted
   (`src/BatchNFTMinterMultiToken.sol:328-336`).
2. `registerStream(batchMinter, token, duration)` succeeds — `isNudgeToken` returns `true`
   (`src/NudgeStreamer.sol:127`).
3. `collectNudge` is **permissionless** (`src/NudgeStreamer.sol:152`, no access control), so
   anyone — including the production `NudgeRatchet` dispatcher on a schedule — funds the
   buffer.
4. `batchMint` reverts `BatchMint__MinterNotConfigured` inside `_resolvePaymentPath()` at
   `src/BatchNFTMinterMultiToken.sol:479`, **before** step 3.5's flush loop at `:532-534` can
   run. Nothing drains the buffer.
5. `NudgeStreamer` has **no rescue, no pause and no deregistration** (ledger `4a1d8edc92`,
   open).

### The gap

Recovery is a plain owner config call (`setTokenMinter` + `setDispatcherIndex`, then a
qualifying unpaused batch), so this is a **deployment-ordering footgun, not a loss** — hence
Low, not Medium. But it is squarely in Law-3 scope as a non-obvious footgun: the check that
made the bad ordering *impossible* is gone, the story frames the removal purely as
deployment-script convenience, and the story's own dependency section tells the reader the
streamer is unaffected. A competent, non-malicious owner following the newly-permitted
ordering would be surprised to find donor funds parked in a contract with no escape hatch.

`L-04` carries the code limb. It must **not** be collapsed into ledger entry `4a1d8edc92` —
that entry is "the streamer has no rescue"; this is "story-032 opened a new route into needing
one". They compound.

### Law-1 check applied

Does story-032's intended behaviour introduce an exploit? **No.** `_nudgeTokens` appears in no
input to `budget` (written only at `:604`/`:649`) and is never the subject or spender of a
`forceApprove` (`:648`/`:655`), so the whitelist has no data path to refund magnitude or to
any approval — the removal is structurally incapable of reopening `ycn19h1`. The frozen twin's
differently-named runtime gate `BatchMint__NudgeTokenMatchesPaymentToken` survives intact at
`src/BatchNFTMinter.sol:98`/`:261-263`, which was the story's single most dangerous
mis-execution risk and was correctly avoided. The same-denomination arbitrage is a registered
accepted owner decision and is not re-filed.

### Recommendation

Either restore the completeness half without the payment-token opinion story-032 deliberately
dropped (`if (tokenMinter == address(0) || dispatcherIndex == 0) revert …` on the add branch),
or state the required sequence — configure minter + dispatcher → whitelist → `registerStream`
→ fund — in `setNudgeTokenWhitelist`'s NatSpec and in the deployment runbook. Either way,
correct the two "unaffected" claims at `032-…md:126-128` and `:382-385`. Because story-032 is
still in `review`, this can be folded into the story rather than filed as a follow-up.

---

## F-03-031 — the `NudgeCollected.amount` repoint is disclosed in the story but not at the declaration an indexer author reads

- **Severity:** Low · **Confidence:** medium · **Story:** story-031 · **Doc state:** `complete`
- **Story document:** `~/code/product-owner/stories/nft-staking/complete/audit-21/031-nudgestreamer-collectnudge-balance-delta-credit.md`
- **Location:** `src/NudgeStreamer.sol:106-114` (event declaration); emit site `src/NudgeStreamer.sol:211`
- **Fingerprint:** `617102508aea99e1b5f020b433f8eedf540522b679b39c65b071f5aab6704c42`
- **Cross-reference:** `Q-02` in `qa-report.md`

### What the story DID address — so this is a narrow gap, not the headline

**VERBATIM QUOTE — story-031, Concerns §3, `031-…md:187`:**

> **§3 — `NudgeCollected.amount` will carry `received`, not the sent amount; no fifth field
> added.** Adding a field is an event-ABI change that would force indexer/UI regeneration
> downstream. Emitting the credited amount is also the semantically correct pairing with
> `rewardPerSecond`, which is derived from it. **Consequence to accept:** any consumer summing
> that field sees a smaller number for taxed tokens — which is the true credited value. If the
> human wants the sent amount preserved on-chain, that is a deliberate event-ABI change and a
> follow-up story.

The story also addressed the vendored sibling copies of `INudgeStreamer.sol` for the
*signature* (Concerns §4) and swept the five downstream `collectNudge` call sites under "Not
ABI-breaking". On the question "does the story address the semantic change?" the answer is
**yes**, and no faithfulness finding lies there.

### Actual behaviour at `src/NudgeStreamer.sol:106-114`

```solidity
    /// @notice Emitted when a donor tops up a stream's buffer.
    event NudgeCollected(
        address indexed batchMinter,
        address indexed token,
        address indexed donor,
        uint256 amount,
        uint256 rewardPerSecond
    );
```

### The gap

Two residuals the story's disclosure does not reach:

1. **The declaration itself is unamended.** `src/NudgeStreamer.sol:106-114` still reads
   "Emitted when a donor tops up a stream's buffer" with no note that `amount` is now the
   credited receipt. The change is documented at the emit site (`:208-210`) and in
   `INudgeStreamer.sol:14-18`, but not on the line a downstream indexer author reads first.
   Story-031's own review recorded this as non-blocking Issue 3 (`031-…md:434-438`) and it was
   not actioned. Sibling repos hold vendored `INudgeStreamer` copies still carrying the stale
   comment.
2. **The "Not ABI-breaking" analysis is scoped to calldata and returndata only.** Its
   five-call-site sweep verifies that each donor `forceApprove`s an exact amount and ignores
   returndata — true and sufficient *for the call*. It never asks whether a donor keeps a
   **sent-amount-derived pot counter**, which `collectNudge`'s `void` return makes impossible
   to correct on-chain.

Same event topic, same four fields, same types — one non-indexed value silently repointed
across a deployment boundary, with **no compile-time and no on-chain signal**.

### Verified mitigation

No on-chain consumer exists. `NudgeRatchet` (the production donor, `yield-claim-nft` @
`d4cc563`) keeps **no cumulative sent-amount counter**, and its mint-debt ledger derives from
`onDispatch`'s `amount`, not from the credit. The residual is therefore confined to an
**off-chain silent under-count** — an indexer reconciling `Σ NudgeCollected.amount` against
donor-side sent totals disagrees with itself — and is only reachable at all if a taxed or
rebasing token is the nudge asset.

### Recommendation

Action story-031 review Issue 3: add the receipt semantics to the event declaration NatSpec at
`src/NudgeStreamer.sol:106` and to `INudgeStreamer.sol:14-18`. Widen the "Not ABI-breaking"
analysis to cover event-derived off-chain counters, not just calldata/returndata. If an indexer
spans both deployments, the story's own escape hatch applies: a new event name or a version
marker is the only available signal, since the field's type is unchanged.

---

## F-04-030 — story-030 left an unenforced ordering guarantee standing inside the comment block it rewrote, and its own new text contradicts it

- **Severity:** Low · **Story:** story-030 · **Doc state:** `complete`
- **Story document:** `~/code/product-owner/stories/nft-staking/complete/documentation/030-documentation-accuracy-stop-asserting-unenforced-guarantees.md`
- **Location:** `src/BatchNFTMinterMultiToken.sol:659-665` (`batchMint`, step-9 rationale block)
- **Fingerprint:** `8c67e63917222084397343a2b6925fb0338068b4be71018ce4c20bb660f2eb2a` (**shared with `L-06`** — one finding, two channels; do not dedup either away)
- **Cross-reference:** `L-06` in `qa-report.md`; **`WATCH-26-02`**

### VERBATIM QUOTE — story-030, title and Story Overview (`030-…md:1`, `:11`)

> # Documentation and comment accuracy: **stop asserting guarantees the code does not provide**

> Prose-only story. **No behavioural change, no ABI change, no gas change.** The nft-staking
> repo's docs and comments assert several guarantees that the code does not actually
> establish. … Fix the prose so **no future auditor re-derives a defect that is not there**,
> and no future author "fixes" the intended economics to match an inaccurate sentence.

Anchor E's DECIDED text — the required content for this exact comment block (`030-…md:157-160`):

> **DECIDED: option (b) — keep the cap, fix the comment.** … The corrected comment must state:
> … it **cannot** degrade a caller-credit shortfall, because it is not caller-scoped — such a
> shortfall is absorbed by `P` first.

And the acceptance standard the story's own review pass established (`030-…md:374-378`):

> **4. Did not restrict the search to the story's named anchors.** … *Rationale*: The story's
> purpose is stated in **semantic** terms ("no future auditor re-derives a defect that is not
> there"), so the acceptance check had to be semantic too. … *Alternatives*: Validating only
> against the checklist — **rejected as testing the check rather than the property it stands
> for.**

The story therefore explicitly disowns "it wasn't in my enumerated anchor list" as a defence.

### Actual behaviour at `src/BatchNFTMinterMultiToken.sol:659-665`

```solidity
        // ORDER IS LOAD-BEARING, IN TWO PLACES.
        //   1. The snapshot (step 4) must stay BEFORE the pull (step 5), so the
        //      caller's own money is never visible to the payout.
        //   2. The refund (here) must stay BEFORE the payout (step 10), so a
        //      payout can never be funded out of a refund that is owed, and
        //      vice versa.
```

### The gap — both halves of claim 2 are false

1. **The ordering is not what establishes it.** In the ordinary case *both* orderings are
   solvent. The refund is sourced from the tracked `budget` (`:711`) and the payout from the
   pre-loop `snapshot` (`:833`); the balance at step 9 is `P + (credited − C) + D ≥ P + budget`.
   What makes the two transfers independent is their **sourcing**, not their sequence. Tier-1
   reaches the same conclusion independently.
2. **The symmetry is false in the one case where the ordering does bind.** Under any erosion
   of the contract's payment-token holdings between step 5 and step 9, refund-first pays the
   refund at `min(budget, available)` and charges the shortfall to `D` (this batch's donations,
   owed to the *next* claimant) and then to `P`. If erosion `≤ D` the batch **succeeds
   silently**, with the refund funded out of value owed to the payout side; if erosion `> D`
   the payout's `safeTransfer` reverts the whole batch. In neither branch is the refund the
   party that degrades. So "a refund funded out of a payout that is owed" — the `vice versa`
   half — is exactly what the ordering *causes*, not what it prevents.

Story-030's own Anchor E addition, 20 lines below at `src/BatchNFTMinterMultiToken.sol:695-702`,
states the contradicting fact in the terms the story required:

```solidity
        // DURABLE RESIDUAL — `budget` is a ONE-SHOT MEASUREMENT, pinned in the
        // step-5 block and never re-validated. Any erosion of this contract's
        // payment-token holdings AFTER that point is therefore charged to the
        // pot, silently ...
```

The story therefore shipped a comment block that asserts mutual non-interference by
construction in its opening paragraph and admits silent pot absorption in its closing one —
newly **self-contradicting as a result of the story's own edit**, and the exact failure mode
the story was written to remove. A maintainer reads the *cleaned* comment with more trust than
the original.

### Attribution — stated honestly

The ORDER text was authored by **story-029**, not story-030:

```
$ git log --oneline -S "ORDER IS LOAD-BEARING, IN TWO PLACES" -- src/BatchNFTMinterMultiToken.sol
0318089 [story-029] GREEN: budget-tracked refund makes paymentToken as nudge token safe
```

At `5015f1b` the block occupied `:634-640`; Anchor E's quoted range begins at `:643` and
commit `bae1a6e` does not touch a line of it. It is therefore **outside the anchor's
enumerated line range** — but **inside the same contiguous step-9 `//` comment block that
Anchor E rewrote**, and Anchor E's own new DURABLE RESIDUAL text contradicts it three
paragraphs later. That, plus the story's explicit disowning of checklist-only acceptance
(`030-…md:374-378`), is what makes it in scope rather than out.

### Reachability and WATCH-26-02

This stays **documentation-only at this commit**. There is no value transfer to classify: the
erosion path requires a **token-side property**, which is C4-invalid standalone. The KI #16
carve-out flag is formally **discharged** — carve-out (b) (`refund > paymentAmount`) is
structurally impossible (`refund ≤ budget ≤ paymentAmount` at `:604`, and `budget` only
decreases), and carve-out (d) ("any claimant taking other users' money") does not fire on a
plain token.

**`WATCH-26-02` — the door stays open.** That plain-token proof rests on an **undocumented
cross-repo coupling**: `NFTMinterV2._executeMint` must charge exactly the `config.price` the
batchMinter read. If that is ever changed — a consumption-side fee, a two-pull mint, a price
write before the transfer — `budget` under-decrements, the erosion becomes reachable on a plain
token, carve-out (d) fires, and this becomes a **real value-transfer finding** at Medium or
above.

### Recommendation

Same as `L-06`: correct `:659-665` to attribute independence to **sourcing** (`budget` vs
`snapshot`), not sequence; state that the ordering additionally fixes *which side absorbs an
erosion shortfall* (refund-first charges `D` then `P`, never the caller); delete or scope "and
vice versa"; reconcile with `:695-702`; and document the cross-repo `config.price` coupling
against `NFTMinterV2._executeMint`. One sentence of prose, zero behavioural change, consistent
with story-030's prose-only contract.

> ⚠ **DISCRIMINATOR — F-04-030 / L-06 vs Q-01 / F-01-031. DO NOT COLLAPSE THE TWO DOCUMENTATION
> FINDINGS.** Both are "shipped text asserts a property the code does not establish", and a later run
> reading only the summaries could plausibly merge them. The discriminator is **what the text is wrong
> about**, and it changes the remediation:
>
> - **F-04-030 / L-06 — *undocumented cross-repo coupling + in-file self-contradiction*.** The
>   asserted property is **FALSE** (both halves of claim 2 fail); the file **refutes itself** 20 lines
>   later at `:695-702` (story-030's own Anchor E); and the property's real safety rests on an
>   **undisclosed cross-repo coupling** to `NFTMinterV2._executeMint` @ `yield-claim-nft` `d4cc563`
>   (`WATCH-26-02`). Fix = delete/correct a false claim **and** document an external dependency.
> - **Q-01 / F-01-031 — *machine-proved + locally self-consistent*.** The asserted property is
>   **TRUE** — Halmos-proved for 2 streams (independently re-run and reproduced), no counterexample in ~640k Foundry fuzzed calls — locally
>   consistent, single-contract and token-independent. Only its **cited basis** is wrong ("by
>   construction" at one site, where a conjunction of two sites is what holds it). Fix = restate the
>   basis, or add the clamp the text implies.
>
> Neither fix closes the other, and merging them would lose `WATCH-26-02` entirely. Full comparison
> table under `Q-01` in [`qa-report.md`](./qa-report.md).

---

## F-05-032 (Informational) — story-032 has landed at HEAD while its document sits in `review`

- **Severity:** Informational (process note) · **Story:** story-032 · **Doc state:** **`review`**
- **Story document:** `~/code/product-owner/stories/nft-staking/review/whitelist-liberation/032-remove-payment-token-whitelist-gate.md`
- **Location:** `src/BatchNFTMinterMultiToken.sol:328-336`
- **Fingerprint:** `c8eea30dd352b7d9c2036c7f5e34d6ead350913ed054160665136e04b8027e53`

Per `CLAUDE.md` → Stories, the state folder is **metadata, not a filter**, so story-032 was
graded in full and its findings carry the same weight as the two `complete` stories. It is
recorded here because the same guidance calls a landed-but-unclosed story worth surfacing:
`9611312` is HEAD of the audited range and the deliverable is wired, yet
`032-remove-payment-token-whitelist-gate.md` remains under `review/whitelist-liberation/`, so
its acceptance criteria are formally still in flux.

Its own Review Results record status **PASSED (47/47)** with two deferred items:

- **`phStaging2:072`'s six-row stale-claim reconciliation.** Its phase-0 assertion of the
  now-deleted `BatchMint__RewardTokenIsPaymentToken` tripwire would fail if 072 were run as
  written. This is the owner's item per Concerns §2; 072 is on ice and unbroadcast
  (owner-confirmed 2026-07-30), so there is no live runbook breakage today.
- Branch `sprint/whitelist-liberation` is committed but **not pushed**.

**This is not a security finding.** It is also an opportunity: `F-02-032`'s and `L-04`'s
remediations can be folded into story-032 before it closes, rather than filed as follow-ups.

### Recommendation

Fold the `F-02-032` / `L-04` remediations into story-032 before closing it; correct the two
false "`NudgeStreamer` is unaffected" claims; push `sprint/whitelist-liberation`; and resolve
the `phStaging2:072` phase-0 assertion before 072 is ever taken off ice.

---

## 6. Per-story verdict, and the Law-1 override

| Story | Document (under `~/code/product-owner/stories/nft-staking/`) | State | Verdict | Findings | Law-1 override |
|---|---|---|---|---|---|
| **story-030** | `complete/documentation/030-documentation-accuracy-…md` | `complete` | **DEVIATION** | `F-04-030` | Applied — **SAFE** |
| **story-031** | `complete/audit-21/031-nudgestreamer-collectnudge-balance-delta-credit.md` | `complete` | **DEVIATION** (mechanism faithful; documentation obligation not met) | `F-01-031`, `F-03-031` | Applied — **SAFE** |
| **story-032** | `review/whitelist-liberation/032-remove-payment-token-whitelist-gate.md` | **`review`** | **DEVIATION** (contract change faithful *including* the wider blast radius; the cross-contract dependency claim is false) | `F-02-032`, `F-05-032` | Applied — **SAFE** |

### No UNSAFE-STORY was found — and the check was run

The Law-1 override question — *"if the code did exactly what the story says, would that be
exploitable or break a protocol invariant?"* — was asked of each story **independently of
conformance**. A silent pass on this check is indistinguishable from not running it, so the
result is stated per story:

| Story | Intended behaviour | Law-1 verdict |
|---|---|---|
| 030 | Prose only. Zero executable Solidity changed — verified at bytecode level in the story's own record (deployed bytecode identical for 21,204 of 21,290 hex chars; divergence confined to the 64-char CBOR IPFS digest). | **Safe.** No mechanism by which it could be unsafe. |
| 031 | `min(received, amount)` credit, snapshot taken after `_settle`, revert on zero receipt. Strictly safety-improving and directionally conservative: surplus is left uncredited (protocol-favourable), under-delivery fails closed. | **Safe.** The defect is in the guarantee's stated *scope* (`F-01-031`), not the mechanism. |
| 032 | Delete an admin-time check that story-029 had already reduced to defence-in-depth, plus three incidental config preconditions. | **Safe.** No data path from `_nudgeTokens` to `budget` or to any approval; the frozen twin's runtime gate is untouched; the arbitrage is a registered accepted decision. The one new consequence (`F-02-032`) is a recoverable ordering footgun, not an exploit. |

**No `story-unsafe` findings. No `securityEscalation: true` on any Law-2 finding.** Not one of
the three stories' *intended* behaviours introduces an exploit; every deviation reported above
is a defect in what the code and documents **claim**, not in what the intended design does.

---

## 7. Attribution correction — two over-claims were reassigned to the right story

Recorded because Law 2 requires grading against the **right** story: a faithfulness finding
filed against the wrong story sends the fix to the wrong owner and lets the real one close
clean. Two over-claims were handed to the faithfulness stage as "story-030 misses" and were
reassigned on `git log -S` evidence.

**(a) `src/NudgeStreamer.sol:56-57` and `:258-261` → reassigned to story-031** (now
`F-01-031`, not a story-030 finding):

```
$ git log --oneline -S "rather than by convention"  -- src/NudgeStreamer.sol
2ba764e [story-031] Credit NudgeStreamer.collectNudge with the amount RECEIVED, not sent
$ git log --oneline -S "established at ONE site"    -- src/NudgeStreamer.sol
2ba764e [story-031] ...
$ git log --oneline 5015f1b..d2506c1 --name-only | grep -c NudgeStreamer
0
```

`src/NudgeStreamer.sol` appears in **no** story-030 commit and in **none** of story-030's File
Locations table. The text did not exist when story-030 ran; it cannot be a story-030 miss. It
is a story-031 deliverable.

**(b) `src/BatchNFTMinterMultiToken.sol:659-665` → authored by story-029**, and filed as
`F-04-030` on a *scope* argument rather than an authorship one:

```
$ git log --oneline -S "ORDER IS LOAD-BEARING, IN TWO PLACES" -- src/BatchNFTMinterMultiToken.sol
0318089 [story-029] GREEN: budget-tracked refund makes paymentToken as nudge token safe
```

It remains a story-030 finding only because it sits inside the same contiguous step-9 comment
block Anchor E rewrote, story-030's own new text 20 lines below contradicts it, and the story's
review pass explicitly rejects checklist-only acceptance. The authorship is stated plainly in
the section itself so the owner is not asked to answer for text they did not write.

---

## 8. Checked and found faithful — recorded so a later run does not re-derive these as gaps

- **story-030, Anchors A–H:** all eight landed. The "by construction a fraction of the cost"
  claim was replaced with the yield-funded-subsidy framing at all three grep sites plus a fifth
  paraphrase site the review pass found (`9c456f5`). Anchor C's "do not add a value-aware cap
  to the payout on the strength of this paragraph" is in shipped NatSpec — the highest-leverage
  line in the change, directly foreclosing the withdrawn `pns25m1` remedy. Anchors D/E/F/G
  landed as specified. The one retained `fraction of the cost` hit at
  `docs/multi-token-nudge.md:58` is scoped "in normal operation" and immediately followed by
  the policy-not-construction denial; the story's criterion was "zero hits *asserting a
  bound*", which is met.
- **story-031, all eight mechanism points:** `heldBefore` at `:193` taken **after** `_settle`
  and immediately before the pull (the story's own "single highest-risk detail"); pull `:194`;
  delta `:195` (underflows and fails closed on a recipient-debiting token); cap
  `min(received, amount)` `:196`; distinct `NudgeStreamer__ZeroReceived` `:199`;
  `s.buffer += received` `:201`; single rate recompute reading `s.buffer` `:206` with no
  parallel derivation from `received`; event carries `received` `:211`. Frozen
  `src/BatchNFTMinter.sol` and `MockFeeOnTransferERC20.sol` byte-identical to base.
- **story-032, the contract diff:** exactly five non-comment deleted lines, all inside
  `setNudgeTokenWhitelist`. Zero lines of `batchMint`, `_snapshotRewards` or `_payRewards`
  changed. Both ordering constraints intact. The two historical-incident tests were genuinely
  rewritten to pin story-029's budget mechanism rather than deleted or mechanically flipped —
  the story named this as the likeliest place to take a shortcut, and it was not taken.
- **story-032, the +17,000 gas snapshot shift:** not a `batchMint` change. Flat offset across
  counts 1/2/3 (so not loop work), inter-label deltas 30,855 before and after, cold-path labels
  byte-identical, and 2 cold accounts × 2500 + 6 cold slots × 2000 = 17,000 exactly — an
  EIP-2929 test-harness pre-warming artifact of the deleted `_resolvePaymentPath()` call in the
  same transaction. The new figures are the production-representative ones.

---

*Findings records: `reports/phoenix-nft-staking/26/findings/faithfulness/`. Full Tier-2
analysis with all story quotes in context: `reports/phoenix-nft-staking/26/tier2/faithfulness.md`.
Classification rationale and walk-backs: `reports/phoenix-nft-staking/26/classified-findings.md`.
Code-side limbs of the dual-routed findings: `reports/phoenix-nft-staking/26/submissions/qa-report.md`.*
