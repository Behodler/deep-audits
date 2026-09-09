# C4 severity classification — stable-staker run-16

- **Project:** stable-staker · **Commit:** `fa06de5` · **Range:** `2146428..fa06de5` (stories 022 / 023 / 024) · **Branch:** `master`
- **Agent:** severity-classifier · **Date:** 2026-08-31
- **Authoritative input:** `reports/stable-staker/16/sanitized.md` (KEEP/SUPPRESS/RE-WEIGH). Evidence: `findings-deduped.md`, `scan-econ.md`, `scan-code.md`, the two passing PoCs.
- **Ledger: not modified.** Every severity below is a *proposal* for a human at `/ledger`.

## 0. Headline

| Label | Finding | Severity | Plausibility | Regression |
|---|---|---|---|---|
| ~~**H-01**~~ **L-09** | ~~Empty-pool emission cliff — 1 wei arms a full-rate, permissionlessly-capturable unbacked-phUSD dilution stream~~ **RETRACTED 2026-08-31 — mechanism disproved (the empty branch fast-forwards `lastRewardTime`, so the dormant window is discarded, not banked). What survives is TVL-independent emission misallocating *budgeted* tokens to a dust position. Re-labelled `L-09`, closed `wont-fix` by owner decision. See §1.** | ~~HIGH~~ **LOW** | — | no |
| ~~**M-01**~~ **L-10** | ~~Migration-exit mint trap — a revoked AM minter freezes 100% of a pool's principal (re-weigh of `e4567dc3`)~~ **RE-WEIGH WITHDRAWN 2026-08-31 by owner triage — fail-loud is the intended behaviour on this attended, `onlyMigrator` path, and that reasoning collapses the severity. Severity returns to LOW; status stays `wont-fix` (the proposed reopen is withdrawn, `HTQ-16-01` CLOSED); the recommended mitigation (book to `unclaimedReward`) is REJECTED. What survives is a doc-accuracy defect at QA/Low. Re-labelled `L-10`; report stays at `submissions/M-01.md`. See §2.** | ~~MEDIUM~~ **LOW** | — | **no** (prior status was `wont-fix`, not `fixed` — see §3.1) |
| **L-08** | `finalizeAndReset` revives a pool at a stale emission rate (`ss9l1`) — classified **M-02 / MEDIUM**, **DOWNGRADED to LOW on second-opinion review 2026-08-31**; see §3 | **LOW** | — | no |
| **L-01** | `emergencyWithdraw` skips `_updatePool`, recycling forfeited emissions to survivors | LOW | — | no |
| **L-02** | `pendingReward` reads zero for a fully-owed settled user | LOW | — | no |
| **L-03** | `depositFor` has no zero-address recipient guard | LOW | — | no |
| **L-04** | Retired stakers must remain approved AM minters forever | LOW | — | no |
| **L-05** | Sliced migration re-injection over-pays the first page ~83% | LOW | — | no |
| **L-06** | Revival-window permissionless-stake race before `migrateIn` (re-weigh of `86fcf00e`, QA → Low) | LOW | — | no |
| **Q-01** | Duplicate `FlaxToken` build artifacts, no CI hash pin | QA | — | no |
| **Q-02** | `setYieldStrategy` / `finalizeAndReset` lack `nonReentrant` | QA | — | no |
| **Q-03** | Pause does not freeze reward minting on the migration path (MR-16-02) | QA | — | no |
| **F-01** | story-022's "principal paths never call phUSD" criterion unmet on the migration exit | faithfulness (Medium-equivalent) | — | no |
| **F-02** | story-023 silent on the redemption consequence; laundered a token-specific conclusion into a token-agnostic one | faithfulness (Medium-equivalent) | — | no |
| **F-03** | story-022 Decision 3's "nothing is stranded" has an unstated third precondition | faithfulness (Low-equivalent) | — | no |
| **F-04** | Vendored V1 pair has zero gate; story-024 declined to pin it on a false CI premise | faithfulness (Low-equivalent) | — | no |
| **C-1** | *(carryover)* Idle-pool strategy adoption discards `creditedPrincipal` — `dab5a65613c7af50`, **fix-pending** | MEDIUM (carried) | — | no (code unchanged in range) |

Totals (post-retraction **and post-owner-triage**, 2026-08-31): **0 High · 0 Medium (+1 Medium carried) · 9 Low · 3 QA · 4 faithfulness.** The former `M-02` is now `L-08` and is bundled in `submissions/qa-report.md` rather than filed as a standalone submission. The former `H-01` is now **`L-09`** — its mechanism was disproved on 2026-08-31 and it was downgraded High → Low and closed `wont-fix` by owner decision; its report stays at `submissions/H-01.md` (filename kept for link stability) rather than being folded into the QA bundle. The former `M-01` is now **`L-10`** — the run-16 re-weigh Low → Medium was **withdrawn by owner triage on 2026-08-31** (fail-loud is intended on the attended `onlyMigrator` migration path); its status stays **`wont-fix`**, its recommended mitigation is **rejected**, and its report stays at `submissions/M-01.md` (filename kept for link stability), so it is **not** folded into the QA bundle. **This run raises no Medium of its own; the only Medium in the set is the carried `C-1` (`dab5a65613c7af50`, `fix-pending`).** *Superseded totals, recorded so the change is visible: after the `H-01` retraction but before the `M-01` withdrawal, **0 High · 1 Medium (+1 carried) · 8 Low · 3 QA · 4 faithfulness**; as originally classified, **1 High · 1 Medium (+1 carried) · 7 Low · 3 QA · 4 faithfulness**.*

**No `C-01` centralization label is issued this run.** Every owner-facing item was filed as a *non-obvious footgun* under Law 3 and is classified by the impact it unlocks, not bundled as centralization risk. Zero "a malicious owner could…" vectors exist in this run (re-verified against the sanitizer's §6).

**Anti-inflation note, stated up front.** H-01, L-08 (was M-02) and L-06 share one root class (a live emission rate against a pool with no legitimate stakers). They are kept separate because the sanitizer's §4.2 established three distinct triggers and three distinct remedies, but their risk is **not additive**: a reader must not total them as three independent losses. **H-01 is the class parent** and carries the realization impact for the whole class; L-08 and L-06 are migration-specific instances carrying remedies H-01 does not cover. *This note is the reason for the §3 correction: L-08 was first labelled Medium on impact borrowed from H-01, which is precisely what this note forbids.*

---

## 1. ~~H-01~~ L-09 — Emission is TVL-independent (DEDUP-001) — **RETRACTED AND DOWNGRADED**

> **Retraction, 2026-08-31.** The classification below is **superseded**. It rests on the claim that a
> dormant pool **banks** emissions which the first staker then captures. That claim is **false**:
> `_updatePool`'s empty branch (`src/StableStakerV2.sol:816-819`) sets `pool.lastRewardTime =
> block.timestamp` and returns, and `stake` calls `_updatePool` at `:327` **before**
> `pool.totalStaked += credited` at `:335` — so the dormant window is **discarded**, and the new
> staker's `rewardDebt` is set against an index that never advanced. Textbook MasterChef, correct
> behaviour. The PoC warped 90 days **after** the 1-wei stake, so it only showed a sole dust staker
> collecting the full rate **going forward**; `test_emptyPoolAccruesNothing` (index unchanged,
> `lastRewardTime` advanced) was the **refutation**, mis-read as support.
>
> **What survives:** emission is time-denominated and TVL-independent, so an armed pool with negligible
> stake still mints at the full scheduled rate, and post-story-023 those tokens are claims on unbacked
> phUSD. Bounded: no other staker is deprived, any genuine staker dilutes the dust holder pro rata
> immediately, and the tokens are **budgeted emission misallocated**, not issuance outside the schedule.
>
> **Corrected severity: LOW.** **Label: `L-09`** (was `H-01`; `issueId` stays `ss16h1`, report stays at
> `submissions/H-01.md`). **Status: `wont-fix`, human-set by the owner on 2026-08-31** — the behaviour is
> intuitive/optics-shaped, day-1 exposure is zero (an existing user base is migrated in), and realization
> is capital-positive because the redeemer must front matching stablecoin that routes through the minter
> as real backing. *Caveat preserved, not as rebuttal:* `annihilate` adds 2x liability against 1x backing,
> so the collateralization **ratio** still slips. **Reopen (`REOPEN-ss16h1`)** if a pool is ever left armed
> (`antimatterPerSecond > 0`) at near-zero TVL after its users exit without `antimatterPerDay(token, 0)`.
>
> The JSON and argumentation that follow are retained unaltered for auditability (Law 1) and must not be
> cited as current.


```json
{
  "classifiedFinding": {
    "id": "CLASS-001",
    "originalId": "DEDUP-001",
    "label": "H-01",
    "fingerprint": "3102c29c8407a0e1",
    "severity": "high",
    "plausibility": "plausible",
    "regression": false,
    "faithfulness": false,
    "classification": {
      "assetImpact": "The protocol's phUSD backing ratio. Each AM emitted into a dust-held pool is a bearer claim on ~1e18 of UNBACKED phUSD via the permissionless Antimatter.annihilate (lib/antimatter/src/Antimatter.sol:294, at the nested pin a5570ce that stable-staker compiles against; annihilate spans :253-298). PoC-realized: 899,999.999999e18 AM captured, annihilated into phUSD supply +1,799,999.999998e18 against only 899,999.999999e18 of new backing => ~899,999.999999 phUSD unbacked (~$900k) for 1e-6 USD of staked capital.",
      "attackPath": [
        "1. Attacker observes a pool that is Active with totalStaked == 0 and antimatterPerSecond != 0 (retired, organically emptied, pre-launch, or post-finalizeAndReset).",
        "2. stake(token, 1) — one wei, satisfying require(credited > 0) at :333.",
        "3. Wait. _updatePool (:822) computes reward = elapsed * antimatterPerSecond with no reference to totalStaked; the sole staker's pending is 100% of it.",
        "4. claim(token) mints the full window's AM to the attacker (:385).",
        "5. Antimatter.annihilate (a5570ce:253-298): burn AM (:270) + supply matching stablecoin, minted backed through minter.mint(stable, stableAmount) (:282) AND an equal amount of UNBACKED phUSD via _phUSD.mint(recipient, amount) (:294). The stablecoin leg returns as backed phUSD in the same call."
      ],
      "likelihood": "high - permissionless, two transactions, no privileged role, no race, no MEV requirement. The enabling state is the DEFAULT end-state, not a misconfiguration: no code path anywhere zeroes antimatterPerSecond, and the launch window (a) arises from the wiring order CLAUDE.md documents verbatim.",
      "assumptions": "phUSD trades near par, so the unbacked half is realizable at value; the pool is idle-hold or its strategy credits a minimal deposit (a strategy that rounds 1 wei to zero raises the entry cost to that strategy's minimum credit — negligible against a multi-day stream, per the deduplicator's coverage note).",
      "externalRequirements": "The attacker must source stablecoin equal to the AM position for the annihilate leg. This is a LIQUIDITY requirement, not a capital-at-risk requirement — the stablecoin comes back as backed phUSD inside the same call, so nothing is exposed."
    },
    "justification": "Direct, permissionless, PoC-proven creation of ~$900k of unbacked phUSD against ~$1e-6 of capital, executable by any external address with no hypotheticals in the path."
  }
}
```

### Both directions, argued

**The Medium case (the one I rejected), stated fully.** ECON-16-02 recorded it honestly and it is not weak: (i) every window requires the owner to have armed a rate against a pool with no users, which reads exactly like C4 Medium's *"value leak with a hypothetical attack path with stated assumptions, but external requirements"*; (ii) no staker is short-changed — the pool was empty, so nobody is diluted **out of** anything; the harm lands on holders of a **different token in a different contract**, which is one step removed from "assets can be stolen"; (iii) the attacker must front ~900k stablecoin, which superficially reads as an external capital requirement.

**Why it loses, point by point.**

1. **The "external requirement" is the steady state, not an exception.** C4's Medium carve-out contemplates a precondition that must be *arranged*. Here nothing ever clears `antimatterPerSecond` — windows (c) retired pool and (d) organic emptying are what every pool becomes at end of life, and window (a) is the documented deployment sequence. A precondition that the protocol reaches by doing nothing is not an external requirement; it is the default configuration. The severity-relevant question "must something unusual happen first?" answers *no*.
2. **The harm is a realized loss, not a leak with assumptions.** The PoC does not stop at "AM was over-emitted" — it runs a real `Antimatter.annihilate` and measures phUSD supply against backing. The preceding empty window emitted zero (index byte-identical), so this is **net-new issuance**, not redistribution: the emission would never have existed. Freshly-minted unbacked phUSD is genuine dilution of the protocol's collateralization, categorically distinct from externally-derived yield paid to the wrong party (memory `externally-derived-yield-opportunity-cost-not-loss`, which the sanitizer §1.3 correctly voided for the V2 reward leg). Nine hundred thousand dollars of backing evaporates and an attacker holds the offsetting claim.
3. **"Assets" is not restricted to the staked principal.** The value compromised is the phUSD backing pool — a protocol asset, held on behalf of identifiable third parties (phUSD holders). Diluting them is a transfer of value to the attacker, i.e. it is stolen, not merely leaked. The fact that the victims hold a different token narrows *who* pays, not *whether* the protocol lost.
4. **The capital front is not risk.** The stablecoin leg returns inside the same `annihilate` call as backed phUSD. The attacker's exposure is a one-block liquidity need (flash-loanable against a liquid phUSD), not principal at risk. It does not gate the attack and does not soften the impact — it is a *convenience* precondition, and C4 does not discount for those.

**Law-3 check.** This is a non-obvious owner footgun (a competent owner would be surprised that a zero-user pool carries a live dilution liability), but the footgun classification rule applies: classify by the impact it unlocks, up to High where it enables direct asset loss. Critically, the *exploit* is executed by an unprivileged external attacker; the owner's only contribution is an omission. It is therefore not an "admin mistake" finding at all under the C4 known-invalid filter, and no downgrade applies.

**Plausibility: PLAUSIBLE.** No validator collusion, no oracle failure, no black swan, no governance capture. Two transactions and patience.

**Suppression authority checked and refused** (upheld from sanitizer §5): KI#1 bounds emission *quantity* and this finding concedes the cap holds — it attacks the cap's cost basis; KI#2 ("empty-pool windows accrue nothing") is true and off-point since the attack stakes 1 wei; KI#4's harmlessness reading is void for the V2 reward leg; KI#8's blanket "centralization by design" cannot dispose of a non-obvious footgun.

**Dependency flagged for the report writer:** the entire economic conclusion rests on the unbacked mint at `lib/antimatter/src/Antimatter.sol:294`, which is **out of this run's scope**. Per memory `nested-submodule-pin-stale-trap`, the citation must be taken at the **nested pin `a5570ce`** that `stable-staker` records and compiles against, not at top-level `lib/antimatter` HEAD `3a96fb7`. **It has now been verified at `a5570ce`** (this correction supersedes the earlier note that it "was verified at top-level HEAD only"): `annihilate` spans `:253-298`, the self-burn is `:270`, the backed leg is `minter.mint(stable, stableAmount)` at `:282`, and the unbacked leg is `_phUSD.mint(recipient, amount)` at `:294`. At `a5570ce`, `:263` is `PhusdStableMinter minter = phUSDMinter;` — an assignment, not a mint; the stale `:263`/`:226-267` citations were `3a96fb7` numbers. **Directional note (previously stated backwards elsewhere): `a5570ce` HAS the `Pausable` mixin (`contract Antimatter is ERC20, Ownable, Pausable, ReentrancyGuard, IPausable`); top-level `3a96fb7` has DROPPED it.**

---

## 2. ~~M-01~~ L-10 — Migration-exit mint trap (DEDUP-002 → re-weigh `e4567dc343655af9`) — **RE-WEIGH WITHDRAWN, SEVERITY RETURNED TO LOW**

> **Owner triage, 2026-08-31. The classification below is SUPERSEDED and retained in full (Law 1).**
> The re-weigh to **Medium** is **WITHDRAWN**; severity returns to **LOW**, its pre-run-16 value. The
> status was and remains **`wont-fix`** (human-set 2026-06-08) — the proposed reopen is withdrawn and
> `HTQ-16-01` is **CLOSED/withdrawn**, not deleted. The **recommended mitigation** below (book to
> `unclaimedReward` instead of minting inline in `_exitPosition`) is **REJECTED**.
>
> **Basis — fail-loud is the intended and preferred behaviour on this path, and that same reasoning
> collapses the severity:**
> 1. **The fix does not deliver the Antimatter.** `claim` (`:385`) is itself a mint site, so a booked
>    `unclaimedReward` balance is still unmintable while the minter is revoked. Booking lets users exit
>    *without* their AM — it moves the failure from loud-and-now to **silent-and-later**, onto the user
>    with no recourse.
> 2. **The fix manufactures more of a class this same run filed.** `L-07` (`ss16l7`) and `F-03` are the
>    backlog-stranding class; routing the migration exit into `unclaimedReward` feeds exactly it.
> 3. **The operation is attended and permissioned.** `initiateMigration` / `batchMigrate` /
>    `userMigrate` are all `onlyMigrator` (`:178-181`). `Antimatter.NotApprovedMinter` (`0x6830132b`)
>    is an immediate, named alarm — a working signal, not a defect.
> 4. **Story-022 already decoupled the paths that matter.** `withdraw` books rather than mints
>    (`:361-363`); the migration exit is the deliberate exception, and the one path with an operator
>    watching.
>
> **Net:** an attended, permissioned migration halts loudly and resumes after one
> `setApprovedMinter(staker, true)`. The permanent branch needs `renounceOwnership`, obviously
> irreversible on its face → **Law 3, the owner's own affair, not a finding.** This also disposes of
> §2's "High case" and the `severity-audit.md` / §8 debate item 2 below.
>
> **The PoC stands, unchanged and passing** — exact revert, 100% of `totalStaked` under the `owed > 0`
> gate at `:619`, all hatches closed, recovery by re-approval. **What changed is the INTERPRETATION of
> that evidence, not the evidence.**
>
> **What survives:** `lib/stable-staker/CLAUDE.md:12-13`'s unconditional *"can no longer brick a
> principal path"* is a **live documentation-accuracy defect at QA/Low** — the migration exit is a
> genuine exception. **Correct the doc, not the contract.** Its Law-2 twin **`F-01` REMAINS VALID and
> unchanged** in `spec-conformance.md`.
>
> **Reopen trigger:** revisit if migration is ever made permissionless, keeper-driven, or otherwise
> **unattended** — the argument rests on an operator being present.


```json
{
  "classifiedFinding": {
    "id": "CLASS-002",
    "originalId": "DEDUP-002",
    "label": "M-01",
    "fingerprint": "e4567dc343655af9",
    "fingerprintAction": "PRESERVE — reopen the existing entry; do NOT mint fe5e8b27",
    "priorStatus": "wont-fix (human-set 2026-06-08, ss7m3)",
    "severity": "medium",
    "severityAfterOwnerTriage_20260831": "low (this re-weigh WITHDRAWN; see the banner above)",
    "plausibility": "n/a (medium)",
    "regression": false,
    "faithfulness": false,
    "classification": {
      "assetImpact": "100% of a migrating pool's totalStaked (PoC: 1,000,000e6 USDC) is frozen — not extracted. Availability, not theft. In the compound branch (§2.2) it becomes permanent loss of that principal.",
      "attackPath": [
        "1. Owner calls initiateMigration(token) — pool enters Migrating; withdraw (:347) and emergencyWithdraw (:396) now require Active and revert 'pool not active'.",
        "2. Independently, Antimatter.setApprovedMinter(staker, false) — ordinary incident response, or the natural decommissioning order.",
        "3. _exitPosition (:620) mints inline. It is the SOLE principal exit while Migrating. Every path through it now reverts Antimatter.NotApprovedMinter (0x6830132b): batchMigrate (full and single-user batch), userMigrate, claim.",
        "4. finalizeAndReset reverts 'stakers remain'; rescueERC20 reverts at 1 wei (reserved == totalStaked, max rescuable exactly 0); pause() opens nothing.",
        "5. Recovery: setApprovedMinter(staker, true) — one call, fully restores the exit."
      ],
      "likelihood": "medium - requires an owner action (minter revocation) that is routine and whose consequence is invisible from Antimatter, invisible from emergencyWithdraw, and actively contradicted by the project's own CLAUDE.md:12-13. No attacker involvement.",
      "assumptions": "The pool is in Migrating when the revocation lands. Outside Migrating, story-022's rework holds and principal paths are mint-free.",
      "externalRequirements": "Minter revocation must occur (or the Antimatter deployment must become unusable) while a migration is open."
    },
    "justification": "Protocol function and availability of 100% of a pool's principal, PoC-proven with the exact revert, but recoverable by a single owner call. Medium, not High."
  }
}
```

### Both directions, argued

**The High case (the one I rejected), stated fully.** `Antimatter` is plain `Ownable`, not `Ownable2Step`, with `renounceOwnership` inherited and un-overridden; `StableStakerV2.antimatter` is `immutable` (`:60`) with no setter. The ordinary teardown sequence — *revoke the minters, then renounce ownership* — is two individually reasonable steps that together make the trap **permanent and unrecoverable by anyone**. Permanent loss of 100% of a pool's principal is, on its face, "assets lost".

**Why it loses.**

1. **The compound branch requires a second, independent operator action after the first has already produced the freeze.** C4 High requires a valid attack path free of hypotheticals; a path whose loss leg only closes if the owner *also* renounces is a conjunction of two discretionary acts, not an attack path. The base case — the one the PoC actually demonstrates — is recoverable in one call, and the same PoC demonstrates the recovery.
2. **Renouncing ownership fails the Law-3 surprise test in the direction that matters.** The freeze is genuinely non-obvious and stays in scope as a footgun (which is precisely why the prior `wont-fix` is falsified — see §3.1). But `renounceOwnership` is *universally understood* to be irreversible; an owner who calls it has been told by the function's own name what it does. Making irreversibility the load-bearing step of a High would rest the label on an obvious-consequence admin action, which the C4 filter and Law 3 both exclude.
3. **No external attacker exists anywhere in this path.** Nothing is stolen; nothing is extracted. The impact is exactly C4 Medium's text: *"assets not at direct risk, but the function of the protocol or its availability could be impacted."*
4. **The counter-argument in the *other* direction is also recorded and also rejected.** The deduplicator honestly noted that the old token had `FlaxToken.revokeAllMintPrivileges()` while Antimatter has only per-minter revocation, which arguably makes *accidental blanket* revocation **less** likely — i.e. on that one sub-axis the original `wont-fix` got stronger. That narrows the blanket-accident path; it does not touch the targeted single-minter revocation the PoC uses, which is the realistic trigger. It moves likelihood slightly, not category.

**Severity floor is nevertheless raised inside Medium, and this must reach the report.** `CLAUDE.md:12-13` asserts unconditionally, with no migration carve-out, *"a revoked minter role, or any Antimatter revert, can no longer brick a principal path"* — and the PoC falsifies it exactly. Per memory `in-source-natspec-carries-no-suppression-authority`, a doc that self-certifies exhaustively and is wrong **raises** severity and never suppresses. It cannot lift a recoverable availability bug across the High line by itself, but it is why this sits at the top of Medium and why the permanence branch must be stated prominently rather than as a footnote.

**Regression flag: NO — and this is a deliberate call.** The prior entry was `wont-fix`, never `fixed`. A regression is a finding that reappears after being marked `fixed`; this is a **re-weigh on falsified-closure grounds**, and mislabelling it a regression would send the reader hunting for a patch that never existed (memory `expired-closure-vs-regression`). Note also the sanitizer's precise ruling: the closure is falsified on the **Law-3 axis** (its own words *"an obvious admin misstep… and recoverable"*), **not** on the redemption-premise axis — it must not be reopened on premise-expiry grounds.

**Disclosure obligations carried forward** (memory `disclose-when-refiling-owner-wontfix`): name `e4567dc343655af9`, quote its `triageReason` in full, and concede without reservation its un-disputed half — the `Migrating` freeze of `withdraw`/`emergencyWithdraw`/`depositFor` **is** intended design protecting the `(R,P)` snapshot, no mitigation touches it, and the prior `reclassNote` is **not** overridden. Preserve the fingerprint (a new hash under `_exitPosition` would fracture five runs of history); annotate the function drift — filed against `userMigrate`, root cause at `_exitPosition:620`, reached by both `userMigrate` and `batchMigrate`.

**Recommended mitigation to carry into the submission — WITHDRAWN 2026-08-31, REJECTED by the owner (see the banner at the head of §2):** mirror `claim`'s shape — leave the amount booked (`unclaimedReward[token][account] = owed`) and drop the inline mint, so principal leaves unconditionally; or wrap the mint in `try/catch` falling back to booking. Independently, give `Antimatter` an `Ownable2Step` + overridden `renounceOwnership`, or `StableStakerV2` an owner-settable `antimatter` pointer — either alone deletes the permanence branch.

---

## 3. L-08 (was M-02) — `finalizeAndReset` revives a pool at a stale emission rate (`ss9l1`)

> **SEVERITY CORRECTED 2026-08-31: MEDIUM → LOW.** The Medium below was my classification. It was
> overturned on independent second-opinion review and the correction is **accepted**. This section is
> retained in full — original reasoning first, then the correction — so the record shows what was
> argued and why it was wrong, rather than silently reading as if Low had always been the call.
> The finding keeps a **separate ledger entry** and is **not** collapsed into `H-01`. It is reported
> as **`L-08`** in `submissions/qa-report.md`; no standalone submission file is owed at Low.

```json
{
  "classifiedFinding": {
    "id": "CLASS-003",
    "originalId": "ss9l1-finalizeAndReset-revival-stale-emission-rate",
    "label": "L-08",
    "priorLabelThisRun": "M-02",
    "fingerprintAction": "PRESERVE (label-string identity, not a hash) — re-weigh in place",
    "severity": "low",
    "severityAtClassification": "medium",
    "severityCorrectedAt": "2026-08-31",
    "severityCorrectedBy": "severity-auditor second opinion, accepted",
    "priorSeverity": "low",
    "regression": false,
    "faithfulness": false,
    "classification": {
      "assetImpact": "On its own merits: a bounded operational window in which a revived pool is Active and armed with zero legitimate stakers, plus a yieldStrategy binding that is not re-asserted on revival. The realization impact previously recorded here (unbacked phUSD via Antimatter.annihilate) belongs to H-01 and is NOT re-counted at this entry.",
      "attackPath": [
        "1. Owner completes a terminal migration and calls finalizeAndReset — poolState returns to Active, lastRewardTime = now, antimatterPerSecond UNCHANGED, yieldStrategy binding not re-asserted.",
        "2. The pool is now live and armed with zero legitimate stakers.",
        "3. Any address stakes dust and captures the stream until the migrator's depositFor re-injection lands. The capture-and-realize mechanism, and the whole of its impact, are H-01's — this entry contributes the window, not the loss."
      ],
      "likelihood": "medium - bounded by the revival window, which the operator controls in principle but which is open by default.",
      "assumptions": "None of its own. The realization leg is H-01's.",
      "externalRequirements": "A finalizeAndReset revival must occur; the window between revival and re-injection must be non-trivial."
    },
    "justification": "LOW. Stripped of H-01's borrowed impact, what remains is a bounded operational window plus a configuration hazard. Kept as a distinct visible entry because its remedy is distinct and lives inside finalizeAndReset."
  }
}
```

### The correction, and its basis

**What I originally argued (Low → Medium):** that the downgrade to Low rested on the clause *"Emission
cap not violated, no principal at risk"* — true of the staked stablecoin, false of the protocol's phUSD
backing since story-023 — and that the entry should therefore rise a band.

**Why that was wrong.** The raise was carried by `H-01`'s impact, not by this finding's own. The evidence
is in my own classification record, above the correction line:

- the `assetImpact` field as I first wrote it read *"the same realization leg as H-01"*;
- the attack path's step 3 read, verbatim, *"(H-01 mechanism)"*;
- `H-01`'s own reachability list already names `finalizeAndReset` as one of its enabling windows, so the
  loss was already counted once.

That is **inflation by association** — and I had already stated the guard-rail against it and applied it
correctly to `L-01` (*"the story-023 premise change must not pull this upward"*). I did not apply the same
guard-rail here. Worse, I rejected raising this to High **on exactly this reasoning** — *"double-counting:
rating both High would present one class of loss as two"* — without noticing that the argument does not
stop at High. Rating it Medium presents the same one class of loss as two, one band down.

Strip the borrowed impact and two legs remain, both Low-shaped:
1. a **bounded operational window** (revival → `depositFor` re-injection), whose exposure during the window
   is `H-01`'s and is counted there;
2. the **`yieldStrategy` re-binding leg**, which is genuinely independent of `H-01` — and which I myself
   characterized as *"a configuration hazard, not a value path."* By my own characterization, Low.

**LOW is the correct label.**

### What the correction does NOT change

**A distinct remedy justifies a distinct ledger entry; it does not justify a severity raise.** That
distinction is the whole of the correction. Everything below stands unchanged:

- **Do not collapse into `H-01`.** `ss9l1`'s remedy lives **inside `finalizeAndReset`** (zero the rate on
  revival; re-assert the strategy binding) and it carries a `yieldStrategy` re-wiring leg `H-01` does not
  have at all. Collapsing would silently delete the strategy-rebinding half. The sanitizer's §4.2 forbids
  the collapse, and it is still forbidden at Low.
- **The fingerprint is preserved verbatim**: `ss9l1-finalizeAndReset-revival-stale-emission-rate` (a
  label-string identity, not a hash). No re-mint.
- **The rationale correction remains mandatory, not optional.** As stored, the entry instructs a future
  reader that emission dilution is harmless. That inverted rationale is more dangerous than the severity
  label, and fixing the label does not fix it.
- **Risk is not additive** across `H-01` / `L-08` / `L-06`. `H-01` is the class parent and carries the
  realization impact for all three.

**Flagged for human triage** (Symmetry Rule — the downgrade is disclosed, not buried): a reviewer who
weighs the `yieldStrategy`-rebinding leg as a value path rather than a configuration hazard would reach
Medium. The severity here is a proposal; only a human at `/ledger` sets it.

---

## 4. Low findings

### L-01 — `emergencyWithdraw` skips `_updatePool` (DEDUP-003) · `0651258fcc7f607d`
**LOW.** Three agents independently re-derived the cap bound `Σ amount_i·Δacc ≤ reward`; the leaver forfeits both the live pending and the `unclaimedReward` backlog and can only shrink **their own** contribution to `totalStaked`, so every variant — including the paired-dust and sole-staker cases — is a **donation to honest survivors**. No profitable exploit, so no PoC is owed. Reportable because "forfeited reward is recycled and re-minted" versus "never minted" is a genuine bounded difference in *realized* dilution that the NatSpec does not state, and because `pendingReward`/`claimableReward` step discontinuously for survivors with no event.
**Explicit severity guard-rail:** the story-023 premise change must **not** pull this upward — the defect emits nothing extra. The sibling `phoenix-nft-staking` `911c54fd` (wont-fix) has no cross-project authority and a different mechanism (per-position rate, no shared denominator). *Counter-argument rejected: "redistribution of a now-redeemable token is a value leak ⇒ Medium." Rejected — the recycled amount was already inside the cap and would have been minted to someone; the leaver's donation moves it between users, and the emission total is unchanged.*

### L-02 — `pendingReward` reads zero for a settled user (DEDUP-004) · `708283cc026fdeb4`
**LOW.** State-handling / view-semantics. No value is lost — `claim` pays `unclaimedReward + pending` correctly. Held **at Low rather than QA** because it is load-bearing for integrators that *branch* on the value, and a live consumer exists (`ClaimWithdrawStableStaker.s.sol:57-63` hard-requires `pending > 0`). Held **at Low rather than Medium** because that consumer targets V1 today, so the break is latent, and because C4 ranks unused/mis-signalling view functions at QA/Low at best. Live **N5** disposes of the semantic-change half; the two residuals it does not reach are (a) the KI's own word "unchanged" is misleading — the formula is unchanged, the *meaning for a settled user* is not — and (b) the integrator break. **Flagged for human review** as a partial known-issue match; recommended remedy is a doc correction plus the MR-16-03 cross-repo watch, not a behaviour change.

### L-03 — `depositFor` missing zero-address guard (DEDUP-005) · `f35d1dc03602cac8`
**LOW (defensive hardening).** Mechanism confidence high, **reachability blocked today** — both shipped migrators skip zero-credit users. Filed rather than dropped because the consequence is unfixable-by-construction (`address(0)` joins `_stakers` permanently, `_exitPosition` reverts in OZ `_mint`, `finalizeAndReset` needs an empty staker set, and the residual principal is not rescuable), the guard is one line, and `migrator` is an **owner-settable pointer** — the protection lives entirely outside the contract that suffers. *Not a regression of `eae10d6031d96318` or `8d5ceff20ca74fbd`*: both are zero-**credit**, this is zero-**address** — different root-cause classes. Do not let "depositFor guard, fixed" be read as covering it.

### L-04 — Retired stakers must remain approved AM minters forever (DEDUP-006) · `f9a08a4021e57cdf`
**LOW.** The Medium argument was carried forward and is **rejected on two grounds.** (i) The incident-response half — mass revocation requires `n` non-atomic transactions because Antimatter has no `mintVersion` equivalent — is a property of a contract outside this repo's scope and describes a slower response, not an impacted protocol function here. (ii) The stranding half is the stronger argument (a de-approved decommissioned staker permanently strands every residual `unclaimedReward` backlog, and matured owed yield is capital-like), but revocation is **reversible by one call**, unlike M-01's compound branch, so the impact is availability of a modest residual backlog, not loss. Consistent with M-01's own reasoning, that holds it at Low. Safe-config guidance: terminal batch sweep before revoking. **Suppression on N2 refused** — N2 states the *precondition* ("no mass revocation exists"), carries no acceptance language, and matches no known-issue pattern.

### L-05 — Sliced re-injection emission over-share (DEDUP-007) · `d7a3b9d4421f2b9e`
**LOW.** Worked case: 3 pages × ~1M USDC one per day at 10,000 AM/day → page-1 users capture ≈18,333 AM against a fair ≈10,000, an **83% over-share** (≈8,333 AM) taken from page-3 users. *Counter-argument for Medium, rejected:* ~$8k of misallocated value is not dust. It fails Medium because **total AM emitted over the interval is unchanged** — this is pure redistribution among legitimate users, with no leak, no availability impact, and no attacker (page order is owner-chosen, so it is not user-exploitable). Valid as a **non-obvious footgun**, not as "reckless admin": a competent owner paginating for gas/review reasons would be surprised. Safe config: `antimatterPerDay(token, 0)` across the re-injection, or single-tx `migrateIn`.

### L-06 — Revival-window permissionless-stake race before `migrateIn` (`86fcf00ef786f496`, QA → Low)
**QA → LOW.** Its stated rationale is **exactly inverted** by story-023: *"emission-share dilution (normal MasterChef TVL dilution … not a leak)"* — under Antimatter, emission dilution **is** the leak, realized at `Antimatter.sol:294` (pin `a5570ce`). The entry's refutations of the theft, share-price-inflation and rate-manipulation angles remain **correct and must be preserved verbatim**; only the final "so the residual is harmless" step fails. **Low, not Medium**, because its incremental exposure above H-01/L-08 is a single narrow operational window inside one migration session; **not QA**, because the residual is now a real value leak rather than a redistribution note. Unique trigger and remedy preserved (pause-wrap of the out→reset→rewire→in session, already bundled with `ss9l1`/`787e9fac`) — **do not collapse into H-01.**

---

## 5. QA findings

### Q-01 — Duplicate `FlaxToken` build artifacts, no CI pin (DEDUP-009) · `17404e3df9dab691`
**QA.** Build-integrity hazard on the compile-time definition of the frozen V1's imports. Both copies are byte-identical at `f5300117` today and `grep` confirms no `vm.getCode`/`deployCode` call site exists in the first-party tree, so nothing breaks now; a future `lib/antimatter` bump drifts them silently with no check. Not tool noise, but no runtime impact ⇒ QA, not Low.

### Q-02 — `setYieldStrategy` / `finalizeAndReset` lack `nonReentrant` (DEDUP-010)
**QA — suppressed at H/M, routed, not deleted.** C4 known-invalid: *common findings from automated tools without a demonstrated H/M exploit path*. Non-exploitability is affirmatively established, not assumed: the `staked > 0` branch is unreachable behind the enforced `totalStaked == 0` gate, `finalizeAndReset` makes no external call, and OZ's guard is contract-wide. Owner-wired strategy ⇒ Law-3 *obvious*, so no footgun carve-out. **Do not mint `a8a164d4…`** — append as a note under existing QA entry `b197e829fb8468fe`. **Re-raise trigger recorded: if the empty-pool gate is ever relaxed, the `staked > 0` branch becomes reachable and this must be re-scanned.**

### Q-03 — Pause does not freeze reward minting on the migration path (MR-16-02)
**QA / informational.** No over-mint occurs — `owed` is the frozen already-accrued figure and `_updatePool` no-ops while `Migrating` — so it is a completeness gap in the pause, not a value bug. Kept visible because "reward minting continues during an incident pause" is a materially different statement now that the reward unit is redeemable. **Suppression refused:** cached KI#9's pause-exemption clause has **no text in the live source**, and live N4 covers `claim` only, never `_exitPosition`.

---

## 6. Faithfulness findings — Law 2, routed to `spec-conformance.md`

All four carry `faithfulness: true` and are reported as `F-XX` at honest severity. **None may be buried in the QA/gas bundle.** Where a faithfulness item has a security twin, the security impact is carried by the twin — the `F` label is the *spec* defect (correct the story/docs, or implement the missing requirement) and must not be double-counted as a second loss.

| Label | Severity of the deviation | Security twin | Ruling |
|---|---|---|---|
| **F-01** | **Medium-equivalent** | M-01 | story-022's headline criterion — *"the principal paths never call phUSD at all"*, with the explicit test *"with the minter role revoked, `stake`, `withdraw` and `emergencyWithdraw` all still succeed"* — is not met on the migration exit, and `CLAUDE.md:12-13` + `docs/deferred-reward-accrual-plan.md:37-38` state it **unconditionally with no migration carve-out**. The story's own requirements (a) and (b) are mutually inconsistent; the implementation executed (b) and silently dropped (a). No test exercises "migration exit with the minter revoked". Medium-equivalent because a false exhaustive safety claim in the operator-facing doc is what makes M-01's trigger non-obvious. **Not suppressible by construction** — the claim *is* that the doc is wrong, so citing the doc would be circular. **Kept separate from M-01**: distinct remedy. **Explicitly not a re-litigation** of the Law-2 framing rejected in 2026-06 — story-022's acceptance criterion did not exist then. |
| **F-02** | **Medium-equivalent** | H-01 | story-023 swapped the emissions token for one with a permissionless redemption path and is **silent** on the consequence, and it **laundered story-022's token-specific risk conclusion into a token-agnostic one** (`git diff 045d13c 2d609cb`: the *subject* was substituted `phUSD peg` → `reward-token` while the *conclusion* `not a solvency one` was preserved untouched — though that conclusion followed **from** phUSD's properties). Corroborated independently by this run's KI re-extraction: the live cap statement was rewritten token-agnostically without ever stating it is now a **dilution budget denominated in phUSD backing**. Law-3 rider: an `antimatterPerDay` calibrated under the old premise is now a phUSD dilution rate. Medium-equivalent — this is the reasoning failure that produced H-01. |
| **F-03** | **Low-equivalent** | L-04 | story-022 Autonomous Decision 3's *"nothing is stranded"* has an unstated third precondition (the old staker must remain an approved minter and unpaused indefinitely); story-023 changed the revocation model and never revisited Decision 3. Non-obvious consequence of ordinary decommissioning hygiene ⇒ in scope. |
| **F-04** | **Low-equivalent** | Q-01 | The vendored pair is the compile-time definition of the frozen V1's imports and is protected by **zero** gates; story-024 declined to pin it on a **factually wrong** premise (`manifest_count != ${#FROZEN_FILES[@]}` compares against a hard-coded array two lines above — a two-line edit to a script this repo owns keeps CI green). Compounding: the stated second line of defence does not exist — the hook guards only `PROTECTED=(initiateMigration batchMigrate depositFor)`. **Not suppressed by N9** (a different hook gap — session-project-root scoping vs. `PROTECTED` coverage). **Do not collapse** with `9abbb7b1463dbef7` / `7c99f3744421c61f`, which concern the **frozen** pair. |

**Conditioning caveat carried verbatim into the report:** all three stories resolve to `auto-complete/` — machine approval, not human review. Stories 023 and 024 were auto-completed on a review status of **`ISSUES_FOUND`**, triaged non-blocking by the same automated workflow; only 022 closed on `PASSED`; every review ran `--inline-delegation` with self-declared *"Independence: reduced"*. The acceptance criteria are authoritative **text**; their sign-off carries **no independent-human weight**.

---

## 7. Carryover, unresolved, and no-severity items

### C-1 — `dab5a65613c7af50`, **fix-pending**, MEDIUM (carried, not re-classified)
*"Idle-pool strategy adoption discards `creditedPrincipal`, shorting last withdrawers."* Not re-tripped this run and **that changes nothing** — `fix-pending` is reported regardless. Code did not change in range (`git diff` on `src/StableStakerV2.sol` has no hunk covering `setYieldStrategy`), so the bucket is **`FIX-PENDING (fix not yet landed)`**, explicitly **NOT** `⚠ INCOMPLETE FIX`. **Carryover MANDATORY and in full** — copy `reports/stable-staker/06/submissions/M-01-idle-pool-adoption-discards-credited.md` to `reports/stable-staker/16/submissions/ss6m1-C1.md`; never a pointer stub. **HTQ-14-02 HOLD stays ARMED**: do not propose `fixed`, do not close the `fixGroup` (`dbdc3ac9b9`, `969722dc9e`). No status change proposed.

### `2b9a89d29c34df41` / ss15m1 — **no severity action**
Its PoC no longer compiles after the `IFlax` → `IAntimatter` rename. **A PoC that fails to build is INCONCLUSIVE bit-rot, never evidence of a fix.** Status stays `wont-fix`, byte-identical (human-set). `REOPEN-ss15m1` stays **ARMED**. Housekeeping only: repair the PoC so a future `/recheck` is not blocked; record as `pocCaveat`.

### MR-16-01 — **not classified; stays in manual review**
Whether `CrossVersionMigrator.migrate`'s un-grossed-up `depositFor` can credit less than it pulls is not statically resolvable. The **asymmetry** half is disposed of by live N7 (an explicit design decision, quoted and confirmed present). The **residual** — can `depositFor` haircut at all? — is **not** suppressed and carries a **preliminary Medium if confirmed** (same class as ss12m1/M-07). Per memory `mock-no-op-stub-fakes-permanence`, do **not** close it by assuming the haircut cannot happen; it needs a fork/harness against a real haircutting destination strategy. Assigning a severity now would be speculation in either direction.

### DEDUP-008 — reconcile-only, no new label
Same defect as open Low `f0cb5f7cdddeea0a`; adjacent liveness half is `bda951d9f1ce1fef`. Both migrators had a NatSpec-only diff with zero executable change in range (confirmed three times), so minting a new fingerprint would mis-attribute a run-13 defect to this range. Severity unchanged at **Low** (stuck owner batch, not stuck user funds; self-limiting via pagination and the permissionless `claimTimedOut` hatch). The DEDUP-007/008 separation is upheld — only DEDUP-008's *novelty* is denied.

### Reconcile-only, severities unchanged
`d47619d29f0dcfc9` **Low** (arithmetic unchanged post-rename; AM is 18-dec so an 86400-wei/day budget stays economically absurd — **DRIFT ALERT**, a cold run will re-file it under `6aa67015…`); `59eebbf87b3d0a71` **Low**; `787e9faceb60e76e` **QA** (severity basis unchanged by story-023 — availability nuisance, no dilution leg); `f84992e9ac16ce59` **QA**; `69c7666eee33698e` / `0dca43f3156be442` untouched (human-disposed, covered by live KI#5).

---

## 8. Classification integrity checks

| Check | Result |
|---|---|
| Findings entering classification | 14 (10 DEDUP + 4 SPEC) + 3 MR + 5 reconcile-only + 1 fix-pending carryover |
| Findings dropped without a label or a visible channel | **0** |
| Severities raised above the sanitizer's carried value | 1 (`86fcf00e` QA→Low). A second raise (`ss9l1` Low→Medium) was made and **withdrawn on second-opinion review** — see §3; `ss9l1` stands at **Low**, its carried value. |
| Severities lowered below the carried value | 0 (the `ss9l1` correction withdrew this run's own raise; it did not go below the carried Low) |
| High findings | **0 (post-retraction).** ~~1, with the Medium counter-argument recorded and rebutted point-by-point~~ — the single High (`H-01`) was retracted on 2026-08-31 on a disproved mechanism and re-labelled `L-09` at **Low**. Neither the counter-argument recorded here nor the two adversarial reviews identified the actual defect in the finding. |
| Medium findings whose High case was argued and rejected | ~~1 (M-01)~~ **0** — M-01's re-weigh to Medium was itself **withdrawn** on 2026-08-31; it is `L-10` at **Low**, `wont-fix`. Its High case is disposed of a fortiori. |
| Low/QA findings whose Medium case was argued and rejected | 3 (L-01, L-04, L-05) |
| Malicious-owner vectors filed | **0** |
| Owner items classified as footguns by unlocked impact (not as centralization) | 6 (H-01, M-01, L-08, L-03, L-04, L-05) |
| `C-01` centralization labels issued | 0 — none warranted |
| Faithfulness items routed to `spec-conformance.md` rather than the QA bundle | 4 |
| Ledger writes performed | **0** |
| Human-set statuses changed | **0** |

**Open severity questions flagged for the human / severity-auditor:**
1. **~~H-01's High-vs-Medium line~~ — CLOSED 2026-08-31, and not in either direction argued here.** The finding's *mechanism* was disproved (empty-branch fast-forward, §1 banner); it is now `L-09` at **Low**, `wont-fix`. The debate below was framed entirely around whether the enabling state was default or arranged, and never questioned whether the window was banked at all. Retained as written: **H-01's High-vs-Medium line** is the run's single most consequential call. It is argued at length in §1; the rebuttal turns on the enabling state being the *default* rather than an arranged precondition. If a reviewer judges that "the owner armed a rate on an empty pool" is a genuine external requirement, Medium is defensible and the report should still lead with this finding.
2. **~~M-01's permanence branch~~ — CLOSED 2026-08-31, and in the opposite direction to the one debated here.** The question was Medium-vs-High; the owner's triage moved it to **Low**, `wont-fix`, and rejected the recommended mitigation, on the grounds that fail-loud on an attended `onlyMigrator` path is intended behaviour (banner at §2). The permanence branch stays dismissed under Law 3. Retained as written: *Held at Medium because the loss leg needs a second discretionary act whose consequence is obvious. A reviewer who weighs the compound decommissioning sequence as a single realistic runbook would reach High.* **This debate reopens only if migration becomes unattended.**
3. **L-04's stranding half** is the closest Low/Medium boundary in the QA set; it rests on revocation being reversible.
4. **H-01's premise is out of scope — but it has now been verified at the commit that matters.** The unbacked mint is `Antimatter.sol:294` at the nested pin `a5570ce` (verified 2026-08-31). The earlier note that it "was verified at top-level HEAD only" is **withdrawn**; top-level `3a96fb7` line numbers do not apply to this repository's build. No open question remains on this point.
