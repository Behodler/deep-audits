# QA Report — `phoenix-nft-staking` (run-26)

- **Target**: `lib/phoenix-nft-staking` @ `9611312` (`96113129b57ebf7a7c45c65996f792a92c71cdce`)
- **Cross-repo sites verified at**: `lib/yield-claim-nft` @ `d4cc563` (top-level submodule HEAD)
- **Date**: 2026-07-30

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 5 |
| QA / Hardening | 3 |
| Centralization | 0 |
| **Total** | **8** |

**This run produced 0 High and 0 Medium findings**, so this QA report is the run's primary
deliverable. That is a statement about the code at this commit, not a shortfall in the scan:
the two candidate escalations were investigated to a conclusion and both resolved *against*
escalation on evidence (see L-03 and L-06). Nothing was deflated to fit this bundle, and
nothing has been padded into it to make it look fuller.

### Low Risk

| ID | Title | Site |
|---|---|---|
| L-01 | Un-isolated cross-contract flush loop can brick `batchMint` | `BatchNFTMinterMultiToken.sol:528-536` |
| L-02 | `nudgeSize == 0` disables the payout but not the inflow or the flush | `BatchNFTMinterMultiToken.sol:510-536` |
| L-04 | story-032 removed the config-completeness precondition (deployment-ordering footgun) | `BatchNFTMinterMultiToken.sol:328-336` |
| L-05 | `setNudgeStreamer` accepts any address with no structural probe | `BatchNFTMinterMultiToken.sol:297-300` |
| L-06 | Self-contradicting, unenforced ordering guarantee on a load-bearing property | `BatchNFTMinterMultiToken.sol:659-665` |

### QA / Hardening

| ID | Title | Site |
|---|---|---|
| Q-01 | Falsely-exhaustive NatSpec on a load-bearing pooled-custody invariant | `NudgeStreamer.sol:250-265` |
| Q-02 | `NudgeCollected.amount` repointed from request to receipt under a byte-identical ABI | `NudgeStreamer.sol:106-211` |
| L-03 | `NudgeRatchet`'s failure-mode enumeration omits `NudgeStreamer__ZeroReceived`, and diverges silently from `BalancerPoolerV2`'s failure semantics **(rescoped; rebanded Low → QA — label retained, see §L-03)** | `NudgeStreamer.sol:93`, `:199`; `NudgeRatchet.sol:29-38` |

### Count reconciliation — two pre-publication changes, stated so the arithmetic is checkable

This bundle went through a remediation pass before publication and **two** of its changes move the
counts. Both are recorded here rather than silently absorbed:

1. **`Q-03` was WITHDRAWN** (see §"Withdrawn before publication"). Run tally went from
   9 Low · 3 QA · 1 Informational (13 findings, 14 records) to **9 Low · 2 QA · 1 Informational**
   (12 findings, 13 records).
2. **`L-03` was rescoped and rebanded Low → QA** (see §L-03). That moves one finding between bands
   without changing the total: the run tally is therefore **8 Low · 3 QA · 1 Informational**
   (12 findings, 13 records), and this bundle's own table above reads **5 Low · 3 QA**.

The difference between "9 Low · 2 QA" and the final "8 Low · 3 QA" is exactly change 2. The two
figures are the same 12 findings counted before and after the reband; neither is a correction of the
other. Run-level counts include the four Law-2 Lows and the one Informational routed to
`spec-conformance.md`, and count the dual-routed `L-06` / `F-04-030` **once**.

**`L-03` keeps its `L-` label after the reband, deliberately.** Labels persist once assigned and are
never reused or renumbered; relabelling it `Q-03` would reuse the label of the entry withdrawn above,
which is exactly the collision the persistence rule exists to prevent.

### What is deliberately *not* in this bundle

- **Faithfulness (Law 2) findings** — `F-01-031`, `F-02-032`, `F-03-031`, `F-04-030` and the
  informational `F-05-032` are routed to `spec-conformance.md`. L-06 is **dual-routed** (`L-06`
  here **and** `F-04-030` there) by design; that is not a duplicate.
- **Carryover QA from earlier runs** — one pruned copy per originating audit, at
  [`submissions/carryover/qa-report-24.md`](./carryover/qa-report-24.md), with the selection rule and
  its gaps in [`submissions/carryover/README.md`](./carryover/README.md). That file carries the four
  still-open run-24 QA entries and, in particular, **the mandatory run-26 re-frame of
  `aaebb4b9b056…`** — the low-pass-filter correction and its **reversed** remediation (*do NOT
  permission `collectNudge`*). **Read it: it is a substantive run-26 conclusion, not a historical
  appendix.** This run's `L-`/`Q-` sequence covers only run-26's new findings and is not renumbered
  around the carried entries; run-24's `L-02` and this run's `L-02` are different findings —
  disambiguate by fingerprint, never by label.
- **The three `fix-pending` entries** (1 High, 2 Medium) are **not in this QA bundle** — they are
  High/Medium severity and therefore carried **alongside this run's submissions**, not inside a QA
  report. An earlier draft recorded them as an unfilled gap; **that gap is now closed** and each is
  reproduced as a **full copy**:
  [`H-01-C1.md`](./H-01-C1.md) (`1c222d5485…`, **High**), [`M-02-C1.md`](./M-02-C1.md)
  (`a62fe01a25e2…`, Medium — ⚠ **its contract was rewritten in range; highest-priority `/recheck`**),
  [`M-05-C1.md`](./M-05-C1.md) (`bdf84579b6ff…`, Medium). **Every one states explicitly that run-26
  did NOT re-verify it** — no PoC replay, no targeted re-scan, no invariant or symbolic run aimed at
  it — so all three statuses are carried forward **unchanged and unexamined**. `fix-pending` is never
  a disposal; all three are **still owed fixes**, and **no `fixed` is proposed**. Reversal and
  reasoning in [`carryover/README.md`](./carryover/README.md) §"GAP CLOSED".

---

## Low Risk Findings

### [L-01] Un-isolated cross-contract flush loop can brick `batchMint` <!-- id: pns26l1 -->

**Severity**: Low (availability / isolation leg only)

**Location**: `src/BatchNFTMinterMultiToken.sol:528-536` (call at `:531-534`), reverting line
`src/NudgeStreamer.sol:243` via `pullPendingStream:224`

**Description**

`batchMint`'s flush loop iterates the **owner's** nudge-token whitelist and calls
`NudgeStreamer.pullPendingStream` for each entry with no `try/catch` and — the material point —
**without gating on `qualifies`**. Every iteration is optional for the caller's own outcome, yet
any revert inside the semi-trusted streamer rolls back the whole mint.

The genuinely new and plainly-reachable increment is a **loss of structural immunity for
non-qualifying batches**. Every other reward-token touch in this contract *is* gated:
`_snapshotRewards:801` short-circuits its `balanceOf` read behind a `qualifies` ternary, and
`_payRewards:831` skips zero amounts. Before this loop existed, a `count < nudgeSize` caller had
**zero** nudge-token exposure. The flush loop — sitting immediately above `_snapshotRewards`,
doing the opposite — is now that caller's *only* exposure, **for zero benefit to them**.

**Impact**

Availability only. A revert inside the streamer bricks `batchMint` for every caller, including
callers who take no nudge payout at all. Nothing is lost, and the owner holds two
single-transaction escapes (`setNudgeStreamer(0)`, `setNudgeTokenWhitelist(token, false)`).

**Plain-token reachability at this commit: NON-NIL, but not attacker-inducible.** (An earlier draft
of this finding recorded *"nil … requires a weird token"*. That was a **factual error** — it
contradicted this finding's own severity reasoning, and read literally it invited a reader to
dismiss the finding under the non-standard-token rule. Corrected here.)

- `NudgeStreamer__NotRegistered` **cannot fire** in this loop: `pullPendingStream` early-returns
  for unregistered streams (`NudgeStreamer.sol:222`, `if (s.duration == 0) return;`).
- `_settle`'s transfer at `:243` reverts on **either** an INV-1 violation (a weird token — see
  below) **or** an **issuer-side event on the settlement asset itself**: a USDC global pause, or a
  USDC/USDT blocklisting of the batchMinter. `_settle` transfers to
  `recipient == msg.sender == the batchMinter`, so either event reverts the un-isolated, un-gated
  flush loop and therefore `batchMint` — for every caller, including a `count < nudgeSize` caller
  who takes no payout. **That trigger requires no weird-token property at all**: it is documented
  canonical behaviour of the protocol's actual settlement asset (both production donors forward
  USDC), and **USDT is the named exception** to the non-standard-token rule. It is in scope as a
  matter of rule and **may not be waved away as weird-token noise.**
- **In scope ≠ Medium.** Severity is set below on the trigger-and-escape analysis, **not** on
  token-class invalidity.

The aggregate-over-statement mechanism (formerly "leg B") is separately **killed** and is not
restated here: every enumerated mechanism for it is token-side (negative rebase, burn-on-hold,
clawback, blacklist-zeroing) and therefore C4-invalid standalone. The USDT carve-out does not
rescue *that* mechanism — a blacklisted streamer cannot transfer at all, so the blacklist is the
brick, not the buffer sum. Note that this argument kills leg B while **confirming** the isolation
limb above.

**Why this is Low, and what would make it Medium.** C4's Medium availability limb needs the outage
to be **attacker-inducible, OR undetectable, OR unrecoverable**. It is none of the three, and each
branch of the issuer-event trigger was taken separately rather than dismissed in the abstract:

| Branch | Reachable? | Incremental to this finding? | Escape |
|---|---|---|---|
| Global USDC pause, payment token **==** nudge token (USDC) | yes | **NO** — `batchMint`'s own payment pull at `:581` reverts regardless; the flush loop adds nothing and the outage is not this finding's | — |
| Global USDC pause, payment token **≠** USDC | yes | yes — the flush loop is then the only USDC touch and takes down an otherwise-working mint | `setNudgeTokenWhitelist(USDC,false)` **or** `setNudgeStreamer(0)` — **one** owner transaction, loudly signalled |
| Blocklist of the batchMinter specifically | yes, but a targeted sovereign act against one named protocol contract | partly — if payment is USDC the batchMinter cannot receive or pay USDC at all, so the nudge path is dead independently | same two one-transaction escapes |

No third party can induce an issuer freeze; the revert is loud and atomic; and the owner holds **two
single-transaction escapes that lose no value** (the stranded buffer is a separate, already-tracked
Low — ledger `4a1d8edc92…`, open). Hence Low.

**Reopen trigger (falsifiable, and it supersedes the earlier wording).** The earlier trigger read
*"reopens at Medium if a plainly-reachable trigger is found"*, which is not adjudicable — a
plainly-reachable trigger is **named above** and the finding is still Low, so that wording was both
vague and already arguably met. The escapes, not the trigger class, are what hold the Low:

> **`L-01` becomes MEDIUM if either one-transaction owner escape is removed** — i.e. if the nudge
> whitelist becomes immutable, or if `nudgeStreamer` can no longer be zeroed. Both escapes were
> verified in source at this commit (`setNudgeStreamer:297-300`; `setNudgeTokenWhitelist:328-336`,
> whose removal branch is derivation-free by design and so works even while the minter is
> unconfigured). **They are load-bearing for this Low.**

This is in addition to `WATCH-26-03` below, which is a different trigger (an INV-1 counterexample,
i.e. the outage arriving in *normal operation* with no operator action).

**Recommended Mitigation**

The complete fix has **two co-equal parts**. They close different halves of the exposure and
**neither is sufficient alone** — in particular, part 1 by itself leaves this finding's primary
stated impact fully live.

**Part 1 — gate the flush loop at `:528-536` on `qualifies`.** This removes the zero-benefit
exposure for **non-qualifying** batches, restoring the structural immunity a `count < nudgeSize`
caller used to have, and brings this site into line with the gating every other reward-token touch
already applies. It is **provably behaviour-neutral**, which was verified rather than assumed:
`_settle` never recomputes `rewardPerSecond` (its only write sites are `:139` and `:206`), and
`_accrued` derives from `block.timestamp - lastUpdate`. Skipping a settle therefore loses no
accrual — the same amount settles at the next qualifying batch.

**Part 1 does not address the brick.** A **qualifying** batch still calls `pullPendingStream`
across the whole whitelist, so a single reverting nudge token still rolls back the entire mint.
That is the primary impact stated above, and the `qualifies` gate does not touch it.

**Part 2 — wrap each per-token `pullPendingStream` call in `try/catch`, skipping with an event on
failure.** This is what removes the brick for **qualifying** batches. Each iteration is optional to
the caller's own outcome, so a failed pull should degrade that one token's settlement rather than
destroy the mint; the emitted event keeps the failure diagnosable rather than silent.

**Part 2's justification is a plain-asset one, not a weird-token one.** This is a direct consequence
of the reachability correction above: part 2 closes an **issuer-event-conditional** exposure on
USDC/USDT — the settlement asset the protocol actually uses — and only secondarily the token-side
INV-1 branch. Part 1 closes all of the *routinely*-reachable exposure (the non-qualifying caller's
zero-benefit exposure, and L-02 in full); part 2 is the half that survives an issuer freeze, a
blocklisting, or a future token change. Both are worth doing, and a reader deciding what to ship
first should know part 1 has the broader everyday effect while part 2 covers the branch nobody
controls.

**Note the asymmetry with L-03 and do not generalise:** swallowing is acceptable here because the
flush is optional to the caller and nothing downstream accrues debt against a value that failed to
move. At L-03's site it is actively harmful. See L-03's mitigation for why.

That asymmetry is a deliberate, reasoned distinction, not an inconsistency in this report, and it
turns on what executes *after* the swallowed call. Here, nothing does: a skipped
`pullPendingStream` leaves that token's buffer untouched on the streamer, to be settled by the next
batch, and no downstream accounting is keyed to the amount that failed to arrive. At L-03's site,
`ATokenDispatcherV2.dispatch:124-125` runs `_dispatch(...)` and **then**
`hook.onDispatch(minter, amount, extraData)`, so a swallowed `collectNudge` lets mint-debt accrue
against `amount` while the USDC sits undelivered on the dispatcher. Same construct, opposite
verdict, because the consequence of proceeding differs.

**Disclosure — third occurrence of this class.** This is the **third** finding in the
un-`try/catch`'d-external-call class for this family, after `966e717669` and `1887dbe136`.
Separately, `bfdb50105e`'s wont-fix rationale — *"caller chooses both the token and the
recipient"* — **does not transfer to this site**, because this loop iterates the **owner's**
whitelist, not a caller-supplied list. The caller chooses neither the token nor the recipient
here, so the reasoning that disposed of `bfdb50105e` is unavailable.

**The escape hatch does NOT arm L-03 — stated affirmatively, because a reader will suspect it does.**
`setNudgeTokenWhitelist(token, false)` is recommended above as a one-transaction escape from this
finding's brick. It **does not** create L-03's mint-brick. This was checked specifically, in source,
and the reason is narrow: **`collectNudge` does not consult the batchMinter's whitelist at all.** Its
only gate is `s.duration == 0` (`NudgeStreamer.sol`); the batchMinter's `isNudgeToken` is read by
**`registerStream:127` only**, at registration time. So de-whitelisting a token stops *the flush* and
leaves `collectNudge` — and therefore `NudgeRatchet.dispatch`, and therefore the mint — working
exactly as before. Had `collectNudge` carried a whitelist check, this escape would have converted an
availability outage in one finding into an availability outage in the other, and the two would have
composed into a genuine Medium. **It does not, and they do not.** The same holds in the other
direction: `setNudgeStreamer(0)` on the batchMinter does not touch `NudgeRatchet.nudgeStreamer`.
Both escapes are safe.

What the de-whitelist escape *does* cost is separately tracked: it strands the accumulated buffer,
which is ledger `4a1d8edc92…` (Low, open, carried at
[`carryover/qa-report-24.md`](./carryover/qa-report-24.md) §L-01). The composition is stated so this
Low does not read as costless.

**Watch note — WATCH-26-03 (escalates to Medium — ⚠ JOINT RE-WEIGH, MEDIUM *FLOOR*).** This finding
escalates to **Medium** if a plain-ERC20 counterexample to INV-1
(`Σ buffer_i ≤ token.balanceOf(streamer)`) is found. The impact side already satisfies C4 Medium's
availability limb ("protocol function/availability impacted"); only the precondition side holds it
at Low.

> ⚠ **THE ESCALATION IS JOINT, AND MEDIUM IS THE FLOOR, NOT THE CEILING.** One INV-1 counterexample
> does not escalate two findings independently — it escalates **L-01 and L-03 together, from the same
> witness**. In that world a single counterexample **bricks mint AND flush in normal operation with
> no operator action**: `_settle`'s transfer reverts on the ordinary path, which takes out the flush
> loop (L-01) and the dispatcher hop (L-03) at once, unannounced, with nothing an operator did or
> could have avoided. Two simultaneous availability outages on the routine path, arriving without
> warning and without an operator trigger, must be **re-weighed from that combined shape** — the
> pair is **not** two Lows that each happen to become a Medium. **Medium is the FLOOR of that
> re-weigh, not its ceiling**; do not treat "becomes Medium" as the answer already settled. Re-weigh
> L-01 and L-03 jointly, on the combined blast radius, and only then pick the label.

**The invariant work must not be
presented as unqualified verification:** Halmos *proved* INV-1 for **2 streams** at wide bounds
(buffers/balance < 2^96, `rewardPerSecond` < 2^128, elapsed < 2^40) across all three write sites,
including the strong no-brick form. The **≥ 3-stream case is INCONCLUSIVE-timeout above 2^32** —
it passes only in the narrowed 2^32 / 2^48 / 2^24 domain — and the **N > 2 generalisation is
hand-checked, not machine-proved**. A Halmos timeout is not a proof in either direction. The same
counterexample would escalate **L-03** as well.

---

### [L-02] `nudgeSize == 0` disables the payout but not the inflow or the flush: value migrates into an un-metered container the owner cannot stop filling <!-- id: pns26l2 -->

**Severity**: Low

**Location**: `src/BatchNFTMinterMultiToken.sol` — `qualifies` at `:510-514`, flush loop at
`:528-536`, `_snapshotRewards:801`, `_payRewards:831`, NatSpec at `:40-41` and `:269-270`

**Description**

`setNudgeSize(0)` is documented at two NatSpec sites (`:40-41`, `:269-270`) as *"disables the
feature"*. It disables the **payout** — `_snapshotRewards:801` gates its own balance read on
`qualifies`, `_payRewards:831` skips zero amounts — but it does **not** disable the **inflow**
(permissionless `collectNudge` keeps funding the streamer buffer; the production `NudgeRatchet`
donates on schedule) and it does **not** disable the **flush** (the loop at `:528-536` sits
immediately above `_snapshotRewards` doing the opposite: it does not read `qualifies`).

Value therefore migrates **out of** the streamer and **into** the batchMinter during the
nominally-disabled period — in the wrong container, invisibly.

**Impact**

A "disabled" nudge accumulates on the order of 30,000 units over a 30-day disable at a
1,000/day inflow, delivered as **one un-metered lump** to whoever wins the first re-enabled
qualifying batch.

**Precisely: there is no way to stop the inflow, and no meter on the destination.** An earlier draft
said "no return path", which is true of the *source* and false of the *destination*, and the
distinction matters to the operator's options. `NudgeStreamer` is the container with no exit — no
withdrawal, no pause, no deregistration. The destination, `BatchNFTMinterMultiToken`, **does** have
`rescueERC20` (`:386-389`, `onlyOwner`, no token restriction, callable while paused). So the flush
moves value **out of a no-rescue container and into a rescuable one**, and the owner has a remedy for
the accumulated lump once it has landed. What the owner has no lever for is the accumulation itself:
`collectNudge` is permissionless, the production donor is on a schedule, and the flush does not read
`qualifies`. That is the finding, and it still supports Low.

**Honest limits — stated plainly.** **No value is lost.** Nudge pots are funded by
externally-derived yield on protocol-owned capital, so mis-sizing is misallocation / opportunity
cost, never economic loss; funds remain in protocol-controlled contracts throughout. This finding
carries **no value-leak limb**. The flush is also not the *cause* of the lump — a quiet period
longer than `duration` makes `_accrued` hit its `buffer` cap anyway. The flush's distinct
contribution is that accumulation happens **during the disabled period, in the wrong container,
invisibly**. Classified on the custody-location and operator-expectation footgun alone.

**Law 3**: non-obvious footgun ⇒ in scope. Two NatSpec sites say "disables the feature";
`_snapshotRewards` gates its own balance read on `qualifies`; the flush sits immediately above
doing the opposite. A competent, non-malicious owner would be surprised.

**Recommended Mitigation**

Gate the flush loop at `:528-536` on `qualifies` — the **same change is part 1 of L-01's fix**,
and it closes this finding in full — and correct the two NatSpec sites (`:40-41`, `:269-270`) to
state precisely what `setNudgeSize(0)` does and does not stop. Note that the gate alone does
**not** complete L-01, which additionally needs the per-token `try/catch` (L-01 part 2) to remove
the brick for qualifying batches.

**Live-config dependency**: actual `nudgeSize`, whitelist contents, and per-pair inflow rates are
not verifiable from the repository. Resolve them **from chain**, not from deploy records, before
acting on this finding (MR-26-05 / GAP-26-04).

*Cross-reference*: same code site as L-01, **different consequence** (value migration vs
availability). Deliberately not collapsed — a reader who saw only the availability framing would
never learn the accumulation happens.

---

### [L-04] story-032 removed the precondition that made "fund the streamer before wiring the minter" impossible <!-- id: pns26l4 -->

**Severity**: Low (deployment-ordering footgun)

**Location**: `src/BatchNFTMinterMultiToken.sol:328-336` (gate removed);
`src/NudgeStreamer.sol:127` (now the only registration gate);
`src/BatchNFTMinterMultiToken.sol:479` (where `batchMint` reverts instead);
`:532-534` (the flush that never runs)

**Description**

Before `9611312`, `isNudgeToken(token) == true` **transitively witnessed**
`tokenMinter != 0 && dispatcherIndex != 0 && dispatcher != 0`, because no whitelist entry could be
added without `_resolvePaymentPath()` succeeding. `registerStream` gates on nothing else.
story-032 removed that gate.

The resulting sequence is: whitelist → register → **permissionless** `collectNudge` funds the
buffer (the production `NudgeRatchet` does this on schedule) → `batchMint` reverts
`BatchMint__MinterNotConfigured` at `:479` **before** the flush loop → nothing drains the buffer,
and the streamer has no rescue function.

**The hazard is not merely undisclosed — the shipped NatSpec asserts it away.**
`src/BatchNFTMinterMultiToken.sol:317-320`, added by the same commit that removed the gate:

> `///         Because nothing here reads the payment path, adding works while`
> `///         `tokenMinter`/`dispatcherIndex` are unset — symmetric with`
> `///         removal, and **no longer an ordering constraint on deployment`
> `///         scripts**.`

An ordering constraint **does** remain — whitelist → `registerStream` → permissionless `collectNudge`
from a stateless sweeping donor → `batchMint` reverts `BatchMint__MinterNotConfigured` at `:479`
*before* the flush loop → nothing drains the buffer, and the streamer has no rescue. An operator who
strands donor throughput here is **not being reckless: they are following a line of shipped
documentation that tells them the constraint was lifted.** That is the strongest form of the Law-3
non-obvious-footgun test — the hazard is not just non-obvious, it is affirmatively contradicted by the
project's own documentation — and it places this finding unambiguously in scope, foreclosing any later
attempt to re-triage it as an admin mistake. It also makes this finding and **`F-02-032`** a matched
pair: the same false conclusion appears in the story (*"`NudgeStreamer` … is **unaffected**"*) and in
the source.

**Impact**

Donor funds accumulate in a streamer buffer that nothing can drain until minter configuration is
completed. Fully recoverable by completing configuration, so this is a **runbook hazard, not a
loss**. Magnitude is not a fixed sum: both production donors are **stateless sweepers** that
forward their entire balance on every dispatch, so the amount at risk is *all donor throughput*
between `registerStream` and completed minter configuration.

**Why this is Low, on the argument that actually carries it.** In the parked state **`batchMint`
reverts for *everyone*.** The contract is not mis-sequenced-but-working, it is entirely
non-functional, so this is a **bring-up window** in which nobody is minting and the condition
announces itself on the first smoke test. Value parking during pre-commission, in protocol custody, in
a state that is **loud** and **unilaterally unlockable by the owner** (`setTokenMinter` +
`setDispatcherIndex`), is Low. Both escalation branches were taken and both fail: *"configuration is
never completed"* is the absence of a deployment, not an attack path, with the unilateral unlock
available throughout; and *"the batchMinter is repointed"* is permanent stranding that is already
tracked separately at Low (ledger `4a1d8edc92…`, whose title covers both the decommission and the
permanent-de-whitelist case). The compound of the two was considered for Medium and declined
affirmatively: it needs two privileged actions and strands only optional-incentive funds already sunk
from yield (opportunity cost, not loss).

**Recommended Mitigation**

**Preferred — one change closes three open items.** Add a `rescueERC20`-equivalent, or better a
`deregisterStream`, to `NudgeStreamer`. That single change closes **this finding**, ledger
**`4a1d8edc92…`** (*"the streamer has no rescue"*, open) and the **permanent-de-whitelist stranding**
at once — three open items, one fix, which is more useful than three separate documentation asks. Note
the standing counter-argument recorded against `4a1d8edc92…`: an owner rescue would let the owner
divert third-party donations, and the pass-through-no-custody design is defensible. A
`deregisterStream` that settles to the **registered batchMinter** rather than to an owner-chosen
address satisfies both concerns.

**Also, and independently:** restore a config-completeness precondition on `setNudgeTokenWhitelist`
(or add one to `NudgeStreamer.registerStream`), and **correct the NatSpec at `:317-320`** — as written
it is the affirmative misstatement quoted above, and leaving it in place while adding a runbook note
elsewhere would leave the misstatement to win. Document the required ordering explicitly: **complete
minter configuration before whitelisting and registering a stream.** Fold the remediation into
story-032 while it is still open (see `F-05-032` in `spec-conformance.md`).

*Cross-reference*: **do not collapse with ledger entry `4a1d8edc92…`** (open). That entry is *"the
streamer has no rescue"*; this is *"story-032 opened a new route into needing one"* — the
pre-commission mirror of that entry's decommission case. They **compound**.

**Live-config dependency**: resolve the `nudgeStreamer` address, whitelist contents, and streamer
registrations **from chain**, not from deploy records, before acting (MR-26-05 / GAP-26-04).

---

### [L-05] `setNudgeStreamer` accepts any address with no structural probe: a mis-point is a permanent silent no-op <!-- id: pns26l5 -->

**Severity**: Low

**Location**: `src/BatchNFTMinterMultiToken.sol:297-300`

**Description**

`setNudgeStreamer` accepts any address with no structural probe. It is **asymmetric with its own
counterparty**: `NudgeStreamer.registerStream` deliberately probes the batchMinter with
`isNudgeToken` (`:127`, documented at `:10-17`) precisely to confirm the target type — the reverse
direction has no equivalent check. Aggravating: the event is emitted **before** assignment
(`:298-299`), so a mis-point reads as a clean success in the logs.

**Impact**

The flush loop succeeds and does nothing, **forever**, while donor buffers accumulate unreachably
on the correctly-registered-but-unpointed streamer. Recoverable by re-pointing.

**Partial defeat — carried forward honestly, not overclaimed.** For an **EOA the pattern is
defeated**: solc 0.8.20 retains the `extcodesize` check for void-returning external calls, so the
flush reverts loudly. The reachable residual is a **contract with a permissive fallback** — a
Safe, a proxy with an unset implementation, another Phoenix contract.

**Disclosure — Medium-class cross-project precedent, and why this is nonetheless Low.** This
root-cause class has been filed at **Medium** in two other projects: **phStaging run-21 M-02** and
**stable-yield-accumulator `0xd62cbfe8`**. Both were genuine Mediums. The distinction that holds
this one at Low is substantive, not presentational: in those cases the brick sat on a
**value-bearing path**, whereas here it degrades an **optional incentive** whose funds remain in
protocol custody, keep accumulating on the correctly-pointed streamer, and flush normally once the
pointer is fixed — **fully recoverable, no value lost**. The likelihood limb is also weaker: the
EOA case is *defeated* by solc 0.8.20's retained `extcodesize` check, leaving only a contract with
a permissive fallback.

**Recommended Mitigation**

Probe the target structurally before assignment — mirror `registerStream`'s approach by calling a
known view on the candidate streamer (e.g. a `duration` or stream getter) and reverting on empty
returndata. Emit the event **after** assignment.

**A bare zero-address check would be actively wrong**: `address(0)` is a deliberate disable path.

*Cross-references*: **`Q-03` was withdrawn before publication** (see §"Withdrawn before
publication") — the adjacent missing-interface-*declaration* item is therefore no longer filed, and
this finding stands alone on the unvalidated *setter*. **The withdrawal takes nothing from L-05:**
the two were separate root causes with separate fixes, and the permissive-fallback precondition they
shared is adjudicated **here**, correctly — silence, plus the event emitted *before* assignment at
`:298-299`, is what makes a mis-point non-obvious rather than obvious owner error. (Q-03 invoked
Law 3 to suppress that same precondition, which contradicted this finding; that inconsistency was one
of the reasons it was withdrawn.) Not the same as ledger entry `cf332bf46c…` (open), which is the
**interface documentation** gap on `INudgeStreamer`; keep that one **open**, only partially addressed.

**Live-config dependency**: the deployed `nudgeStreamer` address must be resolved **from chain**
(MR-26-05 / GAP-26-04).

---

### [L-06] story-030 left an unenforced ordering guarantee standing inside the comment block it rewrote, and its own new text contradicts it <!-- id: pns26l6 -->

**Severity**: Low *(dual-routed: also `F-04-030` in `spec-conformance.md` — intentional, not a
duplicate)*

**Location**: `src/BatchNFTMinterMultiToken.sol:659-665`; contradicting text at `:695-702`

**Description**

The comment block at `:659-665` (claim 2, *"and vice versa"*) asserts a **symmetric**
mutual-non-interference guarantee between the caller's refund and the pot payout, and attributes
it to **ordering**. Neither half survives:

- Independence comes from **sourcing** (`budget` vs `snapshot`), not from sequence.
- In the one case where ordering *does* bind — erosion between step 5 and step 9 — refund-first
  charges the shortfall to `D`, then `P`. So *"a refund funded out of a payout that is owed"* is
  what the ordering **causes**, not what it prevents.

story-030's own Anchor E addition 20 lines below (`:695-700`, *"charged to the pot, silently"*)
states the contradicting fact.

> ⚠ **DISCRIMINATOR — L-06 vs Q-01. DO NOT COLLAPSE.** Both findings are "a comment asserts a
> property the code does not establish", but they are **not the same defect**. **L-06 is
> *undocumented cross-repo coupling + in-file self-contradiction*:** the asserted property is
> **false**, the file itself refutes it 20 lines later, and its real safety depends on a
> **cross-repo** coupling to `NFTMinterV2._executeMint` @ `yield-claim-nft` `d4cc563` that no comment
> here discloses (WATCH-26-02). **Q-01 is *machine-proved + locally self-consistent*:** the asserted
> property is **true** (Halmos-proved for 2 streams, no fuzz counterexample), locally consistent, and
> token-independent — only its *cited basis* is wrong. Fixing L-06 requires deleting a false claim
> **and** documenting an external dependency; fixing Q-01 requires restating a basis. Neither fix
> closes the other. Full comparison table under **Q-01**.

**Impact**

A **false safety guarantee on a load-bearing property**. There is **no value transfer at this
commit**. The harm is prospective: a future editor relying on the ordering rationale could reorder
or extend the flow and break the property the block claims is already guaranteed.

**Why this is a documentation finding and not a Medium.** The step-5 → step-9 erosion path is
**not reachable without a token-side property**, which was proved rather than assumed. The
required behaviour is a mechanism that reduces this contract's `paymentToken` balance between the
pull at `:581` and the balance read at `:708`, other than the minter's `transferFrom` of `price` —
i.e. a negative rebase, an admin clawback/burn on a third party's instruction, or a
fee-on-transfer variant that debits the sender `price + fee`. All three are C4-invalid standalone.
The contract's own comment at `:700-701` already names the first (*"a negative-rebase prime token
suffices"*), so the code and this classification agree. On a plain 18-decimal ERC20:
`budget ≤ credited` (`:604` takes `min`); the mint loop's decrement equals its outflow exactly; no
other outflow exists inside `batchMint`; therefore the `available` cap at `:709` never binds,
`refund == budget` always, and no shortfall is charged to `D` or `P`. Consequently
`refund > paymentAmount` is **structurally impossible** and there is **no value transfer to
classify**.

**Recommended Mitigation**

Correct the block at `:659-665` to state that independence comes from **sourcing** (`budget` vs
`snapshot`), not from sequence, and reconcile it with the Anchor E text at `:695-702` that
currently contradicts it. Additionally, **document the cross-repo `config.price` coupling on the
`phoenix-nft-staking` side** — it is currently load-bearing and unstated.

**Watch note — WATCH-26-02 (this stays a documentation finding only because of a token-side
requirement, resting on an undocumented cross-repo coupling).** The no-erosion proof depends on
one leg that lives in **another repository**: `batchMint:646` reads `price` from
`configs(_dispatcherIndex)` and `:649` decrements `budget` by exactly that, while
`NFTMinterV2._executeMint` (`yield-claim-nft` @ `d4cc563`, `:179-183`) reads
`uint256 price = config.price` and executes `safeTransferFrom(msg.sender, config.dispatcher,
price)` — the same storage slot, in the same transaction, with no interleaving write, and with the
price ramp at `:188` happening *after* the transfer. **That coupling is undocumented on the
`phoenix-nft-staking` side.** If `NFTMinterV2` is ever changed so that the amount charged is not
the `config.price` the batchMinter read — a consumption-side fee, a two-pull mint, or a price write
before the transfer — then `budget` under-decrements, the erosion becomes reachable **on a plain
token**, and this ceases to be a documentation finding: it becomes a real **value-transfer finding
at Medium or High**. Break the coupling and you break the severity.

**Scope note**: in scope despite sitting outside story-030's enumerated anchor line range, because
story-030's own review pass (`:375-378`) explicitly disowns *"it wasn't in my anchor list"* as a
defence.

---

## QA / Hardening Notes

### [Q-01] Falsely-exhaustive NatSpec on a load-bearing pooled-custody invariant <!-- id: pns26q1 -->

**Severity**: QA

**Location**: `src/NudgeStreamer.sol:55-62` (contract NatSpec) and `:250-265` (`_accrued` NatSpec);
claim introduced at `2ba764e` (attribution verified with `git log -S`)

**Description**

Both NatSpec blocks assert the pooled-custody invariant `Σ buffer_i ≤ balanceOf(streamer)` as
holding *"by construction"*, established at **one** site (`:258`). The aggregate is **not**
structurally guaranteed by a clamp — there is no clamp. Per repo policy, in-source NatSpec carries
no suppression authority, and a falsely-exhaustive claim on a **load-bearing** invariant *raises*
rather than lowers severity.

**Impact**

A future editor reading `:258` will believe the aggregate is structurally guaranteed and will not
add the clamp that is not there. **No current exploit** — Halmos independently proved the
invariant for 2 streams and fuzzing found no counterexample, so the claim is currently **true but
unbacked by the mechanism it cites**.

**Recommended Mitigation**

Rewrite `:55-62` and `:250-265` to state what actually establishes the aggregate invariant
(measured-receipt crediting at `collectNudge`, plus the buffer cap in `_accrued`), **or** add the
clamp the text implies. Do not describe it as established at a single site.

*Split note (not a silent drop)*: the upstream profile finding had two limbs. Its consequence
chain (*"⇒ `batchMint` bricked"*) is not independently reachable and merged into **L-01**; its
documentation claim is this entry. Both limbs are preserved.

> ⚠ **DISCRIMINATOR — Q-01 vs L-06. DO NOT COLLAPSE THESE TWO DOCUMENTATION FINDINGS.** Both are
> "a comment asserts a property the code does not establish", and a later run reading only the
> one-line summaries could plausibly merge them. They are distinguished by **what the shipped text is
> wrong about**, and the difference changes the remediation:
>
> | | **Q-01** (`e16a9cac…`, `src/NudgeStreamer.sol:55-62`, `:250-265`) | **L-06 / F-04-030** (`8c67e639…`, `src/BatchNFTMinterMultiToken.sol:659-665`) |
> |---|---|---|
> | Truth of the asserted property | **TRUE — machine-proved.** Halmos proved the aggregate for 2 streams (independently re-run and reproduced 2026-07-30); ~640k Foundry fuzzed calls found no counterexample | **FALSE.** Both halves of claim 2 fail: independence comes from *sourcing*, and ordering *causes* the very thing it claims to prevent |
> | What is wrong | Only the **cited basis** — "by construction" at one site, where a **conjunction of two** sites is what holds it | The **claim itself**, and its attribution to ordering |
> | Internal consistency | **Locally self-consistent** — nothing else in the file contradicts it | **In-file self-contradiction** — story-030's own Anchor E text 20 lines below (`:695-700`) states the opposite |
> | External dependency | **None** — token-independent, single-contract | **Undocumented cross-repo coupling** to `NFTMinterV2._executeMint` @ `yield-claim-nft` `d4cc563` (WATCH-26-02) |
> | Fix | Restate the real basis (credit **plus** the `_accrued` cap), or add the clamp the text implies | Delete/correct claim 2, reconcile with Anchor E, and **document the cross-repo dependency** |
>
> **Shorthand:** Q-01 is *machine-proved + locally self-consistent* (a true property with a wrong
> stated basis); L-06 is *undocumented cross-repo coupling + in-file self-contradiction* (a false
> property that the file itself refutes). One fix does not close the other, and merging them would
> lose the cross-repo watch (WATCH-26-02) entirely.

---

### [Q-02] `NudgeCollected.amount` repointed from request to receipt under a byte-identical ABI <!-- id: pns26q2 -->

**Severity**: QA

**Location**: `src/NudgeStreamer.sol:106-114` (declaration), `:211` (emit),
`src/INudgeStreamer.sol:14-18` (documented)

**Description**

story-031 repointed `NudgeCollected.amount` from the **requested** amount to the **measured
receipt**, under a **byte-identical ABI** — no compile-time, ABI-level, or topic-level signal of
the semantic change.

**Impact**

Off-chain only, and a **silent under-count** — the direction an operator is least likely to
investigate. There is no on-chain way to learn the credited value (`collectNudge` returns void).

**No on-chain desync — verified, not assumed.** No sibling contract consumes the event
(`grep -rn 'NudgeCollected' lib/yield-claim-nft/src` → 0 hits); `NudgeRatchet.dispatch` keeps no
cumulative sent-amount counter; the mint-debt ledger that *does* accumulate
(`NudgeRatchetMintDebtHook.onDispatch:122-130`) derives from the NFTMinter's `amount`, never the
streamer credit; and both production donors forward USDC, for which receipt == request.

**Recommended Mitigation**

Rename the event field (or add a second field) so the semantic change is visible at the ABI level,
and amend the declaration at `:106-114` and `INudgeStreamer.sol:14-18`. Consider returning the
credited amount from `collectNudge` so on-chain consumers can learn it.

**Open gap (GAP-26-05)**: whether any off-chain indexer sums `NudgeCollected.amount`. This
finding's *entire* residual is contingent on it. On-chain consumers are ruled out; off-chain ones
cannot be from here.

---

### [L-03] `NudgeRatchet`'s failure-mode enumeration omits `NudgeStreamer__ZeroReceived`, and diverges silently from `BalancerPoolerV2`'s failure semantics <!-- id: pns26l3 -->

**Severity**: QA — **rebanded from Low, and rescoped.** Label retained as `L-03` (labels persist;
see §"Count reconciliation").

**Location**: `src/NudgeStreamer.sol:93` (`NudgeStreamer__ZeroReceived` declared), `:199` (reverted —
new at story-031), `:158` (`NudgeStreamer__NotRegistered`), `:243`.
**Fix site**: `yield-claim-nft/src/dispatchers/NudgeRatchet.sol:29-38` (documentation).

### What changed in this finding, and why

The earlier title — *"a streamer revert bricks the mint, not just the flush"* — asserted the
**availability footgun** limb that **this run itself refuted**. Standing alone, that limb is a
reckless-admin item and therefore invalid: the hazard is documented accurately and in advance by the
counterparty contract, and it is triggered by a privileged wiring step for which that contract
supplies a numbered runbook. A finding whose title claims the limb its own analysis kills will be
scored on the title. So the finding now leads on the residual that **is** real, and the availability
mechanism is retained below as **flagged context** — deliberate, documented, and *not* the claim.

The reband to QA follows: once rescoped to two documentation items, the feature that justified Low
over QA is gone. `Q-01` and `Q-02` carry substantively identical material — documentation accuracy
with no reachable impact — at QA. This is the report's own standard applied consistently.

### The residual — the defect actually reported

**1. The `ZeroReceived` omission (the substantive gap; confirmed at source).** `NudgeStreamer`
declares `NudgeStreamer__ZeroReceived()` at `:93` and reverts it at `:199`. `NudgeRatchet`'s
failure-mode enumeration at `:29-38` lists `nudgeStreamer unset`, `NotRegistered`, `NotWhitelisted`
and `ZeroAmount` — and **`ZeroReceived` appears nowhere in `NudgeRatchet`** (verified by grep over the
file at `yield-claim-nft` @ `d4cc563`: zero hits). Story-031 widened the revert surface of the
un-isolated leg and did not update an otherwise-complete enumeration. This is present-tense,
demonstrated, and **not an owner action at all** — which is precisely why it survives the
reckless-admin rule that disposes of the availability framing.

**2. Failure-semantics divergence across two dispatchers on one streamer (supporting, weaker).** One
streamer, two dispatchers, **opposite outcomes for the identical condition**: `NudgeRatchet` fails
closed, `BalancerPoolerV2._dispatch` wraps the same hop to the same contract in a documented,
story-047-mandated `try/catch` and fails open. `BalancerPoolerV2`'s own NatSpec trains the reader that
*"a streamer misconfiguration is quiet"*; an operator carrying that model to `NudgeRatchet` is wrong.
Noted as **supporting, not as the basis** — it is partly self-defeating, since the operator wiring
`NudgeRatchet` reads `NudgeRatchet`'s NatSpec, which is accurate and ordering-prescriptive.

### Flagged context — the availability mechanism, documented and deliberate

`NudgeRatchet.dispatch` calls `collectNudge` bare, so a revert there bricks the **mint** itself
(`NudgeRatchet.dispatch` → `NFTMinterV2._executeMint` → `mint`) for every minter on that dispatcher —
not merely the flush. It fails **closed**, is recoverable in **one owner transaction**
(`registerStream`), and donor funds keep accumulating safely in the streamer buffer and flush
normally afterwards. **No value is lost**; nudge delivery is delayed, not destroyed, and users lose
reverted-transaction gas only. The hop is un-isolated **on purpose** — story-046 removed the
direct-transfer fallback deliberately and there is no donation-disable switch.

**This is context, not the claim.** `NudgeRatchet`'s own contract NatSpec (`yield-claim-nft` @
`d4cc563`, `:23-43`) discloses the entire hazard accurately and in advance: it names the exact revert
(`NudgeStreamer__NotRegistered()`), states the blast radius (*"every `dispatch`"*), covers the
`setBatchMinter` repoint case, and prescribes a numbered **Required ops ordering** with
`setNudgeStreamer` explicitly **last** — i.e. the mistake is the mistake that list exists to prevent,
at the very function that causes the harm. The Law-3 surprise test therefore **fails** for this limb.
**This is not deference to the NatSpec's "NOT an audit finding" clause** — per standing policy
in-source NatSpec carries no suppression authority, and that sentence carries none here. What does the
work is the *surrounding disclosure being accurate*, which was verified against the code rather than
taken on trust. The rule that *raises* severity applies to **falsely**-exhaustive documentation; this
documentation is true.

Against C4's Medium availability discriminators the mechanism is not attacker-inducible (it requires
a privileged config action), does not arise in normal operation without operator error, is not silent
(a self-naming custom error on the very first mint attempt, atomically), is recoverable, and loses no
value. Medium availability needs the outage to be attacker-inducible, **or** undetectable, **or**
unrecoverable. It is none of the three.

**It does not follow `L-01` on the issuer-event trigger either, and it fails that test harder.**
`NudgeRatchet`'s prime token is USDC (constructor-enforced 6 decimals) and the mint payment arrives on
the dispatcher in that same USDC via `NFTMinterV2._executeMint`'s
`safeTransferFrom(msg.sender, config.dispatcher, price)`. So under a **global USDC pause the mint is
already bricked at the payment leg**, before `dispatch` is ever reached — **zero incremental impact**
from the un-isolated hop. Only a *targeted blocklist of the batchMinter* is incremental, and its
recovery is messier than L-01's (`NudgeRatchet` has no donation-disable switch by deliberate design,
so escape means repointing `batchMinter` and registering the new pair — two-plus owner transactions,
stranding the old buffer). Messier, but still recoverable, still loud, still not attacker-inducible.

### Recommended Mitigation

**⚠ Do NOT wrap `collectNudge` in `try/catch`.** The earlier cross-repo fix request to that effect is
**withdrawn**, and this is the most important output of the run. **The reband to QA does not soften
this: the trap is unchanged and is the reason the reband is safe.** That fix is worse than the defect,
for two independent reasons:

1. **It converts a loud failure into a silent one.** `ATokenDispatcherV2.dispatch` (`:124-125`)
   executes `_dispatch(...)` **then** `hook.onDispatch(minter, amount, extraData)`. A swallowed
   `collectNudge` therefore lets `_dispatch` return successfully: the USDC stays on the dispatcher
   while the hook accrues mint-debt against `amount`, and nothing surfaces. That skew is transient and
   self-healing — `_dispatch` sweeps the whole balance on the next dispatch, so no permanent
   over-accrual occurs and **no unbacked-phUSD claim is filed** — but it is precisely the direction
   `NudgeRatchet:148-149` guards against, and it sits adjacent to the tracked DEDUP-001 unbacked-phUSD
   class in `yield-claim-nft`.
2. **It moves `NudgeRatchet` into L-05's failure class to escape a finding.** L-05 is filed
   specifically for a *silent* streamer misconfiguration, and `BalancerPoolerV2`'s NatSpec itself warns
   that its `try/catch` makes streamer misconfiguration *quiet*. Adding a catch here trades a
   self-diagnosing, one-transaction-recoverable revert for a quiet, indefinitely-accumulating
   misconfiguration.

It would also contradict a deliberate, documented design decision (story-046). The correct mitigation
is documentation and consistency, matching the honest severity:

1. **Add the missing `NudgeStreamer__ZeroReceived` row** to `NudgeRatchet`'s failure-mode enumeration
   at `:29-38`. This is the one substantive gap and the cheapest thing to fix.
2. **Document the deliberate divergence** from `BalancerPoolerV2`, at **three** sites — see the
   third-site note under `WATCH-26-04` below — so an operator cannot carry the wrong model between
   dispatchers.
3. **Keep the revert.** It is the correct, deliberate, story-046 behaviour.

The cross-file to `yield-claim-nft` still happens, but as a **documentation-consistency** item against
`NudgeRatchet:29-38`, not as a missing-guard item.

**Watch note — WATCH-26-03 (escalates to Medium — ⚠ JOINT RE-WEIGH, MEDIUM *FLOOR*).** Shared with
L-01: a plain-ERC20 counterexample to INV-1 escalates **both, from the same witness**. It would make
`_settle`'s transfer revert in *normal operation*, so the outage would arrive unannounced instead of
at bring-up.

> ⚠ **ONE INV-1 counterexample bricks mint AND flush in normal operation with no operator action.**
> The re-weigh is therefore **joint with L-01, on the combined shape** — two simultaneous
> routine-path availability outages, unannounced, with no operator trigger — **not** two independent
> Lows that each separately become a Medium. **Medium is the FLOOR of that re-weigh, not its
> ceiling.** See the fuller statement under `L-01`; both findings share this contingency and must be
> re-classified together or not at all.

The evidence state is as recorded under L-01 —
proved for 2 streams at wide bounds, **INCONCLUSIVE-timeout for ≥ 3 streams above 2^32**, N > 2
generalisation **hand-checked, not machine-proved**. Also escalates if `NudgeStreamer` acquires a
pause, deregistration, or `duration`-zeroing path, making the brick reachable from a routine live
operation.

**Watch note — WATCH-26-04 (documentation mitigates the surprise limb only — CORRECTED).** An earlier
draft of this note said the accuracy of `NudgeRatchet`'s NatSpec at `:23-43` is *"the entire basis"*
for the severity, and that editing it would **invalidate** the finding and make any
disclosure-less dispatcher **Medium**. **That over-states what documentation can do.** Accurate
documentation moves the **surprise / likelihood** limb and nothing else — it cannot move impact,
detectability, or recoverability, and those are code properties that hold this finding at Low/QA **on
their own**: not attacker-inducible, a self-naming atomic revert on the first mint attempt,
one-transaction recoverable, no value lost. Corrected:

> **Trigger.** `NudgeRatchet`'s NatSpec at `:23-43` is trimmed, reworded, moved, or drifts from the
> code; **or** any dispatcher acquires a `collectNudge` hop without an equivalent accurate,
> ordering-prescribing disclosure.
> **Effect: RE-WEIGH, with the footgun limb no longer mitigated — NOT "invalidated", and NOT
> automatically Medium.** Deleting the disclosure would make this an *undocumented* footgun with a
> loud, atomic, one-transaction-recoverable failure at bring-up, which is still Low/QA. A watch that
> promises a Medium it cannot deliver gets discounted the first time it fires.
>
> **Third mitigation site (new).** The disclosure is also doing **less** work than the earlier note
> credited it with, and the reason is a genuine weakness worth recording: the runbook lives in the
> **other repo**, on the dispatcher, and prescribes an ordering spanning three contracts — while
> `BatchNFTMinterMultiToken.setNudgeStreamer`'s **own** NatSpec (`:293-296`, function at `:297-300`)
> says nothing about the mint-brick consequence at all, and the ops runbook is not in this repo either.
> **An operator working from the phoenix side never sees the disclosure.** Mitigation item 2 therefore
> extends to a third site: `setNudgeStreamer`'s NatSpec on the phoenix side, alongside the two
> dispatcher sites.

---

## Withdrawn before publication — `Q-03` (duck-typed structural guard with no compiler enforcement)

**`Q-03` was filed, reviewed, and then WITHDRAWN. It is not a finding of this run.** It is recorded
here rather than deleted so that a reader comparing artefacts can see that `Q-03` existed and why it
is gone — the label is retired and will never be reused.

- **Site it named**: `src/BatchNFTMinterMultiToken.sol:159`, `:289`; `src/NudgeStreamer.sol:15-17`,
  `:127` — the duck-typed `isNudgeToken` call that is `registerStream`'s sole admission check.
- **Claim**: coupling by convention rather than inheritance means a signature change on either side
  compiles clean.

**Why it was withdrawn — its own text is the argument.** It stated *"impact: **None at this
commit**"*, that drift *"**fails closed**"*, and that *"**This is not a security finding**"*. Its
origin was unvalidated Slither missing-inheritance noise. C4 discourages non-critical issues and puts
*"common findings from automated tools without a demonstrated H/M exploit path"* out of scope — so it
is out of scope twice over. It additionally contained a reasoning error: it dismissed its only
false-accept path (an owner-supplied address with a permissive fallback) as obvious owner error
suppressed under Law 3, while **L-05 is filed on exactly that precondition**. The same condition
cannot be Law-3-suppressed in one entry and finding-sustaining in the next; L-05's treatment is the
correct one.

**Law 1 is not engaged by this removal, and that is checked rather than asserted.** The
no-silent-drop rule protects findings that could hide an exploit. This one has **no security limb by
its own text**, so dropping it cannot conceal one — and it is not being dropped silently: it is named
here, its ledger entry is recorded as withdrawn in the ledger's `run26` block, and its finding record
was removed with the withdrawal recorded in the same place. What a retained `Q-03` *would* cost is
reader credibility, which the quality standard says the report cannot afford.

**Nothing else moves as a result.**

- **Ledger `cf332bf46c…` stays `open` and *partially addressed*.** It is the `INudgeStreamer`
  **documentation** gap, a different root cause from the missing declaration, and it must **not** be
  closed against `Q-03` in either direction — including not being closed on the grounds that `Q-03`
  went away.
- **`L-05` is unaffected** and now stands alone on the unvalidated setter (see its cross-references).
- The interface **is** still worth declaring explicitly; that is now an ordinary hardening suggestion
  with no finding attached, best done alongside `L-05` and `cf332bf46c…`.

---

## Systemic observation — the un-`try/catch`'d-external-call class has three open instances

**This is a policy observation, not a finding, and explicitly NOT a severity raise on any instance.**
It is recorded because three open, unfixed instances of one root-cause class across one contract
family is a pattern the owner should see *as* a pattern, and no per-finding entry can show it. It is
**not counted in this run's tally** and it is **not a duplicate of the three** instances, each of
which remains separately filed at its own honest severity:

| Instance | Site | Ledger | Status |
|---|---|---|---|
| `NFTStakerDepletion._syncBudget` → `dispatcherHook.pull()` | staker family | `966e717669…` (Low) | **open** |
| copy #4, same class via a different trigger | staker family | `1887dbe136…` (Low) | **open** |
| `batchMint`'s streamer flush loop | `BatchNFTMinterMultiToken.sol:528-536` | `L-01` (Low, new this run) | **open** |

The recommended remediation has the **same shape** in all three, and none of the three has landed.
The class-level statement, which is what a per-instance report cannot make: **adopt an explicit
external-call isolation policy for optional cross-contract legs — isolate (`try/catch` + event) where
nothing downstream consumes the result, and fail loud where something does.** The second half is not
boilerplate; it is the distinction that makes `L-01` part 2 correct and the withdrawn `L-03`
`try/catch` wrong, and a policy stated without it would license the harmful fix.

**Recurrence does not raise any instance's severity.** Each instance's impact and precondition are
what they are, and all three were checked individually for mislabelling; none is mislabelled. Filing
this is a recall action so the pattern is visible, not an inflation. A corresponding ledger entry
(`SYS-26-01`) carries the same statement.

---

## Watch Notes Carried by This Bundle

| Watch | Carried by | Trigger | Becomes |
|---|---|---|---|
| **WATCH-26-02** | L-06 | The cross-repo `config.price` coupling breaks (`batchMint:646` ↔ `NFTMinterV2._executeMint:179-183` @ `yield-claim-nft` `d4cc563`) — consumption-side fee, two-pull mint, or price write before transfer | A real value-transfer finding, **Medium or High** |
| **WATCH-26-03** | **L-01 and L-03** (same counterexample escalates both) | A plain-ERC20 counterexample to INV-1 (`Σ buffer_i ≤ balanceOf(streamer)`); or `NudgeStreamer` acquires a pause / deregistration / `duration`-zeroing path | **⚠ JOINT RE-WEIGH — Medium FLOOR, not Medium ceiling.** One INV-1 counterexample bricks **mint AND flush in normal operation with no operator action**, so L-01 and L-03 are re-weighed **together on the combined shape** (two simultaneous routine-path outages, unannounced, no operator trigger) — not as two independent Lows that each become a Medium. Re-classify jointly or not at all |
| **WATCH-26-05** *(new — replaces the residual `N > 2` symbolic gap with a maintainable code invariant)* | **L-01 and L-03** (via INV-1), and `Q-01` / `F-01-031` (which cite INV-1's basis) | **`NudgeStreamer` reads or writes more than one `Stream` struct per state transition, or introduces aggregate state.** Concretely: any cross-stream read, any loop over streams, or any per-token running total | The **`N > 2` reduction is invalidated** and **INV-1 demotes to proved-at-2-streams-only**. WATCH-26-03's contingency then rests on an unproved aggregate, and both L-01 and L-03 must be re-weighed on that weaker footing |
| **WATCH-26-04** *(corrected — see §L-03)* | L-03 | `NudgeRatchet`'s NatSpec at `:23-43` is edited, trimmed, moved or drifts from the code; or any dispatcher acquires a `collectNudge` hop without an equivalent ordering-prescribing disclosure | **RE-WEIGH**, footgun limb no longer mitigated — **not** "invalidated", **not** automatically Medium. Documentation moves the surprise/likelihood limb only; impact, detectability and recoverability are code properties and hold this at Low/QA on their own. **Mitigation covers three sites**, the third being `BatchNFTMinterMultiToken.setNudgeStreamer`'s own NatSpec (`:293-296`), which discloses nothing |

---

## Coverage Gaps

Stated so that absence of findings is not mistaken for evidence of absence.

1. **Semgrep's silence is NOT evidence.** The run has **no usable Solidity security ruleset**.
   Semgrep scanned 14 files with 50 rules and returned **253 findings, all INFO severity, with
   zero security rules fired**. Its clean security result is an artefact of rule availability, not
   a property of the code, and must not be cited as corroboration for any finding's absence.
2. **The ≥ 3-stream symbolic gap.** INV-1 is Halmos-**proved** for **2 streams** at wide bounds
   (buffers/balance < 2^96, `rewardPerSecond` < 2^128, elapsed < 2^40) across all three write
   sites, including the strong no-brick form. The **≥ 3-stream case is INCONCLUSIVE-timeout above
   2^32** — passing only in the narrowed 2^32 / 2^48 / 2^24 domain — and the **N > 2
   generalisation is hand-checked, not machine-proved**. A Halmos timeout is not a proof in either
   direction. This gap is the open door for WATCH-26-03, which governs both L-01 and L-03.

   **⚠ THE RESIDUAL IS NOW EXPRESSED AS A CODE INVARIANT, NOT AS A SOLVER LIMITATION (WATCH-26-05).**
   Restating "Halmos timed out above 2^32 for N ≥ 3" is not maintainable — it describes the tool, not
   the code, and it decays the moment the solver, the bounds, or the version changes. What the
   hand-checked reduction **actually depends on** is a structural property of the contract, and that
   property is watchable:

   > **`NudgeStreamer` must never read or write more than one `Stream` struct per state transition,
   > and must never introduce aggregate state.** Any cross-stream read, any loop over streams, or any
   > per-token running total **invalidates the `N > 2` reduction** and **demotes INV-1 to
   > proved-at-2-streams-only.**

   This holds at `9611312`: every write site touches exactly one `Stream`, so the aggregate
   `Σ buffer_i ≤ balanceOf` follows from the per-stream property by summation, which is why two
   machine-proved streams generalise at all. **Encode and watch that invariant** — a reviewer can
   check it by reading a diff, whereas "the solver timed out" can only be re-discovered by re-running
   the solver. Tracked as `WATCH-26-05`; it does not replace the owed machine proof of the ≥ 3-stream
   aggregate at wide bounds, it makes the reduction's precondition auditable in the meantime.
3. **Token classes untested by design.** Fee-on-transfer, rebasing, hook-bearing (ERC-777-style),
   and non-18-decimal tokens were not exercised. This is a deliberate scoping decision consistent
   with the standing known-invalid list, not an oversight — but it means the token-side
   preconditions that hold L-01, L-03 and L-06 at their current severities are **assumed absent,
   not verified absent**. Introducing any such token to a nudge path invalidates those
   assessments.
4. **Live on-chain configuration was not resolved (MR-26-05 / GAP-26-04).** `nudgeSize`, nudge-token
   whitelist contents, streamer registrations, per-pair inflow rates, and the deployed
   `nudgeStreamer` address are **not verifiable from the repository**, and this family has a
   standing history of deploy records disagreeing with chain state. **Resolve these values from
   chain, not from deploy records**, before acting on L-02, L-04 or L-05.
5. **No PoCs in this bundle.** With 0 High and 0 Medium, no finding here meets the coded-PoC
   threshold. L-01's killed aggregate mechanism was nonetheless machine-checked (INV-1 PASS at
   128,000 calls/invariant in Foundry (~640k total, reproduced; the Medusa figures previously cited here are RETRACTED as not substantiated - see `tier3/invariants.md`), anti-vacuity
   measured at 600/600 non-trivial checks across 3 simultaneously-funded streams on one token,
   with the harness proven able to fail against a 1-wei over-credit mutant).

---

## Appendix A — Automated Report (4naly3er)

> **This appendix is unvalidated automated output.** It was produced by 4naly3er, the C4-style
> automated QA/gas report generator, and **no entry in it has been individually reviewed,
> confirmed, or endorsed** by this audit. It is attached as a mechanical baseline only.
> Treat every line as a candidate, not a finding. **The 4naly3er labels are its own and are
> unrelated to this report's `L-`/`Q-` labels** — in particular its "Medium Issues" section is
> **not** a Medium finding of this audit, and its `M-2 Centralization Risk for trusted owners`
> (92 instances) is a blanket `onlyOwner` enumeration that Law 3 suppresses for this project.
> That is why this report's Centralization count is **0**.

**Full output**: [`4naly3er-report.md`](./4naly3er-report.md) (7,966 lines)

**Invocation** (recorded for reproducibility — note that argument 3 is a **scope list**, not a
remappings file, and that `remappings.txt` resolves relative to `basePath`, so `basePath` must be
the submodule root):

```bash
cd /home/justin/code/audits/tools/4naly3er
yarn analyze /home/justin/code/audits/lib/phoenix-nft-staking <scope-list>.txt
# scope list = the 14 first-party src/*.sol paths, relative to basePath
# output: tools/4naly3er/report.md -> copied to submissions/4naly3er-report.md
```

**Coverage**: all **14** first-party `src/*.sol` files parsed and reported on; imports resolved
via the submodule's own `remappings.txt`; no unresolved-import or parse errors. The project's
nested `lib/**` (third-party and forked dependencies) is excluded, per scope policy.

**Category counts as reported by the tool** (unvalidated):

| Section | Categories | Total instances |
|---|---|---|
| Gas Optimizations | 14 (`GAS-1` … `GAS-14`) | 979 |
| Non-Critical Issues | 25 (`NC-1` … `NC-25`) | 712 |
| Low Issues | 12 (`L-1` … `L-12`) | 192 |
| "Medium" Issues | 4 (`M-1` … `M-4`) | 104 |

Highest-count categories, for orientation only: `GAS-5` "operations that will not overflow could
use `unchecked`" (383), `GAS-6` "use custom errors instead of revert strings" (134), `GAS-14`
"`!= 0` instead of `> 0`" (116), `NC-10` "functions longer than 50 lines" (153), `L-7` "loss of
precision" (65), `M-2` "centralization risk for trusted owners" (92, Law-3 suppressed as above).

A handful of tool categories touch sites this report discusses independently — notably `NC-13`
"lack of checks in setters" (23) and `L-3` / `NC-1` "missing `address(0)` checks when assigning
address state variables" (12), which overlap the *area* of **L-05**. The tool's generic
recommendation there would be **wrong for `setNudgeStreamer`**: `address(0)` is a deliberate
disable path, and the correct fix is a structural probe, not a zero-address `require`. See L-05.
This is a concrete illustration of why the appendix is not endorsed.
