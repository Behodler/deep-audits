# Tier-2 Story Faithfulness (Law 2) — phoenix-nft-staking run-26

- **Target**: `lib/phoenix-nft-staking` @ `9611312` (read-only)
- **Range**: `5015f1b..9611312`, 13 commits
- **Mode**: regression
- **Scan type**: story-faithfulness
- **Timestamp**: 2026-07-30

## Stories checked

| Story | Commits | Doc state | Verdict |
|---|---|---|---|
| story-030 — documentation accuracy: stop asserting unenforced guarantees | 11 (`a72e650`..`d2506c1`) | `complete` | **DEVIATION** (F-01) |
| story-031 — credit `collectNudge` with the amount RECEIVED | 1 (`2ba764e`) | `complete` | **DEVIATION** (F-02, F-03) — mechanism faithful, documentation obligation not met |
| story-032 — remove the admin-time payment-token whitelist gate | 1 (`9611312`, HEAD) | **`review`** | **DEVIATION** (F-04) — contract change faithful *including* the wider blast radius; the story's own cross-contract dependency claim is false |

**No UNSAFE-STORY.** Law-1 override was applied independently to all three (see §5). None of the three stories' *intended* behaviour introduces an exploit.

---

## 0. Two corrections to the intake framing (attribution)

Both of the surviving over-claims handed to this agent as "story-030 misses" are attributed
elsewhere by `git log -S`. Recording this because a faithfulness finding filed against the
wrong story sends the fix to the wrong owner and lets the real one close clean.

**(a) `NudgeStreamer.sol:56-57` / `:258-261` were authored by story-031, not left behind by story-030.**

```
$ git log --oneline -S "rather than by convention"  -- src/NudgeStreamer.sol
2ba764e [story-031] Credit NudgeStreamer.collectNudge with the amount RECEIVED, not sent
$ git log --oneline -S "established at ONE site"    -- src/NudgeStreamer.sol
2ba764e [story-031] ...
$ git log --oneline 5015f1b..d2506c1 --name-only | grep -c NudgeStreamer
0
```

`src/NudgeStreamer.sol` appears in **no** story-030 commit and in **none** of story-030's
File Locations table. The text did not exist when story-030 ran. It cannot be a story-030
miss; it is a story-031 deliverable. Filed as **F-02**.

**(b) `BatchNFTMinterMultiToken.sol:659-665` was authored by story-029 and sits just *above*
Anchor E's quoted range.**

```
$ git log --oneline -S "ORDER IS LOAD-BEARING, IN TWO PLACES" -- src/BatchNFTMinterMultiToken.sol
0318089 [story-029] GREEN: budget-tracked refund makes paymentToken as nudge token safe
```

At `5015f1b` the ORDER block occupied `:634-640`; Anchor E's quoted range begins at `:643`
(`// refund <= paymentAmount HOLDS BY CONSTRUCTION`). The Anchor E commit `bae1a6e` does not
touch a single line of it. So it is **outside the anchor's enumerated line range** — but
**inside the same contiguous step-9 `//` comment block that Anchor E rewrote**, and story-030's
own new text now contradicts it three paragraphs later. That is what makes it in scope rather
than out. Filed as **F-01**, with the scope argument stated from the story's own text.

---

## F-01 — story-030 left an unenforced ordering guarantee standing inside the very comment block it rewrote, and its own new text contradicts it

- **type**: `faithfulness`
- **storyTag**: `story-030` (doc state `complete`)
- **severity**: `potential-low` (QA)
- **contract**: `src/BatchNFTMinterMultiToken.sol`
- **function**: `batchMint` (step 9 rationale block)
- **line**: 664 — **lineStart** 659, **lineEnd** 665
- **lawImpacted**: 2
- **securityEscalation**: `false`
- **confidence**: high

### Intent violated

`storyDoc` title and Story Overview (`030-…md:1`, `:11`):

> "# Documentation and comment accuracy: **stop asserting guarantees the code does not provide**"
>
> "The nft-staking repo's docs and comments assert several guarantees that the code does not
> actually establish. … Fix the prose so **no future auditor re-derives a defect that is not
> there**, and no future author 'fixes' the intended economics to match an inaccurate sentence."

Anchor E's DECIDED text (`:157-160`) — the required content for this exact comment block:

> "**DECIDED: option (b) — keep the cap, fix the comment.** … The corrected comment must state:
> … it **cannot** degrade a caller-credit shortfall, because it is not caller-scoped — such a
> shortfall is absorbed by `P` first."

And the acceptance standard the story's own review pass established (`:375-378`, Autonomous
Decision 4 of the Review Results):

> "**Did not restrict the search to the story's named anchors.** … The story's purpose is stated
> in **semantic** terms ('no future auditor re-derives a defect that is not there'), so the
> acceptance check had to be semantic too. … *Alternatives*: Validating only against the
> checklist — **rejected as testing the check rather than the property it stands for.**"

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

Claim 2 asserts a **symmetric** mutual-non-interference guarantee ("and vice versa") and
attributes it to the **ordering**. Neither half survives:

1. **The ordering is not what establishes it.** In the ordinary case *both* orderings are
   solvent — the refund is sourced from the tracked `budget` (`:711`) and the payout from the
   pre-loop `snapshot` (`:833`), and the balance at step 9 is `P + (credited − C) + D ≥ P + budget`.
   What makes the two transfers independent is their **sourcing**, not their sequence. Tier-1
   reaches the same conclusion independently (`profiles/BatchNFTMinterMultiToken.md:68-76`).
2. **The symmetry is false in the one case where the ordering does bind.** Under any erosion of
   the contract's payment-token holdings between step 5 and step 9, refund-first means the
   refund is paid in full at `min(budget, available)` and the shortfall is charged to `D` (this
   batch's donations, owed to the *next* claimant) and then to `P`. If erosion `≤ D` the batch
   **succeeds silently** with the refund funded out of value owed to the payout side; if
   erosion `> D` the payout's `safeTransfer` reverts the whole batch. In neither branch is the
   refund ever the party that degrades. So "a refund funded out of a payout that is owed" — the
   `vice versa` half — is exactly what the ordering *causes*, not what it prevents.

### Why this is a story-030 deviation and not out-of-scope drift

Story-030's own Anchor E addition, 20 lines below at `:695-700`, states the contradicting fact
in terms the story required:

> "DURABLE RESIDUAL — `budget` is a ONE-SHOT MEASUREMENT … Any erosion of this contract's
> payment-token holdings AFTER that point is therefore **charged to the pot, silently**"

The story thus shipped a comment block that asserts mutual non-interference by construction in
its opening paragraph and admits silent pot absorption in its closing one. This is the exact
failure mode the story was written to remove — an operating property stated as a construction —
newly **self-contradicting** as a result of the story's own edit. Per the repo's standing
principle (`MEMORY.md` → in-source NatSpec carries no suppression authority), a falsely
exhaustive in-source guarantee raises rather than lowers severity, and a maintainer reads the
*cleaned* comment with more trust than the original.

### Remediation

Rewrite claim 2 to say what is true: the refund and the payout are independent because of their
**sources** (`budget` vs `snapshot`), and the ordering additionally fixes *which side absorbs an
erosion shortfall* — refund-first charges it to `D` then `P`, never to the caller. Delete "and
vice versa", or scope it. One sentence; zero behavioural change, consistent with story-030's
prose-only contract.

---

## F-02 — story-031 replaced one false NatSpec guarantee with another, and its own acceptance criterion is what asked for the over-claim

- **type**: `faithfulness`
- **storyTag**: `story-031` (doc state `complete`)
- **severity**: `potential-medium` (classifier's call; the code-side consequence is Tier-1 `LOCAL-NS-01`)
- **contract**: `src/NudgeStreamer.sol`
- **function**: contract-level NatSpec + `_accrued` NatSpec
- **line**: 56 — **lineStart** 55, **lineEnd** 62; second site **lineStart** 250, **lineEnd** 265
- **lawImpacted**: 2
- **securityEscalation**: `false` (the DoS chain routes separately via `LOCAL-NS-01`; this entry is the spec-conformance half)
- **confidence**: high

### Intent violated

`storyDoc` Background, the story's own framing of *why* it exists (`031-…md:24-32`):

> "### Why the current NatSpec is actively misleading
>
> `NudgeStreamer.sol:192-194` asserts: > … *The buffer cap guarantees the streamer can never
> transfer more than it holds* … The cap is per-`Stream.buffer`; custody is pooled per token.
> `Σ buffer_i` can exceed `balanceOf(this)` under an over-credit, so the guarantee is false
> across pairs. **Per this repo's standing principle, falsely-exhaustive documentation raises
> severity rather than lowering it — it is the reason an operator would never think to check.**"

### Actual behaviour at `src/NudgeStreamer.sol:55-62`

```solidity
///         That direction holds at the credit site too, and by construction
///         rather than by convention. `collectNudge` credits the MEASURED
///         receipt capped at the quoted amount, so a taxed token credits less
///         than was sent (never more) … The
///         resulting invariant — `Σ buffer_i <= balanceOf(this)` over every
///         pair on one token — is what makes the per-stream cap in `_accrued`
///         affordable out of the pooled per-token balance.
```

and at `:255-265`:

```solidity
///          Σ buffer_i  <=  IERC20(token).balanceOf(address(this))
///
///      summed over every `(batchMinter, token)` pair on one token. That
///      invariant is established at ONE site — the balance-delta credit in
///      `collectNudge`, which credits `min(received, amount)` measured
///      across the pull.
```

Both are unconditional. The credit at `:193-196` is a **one-shot measurement bracketing a single
`transferFrom`**, so it establishes the invariant *at credit time* and *only against shortfalls
occurring during the pull*. It is one-directional: it closes the fee-underpay direction and
leaves post-credit erosion of `balanceOf(streamer)` entirely undetected — negative-rebase,
burn-on-hold, a token zeroing a blacklisted holder, or a token-side admin sweep. Once the sum
exceeds custody the pre-fix failure chain reopens verbatim: first-settling pair drains a
sibling's backing → sibling `pullPendingStream` reverts → `batchMint` bricks for every reward
token, because the flush loop at `BatchNFTMinterMultiToken.sol:532-534` has no `try/catch`.
The mechanism is fully profiled at `profiles/NudgeStreamer.md` §5.1 (`LOCAL-NS-01`).

So the story's deliverable reproduces the anti-pattern the story was written to remove, at the
same contract, one release later. A reader of `:56` ("by construction rather than by convention")
is told precisely the thing that would stop them checking.

### The story text is the origin, not the execution

This is not an executing-agent slip. Story-031's Documentation checklist (`:168`) *instructed*
the unconditional wording:

> "Correct the false NatSpec at `NudgeStreamer.sol:192-194`: the buffer cap is **per-stream** and
> guarantees nothing about pooled per-token custody. **State the real invariant that now holds
> (`Σ buffer_i <= balanceOf(this)`, established at the credit site)** and where it is established."

and `:169` compounded it:

> "the 'dust always accrues in the protocol's favour' claim is **now TRUE by construction**"

The implementation is a faithful rendering of both instructions. The acceptance criterion itself
asserted a general invariant from a directional fix. Story-031's own review pass caught this and
recorded it as non-blocking Issue 1 (`:421-427`): *"A token that shrinks `balanceOf(streamer)`
after credit breaks it again — nothing at the credit site can prevent that."* That observation
was accepted without amending the shipped NatSpec, so the over-claim is live at HEAD.

**Law-1 check applied:** does the *story's intent* introduce an exploit? No. The mechanism it
specifies (`min(received, amount)`, snapshot after `_settle`, revert on zero receipt) is correct
and strictly safety-improving, and every one of the eight mechanism points verified at
`:193-211`. The defect is confined to the guarantee's stated scope. So this stays Law 2, and the
residual DoS reachability is carried by `LOCAL-NS-01`, not escalated here.

### Remediation

Scope both sites to the direction actually closed — e.g. *"the credit site establishes
`Σ buffer_i <= balanceOf(this)` **at credit time**, against under-delivery during the pull; it
cannot defend post-credit erosion of the pooled balance, so a negative-rebase or burn-on-hold
nudge token can still break the sum"* — and pair it with the `try/catch` recommendation on the
flush loop if the owner wants the brick closed rather than merely documented.

---

## F-03 — story-031's silent `NudgeCollected.amount` repoint is disclosed in the story but not at the site an indexer author reads

- **type**: `faithfulness`
- **storyTag**: `story-031`
- **severity**: `potential-low` (QA)
- **contract**: `src/NudgeStreamer.sol`
- **function**: `NudgeCollected` event declaration / `collectNudge` emit
- **line**: 107 — **lineStart** 106, **lineEnd** 114 (emit site `:211`)
- **lawImpacted**: 2
- **securityEscalation**: `false`
- **confidence**: medium

### What the story *did* address — so this is a narrow gap, not the headline

Contrary to the intake hypothesis, story-031 **does** address the semantic change squarely, as a
named accepted consequence (`031-…md:187`, Concerns §3):

> "**§3 — `NudgeCollected.amount` will carry `received`, not the sent amount; no fifth field
> added.** Adding a field is an event-ABI change that would force indexer/UI regeneration
> downstream. … **Consequence to accept:** any consumer summing that field sees a smaller number
> for taxed tokens — which is the true credited value. If the human wants the sent amount
> preserved on-chain, that is a deliberate event-ABI change and a follow-up story."

and it addressed vendored sibling copies for the *signature* (`:188`, Concerns §4: *"sibling repos
compile against vendored copies of `INudgeStreamer.sol`"*), and enumerated the five downstream
`collectNudge` call sites under "Not ABI-breaking" (`:202`). **On the axis the intake flagged —
"does the story address it?" — the answer is yes.** No faithfulness finding lies there.

### The residual gap

Two things the story's disclosure does not reach:

1. **The event declaration itself is unamended.** `src/NudgeStreamer.sol:106-114` still reads
   *"Emitted when a donor tops up a stream's buffer"* with no note that `amount` is now the
   credited receipt. The change is documented at the emit site (`:208-210`) and in
   `INudgeStreamer.sol:14-18`, but not on the declaration a downstream indexer author reads
   first. Story-031's own review recorded this as non-blocking Issue 3 (`:434-438`) and it was
   not actioned.
2. **The "Not ABI-breaking" analysis is scoped to calldata/returndata only.** Its five-call-site
   sweep verifies that each donor `forceApprove`s an exact amount and *ignores returndata* — true
   and sufficient for the call. It does not ask whether any donor keeps a **sent-amount-derived
   pot counter**, which `collectNudge`'s `void` return makes impossible to correct on-chain. The
   production donor is `NudgeRatchet.dispatch` in the `yield-claim-nft` sibling. Tier-1 flags this
   as an explicitly **UNVERIFIED cross-repo** handoff (`profiles/NudgeStreamer.md:165-172`), and
   this agent does not adjudicate it either — it is only reachable at all if a taxed or rebasing
   token is the nudge asset.

Same event topic, same four fields, same types, one non-indexed value silently repointed across a
deployment boundary. Any indexer reconciling `Σ NudgeCollected.amount` against donor-side sent
totals now disagrees with itself with no compile-time or ABI-level signal.

### Remediation

Add the receipt semantics to the event declaration NatSpec at `:106`. If any indexer spans both
deployments, the story's own escape hatch applies: a new event name or a version marker is the
only signal available, since the field's type is unchanged.

---

## F-04 — story-032's contract change is faithful *including* the four-revert blast radius, but its cross-contract dependency analysis ships a false "unaffected" claim

- **type**: `faithfulness`
- **storyTag**: `story-032` (doc state **`review`** — landed at HEAD, see F-05)
- **severity**: `potential-low` (operational hazard; Tier-1 `LOCAL-BM-01`)
- **contract**: `src/BatchNFTMinterMultiToken.sol`
- **function**: `setNudgeTokenWhitelist`
- **line**: 328 — **lineStart** 328, **lineEnd** 336; consequence sites `NudgeStreamer.sol:127`, `BatchNFTMinterMultiToken.sol:479`, `:532-534`
- **lawImpacted**: 2
- **securityEscalation**: `false`
- **confidence**: high

### The intake hypothesis is REFUTED — the wider blast radius is explicitly authorised

The removal deleted four admin-time reverts, not one: the payment-token identity check plus
`MinterNotConfigured`, `DispatcherNotConfigured` (index unset), and `DispatcherNotConfigured`
(resolved zero), all incidental to calling `_resolvePaymentPath()`. Confirmed at
`profiles/BatchNFTMinterMultiToken.md:173`. That is **not** Law-2 over-reach, because the story
anticipates it in a dedicated section and decides it deliberately (`032-…md:155-178`):

> "### The load-bearing side effect: `_resolvePaymentPath()` reverts when unconfigured
>
> … **today a token cannot be whitelisted before `setTokenMinter` and `setDispatcherIndex` have
> both been set.** That ordering constraint is a pure accident of where the gate happens to sit —
> it is not a deliberate invariant anywhere. Three tests pin it: … **Decision: remove the call
> too.** See Concerns §1 — **this is the one consequence of this story that reaches beyond the
> literal request.**"

and Concerns §1 (`:562-573`):

> "The literal request was to remove the require statement forbidding the collision. … **Decision:
> remove the derivation too** … This is the honest reading of 'liberate the whitelist', but it is
> **a genuine behavioural change beyond the one-line ask and is called out here for that reason.**
> If the human wants the ordering constraint kept, the gate can be replaced with a bare
> `_resolvePaymentPath();` call — ugly, but it preserves it. **Not recommended.**"

The checklist authorises inverting the three pinning tests by name (`:471-477`), and the
Documentation checklist requires recording the ordering change as *"the deployment-ordering change
downstream runbooks care about"* (`:534-537`). Per **Law 3** the removal of the payment-token
opinion is additionally a registered intentional owner decision and is not filed as a defect.
**Verdict on the blast radius: authorised, disclosed, faithful.**

### The actual deviation — the story adjudicated `NudgeStreamer` on mechanism and got the reachable-state answer wrong

Story-032 twice clears `NudgeStreamer` with the same reasoning (`032-…md:126-128` and `:383-385`):

> "Also not touched: `src/NudgeStreamer.sol`. `NudgeStreamer.registerStream` calls
> `isNudgeToken(token)`, **which is unaffected** — it reads `_nudgeTokenIndex`, and this story does
> not change how entries are added to it, **only what is refused**."
>
> "### Not a dependency
> - `NudgeStreamer` (`nft-staking:028`, `031`) — `registerStream` → `isNudgeToken` reads
>   `_nudgeTokenIndex` and **is unaffected**."

The mechanism claim is true and the conclusion drawn from it is false. What changed is not how
`_nudgeTokenIndex` is written but **what a `true` from `isNudgeToken` transitively witnesses**.
Before `9611312`, `isNudgeToken(token) == true` implied `tokenMinter != 0 && dispatcherIndex != 0
&& dispatcher != 0`, because no entry could be added without `_resolvePaymentPath()` succeeding.
`NudgeStreamer.registerStream` (`NudgeStreamer.sol:127`) gates on **nothing else** — that single
duck-typed call is its entire admission check. It was therefore relying on the deleted
preconditions as a free configuration-completeness proof. "Only what is refused" *is* the change
to the reachable state set.

Consequence, traced end to end:

1. Owner whitelists a token while `tokenMinter == 0` (now permitted, `:328-336`).
2. `registerStream(batchMinter, token, D)` succeeds — `isNudgeToken` returns `true`.
3. `collectNudge` is **permissionless** (`NudgeStreamer.sol:152`, no access control), so anyone —
   including the production `NudgeRatchet` dispatcher on a schedule — funds the buffer.
4. `batchMint` reverts `BatchMint__MinterNotConfigured` at `:479`, **before** step 3.5's flush loop
   at `:532-534` can ever run. Nothing drains the buffer.
5. `NudgeStreamer` has no rescue, no pause and no deregistration (ledger `4a1d8edc92`, open).

Recovery is a plain owner config call (`setTokenMinter` + `setDispatcherIndex`, then a qualifying
unpaused batch), so this is a **deployment-ordering footgun, not a loss** — which is why it is
Low and not Medium. But it is squarely Law-3 in scope: the check that made the bad ordering
*impossible* is gone, the story frames the removal purely as convenience ("no longer an ordering
constraint on deployment scripts", `:424-426`), and the story's own dependency section tells the
reader the streamer is unaffected. A competent non-malicious owner would be surprised that
following the newly-permitted ordering parks donor funds in a contract with no escape hatch.
Tier-1 files the code-side as `LOCAL-BM-01` (`profiles/BatchNFTMinterMultiToken.md:257-266`),
which must **not** be collapsed into `4a1d8edc92` — that entry is "the streamer has no rescue";
this one is "story-032 opened a new route into needing one". They compound.

**Law-1 check applied.** Does story-032's intended behaviour introduce an exploit? No. Tier-1
verified exhaustively that `_nudgeTokens` appears in **no** input to `budget` (written only at
`:604`/`:649`) and is **never** the subject or spender of a `forceApprove` (`:648`/`:655`), so the
whitelist has no data path to the refund magnitude or the approval — the removal is structurally
incapable of reopening `ycn19h1`. The frozen twin's differently-named runtime gate
`BatchMint__NudgeTokenMatchesPaymentToken` survives intact at `src/BatchNFTMinter.sol:98`/`:261-263`,
which was the story's single most dangerous mis-execution risk and was correctly avoided. The
same-denomination arbitrage is a registered accepted owner decision and is not re-filed.

### Remediation

Two options, both cheap. Either restore the completeness half without the payment-token opinion
story-032 deliberately dropped — `if (tokenMinter == address(0) || dispatcherIndex == 0) revert …`
on the add branch — or state the required sequence (configure minter + dispatcher → whitelist →
`registerStream` → fund) in `setNudgeTokenWhitelist`'s NatSpec and in the deployment runbook, and
correct the two "unaffected" claims in the story document.

---

## F-05 — story-032 has landed at HEAD while its story document sits in `review`

- **type**: `faithfulness` (process note)
- **storyTag**: `story-032`
- **severity**: `informational`
- **lawImpacted**: 2
- **confidence**: high

Per `CLAUDE.md` → Stories, the state folder is metadata and not a filter, so story-032 was graded
in full. Recording the state anyway because the guidance calls a landed-but-unclosed story worth
surfacing: `9611312` is HEAD of the audited range and the deliverable is wired, but
`032-remove-payment-token-whitelist-gate.md` remains under `review/whitelist-liberation/`, so its
acceptance criteria are formally still in flux. Its own Review Results record status **PASSED**
(47/47 items) and three deferred items, of which two are the owner's and one is the unpushed
branch:

- `phStaging2:072`'s six-row stale-claim reconciliation — **its phase-0 assertion of the
  now-deleted `BatchMint__RewardTokenIsPaymentToken` tripwire would fail if 072 were run as
  written.** Owner's job per Concerns §2; 072 is on ice and unbroadcast (owner-confirmed
  2026-07-30), so there is no live runbook breakage today.
- Branch `sprint/whitelist-liberation` is committed but **not pushed**.

No action for the audit beyond noting that F-04's remediation, if taken, lands while the story is
still open and can therefore be folded into it rather than filed as a follow-up.

---

## 5. Law-1 override — applied to all three stories, no escalation

The independent question *"if the code did exactly what the story says, would that be exploitable
or break a protocol invariant?"* was asked of each story separately from conformance:

| Story | Intended behaviour | Law-1 verdict |
|---|---|---|
| 030 | Prose only. Zero executable Solidity changed (verified at the bytecode level in the story's own record: deployed bytecode identical for 21,204 of 21,290 hex chars, divergence confined to the 64-char CBOR IPFS digest). | **Safe.** No mechanism to be unsafe. |
| 031 | `min(received, amount)` credit, snapshot after `_settle`, revert on zero receipt. Strictly safety-improving and directionally conservative — surplus is left uncredited (protocol-favourable), under-delivery fails closed. | **Safe.** The defect is in the guarantee's stated *scope* (F-02), not the mechanism. |
| 032 | Delete an admin-time check that story-029 had already reduced to defence-in-depth, plus three incidental config preconditions. | **Safe.** No data path from `_nudgeTokens` to `budget` or to any approval; frozen twin's runtime gate untouched; arbitrage is a registered accepted decision. The one new consequence (F-04) is a recoverable ordering footgun, not an exploit. |

No `type: "story-unsafe"` findings. No `securityEscalation: true`.

## 6. What was checked and found faithful (no finding)

Recorded so a later run does not re-derive these as gaps:

- **story-030, Anchors A–H**: all eight landed. Anchor A/B/C's "by construction a fraction of the
  cost" claim replaced with the yield-funded-subsidy framing at all three grep sites plus the
  fifth paraphrase site the review pass found (§5 MEV posture, `9c456f5`). Anchor C's "do not add
  a value-aware cap to the payout on the strength of this paragraph" is in shipped NatSpec — the
  highest-leverage line in the change, and it directly forecloses the withdrawn `pns25m1`
  remedy. Anchors D/E/F/G landed as specified, including Anchor E's DURABLE RESIDUAL and Anchor
  F's numbered two-obligation note on the step-5 `min`. The one retained `fraction of the cost`
  hit at `docs/multi-token-nudge.md:58` is scoped "in normal operation" and immediately followed
  by the policy-not-construction denial — the story's acceptance criterion was "zero hits
  *asserting a bound*", which is met.
- **story-031, all eight mechanism points**: `heldBefore` at `:193` taken **after** `_settle` and
  immediately before the pull (the story's own §1 "single highest-risk detail"); pull `:194`;
  delta `:195` (underflows and fails closed on a recipient-debiting token); cap `min(received,
  amount)` `:196`; distinct `NudgeStreamer__ZeroReceived` `:199`; `s.buffer += received` `:201`;
  single rate recompute reading `s.buffer` `:206` with no parallel derivation from `received`;
  event carries `received` `:211`. Frozen `src/BatchNFTMinter.sol` and `MockFeeOnTransferERC20.sol`
  byte-identical to base.
- **story-032, the contract diff**: exactly five non-comment deleted lines, all inside
  `setNudgeTokenWhitelist`. Zero lines of `batchMint`, `_snapshotRewards` or `_payRewards` changed
  (`git diff 2ba764e 9611312 -- src/`). Both ordering constraints intact. The two
  historical-incident tests were genuinely rewritten to pin story-029's budget mechanism rather
  than deleted or mechanically flipped — the story named this as the most likely place to take a
  shortcut, and it was not taken. The `bootToken`/repoint scaffolding was left as logic-unchanged
  coverage of the production repoint route per Concerns §8, with comment-only corrections.
- **story-032, the +17,000 gas snapshot shift**: not a `batchMint` change. Flat offset across
  counts 1/2/3 (so not loop work), inter-label deltas 30,855 before and after, cold-path labels
  byte-identical, and 2 cold accounts × 2500 + 6 cold slots × 2000 = 17,000 exactly — an EIP-2929
  test-harness pre-warming artifact of the deleted `_resolvePaymentPath()` call in the same tx.
  The new figures are the production-representative ones. Independently corroborated by two
  reviewers in the story record; not re-derived here.
