# Spec-Conformance Report (Law 2 — Faithfulness to Stories)

**Project:** phlimbo-ea
**Run:** phlimbo-ea-11
**Range:** `e32588d..f279c62`
**HEAD:** `f279c62` — *[story-031] Enable optimizer, disable via_ir for builds (resolves EIP-170 flag)*
**Stories in range:** story-031 (two commits: `e04136d` banking leg, `f279c62` build leg)
**Scope of this document:** Law 2 (faithfulness to stories) only. This report is **separate from the QA bundle**, which carries gas/style/Low noise. Findings here are routed at honest severity and are not buried.

---

## Headline

**story-031 is FAITHFUL and COMPLETE. This report is not an indictment of it.**

story-031 banked the phUSD mint leg (`src/PhlimboV3.sol:913`) — the last propagating reward leg in the contract. **All three legs now bank rather than propagate:**

| Leg | Line @ HEAD | Mechanism | Closed by |
|---|---|---|---|
| Stable | `:930` | `_tryTransfer` → `unclaimableStableOf` + `StableClaimFailed` | story-029 (prior baseline) |
| Promo | `:954` | `_tryTransfer` → `unclaimablePromoOf` + `PromoClaimFailed` | story-029 (prior baseline) |
| **phUSD mint** | **`:913`** | **`try/catch` → `unclaimablePhUSDOf` + `PhUSDMintFailed`** | **story-031 / `e04136d` (this run)** |

The completeness claim is not taken on the story's word. It is verified three independent ways:

- **PoC replay.** Both prior PoCs (`PoC_V3L14_phUSDMintFreeze.t.sol` for V3-M-07; `poc-CODE-09-001-promo-blocklist-principal-freeze.t.sol` for V3-M-05) now **fail with `"next call did not revert as expected"` while compiling cleanly**. A PoC that no longer compiles would be inconclusive bit-rot; these compile and their freeze assertions simply no longer trip. That is a **genuine fix**.
- **Fuzzing.** A 628k-call Foundry campaign plus 1.51M Medusa calls produced **0 counterexamples**, with the tripwire confirmed **non-vacuous** and mutation testing catching **3/3**.
- **Symbolic execution.** **9 Halmos properties PROVEN** under stated bounds — **0 timeouts, 0 counterexamples**, mutation testing **4/4**.

**No Law-1 override fires.** story-031's *own intended behaviour* was independently challenged for whether the intent, implemented exactly as specified, would introduce an exploit. It does not:

- **No unearned banking.** `unclaimablePhUSDOf` is written only in the catch at `:915`, crediting exactly `pendingPhUSDAmount` — the genuine accrual. No admin or redirect writer exists (verified: written only at `:915` and `:647`).
- **No double-claim.** All three `_claimRewards` callers realign `phUSDDebt` **unconditionally** afterwards (`stake :715`, `withdraw :761`, `claim :808`), so pending settles to zero on **both** branches. The bank is the sole record and can never be re-accrued.
- **No redistribution leak.** phUSD emission is uncapped mint-on-demand, not drawn from a distributable pool, so no `:789`-style cap exclusion is needed. Proven by `test_bankedPhUSD_notRedistributed_toCostaker`.
- **The retrieval path does not recreate the bug one level down.** `claimUnclaimablePhUSD` reverts while authority is still missing, but **only that function** reverts — the bank survives intact and the principal path stays live. That is the intended `claimUnclaimableStable` recoverability semantic, not a re-created freeze.
- **The EIP-170 claim verifies exactly.** Built at HEAD: PhlimboV3 runtime **15,979 B, +8,597 B margin** — byte-for-byte the commit's figures. EIP-170 is genuinely **RESOLVED**, not merely flagged.

**The deviations below are documentation and configuration defects, not behavioural ones.** In every case the on-chain code does what story-031 says. What is wrong is a comment, a docblock, a label, or a build-vs-deploy config — including, in one case, a defect in **the audit's own inputs**.

### Deviation summary

| Label | Story | Severity | Subject | Defect class | Security cross-ref |
|---|---|---|---|---|---|
| **F-11-01** | story-031 | QA | `MigratorV2V3.sol:252-255` + `PhlimboV3.sol:637-643` | Two documented behaviours falsified by this story | **L-01** (`1dc92a33`, Low — *disputed*) |
| **F-11-02** | story-030 (surfaced this run) | QA | `IPhlimboHook.sol:4-14` + `PhlimboV3.setHook:330-333` | Doc no longer describes the code — **lost mitigation** | **M-01** (`4f97b39e`, Medium) |
| **F-11-03** | story-031 | QA | Commit subject + 8 source comments; **+ the audit's own KI inputs** | Stale label traceability + unfalsifiable known-issues source | *(none — traceability)* |
| **F-11-04** | story-031 | *(bundled)* | `foundry.toml:6-15` | Test/deploy config divergence | **L-04** (`38aefbfb`) — **cross-ref only, no duplicate** |

---

## F-11-01 — story-031 falsified two documented behaviours it did not update: the migrator's delta-capture assumption, and PhlimboV3's own claimed bank-recoverability semantics (QA)

- **Upstream ID:** F-01 (story-faithfulness) → routed as F-11-01 · **Attached to:** CLASS-11-002 / DEDUP-11-001
- **Story:** story-031 (`e04136d`)
- **Filed against:** `src/MigratorV2V3.sol` comment at `:252-255` and `src/PhlimboV3.sol` docblock at `:637-643` — **not** against the banking logic itself
- **Security cross-reference:** **L-01** (`DEDUP-11-001` / `1dc92a33`, Low — *severity disputed*). See `submissions/qa-report.md`.

### Deviation 1 — the delta-capture comment is now false under banking

`src/MigratorV2V3.sol:252-255` states verbatim:

> ```
> // Wiring prerequisite (b): phlimboV3.setMigrator(this). Restakes the
> // principal for the user; promoDebt is set against the current
> // accPromoPerShare → no retroactive promo accrual. Any V3 auto-claim
> // (second pass only) lands here and is included in the deltas below.
> ```

**The actual behaviour.** The sentence *"Any V3 auto-claim (second pass only) lands here and is included in the deltas below"* is **FALSE for the banked case**. Under migrator delegation the beneficiary is the migrator (`PhlimboV3.stake` routes `_claimRewards(user, msg.sender)` at `:708`). When the phUSD mint fails, story-031's catch banks the accrual into `PhlimboV3.unclaimablePhUSDOf[migrator]` — **the migrator's phUSD balance never moves**. So:

1. the balance delta at `MigratorV2V3.sol:260` (`phUSD.balanceOf(address(this)) - phUSDBefore`) reads **0**;
2. `_forward` at `:268` forwards **nothing**;
3. `migrateOne` **reports SUCCESS** while the user's accrual is stranded.

story-031 defeated this comment's assumption and did not update it. *Confirmed in source at `f279c62`.*

### Deviation 2 — PhlimboV3 promises recoverability semantics the migrator bank does not have

`src/PhlimboV3.sol:637-643` (the `claimUnclaimablePhUSD` docblock) states verbatim:

> ```
>  *      the tokens were never minted, so the contract holds nothing to transfer. A
>  *      pull that fails because authority is still missing SHOULD revert, leaving the
>  *      bank intact (exactly the `claimUnclaimableStable` recoverability semantics).
> ```

**The actual behaviour.** The docblock presumes the beneficiary **can** pull, and reasons only about the pull *failing*. For the `MigratorV2V3` beneficiary **there is no pull at all**. `MigratorV2V3`'s complete external surface was enumerated exhaustively (`seedUsers:144`, `migrate:172`, `migrateOne:235`, `skipCurrent:284`, `claimUnclaimable:302`, `withdrawAll:318`, `userCount:370`) — **none** reaches `PhlimboV3.claimUnclaimablePhUSD()`. Its own `claimUnclaimable(token)` pays only from its **own** `unclaimable` mapping, which was never credited; `withdrawAll()` sweeps only balances it **holds**.

So for this beneficiary, *"leaving the bank intact"* does not mean *"preserving it for a later retry"* — it means **"leaving it permanently unreachable."** The docblock asserts a recoverability property the bank does not universally have.

### The story's "mirror the stable-leg pattern" claim does not hold in the recovery dimension

story-031's stated intent (`e04136d`) is to add the pull path *"mirroring the story-029 stable-leg bank pattern"*, and the catch block's own comment at `:909-912` asserts it *"Credits the BENEFICIARY, mirroring the stable leg below."*

**It is not a faithful mirror where it matters most.** The same structural gap exists on the story-029 stable bank (`unclaimableStableOf[migrator]` is equally unreachable by the migrator) — but that leg is **strictly better off**:

| | Stable bank (story-029) | phUSD bank (story-031) |
|---|---|---|
| Tokens exist? | **Yes** — real tokens are custodied | **No** — never minted |
| `emergencyTransfer` backstop? | **Yes** — `:354` NatSpec says so explicitly | **No** — sweeps `balanceOf`; there is nothing to sweep |

The mirror holds on the *crediting* dimension and breaks on the *recovery* dimension. That asymmetry is the whole of this deviation.

### Why QA and not higher

No functional deviation from story-031's letter: the banking works exactly as specified. These are two comments that became false. The **security** consequence is carried at its own honest severity as **L-01**; this F-label exists so the documentation legs do not die with that severity vote.

### ⚠ The Medium dissent was ADOPTED ON MECHANISM — this must survive L-01's Low

L-01 carried a four-agent severity split (3 Low vs 1 Medium). The severity-classifier adjudicated the dissent **on its merits rather than out-voting it**, and the outcome is split:

- **ACCEPTED (mechanism):** story-031 **converted a loud, self-healing failure into a silent, permanent one** on the migrator leg. Pre-fix, the mint revert bricked the pass → `migrate`'s try/catch caught it → `UserMigrationSkipped(reason)` was emitted → the cursor advanced → **the user's V2 position was untouched** → the owner (whose own docstring says they MUST read those events after every pass) restored authority and re-ran. **Loud and fully recoverable.** Post-fix: swallowed → `migrateOne` completes → delta reads 0 → V2 position consumed, V3 position created, **migration reports success, reward gone.** The fix introduced a new loss path that did not previously exist.
- **REJECTED (severity only):** the dissent's Medium rests on *"unrecoverable"*, which is **true on-chain and false in practice** — the entitlement is re-issuable at ~zero cost via `setMinter(owner,true)` + `mint(user,amount)` (`FlaxToken.revokeAllMintPrivileges` only increments `mintVersion`; it is **reversible**, not a supply lock).

**The hinge under that rejection is ANSWERED, and L-01's Low now rests on firmer footing than the classifier believed.** The classifier called *"is PhlimboV3's owner the same party as FlaxToken's owner?"* the highest-value open question in the run and could not answer it from source; it is the same standing `humanTriageQuestion` open on V3-M-07 since run-10. **Answer: same party** — proven by *executed mainnet transactions*, not by reading intent. `MigratePhlimboV1ToV2.s.sol/1/run-latest.json` shows a single EOA (`0xCad1a786…`) successfully calling, in one broadcast and all with receipt status `0x1`: `setMinter` on phUSD (**`onlyOwner` on FlaxToken**) *and* `emergencyTransfer` / `setMigrator` / `setPauser` on Phlimbo (**`onlyOwner`**). Since the FlaxToken owner-gated call **succeeded** from that address, it was phUSD's owner at that block; the Phlimbo owner-gated calls succeeding from the same address in the same run puts both roles in one hand. No `transferOwnership` exists anywhere in phStaging (count: 0); no Safe, multisig, or timelock governs these roles.

Moreover, **the owner has already exercised L-01's exact remedy on mainnet** — `MintAndSellPhUSDToDeployer.s.sol:292-294` reads `if (!ph.authorizedMinters(OWNER).canMint) { ph.setMinter(OWNER, true); } ph.mint(...)`, with landed receipts. This is **established operational practice, not theory**.

**One honest residual, carried not buried:** PhlimboV3 is **undeployed** — no deploy script, no mainnet address, zero first-party references in phStaging (which pins `lib/phlimbo-ea` at a commit predating `PhlimboV3.sol` entirely). `Ownable(msg.sender)` means V3's owner will be whoever deploys it, so same-owner is a **strong evidence-backed projection for V3, not yet a fact**. That converts the classifier's open audit question into a **one-line deploy-time runbook check**: *confirm at PhlimboV3 deployment that its owner is the same key that owns FlaxToken; if V3 is deployed under a different key, or ownership is later split, re-weigh L-01 to **Medium**.*

**The mechanism half does not die with the severity vote.** Deviation 2 above is the clearest single artefact showing the strand was **unintended rather than accepted**: the contract's own docblock promises the opposite of what happens.

### Recommendation

Correct both comments as part of whichever L-01 fix is chosen.

- **Preferred (closes the class):** add `claimUnclaimablePhUSDFor(address beneficiary)` on PhlimboV3, crediting the **recorded** beneficiary, so no address can ever hold an unreachable entry. **If this is adopted, the `:637-643` docblock becomes TRUE as written** and only the `MigratorV2V3` comment needs updating — a further point in that fix's favour.
- **Cheaper (closes only the known migrator):** a call-through on `MigratorV2V3` that calls `PhlimboV3.claimUnclaimablePhUSD()` inside a try/catch after `phlimboV3.stake(...)`, so a banked accrual is re-minted into the migrator and picked up by the existing delta+`_forward` accounting.
- **Minimal:** accept and document that the migrator-beneficiary phUSD bank is out-of-band-settled, and correct the now-false `:252-255` comment.

**MANDATORY, and owed to the dissent:** whichever fix is chosen must **restore loudness, not merely reachability**. A fix that makes the value recoverable but leaves the migration silently reporting success on a failed reward leg closes only half of what story-031 opened. `Q-01`'s reason-capture (`catch (bytes memory reason)`) is a prerequisite, and its ABI-break window is **open now and closing** — story-031 is unreleased.

---

## F-11-02 — the documentation no longer describes the code: the only warning governing hook-revert propagation is a V2-scoped docblock whose safety context story-030 deleted (QA) — **NEW this run**

- **Upstream ID:** *None* — raised during the severity-classifier's disclosure weighing; **not present in `story-faithfulness.json`**
- **Story:** story-030 (deletion of `pauseWithdraw`); surfaced by this run's story-031 review
- **Filed against:** `src/interfaces/IPhlimboHook.sol:4-14` and `src/PhlimboV3.sol:330-333` (`setHook` NatSpec)
- **Security cross-reference:** **M-01** (`DEDUP-11-002` / `4f97b39e`, **Medium**). See `submissions/M-01-hook-principal-freeze.md`.

### The spec text — a V2-scoped docblock inherited by V3

`src/interfaces/IPhlimboHook.sol:4-14` states verbatim:

> ```
>  * @title IPhlimboHook
>  * @notice Generic hook interface invoked by PhlimboV2 after stake, withdraw, and claim actions.
>  ...
>  *      Hooks fire AFTER all internal state mutations and external token transfers complete,
>  *      inside PhlimboV2's `nonReentrant` guard. The owner of PhlimboV2 is trusted to set
>  *      non-malicious hooks; a reverting hook will revert the outer call.
> ```

**It names PhlimboV2 three times and never mentions V3** — yet V3 imports and relies on this interface. *Verified in source at `f279c62`; file read in full.*

### The actual behaviour — truth value unchanged, meaning silently degraded

The sentence *"a reverting hook will revert the outer call"* is a **mechanism**. What it does **not** state is the **consequence**, and the consequence is what changed between the contract the docblock names and the contract that imports it.

On PhlimboV2 — the only contract the docblock names — a reverting hook was **survivable**, because a second, **independently-held** privileged remedy existed: the `pauser` role could pause, which enabled the hook-exempt `pauseWithdraw`. `PhlimboV2.sol:276-278` records that exemption deliberately and in terms:

> ```
>  * @notice Allows users to withdraw their staked phUSD when contract is paused
>  * @dev Emergency exit mechanism — strictly msg.sender-only. NOT delegatable to
>  *      migrator. Does NOT claim rewards or update pool. Does NOT invoke any hook.
> ```

**⚠ Stated precisely, because the tempting overstatement is wrong:** this was **never** a user self-rescue. `pauseWithdraw` is `whenPaused` (`PhlimboV2.sol:280`) and `PhlimboV2.pause()` is gated to the `pauser` role (`:270-271` — `require(msg.sender == pauser, "Only pauser can pause")`). On **both** V2 and V3, users have **zero unilateral escape** from a reverting hook; both require one privileged transaction. The true V2→V3 delta is therefore **narrower than "escape vs no escape"** — it is **two independently-held privileged remedies vs one**:

| | PhlimboV2 | PhlimboV3 |
|---|---|---|
| User unilateral escape | **No** | **No** |
| Privileged remedies | **Two** — `pauser` pauses → hook-exempt `pauseWithdraw`; **or** owner `setHook(0)` | **One** — owner `setHook(0)` only |

**story-030 deleted `pauseWithdraw` from V3 and left the docblock untouched.** Verified at `f279c62`: **zero** occurrences of `pauseWithdraw` and **zero** of `emergencyWithdraw` in `src/PhlimboV3.sol` (untruncated `grep -c` on the full file); PhlimboV2 retains it (2 occurrences).

**The sentence's truth value never changed. Its safety context did, silently.** The identical words that described a mechanism backed by redundant remedies on V2 now describe one whose sole remedy is concentrated in a single owner key on V3 — a genuine reduction in remedy redundancy, and the docblock that governs it still describes only V2. An owner is entitled to read a documented behaviour in the safety context the document was written for.

### The warning is absent at the point of the load-bearing action

`src/PhlimboV3.sol:330-333` — the NatSpec an owner reads at the moment of the one action this finding turns on — is, **in full**:

> ```
> /**
> * @notice Sets the hook contract invoked after stake/withdraw/claim.
> * @dev Accepts address(0) to disable the hook.
> */
> ```

**No warning at all.** Nothing about revert propagation, nothing about the absence of a hook-exempt exit, nothing about the consequence for principal. *Verified in source at `f279c62`.*

### It also falsifies an asserted invariant

The contract-profile asserts **INV-01** (*"A user's principal is never frozen by a failing reward payout"*) **HOLDS** at `f279c62`. It survives only under a narrow literal reading of *"reward payout"*. The property that **three consecutive stories (027, 029, 031) were spent buying** does **not** hold in the hooked configuration. That is a conformance gap between the protocol's asserted invariants and its actual guarantees, and it materially amplifies M-01's non-obviousness: an owner who watched those three stories land and reads that invariant will reasonably believe principal cannot freeze on a reward-path failure.

**Recommend the profile be corrected to `HOLDS-EXCEPT-HOOKED-CONFIG`** so a future run does not read the green as clearance.

### Why this is routed here rather than folded into M-01

Two reasons, and the second is a matter of honesty:

1. **It is independently actionable.** Even if M-01's try/catch fix is declined, the documentation must be corrected — and correcting it is nearly free.
2. **It is the honest counterweight to M-01.** The propagation **is** documented somewhere, and this F-label is where that fact is recorded rather than quietly omitted from the Medium's write-up. M-01 must be read as an **inherited-mechanism / lost-mitigation** finding, **not** as "the protocol hid a trap." The disclosure is real, accurate, and names the mechanism in plain words. What it does not do is address the case actually reported: the docblock's semicolon binds the propagation to the **malicious**-hook frame ("the owner is trusted to set *non-malicious* hooks; a reverting hook will revert the outer call") — and the malicious-hook case is **Law-3 trusted and expressly out of scope**. The case reported is a **benign, correctly-written hook that begins reverting later for a third-party reason**. The disclosure is silent on it.

### V3-M-06 — this finding does NOT discharge its obligation, and its `fixed` status STANDS

**Recorded because an earlier draft of this report claimed the opposite. The claim was wrong and is retracted.**

V3-M-06 (`efdc3c4f`, **`fixed`** in the ledger, 2026-07-16) carried a run-10 verification obligation: *"confirm the removal [of `pauseWithdraw`] does not strand stakers who could previously escape **during a `beginFlush` pause**."* An earlier draft asserted M-01 discharges it and that *"the answer is not clean."* **Both halves are incorrect:**

1. **Category error.** The obligation is scoped to the **`beginFlush` pause window** — a shipped, hook-independent, routine promo-rotation operation. M-01 concerns a **hooked** configuration that requires `setHook` and is inert today. M-01 has nothing to say about the flush window and cannot discharge an obligation scoped to it.
2. **The underlying hazard is REFUTED.** Stakers **are** frozen during a flush — verified: `beginFlush` (`:468`) calls `_pause()`; `stake`/`withdraw`/`claim` are all `whenNotPaused` (`:694`/`:739`/`:789`); `unpause` (`:309`) reverts while Flushing (*"Cannot unpause while flushing"*); the only exits are `finalizePromotion` or `abortFlush`, both `onlyOwner`. **But that freeze is intended, documented, and necessary.** `beginFlush`'s own NatSpec states the design premise: *"from this point every user's `amount` and the staker set are frozen"* — and that freeze is precisely what makes the flush cursor's iteration over `_stakers` sound (`finalizePromotion` requires `flushCursor == _stakers.length()`). Permitting a mid-flush exit is exactly what V3-Q-02 recorded as a defect and what V3-M-06 recorded as an over-emission path. **Removing `pauseWithdraw` did not create a hazard here; it closed two.** Under Law 3 the freeze is an obvious, disclosed consequence of a deliberate pause — trusted, not a footgun.

**V3-M-06's obligation (a) discharges CLEAN on its own grounds, and its `fixed` status stands.** Recorded so a future run does not re-raise *"stakers cannot exit during a flush"* as a finding — it is intended design with an in-source rationale.

**The distinction that makes both statements true at once, kept crisp:** story-030's removal of `pauseWithdraw` **IS** load-bearing for M-01 — it deleted the hook-exempt exit, voiding V2-L-09's Low rationale on V3. It is **NOT** a defect with respect to the **flush window**, which was always meant to freeze exits. M-01's hook-freeze hazard is **independent** of the `beginFlush`-pause question. **F-11-02's content is the documentation deviation** — the V2-scoped docblock and the silent `setHook` NatSpec — **and it stands on its own without any V3-M-06 claim.**

Separately, and still accurate: the run-11 propose-fixed on **V3-M-05** and **V3-M-07** must **NOT** be recorded as establishing *"principal can never freeze in PhlimboV3."* Both closures are correct for their **own** stated scopes (the reward legs); **neither reaches the hook leg**, and M-01 is the standing counterexample.

### Recommendation

Whether or not the try/catch lands:

1. **Rewrite `IPhlimboHook`'s docblock** to be contract-neutral, to state the **consequence** and not just the mechanism, and to distinguish the malicious-hook case (trusted, out of scope) from the benign-hook-breaks-later case (the real hazard).
2. **Add the warning to `PhlimboV3.setHook`'s own NatSpec**, where the owner will actually see it.
3. **Reconcile INV-01's statement** with the hooked configuration.

---

## F-11-03 — stale label traceability, and an unfalsifiable known-issues source in the audit's own inputs (QA)

- **Upstream ID:** F-03 (story-faithfulness) → routed as F-11-03 · **also bundled as `Q-03`** (`0df1d899`) in the QA report
- **Carries:** **V3-F-06** (`aedfcdb0`, **open**) context
- **Fingerprint impact:** **none** — severity is not part of the hash, so ledger reconciliation is unharmed

### Leg 1 — the in-code provenance markers cite a retired label

story-031's commit subject (`e04136d`) reads:

> `[story-031] Bank failed phUSD mint leg in _claimRewards (V3-L-14/V3-M-05 residual)`

and **eight** source/interface comments cite the finding as *"audit-09 V3-M-05 / V3-L-14"* (`src/PhlimboV3.sol:168-169, 631, 904`; plus five NatSpec sites in `src/interfaces/IPhlimboV3.sol` — `PhUSDMintFailed`, `UnclaimablePhUSDClaimed`, `claimUnclaimablePhUSD`, `unclaimablePhUSDOf`, `totalUnclaimablePhUSD`).

**`V3-L-14` is the stale pre-reclassification label.** run-10 promoted it to **V3-M-07** (Low → Medium, ledger field `reclassifiedFrom: "V3-L-14"`, fingerprint unchanged). **No code comment mentions V3-M-07**, so the source is un-greppable from the current label.

Two consequences worth stating:

- **`V3-L-14` is NOT a separate live ledger entry** — it is the pre-reclassification label *of* V3-M-07. The commit subject's *"V3-L-14/V3-M-05 residual"* therefore names **one** finding by its stale label, plus its parent. A future agent grepping for `V3-L-14` as a distinct finding will find nothing and may wrongly conclude the marker is dangling.
- **The subject understates what was fixed.** It reads as closing a Low when it in fact closes a **Medium** — and one that had been triaged **wont-fix**. Minor, but it makes an audit trail read as less significant than it was, which matters given the wont-fix-that-got-fixed anomaly this run surfaced.

**Recommendation:** in any future touch of these comments, cite **`V3-M-07 (ex V3-L-14)`** so the in-code marker matches the ledger label. No code change warranted on its own account.

### Leg 2 — ⚠ the project's known-issues source does not describe the code being audited (V3-F-06, open)

This is a **live spec-conformance defect in the audit's own inputs**, and it is stated as such.

The project's registered `knownIssuesSource` is `lib/phlimbo-ea/CLAUDE.md`. Verified this run by **untruncated full-file greps**:

| Search term | Occurrences in `lib/phlimbo-ea/CLAUDE.md` |
|---|---|
| `known issue` | **0** |
| `PhlimboV3` | **0** |
| `MigratorV2V3` | **0** |

**The file has no Known-Issues section at all, and zero mentions of either contract under audit.** The 10 cached registry KIs are **V1-era** and **not re-derivable from source** — they cannot be checked against anything. This **blocked all KI-based suppression this run**, correctly: the sanitizer performed **zero** KI suppressions and explicitly **rejected 5** candidate suppressions rather than leaving them unexamined.

**Sharpest illustration — cached KI-4 describes deleted code:**

> **KI-4:** *"pauseWithdraw does NOT claim rewards or update pool (emergency exit mechanism by design)"*

`pauseWithdraw` has **ZERO occurrences in PhlimboV3.sol** (verified above). **story-030 deleted it.** KI-4 documents, as intentional design, a function that no longer exists in the contract under audit.

**A stale KI describing deleted code was one careless step from suppressing this run's only Medium — whose entire premise is that deletion.** M-01 exists *because* the hook-exempt exit is gone; KI-4 would have suppressed it by asserting that exit is present by design. The sanitizer caught this independently and named the inversion precisely: reaching for KI-4 here *"would suppress a Medium using a note about the very mitigation whose absence creates it."*

That two agents, working independently and never comparing notes, both located the crux in the same place is corroboration of M-01's mechanism. It is also a warning about the input set: **the KI block must stay in force until the known-issues source is re-extracted from the current code.**

**Recommendation:** re-extract known issues from the V3 source and populate a real Known-Issues section in `lib/phlimbo-ea/CLAUDE.md`. Until then, **KI-based suppression must remain blocked** — as it was this run. Purge or re-derive KI-4 specifically; it is affirmatively false against `f279c62`. Tracked as **V3-F-06** (`aedfcdb0`, open).

---

## F-11-04 — tested bytecode is not deployable bytecode (cross-reference only)

- **Upstream ID:** F-02 (story-faithfulness) · **Bundled as:** **L-04** (`38aefbfb`) in `submissions/qa-report.md`
- **Status here:** **cross-reference only — the full write-up is in the QA bundle and is not duplicated.**

story-031's build leg (`f279c62`) pins `via_ir = false` for **every build this repo performs**, while the story's own text contemplates a `via_ir` **production** deploy (*"Deploying staging/mainnet with via_ir remains safe"*). The established deploy vehicle — `lib/phoenix-phase-2-staging` — sets `via_ir = true` and compiles phlimbo-ea **from source**. The two pipelines emit materially different bytecode (15,979 B legacy vs 14,529 B via_ir — a ~9% codegen delta), so the 365-test suite never executes the bytecode that would actually ship.

**Recorded here as a spec/config conformance note** because the gap is in the story's **own reasoning**, not its implementation: it justifies `via_ir=false` with an argument covering **one specific divergence** (timestamp caching under `vm.warp`) and then generalises to *"deploying with via_ir remains safe"* without validating the via_ir-compiled bytecode at all. It is **not tagged `faithfulness: true`** — the implementation does exactly what the story says, so there is no behavioural deviation. It is an **assurance** gap.

**Two corrections carried forward, both in the author's favour:**

1. **PROSPECTIVE, not live.** PhlimboV3 is **not yet wired into phStaging** — no PhlimboV3 reference exists anywhere in that repo. This is a hazard to close **before** the V3 deploy story lands, which is also when it is cheapest to close.
2. **EIP-170 is genuinely resolved, and independent of `via_ir`.** It is resolved by the **optimizer**; the via_ir build fits even more comfortably (14,529 B, **+10,047 B** margin vs +8,597 B). **`via_ir=false` is NOT load-bearing for EIP-170** and can be revisited freely without reopening the size problem — which materially cheapens the preferred fix.

The author is right on the substance: the `via_ir` + `vm.warp(block.timestamp + X)` diagnosis is a real, well-known solc/cheatcode interaction rather than a contract defect, and the on-chain safety argument is sound (`block.timestamp` **is** constant within a real transaction, so *this* divergence provably cannot manifest on-chain). See **L-04** for the full analysis and fix options.

---

## Reconciliation notes — read before triage

### Label mapping

| This report | Security finding | Fingerprint | Severity | Location |
|---|---|---|---|---|
| F-11-01 | **L-01** | `1dc92a33` | Low *(disputed — Medium dissent adopted on mechanism)* | `submissions/qa-report.md` |
| F-11-02 | **M-01** | `4f97b39e` | Medium | `submissions/M-01-hook-principal-freeze.md` |
| F-11-03 | *(Q-03)* | `0df1d899` | QA | `submissions/qa-report.md` |
| F-11-04 | **L-04** | `38aefbfb` | Low | `submissions/qa-report.md` |

### Two story-faithfulness legs were examined and deliberately NOT routed here

Recorded so a future run does not mistake their F-provenance for an unreported faithfulness leg:

- **F-02 → L-04** (`CLASS-11-005`): not tagged `faithfulness: true`. The implementation matches the story exactly; the gap is in the story's reasoning. Cross-referenced above as F-11-04.
- **F-03 → Q-03** (`CLASS-11-008`): a stale **audit label** in provenance comments is documentation drift, not a deviation from any story's stated **behaviour**. C4 places "issues with comments" squarely in QA. Carried here as F-11-03 because its second leg (V3-F-06) is a genuine conformance defect in the audit's inputs.

### Proposed ledger movements (PROPOSALS ONLY — not applied)

Both are **human-only**: `fix-pending` is never auto-closed, and `wont-fix` likewise requires a human to move. They are proposed **separately, on separate evidence**, honouring V3-M-07's *"do not conflate or collapse"* triage instruction.

- **V3-M-05** (`69f8b29a`, `fix-pending` → `fixed`, at `e04136d`) — all three legs banked; M-05's own PoC no longer reproduces; run-10's `incompleteFixFlag` closure condition (*"verify the phUSD leg is banked"*) is now **satisfied**.
  `/ledger phlimbo-ea fixed 69f8b29a043da5933c6e3adfe7bdf8d443bb4ee98cb36459cd998c5776c64df8`
- **V3-M-07** (`27e83ab2`, `wont-fix` → `fixed`, at `e04136d`) — the owner triaged this wont-fix on 2026-07-16 and then **fixed it anyway the same day**, implementing V3-M-07's own recommendation verbatim.
  `/ledger phlimbo-ea fixed 27e83ab27be4abb142f259f554a61142a592989b180054d1bd3c9dde1904d5c8`
  **Also record on this entry:** its standing `humanTriageQuestion` from run-10 — whether the Flax authority is *"a separate ecosystem operator (as the mutable-dependency structure suggests)"* — is now **ANSWERED: it is not** (same EOA; see F-11-01's owner-identity evidence). V3-M-07's run-10 Medium rested on the premise that the trigger is *"an EXTERNAL shared-ecosystem-token authorization revocation PhlimboV3 does not control"*; that premise is **refuted**, which resolves the entry to its own *"Low is defensible"* branch and **retroactively vindicates the owner's wont-fix triage**. Worth recording so the question stops recurring across runs. It does not change the propose-fixed above — the leg is fixed regardless of what severity it should have carried.

### ⚠ V3-L-15 must NOT be closed as written (incomplete-fix hazard)

**V3-L-15** (`166e6393`, open, Low) recommends *"add a forwarder that calls `claimUnclaimableStable`/`Promo`"*. That would close the stable and promo legs and **leave the phUSD leg stranded** — an incomplete fix that reads as done, the failure mode this project ranks second only to a regression. **Widen V3-L-15's recommendation to also cover `claimUnclaimablePhUSD`.**

### ⚠ The Tier-3 green is silent on these findings, not exculpatory

- `invariant-results` explicitly records *"Reverting IPhlimboHook not modelled (no hook set)"*. The 628k Foundry + 1.51M Medusa campaign says **nothing** about M-01 / F-11-02 and must not be cited as clearing it.
- `coverageGaps` records that **migrator-as-beneficiary is not covered**. story-031 shipped with tests that are **structurally incapable of failing on its own new loss path**: the 5 new tests in `PhlimboV3PhUSDMintBankTest` declare `address migrator = address(0x5)` but **never call `phlimbo.setMigrator(...)`** — the address is used only as a funded ordinary staker, so every test exercises `beneficiary == msg.sender == user`, the one routing where the pull always works. **Add a test that wires a CONTRACT migrator via `setMigrator`.**
- All Tier-3 results are evidence about the **legacy-codegen (`via_ir=false`) build only** (`invariant-results.buildProvenance`) — i.e. the entire campaign inherits F-11-04's gap. That does not weaken the results for this run's purposes, but **no Tier-3 evidence in this run speaks to the deployed bytecode.**
