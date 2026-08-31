# Severity Audit — phoenix-nft-staking run-21

**Auditor:** severity-auditor (independent second opinion)
**Date:** 2026-07-21
**Project:** `phoenix-nft-staking` @ `c881a428c87ef4ef42ba07a71be5d49101c9006d`
**Baseline:** `0d1a0b2187bb980f1ac6c6b54d0b01e6410a2e54`
**Reviewed:** `classified-findings.json` (28 entries) against `submissions/`, `poc-replay.md`,
`tier3-invariants.md`, `mainnet-verification-ECON-001.md`, `dedup-results.json`, plus independent
re-reads of `src/BatchNFTMinter.sol`, `src/NFTStakerDepletion.sol` and the phStaging deploy scripts.

---

## VERDICT

| Outcome | Count |
|---|---|
| **Severity CONFIRMED** | **28 / 28** |
| **Severity DISPUTED** | **0** |
| **Stated ground DISPUTED at an unchanged label** | **3** (M-01, M-02, M-03) |
| **Cross-cutting consistency dispute** | **1** (missing re-arm triggers on the two expired-closure reopens) |
| Convention calls agreed | 2 (no-`M-nn` on reopens; fix-pending not re-rated) |
| Parked items — parking agreed | 2 |

**No label moves.** That is not a rubber stamp: I pushed on all three hard calls and on the two
Lows named in the brief, and one of the three grounds (M-02's) is not merely stylistically weak —
it is **factually wrong in a direction that invites an unjustified future downgrade to Low**. That
is the substantive result of this audit and it should be treated as the headline, not the count.

**Direction of pressure.** I found no overstatement anywhere in this run. I found **one place where
the report understates its own strongest evidence** (M-02) and **one place where a severity-pivotal
fact is asserted from source rather than read from mainnet** (M-03). Both are understatement risks,
which under Law 1 are the more expensive kind.

---

## 1. The three hard calls

### 1.1 M-01 (`7a1718e9…`) — Medium held. **CONFIRMED. Ground must be re-ordered.**

**Is "no asset presently reachable" a legitimate bound on C4 High, or deployment-status reasoning
wearing a different hat?**

It is *legitimate but load-bearing on the wrong plank*, and as written it is the weakest defensible
version of a much stronger argument the report already has the evidence for.

**Why the stated ground is weak.** "Both live instances hold 0 payment token at block 25577241" is a
**block-height fact**. The standard C4 rebuttal writes itself: *TVL at audit time does not bound
severity — a pool-drain is a High whether or not the pool is empty on the day you looked.* A reviewer
can dismantle the Medium in one sentence by invoking that principle, and they would be applying the
same instinct that produced R-6. Six sampled blocks make the zero durable; they do not make it
structural. Worse, `mainnet-verification-ECON-001.md` §7 lists as *fact 5 keeping it off High*:
*"`BatchNFTMinterMultiToken` — where the finding is filed — is **not deployed**."* That is **exactly
the R-6-forbidden ground**, stated in the evidence file, and it contradicts `M-01.md:149-150` which
explicitly disclaims it. **Strike or relabel §7 fact 5** — as written it hands a reader the argument
that the Medium rests on non-deployment after all.

**Why Medium is nevertheless correct — the ground that actually holds.** I tested the one thing that
would break it: *can the attacker create the precondition themselves?* Under my rule 4, a
self-creatable precondition is not an external requirement and does not cap severity at Medium.

- **Self-funding is net-neutral.** Donate `R`, then `batchMint(paymentAmount = 0)` — you recover your
  own `R`. No extraction.
- **The compound case is loss-making.** Donate ~634 USDS to `0x86866e01…`, call `count = 40,
  paymentAmount = 0` → you take back the USDS *and* the 94.95 USDC nudge pot, but you have paid
  ~634 USDS for 40 NFTs. This is the **designed nudge bounty operating as intended**, not a drain.
  §5 of the verification reaches the same conclusion; I re-derived it independently from source.
- **Dust accumulation cannot arm the free-mint leg.** Residual below `DUST_THRESHOLD = 1e6` is
  retained, and the next sweep at `>= 1e6` hands it to the next honest caller. On `0x81896F48…`
  (70 USDC/mint) the retainable residue is `< 1 USDC` — two orders of magnitude short of funding a
  single free mint.

So arming genuinely requires a **third party or the owner** to route payment token in, and the
inflow trace in §5 shows **all three live routes deliver the wrong token** (USDC into an instance
whose payment token is USDS; nothing into the instance whose payment token is USDC). *That* is a
structural claim about the system as wired, it is attacker-uncontrolled, and it is the textbook C4
Medium external requirement.

> **Replace the ground.** Lead with: *the attacker cannot profitably arm this, and no live route
> arms it — traced through all three inflow paths.* Demote the balance census to **corroboration**
> ("and consistent with that, the measured balance is durably zero"). Same label, an argument a
> reviewer cannot knock over with the TVL-at-audit-time objection.

The RE-RATE trigger list (a)–(d) is the best-constructed part of this submission and must survive
any rewrite. Trigger (c) — repointing `NudgeRatchet.batchMinter()` to the instance whose payment
token **is** USDC — is a genuinely non-obvious one-call arming action against an operator with a
documented history of exactly that move. Correctly filed as a Law-3 footgun, not a malicious-owner
vector.

### 1.2 M-02 (`c847207d…`) — Medium. **CONFIRMED. The stated ground is WRONG and must be replaced.**

**Is it "user input mistake" (invalid)?** No. Passing a contract to a parameter whose entire purpose
is to accept ERC-1155 recipients is documented use, not a mistake, and the submission's
detectability test (tx succeeds, no event, `totalPaid` affirms a clean batch) is the right one. The
known-invalid class does not reach it. **Not invalid.**

**Is it double-counting ledger `L-01` `9135cf79…`?** No. L-01 is the bare *observation* that a guard
is missing; M-02 is an **exploit-backed realised instance with a measured 26.900000 USDC victim
loss on the deployed file**, dual-harness, identical literals, real unmodified `NFTMinterV2`. The
Medium is earned by the exploit, not by the omission. *Ledger note:* keeping both **open**
indefinitely does risk a reader counting the omission twice — L-01 should be marked
**superseded-by `c847207d…`** rather than carried as an independent open Low. Hygiene, not severity.

**The ground is wrong.** `M-02.md:216-224` holds Medium **"on that operational-reachability ground
alone"** — no caller has been shown to name a contract as `recipient` — and then offers the triager
this: *"if the operator can state that every caller is a first-party front-end naming EOA
recipients, this drops honestly to Low."*

**That sentence is false, and it is a live downgrade trap.** I re-read
`src/BatchNFTMinter.sol:280-311` from source. The nudge pays **`recipient`**; the sweep pays
**`msg.sender`**. Both are attacker-choosable *by the attacker acting as the caller*. There is
therefore a self-contained path requiring **no third-party integration and no victim at all**:

> Attacker calls `batchMint(count >= nudgeSize, recipient = own hostile contract, paymentAmount = X)`
> and funds the batch honestly. The acceptance hook re-enters on the last iteration. The inner frame
> re-snapshots the nudge pot — now inflated by the outer batch's own donations — and is paid it; the
> inner's donations refill the pot so the outer `:301` transfer still clears. Both payouts land on
> attacker-controlled addresses.

`test_Exploit_NudgeSnapshotPaidTwice` already proves this (Mallory +25,000,000 NDG vs an honest
5,000,000; pot left at 10,000,000 instead of 15,000,000). Netted against the honest two-batch
counterfactual the attacker gains **one extra pot cycle** and depletes the pot by the same amount —
value owed to **future third-party claimants**, exactly as the submission itself says at
`:150-153` before immediately re-gating it behind a precondition that does not apply.

Consequences:

1. **The operator's answer cannot drop this to Low.** "All callers are our front-end naming EOAs"
   does not touch the attacker-as-caller path — the attacker is not the front-end. **Strike that
   sentence.** Left standing, it authorises a Low that the run's own PoC refutes.
2. **This is the only defect in run-21 that reaches an actual mainnet balance.** ~94.95 USDC on
   `0x86866e01…`, on a contract that is **frozen** (no in-place fix) and **unpausable**
   (`pauser() == address(0)`, verified at block 25577241). M-01's `R = 0` mitigation does not carry
   here — the submission is right about that, and it is more right than it realises.
3. **Still not High.** The nudge leg's extraction is bounded by the pot and costs the attacker a
   genuine `2 × nudgeSize` mint outlay (~1,268 USDS to net ~95 USDC) — a value leak, not theft. The
   caller-victim leg (full surplus, silent) is the larger loss but does depend on a
   third-party-recipient integration nobody has demonstrated. **Medium, firmly, by two routes.**

> **Replace the ground.** Medium is held on **magnitude and attacker outlay**, not on operational
> reachability. State both legs: (i) attacker-as-caller nudge double-dip — permissionless, no
> integration required, bounded by the pot; (ii) caller-victim surplus theft — larger, silent,
> conditional on a third-party-recipient integration. Keep the RE-RATE-to-High trigger for (ii);
> delete the drop-to-Low offer.

**Ranking note for the triager:** on evidence *and* on present reachability, M-02 is the run's
highest-priority item. Frozen + deployed + unpausable + reaches a live balance is the worst
combination in this report, and the current write-up buries it under an unanswered question.

### 1.3 M-03 (`b3243f42…`) — Medium. **CONFIRMED (borderline, kept higher). Ground must be strengthened.**

**Does a latent trap with no currently-reachable path earn Medium?** On the ground as written —
*"a future deployment action plus a non-forwarding orchestrator"* — it is genuinely borderline
against Low, and I considered a downgrade seriously. Three things hold it up, and only the third is
in the submission:

1. **The instances already exist.** `DeployMainnetUniboostCutover.s.sol:478` deployed **three
   mainnet stakers** (EYE/SCX/FLX) from this file under phStaging story-071. This is not a
   hypothetical future deployment — the vulnerable code is **already on mainnet**, three times.
2. **The arming action is a scheduled step, not a hypothesis.** `setMigrator` is the entry point of
   the migration API these contracts exist to serve. `migrator == address(0)` today is *pre-launch
   state*, not a design bound. Calling it is the expected next operational move, and reach-path 1
   (an EOA or multisig wired as migrator) is **unclosable from the migrator side by construction** —
   no capture-and-forward patch anywhere can defend it.
3. **The root cause is carried as a High elsewhere in this project's own ledger** (`1c222d5485…`,
   fix-pending). Filing the residual source-tree instance at Low would let a `fixed` flip on the
   High orphan it into the QA bundle — precisely the outcome the do-not-collapse register exists to
   prevent.

Under rule 6 (genuinely borderline ⇒ keep the higher severity and flag for human triage): **Medium
stands.** Impact is a user's accrued reward misrouted with a `Claimed(user, …)` event affirming
payment — a value leak, not theft (funds land on a protocol-controlled orchestrator), which is why
it does not reach High and why `SOURCE-VERIFIED` without its own PoC is acceptable here.

> **Replace the ground.** Not *"a future deployment hazard"* but *"three mainnet instances already
> deployed from this template, one expected `setMigrator` call from arming, with one reach-path no
> migrator-side control can close."* This also resolves the R-6 tension the current wording creates:
> the finding is not being held down by non-deployment, and it should not read as if it could be.

> ⚠ **Unpaid verification obligation — this is the severity pivot.** *"The three new mainnet stakers
> currently have `migrator == address(0)`"* is **inferred from script source** (`DeployMainnetUniboostCutover`
> never calls `setMigrator`), **not read from mainnet.** I checked the phStaging tree independently:
> the only `setMigrator` call sites target the *stable-staker* family, so the inference is plausible.
> But it is the single fact separating Medium from actively-reachable, and it points in the
> unsafe direction if wrong. **Owed next run (or now, it is three `cast call`s):
> `migrator()` on all three Uniboost-cutover stakers.** Any non-zero result that is not a
> capture-and-forward migrator re-rates this immediately.

---

## 2. Per-finding disposition

### New findings

| Label | Fingerprint | Classified | Audit | Note |
|---|---|---|---|---|
| M-01 | `7a1718e9…` | medium | **CONFIRMED** | Ground re-ordered — §1.1 |
| M-02 | `c847207d…` | medium | **CONFIRMED** | Ground **replaced** — §1.2. Highest-priority item in the run |
| M-03 | `b3243f42…` | medium | **CONFIRMED** (borderline, kept higher) | Ground strengthened + mainnet read owed — §1.3 |
| L-01 | `d0bb0539…` | low | **CONFIRMED** | §3.1 |
| L-02 | `7af123b5…` | low | **CONFIRMED** | §3.2 |
| L-03 | `afa52000…` | low | **CONFIRMED** — deploy-time conformance gap, recoverable via the timeout hatch, no value lost. Law-3 footgun correctly surfaced rather than suppressed |
| L-04 | `75305ec0…` | low | **CONFIRMED** — and the anti-double-count reasoning is exemplary: the value consequence sits on the reopened H-01 lineage, so an independent Medium here would inflate one defect into two |
| L-05 | `3a5fcb33…` | low | **CONFIRMED** — conditional on a source staker settling to `msg.sender` on `batchMigrate`; `:733` uses `_safePayTo(account, …)` and is clean. Explicit escalation trigger beats a speculative Medium |
| Q-01 | `fb3fd4ba…` | qa | **CONFIRMED** — fail-closed, trusted boundary. The `notSuppressedBecause` note is right: an array returned by a contract is not user input |
| Q-02 | `cf882d8f…` | qa | **CONFIRMED** — cosmetic; retained value is as a tripwire against future misdiagnosis |
| F-21-01 | `1ad1434c…` | low | **CONFIRMED** — the missing guardrail for M-03's hazard; Low is right precisely because M-03 carries the impact |
| F-21-02 | `ffdb3413…` | qa | **CONFIRMED** — three-branch/two-branch claim; distinct fix from L-02, do-not-collapse honoured |
| F-21-03 | `6e37fdb6…` | qa | **CONFIRMED** — escrow-branch disclosure gap |
| F-21-04 | `de7f81c5…` | low | **CONFIRMED** — normative spec partially stale; Low over QA justified because downstream suppressions depend on it |
| F-21-05 | `3835e88a…` | low | **CONFIRMED** — meta-load-bearing on the audit's own suppression machinery. The circularity bar is correctly applied |
| F-21-06 | `130363a9…` | qa | **CONFIRMED** — and the embedded ⚠ *"must NEVER be used to discount a severity"* warning is the right guard. Note it is contradicted by `mainnet-verification-ECON-001.md` §7 fact 5 (§1.1) |

### Still-open carryovers (no new label — agreed)

| Fingerprint | Ledger | Classified | Audit |
|---|---|---|---|
| `a62fe01a…` | M-02 | medium unchanged | **CONFIRMED.** Attacker fully controls the precondition (lists the duplicate), so the bound is **magnitude** (the pot), not reachability — which is what keeps it Medium rather than High. Pure relocation, correctly not re-filed |
| `58bd104c…` | M-03 | medium unchanged | **CONFIRMED.** Inter-user value transfer via operator slice ordering; correctly *not* filed as a regression (run-20 already minted the incomplete-fix entry). ⚠ The recorded `openGap` — `NFTStakerPriceScaledMigrateReady.sol` not re-read for the tail-recompute line — is a real unpaid clone-drift watch and must be settled next run |
| `d37ab4bb…` | L-03 + Q-05 | low unchanged | **CONFIRMED** — no demonstrated value consumer; clone-coverage extension beats minting low-value fingerprints |
| `e35388bf…` | L-02 | low unchanged | **CONFIRMED** — self-DoS only. The note that `submitted` is not a disposal status and is treated as `open` is correct and important |
| `a7dffb34…` | F-20-07 | low unchanged | **CONFIRMED** — re-derived at HEAD, two artifacts, correctly not collapsed with L-04 |

### Non-security items — all **CONFIRMED** as carrying no severity

`CLASS-21-025` (superseded patched-PoC tripwire), `CLASS-21-026` (Medusa vacuous harness — the
hard rule *"absence of evidence is not proof of safety"* is correctly stated and must not be
softened), `CLASS-21-027` (Halmos truncation = zero weight in both directions; transcription
harnesses are corroborating-only), `CLASS-21-028` (fork-drift parity watch — held today, and the
watch has already paid out once as M-02). Assigning severities here would be inflation; withholding
them from the report would be recall loss. Both avoided.

### Parked — **parking AGREED**

`MR-21-001` (`invariant_fotFloor` BROKEN, 95.0e18 delivered vs 100.0e18 declared) and `MR-21-002`
(caller-supplied `rewardTokens` call surface). Three tiers declined to close MR-21-001 in either
direction; assigning a severity here would settle by fiat a question they deliberately left open,
and parking is a *visible* channel under Law 1 — not a silent drop. The three `doNotDo` guards are
correct, in particular **do not suppress under the fee-on-transfer known-invalid rule**: the FoT
token is the delivery vehicle, and the defect (a guarantee documented as a floor on *delivery* but
enforced *pre-transfer*) is token-class independent. The `promotes` argument names the one fact that
would settle it upward — a non-FoT route to the same gap. That is the right shape for a parked item.

---

## 3. The two Lows named in the brief

### 3.1 L-01 (`d0bb0539…`) — mispointed tripwire, batch-wide blast radius. **Low CONFIRMED.**

I pushed on the strongest upgrade argument: the tripwire is an **exact** bound, the blast radius is
**executed** (`migrateIn(0,3)` reverts, `parkedUserCount() == 3` — three users stranded for one
anomalous position), per-user slicing does not route around it, and a plain ERC20 donation to the
migrator is **permissionless**. If a donation could trip it, this is unprivileged availability
griefing of a live migration = Medium.

**It cannot.** `captured` is a **balance delta measured around the `depositFor` call**. A donation
landing *before* the call moves both endpoints and cancels; only an inflow arriving *inside* the
call could break the bound, and phUSD is a standard ERC20 with no transfer hook. There is no way to
time an external transfer into another transaction's execution window. The econ tier's refutation
is **sound and I independently re-derived it**. Low is correct, the recorded ceiling
("rises to Medium the moment any attacker-reachable inflow path into `depositFor` is demonstrated")
is exactly the right trigger, and the merge of both directions of one bound into one finding
correctly avoids double-counting.

### 3.2 L-02 (`7af123b5…`) — `totalUnforwarded` desync, INV-2 BROKEN, double brick. **Low CONFIRMED.**

Two executed counterexamples and a **permanent** double brick (`rescueERC20` reverts Panic 0x11,
`claimForwarded` reverts, a donation of `totalUnforwarded - 1` does not un-brick it) with no
administrative fallback. That is a severe *consequence*. But both counterexamples require a
**non-standard reward token** — move-and-return-`false`, or sender-side fee-on-transfer — and the
project's reward token is phUSD: standard, revert-on-failure, no fee.

C4 lists weird ERC-20s and fee-on-transfer tokens as known-invalid. The classifier's handling is
exactly right: it does **not** suppress under that rule (the unguarded subtraction is a real defect
with a one-line correct fix), and it does **not** file it as a weird-token-support request. **Low is
correct and is if anything generous**; escalate only if the reward token is ever changed. The
do-not-collapse with `F-21-02` is right — arithmetic clamp and SafeERC20 adoption are different
fixes and applying one leaves the other's gap open.

---

## 4. Convention calls

### 4.1 Expired-closure reopens carry no `M-nn` label — **AGREED, with one dispute**

`CLASS-21-022` (`858e9e80…`, value-blind nudge gate) and `CLASS-21-023` (`521c20ad…`, MEV nudge
race), both `medium-at-HEAD`, both filed as ledger-reopen proposals outside the `M-nn` sequence per
run-20 R-2/D-29.

**Agreed.** These are ledger-status consequences, not new defects; both mechanics are already
carried by live findings, and numbering them would present six Mediums where there are three new
ones. They are not hidden — they appear in the severity distribution at `medium`, and each has its
own submission file. The `expiredClosureFraming` (*"NOT A REGRESSION — no patch was reverted; there
is no intact patch to restore"*) is correctly applied to both and matches the expired-closure-vs-
regression distinction. The disclosure obligations are properly discharged: the prior `fixed`
disposition is quoted in full, the falsifying fact is named (caller-supplied `rewardTokens` removes
the owner-pinning the closure rested on), and the owner-signed 2026-06-09 L-05 triage is disclosed
as affected without being overridden.

> **⚠ DISPUTE — missing re-arm triggers.** Both are held at `medium-at-HEAD` on **exactly the same
> shape of ground as M-01**: a configuration relation (*pot < cost of `nudgeSize` mints*) that
> `L-04` establishes is **asserted in NatSpec and enforced nowhere**. `858e9e80…` was a **High at
> run-12**, when that relation was inverted. M-01 got an explicit, quantified RE-RATE trigger list;
> these two got **none** — I grepped both submissions for `re-rate` / `re-arm` / `escalat` /
> `trigger` and found nothing. A finding whose severity is held down by an unenforced funding
> practice **must** ship the arming condition with it, or the next reader inherits a Medium with no
> way to know when it stops being one.
>
> **Add to both:** *RE-RATE TO HIGH if the nudge pot on either live instance exceeds the cost of
> `nudgeSize` mints (today: 94.95 USDC pot vs ~634 USDS to qualify — the relation holds by funding
> practice only, see L-04).* Label unchanged; the omission is the defect.

### 4.2 Fix-pending High (`1c222d5485…`) retains its ledger severity, not re-rated — **AGREED**

Correct on every axis. CLAUDE.md is explicit that `fix-pending` is human-set and never auto-closed,
and that a fix which merely stops tripping the scanner is not a verified fix. Position A
(PoC-inverted ⇒ propose `fixed`) and position B (`:756` unchanged, four residual reach-paths, fresh
mainnet instances deployed from the file ⇒ keep) are both recorded rather than one being quietly
adopted, sanitizer and classifier concur on B, and the decision is routed to a human via `/ledger`.
The `⚠ FIX-PENDING STILL LIVE (possible incomplete fix)` framing is the right one — an incomplete
fix reads as done and is ranked second only to a regression. The hard constraint (*must NOT be
reported as "the defect is gone"*) and the M-03 linkage (so a later `fixed` flip cannot orphan the
residual hazard) together close the trap correctly. Recording the migrator-side work as
**LIKELY-FIXED-FOR-COVERED-PATHS** on the entry is the honest middle and I endorse it verbatim.

---

## 5. Actions

**Must fix before the report ships**

1. **M-02** — strike *"if the operator can state that every caller is a first-party front-end naming
   EOA recipients, this drops honestly to Low."* It is refuted by the run's own
   `test_Exploit_NudgeSnapshotPaidTwice`. Replace the "why not High" section with the two-leg
   magnitude/outlay argument (§1.2). Re-rank M-02 as the run's lead item.
2. **`mainnet-verification-ECON-001.md` §7 fact 5** — strike or relabel *"BatchNFTMinterMultiToken
   is not deployed"* as context. As a listed reason for holding off High it is R-6-forbidden and it
   contradicts `M-01.md:149-150`.
3. **Both expired-closure reopens** — add the quantified RE-RATE trigger (§4.1).

**Should fix**

4. **M-01** — lead with attacker-cannot-arm + no-inflow-route; demote the balance census to
   corroboration (§1.1).
5. **M-03** — reframe on *three already-deployed mainnet instances, one expected `setMigrator` call
   from arming, one migrator-unclosable reach-path* (§1.3).
6. **M-03 verification** — read `migrator()` on the three Uniboost-cutover stakers from mainnet.
   Three `cast call`s; it is the fact the severity pivots on and it is currently inferred.

**Ledger hygiene**

7. Mark ledger `L-01` `9135cf79…` **superseded-by `c847207d…`** rather than carrying it as an
   independent open Low (§1.2).
8. Settle the recorded `openGap` on `NFTStakerPriceScaledMigrateReady.sol` (tail-recompute clone
   drift) next run.

---

## 6. Standard of the run

Every High-adjacent claim in this run is PoC-backed or explicitly marked `SOURCE-VERIFIED` with the
absence of a PoC stated rather than papered over. Refutations are recorded as loudly as
confirmations (Medusa vacuity, Halmos truncation, the L-01 donation-griefing refutation, the
MR-21-002 reentrancy refutation). The anti-double-counting discipline — L-04 deferring its value
consequence to the reopened lineage, F-21-02 kept separate from L-02 on fix-distinctness, the two
reopens declining labels — is the strongest I have reviewed on this project. The three grounds I am
sending back are argument-quality defects on correct labels, not severity errors, and one of them
(M-02) would have licensed a wrong downgrade later.
