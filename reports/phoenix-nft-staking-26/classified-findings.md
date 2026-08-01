# Severity Classification — `phoenix-nft-staking` run-26

- **Target**: `lib/phoenix-nft-staking` @ `9611312`
- **Cross-repo sites verified at**: `lib/yield-claim-nft` @ `d4cc563` (top-level submodule HEAD, per the nested-pin-staleness rule)
- **Date**: 2026-07-30
- **Input**: `sanitized-findings.md` — 13 findings, 13 kept, 0 suppressed
- **Outcome**: **0 High · 0 Medium · 9 Low · 3 QA · 1 Informational**

## Headline

Both escalation questions resolve **against** escalation, on evidence rather than on
deference to the proposed labels.

- **Q1 (D-26-11)**: the step-5 → step-9 erosion path is **NOT reachable without a
  token-side property**. I proved the `available` cap is a dead branch arithmetically
  and closed the one gap the code's own comment left open (that the mint leg's outflow
  exactly equals the `budget` decrement) by reading `NFTMinterV2._executeMint`. KI #16
  carve-outs **(b)** and **(d)** do not fire. It stays a documentation finding.
- **Q2 (D-26-05)**: **Low upheld**, but the dissent's central premise is *refuted*, not
  merely outweighed — `NudgeRatchet`'s own NatSpec documents the failure mode, its
  trigger, its blast radius, the repoint-re-arms case, and a numbered required ops
  ordering. The Law-3 surprise test fails.
- **A material safety correction falls out of Q2**: the remediation dedup recommended
  (add `try/catch` around `collectNudge`) is **worse than the status quo** and must not
  be filed as the fix. Details in §2.4. This is the run's most valuable output.

No severity label moved up or down. Two findings had their **content and recommended
mitigation** changed, one of them reversing a cross-repo fix request. Both are recorded
in §4.

---

## 1. Final severity table

| ID | Subject | Proposed | **Final** | Plausibility | Faithfulness | Route |
|---|---|---|---|---|---|---|
| D-26-01 | Unisolated cross-contract flush loop can brick `batchMint` | Low | **Low** | n/a | — | QA `L-01` |
| D-26-02 | `nudgeSize == 0` disables payout but not inflow or flush | Low/QA | **Low** | n/a | — | QA `L-02` |
| D-26-03 | Falsely-exhaustive NatSpec on a pooled-custody invariant | QA | **QA** | n/a | — | QA `Q-01` |
| D-26-04 | Story-031 instructed the unconditional NatSpec wording | Low | **Low** | n/a | **yes** | spec-conf `F-01-031` |
| D-26-05 | Streamer revert bricks the *mint*, not just the flush | Low | **Low** | n/a | — | QA `L-03` |
| D-26-06 | Story-032 removed the config-completeness precondition | Low | **Low** | n/a | — | QA `L-04` |
| D-26-07 | Story-032 twice ships a false "`NudgeStreamer` is unaffected" claim | Low | **Low** | n/a | **yes** | spec-conf `F-02-032` |
| D-26-08 | `setNudgeStreamer` accepts any address, no structural probe | Low | **Low** | n/a | — | QA `L-05` |
| D-26-09 | `NudgeCollected.amount` repointed from request to receipt | QA | **QA** | n/a | — | QA `Q-02` |
| D-26-10 | Story-031's unamended declaration for the event repoint | Low/QA | **Low** | n/a | **yes** | spec-conf `F-03-031` |
| D-26-11 | Unenforced ordering guarantee, self-contradicted by its own new text | Low/QA | **Low** | n/a | **yes** | QA `L-06` **+** spec-conf `F-04-030` |
| D-26-12 | Story-032 landed at HEAD while its story sits in `review` | info | **Informational** | n/a | **yes** | spec-conf (info) |
| D-26-13 | Duck-typed structural guard with no compiler enforcement | QA | **QA** | n/a | — | QA `Q-03` |

**Regressions: 0.** No finding matched a `fixed` ledger entry going live. The one
apparent contradiction (`9135cf7947`) is an expired closure premise by intentional
revert — a ledger-hygiene item, not a regression, and correctly excluded from this table.

Counts: **Low 9** (D-26-01, -02, -04, -05, -06, -07, -08, -10, -11) · **QA 3**
(D-26-03, -09, -13) · **Informational 1** (D-26-12).

---

## 2. Question 1 — is a Medium hiding in D-26-11?

### 2.1 Answer: NO. The erosion path is not reachable without a token-side property.

Required token behaviour, stated specifically as instructed:

> A mechanism that **reduces this contract's `paymentToken` balance between the pull at
> `:581` and the balance read at `:708`, other than the minter's `transferFrom` of
> `price`.** The candidates are a **negative rebase**, an **admin clawback / burn on a
> third party's instruction**, or a **fee-on-transfer variant that debits the sender
> `price + fee`** rather than debiting `price` and short-crediting the recipient.

All three are C4-invalid standalone here (non-standard/weird ERC-20; fee-on-transfer not
in scope). The contract's own comment at `:700-701` already names the first — *"a
negative-rebase prime token suffices"* — which is a token-side property by definition, so
the code and this classification agree.

### 2.2 The proof that it is unreachable on a plain 18-decimal ERC20

Let `P` = standing pot, `credited` = measured receipt at `:582`, `C` = total charged by
the mint loop, `D` = this batch's own donations.

1. **`budget ≤ credited`.** `:604` takes `min(credited, paymentAmount)`.
2. **The loop's decrement equals the loop's outflow, exactly.** This is the one leg the
   in-source comment asserts but does not prove, so I verified it at the counterparty.
   `batchMint:646` reads `price` from `configs(_dispatcherIndex)` and `:649` decrements
   `budget` by exactly that. `NFTMinterV2._executeMint` (`lib/yield-claim-nft` @
   `d4cc563`, `:179-183`) reads `uint256 price = config.price` and executes
   `safeTransferFrom(msg.sender, config.dispatcher, price)` — the same storage slot, in
   the same transaction, with no interleaving write between the batchMinter's read at
   `:646` and the minter's read at `:179`. The price ramp at `:188` happens **after** the
   transfer. So outflow per iteration `== price ==` decrement per iteration, and
   `C == paymentAmount − budget_remaining` for the pulled portion.
3. **No other outflow exists.** The only `paymentToken`-moving statements reachable
   inside `batchMint` are the pull (`:581`, inbound), `forceApprove` (`:648`, `:655`, no
   balance effect), the minter's `transferFrom` of `price`, and the refund itself
   (`:711`). `rescueERC20` (`:386-388`) is `onlyOwner` and cannot interleave —
   `batchMint` is `nonReentrant` and `rescueERC20` is a separate transaction. The
   dispatcher's `_dispatch` sweeps **its own** balance, never the batchMinter's; the
   streamer hop moves funds *into* the batchMinter later, never out.
4. **Therefore** `available = P + (credited − C) + D` and `refund = budget ≤ credited − C
   ≤ available`. The `available` cap at `:709` **never binds**, `refund == budget`
   always, and no shortfall is charged to `D` or `P`.

### 2.3 Consequence for the KI #16 carve-outs

- **Carve-out (b), "any path where `refund > paymentAmount`": structurally impossible**,
  not merely unobserved. `refund ≤ budget ≤ paymentAmount` by construction at `:604`,
  and `budget` only ever decreases. `totalPaid = paymentAmount − refund` at `:712` cannot
  underflow. This is exactly the property the step-5 `min` exists to establish.
- **Carve-out (d), "ANY CLAIMANT TAKING OTHER USERS' MONEY": does not fire.** On a plain
  token no claimant absorbs `D` or `P` through this path. There is no value transfer to
  classify, so there is no Medium here.

Per the run's own constraint — a token-side requirement is C4-invalid standalone — **the
QA/documentation framing stands.** I am pinning it at **Low** rather than leaving the
proposed "Low (QA)" ambiguous, because the defect is a false *safety* guarantee on a
load-bearing property and it is dual-routed to spec-conformance; that belongs in the Low
band, not in the discretionary-drop band. The mitigation is documentation accuracy:
correct the block at `:659-665` to say independence comes from **sourcing** (`budget` vs
`snapshot`), not from sequence, and reconcile it with the Anchor E text at `:695-702`
that currently contradicts it.

**Recall note (Law 1) — the door stays open.** The proof above is a plain-token proof and
rests on leg 2, which is a cross-repo coupling. **If `NFTMinterV2` is ever changed so
that the amount charged is not the `config.price` the batchMinter read** — a
consumption-side fee, a two-pull mint, a price write before the transfer — then leg 2
fails, `budget` under-decrements, and the erosion becomes reachable on a plain token, at
which point carve-out (d) fires and this is a **Medium or High** value-transfer finding.
That coupling is undocumented on the `phoenix-nft-staking` side and should be recorded as
a watch-note against `NFTMinterV2._executeMint`.

---

## 3. Question 2 — arbitrating the D-26-05 dissent

### 3.1 Verdict: **Low upheld.** The Medium case's central premise is refuted by the code.

### 3.2 The Law-3 test, applied explicitly

*Would a competent, non-malicious owner be surprised by this consequence?* **No.**

`NudgeRatchet`'s contract NatSpec (`lib/yield-claim-nft` @ `d4cc563`, `:23-43`) discloses
the entire hazard, accurately and in advance:

```
///      ### The streamer is MANDATORY (story 046)
///        * If the streamer is set but ops forgot `registerStream(batchMinter, _token, duration)`
///          on it, every `dispatch` reverts `NudgeStreamer__NotRegistered()`. This is the
///          accepted consequence of the mandatory-streamer decision, NOT an audit finding.
///        * Repointing `batchMinter` to an address with no registered stream re-arms the same
///          failure mode; register the new pair first.
///
///      **Required ops ordering** ...
///        1. `batchMinter.setNudgeTokenWhitelist(_token, true)`
///        2. `nudgeStreamer.registerStream(batchMinter, _token, duration)`
///        3. `this.setNudgeStreamer(nudgeStreamer)`
```

This defeats the Medium case on its own terms. It names the exact revert, states the
blast radius (*"every `dispatch`"*), covers the `setBatchMinter` repoint case the dissent
did not account for, and prescribes the correct order with `setNudgeStreamer` explicitly
**last** — i.e. the mistake the dissent posits is the mistake this list exists to
prevent, at the very function that causes the harm. An owner performing this wiring is
following a runbook, not walking into a surprise. **No surprise ⇒ trusted ⇒ not a
footgun**, per Law 3's own boundary condition.

**I am not deferring to the "NOT an audit finding" clause.** Per standing policy,
in-source NatSpec carries no suppression authority, and that sentence carries none here.
What does the work is the *surrounding disclosure being accurate and complete* — which I
verified against the code rather than taking on trust. The MEMORY rule that raises
severity applies to **falsely**-exhaustive documentation; this documentation is true.

### 3.3 Why the availability limb does not reach Medium

C4 Medium's availability limb, applied to the facts:

| Discriminator | D-26-05 |
|---|---|
| Attacker-inducible / permissionless trigger? | **No** — requires a privileged config action |
| Arises in normal operation without operator error? | **No** — on a plain token, `NotRegistered` needs the unregistered state; `ZeroAmount` is defended by `NudgeRatchet`'s load-bearing `bal > 0` guard; `ZeroReceived` needs a 100%-tax/confiscatory token (not USDC); `_settle`'s transfer reverting needs an INV-1 violation, which needs a weird token |
| Silent or hard to diagnose? | **No** — reverts with the self-naming custom error `NudgeStreamer__NotRegistered()` on the very first mint attempt, atomically |
| Unrecoverable / value locked? | **No** — one owner `registerStream` transaction; donor funds keep accumulating safely in the streamer buffer and flush normally afterwards |
| Value lost? | **No** — nudge delivery is delayed, not destroyed; users lose reverted-transaction gas only |

An outage that cannot begin without a privileged action, cannot survive the operator's
first smoke-test, cannot outlive one transaction, and locks no value is Low. Medium
availability findings need the outage to be **attacker-inducible, or undetectable, or
unrecoverable**; this is none of the three.

### 3.4 Disposition of the three Medium arguments

- **"Story-031 added a revert (`ZeroReceived` at `:199`) to the un-isolated leg, so the
  surface grew."** *Partly upheld, and it is the one limb that survives.*
  `NudgeRatchet`'s enumeration lists `nudgeStreamer unset`, `NotRegistered`,
  `NotWhitelisted` and `ZeroAmount` — and **omits `ZeroReceived`**. So story-031 widened
  the revert surface of the un-isolated leg without updating the dispatcher's
  otherwise-complete failure-mode list. That is a real, narrow disclosure incompleteness
  introduced in this range. It does not move severity, because the new revert needs a
  confiscatory token on a USDC path, but it is the correct residual to report and the
  cheapest thing to fix.
- **"The asymmetry with `BalancerPoolerV2` shows the isolation was understood to be
  necessary."** *Weakened.* The asymmetry is real, but on the `NudgeRatchet` side it is a
  **documented deliberate divergence** (story 046 removed the direct-transfer fallback on
  purpose; there is no donation-disable switch). It is not an oversight. What survives is
  a **cross-contract inconsistency of failure semantics**: one streamer, two dispatchers,
  opposite outcomes for the identical condition — and `BalancerPoolerV2`'s own NatSpec
  trains the reader in the *other* direction (*"a streamer misconfiguration is
  quiet"*). An operator carrying that model to `NudgeRatchet` is wrong. Worth reporting;
  worth Low.
- **"`NudgeStreamer__NotRegistered` is plainly reachable with no weird token."**
  *Upheld as a fact, but it is not decisive.* Reachability establishes that the finding is
  real; severity turns on trigger, detectability and recoverability, and all three point
  Low.

### 3.5 Escalation triggers (recorded so the Low is revisable, per Law 1)

Re-classify to **Medium** if any of the following becomes true:

1. A path is found where `collectNudge` reverts **without** a privileged action — in
   particular a plain-ERC20 counterexample to INV-1 (`Σ buffer_i ≤ balanceOf(streamer)`)
   with **≥ 3 streams on one token**, which `tier3/symbolic.md` records as
   INCONCLUSIVE-timeout at wide bounds, resting on one hand-checked reduction step. That
   would make `_settle`'s transfer revert in normal operation, and the outage would
   arrive unannounced instead of at bring-up.
2. `NudgeStreamer` acquires a pause, deregistration, or `duration`-zeroing path, making
   the brick reachable from a routine live operation.
3. Any dispatcher acquires a `collectNudge` hop that is **not** covered by an accurate,
   ordering-prescribing disclosure of this failure mode — the disclosure is what holds
   this at Low, and it is not a property of the code.

### 3.6 A safety correction to the remediation — the run's most important output

**Do NOT file "wrap `collectNudge` in `try/catch`" as the mitigation, and strike the
cross-repo fix handoff to the `yield-claim-nft` ledger in that form.** The recommended fix
is worse than the defect, for two independent reasons:

1. **It converts a loud failure into a silent one.** `ATokenDispatcherV2.dispatch`
   (`:124-125`) executes `_dispatch(...)` **then** `hook.onDispatch(minter, amount,
   extraData)`. A swallowed `collectNudge` therefore lets `_dispatch` return successfully:
   the USDC stays on the dispatcher while the hook accrues mint-debt against `amount`, and
   nothing surfaces. This is a **transient backing/debt timing skew** — self-healing,
   because `_dispatch` sweeps the whole balance (`bal`) on the next dispatch, so no
   permanent over-accrual occurs and I am **not** filing an unbacked-phUSD claim. But it
   is precisely the direction `NudgeRatchet:148-149` guards against, and it sits adjacent
   to the tracked DEDUP-001 unbacked-phUSD class in `yield-claim-nft`.
2. **Silence is the aggravator this audit penalises elsewhere.** D-26-08 is filed
   specifically for a *silent* streamer misconfiguration, and `BalancerPoolerV2`'s NatSpec
   itself warns that its `try/catch` makes streamer misconfiguration *quiet*. Adding a
   catch here trades a self-diagnosing, one-transaction-recoverable revert for a quiet,
   indefinitely-accumulating misconfiguration — moving `NudgeRatchet` **into** the D-26-08
   failure class to escape a Low.

**Recommended mitigation instead** — documentation and consistency, matching the honest
severity:

- Add the missing **`NudgeStreamer__ZeroReceived`** row to `NudgeRatchet`'s failure-mode
  enumeration at `:29-38` (the one substantive gap, §3.4).
- Document the **deliberate divergence** from `BalancerPoolerV2`: state at both sites why
  one dispatcher fails closed on a streamer fault and the other fails open, so an
  operator cannot carry the wrong model between them.
- Keep the revert. It is the correct, deliberate, story-046 behaviour.

---

## 4. Changes from the proposed disposition

No severity label was moved up or down. Two findings changed materially in content:

### 4.1 D-26-05 — label unchanged (Low), **remediation reversed**

The proposed disposition carried a cross-repo obligation to *"cross-file the missing
`try/catch` to the `yield-claim-nft` ledger."* That instruction is **withdrawn** and
replaced per §3.6: the fix it requests would create a silent-misconfiguration and a
transient debt/backing skew, and would contradict a deliberate, documented design
decision (story 046). The cross-file to `yield-claim-nft` still happens, but as a
**documentation-consistency** item against `NudgeRatchet:29-38`, not as a missing-guard
item. The finding's basis also narrows: the surviving substantive residual is the
**`ZeroReceived` omission** plus the cross-contract failure-semantics inconsistency, not
"the hop is un-isolated" — the hop is un-isolated *on purpose*, and accurately disclosed.

### 4.2 D-26-11 — ambiguity resolved to **Low**, and the carve-out flag discharged

The sanitizer flagged this to me undecided between "Low" and "QA" pending the Q1
reachability check. Answered NO (§2), so no escalation. Pinned at **Low**, not QA,
because the false claim is a *safety* guarantee on a load-bearing property and the
finding is dual-routed to spec-conformance. The KI #16 carve-out flag is formally
**discharged**: (b) is structurally impossible and (d) does not fire on a plain token.
A new **watch-note** replaces it (§2.3, final paragraph): the plain-token proof depends
on `NFTMinterV2._executeMint` charging exactly the `config.price` the batchMinter read,
an undocumented cross-repo coupling whose breach would make this a real value-transfer
finding.

### 4.3 Faithfulness tagging (Law 2)

D-26-04, D-26-07, D-26-10, D-26-11 and D-26-12 are tagged `faithfulness: true` and routed
to `spec-conformance.md` with `F-` labels (§1). **None may be folded into the QA/gas
bundle.** D-26-11 is dual-routed (`L-06` **and** `F-04-030`) by design, not duplicated.

### 4.4 Explicitly not escalated, and why

For the audit trail, since the run instruction warns against padding as strongly as
against deflating:

- **D-26-08** (`setNudgeStreamer` silent brick) has genuine Medium-class cross-project
  precedent (`phStaging` run-21 M-02; `stable-yield-accumulator` `0xd62cbfe8`). Held at
  **Low** on a substantive distinction: there the brick sat on a value-bearing path,
  whereas here it degrades an **optional incentive** whose funds remain in protocol
  custody, keep accumulating on the correctly-pointed streamer, and flush normally once
  the pointer is fixed. Fully recoverable, no value lost. The likelihood limb is also
  weak — the EOA case is *defeated* (solc 0.8.20 retains `extcodesize` for
  void-returning external calls), leaving only a contract with a permissive fallback.
- **D-26-01** stays **Low**, and its plain-token reachability is in fact *nil*:
  `pullPendingStream` early-returns for unregistered streams (`NudgeStreamer.sol:222`), so
  `NotRegistered` cannot fire in the flush loop at all, and the only remaining revert
  path (`_settle`'s transfer) needs an INV-1 violation, i.e. a weird token. Leg B was
  killed by 452k fuzzed calls plus the Halmos proof. The written reopen trigger and the
  ≥3-stream symbolic gap (§3.5 item 1) are preserved verbatim, not closed.
- **D-26-02** carries no value-leak limb. Nudge pots are funded by externally-derived
  yield on protocol-owned capital, so mis-sizing is misallocation/opportunity cost, never
  economic loss. Classified on the **custody-location and operator-expectation** footgun
  alone, with the KI #16 pot-size limb struck per the sanitizer's narrowing.
- **No severity anywhere rests on "an attacker acquires NFTs."** The minted NFT has no
  redemption value.

---

## 5. Structured output

```json
{
  "classification": {
    "project": "phoenix-nft-staking",
    "run": "phoenix-nft-staking-26",
    "commit": "9611312",
    "crossRepoVerifiedAt": { "yield-claim-nft": "d4cc563" },
    "totals": { "high": 0, "medium": 0, "low": 9, "qa": 3, "informational": 1 },
    "regressions": 0,
    "severityChanges": [],
    "contentChanges": [
      {
        "id": "D-26-05",
        "change": "remediation_reversed",
        "detail": "Withdraw the 'add try/catch around collectNudge' fix request. ATokenDispatcherV2.dispatch runs _dispatch then hook.onDispatch(amount), so a swallowed collectNudge leaves USDC on the dispatcher while mint-debt accrues against amount (transient, self-healing) AND makes streamer misconfiguration silent — the D-26-08 failure class. Replace with: add the missing ZeroReceived row to NudgeRatchet:29-38, and document the deliberate divergence from BalancerPoolerV2. Keep the revert."
      },
      {
        "id": "D-26-11",
        "change": "carve_out_flag_discharged",
        "detail": "Q1 answered NO. KI #16 carve-out (b) is structurally impossible (refund <= budget <= paymentAmount at :604); (d) does not fire on a plain token. Pinned Low. New watch-note: the proof depends on NFTMinterV2._executeMint charging exactly the config.price the batchMinter read at :646 — an undocumented cross-repo coupling."
      }
    ],
    "findings": [
      { "id": "D-26-01", "severity": "low",  "faithfulness": false, "route": "qa",   "label": "L-01" },
      { "id": "D-26-02", "severity": "low",  "faithfulness": false, "route": "qa",   "label": "L-02" },
      { "id": "D-26-03", "severity": "qa",   "faithfulness": false, "route": "qa",   "label": "Q-01" },
      { "id": "D-26-04", "severity": "low",  "faithfulness": true,  "route": "spec", "label": "F-01-031" },
      { "id": "D-26-05", "severity": "low",  "faithfulness": false, "route": "qa",   "label": "L-03" },
      { "id": "D-26-06", "severity": "low",  "faithfulness": false, "route": "qa",   "label": "L-04" },
      { "id": "D-26-07", "severity": "low",  "faithfulness": true,  "route": "spec", "label": "F-02-032" },
      { "id": "D-26-08", "severity": "low",  "faithfulness": false, "route": "qa",   "label": "L-05" },
      { "id": "D-26-09", "severity": "qa",   "faithfulness": false, "route": "qa",   "label": "Q-02" },
      { "id": "D-26-10", "severity": "low",  "faithfulness": true,  "route": "spec", "label": "F-03-031" },
      { "id": "D-26-11", "severity": "low",  "faithfulness": true,  "route": "qa+spec", "label": "L-06 / F-04-030" },
      { "id": "D-26-12", "severity": "informational", "faithfulness": true, "route": "spec", "label": "F-05-032" },
      { "id": "D-26-13", "severity": "qa",   "faithfulness": false, "route": "qa",   "label": "Q-03" }
    ],
    "watchNotes": [
      "NFTMinterV2._executeMint must keep charging exactly the config.price the batchMinter read at BatchNFTMinterMultiToken.sol:646. A consumption-side fee, a two-pull mint, or a price write before the transfer breaks the no-erosion proof and makes D-26-11 a real value-transfer finding under KI #16 carve-out (d).",
      "INV-1 (Sigma buffer_i <= balanceOf(streamer)) is Halmos-proved for 2 streams at wide bounds but INCONCLUSIVE-timeout for >=3 streams; the reduction step is hand-checked. A plain-ERC20 counterexample escalates D-26-01 AND D-26-05 to Medium.",
      "D-26-05 is held at Low BY THE ACCURACY OF NudgeRatchet's disclosure, not by a code property. Any new collectNudge hop lacking an equivalent ordering-prescribing disclosure is Medium."
    ],
    "noSubmissions": "0 High, 0 Medium => no individual submissions/ artifacts. qa-report.md + spec-conformance.md only."
  }
}
```

**13 in → 13 classified. 0 High, 0 Medium. No finding dropped, no severity inflated, no
severity deflated.**
