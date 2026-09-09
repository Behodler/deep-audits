# Spec Conformance Report — Law 2 (Faithfulness to Stories)

**Project:** `stable-yield-accumulator`
**Run:** `stable-yield-accumulator-14`
**Commit audited:** `f7041304e4a71cc2325cf406974f5cc16a5b5322` (`f704130`)
**Range:** `0fef726..f704130` (regression scan)
**Stories in range:** `story-026` — nudge-share routing through `NudgeStreamer`
**Story sources consulted:** the five `[story-026]` commit bodies (`3e1259b`, `e7f8a45`, `2dc2426`, `b14522d`, `f704130`), the contract-level NatSpec block `## Nudge share routing (story 026)` (`src/StableYieldAccumulator.sol:57-101`), `src/interfaces/IStableYieldAccumulator.sol`, and the project `CLAUDE.md`.

This report is **separate from the QA bundle**. Faithfulness is Law 2 in the audit hierarchy — a deviation between what a story says and what the code does, or a story whose own intent is unsafe. It is not gas or style noise and must not be read as such.

---

## Verdict summary

| ID | Subject | Law | Severity | Security cross-ref |
|---|---|---|---|---|
| **F-01** | story-026's own intent makes an external, post-deploy-zero contract a hard precondition of `claim()` | **1** (overriding 2) | Low | design origin of **M-01** |
| **F-02** | In-source NatSpec self-certifies the exposure as "not an audit finding", and over-claims completeness | 2 | Low | mutually reinforcing with **M-01** |
| **F-04** (note) | SYA NatSpec `:62` restates the streamer's upstream capture-size over-claim | 2 | Low — filed as **L-05 (run-14)** / ledger **L-11** | routed to `phoenix-nft-staking`; related to `858e9e80` (wont-fix) |
| **POS-001** | story-026 closes a real pre-existing atomic claimer self-rebate | — | Positive result | — |

**Implementation conformance for story-026: FAITHFUL on every explicit acceptance criterion.** Seven criteria were checked and all seven are satisfied. Neither F-01 nor F-02 alleges that the developer failed to build what was asked for.

---

## F-01 — story-026's own intent is the exposure (Law 1 overrides Law 2)

- **Severity:** Low
- **Type:** `story-unsafe` — no deviation; the story's intent is what is flagged
- **Location:** [`src/StableYieldAccumulator.sol#L594-L599`](https://github.com/Behodler/stable-yield-accumulator/blob/f7041304e4a71cc2325cf406974f5cc16a5b5322/src/StableYieldAccumulator.sol#L594-L599) — `claim`
- **Fingerprint:** `36c3e70ecc6e000207c136f6c6529ead34eb186b54140ba835c9d8cf488f9482`
- **Story:** `story-026`
- **Cross-reference:** **M-01 (run-14)** / ledger **M-02** (`setRewardToken` brick) — F-01 is the design decision that makes that brick possible.

### The spec text

story-026, commit `2dc2426`:

> "Replaces the direct `safeTransfer(nudge, nudgeAmount)` with an inline `forceApprove` + `INudgeStreamer.collectNudge(nudge, rewardToken, nudgeAmount)` pull"

> "**The old transfer is removed, not kept as a fallback.**"

> "The streamer requirement is scoped to the live-donation branch, so a split-0 accumulator still claims with no streamer set."

Restated in-source at `src/StableYieldAccumulator.sol:61` and `:69-70`:

> "That leg has been **REMOVED, not kept as a fallback**."

> "Once a nudge share is actually payable there are three failure modes, all deliberate and loud (**there is no try/catch envelope here**)"

### The actual behaviour

The implementation is exactly what the story specifies:

```solidity
if (nudgeAmount > 0) {
    address streamer = nudgeStreamer;
    if (streamer == address(0)) revert NudgeStreamerNotConfigured();
    IERC20(rewardToken).forceApprove(streamer, nudgeAmount);
    INudgeStreamer(streamer).collectNudge(nudge, rewardToken, nudgeAmount);
}
```

No `safeTransfer(nudge, ...)` survives anywhere in `src/`. There is no envelope, no degradation path, and no owner-settable bypass short of disabling the split entirely.

The consequence is that **`claim()` — SYA's only permissionless entry point, and the sole mechanism converting yield-strategy surplus into phlimbo rewards — has a hard liveness dependency on state held in a separately-deployed, owner-configured contract whose post-deploy default is unset.** `nudgeStreamer` is a setter-only field (deliberately not a constructor argument, because the streamer is deployed later), so `address(0)` is its state at `t=0`. An accumulator whose owner enables `nudgeSplit > 0` before calling `setNudgeStreamer` has a fully bricked claim rail; the conversion pipeline and every downstream `ClaimArbitrage` run stall until the owner acts.

Verified constructively (Tier-3 `test_P1_D`): a payable-nudge claim in that state reverts `NudgeStreamerNotConfigured()` — selector `0xb94406b2`. The second mode, `NudgeStreamer__NotRegistered()` (`0xd62cbfe8`), is reachable whenever `streams[nudge][rewardToken].duration == 0`.

### Why this is filed under Law 1, not as a Law-2 deviation

Nothing the story asked for was omitted. This is the one case where the *absence* of a fallback is itself the instruction. Law 2 in this repository's hierarchy is explicit that **Law 1 overrides**: where a story's own intended behaviour introduces an exposure, the unsafe story is flagged rather than the faithful implementation blessed. F-01 is that flag.

### Conformance credit — stated explicitly, because it is a credibility point

**The implementation is FAITHFUL.** Every acceptance criterion in the `[story-026]` commit bodies is satisfied:

1. `safeTransfer` replaced with `forceApprove` + `collectNudge` — satisfied at `:594-599`.
2. The old transfer removed, not kept as a fallback — satisfied; no `safeTransfer(nudge, ...)` remains in `src/`.
3. `nudge` stays the sink; setter-only `nudgeStreamer` added, rejecting `address(0)` with `ZeroAddress` and emitting `NudgeStreamerUpdated` — satisfied at `:469-475`.
4. Requirement scoped to the live-donation branch; split-0 still claims — satisfied; the guard sits inside `if (nudgeAmount > 0)`, proven by `test_claim_SplitZero_RequiresNoStreamer`.
5. The phlimbo `collectReward` leg, `approvePhlimbo` and the `NudgeNotConfigured` guard untouched — satisfied; the diff confirms none of the three changed.
6. No residual allowance lingers — satisfied; `collectNudge` `safeTransferFrom`s exactly `amount`, and the test asserts `allowance == 0` post-claim.
7. TDD discipline, mandated by the project `CLAUDE.md` — satisfied, and cleanly. **RED `e7f8a45` touches `test/` only; GREEN `2dc2426` touches `src/` only. Zero test lines were edited in the GREEN commit, so no goalposts were moved and every RED assertion stands as written.** The RED suite deploys a real `NudgeStreamer` rather than a mock, so the assertions are against genuine streamer semantics.

Two further regression checks cleared: story-026 did not regress the `NudgeNotConfigured` guard, nor the nudge-before-phlimbo subtraction ordering (`phlimboAmount = actualPayment - nudgeAmount`), both of which survive verbatim.

**The defect is in the story's intent, not the developer's execution.**

### Severity — Low, and why

The exposure is **loud, pre-transactional, and binds at `t=0` before the rail carries value**. It fails closed: Tier-3 Property 3 verified that a nudge-leg revert rolls back the entire `claim()` — the claimer's payment, the skimmed surplus, the NFT burn and the streamer deposit all revert together, so no partial-state value loss is reachable. And `setNudgeSplit(0)` is a **unilateral, SYA-only escape** requiring no external coordination: the owner can always disarm the dependency from the contract under audit.

This finding stands on its own merits and is **not** merely the design shadow of M-01 — the classifier's double-counting note was struck in `review/severity-audit-revised.json`.

### Reopen trigger — `REOPEN-SWING-001`

The Low rests on a **shared-owner reading**, which is convention plus functional necessity, not an on-chain artefact and not code-level enforcement. Both `NudgeStreamer` and `BatchNFTMinterMultiToken` are **undeployed** at `f704130` and take a free `constructor(address initialOwner) Ownable(initialOwner)`.

- **`REOPEN-SWING-001`** — if either is deployed with an owner key distinct from the SYA owner `0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6`, **reopen at Medium** (cross-party coordination outage). Machine check at deploy time, before the split is enabled: `owner() == 0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6` on both.
- **`REOPEN-SWING-001b`** — if ownership of SYA, the streamer or the batch minter is later transferred to a separate party, multisig quorum, or timelock that materially lengthens the repair window, **reopen at Medium**.
- **`REOPEN-F01-c`** — if a degradation path is ruled out permanently *and* the rail is expected to carry material value with no monitoring on `claim()` revert rates, **reopen at Medium**.

### What this finding asks for

**An owner decision, not a code fix.** Either:

- accept the mandatory-dependency design and **record the acceptance as a real triage artefact** — a `/ledger` status or a `registered-projects.json` `designDecision` (see F-02, which is precisely about the absence of such an artefact); or
- restore a bounded degradation path — a `try/catch` envelope routing the nudge share to phlimbo on streamer failure, or an owner-settable `nudgeFallbackToPhlimbo` flag.

If accepted as-is, add a `nudgeRailArmed()` view that probes the full four-step precondition, so ops can verify the runbook before enabling the split.

---

## F-02 — the NatSpec self-certifies against audit, and over-claims completeness

- **Severity:** Low
- **Law:** 2
- **Location:** [`src/StableYieldAccumulator.sol#L69-L79`](https://github.com/Behodler/stable-yield-accumulator/blob/f7041304e4a71cc2325cf406974f5cc16a5b5322/src/StableYieldAccumulator.sol#L69-L79) — contract-level NatSpec (added in the GREEN commit `2dc2426`). The self-certifying sentence is at **`:75-77`**; the finding record and upstream scan artefacts cite it as `:73-75`, which is off by two lines against `f704130`. The quoted text below was re-read at HEAD and is authoritative.
- **Fingerprint:** `12d4ec2676c5dd490def7e8dd4651080f5e8ebe9bf687ac591d947df479fe0a5`
- **Cross-reference:** **M-01 (run-14)** / ledger **M-02** — mutually reinforcing; see below.

### Leg 1 — a suppression written into the artefact under audit

The exact text at `:75-77`:

> "2. If the streamer is set but ops forgot `registerStream(nudge, rewardToken, duration)` on it, every `claim` reverts `NudgeStreamer__NotRegistered()`. **That is the accepted consequence of the mandatory-streamer decision, not an audit finding.**"

**The verified fact:** no story artefact records any such acceptance. The story-faithfulness scan read **all five `[story-026]` commit bodies in full** — `3e1259b` (submodule wiring), `e7f8a45` (RED tests), `2dc2426` (GREEN), `b14522d` (gas snapshot), `f704130` (submodule branch fix). `2dc2426` states the design *facts* ("removed, not kept as a fallback"; "scoped to the live-donation branch") but **records no acceptance decision anywhere, and nowhere pre-adjudicates the exposure as a non-finding.** The project `CLAUDE.md` is **silent on the nudge rail entirely** — it documents the accumulator's purpose and the `ClaimArbitrage` accounting and nothing else. `registered-projects.json` carries no matching `designDecision`. The ledger has no entry for the rail.

The sentence is therefore an **unsupported in-source claim traceable to no story decision** — a suppression written into the artefact under audit. It is the only place in the repository where the exposure is dispositioned, and it disposes of it by asserting it is out of audit scope.

**Circularity ruling — unconditional.** Suppressing this finding on the strength of the sentence it objects to would let the code under audit adjudicate a finding against itself. The sanitizer's `selfSuppressingClaimRuling` is concurred with in full: the comment is **not** a known-issues artefact, no severity discount was applied on its strength, and no confidence reduction was taken from it.

**The sanitizer explicitly declined to honour this comment. Had it been honoured, both M-01 and F-01 would have been removed at sanitization — a Law-1 violation.** That is what makes this Low rather than informational: it is an active suppression attempt that was **load-bearing for this run**.

### Leg 2 — a false completeness claim that manufactures a footgun

The same block asserts a **closed** enumeration at `:69-70`:

> "Once a nudge share is actually payable **there are three failure modes**, all deliberate and loud (there is no try/catch envelope here)"

naming only `setNudgeAddress` as a re-arm trigger at `:78-79`:

> "3. Repointing the sink via `setNudgeAddress` re-arms exactly that failure mode: register the new `(sink, rewardToken)` pair on the streamer FIRST."

followed by a four-step ops runbook at `:81-88` (`setNudgeTokenWhitelist` → `registerStream` → `setNudgeAddress`/`setNudgeStreamer` → `nudge.setNudgeStreamer`).

**The actual behaviour:** `NudgeStreamer` keys its buffer on the **pair** `streams[nudge][rewardToken]`. `setRewardToken` ([`:417-420`](https://github.com/Behodler/stable-yield-accumulator/blob/f7041304e4a71cc2325cf406974f5cc16a5b5322/src/StableYieldAccumulator.sol#L417-L420)) rewrites the **second key** of that identical lookup:

```solidity
function setRewardToken(address _rewardToken) external onlyOwner {
    if (_rewardToken == address(0)) revert ZeroAddress();
    rewardToken = _rewardToken;
}
```

A bare assignment with a zero-address check, no rail guard, and no event. After it, `streams[nudge][newRewardToken].duration == 0`, so every subsequent claim with a payable nudge share reverts `NudgeStreamer__NotRegistered()` (`0xd62cbfe8`) — **the identical brick the document attributes solely to `setNudgeAddress`**. It appears in neither the three-mode enumeration nor the four-step runbook.

### Why F-02 and M-01 are mutually reinforcing

M-01 (ledger M-02) is a Medium: total, permanent-until-cured outage of the only permissionless entry point, proven constructively with a direct storage assertion that the old `(sink, oldReward)` stream survives with `duration == DURATION` while `(sink, newReward)` has `duration == 0` — nothing broke, **the key moved**.

M-01 is in scope under Law 3 as a **non-obvious owner footgun**, and the reason it is non-obvious is exactly this NatSpec. **An owner following the documented runbook to the letter still bricks the rail.** The document's false completeness claim is precisely what converts an ordinary, competent ops action into a surprise. Remove the claim and the footgun becomes an ordinary documented ordering constraint; leave it and the doc actively misleads.

F-02 is therefore not a duplicate of M-01: M-01 is the code path and its availability impact, F-02 is the documentary defect that makes the path non-obvious *and* the suppression clause that would have hidden both.

### Impact

None to assets or availability. The impact is on **audit assurance**: the comment, if honoured, removes a verified availability defect from the record.

### Recommendation

Either record the acceptance as a **real triage decision** — a `/ledger` status or a `registered-projects.json` `designDecision` — and delete the self-exculpating sentence, or drop the claim. Do not leave the adjudication in the source comment.

Separately, correct the completeness claim: add `setRewardToken` as failure mode 4 and to the ops runbook, or gate it on a registered `(nudge, _rewardToken)` stream when `nudgeSplit > 0`.

**Triage-status guidance (Law 1).** If the owner's intent is "accepted, we will fix it", the correct ledger status is **`fix-pending`, never `acknowledged`**. `acknowledged` suppresses the finding from every future scan precisely when someone is depending on the fix landing.

**Do not auto-suppress or auto-close anything on the strength of `src/StableYieldAccumulator.sol:69-79` (the story-026 failure-mode NatSpec block). Acceptance must be a real `/ledger` triage decision.**

---

## Note — F-04 / L-05 (run-14), ledger L-11: the capture-size restatement

Reported in full as **L-05 (run-14)** / ledger **L-11**; recorded here because its origin is a story-026 conformance question.

SYA's contract NatSpec at [`:60-64`](https://github.com/Behodler/stable-yield-accumulator/blob/f7041304e4a71cc2325cf406974f5cc16a5b5322/src/StableYieldAccumulator.sol#L60-L64) restates the streamer's own claim. The upstream text, `lib/phoenix-nft-staking/src/NudgeStreamer.sol:20-24`:

> "Buffers bursty donations per `(batchMinter, token)` and streams them linearly to zero over a configured `duration`, so that whoever calls `batchMint` right after a burst **can no longer capture a disproportionate share of the reward pot**."

**The actual behaviour:** the streamer throttles the **arrival rate** of donated value; it does not bound any single batcher's **share** of what has arrived. `pullPendingStream` settles the full accrued amount to whichever `batchMinter` calls it, and `batchMint` then consumes the pot it finds. Below a demand threshold — whenever `batchMint` calls are sparse relative to `duration` — **one batcher still captures 100%** of everything accrued since the last flush. Streaming converts an *instantaneous* winner-take-all capture into a *delayed* winner-take-all capture of the same total; it does not divide the pot. The property asserted unconditionally holds only in the high-frequency limit.

**Scoping.** SYA's own story-026 text makes only the weaker and **true** claim — "the batch-minter (`nudge`) receives a smooth linear stream instead of a lumpy push" — which the code does deliver. The **root cause is in `phoenix-nft-staking`, out of scope for this project**, and is related to ledger entry `858e9e80` (wont-fix). **Do not relitigate `858e9e80` from here** — this is donor-side evidence bearing on its residual, nothing more. It is also distinct from `phoenix-nft-staking` run-22 M-01 (aggregate-nudge over-funding, Σ pots > cost); that is aggregate over-funding, this is single-pot capture concentration. Do not collapse them.

**The first-party leg is the SYA restatement**, which reads to an SYA integrator as a structural guarantee against burst capture. **The cure is documentary: soften `:62`** to state that the streamer is a *timing* throttle with *no value cap*, and cross-reference the upstream entries so an SYA reader is not left believing burst capture is structurally prevented.

The C4 "root cause in an out-of-scope parent/forked contract" exclusion was considered and **deliberately not applied as a removal** — suppressing the whole item would delete the only actionable leg.

---

## Positive result — story-026 closed a real pre-existing hole (POS-001)

Stated fairly, and required alongside the F-04/L-05 note so this report is not read as "story-026 achieved nothing."

**Before story-026,** `claim()` pushed `nudgeAmount` directly into `BatchNFTMinterMultiToken`'s balance. `_snapshotRewards` reads that balance **before** the mint loop (`BatchNFTMinterMultiToken.sol:748`), so a donation that landed in a prior transaction is fully capturable. A claimer could therefore **back-run their own claim** in the same block with `batchMint(nudgeSize, self, ...)` and recover the entire nudge share they had just paid **while keeping the NFTs** — buying the claim-gate NFTs at a discount of exactly `nudgeAmount`, funded by their own donation. The nudge subsidy was recapturable by the person paying it: deterministic, atomically adjacent, uncontested.

**After story-026,** the donation lands in the streamer buffer, and `collectNudge` **settles first, then deposits**, so accrued at that instant is zero. An immediate back-run captures nothing of the new donation. The self-rebate is converted into a delayed, competitive claim.

**story-026's narrow, literal goal — killing the same-block claimer self-rebate — is achieved, and that is a genuine and material improvement. The change is not pure downside.**

Residual: a claimer can return later and compete for the accumulated pot like anyone else. That is ordinary open MEV, not a self-rebate, and is the subject of the F-04/L-05 note above.

Two further economic positives were recorded and cleared:

- **POS-002** — claimer P&L is unchanged by story-026. The claimer's gain (`skimSurplus` proceeds, `:558`) and cost (`actualPayment`, `:583`) are both settled before the nudge leg and depend on neither the streamer nor stream state nor delivery timing. Because the leg is un-enveloped, a claimer cannot keep the skim while suppressing either leg — a revert in `collectNudge` reverts the whole claim including the skim. No new value-extraction path for the claimer.
- **POS-003** — rounding directions cleared. `nudgeAmount = (actualPayment * nudgeSplit) / 100` floors and `phlimboAmount = actualPayment - nudgeAmount` takes the remainder; both legs are protocol-side and the dust goes to phlimbo, never to a user. No round-trip exists in SYA at all.

---

## Cross-reference index — deviations carrying security impact

| Spec finding | Also filed as | Severity | Ledger |
|---|---|---|---|
| **F-01** (unsafe story: mandatory external dependency, no fallback) | design origin of **M-01 (run-14)** — `setRewardToken` re-keys the stream and bricks `claim()` | Medium | **M-02**, fp `5292756503a71502…` |
| **F-02** leg 2 (closed enumeration omits `setRewardToken`) | the non-obviousness limb of **M-01 (run-14)** — cited there as the "documentation makes it non-obvious" aggravator | Medium | **M-02** |
| **F-02** leg 1 (self-certifying suppression clause) | no security label — impact is on audit assurance only | Low | **F-02**, fp `12d4ec2676c5dd49…` |
| **F-04** (capture-size over-claim restated at `:62`) | **L-05 (run-14)** | Low | **L-11**, fp `e3a970c5d93e9f6c…`; routed to `phoenix-nft-staking`, related `858e9e80` (wont-fix) |
| **F-01** (as filed) | — | Low | **F-01**, fp `36c3e70ecc6e0002…` |

Two further run-14 Lows touch the same rail and are reported in the QA bundle, not here, because they are behavioural rather than conformance findings: **L-03 (run-14)** / ledger **L-09** (the same setter orphans the old pair's buffer) and **L-04 (run-14)** / ledger **L-10** (standing phlimbo allowance never revoked on repoint).

**Label reconciliation warning.** Run-scoped report labels collide with pre-existing ledger labels for *different* findings. Reconcile by **fingerprint**, never by label. Run-14 `L-01` is not ledger `L-01`; run-14 `QA-01` is not ledger `QA-01`.
