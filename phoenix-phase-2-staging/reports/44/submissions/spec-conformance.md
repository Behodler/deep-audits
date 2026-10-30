# Spec-conformance report (Law 2): phoenix-phase-2-staging, run 44

- **Run:** phoenix-phase-2-staging-44 (script audit)
- **Entry points:** `antimatter-pool` (Script B), `sya-harvester` (Script A)
- **Source commit:** `669cbc11a41b1bd677ac422391532bb79199b9a6` (branch `master`), fork block 26303964
- **Story:** story-122, *Mainnet catch-up to DeployMocks: SYAHarvester + claim enable, Antimatter/sUSDS cutover, UniswapHelper redeploy*
  - **Path:** `/home/justin/code/product-owner/stories/phStaging2/auto-complete/sya-antimatter-cutover/122-sya-antimatter-mainnet-catch-up.md`
  - **State:** `auto-complete`, a final state equivalent to `complete`. The story was machine-approved by the story-batch workflow on 2026-10-30T06:38:41Z, with review status `ISSUES_FOUND` triaged as "non-blocking". No human has reviewed it.
  - **Story base commit:** `753796b`. A project-wide glob for `122-*.md` / `122.*-*.md` under `phStaging2/` returns exactly one hit.

This file is separate from the QA bundle (`qa-report.md`). Labels are namespaced by entry point, because each script audit numbers its findings independently. **Two of the four entries are unsafe-story flags** (Law 1 overrides Law 2). For those, fixing the code alone is not enough: the story text must be amended too, otherwise a later "faithful" re-implementation brings the exploit back.

| issueId | Label | Severity weight | Kind | Security cross-reference |
|---|---|---|---|---|
| `pps44f1` | antimatter-pool F-01 | Medium (carried by M-01, not a separate H/M) | **Unsafe story** | antimatter-pool M-01 `pps44m1` |
| `pps44f2` | antimatter-pool F-02 | Low | Code deviates from a safe story | antimatter-pool L-01 `pps44l1` |
| `pps44f3` | sya-harvester F-01 | Medium (enabling condition of M-01, not a separate H/M) | **Unsafe story** | antimatter-pool M-01 `pps44m1`, M-02 `pps44m2`; sya-harvester L-01 `pps44l4` |
| `pps44f4` | sya-harvester F-02 | Low | Ticked-but-false checklist item (disclosed) | pps L-09 `pps35l9` (`78cb5942d483`, fixed) |

---

## pps44f1: antimatter-pool F-01. The story says F3 (`amountBMin=0`) is safe because "step 0 guarantees" a fresh pair; on chain nothing guarantees it

- **Fingerprint:** `9d2f2c79c3ef40c9c78a01d90f1b561c5a913ef152935f55b71d72f796120552`
- **Location:** `script/CutoverAntimatterPoolMainnet.s.sol`, `run` (Step 0 L258-271; F3 NatSpec L49-52); `docs/SyaAntimatterMainnetCutover.md` (Script B section)
- **Root cause class:** `StoryGuaranteeNotEnforcedOnChain`
- **Story verdict:** **UNSAFE STORY.** The code implements the story faithfully, and the story's safety premise is false.

### What the story says (verbatim)

story-122 L122, Script B step 0:
> 0. Precondition: `factory.getPair(AM, sUSDS) == address(0)`. If the pair already exists, ABORT with a clear message (griefing risk R1 from story 113) rather than seeding into it.

story-122 L142-143, open items carried from story 113:
> - **F3:** the AM/sUSDS add uses `amountBMin=0`. That is acceptable because the pair is created fresh in the same transaction, guaranteed by step 0.
> - **R1:** front-run pair-creation griefing. Mitigate with the step-0 precondition. The runbook recommends broadcasting B through a private RPC (e.g. Flashbots Protect) by overriding `--rpc-url` on the broadcast.

story-122 L203, Concerns:
> - **Pair griefing (R1) / amountBMin=0 (F3)**: B refuses to run if the AM/sUSDS pair already exists, and the runbook recommends a private RPC for B.

The runbook (`docs/SyaAntimatterMainnetCutover.md`) repeats the claim:
> F3 (story 113): the seeder adds the AM/sUSDS liquidity with `amountBMin = 0`. That is safe only because the pair is created inside the same transaction; step 0 guarantees it.

### What the code and script do instead

- Step 0 (`require(factory.getPair(AM,sUSDS)==0 …)`) runs only during forge's **local simulation pass**. No transaction carries it to chain, and `AntimatterPoolSeeder.seed()` does not check that the pair is absent.
- With `--broadcast --slow` the six transactions land one receipt at a time. tx1 (the seeder CREATE, at a nonce-predictable address with every immutable public) is **mined** four transactions before the seed (tx5). A private RPC hides pending transactions only. It cannot hide mined ones, so the runbook's mitigation does not cover the tx1-to-tx5 window.
- If a pair already exists on chain when tx5 lands, `_requireFullConsumption` rejects only an AM-**dear** pair. Against an AM-**cheap** pair, `Router02.addLiquidity(amountAMin=am, amountBMin=0)` deposits all 2,457.70 protocol-minted AM at the attacker's price.
- PoC evidence: `test_PoC_M01_frontRunStealsSeededAM` (`work/test/audit-run44/AntimatterPoolPoC44.fork.t.sol`, fork 26303964; diff at `reports/44/pocs/AntimatterPoolPoC44.diff`). Step 0 logs `factory.getPair(AM, sUSDS) == 0: OK` locally, and the attacker then buys 2,452.65 AM (2452654935079871585286 wei) for 1e12 wei sUSDS. Attacker P&L is +$1,319.14 realized, net of a conservative $1 for the 1 AM seed, and +$2,168.13 marked to market. Full write-up: M-01 (`pps44m1`).

### Is the story itself unsafe? Yes (Law 1 overrides Law 2)

A fully faithful implementation of "step 0 guarantees it" is the code under review, and it still leaves M-01 exploitable. The defect sits in the story's own safety argument: an off-chain, local-pass precondition is treated as an on-chain guarantee, and a private RPC is treated as covering transactions that are mined in public. Amending only the code would leave story-122 L142-143 / L203 and the runbook telling the next implementer that `amountBMin=0` is safe.

### Recommendation

1. **Amend story-122** L142 (F3), L143 (R1) and L203. F3 is acceptable **only** with an on-chain guard inside the seed transaction: an expected-fresh flag (`require(amSusdsPair() == address(0))` within `seed()`), or a `minSUSDSPaired` floor computed from the same pro-rata quote. Either makes an AM-cheap pair revert tx5 instead of leaking.
2. **Amend the runbook** to say that a private RPC protects only the seed transaction's mempool exposure, not the tx1-to-tx5 window.
3. Until the guard lands, require Script B to run **before** Script A (see `pps44f3`).
4. A tripwire confirms the guard closes the gap: `test_PoC_M01_frontRunStealsSeededAM` FAILs against `AntimatterPoolSeederFixed` with `InsufficientSUSDS(2457703431, 2075083110422466836443)`.

---

## pps44f2: antimatter-pool F-02. The story says the minter revoke "must always run, even on resume"; a failed seed with an existing pair aborts at Step 0 before the revoke

- **Fingerprint:** `7a2a50635466dcf10d34943fa77dc72570adfb017f8cccfc4e17ca2a47d2c151`
- **Location:** `script/CutoverAntimatterPoolMainnet.s.sol`, `run` (Step 0 abort L261-266 vs Step 8 revoke L404-413)
- **Root cause class:** `StoryAlwaysRunCleanupSkipped`
- **Story verdict:** the story is **safe**. The code deviates from it.

### What the story says (verbatim)

story-122 L130 and L132:
> 8. `Antimatter.setApprovedMinter(seeder, false)` + require it was revoked.

> - **Resumable:** each step has a `done` gate read from chain state. If the run dies after step 4, the LP sits safely on OWNER and the resumed run continues from step 5. The revoke (step 8) must always run, even on resume.

story-122 L177, ticked checklist item:
> - [x] `script/CutoverAntimatterPoolMainnet.s.sol`: pair-absent precondition, seeder deploy, `lpForBps(1_000)`, rescue, approve, grant minter, seed with pro-rata floors, revoke minter, pair read-back; resumable with an always-run revoke

The script's own NatSpec (L46) says the same thing: "8. `Antimatter.setApprovedMinter(seeder, false)` + require - ALWAYS runs, including on resume".

### What the code does instead

The cutover can stop after tx4 (minter granted) with tx5 (`seed`) reverted, for example because an attacker created an AM-dear pair, in which case `seed()` reverts with `AntimatterNotFullyConsumed`. The pair then exists on chain and OWNER holds none of its LP. On every resume, Step 0 sees `existing != 0`, fails the `IERC20(existing).balanceOf(OWNER) > 0` arm of its `require`, and aborts with "the AM/sUSDS pair ALREADY EXISTS … ABORT". Step 8 is never reached, so the seeder **remains an approved Antimatter minter** until someone revokes it by hand. The exploratory fork test `test_r44_04_frontRun_amDear_seedReverts_revokeNeverRuns_thenDustLpSpoofCompletes` demonstrates this. Security weight sits with antimatter-pool L-01 (`pps44l1`).

### Is the story itself unsafe? No

"Always run the revoke" is the correct safety property. The script's control flow places an abort ahead of it.

### Recommendation

Before any Step-0 abort, revoke any recorded seeder (`p.seeder`) that `isApprovedMinter` reports as still approved. Alternatively, move the revoke into a pre-Step-0 cleanup that runs unconditionally. Document the manual `Antimatter.setApprovedMinter(seeder, false)` recovery in the runbook. No story amendment is needed. Story-122's L177 tick should be re-opened until the code meets it.

---

## pps44f3: sya-harvester F-01. The story and runbook declare Scripts A and B order-independent ("A and B in either order"); A's `setClaimEnabled` puts AM in third-party hands, which enables the B-side theft and abort

- **Fingerprint:** `031dd8696af066e301292880c613879ac22bda7219b0536b238829cec83ac2de`
- **Location:** `docs/SyaAntimatterMainnetCutover.md`, § Order item 1 (L15-16); Script A's final transaction `StableStakerV2.setClaimEnabled(true)`
- **Root cause class:** `UnsafeStoryOrderingClaim`
- **Story verdict:** **UNSAFE STORY.** The scripts implement the story faithfully, and the story's ordering rule is unsafe.

### What the story says (verbatim)

story-122 L16:
> Run order for the human: A and B in either order, then C.

story-122 L192, ticked checklist item:
> - [x] `docs/SyaAntimatterMainnetCutover.md` runbook: order (A, B in either order, then C), exact commands, private-RPC recommendation for B, post-broadcast checks, phlimbo-ui follow-up note

story-122 L12 (what Script A does):
> - **Script A — SYAHarvester + claim enable.** Deploy `SYAHarvester`, set its DOLA and USDe Curve Router NG routes and its ETH pool, then call `StableStakerV2.setClaimEnabled(true)`. Fills book key `SYAHarvester`.

The runbook (`docs/SyaAntimatterMainnetCutover.md` L15-16) gives the rationale:
> 1. **A and B, in either order.** They touch disjoint state (A: a new harvester + one StableStakerV2 flag; B: UniPoolerV2's LP, Antimatter's minter list, a new pair).

### What actually happens

The two scripts write disjoint **storage**, but their **economic** state overlaps. Script A's final transaction enables `StableStakerV2.claim()`, which mints AM to stakers (32 positions, about 205.42 AM pending at the fork block). Before Script A runs, AM `totalSupply == 0` and claims are disabled, so no third party can hold AM. A third party holding AM is the precondition for:
- antimatter-pool **M-01** (`pps44m1`): the attacker pre-creates an AM-cheap pair in the tx1-to-tx5 window and buys about 99.8% of the seeded AM. The PoC's control `test_PoC_M01_control_noScriptA_cannotReproduce` shows that without Script A the clean seed lands at 2,457.70 AM : 2,077.16 sUSDS, and 1e12 wei sUSDS buys only 1179655659889 wei AM.
- antimatter-pool **M-02** (`pps44m2`): an AM-dear front-run makes the seed revert, and dust LP then spoofs a "completed" cutover.
- sya-harvester **L-01** (`pps44l4`): Script A opens claims before Script B creates the AM/sUSDS market.

The A-before-B order is therefore the enabling condition for both Mediums. B-before-A removes the attack, because no third-party AM exists yet.

### Is the story itself unsafe? Yes (Law 1 overrides Law 2)

The "either order" rule is the story's own instruction, and both implementations follow it. Under that rule the owner can pick an order in which an unprivileged third party steals protocol-owned value. This is a non-obvious owner footgun (Law 3): a competent, non-malicious owner who trusts the "disjoint state" rationale would be surprised by the consequence.

### Recommendation

Amend story-122 L16 and L192, and runbook § Order item 1. Require **B (through a private RPC) strictly before A**, or bundle B's seed with A's `setClaimEnabled` so no third-party AM can exist during B's window. Delete the "disjoint state" rationale. Keep this ordering requirement even after the on-chain guard from `pps44f1` lands, as defence in depth. It costs nothing.

---

## pps44f4: sya-harvester F-02 [DISCLOSED]. Checklist item "`stable-staker-v2-cutover:verify` still passes against current mainnet" is ticked but false

- **Fingerprint:** `ff8c0cb81a45292e6f000b20dfa90affd7ac0356af3bf7452c47331e87572b6d`
- **Location:** `script/VerifyStableStakerV2Cutover.s.sol`, `run`: Phase 6b OWNER DOLA residual check (`_verifyPhase6b_minterMove`) vs the story-122 Phase 7 `claimEnabled` edit (L466-470)
- **Root cause class:** `TickedButFalseChecklist`
- **Story verdict:** the story is **safe**. The checklist item is false as written. Disclosure: the story discloses this itself in Autonomous Decision 3 (L293-297), in review Issue 1 (L321), and as a carried-forward `[medium]` in the Auto-Completed section (L368).

### What the story says (verbatim)

story-122 L172, ticked:
> - [x] Update the claimEnabled assertions in `VerifyStableStakerV2Cutover.s.sol` and `CutoverStableStakerV2Mainnet.s.sol` to be state-aware; `stable-staker-v2-cutover:verify` still passes against current mainnet

The story's own disclosure, L295:
> - **Decision**: Leave both alone, document them above, and tick the "`stable-staker-v2-cutover:verify` still passes" item on the basis that story 122 introduces no new failure (proven by running the base versions). Its literal condition is not met because of the unrelated Phase 6b dust.

### What the code does instead

Re-run on the anvil post-Script-A state (`script-audits/sya-harvester/logs/ssv2-cutover-verify-postA.log`), the verifier aborts with:
> `verify: Phase6b: OWNER DOLA residual - OWNER holds 88138771830498 DOLA, expected its pre-execution balance 0`

The story-122 change is the state-aware `_doneClaimStillDisabled` assertion in Phase 7 (L466-470). It sits after Phase 6b, so it is **never exercised end to end** against live state, either before or after Script A. Its only coverage is the unit-level `ClaimUnblockState` tests. The verifier is red on mainnet whether or not Script A has run.

### Is the story itself unsafe? No

This is a false tick, not an unsafe requirement. **Caution, which outweighs the convenience of turning the verifier green:**

- **Phase 6b failing is the pps L-09 fix firing as designed.** L-09 is `pps35l9`, fingerprint `78cb5942d483…`, status `fixed` at `91ed727`. It is not a regression and not a defect in the check. L-09 was the bug where Phase 6b re-seeded a DOLA amount baked from forge's local pass. The OWNER-DOLA-residual check is part of that fix.
- **The origin of OWNER's 88138771830498 wei DOLA is unestablished.** It could be an artefact of the cutover's silent excess, which is exactly what L-09 guards against, or unrelated dust that arrived later. Relaxing or removing the Phase 6b residual check before its provenance is known would **silently reopen L-09**.
- Related check, recorded and not changed: the reopenTrigger of wont-fix `pps36m1` (M-01, `cf684d5dc289`) was compared against story-122's edit of `VerifyStableStakerV2Cutover` at `753796b` and judged **not** fired, because the edit is limited to the Phase 7 `claimEnabled` require message and an inline comment. Human decision.

### Recommendation

1. The human **first establishes the provenance** of the 88138771830498 wei DOLA on OWNER (`0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6`). Then they either relax Phase 6b to an explicit, documented dust tolerance or record the dust's origin. Do not relax the check before the provenance is known.
2. Then re-run `stable-staker-v2-cutover:verify` against the post-Script-A state so the Phase 7 `claimEnabled` branch gets end-to-end coverage.
3. Amend the story-122 L172 tick to say what was actually verified ("no new failure versus base `c117969`"), not "still passes".
