# Severity Audit — phoenix-nft-staking run-20

**Agent:** severity-auditor (independent second opinion)
**Input:** `reports/phoenix-nft-staking/20/classified-findings.json` (24 classified: 1 High, 7 Medium, 9 Low, 5 QA, + 2 reopen candidates at Medium)
**HEAD:** `0d1a0b2187bb980f1ac6c6b54d0b01e6410a2e54`
**Date:** 2026-07-20

## Method

Every disputed call below was re-derived from `lib/phoenix-nft-staking` source at HEAD, not from the
classifier's summary. Source facts I read and verified independently are marked **[verified]**. I did not
re-run PoCs; where a claim rests only on a PoC result I say so and treat it as reported evidence.

Applied asymmetry: overstatement costs reviewer time; understatement can leave a live exploit. Downgrades
are affirmatively justified or not made. Where a downgrade and an as-is call were both defensible, I kept
the higher severity and flagged it (rule 6).

---

## Verdict summary

| | Count |
|---|---|
| **Confirmed as classified** | **23 of 24** |
| **Disputed (severity)** | **1** — CLASS-016 / DEDUP-20-019, Low → **Medium** (understatement) |
| Confirmed with a recorded reservation | 1 — CLASS-007 (weakest Medium in the run) |
| Factual corrections to a confirmed finding's reasoning | 1 — CLASS-003 |
| Presentation/count objections (not severity) | 2 — reopen-candidate labelling; CLASS-004 ↔ CLASS-005 |
| Settled calls re-read, no factual error found | 2 — CLASS-002 (D-22), CLASS-022 (D-19) |

**Net direction of my disagreement: upward.** I found no finding in this run whose severity I judge
inflated enough to downgrade. That is an unusual result and I state it plainly rather than manufacturing a
downgrade for balance.

---

## 1. CLASS-001 / DEDUP-20-009 — **HIGH CONFIRMED**

`NFTStakerDepletion.depositFor` pays the migrator, not the user.

### Source facts I verified myself

- **[verified]** `src/NFTStakerDepletion.sol:756` — `pending = _safePay(pending);` inside the
  `info.amount > 0` branch of `depositFor`. `:593-594` — `_safePay(uint256)` is
  `return _safePayTo(msg.sender, amount);`. `depositFor` is `onlyMigrator`, so `msg.sender` is **always**
  the orchestrator and **never** the user. `:757` then emits `Claimed(user, pending)` regardless.
- **[verified]** `src/NFTStakerPriceScaledMigrateReady.sol:887` — the same call site in copy #4 is
  `_safePayTo(user, pending)`, and its NatSpec at `:870-872` says the `_safePay` form
  *"would route an existing staker's earned phUSD to"* the migrator. The bug is named in the codebase.
- **[verified]** `src/NFTStakerDepletion.sol:733` — `_exitPosition` already uses `_safePayTo(account, …)`
  correctly, so the correct primitive exists in the same file. This is a one-call-site defect.
- **[verified]** `src/NFTStakerMigrator.sol` is 112 lines and contains exactly two non-constructor
  functions — `initiateMigration` and `migrate`. **No `rescueERC20`, no `rescueERC1155`, no `receive`, no
  `fallback`.** Nothing can move an ERC20 out of it.
- **[verified]** `src/InPlaceNFTStakerMigrator.sol:268` — `rescueERC20` is **unconditional**
  (`token.safeTransfer(to, amount)`; the parked floor guards only the ERC1155 at `:281`). The recovery
  asymmetry the classification rests on is real, in both directions.
- **[verified]** `NFTStakerMigrator`'s own NatSpec `:9-11` — *"Orchestrates a zero-user-action migration
  between two `NFTStakerDepletion` instances."* The buggy contract is the **documented target type** of the
  no-rescue migrator. This is the fact that most strongly resists a Medium reading.
- **[verified]** `NFTStakerMigrator.migrate` `:81-111` calls `oldStaker.batchMigrate` then
  `newStaker.depositFor` in one transaction, so the misroute lands and the transaction succeeds.

### Applying C4 High

> *"Assets can be stolen / **lost** / compromised directly or via a valid attack path without hypotheticals."*

- **Is matured-but-unpaid yield an asset?** Yes. `_exitPosition`/`depositFor` settle a balance that has
  already accrued and been moved from `rewardBudget` into `committedDebt` — it is a realized protocol
  liability owed to a named user, not speculative future emission. C4's *"lost"* limb does not require a
  thief. The project's own convention (unmatured/in-motion yield caps at Medium; settled, pending, owed
  yield does not) is applied consistently here.
- **Is the attack path hypothetical?** No. There is no attacker at all — it is the documented operational
  path, executed by the owner, with a deterministic outcome. The classifier is right that absence of an
  attacker *raises* likelihood rather than lowering it; a loss finding does not need an adversary.
- **Is "not currently deployed" severity-bounding?** **No — it is a deployment-status fact.** C4 rates the
  code as written. Discounting severity for non-deployment would make every pre-deployment self-audit
  finding Low, which inverts the entire point of auditing before deployment. Ground (d) is correctly
  rejected.
- **Is "solvency invariant intact" a mitigant?** No. Protocol solvency is not the asset at issue; the
  contract stays solvent precisely *because* it paid someone — the wrong someone.

### The honest bound the report must carry

The one place the classification overstates is scope, and it should be tightened in the writeup even though
it does not change the label:

> *"Every migrated user who already held a position on the target pool loses their entire accrued balance."*

The `if (info.amount > 0)` guard at `:753` means the misroute fires **only** for a user who already holds a
non-zero position **on the target staker**. On a migration into a freshly-deployed target every user has
`pending == 0` and nothing is lost. The realistic loss population is users who hold stake in **both** pools
(permissionless `stake()` on the target makes that ordinary, not exotic). The PoC's 82,191.78 phUSD is a
lab magnitude, not a mainnet one. Say this in the finding; it is the difference between a credible High and
one a reader can pick apart.

**Verdict: HIGH (plausible), agreement with the classifier.** The Medium counter-reading remains
defensible and the `humanMustPick` flag should survive — but per the symmetry rule, when both are
defensible the higher label stands. The named condition under which Medium becomes correct (operator
confirms `NFTStakerMigrator` is dead code) is the right condition and has not been met.

**What would change my mind:** an operator statement that `NFTStakerMigrator` will never be deployed and
every migration runs through `InPlaceNFTStakerMigrator`; or a demonstration that `depositFor` is
unreachable with `info.amount > 0` on any realistic target. Neither exists today.

---

## 2. The five D-10 escalations

D-10 escalated on a tie-break, not on conviction. I re-derived each on the merits. **All five survive** —
four cleanly, one with a reservation about the *stated* reason.

### CLASS-006 / DEDUP-20-011 — Low → Medium. **CONFIRMED, cleanest of the five.**

Textbook C4 Medium: *"protocol function/availability impacted"*. An unprivileged, zero-cost, indefinitely
repeatable permissionless `stake()` blocks `finalizeAndReset` (which requires `totalStaked == 0`), which is
the only transition back to `Active`, which `depositFor` requires — so **one stranger blocks migration for
every parked user**. The second leg is independently Medium-shaped: the contract *accepts* a stake it will
never pay on (`accRewardPerShare` frozen), silently costing an uninvolved user their yield.

The "a complete pause remedy exists" counter does not reduce it: the remedy is an ecosystem-wide halt
(CLASS-014), and a remedy whose cost is a whole-ecosystem outage is not evidence the defect is minor. The
free code remedy (`require(poolState == PoolState.Active)` on `stake`) existing and not being applied is
the finding.

### CLASS-005 / DEDUP-20-017 — Low → Medium. **CONFIRMED.**

C4 Medium *"value leak with stated assumptions"*: value moves between users out of a shared `rewardBudget`,
1000 bps measured, decided entirely by an operator-assigned slice the victim cannot see or influence.
Solvency is untouched but pro-rata emission — the protocol's stated function — is not delivered. The
project has rated this class Medium consistently (phlimbo-ea Linear-Depletion; run-18 M-01), so a Low here
would be an inconsistency, not a calibration.

### CLASS-008 / DEDUP-20-005 — Low → Medium. **CONFIRMED.**

- **[verified]** `src/BatchNFTMinter.sol` step 6 — `paymentToken.forceApprove(address(nftMinter),
  type(uint256).max)` before the loop, revoked at step 8. The allowance is unbounded *within* the loop, so
  an under-funded batch draws on the contract's standing balance rather than reverting as the NatSpec
  claims.

Permissionless, no privilege, no timing window, PoC-proven: a C4 Medium on the standalone header ground —
a value leak from the contract's own balance with stated assumptions and a cross-repo external
requirement. Structurally, it is also a **second route to the same pot that survives a sweep-bound fix of
CLASS-002** — the sweep bound sits at `:381-383` and the allowance bound at `:360`, so patching either
provably does not touch the other. That independence is recorded as a **do-not-collapse constraint on
remediation**, not as a severity ground.

I considered **High** and rejected it: the extracted asset is protocol-directed incentive funds, never user
principal, and the contract's own NatSpec (`:51-61`) explicitly disclaims custody of balances sent to it.
Medium is the honest ceiling.

### CLASS-014 / DEDUP-20-012 — QA → Low. **CONFIRMED.** Trivial step, correct: it has a concrete
availability consequence (ecosystem-wide halt) and a concrete safety consequence (circuit breaker
disabled + broken `Pauser.register` invariant), which is more than informational. No downstream difference —
both QA and Low land in the QA bundle.

### CLASS-007 / DEDUP-20-003 — Low → Medium. **CONFIRMED, with a reservation.**

The label is right; **the stated reason for it is not.** The justification says, in substance, *"filing it
Low next to its Medium twin risks the operator-facing remedy being skipped."* That is report-management,
not severity, and it is exactly the reasoning that produces inflation. It should not appear in the report
as the ground for the Medium.

The valid ground is narrower and sufficient: repointing the dispatcher — a documented, expected maintenance
action the deploy script itself flags as *"ASSUMED … the operator MUST confirm"*, performed in a **different
repository** with no signal there that it matters — kills the nudge mechanism outright
(`BatchMint__RewardTokenIsPaymentToken` on every legitimate claim), and **two of the three real dispatchers
satisfy the unsafe condition today**. That is an availability impact on a protocol function arising from an
expected operation, with a real external requirement — the literal C4 Medium shape. Law 3 is satisfied: no
malicious-owner vector, and the surprise test is answered yes.

This is nonetheless the weakest Medium in the run, and the double-count risk with CLASS-002 (whose value
impact it partly re-states) is real. If a human downgrades exactly one Medium in this run, it should be
this one. **What would change my mind:** evidence that the two unsafe dispatchers are not repoint
candidates, or an operator-facing guard landing in the deploy script.

---

## 3. The two ⚠ EXPIRED-CLOSURE reopen candidates — **BOTH MEDIUM CONFIRMED**

### CLASS-009 (ledger H-01, `858e9e80…`) and CLASS-010 (ledger M-01, `521c20ad…`)

**Not Low.** The prompt's framing — *"the profitability precondition is unmet on mainnet today"* — is a
present-state fact, and I apply it the same way I applied "not deployed" to CLASS-001: it bounds present
exposure, not the code. Two source facts make the arming condition structural rather than accidental:

- **[verified]** `src/BatchNFTMinter.sol:44-49` — *"**Permissionless top-up.** Anyone can seed the batch
  incentive with any ERC20 simply by sending it here. **No owner transaction is involved.**"* The leg-2
  premise that closed ledger H-01 (*over-funded pot ⇒ owner-driven ⇒ Law-3 invalid*) fails on its own
  predicate. That is not a re-litigation of Law 3; it is the observation that the thing Law 3 was applied
  to is not an owner action.
- **[verified]** the gate is `qualifies = _nudgeSize != 0 && count >= _nudgeSize` and the payout is the
  entire snapshotted balance (`_payRewards` transfers `snapshot[i]` in full). **A count compared to a
  count, paying out a value.** Nothing in the contract relates payout to payment, and `nudgeSize` is the
  owner's only lever. The NatSpec's *"the pot is **by construction** a fraction of the cost of the
  `nudgeSize` mints"* is **backed by no code** — I read the whole file to check.

So the safety margin is empirical (~6×, reported) and maintained only by bot competition against an
unbounded, time-accumulating third-party stream. Low would assert a bound that does not exist.

**Not High.** No principal theft in any of the 11 replay tests; the asset is an incentive pot the contract
explicitly disclaims custody of; D-22's live reads show zero present exposure and no historical loss via
this path; and CLASS-010 is a classic MEV shape (front-running a public incentive) rather than direct asset
compromise. The prompt's "unbounded pot + one permissionless top-up arms it" argument is the strongest
High-ward pull, and I weighed it: it establishes that the *arming* is not bounded, but the *loss* is still
capped at what has been voluntarily funded into a contract whose NatSpec says "do not use this address as
custody". Medium.

**Both `humanMustPick` flags must survive.** I endorse the classifier's framing that the one disposition
that is wrong under *either* reading is leaving these `fixed` — that status asserts the residual was
eliminated when it was merely dismissed on a premise that is now false.

### ⚠ Presentation objection (not severity)

CLASS-009/010 are labelled **M-08 / M-09** in the classified set. They mint no new defect — the mechanic is
already filed live as CLASS-002, CLASS-003 and CLASS-019, as `noDoubleCounting` states. Publishing them as
M-08/M-09 alongside the seven new Mediums makes the report read as **9 Mediums for ~7 distinct defects**,
which is count inflation even though every individual label is correct. They should be presented as
**ledger reopen proposals**, in their own section, not in the M-nn sequence.

---

## 4. The declined escalations — checking for the opposite error

This is where I disagree with the classifier.

### CLASS-016 / DEDUP-20-019 — **DISPUTED. Low → MEDIUM** (or merge into CLASS-005 at Medium)

A watching user `userMigrate`s and re-stakes ahead of the operator's batch: **1666 bps** measured, the
largest edge in the migration cluster — *larger* than CLASS-005's 1000 bps, which was escalated to Medium.
The declared distinguisher is agency: *"any user can protect themselves with two transactions."*

That distinction does not survive contact with the measurements. In the reported PoC results the **victim
is the same and the loss is the same**: Bob receives **36.986e18** in `test_ECON_A` (CLASS-005, Medium) and
**36.986e18** in `test_ECON_H` (CLASS-016, Low). Identical victim, identical harm, identical shared budget;
the only difference is who captures the surplus — the operator's slice-1 assignee, or a bot. C4 severity is
assessed on impact, and the impact is the same or worse.

The agency argument describes a mitigation available to a *hypothetical attentive* user, not a bound on the
harm to the *actual* victim. Every MEV finding in DeFi could be argued away as "the victim could have been
faster". And the root cause is a single fact — **emissions run at full rate during a staggered migration
window while most users are parked** — with one remedy (`setTargetAPY(0)` between `finalizeAndReset` and
the last slice) that closes both. Two exploitation shapes of one defect should not straddle a severity
boundary.

**Proposed disposition, in preference order:**
1. **Merge** CLASS-005 and CLASS-016 into one Medium — *"emissions run during a staggered migration window;
   time-in-pool is set by slice assignment or by self-advancing, not by entitlement"* — with two actors and
   two measured magnitudes (1000 bps operator-assigned, 1666 bps self-advance). This is the honest shape and
   it does not inflate the Medium count.
2. Failing that, **raise CLASS-016 to Medium** standalone.

I do **not** accept leaving it Low. `userMigrate` being permissionless is indeed a load-bearing safety
property that must not be removed — but that is an argument about the *remedy*, not the severity.

**What would change my mind:** a demonstration that the passive user's loss in `test_ECON_H` is materially
smaller than in `test_ECON_A`, or that the operator lag is bounded to a window where the edge is immaterial.
The reported numbers say the opposite.

### CLASS-003 / DEDUP-20-001 — **Medium CONFIRMED**, but its bound is stated wrongly

Three agents, two PoC suites, two broken Tier-3 invariants and an independent Medusa reproduction converge
here — but converging evidence proves the **mechanic**, not the **impact**, and the impact is what C4 rates.
Working the arithmetic from the reported figures: with pre-loop snapshot `B`, `k` duplicate entries and the
batch's own donation `D`, the payout is `k·B` and succeeds while `k·B ≤ B + D`. An honest single claim
already takes `B` by design. So the **incremental** harm is up to `D` — *the caller recapturing their own
batch's donation*, defeating donate-forward — not the theft of a third party's pot. That is a real leak of
protocol-directed incentive funds and a defeat of a spec-load-bearing mechanic (Medium), but it is not
theft of anyone's principal (not High). The classifier's Medium is right.

**Factual correction to its reasoning.** The justification leans on
`test_AtObservedShape_DuplicateStillFailsClosed` — *"the currently observed mainnet shape still fails
closed"* — as the thing keeping it off High. That bound is weaker than presented: the shape in question is
`k·B ≤ B + D`, and **`D` scales with `count`, which the attacker chooses** (the reported bite point is
`count = 400`, well inside the ~426-users-per-30M-gas-block ceiling this run measured elsewhere). A
precondition the attacker can create for themselves does not cap severity. The load-bearing bound is the
one I derive above — incremental extraction is capped by the caller's *own* donation — and that is what the
finding should say. Same label, sounder footing; if the report ships the weaker bound, the first reviewer to
notice `count` is caller-supplied will read the Medium as under-argued.

### CLASS-011 / DEDUP-20-024 — Low **CONFIRMED**. The absence of a mitigation is not itself a loss, and the
fix is one owner transaction. Correctly filed at Low rather than QA because it is live on mainnet and it
falsifies an escape-hatch premise a prior suppression rested on. Its `operatorActionItem.urgent` flag is
the right channel — this is the only item in the run touching contracts live right now, and it must not
disappear into the QA bundle.

### CLASS-013 / DEDUP-20-010 — Low **CONFIRMED.** Escalating it would double-count CLASS-001, which is where
the loss lives. **Rider:** if a human downgrades CLASS-001 to Medium, this entry becomes the *sole* carrier
of the permanence fact and must be re-weighed at that time, not left at Low by inertia.

### CLASS-018 / DEDUP-20-015 — Low **CONFIRMED**, ceiling must survive. A total interaction DoS is
Medium-shaped, but no value is at risk at any point, principal always escapes (`emergencyWithdraw` /
`userMigrate` never call `pull()`), and there are two independent owner-side un-brick routes. The recorded
`severityCeiling: medium` is the right instrument and must reach the report — if the operator judges a
half-executed migration with custody already moved to be an availability *event*, Medium is defensible.

I checked the adjacent stranding worry and it does **not** apply: `NFTStakerMigrator.migrate` is atomic
(`batchMigrate` and every `depositFor` in one transaction), so a reverting `depositFor` rolls the ERC1155
pull back rather than stranding it in the no-rescue migrator. Worth recording so nobody re-derives it.

### CLASS-024 / DEDUP-20-016 — QA **CONFIRMED.** Read-only reentrancy with no reader is a latent hazard, not
an impact. `nonReentrant` blocks every mutating re-entry and no on-chain consumer of the inflated views
exists. The free CEI reorder is correct hardening; QA is correct rating.

---

## 5. Settled calls — re-read, not re-litigated

Per instruction I re-read both looking only for factual error in the evidence they rest on.

**CLASS-002 (Medium, D-22).** No factual error found. I independently confirmed the mechanic in source:
step 10 reads `remaining = paymentToken.balanceOf(address(this))` and, above `DUST_THRESHOLD`, transfers
**the entire balance** to `msg.sender` — not the caller's unspent budget. D-22's Medium (not High on zero
present exposure, not Low on the un-gated sweep being unchanged and re-armable by one `setBatchMinter` or
any USDC airdrop) is internally consistent and I do not disturb it.

> One argument for the human, flagged rather than pressed, because it points **downward** and so cannot
> cause a Law-1 miss: `BatchNFTMinter.sol:63-70` documents the step-10 sweep as *intended* — *"unused
> budget, dispatcher-side dust, or a third-party donation — is swept back to `msg.sender`"* and *"a griefer
> who pre-deposits payment-token to this contract simply donates to the next caller."* Neither D-22 nor the
> classification weighs this documented-intent reading explicitly. It is a legitimate Medium→Low argument.
> It is also answerable — the NatSpec anticipates an incidental donation, not a continuous dispatcher-fed
> pot that the §4.1 guard makes claimable *only* through the sweep. I am not disputing the Medium; I am
> making sure the strongest counter-argument is visible to whoever triages it.

**CLASS-022 / Q-03 (QA, D-19).** No factual error found. I confirmed the value flow: `_payRewards`
transfers to `recipient`, and both `recipient` and `rewardTokens` are caller-supplied — so the fee accrues
to the token's own sink and there is no path where A's token choice costs an unrelated B. The shrinking-token
leg is a caller self-DoS. The failing `invariant_fotFloor` (delivered 95e18 vs floor 100e18, 11 census hits)
is correctly parked *inside* this entry rather than suppressed — that placement is what keeps a proven
broken invariant from losing its home, and it should not be edited out.

---

## 6. Items for the human, ranked

1. **CLASS-001 High vs Medium** — arbitration flag must survive; my vote is High, with the loss population
   narrowed to users holding a pre-existing position on the target.
2. **CLASS-016 Low → Medium, or merge with CLASS-005** — my one severity dispute. Understatement.
3. **CLASS-004 ledger arbitration** (reopen `b58b172e…` as incomplete fix vs separate Medium) — I take no
   position on the ledger disposition; the Medium label is right either way. But CLASS-004 and CLASS-005 are
   one root cause on two contracts, and the report should present them as such with an explicit
   cross-reference, or a reader counts two Mediums for one defect. The do-not-collapse instruction is
   correct at the *ledger* layer and should not be read as a do-not-cross-reference instruction at the
   *report* layer.
4. **Reopen candidates should not carry M-08/M-09 labels** — present as ledger reopen proposals.
5. **CLASS-007 is the weakest Medium** — if exactly one Medium is downgraded on human review, this is it,
   and its stated escalation ground (report-management) should be replaced with the availability ground.
6. **CLASS-003's bound should be restated** — the attacker chooses `count`, so "fails closed at the observed
   shape" is not the real bound; "incremental extraction is capped by the caller's own donation" is.
7. **CLASS-011 is the only live-mainnet action item** — set a pauser on both instances.
