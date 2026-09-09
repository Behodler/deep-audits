# Independent severity audit — stable-staker run-16

- **Agent:** severity-auditor (second opinion) · **Date:** 2026-08-31
- **Under audit:** `reports/stable-staker/16/classified.md`, `submissions/H-01.md`, `submissions/M-01.md`, `submissions/qa-report.md`
- **Method:** every load-bearing source claim was re-verified directly against `lib/stable-staker@fa06de5` and the nested pin `lib/antimatter@a5570ce` that the repo actually compiles against. Nothing below is inherited from the classifier's text.
- **Ledger writes: 0.** All rulings are proposals for a human at `/ledger`.

## 0. Verdict table

| Label | Assigned | My assessment | Agree | Confidence |
|---|---|---|---|---|
| **H-01** | HIGH (Plausible) | **HIGH** | yes | **medium-high** (genuinely borderline; kept high per Symmetry Rule) |
| **M-01** | MEDIUM | **MEDIUM** | yes | high |
| **M-02** (`ss9l1`, Low→Medium) | MEDIUM | **LOW** | **NO — disagree** | medium |
| **L-06** (`86fcf00e`, QA→Low) | LOW | **LOW** | yes | high |
| L-01 | LOW | LOW | yes | high |
| L-04 | LOW | LOW | yes | medium-high |
| L-07 | LOW | LOW | yes | high |
| Q-04 | QA | QA | yes | high |

**One severity disagreement (M-02, downgrade). Zero understatements found. Three report-accuracy defects that must be fixed before submission (§1.5, §2.3, §5.1).**

---

## 1. H-01 — empty-pool emission cliff. HIGH survives.

### 1.1 Independently verified, not taken on trust

| Claim | Verified at | Result |
|---|---|---|
| Emission is time-denominated, `totalStaked` absent from the numerator | `StableStakerV2.sol:817-824` | **CONFIRMED.** `:822 reward = elapsed * pool.antimatterPerSecond`; `totalStaked` appears only at `:824` as the index divisor. |
| 1 wei entry suffices | `:333 require(credited > 0, ...)` | **CONFIRMED.** |
| `annihilate` is permissionless | `Antimatter.sol:250-253` | **CONFIRMED.** `external whenNotPaused nonReentrant`, no owner/role gate anywhere in the body. |
| The antimatter half is minted unbacked | `Antimatter.sol:294 _phUSD.mint(recipient, amount)` | **CONFIRMED**, and it sits *after* the backed half is separately computed as `mintedForStable`. Two distinct mints; only one has collateral behind it. |
| Nothing automatically zeroes `antimatterPerSecond` | grep of all 5 occurrences | **CONFIRMED for automatic paths** — see §1.5 for an overstatement in how this is worded. |

The mechanism is real, the PoC's shape matches the source, and the reachability is genuine (organic emptying via real calls, no cheatcodes).

### 1.2 Challenge (a) — "the victims hold a different token; is that C4 High?"

This is the strongest Medium argument and **the classifier's rebuttal to it is incomplete.** I found a fact neither `classified.md` §1 nor `H-01.md` engages:

> **phUSD has no redemption path.** `PhusdStableMinter` exposes `mint` only — there is no `redeem`, `burn`, or `withdraw` in its entire external surface. A phUSD holder cannot present phUSD and take backing out.

That matters, because the classifier's rebuttal #3 asserts *"it is a transfer of value to the attacker, i.e. it is stolen, not merely leaked."* With no redemption path, no holder is denied anything on-chain. The harm reaches holders only through the market price of phUSD, and the attacker's *profit* is realized only by selling into phUSD depth. The submission concedes this in one clause (`assumptions: "phUSD trades near par"`) and then argues past it.

**Why High nonetheless survives.** The protocol-side loss does not depend on the market at all. `annihilate` increases the protocol's outstanding phUSD liability by `2·amount` while increasing backing by `amount`. The collateralization ratio falls **at the moment of mint**, unconditionally. For a stablecoin protocol, minting unbacked liability *is* compromise of the asset base — that is the definition of undercollateralization, not a downstream consequence of it. Market depth governs how much the attacker extracts, not whether the protocol lost.

Two further points decide it:
- **Net-new, not redistribution.** The PoC's third test shows the preceding empty window emitted exactly zero (`accAntimatterPerShare` byte-identical). This is the single most important piece of evidence in the run and it holds: the emission would not have existed. This is categorically outside memory `externally-derived-yield-opportunity-cost-not-loss`, which covers misallocation of yield that *was* going to be paid.
- **Cost basis.** ~$900k of protocol liability against 1e-6 USD of attacker capital. There is no plausible reading of that ratio that is not an asset-compromise event.

**Ruling: not "assets stolen" in the narrow sense, but "assets compromised" in the plain C4 sense. High.** But this is a genuinely close call, and under the Symmetry Rule a borderline High is kept and flagged, never quietly lowered. **Flagged for human triage.**

### 1.3 Challenge (b) — does the ~900k stablecoin front gate the attack?

The classifier's reasoning ("liquidity, not capital at risk — it returns as backed phUSD in the same call") is **correct as far as it goes** and I verified the mechanics: `safeTransferFrom` in, `minter.mint`, `safeTransfer(recipient, mintedForStable)` out, all inside one `annihilate`. Nothing is exposed across blocks.

**But I found a throttle the classifier and the report both missed.** `PhusdStableMinter.mint` enforces a rolling 24h per-stablecoin cap:

```solidity
require(config.mintedToday + phUSDAmount <= config.maxMintPerDay, "Daily mint limit exceeded");
```

A breach reverts the whole `annihilate`. If `maxMintPerDay` is configured on the live deployment, a single 900k realization **reverts**, and the attacker must drip the annihilation across days.

This does **not** change severity: the AM is already minted and held (the theft is complete at `claim`), the cap throttles realization rather than blocking it, and it is `0`-disabled by default. But it falsifies the report's "two transactions" framing for the realization leg, and the PoC did not test against production config. **See §5.1 — required correction, not a downgrade.**

### 1.4 Challenge (c) — is armed-and-empty a real operational state?

**Yes, and this is the finding's strongest leg.** Verified: `antimatterPerSecond` is written at exactly one place (`:217`, inside the owner-only `antimatterPerDay`) and read at `:750`/`:822`. No lifecycle transition — `initiateMigration`, `finalizeAndReset`, full withdrawal, `emergencyWithdraw` — touches it. Organic emptying is the terminal state of every pool that is ever used, and the PoC reaches it with honest calls only.

The 90-day window is illustrative, not required; the capture scales linearly with any window and the entry cost stays 1 wei. A one-week window on the same rate is still ~70,000 AM for 1 wei. **Not contrived.**

### 1.5 Challenge (d) — Law 3, and one overstatement

**Not an obvious misconfiguration.** The intuition runs the *opposite* way: `:817` literally makes an empty pool accrue nothing, so an operator reading the code is reassured, not warned. That a zero-user pool carries a live dilution liability is exactly the kind of consequence a competent, non-malicious owner would be surprised by. And the exploit actor is unprivileged — the owner's contribution is a pure omission. **Law 3 does not apply; the C4 "reckless admin" filter does not apply. Classifier is right.**

**Overstatement to correct.** `H-01.md` states, in bold: *"**Nothing in the codebase ever zeroes `antimatterPerSecond`.**"* This is false as written — `antimatterPerDay(token, 0)` at `:214` does exactly that, and the submission's own mitigation #3 recommends calling it. Per memory `absence-of-remedy-claims-need-enumeration`, rewrite as: *"No **automatic** path zeroes `antimatterPerSecond`; disarming requires a manual `antimatterPerDay(token, 0)` that no runbook step currently requires."* The substance (armed is the default resting state) survives intact; the absolute does not.

### 1.6 Citation hygiene — submission is right, classified.md is wrong

`classified.md` cites `Antimatter.sol:263` at top-level HEAD `3a96fb7`. `H-01.md` correctly cites `a5570ce:294`, the nested pin the repo compiles against, and explains the divergence. **The submission's citation is the correct one** (memory `nested-submodule-pin-stale-trap`); I re-verified `:294` at `a5570ce` myself. The `classified.md` line should be corrected so a future reader does not chase the stale copy.

---

## 2. M-01 — migration-exit mint trap. MEDIUM confirmed, high confidence.

### 2.1 Verified

`_exitPosition:619-621` — `if (owed > 0) { antimatter.mint(account, owed); }`, inline, on the sole principal-exit path while `Migrating`. `IAntimatter public immutable antimatter` at `:60`, assigned once at `:196`, **no setter anywhere**. `Antimatter` is `contract Antimatter is ERC20, Ownable, ...` — plain `Ownable`, so `renounceOwnership` is inherited and un-overridden. **Every premise of the High case is factually correct.**

### 2.2 Down to Low? No — the prior wont-fix is genuinely falsified.

The old closure read *"an obvious admin misstep… and recoverable."* Both halves fail:
- **Not obvious.** `CLAUDE.md:12-13` asserts unconditionally, with no migration carve-out, that a revoked minter can no longer brick a principal path. An owner reading the project's own operator doc is told the opposite of the truth. Per memory `in-source-natspec-carries-no-suppression-authority`, a falsely-exhaustive safety claim **raises** severity and cannot suppress.
- **Magnitude.** 100% of a migrating pool's principal, with every hatch verified closed (`withdraw`/`emergencyWithdraw` require `Active`, `rescueERC20` bounded by `reserved == totalStaked`, `finalizeAndReset` requires an empty staker set). Availability impact on all of a pool's principal is Medium by C4's plain text, not Low.

**Low is affirmatively wrong. The re-weigh is correct.**

### 2.3 Up to High? No — the classifier's specific reasoning holds, and I tested it directly.

The classifier held Medium because the permanence branch needs a second discretionary act whose irreversibility is obvious. **I tested that and endorse it**, on three grounds:

1. **The base case is one call from a party present by construction.** Under Law 3 the owner is non-malicious and available; `setApprovedMinter(staker, true)` fully restores every exit path. Frozen-with-the-key-in-hand is availability, not loss.
2. **`renounceOwnership` is the one admin action whose consequence is not merely obvious but *named in the function*.** Resting a High on it would put the label's weight on an obvious-consequence admin act, which Law 3 and the C4 filter both exclude. This is the correct application of the rule, not an evasion of it.
3. **No attacker exists anywhere in the path.** Nothing is extracted. This is C4 Medium's text verbatim.

**Accuracy narrowing to fix.** The mint is guarded by `if (owed > 0)`. A staker with zero accrued reward *and* zero backlog exits cleanly. So "100% of a pool's `totalStaked` is frozen" is true only when the rate is armed or a backlog exists — the common case, and the case the PoC uses, but the report states it unconditionally. Add the condition.

**Ruling: MEDIUM, at the top of the band.** The permanence branch must be stated prominently, as the classifier directs.

---

## 3. The re-weighs — double-counting check. One fails.

The classifier's own anti-inflation guard-rail is stated correctly up front and applied explicitly to L-01 (*"the story-023 premise change must not pull this upward"*). **It then did not apply the same guard-rail to M-02.**

### 3.1 M-02 (`ss9l1`, Low→Medium) — **I DISAGREE. Assign LOW.**

The two claims to verify were: (i) the risk is not additive, (ii) it must not be collapsed. **Both are correct — and neither supports the raise.**

- The **remedy** is genuinely distinct (zero the rate inside `finalizeAndReset`; re-assert the strategy binding). That justifies a **separate ledger entry**, and I endorse not collapsing it.
- The **severity basis** is not distinct. The classifier's own `assetImpact` field reads: *"the same realization leg as H-01 (`Antimatter.sol:263`)"*, and the attack path's step 3 is literally *"(H-01 mechanism)"*. H-01's own reachability list already names `finalizeAndReset` as an enabling window. So the raise is carried entirely by H-01's impact, applied to a narrower window — which is inflation-by-association, the precise error the guard-rail exists to prevent.
- The one genuinely independent leg — `yieldStrategy` re-binding not re-asserted on revival — the classifier itself describes as *"a configuration hazard, not a value path."* By its own characterization that is Low-shaped.

The classifier rejected raising M-02 to High as *"double-counting: rating both High would present one class of loss as two."* **That argument does not stop at High.** Rating it Medium presents the same one class of loss as two, one band down.

**This is an affirmative downgrade, not a tidying one:** removing H-01's borrowed impact leaves a bounded operational window plus a configuration hazard, which is Low on its own merits. Under the Symmetry Rule I have checked the other direction — there is no independent value path here that H-01 does not already carry, so nothing is buried by the downgrade.

**Recommendation:** keep `ss9l1` as a visible **Low** with its inverted rationale corrected (the classifier's strongest and entirely correct point — the entry currently tells a future reader that emission dilution is harmless, and that text is more dangerous than the label), and cross-reference *"realization mechanism and severity: see H-01."* **Flagged for human triage** — a reviewer who weighs the strategy-rebinding leg as a value path would reach Medium.

### 3.2 L-06 (`86fcf00e`, QA→Low) — **AGREE. Low is justified on its own trigger.**

The raise here is a different animal and it holds. It is a **one-notch correction of a rationale that is now factually inverted**: the entry closes with *"emission-share dilution… not a leak"*, and under story-023 that sentence is simply false. QA→Low is the proportionate response to "the residual is a real leak rather than a redistribution note" — it does not import H-01's $900k impact figure, it just declines to keep calling the residual harmless. Distinct trigger (pre-`migrateIn` revival race, inside one migration session) and distinct remedy (pause-wrap the out→reset→rewire→in session) both check out. The instruction to preserve its correct refutations verbatim is right.

---

## 4. The Low/QA set — understatement check. Nothing is under-rated.

- **L-01 (`emergencyWithdraw` skips `_updatePool`) — LOW is right.** The decisive fact is not the fuzzing volume, it is the algebra: the recycled amount was **already inside the cap and would have been minted to someone**. Emission total is unchanged, so there is no net-new issuance and the story-023 premise cannot reach it. Verified `:394-411` has no `_updatePool` and forfeits both `pending` and `unclaimedReward`, so the leaver can only shrink their own numerator — every variant is a donation to survivors. The classifier's explicit anti-inflation guard-rail here is exactly correct and I endorse it verbatim. The `phoenix-nft-staking` `911c54fd` distinction (per-position rate vs shared MasterChef denominator) is also correct — no cross-project authority.

- **L-04 (retired stakers must stay minters forever) — LOW is right.** Verified `setApprovedMinter(address, bool)` takes either direction, so revocation is one-call reversible. The apparent tension with M-01 (both are "reversible availability", one Medium one Low) resolves cleanly on magnitude: M-01 freezes **all principal**, L-04 strands a **residual accrued-reward backlog**. That is a legitimate Medium/Low discriminator, not special pleading. The rejection of the incident-response half is also right — a slower response in an out-of-scope contract is not an impacted protocol function here. This is the closest boundary in the set and the qa-report says so honestly.

- **L-07 (`batchMigrate` skips zero-principal backlog holders) — LOW is right.** I verified both halves independently: `_exitPosition:599-601` early-returns on `amt == 0`, and `claim` at `:376` carries `nonReentrant whenNotPaused poolExists` with **no `poolState` gate** — so the backlog is genuinely recoverable post-migration and is not destroyed. The residual (a retired staker left permanently paused strands it, since `claim` is `whenNotPaused`) is real and the permanence arises from an *ordinary end-state* rather than a second deliberate act — a stronger permanence argument than M-01's `renounceOwnership` branch. But the value at stake is a bounded residual backlog, not principal, and it is one `unpause` away. **Low, at the top of the band.** The qa-report already discloses the L-04 compounding, which is the right handling.

- **Q-04 (1-wei emission overshoot) — QA is right.** ~4e-22 relative on an 18-decimal token is not a value finding at any severity. The mechanism (per-user credit is a *difference of independently-floored terms*, not a floor of a difference) is correctly diagnosed and backed by a concrete shrunk counterexample, so it is not tool noise either. The false `CLAUDE.md` "always rounds DOWN" claim is a real documentation defect, but the doc-raises-severity rule raises severity **of an underlying defect**, and here there is none to raise. **Contamination check performed:** the broken cap claim does not undermine L-01 (1 wei does not turn redistribution into issuance) or H-01 (which concedes the cap holds and attacks its cost basis instead). QA/informational, correct.

---

## 5. Required corrections before submission (accuracy, not severity)

1. **`H-01.md` — the `maxMintPerDay` throttle is unstated.** `PhusdStableMinter.mint` enforces a rolling 24h per-stablecoin cap and a breach reverts the whole `annihilate`. Add it as a stated mitigating factor and note the realization becomes an N-day drip if the cap is configured on the live deployment. Verify the live `maxMintPerDay` for the target stablecoins before the report ships — the PoC ran against a mock sink and did not exercise it. *Severity unaffected: the theft completes at `claim`; this throttles realization only.*
2. **`H-01.md` — "Nothing in the codebase ever zeroes `antimatterPerSecond`" is false as written.** `antimatterPerDay(token, 0)` at `:214` does. Rewrite to "no **automatic** path". (§1.5)
3. **`H-01.md` — add the no-redemption fact and answer it.** `PhusdStableMinter` is mint-only. The report currently argues "the attacker holds the offsetting claim" without disclosing that the claim is not redeemable at the protocol. State it, then make the argument that survives: the collateralization ratio falls at the moment of mint regardless of market depth. Omitting this is the report's most exploitable weakness in review. (§1.2)
4. **`M-01.md` — condition the "100%" claim** on `owed > 0`. (§2.3)
5. **`classified.md` §1 — correct the `Antimatter.sol:263` citation** to `a5570ce:294`, matching the submission. (§1.6)

## 6. Integrity checks on my own pass

| Check | Result |
|---|---|
| Severities lowered | **1** (M-02 Medium→Low), affirmatively justified in §3.1, flagged for human triage |
| Severities raised | 0 — no understatement found |
| Findings I would drop entirely | **0** |
| Borderline calls resolved upward and flagged, not lowered | 1 (H-01) |
| Load-bearing source claims re-verified from source rather than from the classifier's text | 12 |
| Facts found that the classifier and report writer both missed | 3 (`maxMintPerDay` throttle, phUSD has no redemption path, `owed > 0` guard) |

**The run is not inflated.** One re-weigh over-reaches; the other is sound. The High is defensible and is the correct call under the Symmetry Rule, but it is the run's closest question and its submission currently under-discloses the two facts most likely to be used against it.


---

## Post-review note — H-01 retracted 2026-08-31 (mechanism disproved)

**This review validated `H-01`, and it missed the defect that actually sinks it.**

The finding's mechanism was disproved in session on 2026-08-31: `_updatePool`'s empty branch
(`src/StableStakerV2.sol:816-819`) sets `pool.lastRewardTime = block.timestamp` and returns, and `stake`
calls `_updatePool` at `:327` **before** `pool.totalStaked += credited` at `:335`. The pool is therefore
still empty at that call, `lastRewardTime` fast-forwards, and the new staker's `rewardDebt` is set
against an index that never advanced. **The dormant window is discarded, not banked** — textbook
MasterChef, and correct behaviour. The PoC warped 90 days *after* the 1-wei stake, so it only ever
showed a sole dust-sized staker collecting the full rate **going forward**; `test_emptyPoolAccruesNothing`
(`accAntimatterPerShare` unchanged, `lastRewardTime` advanced) was the **refutation**, read as support.

What survives is Low: emission is time-denominated and TVL-independent, so an armed pool with negligible
stake still mints at its full scheduled rate, and post-story-023 those tokens are claims on unbacked
phUSD — but the emission is **budgeted** and merely misallocated, no staker is deprived, and any genuine
staker dilutes the dust holder pro rata at once. Re-labelled **`L-09`**, severity **High → Low**, status
**`wont-fix`** by owner decision of 2026-08-31 (`issueId` `ss16h1` unchanged; report retained at
`submissions/H-01.md`).

**Process signal, recorded as fact.** Both adversarial passes — this one and its counterpart
(`severity-audit.md` §1 / `validity-review.md` §1) — affirmed the finding, and **neither identified the
`:817-819` fast-forward**. Each re-verified the claims the report made (time-denominated numerator,
1-wei entry, permissionless `annihilate`, unbacked mint at `Antimatter.sol:294`) and each found those
claims true; what went unchallenged was the report's *framing* of what happens before the stake — the
one premise on which the severity rested. The mechanism error therefore survived classification plus two
independent adversarial passes. Verifying every cited line is not the same as testing the causal story
the lines are assembled into.

Nothing else in this review is altered or withdrawn by this note.
