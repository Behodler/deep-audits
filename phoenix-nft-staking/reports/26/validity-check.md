# Validity Check — `phoenix-nft-staking` run-26

- **Target**: `lib/phoenix-nft-staking` @ `9611312` (`96113129b57ebf7a7c45c65996f792a92c71cdce`)
- **Cross-repo sites re-verified at**: `lib/yield-claim-nft` @ `d4cc563` (top-level submodule HEAD, per the nested-pin-staleness rule)
- **Date**: 2026-07-30
- **Input tally**: 0 High · 0 Medium · 9 Low · 3 QA · 1 Informational (13 findings, 14 records — `D-26-11` is dual-routed)

## Verdict summary

**13 findings checked. 0 INVALID. 2 RESCOPE-REQUIRED. 2 strengthenings recommended.**

| Label | Verdict | Rule applied |
|---|---|---|
| L-01 | **VALID** (Low) | Not weird-token-dependent once the correct trigger is named — RESCOPE-RECOMMENDED |
| L-02 | **VALID** (Low) | Law 3 non-obvious footgun — surprise test PASSES |
| L-03 | **VALID-IF-RESCOPED** (Low/QA) | Reckless-admin rule bites the *title*, not the residual |
| L-04 | **VALID** (Low) | Law 3 non-obvious footgun — surprise test PASSES, decisively |
| L-05 | **VALID** (Low) | Law 3 non-obvious footgun — silence carries it |
| L-06 | **VALID** (Low) | Not speculation; no smuggled weird-token dependency |
| Q-01 | **VALID** (QA) | Present-tense demonstrated documentation defect |
| Q-02 | **VALID** (QA) | Present-tense demonstrated; contingency correctly priced into QA |
| Q-03 | **VALID** (QA), marginal | Clears the automated-tool rule *only* as QA |
| F-01-031 | **VALID-IF-RESCOPED** (Low) | Must not import review-Issue-1's rebase limb (weird-token) |
| F-02-032 | **VALID** (Low) | Law 2; story text verified verbatim |
| F-03-031 | **VALID** (Low) | Law 2; residual correctly narrowed |
| F-04-030 | **VALID** (Low) | Law 2; story-030's own purpose is the defect |
| F-05-032 | **VALID** (Informational) | Explicitly sanctioned by CLAUDE.md stories policy |

Nothing in this run touches the CryptoPunks, approve-race/`safeApprove`-front-running, phishing, or user-input-mistake categories. No finding is anchored in a forked or third-party contract.

---

## 1. Scope clearance

**Every finding is anchored in a first-party in-scope contract.** All 14 records name `src/BatchNFTMinterMultiToken.sol` or `src/NudgeStreamer.sol` in `lib/phoenix-nft-staking` — no record is anchored in the project's own nested `lib/**`.

**Cross-repo scope (pressure point 6) — CONFIRMED, the OOS-root-cause rule does not apply.** L-03's documentation fix site is `NudgeRatchet.sol` in `lib/yield-claim-nft`, which is a **top-level submodule in this audit repo** (`.gitmodules` line 21) and a **registered first-party audited project** in `registered-projects.json`. It is a sibling under review in its own right, not a fork and not a third-party dependency. The known-invalid rule covers "issues in parent/forked contracts where the root cause is OOS"; neither limb fires. Additionally L-03's own anchor (`contract: src/NudgeStreamer.sol:158/199/243`) is *in* `phoenix-nft-staking`, so even the fix-site question is secondary — the defect is anchored in scope and the remediation crosses into another in-scope repo.

I independently re-read `NudgeRatchet.sol` from the **top-level** `lib/yield-claim-nft` @ `d4cc563`, not from the nested pin. The report's `crossRepoVerifiedAt` is correct.

---

## 2. The Law-3 footgun findings (pressure point 1)

I applied the surprise test to each independently against the shipped source, not against the finding's own assertion.

### L-02 (`nudgeSize == 0`) — **VALID footgun**

Verified both halves:

- The disable claim is real and appears twice, unqualified. `src/BatchNFTMinterMultiToken.sol:40` — *"`nudgeSize` gates who qualifies (batch size >= threshold; `0` **disables the feature outright**)"*; and `:270` — *"Setting `0` disables the feature."*
- The flush loop genuinely does not read `qualifies`. `qualifies` is computed at `:510-514`; the flush block at `:517-536` calls `pullPendingStream` for every whitelisted token unconditionally on `nudgeStreamer != address(0)`; and `_snapshotRewards(minRewards, qualifies)` on the very next line *does* take the gate. So two adjacent blocks treat the same switch in opposite ways.

*Would a competent, non-malicious owner be surprised?* **Yes.** An owner who reads "disables the feature outright" and sets `0` has no way to infer from that text that the contract keeps pulling donor value out of the streamer and into the batchMinter for the duration of the disable, to be delivered as one un-metered lump to whoever wins the first re-enabled qualifying batch. The surprise is created by the contract's own documentation. **Not a reckless-admin item — an in-scope operational hazard.**

Two hygiene points the finding already gets right and must keep: the value-leak limb is correctly **struck** (nudge pots are externally-derived yield on protocol-owned capital, so mis-sizing is misallocation, never economic loss), and the `honestLimit` correctly concedes that a quiet period longer than `duration` makes `_accrued` hit its `buffer` cap anyway — the flush's distinct contribution is *custody location and invisibility during the disabled window*, not the existence of a lump. Filed on that basis, Low is right.

### L-04 (story-032 removed the config-completeness precondition) — **VALID footgun, and stronger than filed**

The mechanism is confirmed at the commit itself. `9611312`'s own message: *"delete the gate AND the `_resolvePaymentPath()` call that fed it, so the add branch derives nothing. Side effect… a token can now be whitelisted BEFORE `setTokenMinter` / `setDispatcherIndex`."* The diff removes `(,, IERC20 paymentToken) = _resolvePaymentPath();`. `NudgeStreamer.registerStream` gates on `isNudgeToken` and nothing else, so the transitive witness that L-04 describes is genuinely gone.

**The surprise test does not merely pass — the shipped NatSpec asserts the opposite of the hazard.** `src/BatchNFTMinterMultiToken.sol:318-320`:

> `///         Because nothing here reads the payment path, adding works while`
> `///         `tokenMinter`/`dispatcherIndex` are unset — symmetric with`
> `///         removal, and **no longer an ordering constraint on deployment scripts**.`

L-04's entire substance is that an ordering constraint *does* remain — whitelist → `registerStream` → permissionless `collectNudge` from a stateless sweeping donor → `batchMint` reverts `BatchMint__MinterNotConfigured` at `:479` *before* the flush loop → nothing drains the buffer and the streamer has no rescue. An operator who strands donor throughput here is not being reckless; they are following a line of shipped documentation that tells them the constraint was lifted. This is the strongest footgun in the run and it is **unambiguously in scope**.

> **STRENGTHENING (recommended, not required):** L-04 does not currently cite `:318-320`. Quote it. It converts the finding from "the hazard is undisclosed" to "the hazard is affirmatively contradicted by shipped documentation", which is the class the standing rule says *raises* rather than lowers severity, and it forecloses any later attempt to re-triage L-04 as an admin mistake. It also makes L-04 and F-02-032 a matched pair: the same false conclusion in the story (*"NudgeStreamer … is unaffected"*) and in the source.

### L-05 (`setNudgeStreamer` silent mis-point) — **VALID footgun, borderline; silence carries it**

Verified at `:293-300`. The setter takes any address with no probe; the NatSpec documents only the `address(0)` disable path and says the change leaves "all other behaviour unchanged"; and the event is emitted **before** assignment (`emit NudgeStreamerChanged(nudgeStreamer, newStreamer); nudgeStreamer = newStreamer;`).

This is the closest of the three to a plain admin input mistake, and I weighed invalidating it. Three facts hold it in scope:

1. **The failure is silent and permanent.** The flush loop succeeds and does nothing, forever. There is no revert, no diagnostic, and the emitted event reads as a clean success. An owner cannot detect the error from the transaction, the logs, or any subsequent `batchMint`.
2. **The counterparty probes and this direction does not.** `NudgeStreamer.registerStream:127` deliberately calls `isNudgeToken` on the batchMinter to confirm the target's type, documented at `:10-17`. A competent owner who has read that design would reasonably expect the symmetric check, and would be surprised to find one direction guarded and the other not.
3. **Nothing on the batchMinter side warns.** `NudgeRatchet`'s ops-ordering NatSpec — the document that defeated L-03's footgun claim — governs *`NudgeRatchet`'s own* `setNudgeStreamer`, not the batchMinter's. It provides no cover here.

Silence plus a documented asymmetry plus a misleading event order = non-obvious. **VALID.** The finding's honesty is also load-bearing and must be preserved verbatim: the EOA case is **defeated** (solc 0.8.20 retains `extcodesize` for void-returning external calls, so the flush reverts loudly), leaving only a contract with a permissive fallback. That weak likelihood limb is precisely why Low, not Medium, is the honest label, and the note that a bare zero-address check would be *actively wrong* is correct — `address(0)` is a deliberate disable path.

---

## 3. L-03 — the sharpest test (pressure point 2)

**Verdict: VALID-IF-RESCOPED. The reckless-admin rule bites the finding's framing, not its residual.**

I re-read `NudgeRatchet.sol:23-46` at `d4cc563` and confirm every element the severity-classifier relied on. The NatSpec names the exact revert (`NudgeStreamer__NotRegistered()`), states the blast radius (*"every `dispatch`"*), covers the `setBatchMinter` repoint case (*"Repointing `batchMinter` … re-arms the same failure mode; register the new pair first"*), and prescribes a numbered **Required ops ordering** with `setNudgeStreamer` explicitly step 3 of 3. The surrounding disclosure is accurate against the code. **The Law-3 surprise test therefore FAILS for the primary limb**, exactly as the classifier found, and I agree with the classifier's refusal to defer to the in-source *"NOT an audit finding"* clause — that sentence carries no suppression authority; what does the work is the disclosure being *true*, which I verified rather than accepted.

So: **as titled**, this finding — *"a streamer revert bricks the mint, not just the flush"* — is a documented, deliberate, accepted consequence of story-046 triggered by an owner wiring step the counterparty contract supplies a runbook for. Standing alone, that is a reckless-admin INVALID.

**It does not stand alone.** I verified the residual and it is real:

- **The `ZeroReceived` omission is confirmed.** `NudgeStreamer.sol` declares `NudgeStreamer__ZeroReceived()` at `:93` and reverts it at `:199`. `grep` over `NudgeRatchet.sol` returns `NotRegistered` (`:34`), `NotWhitelisted` (`:40`), `ZeroAmount` (`:49`, `:152`) and the `nudgeStreamer unset` string — and **no occurrence of `ZeroReceived`**. Story-031 widened the un-isolated leg's revert surface without updating an otherwise-complete enumeration. This is a present-tense, demonstrated documentation-completeness defect, and it is not an owner action at all.
- **The cross-contract failure-semantics inconsistency is real but weaker.** One streamer, two dispatchers, opposite outcomes for the identical condition, with `BalancerPoolerV2`'s NatSpec training the reader that *"a streamer misconfiguration is quiet"*. An operator carrying that model to `NudgeRatchet` is wrong. This is a genuine documentation-consistency hazard, but note it is partially self-defeating: the operator wiring `NudgeRatchet` reads `NudgeRatchet`'s NatSpec, which is accurate and ordering-prescriptive. Treat it as supporting, not as the basis.

### RESCOPE REQUIRED

1. **Retitle and re-lead on the residual.** The current title asserts the availability limb the run itself concluded is not the residual, and the `description` leads with *"A revert there bricks the MINT itself … for every minter on that dispatcher."* A reader will score this as an availability finding, which contradicts the finding's own `law3Verdict` field. Retitle to something like *"`NudgeRatchet`'s failure-mode enumeration omits `NudgeStreamer__ZeroReceived`, and diverges silently from `BalancerPoolerV2`'s failure semantics."* Keep the mint-blast-radius description as **context** for why the enumeration matters, explicitly flagged as documented and deliberate.
2. **Severity band.** Once rescoped to two documentation items, Low is arguable but **QA is the more defensible band** — Q-01 and Q-02 carry substantively identical material (documentation accuracy, no reachable impact) at QA. I am not overriding the severity-classifier's arbitration; I am recording that the rescope removes the distinguishing feature that justified Low over QA, and that a reviewer moving L-03 to QA would be applying the report's own standard consistently.
3. **Preserve, unchanged:** the withdrawn `try/catch` remediation and its two reasons (§3.6 of `classified-findings.md`). That reversal is correct and is the most valuable output in the run — the proposed fix would convert a loud, one-transaction-recoverable failure into precisely the silent-misconfiguration class L-05 is filed for, and would let `_dispatch` return successfully while `hook.onDispatch` accrues mint-debt against `amount`. It must survive the rescope intact.
4. **Preserve, verbatim:** all three escalation triggers, especially trigger 3 (*"the disclosure is what holds this at Low, and IT IS NOT A PROPERTY OF THE CODE"*). A Low held up by documentation is revisable by construction, and Law 1 requires the door stay open.

---

## 4. The documentation findings (pressure points 3 and 4)

### Are they "speculation on future code without a demonstrated root cause"? — **No, for all of them.**

The test is whether the asserted defect exists *now* at named lines. In every case it does; the "a future editor could…" language is impact narration, not the root cause.

### L-06 / F-04-030 — **VALID, and no weird-token dependency is smuggled in**

I read the full comment block. The contradiction is present and internal to a single block:

- `:661-664` (claim 2): *"The refund (here) must stay BEFORE the payout (step 10), so a payout can never be funded out of a refund that is owed, **and vice versa**."* — a symmetric guarantee, attributed to **ordering**.
- `~40 lines below`, story-030's own Anchor E addition: *"**DURABLE RESIDUAL** — `budget` is a ONE-SHOT MEASUREMENT… Any erosion of this contract's payment-token holdings AFTER that point is therefore **charged to the pot, silently**: `budget` still reflects the pre-erosion credit, the refund pays out at that figure, and `P` covers the difference."*

That is X and ¬X in the same block. Both texts exist unconditionally — **no token property is required for the contradiction to be present**, which is the whole point of filing this as a documentation finding. Pressure point 4 is satisfied: the weird-token requirement (negative rebase / clawback / FoT-debits-sender) appears **only** in `reachabilityProof`, where it serves to *refuse* escalation and to discharge KI #16 carve-outs (b) and (d). It is not the substance. I re-verified the load-bearing arithmetic leg independently: `:604` takes the `min`, so `refund <= budget <= paymentAmount` and carve-out (b) is structurally impossible, not merely unobserved.

Is it a stylistic quibble? **No.** Two things settle it: the first falsity — that independence comes from **sourcing** (`budget` vs `snapshot`), not from sequence — is entirely token-independent; and story-030's title is literally `030-documentation-accuracy-stop-asserting-unenforced-guarantees.md`. A story whose stated purpose is to stop asserting unenforced guarantees left one standing inside the very block it rewrote, and authored the contradicting text in the same pass. That is a real Law-2 defect, not a wording preference.

I also confirm the in-scope justification: story-030 `:375-378` explicitly disowns the anchor-list defence (*"Directed the purpose-alignment stage to sweep… beyond the named anchors"*), so the finding sitting outside the enumerated anchor range is not a scope objection.

The **WATCH-26-02** note is correct and must survive: the plain-token proof rests on `NFTMinterV2._executeMint` charging exactly the `config.price` the batchMinter read at `:646` — an undocumented cross-repo coupling whose breach makes this a real value-transfer finding.

### Q-01 — **VALID (QA)**

The false claim is present and specific. `_accrued`'s NatSpec at `:259-262`: *"That invariant is established at **ONE site** — the balance-delta credit in `collectNudge`, which credits `min(received, amount)` measured across the pull."* The aggregate `Σ buffer_i <= balanceOf(this)` is in fact a **conjunction across two sites** — the measured-receipt credit *and* the per-stream cap in `_accrued` that bounds each `_settle` debit (`_settle` decrements `s.buffer` by `settled`, where `_accrued` caps `settled` at `buffer`). Naming one site as sufficient is substantively incomplete, on a property the contract's own text calls load-bearing.

The finding's own concession — that the invariant currently **holds** for plain ERC20s (Halmos-proved for 2 streams, 452k+ fuzzed calls, no counterexample) — is exactly why QA and not higher. Judged honestly per pressure point 3: this is *not* "the docs give the wrong reason for something nonetheless true" in the stylistic sense. The stated reason is offered as *the* structural guarantee that makes the per-stream cap affordable out of pooled custody, and the recommendation the finding gives (state the credit **plus** the `_accrued` cap, or add the clamp the text implies) is the correct repair. Real defect, correctly priced at QA.

### Q-02 / F-03-031 — **VALID (QA / Low)**

Verified at `:211`: the emit passes `received`, not `amount`, under a byte-identical ABI, with the in-source comment conceding *"`amount` carries the CREDITED receipt"*. The `noOnChainDesync` clearance is verified-not-assumed and I accept it. `GAP-26-05` (whether any off-chain indexer sums the field) is genuinely unverifiable from the repo, and the finding correctly prices that contingency by sitting at QA rather than asserting an impact it cannot demonstrate. That is the right handling of an unverifiable limb — not speculation, because the *semantic change* is demonstrated and only the *consumer* is unknown.

### F-01-031 — **VALID-IF-RESCOPED**

The story evidence checks out exactly. Story-031 `:168` instructed the wording: *"State the real invariant that now holds (`Σ buffer_i <= balanceOf(this)`, **established at the credit site**)"* — unconditional, and the source of the defect. And the story's own review pass, Issue 1 at `:421-427`, caught it: *"**Invariant statement has no rebase carve-out.** `src/NudgeStreamer.sol:55-62`, the `_accrued` NatSpec at `:248-265`… all state `Σ buffer_i <= balanceOf(this)` unconditionally."* Recorded non-blocking; shipped unamended. The Law-2 substance — that this was **instructed, then caught, then shipped** — is real and is a process defect, not an implementer slip.

**RESCOPE REQUIRED (pressure point 4, applied here rather than to L-06).** Review Issue 1 frames the gap as a **rebase carve-out** — post-credit balance shrinkage, i.e. a token-side property. If F-01-031 imports that framing as its substance, the finding becomes a weird-token finding and is **INVALID standalone** under the non-standard-ERC20 rule. It must be pinned to the token-independent limbs:

- the acceptance criterion at `:168` instructed an unconditional claim about a property that is a two-site conjunction (Q-01's framing), and
- the story's own review caught the defect and shipped without amending the text or the criterion.

State explicitly that the rebase mechanism named in review Issue 1 is **C4-invalid standalone and is not the basis of this finding**. Without that sentence, F-01-031 is one careless read away from being dismissed under the very rule this check exists to enforce. The `law1Override` clearance (story-031's intended mechanism is strictly safety-improving; no `story-unsafe` flag) is correct and I concur. The walk-back from `potential-medium` to Low is also correct — the DoS premise it rested on is killed and separately carried at Low by L-01.

### F-02-032 — **VALID (Low)**

Both story sites verified verbatim. `:126-128`: *"Also not touched: `src/NudgeStreamer.sol`. `NudgeStreamer.registerStream` calls `isNudgeToken(token)`, which is **unaffected** — it reads `_nudgeTokenIndex`, and this story does not change how entries are added to it, **only what is refused**."* And `:383-385` under "Not a dependency", the same conclusion. The finding's rebuttal is precise and correct: the *mechanism* claim is true, the *conclusion* is false, because `"only what is refused"` **is** the change to the reachable state set — and since `registerStream` gates on `isNudgeToken` and nothing else, relaxing what the whitelist refuses directly widens what `registerStream` will admit. Clean Law-2 finding.

---

## 5. Q-03 — the marginal entry (pressure point 5)

**Verdict: VALID (QA), marginal. It clears the automated-tool rule, but only as QA and only on a non-generic justification.**

The rule invalidates *"common findings from automated tools without demonstrated H/M exploit path"* — it invalidates them **as H/M submissions**. Q-03 makes no H/M claim; it states plainly *"None at this commit. NOT A SECURITY FINDING"*. C4 convention puts `missing-inheritance` / missing-interface-declaration items at QA at best, which is exactly where this sits.

What lifts it above raw tool output is a specific, non-generic fact a tool did not produce: the duck-typed `isNudgeToken` call is `registerStream`'s **sole admission check** (`NudgeStreamer.sol:127`), carrying two distinct assertions at once — whitelist membership *and* MultiToken-batchMinter identity — while being coupled by convention, so a signature change on either side compiles clean. That is a genuine maintainability argument about a load-bearing coupling.

Its own honesty is what keeps it valid rather than inflated: drift **fails closed** (`registerStream` reverts on empty returndata, `onlyOwner`, no funds in motion), `external view` ⇒ `STATICCALL` ⇒ cannot reenter or mutate, and the only false-accept path needs an owner-supplied address with a permissive fallback — which Q-03 **correctly suppresses itself** as obvious owner error under Law 3. That self-suppression is the discipline the rule wants.

Conditions on keeping it:

- It must **never** be presented as a security item. The QA report must carry the "None at this commit / not a security finding" qualifier.
- Keep the `L-05` cross-reference note (*"Adjacent, distinct root cause… Fix together, keep separate"*). Q-03 and L-05 target the same coupling from opposite sides; without the note the QA bundle reads as padding.
- Keep the `cf332bf46c` note — that ledger entry is the interface *documentation* gap and stays **open**, partially addressed. Do not close it against Q-03.
- **If the QA report needs trimming, Q-03 is the first entry to drop.** It is the only finding in the run whose removal would cost the report nothing in security terms.

---

## 6. F-05-032 — informational process observation (pressure point 7)

**Verdict: VALID as an informational spec-conformance entry. Keep it.**

I resolved the story tag by globbing the whole `nft-staking` project tree per the Law-2 procedure. Exactly one hit, and it confirms the finding: `review/whitelist-liberation/032-remove-payment-token-whitelist-gate.md`. Meanwhile `9611312` is HEAD and the deliverable is wired. (Control: stories 030 and 031 resolve to `complete/documentation/` and `complete/audit-21/` respectively — one hit each, no ambiguity.)

This is not merely acceptable, it is **directly sanctioned by project policy**. CLAUDE.md's stories rule: *"The state folder is metadata, not a filter… a landed feature whose story sits in `incomplete` is itself worth flagging."* No known-invalid category reaches it — it is not an unused view function, not speculation on future code, not an admin behaviour claim, and it asserts no security impact. It is labelled Informational, which is the honest band.

It also earns its place operationally: an open story is a **remediation channel**. L-04's and F-02-032's fixes can be folded into story-032 before it closes rather than filed as follow-ups, and the recorded `phStaging2:072` phase-0 assertion hazard (the six-row reconciliation asserting the now-deleted `BatchMint__RewardTokenIsPaymentToken` tripwire, which would fail if 072 were run as written — 072 on ice and unbroadcast, owner-confirmed 2026-07-30) is exactly the kind of cross-project trap that would be lost if the entry were dropped as "process noise". Under Law 1, park-in-a-visible-channel beats drop.

---

## 7. One strengthening outside the pressure points — L-01

**Verdict: VALID (Low), but the finding currently undersells its own reachability in a way that invites an incorrect weird-token dismissal.**

L-01's `plainTokenReachability` field reads **"NIL at this commit"**, on the basis that `pullPendingStream` early-returns for unregistered streams (verified: `NudgeStreamer.sol:222`, `if (s.duration == 0) return;`) so `NotRegistered` cannot fire in the flush loop, leaving only `_settle`'s transfer at `:243`, which needs an INV-1 violation, i.e. a weird token. Read literally, that field says *the only trigger is a weird-token property* — which under the non-standard-ERC20 rule would make L-01 **INVALID standalone**.

It is not invalid, because the finding's own `severityNote` names a trigger that is **not** a weird-token property: *"third-party-extraordinary (Circle/Tether pause or blocklist)"*. Working it through against the code — `_settle` transfers to `recipient == msg.sender == the batchMinter` — a USDC global pause, or a USDC/USDT blocklisting of the batchMinter, makes `safeTransfer` at `:243` revert, which reverts the un-isolated, un-gated flush loop, which reverts `batchMint` for **every** caller, including a `count < nudgeSize` caller who takes no payout and gains nothing from the loop. Two rules make that trigger admissible: **USDT is the named exception** to the non-standard-token rule, and a USDC administrative pause is documented canonical behaviour of the protocol's actual settlement asset (the production donors forward USDC), not an exotic token variant. Loss of a structural immunity that non-qualifying callers previously held is a real, if low-severity, isolation regression.

> **STRENGTHENING (recommended):** lead L-01's reachability with the blocklist/pause path and cite the USDT carve-out, demoting the INV-1 path to the secondary/escalation limb where it already correctly lives. As written, a reviewer who reads `plainTokenReachability: NIL` and stops will invalidate a valid finding under the weird-token rule. Also keep `legBKilled` exactly as written — the aggregate-buffer mechanism is dead and must not be restated, and the note that *"a blacklisted streamer cannot transfer at all, so the blacklist is the brick, not the buffer sum"* is right: that argument kills Leg B while **confirming** the isolation limb.

Everything else in L-01 is sound: the `reopenTrigger` is preserved verbatim as required, the escalation contingency correctly records that a Halmos TIMEOUT is not a proof either way (`>=3` streams INCONCLUSIVE above `2^32`, `N>2` generalisation hand-checked), and the shared-escalation link to L-03 is correct — one counterexample escalates both.

---

## 8. Overall assessment

**This report meets the professional-quality bar, with the two rescopes in §3 and §4 applied.**

What supports that:

- **No inflation anywhere.** 0 High, 0 Medium from 13 findings, reached by refuting the run's own lead candidate rather than by deference. Every Low and QA label is argued against the C4 discriminators, and the two escalation questions were both answered *against* escalation on evidence.
- **Every load-bearing claim I spot-checked was true.** I independently verified: the two `nudgeSize == 0` NatSpec sites; the flush loop's failure to read `qualifies`; the `_resolvePaymentPath` deletion in `9611312`; `setNudgeStreamer`'s missing probe and pre-assignment event; `pullPendingStream`'s early return; the `ZeroReceived` declaration at `:93`/revert at `:199` and its absence from `NudgeRatchet`; the self-contradicting ordering block; the `_accrued` "ONE site" claim; the `NudgeCollected` receipt repoint; `NudgeRatchet`'s full ops-ordering NatSpec at `d4cc563`; and four separate story line-references across stories 030, 031 and 032. **Nothing was overstated.** That is unusual and it is the report's main credibility asset.
- **The honest-limit discipline is consistent.** L-01's killed Leg B, L-05's defeated EOA case, L-02's struck value-leak limb, Q-02's unverifiable `GAP-26-05`, F-01-031's applied walk-back, Q-03's self-suppression of its own only false-accept path, and the `NFTMinterV2` watch-note that keeps L-06 revisable — each records what the finding *cannot* claim, in the finding itself.
- **The §3.6 remediation reversal is the run's highest-value output** and I endorse it. Refusing a fix that would move `NudgeRatchet` into the L-05 silent-misconfiguration class in order to escape a Low is exactly the right call, and it is well argued from `ATokenDispatcherV2.dispatch`'s ordering.

Why **nothing** came back INVALID, stated plainly rather than as a clean bill of health: the known-invalid list was already applied hard **upstream** of me. The sanitizer and severity-classifier had already killed the weird-token mechanisms (Leg B), struck the fee-on-transfer erosion limb from L-06, and discharged the KI #16 carve-outs — so the material that this check normally removes had already been removed before it reached me. My contribution is therefore two rescopes and two strengthenings, not a cull. The two entries closest to the line are named explicitly: **L-03**, whose *title* is a reckless-admin item even though its residual is not (rescope mandatory, QA band arguable), and **Q-03**, which passes only as QA and is the first thing to drop if the bundle needs trimming.

### Required before publication

1. **L-03** — retitle and re-lead on the `ZeroReceived` omission plus the failure-semantics divergence; keep the mint blast radius as flagged context only; preserve the remediation reversal and all three escalation triggers.
2. **F-01-031** — add an explicit sentence disclaiming review-Issue-1's rebase mechanism as C4-invalid standalone and not the basis of the finding.

### Recommended

3. **L-04** — quote `BatchNFTMinterMultiToken.sol:318-320` (*"no longer an ordering constraint on deployment scripts"*).
4. **L-01** — lead reachability with the USDC-pause / USDT-blocklist trigger, not `NIL`.
5. **Q-03** — retain the "not a security finding" qualifier and both cross-reference notes; drop first if trimming.
