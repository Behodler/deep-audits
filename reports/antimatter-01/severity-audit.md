# Severity audit — antimatter run-01

**Auditor:** severity-auditor (independent second opinion)
**Date:** 2026-08-18
**Target:** `reports/antimatter-01/` at commit `0bb82d867dba43bc514a508800826f90436c2ee3`, branch `master`
**Posture:** adversarial. Every severity was attacked from below (is it overstated?) and, per the
symmetry rule, from above (is a real Law-1 issue being under-called?).

**Classifier's slate:** 1 High, 6 Medium (M-06 parked), 7 Low, 5 QA.
**This audit's slate:** 1 High, 4 Medium, 9 Low, 5 QA — one downgrade pair, one upgrade, one merge.

---

## 1. Verdicts at a glance

| Label | Claimed | Assessed | Verdict | One-line reason |
|---|---|---|---|---|
| **H-01** | High | **High** | **KEEP** | Real theft of a second, unapproved asset; both preconditions are ordinary and one is mandatory |
| **M-01** | Medium | **Medium** | **KEEP** | Genuine footgun — the fails-open/fails-closed asymmetry is decisive; premise verified in source |
| **M-02** | Medium | **Medium** | **KEEP** (with a required trim) | Unbounded + unaccounted is the reportable core; one profitability claim is overstated |
| **M-03** | Medium | **Medium** | **KEEP** | The protocol's only issuance control is silently off by 2x and misreports its own utilisation |
| **M-04** | Medium | **Low** | **LOWER** | No asset risk, owner-triggered, and its two concrete halves are already L-03 and M-03 |
| **M-05** | Medium | **Low** | **LOWER** | A shared rate limit being consumed first-come-first-served is the control working, not a DoS defect |
| **M-06** | Medium (parked) | **Parked, unlabelled** | **KEEP PARKED** | Correctly handled; the label is provisional and is not treated as verified anywhere |
| **F-01** | Low | **Medium** | **RAISE** | Missing minimum-output on an irreversible burn; a routine owner re-price takes real user capital |
| **L-01** | Low | **Low** | **MERGE** into F-01 | Same line, same root cause, identical one-line fix — over-split |
| L-02, L-03, C-01, C-02, F-02, F-03, Q-01..Q-04 | — | — | **KEEP** | No further under-calls found; see §8 |

Net effect: the Medium band goes from 5 submitted to 4. This is a **re-aiming, not a deflation** —
one Medium is added (F-01) as two are removed, and every downgraded item keeps its safe-configuration
guidance intact (§9).

---

## 2. H-01 — KEEP High

**Claim:** an ERC20 allowance over antimatter is silently a dual-asset authority; the grantee spends
the grantor's stablecoin and keeps the entire ~2x phUSD, sent to an address of the grantee's choosing.

### Independent verification of the mechanic

Re-read at the audited commit, `lib/antimatter/src/Antimatter.sol`:

```solidity
if (from != msg.sender) _spendAllowance(from, msg.sender, amount);   // :214  antimatter ONLY
_burn(from, amount);                                                  // :215
IERC20(stable).safeTransferFrom(from, address(this), stableAmount);   // :222  second asset, no authority read
_phUSD.mint(recipient, amount);                                       // :236  caller-chosen recipient
IERC20(address(_phUSD)).safeTransfer(recipient, mintedForStable);     // :237  caller-chosen recipient
```

`:214` is the only allowance spend in the function. `recipient` is validated against `address(0)`
only (`:203`). Confirmed: no `IERC20(stable).allowance(from, msg.sender)` is read or debited anywhere
in the contract. The finding's description of the defect is exact.

### Attack from below — the four downgrade arguments, each answered

**(a) "The preconditions are not ordinary."** They are. The stablecoin approval to Antimatter is not a
coincidence an attacker waits for — `:222` pulls from `from`, so *no holder can ever annihilate
without it*. It is universal among users of the contract by construction, and a max approval (the
normal pattern for repeat use) makes the exposure the whole balance. The second precondition — a plain
`approve` of antimatter to a third party — is a shipped, documented, unit-tested flow. Neither is
extraordinary; there is no price condition, no timing condition, no flash loan, no owner action, no
third contract. This clears the C4 "no hypotheticals" bar.

Honest narrowing, recorded rather than hidden: the grantee must be adversarial or exploitable. An
antimatter allowance to a *benign* router is not self-executing. But that is true of every allowance-
scope defect, and it does not weaken the High: the whole point is that the victim, having granted what
she believes is authority over asset A, has silently granted authority over asset B. The class —
"an approval for token A also authorises spending token B" — is a settled High.

**(b) "The victim consented by approving Antimatter for the stablecoin."** No. She consented to
*Antimatter* moving her stablecoin in a transaction *she* initiates, which is what the NatSpec at
`:189-192` describes. She did not consent to a third party directing that movement and capturing the
proceeds. ERC20 authority is per token; every wallet, allowance dashboard and revocation tool presents
it that way. There is no interface at which the victim can see or infer that her antimatter grant
carries her USDC with it. Consent to a contract is not consent to an arbitrary caller of that contract.

**(c) "This is user error / counterparty risk (C4 known-invalid)."** No. The known-invalid category is
*user input mistakes and phishing*. Here the victim does exactly what the documentation and the
project's own tests instruct, and the harm is invisible at approval time. A defect that makes the
correct action harmful is a contract defect, not a user mistake.

**(d) "The project's own test asserts this is correct behaviour — so it is intended."**
*Argued, then rejected — and the user's instinct is right.* The strongest form of the defence is:
`test/Annihilation.t.sol:129-141` (`test_thirdPartySpendsAntimatterAllowance`) grants an antimatter
allowance, has the spender call `annihilateFrom` with a distinct `recipient`, and asserts the recipient
receives 120 ether — i.e. the exact exploit is the *asserted expected behaviour* of the shipped suite.
If a behaviour is specified, tested and documented, calling it a vulnerability looks like a
disagreement about product design rather than a finding.

It fails for three independent reasons:
1. **Law 1 is explicit.** Security is paramount and overrides faithfulness to intent; an
   intended-but-exploitable design is reportable, and an unsafe intent is itself flagged.
2. **A test asserts what the *callee* does, never what the *approver* agreed to.** The victim is not a
   party to the test suite. Documenting a behaviour in the callee cannot transfer consent to the
   approver — there is no channel by which the approval UI could carry it.
3. **In-source documentation carries no suppression authority** (standing rule), and here the header
   NatSpec is independently *economically inaccurate* (tracked as F-03), so the intent artefact is not
   even reliable on its own terms. This project has no story and no `storyDir`, so NatSpec is the only
   intent artefact that exists — a weak basis on which to bless a two-asset authority.

**Aggravator not currently priced in (worth one line in H-01, no severity change).** Q-02 notes
`recipient == address(this)` is unguarded. Composed with H-01 this yields a pure-destruction variant:
`annihilateFrom(stable, victim, address(antimatter), amount)` burns the victim's antimatter, consumes
her stablecoin, and strands the entire proceeds on the contract — griefing with no attacker gain, so
not even the "the attacker profits, so he is rational" framing bounds it. Recommend adding as an
impact sentence to H-01.

### Evidence check

`test_H01_amAllowanceDrainsGrantorStablecoinToAttacker` (`Tier2.t.sol:42-64`) asserts
`usdc.allowance(alice, bob) == 0` **before** the call (`:51`), then after the call asserts Alice's
antimatter is 0, Alice's USDC is 0, **Alice's phUSD is 0**, and Bob's phUSD is 200e18. Bob is a
distinct address (`alice = 0xA11`, `bob = 0xB0B`); the only grant to Bob in the setup is
`antimatter.approve(bob, 100 ether)` — grep-verified that no `usdc.approve(…, bob, …)` exists anywhere
in the harness. The invariant replay asserts the zero stablecoin allowance **both before and after**
the exploit (`AntimatterInvariant.t.sol:242`, `:251`), which is the stronger form. The
assertions establish the *claim*, not merely that the code ran. `test_H01_baselineTransferFromTakesOnlyAM`
is a real control: identical setup, plain `transferFrom`, USDC untouched at 100e6 — isolating
`annihilateFrom` as the defect. Two invariants fail on two independent engines
(`invariant_06`, `invariant_07`; Foundry + Medusa), and Halmos property 3b is **REFUTED with a concrete
counterexample** — a refutation, not a timeout. Nothing here rests on a pass or a timeout.

**Verdict: KEEP High. Confidence: high.** This is the strongest finding in the run and the one that
must not be softened.

---

## 3. M-01 — KEEP Medium (top of band)

**Claim:** an understated registered `decimals` fails open, arming a permissionless free mint.

### Premise verified independently

`PhusdStableMinter.registerStablecoin` (`lib/antimatter/lib/phUSD-stable-minter/src/PhusdStableMinter.sol:111-131`)
takes `uint8 decimals` as a caller-supplied argument and writes it to the config with **zero**
cross-check against `IERC20Metadata(stablecoin).decimals()`. There is no validation at registration,
and none in `Antimatter.toStableAmount` (`:250`). The premise holds; the finding is not built on a
misreading.

### The obvious-misconfig challenge (⇒ C4-invalid) versus the footgun reading (⇒ valid)

This is the whole question, and the **fails-open/fails-closed asymmetry is decisive** — the classifier
identified the right load-bearing evidence.

The C4 exclusion is for a *reckless admin mistake whose harm is obvious*. What makes a wrong `decimals`
non-obvious is that **both contracts make the identical error, so it cancels**: `toStableAmount` scales
the pull down by 1e12 and `calculateMintAmount` scales the phUSD up by the same 1e12. The residue check
at `:230` passes (the stablecoin genuinely left), the non-zero check at `:233` passes (phUSD genuinely
arrived), the exactness guard at `:256` passes. There is no revert, no anomalous event, no on-chain
signal of any kind. Meanwhile the *same class of error in the opposite direction* produces a loud,
immediate revert. An operator who has seen the parameter reject a wrong value has positive evidence
that it is self-checking — and is then silently unprotected in the one direction that matters.

That is textbook surprise, and surprise ⇒ footgun ⇒ in scope at honest severity (Law 3).

**One correction to the report's own argument, which slightly overstates the asymmetry.** The
"fails closed" direction is a *balance-dependent* revert, not a structural guard: with `decimals`
overstated the contract tries to pull an oversized amount and `safeTransferFrom` reverts **because the
user lacks the balance**. A holder with a large enough balance would not revert; they would simply
over-pay. The asymmetry survives — over-paying is safe from the protocol's side, under-paying is not —
but the report should say "fails closed *for any user without an outsized balance*" rather than
implying a guard. Related: the control test `test_M_decimalsOverstatedFailsClosed`
(`Tier2.t.sol:114-125`) uses a bare `vm.expectRevert()` rather than the exact error, which falls short
of the project's "demonstrate the exact revert error" standard. Both are report-quality fixes, not
severity moves.

### Attack from below and above

*Down to Low?* No. The consequence is not dust or cosmetic: while armed, any antimatter holder mints
~2x phUSD for ~1e-12 of the intended stablecoin, permissionlessly, deterministically, repeatable to the
entire outstanding antimatter supply, with no signal that would ever end the condition.

*Up to High?* No — and correctly not. The path requires an external requirement (a registration
misconfiguration) that no observed deployment carries. C4 Medium is precisely "a hypothetical attack
path with stated assumptions and external requirements". The report's re-weigh trigger is correctly
specified and load-bearing: **escalate to High on evidence that any live or staged registration carries
a `decimals` differing from `IERC20Metadata(stable).decimals()`.**

*Filed against the wrong repo?* The root cause is arguably in `PhusdStableMinter`, a nested submodule.
The report handles this correctly: Antimatter acts on the value, doubles the blast radius by adding an
uncollateralised second leg, and can defend itself in one `staticcall`. Filing it here is right.

**Verdict: KEEP Medium, top of band. Confidence: high.**

---

## 4. M-02 — KEEP Medium, with one overstatement that must be trimmed

**Claim:** the antimatter leg mints phUSD against zero collateral; unbounded, unaccounted, permanent.

This is the hardest call in the run. Both directions argued in full.

### The case for LOW

- It is **intended design**, implemented exactly as specified. The token's entire purpose is to be
  exercisable into phUSD; objecting to that is objecting to the product, not reporting a bug.
- **No atomic attack, no specific victim.** The actor holds antimatter and parts with real stablecoin.
  The harm is diffuse, realised only through a market sale, and only if the market prices phUSD above
  the break-even.
- **Emission is owner-gated** — `mint` at `:179` is `onlyApprovedMinters`. There is no permissionless
  drain today.
- **Not yet wired** into `phoenix-phase-2-staging`, so emission policy is undecided on-chain.
- phUSD has **no redemption path**, so no insolvency check is ever tripped; "backing ratio" is a
  modelling construct here rather than a claimable right.

### The case for HIGH

- **Unbounded uncollateralised issuance** with no cap, no per-period budget, no tie to realised yield,
  and — decisively — **no on-chain measurement of the exposure at all**. `Antimatter.totalSupply()` *is*
  the outstanding unbacked-phUSD liability, and nothing in the system reads, reports or bounds it.
- The liability is **permanent** — annihilation is one-way.
- Any bug in **any** approved minter converts one-for-one into unbacked phUSD, because `:179` has no
  ceiling. The blast radius of an unrelated defect is unbounded.

### Landing it: Medium

High fails on the C4 test as written: there is no attack path, no victim, no theft, and the one gate
that would make it self-serve (emission) is owner-controlled. Calling a policy exposure "High" is
exactly the overstatement that gets a report rejected.

Low fails too, and this is where I disagree with the downgrade instinct most firmly. The reportable
core is **not** "the protocol issues unbacked phUSD" — that is a design decision and I do not report it
as a defect. The reportable core is that the design ships with **no bound and no instrument**: no cap,
no budget, no liability view. That is a missing control, it is unbounded, it is permanent, and it lands
on parties who never consented. An unmeasured unbounded liability is not a state-handling nit.

I also confirm the standing Phoenix rule was correctly ruled out. "Externally-derived yield
over-payment is opportunity cost, not loss" governs reward budgets funded by yield on protocol-owned
capital. This is different in kind: phUSD is minted at `:236` against **zero incoming value**. That is
seigniorage against phUSD holders, not the spending of a yield budget. The distinction is real and the
report draws it correctly.

**Verdict: KEEP Medium. Confidence: medium** (this is a judgement call and is flagged as one).

### Required trim — a genuine overstatement

The report states the annihilation loop is *"profitable for any phUSD price p > $0.50"*. **This
double-counts, and should be corrected before submission.** The step "an actor receives N antimatter as
a staking reward" treats the antimatter as free. If antimatter has any market price, arbitrage drives
it toward `(2p − 1)` and the loop's excess profit is competed away; the actor's gain is then the reward
itself, which is emission policy, not a leak. The claim is only true *for a recipient of free emission*,
which is a narrower and less dramatic statement.

This does not change the severity — the dilution is real regardless of who captures it, and the
missing cap/instrument is the finding — but the profitability sentence as written is the kind of
inflated-impact claim the pipeline rejects. **Recommend: restate as "profitable to a recipient of
free emission whenever p > 1/(1 + exchangeRate/1e18); competitive antimatter pricing transfers that
profit to the emission recipient without reducing the dilution."**

Presentation note: lead with *unbounded and unaccounted*, not with *dilution*. As currently framed the
finding reads as challenging the product premise, which invites an "accepted by design" triage that
would also bury the missing-cap recommendation.

### Evidence check

`invariant_04` **passes** and is cited — correctly and explicitly — as a *quantification* only
(the uncollateralised leg is exactly 1:1 with antimatter burned, no rounding drift), never as
reassurance. The classification metadata states in terms that no severity rests on an invariant PASS,
and I confirm none does. `test_M02_controlOrdinaryMintingIsBackingNeutral`
(`M02_UnbackedMintDilution.t.sol:88-98`) is a real control: five ordinary mints, backing ratio asserted
`== 1e18` each time, isolating the antimatter leg as the sole source. Real `PhusdStableMinter` and real
`FlaxToken` are used, not mocks.

---

## 5. M-03 — KEEP Medium

**Claim:** `maxMintPerDay` governs only the stable leg, so a cap of X permits 2X.

Verified in source. `PhusdStableMinter.mint:215-223` charges `mintedToday` with
`calculateMintAmount(stablecoin, amount)` — the stable leg only. `Antimatter:236` mints the antimatter
leg on Antimatter's own FlaxToken authorisation, which the counter never sees. The 2x at
`exchangeRate == 1e18` is arithmetic, and the general divisor `(1 + exchangeRate/1e18)` is correct.

*Down to Low?* The Low argument — no asset loss, no attacker-specific gain — is honest but mis-frames
the impact class. The function impaired **is a safety control**, and C4 Medium explicitly covers "the
function of the protocol could be impacted". Two features push it over the line rather than under it:

1. The counter **actively misleads**: it reads 100% utilised at exactly the moment it has permitted
   double. A control that misreports its own utilisation manufactures false confidence precisely when
   it matters — worse than an absent control.
2. It is the **sole quantitative bound** on the uncollateralised issuance of M-02. Its being off by 2x
   is not an isolated nit.

*Up to High?* No. No theft, no victim, no attacker gain beyond what the design already grants.

**One external requirement the report should state more prominently.** `registerStablecoin` initialises
`maxMintPerDay: 0`, and `mint` treats `0` as *no limit* (`:214-215`, "disabled when maxMintPerDay == 0").
So the cap is **off by default** and must be explicitly set by `setMaxMintPerDay`. The finding is
correctly conditioned on "the operator is relying on the rail at all", but the default-off fact belongs
in the External Requirement line, because it means no live deployment is exposed until an operator
opts in.

*Duplicate of M-02?* No. M-02 is "the leg has no backing"; M-03 is "the leg escapes the counter".
Different root causes, different mitigations. Keeping both is correct.

### Evidence check

`invariant_09` and `invariant_10` **fail** on Foundry *and* Medusa; Medusa produced a single-call
counterexample pinning the ratio at exactly 2.000x; `test_counterexample_dailyCapDoubled` is a
deterministic non-fuzz replay that reproduces. Critically — I verified this myself, since a mocked cap
would have hollowed out the finding — the harness constructs the **real** `PhusdStableMinter`
(`Tier2.t.sol:27`, `PocBase.sol:34`, `AntimatterInvariant.t.sol:37`, `MedusaTarget.sol:38`), so the cap
logic under test is production code, not a reimplementation. Only the yield strategy is mocked, which
is immaterial to this finding. The anti-vacuity record (121 swallowed inner reverts dominated by
`"Daily mint limit exceeded"`) confirms the cap was live and enforcing.

**Verdict: KEEP Medium. Confidence: high.**

---

## 6. M-04 — LOWER to Low

**Claim:** `exchangeRate` re-prices only the stable leg — a hard 1x issuance floor, a near-zero-rate
brick, and a silent re-pricing of `maxMintPerDay`.

The mechanic is correct and well proved. The **severity** is inflated, and the reason is
decomposition: once you separate M-04's three consequences, each is already reported elsewhere or is
below the Medium bar.

- **(a) The hard 1x floor.** This is M-02 restated in rate coordinates. "The antimatter leg is unbacked
  and unscaled" *is* M-02. That no rate makes annihilation backing-neutral is a corollary, not a
  second finding.
- **(b) The near-zero-rate brick.** Already filed as **L-03**
  (`RoundToZeroStableLegBricksAnnihilation`, `qa-report.md:157`), at Low, with the same witness and the
  same remediation. M-04 is re-reporting a Low as part of a Medium.
- **(c) The rate change re-prices `maxMintPerDay`.** This is an addendum to M-03 — same control, same
  operator, and M-03 already carries the `(1 + exchangeRate/1e18)` divisor in its safe-config guidance.

What remains that is genuinely M-04's own is the *expectation* defect: an operator reaching for
`exchangeRate` as an issuance throttle finds it cannot reach parity. That is real and worth reporting —
but it is a documentation/design footgun with **no asset risk, no attacker, and an owner action
required**, whose entire downstream harm is the dilution already priced in M-02. C4 Medium's function
limb is a stretch when the "impaired function" is a lever's fitness for a purpose the code never
claimed for it.

**I record this as a deliberate downgrade, affirmatively justified, not a tidy-up**: the justification
is over-split reporting (b duplicates L-03, a duplicates M-02, c duplicates M-03), not "the count looks
high". I also record the counter-argument honestly: "the protocol's issuance throttle does not
throttle" is a defensible Medium reading, and a triager who disagrees with the decomposition should
keep it at Medium. Because it is a genuine judgement call, **flag for human triage** — but note the
symmetry rule's borderline-keep-higher instruction is aimed at Law-1 exploit risk, and there is none
here: no attacker, no assets, no permissionless path.

**Preservation requirement (non-negotiable).** Downgrading must not lose the operator guidance. The
Low entry must retain, verbatim: treat `exchangeRate` as an amplitude control on the backed leg only;
keep it at or below `1e18`; recompute `maxMintPerDay` as `intendedIssuance / (1 + exchangeRate/1e18)`
on every rate change; `setStablecoinEnabled(false)` is the only lever that actually stops dilution.

**Verdict: LOWER to Low. Confidence: medium. Flagged for human triage.**

---

## 7. M-05 — LOWER to Low

**Claim:** the annihilator extracts 2 phUSD per unit of shared daily budget and DoSes ordinary minters.

The user asked the right question: *is "ordinary minting is DoS'd by someone who profits from doing it"
a real availability impact or a theoretical one?* Having attacked it, my answer is: **the availability
half is not a defect at all, and the part that is real is M-03.**

1. **The daily cap is a rationing device. Being consumed is it working.** Any ordinary depositor with
   enough capital exhausts `maxMintPerDay` for a stablecoin with **no antimatter whatsoever**. First-
   come-first-served exhaustion of a rate limit is the designed behaviour of a rate limit, not a denial
   of service. The finding does not distinguish the annihilator's exhaustion from a whale's.
2. **The attacker deploys full capital.** To consume the window the annihilator must supply stablecoin
   equal to the entire budget (`:222` pulls it) *and* hold matching antimatter. This is not a
   zero-cost grief; it is a large capital commitment.
3. **Two external requirements, both currently unmet.** `maxMintPerDay` defaults to `0` at registration
   and `0` means *no limit* — so with default config there is no shared budget and no DoS. And
   antimatter is not yet wired into staging, so emission volume is undecided.
4. **Self-resolving within 24h**, by the finding's own account.
5. **The genuinely novel content is the 2x extraction ratio — which is M-03.** Strip that out and what
   remains is "a rate limit can be consumed", plus the window-timing observation.

The window-reset semantics (the window restarts on the first mint after expiry, `mint:216-219`, rather
than on a fixed epoch) are a real and correctly-identified defect — the annihilator, or indeed any
first-mover, controls when each window opens. That is a legitimate Low with a clean fix
(`block.timestamp / 1 days`), and it must survive the downgrade.

The classifier itself recorded **confidence: medium** on M-05 and wrote that "its practical severity
depends on emission volumes that are not yet decided". That hedge is doing the work a lower band should
be doing.

**Recommended disposition:** file as **Low**, retitled around its real content — *"the shared daily
budget's window restarts on first-mint-after-expiry, and the annihilation path consumes it at 2x the
rate of the ordinary on-ramp"* — and cross-reference M-03 for the asymmetry. Do **not** delete the
on-ramp contention observation; it is a legitimate operational note for anyone sizing the cap.

**Verdict: LOWER to Low. Confidence: medium-high.** Of the two downgrades this is the better-founded.

---

## 8. M-06 — confirmed parked, and the label is not being treated as verified

Checked at every layer, and the handling is correct:

- `findings/classified.json`: `submittable: false`, `status: PARKED-MANUAL-REVIEW`,
  `verificationStatus: "UNVERIFIED - severity label is PROVISIONAL and carries NO verification weight"`,
  `confidence: medium`.
- **No `submissions/M-06.md` exists** — verified by directory listing. The submissions index states
  plainly that the Medium label was carried forward as the highest input severity (`ECON-004` medium
  over `CODE-006` low) *for triage ordering only*, and that no downstream stage may read it as a
  verification result.
- The park itself is correct, but **the stated reason needs one refinement**. The park is justified as
  "diff-only against a stale nested pin". I checked: `lib/phUSD-stable-minter` is at `d6ed1156`, which
  **equals `origin/HEAD`** — the minter pin is *current*, not stale. What genuinely cannot be
  adjudicated here is the **deployed yield strategy's** crediting behaviour (vault-RM), which is not
  in this tree at all, plus the question of which minter build is actually deployed on chain. The park
  stands on that narrower and more accurate ground; the "stale pin" phrasing should be corrected so a
  future run does not dismiss the park as resolved once it re-checks the pin and finds it current.
- It is parked in a **visible** channel (`manual-review.json` + the ledger as `am1m6`) with the reason
  attached — Law 1's recall requirement, satisfied.
- **Nothing actionable is gated behind the park**: the mitigation (assert `mintedForStable` against
  `minter.calculateMintAmount`) is independently carried by L-01, F-01 and M-04's recommendation list.

**Verdict: KEEP PARKED. The Medium label is provisional and is correctly quarantined.** No change.

---

## 9. Under-called findings — one raise

Every Low, Centralization and QA item was re-tested against the three C4 Medium limbs (assets at risk /
function or availability impaired / value leak). One carries.

### F-01 — RAISE to Medium, absorbing L-01

**`3aac91383dcb6060` — "no minimum-output guard on an already-irreversible burn"**, currently Low in the
spec-conformance channel.

The softening is a single word. The finding describes the exposure as *"caller-borne, **bounded** by the
rate divergence"*. **That bound is zero**, and the source confirms it:

- `annihilateFrom` takes no `minOut` and no expected-output parameter (`:201`); `:233` accepts *any*
  non-zero `mintedForStable`.
- The caller irrevocably parts with real stablecoin: `:222` pulls it, `:227` deposits it into the yield
  strategy, and the protocol keeps it. The burn at `:215` has already happened.
- `PhusdStableMinter.updateExchangeRate` (`PhusdStableMinter.sol:138-143`) is a **bare `onlyOwner`
  write with no lower bound and no timelock**, effective the next block. I verified this directly.

So an ordinary, non-malicious owner re-pricing that lands between a user's submission and execution
takes real user capital: at `rate = 0.10e18` the user deposits 100 USDC and receives 10 phUSD for it
(the antimatter leg is `amount`, unaffected). Down toward `1 wei` the stablecoin deposit is effectively
confiscated **and the transaction still succeeds**. This is the standard missing-slippage-protection
finding on a one-way user-initiated conversion — C4 Medium: assets at risk, stated assumptions, an
external requirement.

It is explicitly **not** a malicious-owner claim, so Law 3 is untouched: the victim is the user, the
owner action is routine, and the surprise is entirely on the user's side. It is also distinct from
M-04 (which is about the lever's *fitness as a throttle*) — F-01 is about the *user's* exposure to a
rate change in flight.

**Merge L-01 into it.** L-01 and F-01 are the two directions of one defect at `:232-233`: the phUSD leg
is never compared against `minter.calculateMintAmount(stable, stableAmount)`. L-01 = delta too large
(mid-call inbound swept to a caller-chosen recipient); F-01 = delta too small (an irreversible burn
settles against near-nothing). Both propose the *identical* one-line fix. Filing them separately
over-splits and buries the Medium half inside the QA bundle. Merged framing: **"the phUSD leg is
checked for existence, never for correctness."** Q-01(a) — the absence of a phUSD-side preview — belongs
inside that entry as the enabler: with no preview, an integrator could not compute a `minOut` even if
one existed.

L-01 *on its own* is correctly Low: the only mid-call injection window is the owner-registered
stablecoin's own transfer hook, and its control test confirms the `:220` snapshot correctly excludes
pre-existing donations. It does not reach Medium alone.

### Everything else — KEEP

| Label | Verdict | Reason |
|---|---|---|
| L-02 (setter mutual lock) | KEEP Low | Deadlock is real, but only phUSD *migration* is welded; the minter can still be swapped for one on the same phUSD. **Softening flag:** the text says "no funds at risk" and then "every outstanding antimatter balance would be lost" one sentence later — reword, do not reband |
| L-03 (near-zero rate bricks) | KEEP Low | Liveness only, owner-reversible in one tx. Now the primary home for M-04's brick; add the cross-reference |
| C-01 (`revokeAllMintPrivileges` unobservable) | KEEP Low | Pushed hard on "core function silently unavailable". Fails because the failure is **atomic** — `:236` reverts and the stable leg unwinds with it, so no half-state and no stranded value — and recovery is one `setMinter` per contract. The reportable core is the unobservability |
| C-02 (no local kill switch) | KEEP, but bump ledger severity `qa` → `low` | The "arguably deliberate" hedge is weaker than admitted now that H-01 exists in this same contract and its own owner cannot stop it. Stays below Medium only because the minter's pauser and `setStablecoinEnabled(false)` are genuine halt levers |
| F-02 (trip-wire is a denylist) | KEEP Low | Coverage defect, no asset impact of its own |
| F-03 (NatSpec economically false) | KEEP Low, **do not merge into M-02** | Correct as filed: if M-02 is triaged accepted-by-design, the doc defect must not vanish with it. Standing rule — falsely-exhaustive in-source docs raise severity, never lower it |
| Q-01 | KEEP QA | Cite part (a) inside the merged F-01 Medium as the enabler |
| Q-02 (`recipient == address(this)`) | KEEP QA | Self-inflicted, owner-recoverable, next snapshot excludes it. But see the H-01 aggravator in §2 — as a *composed* vector it belongs in H-01's impact, not as its own finding |
| Q-03, Q-04 | KEEP QA | No impact path |

---

## 10. Evidence-integrity audit

The brief asked for three specific failure modes. All three were checked and **none is present**.

**(a) Does any finding rest on an invariant PASS?** No. Five invariants pass (`01`–`05`, `08`); the only
one cited in a submission is `invariant_04`, in M-02, and it is explicitly cited as a *quantification*
of the 1:1 ratio, with the report stating in terms that no severity rests on it. The classification
metadata carries the same statement. The four **failures** (`06`, `07`, `09`, `10`) are the load-bearing
artifacts and they fail on **two independent engines**. The anti-vacuity discipline is unusually good:
an `afterInvariant` abort-on-empty tripwire, a Medusa `vacuityTripwire()` equivalent, a handler revert
profile, and — notably — a *discarded* first Medusa run recorded explicitly so its vacuous "28 passed"
can never be mistaken for corroboration.

**(b) Is any Halmos TIMEOUT treated as a proof?** No. Every marker across all 29 `halmos-*.txt`
artifacts was enumerated and matches `symbolic-results.md` test-for-test: **7 PASS**, **3
REFUTED-that-support-findings** (p3b ×2 → H-01; p4-nonzero → the brick), **4 intended-to-fail harness
tripwires** (3 non-vacuity probes + the symbolic-EXP probe), **11 TIMEOUT**, **1 ERROR** (cvc5-int not
installed). The
symbolic report states up front that `[TIMEOUT]` "**Proves nothing**" and `[ERROR]` means "the property
was never tested", repeats "carry zero weight" at property 4, and lists them again under "What was NOT
covered". The two results that **support** findings are both **REFUTED-with-counterexample** (p3b → H-01;
p4d → L-03), which is the strong direction. The `PROVED` results (p1, p2, p3a, p4a) are cited only as
*scoping* — e.g. "the arithmetic is correct given a correct `decimals`, which is why the unvalidated
value carries the whole risk" — never as all-clears. This is exactly right.

The p3b refutation is on a fully **concrete** `d=6, rate=1e18` domain, so it is unaffected by the
symbolic-EXP over-approximation that the report itself flags — H-01's symbolic support is sound. The
p4-nonzero witness (`amount = 524288000000000000, rate = 1`) is the exact value replayed at
`M04_ExchangeRateOneSided.t.sol:93-94`, so the symbolic and concrete evidence are the same fact. The
report also correctly warns that the consolidated suite's "18 failed" headline conflates
FAIL / TIMEOUT / ERROR — that breakdown reproduces exactly against `halmos-full-suite.txt`.

**(c) Do the PoC assertions establish the claims, or merely that code ran?** Checked line by line for
H-01, M-01, M-02, M-03. In each case the assertions pin the *claimed quantity* (Alice's phUSD == 0 and
Bob's == 200e18; spent == 1e8 while minted == 200e18; issued == 2000 ether against a 1000 ether cap;
backing ratio == 1e18 in the control), and each has a real control test that isolates the defect. The
sibling-project failure mode — a passing PoC that appeared to support a Medium later refuted — is not
reproduced here, because in every case the assertion is on the *outcome quantity*, not on
"it didn't revert".

**(d) Independent re-execution.** All 26 audit tests were re-run from a clean checkout during this
audit and all pass. The workspace `src/`, `test/mocks/` and `lib/phUSD-stable-minter/src` were diffed
against `lib/antimatter` and are **byte-identical**, so the PoCs exercise the audited code and not a
drifted copy.

**Mock exposure — checked because it was the highest-leverage way to break M-03.** The harness
constructs the **real** `PhusdStableMinter`, the **real** `FlaxToken` and the **real** `Antimatter`
(`Tier2.t.sol:27`, `Tier2b.t.sol:32`, `PocBase.sol:34`, `AntimatterInvariant.t.sol:37`,
`MedusaTarget.sol:38`, `AntimatterSymbolic.t.sol:28`). There is **no mock minter anywhere in the tree**.
Three project-owned mocks (`MockStable`, `MockYieldStrategy`, `ReentrantStable`) are identical in
`lib/` and `workspace/`, so nothing audit-authored is passed off as project code. Nested pins were
checked for the stale-pin trap and are **current**: `lib/phUSD-stable-minter` @ `d6ed1156` and
`lib/flax-token-v2` @ `f5300117` both equal their `origin/HEAD`, working trees clean.

Four places where a finding touches mock behaviour, each assessed:

1. **M-02's collateral term** is `GuardedYieldStrategy.totalPrincipal` (audit-authored), not the real
   vault-RM strategy. Directionally **conservative** — a real strategy books ≥ principal, so the mock
   cannot manufacture the dilution — but the exact `_backingRatio()` figure is mock-derived. The
   finding should say the *curve shape* is proved and the *absolute figure* is harness-relative.
2. **Invariants 09/10** assert against a hand-written **mirror** of the minter's rolling window
   (`AntimatterHandler.sol:106-119`), not the minter's own storage. M-03 does **not** rest on the
   mirror — the deterministic replay `test_counterexample_dailyCapDoubled` reads the real minter's
   `mintedToday` (`AntimatterInvariant.t.sol:267-271`) — but M-03 currently leads with the fuzz
   invariants. **Re-order the evidence** so the replay is the load-bearing artifact and the mirror-
   dependent invariants are corroboration.
3. **Symbolic properties 3b and 4d** run against `SymMocks` phUSD/strategy, so the real FlaxToken
   authorisation logic is outside the symbolic domain. Both are independently reproduced with the real
   FlaxToken in Tier2 / the invariant harness / the PoCs, so neither finding depends on them.
4. **L-01's `InjectingStable`** is a deliberately hostile audit-authored token, which is exactly why
   L-01 is Low: it is conditional on an owner registering an exotic stablecoin, not a permissionless
   vector. Correctly banded.

**Three evidence-quality defects worth fixing (none changes a severity):**
1. `test_M_decimalsOverstatedFailsClosed` uses a bare `vm.expectRevert()`, not the exact error — below
   the project's stated PoC standard.
2. That same test's "fails closed" is balance-dependent (§3). Traced precisely: the revert is
   `ERC20InsufficientBalance(alice, 1e9, 1e20)` from `MockStable.transferFrom` — the caller cannot
   afford the 1e12x-inflated pull. **No guard is doing the failing.** A sufficiently-funded user is
   silently over-charged 1e12x instead of reverted. M-01 must say "the over-pull exceeds any ordinary
   user's balance", not "the safe direction fails closed".
3. M-03/M-05 should state that `maxMintPerDay` defaults to `0` = unlimited at registration
   (`PhusdStableMinter.sol:125`), so neither is armed under default config.

**Provenance discipline:** every PoC is correctly and repeatedly declared AUDIT-AUTHORED, with the
verification that no `test/audit/**` path exists in `lib/antimatter` at `0bb82d8`. No audit-authored
test is cited as project coverage anywhere. This satisfies the standing rule.

---

## 11. Law 2 and known-issues status

Both are handled honestly and need no correction.

- **Law 2 is UNRESOLVABLE-PENDING-MAPPING**, stated identically in every submission: no story exists
  for `antimatter` anywhere in the product-owner tree (verified by name glob *and* content grep),
  `storyDir` is `null`, and no `[story-NNN]` tag appears on any of the six commits. Crucially, the
  reports say intent is **ungraded, not passed** — they do not claim a story was checked, and they do
  not report "the story is external/unavailable" as a finding. A human must add the mapping line.
- **No known-issues document exists at `0bb82d8`**, and the reports state that **zero** findings were
  suppressed on known-issue grounds at any stage. Given the standing "unfalsifiable KI cache" problems
  on sibling projects, declining to suppress anything is the correct posture.

---

## 12. Actions required before submission

1. **H-01** — add the Q-02 composition as an impact sentence (burn-and-strand griefing variant). No
   severity change.
2. **M-01** — qualify "fails closed" as balance-dependent; tighten the control test to the exact revert.
3. **M-02** — **trim the "profitable for any p > $0.50" claim** (§4); re-lead on *unbounded and
   unaccounted* rather than on dilution.
4. **M-03** — add "the cap defaults to `0`, which means *no limit*" to the External Requirement line.
5. **M-04 → Low.** Move to the QA bundle, retaining the safe-config guidance verbatim; cross-reference
   L-03 (brick) and M-03 (divisor). **Flagged for human triage** as a genuine judgement call.
6. **M-05 → Low.** Retitle around the window-reset defect and the 2x consumption rate; cross-reference
   M-03. Keep the on-ramp contention note.
7. **F-01 → Medium**, absorbing **L-01**, with Q-01(a) cited as the enabler. Needs a submission file
   and a PoC demonstrating a rate change landing between submission and execution.
8. **C-02** — bump ledger severity `qa` → `low`.
9. **L-02** — reword the self-contradicting "no funds at risk" sentence.
10. **M-06** — remains parked and unlabelled, but **correct the park rationale**: the nested minter pin
    is current, not stale; the unadjudicable element is the deployed yield strategy's crediting.
11. **M-03 evidence order** — lead with `test_counterexample_dailyCapDoubled` (reads the real minter's
    `mintedToday`), demote the mirror-dependent invariants 09/10 to corroboration.
12. **M-02** — state that the backing *curve* is proved but the absolute `_backingRatio()` figure is
    derived from an audit-authored strategy mock (directionally conservative).

---

## 13. Summary judgement

The classification is **substantially sound and unusually disciplined on evidence** — the separation of
PROVED / REFUTED / TIMEOUT, the refusal to lean on invariant passes, the recorded discarded-Medusa run,
and the provenance labelling are all better than typical. I found **no fabricated or unsupported
finding**, and **no finding resting on a pass, a timeout, or a PoC that merely runs**.

The corrections are three: **two Mediums are over-split restatements of findings already filed
elsewhere** (M-04 ⊂ L-03 + M-02 + M-03; M-05 ⊂ M-03 + a Low), **one real Medium is buried at Low in the
faithfulness channel** (F-01, on the strength of a single softening word), and **one impact claim is
inflated** (M-02's profitability threshold). The High is correct and should not be softened; the
parked M-06 is handled exactly as it should be.

---

## Correction note appended 2026-08-18 (review pass) — body above unchanged

**This note is appended, not merged.** Everything above is the reviewer's dated record of what was
actually said and must be read as written; nothing in the body has been edited.

**Superseded:** the M-06 park rationale referenced above — that the claim rests on a *stale
`phUSD-stable-minter` pin* — is factually wrong. antimatter pins `lib/phUSD-stable-minter` at
`d6ed1156`, and that commit **is** the minter's remote `master` tip, so the **minter pin is current**.

**Corrected rationale:** the stale layer is one level deeper —
`lib/phUSD-stable-minter/lib/vault` is pinned at `043ff2c` while vault's remote `master` is `0110ce4`,
**11 commits ahead**, including stories 043/044/048/049, which introduced `deposit()` returning
`creditedPrincipal`. What cannot be adjudicated at commit `0bb82d8` is therefore **which
yield-strategy / vault version is actually deployed**, since the finding depends on the deployed
strategy's `deposit()` return behaviour — not on the minter's version.

**Re-check instruction:** read the **deployed** yield strategy (resolved from chain). **Do not
re-check the `phUSD-stable-minter` pin** — it is already current and would wrongly read as the park
being resolved.

The corrected rationale is carried in: `findings/medium/M-06-*.json`, `findings/classified.json`,
`findings/sanitized.json`, `findings/deduplicated.json`, `tier2/econ-findings.json`,
`manual-review.json`, `submissions/README.md`, `submissions/qa-report.md`,
`submissions/spec-conformance.md`, and the `am1m6` entry in `reports/ledgers/antimatter.json`.

**Scope of this note:** rationale only. No severity, label, fingerprint, status or verdict recorded
above is altered by it — including this document's own rulings, which stand as issued.
