# Independent Severity Audit — `phoenix-nft-staking` run-26

- **Target**: `lib/phoenix-nft-staking` @ `9611312`; cross-repo sites at `lib/yield-claim-nft` @ `d4cc563`
- **Tally under audit**: 0 High · 0 Medium · 9 Low · 3 QA · 1 Informational
- **Date**: 2026-07-30
- **Method**: fresh read of the code at both repos for every load-bearing claim, then the C4 criteria
  applied without deference to the proposed labels. Code facts cited below were re-derived, not
  taken from the run's text.

## Bottom line

**0 High / 0 Medium is the honest result for this range.** I looked for a buried Medium in all four
places the run was asked about and did not find one. No finding is raised to Medium, none is raised
to High, and none of the four downgrades/kills is unjustified.

The run is **not** wrong on severity. It has three defects that are not severity errors:

1. **A Law-1 visibility hole (the most serious item in this audit).** `qa-report.md:46` tells the
   reader that carryover QA lives under `submissions/carryover/`. **That directory does not exist.**
   Consequently ledger entry `aaebb4b9b0` — open, Low, re-confirmed *this run* with a **mandatory
   re-frame and a reversed remediation** ("`duration` is a time constant, not a drain time"; ~63%
   of a burst still retained at the nominal window end; 4.6× stretch to 99% delivery; **never**
   permission `collectNudge`, it breaks both production donors) — appears **nowhere in any
   deliverable**. It lives only in the ledger and `dedup-report.md`. That is a substantive,
   reader-facing conclusion parked in a channel nobody reading the report will open. Fix by
   creating `submissions/carryover/` or by folding the re-frame into `qa-report.md` as a carryover
   section. This is precisely the failure mode Law 1's "visible channel" clause exists to prevent.
2. **Two internally inconsistent adjudications** (Q-01 vs L-06; Q-03 vs L-05) — §Direction 2.
3. **A factual error in L-01's finding record.** `plainTokenReachability: "NIL … needs a weird
   token"` is wrong — an issuer-side USDC/USDT pause or a blocklisting of the batchMinter reverts
   `_settle` with no weird-token property — and it contradicts the same record's own `severityNote`,
   which already named that vector. The severity is unaffected; the field must still be corrected,
   because read literally it invites a future reader to dismiss L-01 as weird-token-only. §D1.5.
4. **Two watch notes that are mis-calibrated** — WATCH-26-03 is under-stated (should be *joint*),
   WATCH-26-04 is over-stated (docs are carrying less weight than claimed) — §D1.1, §D3b.

---

## 1. Per-finding disposition

| ID | Claimed | Assessed | Call | Confidence | One-line basis |
|---|---|---|---|---|---|
| L-01 | Low | Low | **CONFIRM** | high | Held by the two one-tx owner escapes, not by token-class invalidity. `plainTokenReachability: "NIL"` is a **factual error** — see §D1.5 |
| L-02 | Low | Low | **CONFIRM** | high | Custody-location/expectation footgun only; no value-leak limb survives, correctly |
| L-03 | Low | Low | **CONFIRM** | medium-high | Availability, but privileged-triggered, atomic, self-naming, one-tx recoverable, no value lost. Low holds on **code** properties, not only on docs |
| L-04 | Low | Low | **CONFIRM** | high | Parked state is maximally loud (`batchMint` reverts for everyone) and pre-commission; owner retains unilateral unlock |
| L-05 | Low | Low | **CONFIRM** | high | Silent + event-before-assignment aggravators are real; optional-incentive path, fully recoverable |
| L-06 | Low | Low | **CONFIRM** | high | No value transfer at this commit — I re-derived the no-erosion argument independently and it holds |
| Q-01 | QA | QA | **CONFIRM** (with a restated discriminator) | medium | Claim is currently true, locally self-consistent, and Halmos-proved. See §D2 |
| Q-02 | QA | QA | **CONFIRM** | high | Off-chain-only, on-chain desync ruled out by grep + hook analysis |
| Q-03 | QA | **drop / informational** | **LOWER** | high | Zero security limb by its own text; origin is unvalidated Slither noise. See §D2 |
| F-01-031 | Low | Low | **CONFIRM** | high | Faithfulness route correct |
| F-02-032 | Low | Low | **CONFIRM** | high | Story's "unaffected" claim is genuinely false on reachable state; footgun, not loss |
| F-03-031 | Low | Low | **CONFIRM** | medium | Contingent on an off-chain indexer (GAP-26-05), honestly stated |
| F-04-030 | Low | Low | **CONFIRM** | high | Dual-route with L-06 is correct, not a duplicate |
| F-05-032 | Info | Info | **CONFIRM** | high | Process observation, correctly not a security finding |

**One LOWER, no RAISE, twelve CONFIRM.** No finding was moved to make the run look calmer: the
single lowering is a finding whose own text says "This is not a security finding".

---

## Direction 1 — is anything UNDER-stated?

### D1.1 — L-01 + L-03 together: do two un-isolated hops into one contract reach Medium?

**No. CONFIRM both at Low.** But the run under-states the *watch*, and that needs fixing.

Code facts I re-derived:

- The flush loop (`BatchNFTMinterMultiToken.sol:528-536`) iterates **storage** `_nudgeTokens`
  (declared `:193`), not the caller's `minRewards`-paired array. The run's claim that
  `bfdb50105e`'s wont-fix rationale ("caller chooses both the token and the recipient") does not
  transfer is **correct**.
- `pullPendingStream` early-returns on `s.duration == 0` (`NudgeStreamer.sol:222`), so
  `NotRegistered` genuinely cannot fire in the flush loop. Correct.
- `collectNudge` checks **only** `s.duration == 0` — it does **not** consult the batchMinter's
  whitelist (only `registerStream:127` does). I checked this specifically because L-01 recommends
  `setNudgeTokenWhitelist(token,false)` as an escape hatch, and if `collectNudge` had a whitelist
  check that escape would have *armed* L-03's mint-brick. It does not. **No cross-finding
  contradiction; the two escape hatches are safe.** Worth stating in the report, because a reader
  will reasonably suspect otherwise.
- `ATokenDispatcherV2.dispatch:122-123` is `_dispatch(...)` then `hook.onDispatch(...)`, exactly as
  the run says. The try/catch counter-argument at L-03 is technically sound.

Why the combination does not clear Medium:

1. **Aggregation is not a C4 mechanism.** Two Lows do not sum to a Medium. What *could* clear
   Medium is a single reachable scenario whose combined blast radius is Medium-grade. I looked for
   one and the only candidate is a shared precondition — an INV-1 violation or a token-side
   property — which is C4-invalid standalone. The privileged-config scenarios do **not** couple:
   de-whitelisting stops the flush but not `collectNudge`; `setNudgeStreamer(0)` on the batchMinter
   does not touch `NudgeRatchet.nudgeStreamer`. There is no non-token-side single action that
   bricks both legs.
2. **L-03 alone already carries the larger radius** (every mint on that dispatcher), and it is
   adjudicated on its own merits in §D3b. Adding L-01 to it adds nothing reachable.

**Where the run *is* under-stated — WATCH-26-03 must become joint.** As written, the watch says the
same counterexample "escalates both", i.e. two separate Mediums. That understates the trigger state:
one INV-1 counterexample would brick the **mint** (via `collectNudge` → `_settle`) *and* the
**flush** (via `pullPendingStream` → `_settle`) simultaneously, in normal operation, unannounced —
that is a total user-facing outage with no operator action involved, which is Medium **at minimum**
and worth a High look. Recommend rewording: *"on trigger, re-weigh L-01 and L-03 **jointly**;
combined effect is a total mint+flush outage arriving without an operator action — Medium floor, not
Medium ceiling."*

**On the "third occurrence" argument.** `966e717669` (open, Low), `1887dbe136` (open, Low), now
L-01. Recurrence is real and the scrutiny is warranted, but it does **not** raise per-finding
severity — each instance's impact and precondition are what they are, and I checked that none of
the three is individually mislabelled. What recurrence *does* justify is a **systemic item**: three
open, unfixed instances of one class across one family is a policy gap, not three coincidences.
Recommend one consolidated hardening entry ("external-call isolation policy for optional
cross-contract legs: isolate where nothing downstream consumes the result, fail loud where it
does") that names all three, so the pattern is visible to the owner as a pattern. Filing that is a
recall action, not an inflation.

### D1.2 — the Leg-B kill: is "proved at 2 streams + hand-checked induction" enough?

**Yes. The kill is sustained. Do not carry it as an open item.** And I can discharge more of the
residual than the run did — with one substitution.

The run treats the §5 N-stream reduction as its soft spot ("an argument a human made; if it is
wrong, the 3-stream timeouts are where the error would hide"). I tested the reduction's premise
directly against the source rather than accepting it:

- `collectNudge` resolves `streams[recipientBatchMinter][token]` once (`:156`) and every subsequent
  read/write on the path goes through that one `Stream storage s`.
- `_settle(Stream storage s, ...)` and `_accrued(s)` read and write **only** `s`.
- `pullPendingStream` resolves one struct; `registerStream` resolves one struct.
- **`NudgeStreamer` holds no aggregate state at all** — no total, no per-token sum, no loop over
  streams anywhere in the contract.

So `Σ_{i≠k} buffer_i` is a *constant* across any single transition, and it is never read on any
path. The N-stream property therefore reduces to `buffer_k' + C ≤ balance'` for an arbitrary
symbolic `C` — which is *literally* the shape of the 2-stream D96 test, whose untouched stream's
buffer is an unconstrained symbolic word bounded only by the inductive hypothesis. That is a sound
reduction, and its premise is a **structural fact checkable by inspection**, not a judgement call.
I checked it. It holds.

Consequence: the ≥3-stream Halmos timeouts are solver blow-up on a **logically redundant** query
(three nonlinear addends), not a coverage gap. They are correctly reported as inconclusive and
correctly not cited as verification — but the run over-weights them as "the open door for
WATCH-26-03". Additionally, the invariant tier *did* exercise ≥3 streams empirically and
non-vacuously: 3 seeded tokenA streams, 600/600 checks against a ≥2-stream aggregate, 3
simultaneously funded, ~452k calls across two engines, mutation-verified. Fuzzing is not proof, but
it is not nothing at the arity the proof could not reach.

**Recommended substitution.** Keep WATCH-26-03's INV-1 trigger, and add the guard that actually
protects the reduction:

> **Code invariant (new watch).** `NudgeStreamer` must never read or write more than one `Stream`
> struct per transition, and must never introduce aggregate state. Any cross-stream read, any loop
> over streams, or any per-token total invalidates the §5 N>2 reduction and demotes INV-1 to
> "proved at 2 streams only".

That converts a hand-check into a maintainable, checkable obligation — strictly better than
carrying a Low nobody can act on. **A false kill is not being recorded here.** Recording one would
require the reduction's premise to be unverified; it is verified.

### D1.3 — L-02: did the KI #16 narrowing strip the real severity driver?

**No. CONFIRM Low.** I re-derived what the finding is left with and it is intact.

The struck limb was economic magnitude (pot-size / payout-cap). What remains, and what the actual
driver is: `setNudgeSize(0)` is documented at two NatSpec sites as *"disables the feature"*; it
disables the payout (`_snapshotRewards:801` gates on `qualifies`, `_payRewards:831` skips zero) but
not the inflow (`collectNudge` is permissionless and the production donor is on a schedule) and not
the flush (the loop at `:528-536` does **not** read `qualifies` — verified). That is the surprise,
and the surprise is the finding. Law 3's test passes cleanly.

The lump-payout limb the narrowing touched was **already** structurally weak, independently of
KI #16, and the run says so honestly: a quiet period longer than `duration` makes `_accrued` hit
its `buffer` cap anyway, so the flush is not the *cause* of the lump. Nothing load-bearing was lost.

I did **not** restore any value-leak framing, and confirm none is available: nudge pots are
externally-derived yield on protocol-owned capital, so mis-sizing is misallocation/opportunity
cost. One additional fact *further weakens* the "no return path" wording rather than strengthening
it: the flush's destination, `BatchNFTMinterMultiToken`, **has** `rescueERC20` (`:386-389`,
`onlyOwner`, no token restriction, callable while paused), whereas the source, `NudgeStreamer`, has
none. So the flush moves value from a no-rescue container into a rescuable one, and the operator has
a remedy for the accumulated lump. "No return path" is true of the streamer, false of the
destination — reword to "no way to stop the inflow, and no meter on the destination", which is the
accurate claim and still supports Low.

### D1.4 — L-04 / F-02-032: is "recoverable by finishing configuration" doing too much work?

**No. CONFIRM Low** — but the run under-uses its own strongest argument and over-uses a weaker one.

Verified: `_resolvePaymentPath()` runs at step 2 (`:479`), the flush loop at step 3.5 (`:528-536`),
so `BatchMint__MinterNotConfigured` fires **before** anything can drain. `registerStream` is
`onlyOwner`; `collectNudge` is permissionless. Funds park. `NudgeStreamer` has no rescue, no pause,
no deregistration. All correct.

The strongest argument, which the run does not lead with: **in the parked state `batchMint` reverts
for every caller.** The contract is not merely mis-sequenced, it is entirely non-functional — this
is a bring-up window, nobody is minting, and the condition announces itself on the first smoke
test. Value parking during pre-commission, in protocol custody, in a state that is loud and
unilaterally unlockable by the owner, is Low.

Taking the user's two escalation branches in turn:

- **Config never completed.** Not a Medium. Nothing has leaked (funds are in a protocol contract),
  and the owner retains a unilateral unlock at all times (`setTokenMinter` + `setDispatcherIndex`).
  "The owner declines to finish a deployment" is not an attack path and not a protocol-function
  impact in the C4 sense — it is the absence of a deployment.
- **BatchMinter repointed.** This is the real one, and it is **permanent** stranding: the buffer is
  keyed `(batchMinter, token)` and only that `msg.sender` can `pullPendingStream`, so if the old
  batchMinter is paused or decommissioned the funds are unreachable with no rescue. That is already
  ledger `4a1d8edc92` (Low, open) — whose title explicitly covers both the decommission case and
  the permanent-de-whitelist case. So it is tracked, at Low, and L-04's instruction not to collapse
  the two is correct: L-04 is a *new route into* needing the rescue that `4a1d8edc92` says is
  absent.

I considered raising the **compound** (new route in + no way out) to Medium and decided against it,
affirmatively: it needs two privileged actions, strands only optional-incentive funds already sunk
from yield (opportunity cost, not loss), and the run has recorded the compounding rather than hidden
it. Both stay Low.

**Positive recommendation the run should carry.** A `rescueERC20`-equivalent (or a
`deregisterStream`) on `NudgeStreamer` is a single change that closes **L-04**, **`4a1d8edc92`**,
and the permanent-de-whitelist stranding at once. Three open items, one fix. That is more useful to
the owner than three separate documentation asks, and it should be stated as the preferred
mitigation for L-04 rather than only the ordering-precondition restore.

### D1.5 — ADDENDUM: the USDC/USDT pause-and-blocklist trigger (validity-checker evidence)

**Decision: L-01 stays LOW. L-03 stays LOW. The `plainTokenReachability: "NIL"` field is a factual
error and must be corrected.** All three parts of that decision are affirmative, and none is taken
to preserve an all-Low headline — I would have raised it if the branch analysis came out the other
way, and I say below exactly what would have made it come out the other way.

**First, a fact that reframes the challenge.** The finding record already weighed this trigger. Its
`severityNote` reads, verbatim:

> "Held at Low because every trigger is individually owner-obvious, **third-party-extraordinary
> (Circle/Tether pause or blocklist)**, C4-permanently-invalid, or owner-observable…"

So the pause/blocklist vector was **not** overlooked; it was named and adjudicated. What is wrong is
`plainTokenReachability`, which says the only remaining revert path "needs an INV-1 violation, **i.e.
a weird token**". That is **internally inconsistent with the record's own `severityNote`** and, read
literally, invites a future reader to dismiss L-01 as weird-token-only. The validity-checker is
right about the field. Correct it to something like:

> `plainTokenReachability`: "NON-NIL, but not attacker-inducible. `NudgeStreamer__NotRegistered`
> cannot fire (`:222` early-return). `_settle`'s transfer at `:243` reverts on **either** an INV-1
> violation (weird token) **or** an issuer-side USDC/USDT global pause or a blocklisting of the
> batchMinter — the latter requires **no** weird-token property and is documented behaviour of the
> actual settlement asset. Held at Low on the trigger and escape analysis, NOT on token-class
> invalidity."

That correction matters beyond bookkeeping: **it moves part 2 of L-01's mitigation (`try/catch`) off
a weird-token-only justification and onto a plain-asset one.** The fix's case gets stronger even
though the label does not move. This supersedes refinement 1 in §D3a, which described part 2 as
closing a "token-side-conditional" exposure — read "issuer-event-conditional" instead.

**Now the three questions, and the standard applied.**

**(1) Is an issuer-side pause/blocklist a "plainly-reachable trigger"?** No — and the reason is not
plausibility handwaving, it is a **branch analysis showing the impact is either non-incremental or
one-transaction escapable in every case.** I did this per branch rather than in the abstract:

| Branch | Reachable? | Incremental to L-01? | Escape |
|---|---|---|---|
| **Global USDC pause, payment token == nudge token (USDC)** | yes | **NO** | `batchMint`'s own payment pull at `:581` reverts regardless. The flush loop adds nothing; the outage is not this finding's |
| **Global USDC pause, payment token ≠ USDC** | yes | yes — the flush loop is then the *only* USDC touch and takes down an otherwise-working mint | `setNudgeTokenWhitelist(USDC,false)` **or** `setNudgeStreamer(0)` — one owner tx, loudly signalled |
| **Blocklist of the batchMinter specifically** | yes, but a targeted sovereign act against one named protocol contract | partly — if payment is USDC the batchMinter also cannot receive or pay USDC at all, so the nudge path is dead independently | same two one-tx escapes |

So the standard I apply is **C4's Medium availability limb, unchanged**: an availability finding
reaches Medium when the outage is **attacker-inducible, OR undetectable, OR unrecoverable**. This
outage is none of the three — no third party can induce it (agreed), it reverts loudly and
atomically, and the owner holds **two single-transaction escapes that lose no value** (the stranded
buffer is `4a1d8edc92`, Low, open). "Requires no weird token and no owner mistake" is a real point in
Medium's favour and I gave it weight; it is not sufficient on its own, because C4 severity is
trigger **and** consequence, and the consequence here is escapable in one transaction.

**What would have made this a Medium**, stated so the call is falsifiable: remove either escape — an
immutable nudge whitelist, or a `nudgeStreamer` that could not be zeroed — and the outage becomes
unrecoverable-within-the-contract, which clears the limb. Both escapes exist and I verified them in
source (`setNudgeStreamer:297-300`; `setNudgeTokenWhitelist:328-336` removal branch is
derivation-free by design, so it works even while the minter is unconfigured). **The escapes are
load-bearing for this Low — if either is ever removed, L-01 is Medium.** That belongs in the ledger
as a reopen trigger, and it is a sharper trigger than the one currently written.

**(2) Does the USDT carve-out put blocklist reverts in scope as a matter of rule?** It puts them in
**scope**; it does **not** set their severity. The carve-out's function is to stop "but a weird token
could…" dismissals of findings that depend on the behaviour of an asset the protocol must actually
support — so a USDT/USDC blocklist finding may be *filed*, and the run may not wave it away as
weird-token noise (which is exactly what the erroneous field does). But in-scope ≠ Medium. Severity
is still decided by likelihood and consequence, and an issuer freeze is a third-party sovereign act
that no design can prevent and that every USDC integrator accepts. Treating "the rule lets me file
it" as "the rule sets it at Medium" would be a category error — and it is the specific error that
produces overstated reports. So: **rule ⇒ in scope and must be named; judgement ⇒ Low, on the escape
analysis above.**

**(3) Plainly stated:** **I am not raising L-01 to Medium.** No PoC or submission report is
triggered. This is not tidiness — the run's own `severityNote` reached the same conclusion with the
same vector in view, and my independent branch analysis reproduces it with a sharper reason (escape
availability) than the one the run gave (trigger extraordinariness).

**Does L-03 follow? No — and it fails the incremental test even harder.** `NudgeRatchet`'s prime
token is USDC (constructor-enforced 6 decimals), and the mint payment arrives on the dispatcher via
`NFTMinterV2._executeMint`'s `safeTransferFrom(msg.sender, config.dispatcher, price)` in **that same
USDC**. So under a **global USDC pause the mint is already bricked at the payment leg**, before
`dispatch` is ever reached — **zero incremental impact from the un-isolated `collectNudge` hop.**
Only the *targeted blocklist of the batchMinter* is incremental, and its recovery is messier than
L-01's (`NudgeRatchet` has no donation-disable switch by deliberate design, so escape means
repointing `batchMinter` and registering the new pair — two-plus owner txs, stranding the old
buffer). Messier, but still recoverable, still loud, still not attacker-inducible ⇒ **Low**.

This also settles §D1.1's coupling question on firmer ground than I had before: the pause/blocklist
vector does **not** couple the two findings into a Medium, because in the one branch where it hits
both (global pause with USDC on both legs) the mint is already down for an unrelated reason. The
INV-1 counterexample remains the **only** trigger that bricks mint and flush *incrementally and
simultaneously*, which is why WATCH-26-03 should be joint and why it, not the blocklist, is the door
to watch.

---

## Direction 2 — is anything OVER-stated?

Nine Lows from a 13-file range is defensible **because seven of them are genuinely distinct root
causes**, not one issue split seven ways: two setter-validation gaps (L-04, L-05), two isolation
sites in different repos (L-01, L-03), one documented-lever asymmetry (L-02), one self-contradicting
safety claim (L-06), plus four story-attribution items correctly routed away from the QA bundle.
I found no padding and no duplicate-in-disguise. The L-01/L-02 same-site split is correctly
justified (availability vs value migration — a reader seeing only one would not learn the other).

**Q-03 → LOWER (drop, or move to an informational maintainability note).** By its own text: origin
is Slither missing-inheritance noise; impact is "**None at this commit**"; drift "**fails
closed**"; and it concludes "**This is not a security finding**". C4 explicitly discourages
non-critical issues and puts "common findings from automated tools without a demonstrated H/M
exploit path" out of scope. The Law-1 no-silent-drop concern does not apply — a finding with no
security limb cannot hide an exploit, so dropping it costs nothing that Law 1 protects. Keeping it
"so the decision is the reader's" is a reasonable instinct applied to the wrong candidate; it
spends reader credibility, which is the one thing the quality standard says the report cannot
afford.

**Q-03 also contains a reasoning error worth correcting even if it is dropped.** It dismisses its
false-accept path — an owner-supplied address with a permissive fallback — as "obvious owner error,
suppressed under Law 3". But **L-05 is filed at Low on exactly that same precondition**. The same
condition cannot be Law-3-suppressed in one entry and finding-sustaining in the next. L-05 has it
right (the aggravators — silence, plus the event emitted *before* assignment at `:298-299`, which
makes a mis-point read as clean success — are what make it non-obvious). Q-03's Law-3 invocation is
over-applied.

**L-06 and Q-01 — the documentation question. Both CONFIRM, but the stated discriminator is wrong.**

"The docs give the wrong reason for something that nonetheless holds" is, in the general case,
**QA** — the property holds, so there is nothing to exploit today, and the harm is a future
editor's. Under this repo's standing rule, a *falsely*-exhaustive claim on a **load-bearing**
invariant raises that; that rule applies to **both** of these, which is why they cannot be split on
the grounds the run gives ("false *safety* guarantee" + "dual-routed"). Both are false-exhaustive
claims about load-bearing invariants; "dual-routed to spec-conformance" is a routing fact, not a
severity fact.

There *is* a real discriminator, and the run should substitute it:

- **Q-01's claim is currently true, locally self-consistent, and machine-proved** (Halmos, 2 streams
  at D96 + the §5 reduction). The text cites the wrong mechanism for a property that is
  independently established. Pure maintainability ⇒ **QA**.
- **L-06's claim is true only modulo an *undocumented cross-repo coupling*** (`batchMint:646` reads
  `config.price`; `NFTMinterV2._executeMint:179-183` charges exactly that same slot, with the price
  ramp at `:188` *after* the transfer — I re-derived this leg at `yield-claim-nft` @ `d4cc563` and
  it holds), **and it is contradicted by its own file 30 lines later** (`:695-702`). So its property
  can be broken silently, from another repository, by someone who never reads this file ⇒ **Low**,
  and WATCH-26-02 is the right instrument.

Same conclusion, sound reason. As written, the split invites a reader to think it is arbitrary.

Nothing else is over-stated. L-05's Medium-class cross-project precedent is disclosed rather than
buried, and the distinction drawn (optional-incentive vs value-bearing path) is substantive — I
checked it against the two cited precedents' framing and it holds.

---

## Direction 3 — testing the two overrides

### D3a — promoting L-01's `try/catch` to co-equal primary: **CORRECT.** CONFIRM the override.

Verified in source: `qualifies` is computed at `:510-514`; the flush loop at `:528-536` does not
read it; `_snapshotRewards(minRewards, qualifies)` at `:539` does. A **qualifying** batch therefore
still calls `pullPendingStream` across the entire owner whitelist inside one transaction with no
isolation. Gating on `qualifies` cannot touch that. The run's reading of its own finding is right,
and part 1 alone would leave the stated primary impact fully live. You are not over-stating the
fix's incompleteness.

Two refinements:

1. **Be precise about which half is presently reachable.** Since the revert's plain-token
   reachability at this commit is nil, part 1 closes **all of the currently-reachable exposure**
   (the non-qualifying caller's zero-benefit exposure, and L-02 in full), while part 2 closes a
   **token-side-conditional** exposure. Both are worth doing and co-equal is the right label for
   completeness — but a reader deciding what to ship first should be told that part 1 is the one
   with reachable effect today and part 2 is the one that survives a token change or an INV-1 break.
2. **The L-01/L-03 try-catch asymmetry is sound, and I verified the reason.** At L-01's site the
   next statement is `_snapshotRewards`, which reads *actual balances* — a skipped pull just
   produces a smaller snapshot, and no downstream accounting is keyed to the amount that failed to
   arrive. At L-03's site `dispatch` runs `hook.onDispatch(minter, amount, ...)` immediately after
   `_dispatch`, so debt accrues against a value that did not move. Same construct, opposite verdict,
   correctly reasoned. Keep the paragraph that explains it; without it the report looks
   self-contradictory.

### D3b — "accurate documentation is severity-reducing": **directionally right, but over-weighted.** Partial disagreement.

You are not letting a comment do a guard's job — the run is explicit that in-source NatSpec carries
no suppression authority, and it verified the disclosure against the code instead of trusting the
"NOT an audit finding" clause. That handling is correct, and the *falsely*-exhaustive vs
*accurately*-exhaustive distinction you rely on is a real one. I read `NudgeRatchet.sol:23-50`
myself: it names the exact revert, states the blast radius ("every `dispatch`"), covers the
`batchMinter` repoint, and prescribes a numbered ordering with `setNudgeStreamer` **last**. It is
accurate.

Where I disagree: **documentation can only move the likelihood/surprise limb. It cannot move impact,
detectability, or recoverability — and those are what actually hold L-03 at Low.** Per §3.3 of the
classification, the outage is not attacker-inducible, reverts with a self-naming custom error on the
first mint attempt, is recoverable in one owner transaction, and loses no value. **Those are code
properties and they are sufficient for Low on their own.** So:

- **WATCH-26-04 over-states.** "If that NatSpec is edited the Low is **invalidated**" and "any
  dispatcher without an equivalent disclosure is **Medium**" are too strong. Deleting the NatSpec
  would make this an *undocumented* footgun with a loud, atomic, one-transaction-recoverable
  failure at bring-up — still **Low**. Reword to "**re-weigh**, with the footgun limb no longer
  mitigated", not "invalidated / becomes Medium". A watch that promises a Medium it cannot deliver
  gets discounted the first time it fires.
- **One genuine weakness in the disclosure argument, worth recording.** The runbook lives in the
  *other repo*, on the dispatcher, and prescribes an ordering spanning three contracts — while
  `BatchNFTMinterMultiToken.setNudgeStreamer`'s own NatSpec (`:292-299`, which I read) says nothing
  about the mint-brick consequence at all. An operator working from the phoenix side does not see
  the disclosure. That does not defeat Low (the code limbs carry it), but it means the
  documentation is doing *less* work than WATCH-26-04 credits it with, and mitigation item 2
  ("document the deliberate divergence at **both** sites") should be extended to a third site:
  `setNudgeStreamer`'s NatSpec on the phoenix side.

Both corrections push in the same direction: the Low is **more robust** than the run believes,
because it rests on code, not prose.

---

## 2. Structured output

```json
{
  "severityAudit": {
    "run": "phoenix-nft-staking-26",
    "commit": "9611312",
    "timestamp": "2026-07-30",
    "claimedTotals": { "high": 0, "medium": 0, "low": 9, "qa": 3, "informational": 1 },
    "assessedTotals": { "high": 0, "medium": 0, "low": 9, "qa": 2, "informational": 1, "dropped": 1 },
    "agreementRate": "13/14 (one LOWER: Q-03)",
    "overallVerdict": "0 High / 0 Medium is the honest result for this range. No under-statement found. One QA-grade entry over-included.",
    "dispositions": [
      { "id": "L-01", "claimed": "low", "assessed": "low", "call": "CONFIRM", "confidence": "high", "note": "Re-decided against the validity-checker's USDC/USDT pause-and-blocklist evidence (see D1.5). NOT raised to Medium: in every branch the outage is either non-incremental (global pause with USDC on both legs bricks batchMint at the payment pull :581 regardless) or escapable in ONE owner transaction (setNudgeTokenWhitelist(token,false) / setNudgeStreamer(0)). Not attacker-inducible, not undetectable, not unrecoverable => C4 Medium's availability limb is not cleared. RECORD ERROR: plainTokenReachability must change from 'NIL ... needs a weird token' to 'NON-NIL but not attacker-inducible' — it contradicts the record's own severityNote, which already named 'third-party-extraordinary (Circle/Tether pause or blocklist)'. New sharper reopen trigger: L-01 becomes MEDIUM if either one-tx escape is removed (immutable nudge whitelist, or a nudgeStreamer that cannot be zeroed)." },
      { "id": "L-02", "claimed": "low", "assessed": "low", "call": "CONFIRM", "confidence": "high", "note": "reword 'no return path' — the destination has rescueERC20; the streamer does not" },
      { "id": "L-03", "claimed": "low", "assessed": "low", "call": "CONFIRM", "confidence": "medium-high", "note": "Low rests on code limbs, not primarily on disclosure; WATCH-26-04 over-states. Does NOT follow L-01 to Medium on the pause/blocklist vector: NudgeRatchet's prime token is USDC and the mint payment arrives in that same USDC via NFTMinterV2._executeMint's safeTransferFrom, so a global USDC pause bricks the mint at the payment leg before dispatch is reached — zero incremental impact. Only a targeted batchMinter blocklist is incremental, and it is recoverable by repointing batchMinter + registering the new pair." },
      { "id": "L-04", "claimed": "low", "assessed": "low", "call": "CONFIRM", "confidence": "high", "note": "lead with 'batchMint reverts for everyone in the parked state'; recommend a streamer rescue as the single fix closing L-04 + 4a1d8edc92 + de-whitelist stranding" },
      { "id": "L-05", "claimed": "low", "assessed": "low", "call": "CONFIRM", "confidence": "high" },
      { "id": "L-06", "claimed": "low", "assessed": "low", "call": "CONFIRM", "confidence": "high", "note": "substitute the discriminator: true only via an undocumented cross-repo coupling, and self-contradicted in-file" },
      { "id": "Q-01", "claimed": "qa", "assessed": "qa", "call": "CONFIRM", "confidence": "medium", "note": "discriminator vs L-06 is 'machine-proved and locally self-consistent', not 'not dual-routed'" },
      { "id": "Q-02", "claimed": "qa", "assessed": "qa", "call": "CONFIRM", "confidence": "high" },
      { "id": "Q-03", "claimed": "qa", "assessed": "drop", "call": "LOWER", "confidence": "high", "note": "no security limb by its own text; unvalidated tool origin; also mis-applies Law 3 in a way that contradicts L-05" },
      { "id": "F-01-031", "claimed": "low", "assessed": "low", "call": "CONFIRM", "confidence": "high" },
      { "id": "F-02-032", "claimed": "low", "assessed": "low", "call": "CONFIRM", "confidence": "high" },
      { "id": "F-03-031", "claimed": "low", "assessed": "low", "call": "CONFIRM", "confidence": "medium" },
      { "id": "F-04-030", "claimed": "low", "assessed": "low", "call": "CONFIRM", "confidence": "high" },
      { "id": "F-05-032", "claimed": "informational", "assessed": "informational", "call": "CONFIRM", "confidence": "high" }
    ],
    "killsUpheld": [
      { "id": "Leg-B / aggregate over-statement", "verdict": "KILL SUSTAINED", "basis": "The §5 N>2 reduction's premise is a structural fact I verified independently: NudgeStreamer holds NO aggregate state and every path resolves exactly one Stream struct, so the untouched sum is a constant never read. The >=3-stream Halmos timeouts are solver blow-up on a logically redundant query, not a coverage gap. No false kill is being recorded. Replace the residual with a code invariant: never read/write more than one Stream per transition." }
    ],
    "correctionsRequired": [
      { "severity": "important", "item": "qa-report.md:46 points readers at submissions/carryover/, which DOES NOT EXIST. The run-26 re-frame of open ledger entry aaebb4b9b0 (duration is a time constant not a drain time; ~63% retained at nominal window end; do NOT permission collectNudge) appears in NO deliverable. Law-1 visibility hole: create the directory or fold the re-frame into qa-report.md." },
      { "severity": "important", "item": "FACTUAL ERROR IN THE L-01 RECORD: plainTokenReachability = 'NIL ... needs an INV-1 violation, i.e. a weird token' is wrong and contradicts the same record's severityNote. An issuer-side USDC/USDT global pause, or a blocklisting of the batchMinter, reverts _settle's transfer at :243 with NO weird-token property. Correct the field to 'NON-NIL but not attacker-inducible', and note that this moves part 2 of the mitigation (try/catch) onto a plain-asset justification — the fix's case strengthens even though the severity does not. The USDT carve-out makes this IN SCOPE as a matter of rule (it may not be waved away as weird-token noise) but does NOT set it at Medium." },
      { "severity": "moderate", "item": "Replace L-01's reopen trigger with the sharper one: L-01 becomes MEDIUM if either one-transaction owner escape is removed (an immutable nudge whitelist, or a nudgeStreamer that cannot be zeroed). Those escapes are what hold the Low; the current 'plainly-reachable trigger' wording is too vague to adjudicate and was read by the validity-checker as already met." },
      { "severity": "moderate", "item": "WATCH-26-03 is UNDER-stated: on trigger, L-01 and L-03 must be re-weighed JOINTLY — one INV-1 counterexample bricks mint AND flush in normal operation with no operator action. Medium floor, not Medium ceiling." },
      { "severity": "moderate", "item": "WATCH-26-04 is OVER-stated: editing the NatSpec would not INVALIDATE the Low. The Low rests on code limbs (not attacker-inducible, atomic self-naming revert, one-tx recoverable, no value lost). Reword to 're-weigh, footgun limb no longer mitigated'. Also extend mitigation item 2 to a third site: BatchNFTMinterMultiToken.setNudgeStreamer's NatSpec (:292-299) discloses nothing about the mint-brick." },
      { "severity": "moderate", "item": "Drop Q-03, or demote it to an informational maintainability note." },
      { "severity": "minor", "item": "Restate the Q-01 vs L-06 discriminator (machine-proved + locally consistent vs undocumented cross-repo coupling + in-file self-contradiction). As written the one-band split reads as arbitrary." },
      { "severity": "minor", "item": "Q-03's Law-3 dismissal of the permissive-fallback path contradicts L-05, which is filed at Low on that same precondition. L-05's treatment is the correct one." },
      { "severity": "minor", "item": "L-02's 'no return path' should read 'no way to stop the inflow, and no meter on the destination' — BatchNFTMinterMultiToken.rescueERC20 (:386-389) gives the owner a remedy for the flushed lump; NudgeStreamer is the container with no exit." },
      { "severity": "minor", "item": "State affirmatively that collectNudge does NOT consult the batchMinter whitelist (only registerStream:127 does), so L-01's recommended escape hatch setNudgeTokenWhitelist(token,false) does NOT arm L-03's mint-brick. A reader will suspect it does." },
      { "severity": "minor", "item": "File one consolidated systemic entry for the un-try/catch'd-external-call class naming 966e717669, 1887dbe136 and L-01 — three open unfixed instances is a policy gap, visible as a pattern. Recall action, not a severity change." }
    ],
    "understatementSweepResult": "No severity under-statement found. The four interrogated downgrades/kills, plus the late USDC/USDT pause-and-blocklist challenge, each survive independent re-derivation from source. No Low touches assets; no Medium-grade direct-theft path was mislabelled. TWO record-level under-statements WERE found and must be corrected: (a) L-01's plainTokenReachability field understates the trigger class as weird-token-only; (b) WATCH-26-03 understates its own trigger by treating it as two separate Mediums rather than one joint total-outage."
  }
}
```

---

## 3. Closing statement

I applied downgrade pressure only where a downgrade was affirmatively justified, and I looked as
hard for under-statement as for over-statement — including the validity-checker's late
pause-and-blocklist challenge (§D1.5), which I decided on a per-branch escape analysis rather than on
plausibility, and one hypothesis of my own (that
`collectNudge` might consult the batchMinter whitelist, which would have turned L-01's escape hatch
into L-03's trigger and produced a genuine coupled Medium). It was refuted by the code. A second
hypothesis — permissionless dust `collectNudge` window-reset as a delay weapon — turned out to be an
already-open Low (`aaebb4b9b0`) that this run re-confirmed and re-framed correctly.

**No finding in this run deserves Medium or High.** The one thing that genuinely worries me is not a
severity label: it is that the run's most substantive economic conclusion — the low-pass-filter
re-frame with its reversed remediation — reaches no reader of the submissions, because the carryover
channel it was routed to does not exist. Under Law 1 that is the costlier error in this report, and
it is the first thing I would fix.
