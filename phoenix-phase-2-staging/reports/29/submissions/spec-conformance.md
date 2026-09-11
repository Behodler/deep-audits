# Spec Conformance (Law 2) — phoenix-phase-2-staging, script audit of the `dev` entry point (run 29)

**Project**: phoenix-phase-2-staging  ·  **Run**: `phoenix-phase-2-staging-29`
**Commit**: `9563c68094e516a91d27684252e6a103271d69cf` (`9563c68`), branch `master`
**Baseline**: `f929b5b` (`entryPointBaselines.dev`, set by run 28)
**Entry points**: `dev` (primary) and `test:stable-staker` (new — surfaced by this run)
**Delta commits**: `ac70af6` [story-080], `9563c68` [story-081]
**Mode**: local-anvil **real execution**, chain 31337 only. 11 executed tests. No mainnet fork.

This run raises **two new Law-2 findings** — `F-03` and `F-04`, both against **story-080** — and
**carries forward `F-01` and `F-02` unchanged**. Both new findings are Low: neither has asset, value
or availability impact, so **neither owes a separate High/Medium label or report**.

| Label | `issueId` | Fingerprint | Story | Deviation type | Severity |
|---|---|---|---|---|---|
| **F-03** | `pps29f3` | `c476a12b04fa…` | story-080 | **UNDECLARED** | Low |
| **F-04** | `pps29f4` | `ee5aae66ac65…` | story-080 | **DECLARED-BUT-UNMET** | Low |
| F-01 *(carried)* | `pps28f1` | `dcf756f7a897…` | story-079 | contravened | Low |
| F-02 *(carried)* | `pps28f2` | `beb259209f88…` | story-079 | contravened | Low |

## Stories graded against, and the weight their verification carries

Both delta stories live in **`auto-complete`** with **self-reported** verification:

- `~/code/product-owner/stories/phStaging2/auto-complete/phStaging2-stable-staker-v2/080-deploymocks-stablestakerv2-antimatter-cutover.md`
- `~/code/product-owner/stories/phStaging2/auto-complete/phStaging2-stable-staker-v2/081-dev-genesis-freshness-gate.md`

Three provenance facts bear on how much the ticked boxes are worth, and all three are stated in the
story documents themselves:

1. **story-080's review self-reports `independence: reduced`** — *"these verdicts were reached by one
   agent rather than five."* Independence from the *executor* is intact; independence among the
   reviewers is not.
2. **story-080 was auto-completed by machine approval**, *"Approved by: story-batch workflow (machine
   approval — not human-reviewed)"*, on a `PASSED` review that itself carried a `[medium] Verification
   gap`: *"the review did not independently re-execute `npm run test:stable-staker` (it needs a live
   anvil and a full deploy)."*
3. **story-081's four gates were hand-run only.**

**All four of story-081's gates were independently re-verified by execution in this run**, and
story-080's Phase 7.6 claim was likewise verified by execution (subject to the re-run provenance
caveat recorded in the run-26 carryover bundle). The verification gap story-080's own review flagged
as `[medium]` — `npm run test:stable-staker` never re-executed — **was closed by this audit**: the
harness was run on a clean machine, which is how `F-03` was found.

---

## F-03 — `verify-stable-staker.sh` and its `package.json` doc key both state an assertion the harness no longer makes <!-- id: pps29f3 -->

**Fingerprint**: `c476a12b04faf476e46dca810c87bb18357daab3760584328074bb7273267856`
**Basis**: `lib/phoenix-phase-2-staging/verify-stable-staker.sh:header comment (lines 6-10); package.json `//verify-stable-staker`:DocumentedAssertionDivergesFromImplementation:test:stable-staker`
**Location**: `verify-stable-staker.sh#L6-L10`; `package.json:36`
**Entry point**: `test:stable-staker` (**new** — this run created its ledger baseline)
**Deviation type**: **UNDECLARED**

### The acceptance text this violates, verbatim

From story-080's ticked acceptance checklist:

> changed the reward assertion from `~10 phUSD` claimed to `~10 Antimatter` **ACCRUED**

### What shipped

`ClaimWithdrawStableStaker.s.sol:86-98` asserts **the caller's pro-rata share**, not a flat ~10:

```
expected = (EXPECTED_DAILY_REWARD * stakedPrincipal) / totalStakedNow      // ±1% band
```

### The deviation

**The implementation is right and the documentation is wrong.** Story-080's *own* Phase 6.5b seeding
puts 12 more actors (1,200 DOLA) into the V1 DOLA pool and migrates them to V2, so the verifier's own
1,000 DOLA stake is a **minority** of V2's DOLA pool and its daily share is well under 10. A flat
"~10" assertion would now fail for a reason unrelated to configuration. Autonomous **Decision 8**
records the generalisation of the *assertions*:

> The reward assertion is now `10e18 * stakedPrincipal / totalStaked` ±1% … The flat figures would now
> fail for a reason unrelated to configuration, and deleting them would leave the rate unchecked.

**But two documentation surfaces still state the superseded assertion**, and neither the checklist
line nor Decision 8 records that they were left behind:

- `verify-stable-staker.sh:9` — `# the accrued reward (~10 Antimatter), that \`claim\` is still closed, and the`
- `package.json:36` — `assert ~10 Antimatter accrued`

So the deviation is **undeclared**: the checklist tick says one thing, the code does another (correctly),
and the story's deviation list is one entry short.

### Evidence — executed, not argued

Ran `npm run test:stable-staker` in `<project>/work/` on a clean machine. Observed:

```
claimableReward (Antimatter):                        4545507154882125000
Expected pro-rata daily reward (Antimatter):         4545454545454545454
Antimatter reward accrued (pro-rata share of 10/day): 4545507154882125000
=== verify-stable-staker.sh: ALL ASSERTIONS PASSED ===
```

**4.5455**, against a documented **~10**.

### Why it matters

A developer who changes the DOLA pool's `antimatterPerDay` rate, or adds a staker to the Phase 6.5b
seed set, will see `npm run test:stable-staker` fail on *"reward below the pro-rata daily lower
bound"*. They will read the script header and the `package.json` doc key — both of which say the
harness asserts *"~10 Antimatter accrued"* — see a printed **4.5455**, and conclude the emission rate
is broken. They will then go looking for a bug in `StableStakerV2`'s accrual maths, when the assertion
that actually fired is a pro-rata bound whose **denominator their change moved**. Both surfaces have
been wrong since `ac70af6`, and they point the investigation at the wrong contract.

### Recommendation (verbatim from the finding record)

> Update both strings to say the assertion is the caller's pro-rata share of the pool's 10
> Antimatter/day (the in-script comment at `ClaimWithdrawStableStaker.s.sol:86-91` already explains it
> well and can be quoted), and record the change as a story-080 Autonomous Decision so the checklist
> tick matches what shipped.

### Severity

**Low.** QA/documentation, no execution consequence — the harness itself is correct and self-documents
the change. Kept at Low rather than QA only because it is an **undeclared divergence from a ticked
story-080 acceptance line**, and the two stale surfaces are the first thing a developer reads when a
run fails.

**⚠ Do not collapse with `F-04`.** Different file, different mechanism (a stale human-readable
assertion string vs an absent type-level drift guard), different remedy. They share a story-080
**provenance**, which is not a shared root cause; collapsing on provenance would erase one of two
independent deviations.

---

## F-04 — story-080's declared drift guard does not exist, and the two files already disagree <!-- id: pps29f4 -->

**Fingerprint**: `ee5aae66ac651277953db1b477d4ba66939701ec5aa7ffe013c2b26b9865e678`
**Basis**: `lib/phoenix-phase-2-staging/server/deployments/mainnet-addresses.ts:mainnetAddresses: ContractAddresses:UnenforceableDeclaredDriftGuard:dev`
**Location**: `server/deployments/mainnet-addresses.ts#L39`
**Entry point**: `dev`
**Deviation type**: **DECLARED-BUT-UNMET**

### The acceptance text this violates, verbatim

From story-080's ticked acceptance checklist:

> Confirm `tsc` passes — the `: ContractAddresses` annotation on `mainnetAddresses` is the **only drift
> guard** between the two files.

And from the story's Technical Details, stating the same premise:

> `server/deployments/mainnet-addresses.ts` is hand-maintained — mainnet codegen was removed in story
> 068 — and its key-set must mirror the generated interface exactly, since that `: ContractAddresses`
> annotation is the only drift guard. It must be edited in the same commit or `tsc` fails.

### What shipped

**No `tsconfig.json` exists anywhere outside `node_modules`/`lib`.** `tsc` has nothing to act on, so
the annotation is never checked. Autonomous **Decision 6** records this **honestly**:

> This repository contains **no `tsconfig.json`** anywhere outside `node_modules`/`lib`, so there is no
> TypeScript project to compile … **Decision**: Verified the actual drift guard directly — that the
> `ContractAddresses` interface key-set in the generated `server/deployments/addresses.ts` and the
> key-set of the hand-maintained `server/deployments/mainnet-addresses.ts` agree on **this story's
> keys** (`StableStaker` gone, `StableStakerV2` and `Antimatter` present).

**The honesty is creditable, and it is why this is Low rather than higher.** But the box is ticked, the
acceptance criterion is not met, and by the story's *own words* — *"the only drift guard"* — there is
now **no drift guard at all**.

### The guard would fail today if it existed

Decision 6's manual substitute checked only *this story's keys*. A full key-set comparison, run
independently this audit, finds the two files **already disagree**:

```
find <project>/work -maxdepth 2 -name 'tsconfig*.json' -not -path './node_modules/*'   ->  no results

interface keys: 56 | mainnet keys: 59 | local keys: 56
IN INTERFACE, MISSING FROM mainnet-addresses.ts:  []
IN mainnet-addresses.ts, NOT IN INTERFACE:        ['BurnerEYE', 'BurnerFlax', 'BurnerSCX']
interface-vs-local delta:                         []
```

The direction that would be a hard `tsc` error is clean; but `mainnet-addresses.ts` carries **three
keys the interface does not declare**, and TypeScript's **excess-property checking on a typed object
literal** would reject them. The check the story claims to have performed would **fail today**.

### Why it matters

`npm run dev` **regenerates** `server/deployments/addresses.ts` — the `ContractAddresses` interface —
on **every run**, via `server/generate-ts-addresses.js:63`. Any future `_trackDeployment` addition or
removal in `DeployMocks` therefore silently re-shapes the interface that `mainnet-addresses.ts` is
annotated against. **This delta already exercised that exact path** (`StableStaker` removed,
`Antimatter` and `StableStakerV2` added). The repo's CI runs `forge fmt --check`, `forge build --sizes`
and `forge test` — none of which has anything to say about TypeScript. The drift surfaces later, in a
downstream UI project that copies both files in and fails to build, or worse reads a key that silently
resolves to `undefined`.

### Recommendation (verbatim from the finding record)

> Add a minimal `tsconfig.json` covering `server/deployments/*.ts` with `strict: true`, and either
> declare the three `Burner*` keys on `ContractAddresses` (by adding their `_trackDeployment` calls,
> the codegen path story-080 itself insists on) or drop them from `mainnet-addresses.ts`. Then wire
> `tsc --noEmit` into the same GitHub workflow that already runs `forge fmt --check` /
> `forge build --sizes` / `forge test`, so the guard is **enforced** rather than **asserted**.

### Severity

**Low.** No runtime consequence in this repo — `mainnet-addresses.ts` is a hand-maintained copy-out
artifact and nothing in-tree reads it. But `dev` **regenerates the interface every run**, so the one
thing standing between a silent key-set drift and a broken downstream UI is a check the story claims to
have performed and that **no tool in this repo can perform**.

**⚠ Do not collapse with `F-03`** (see above), and **do not collapse with run-28 `L-07`**
(`98e727214903…` / `pps28l7`): that is a *de-tracked seed artifact* breaking standalone runs, this is
an *unenforced type annotation*. Same `server/deployments/` family, distinct defect.

---

## Story-080 deviations judged SAFE and honestly recorded

Law 2 grades **both directions**. Story-080 departed from its own checklist in five further places;
every one was **recorded in the story document** and every one is, on this audit's reading, **correct**.
They are listed here so the record is complete and so a later reader does not re-open a settled
question.

| # | Decision | What the checklist implied | What shipped, and why it is safe |
|---|---|---|---|
| **1** | **Decision 2** — USDe registered on `PhusdStableMinter` | Not contemplated | Registration was required for `autoAnnihilateAvailable(USDe)` to hold; without it the Phase 6.5a post-condition could not be asserted at all. Additive, local-only, and disclosed. |
| **2** | **Decision 3** — principal-conservation assertion is **per-strategy**, not universal | A universal conservation assert | A universal assert would be false by construction: ERC4626 rounding plus the 10% set-aside buffer make exact equality unattainable for the market strategy. The shipped form is `maxLossBps = 0` (exact + 2 wei) for DOLA/USDC and `100` for USDe — **the USDe band is the only relaxation**, and it is the narrowest one that can hold. Verified by execution: the postcondition passed with those bands. |
| **3** | **Decision 4** — the V1 phUSD mint grant is **REVOKED after** the cutover | Revocation, ordering unstated | Ordering is the whole safety property, and it shipped **correct**: `_assertStableStakerCutover` runs at `DeployMocks.s.sol:2296`, *then* `phUSD.setMinter(stableStaker, false)` at `:2308`. Revoking **before** the drain assert would have bricked the very migration being asserted. Verified by execution — postcondition *"V1 loses its phUSD mint grant, AFTER the drain assert"* **PASSED**. |
| **4** | **Decision 5** — the two archived interaction scripts were **retargeted**, not merely re-keyed | *"change their progress-JSON key to `.contracts.StableStakerV2.address`"* | Merely re-keying would point a `StableStakerV1`-typed script at a V2 address whose reward token is Antimatter and whose `claim` is disabled — **it would revert**. The scripts were retyped onto `StableStakerV2` and the claim leg now asserts the *closed door* (`claimEnabled` still false, no Antimatter minted, `withdraw` banks the accrual into the `unclaimedReward` backlog rather than forfeiting it). The story forbids enabling claims, so asserting the closed door is the only honest version of the reward leg. |
| **5** | **Decision 7 — the inversion** | *"Fix `verify-stable-staker.sh` lines 56 and 67 to point at `script/archives/interactions/`"* | **The implementation did the opposite of the literal instruction, and that is correct.** `foundry.toml:32` carries `skip = ["script/archives/**"]`, so a script under that path answers `Error: Could not find target contract` — the target is **excluded from compilation, so no path repair can make it runnable.** The executor verified this **by running it**, then `git mv`'d both files into `script/interactions/` — exactly the paths `verify-stable-staker.sh` already named — and left the shell script's two lines untouched, adding a comment recording why. The story's own Verification checklist requires `npm run test:stable-staker` to **run**, and the prescribed repair **cannot achieve that**. The alternative (removing `script/archives/**` from `skip`) was considered and correctly rejected: the rest of that directory is pinned to submodule interfaces that have moved on and no longer compiles. **Confirmed by execution this run — the harness runs.** |

**Decision 8** (`verify-stable-staker.sh`'s assertions generalised to pro-rata) belongs in this list on
its **code** half — the generalisation is right, for the reasons Decision 8 gives. Its **documentation**
half is what `F-03` files. **Decision 6** is what `F-04` files: honestly recorded, still unmet.

---

## Carried forward unchanged — F-01 and F-02 (story-079)

**Neither commit in this delta touches `_seedNudgeStream` or the `LOCAL_PROMO_KENDU` pin.** Both
findings are therefore **carried forward verbatim** — not re-derived, not re-graded, not
re-fingerprinted. **story-079's verbatim instruction — *"Do NOT gate the Kendu nudge stream"* — remains
contravened at `9563c68`.** Their ledger entries stay `open`; run 29 proposes nothing on either.

The two sections below are a **verbatim copy** of the audit-28 spec-conformance report. Line numbers and
links were accurate at `f929b5b`; **re-verify against `9563c68` before acting.**

---

## F-01 — `dev` pins `LOCAL_PROMO_KENDU=true`, making the dormant (day-one mainnet) leg unreachable <!-- id: pps28f1 -->

**Fingerprint**: `dcf756f7a8977d7d8f3b8b3fb96cbe478f392b057ac045cb0e5928164123d92a`
**Basis**: `lib/phoenix-phase-2-staging/package.json:dev:EntryPointPinsRehearsalToNonMainnetLeg:dev`
**Location**: `lib/phoenix-phase-2-staging/package.json:16` (the `dev` key)
**Story graded against**: story 079
**Story document**: `/home/justin/code/product-owner/stories/phStaging2/complete/phStaging2-script-audit-26/079-rehearse-cutover-mechanics-toggle-kendu-promo-and-sweep-deployer-grant.md`
**State folder**: `complete`  ·  **Sprint folder**: `phStaging2-script-audit-26`
**Story base commit** (from the document header): `1d8a3a7515adca7819c530a01a87c132863a5ae2` — exactly this audit's baseline.

### The acceptance text this violates, verbatim

From the story's *Explicitly OUT of scope (do not touch, do not "helpfully" fix)* list, line 32:

> - `src/` contracts, the UI repo, `package.json`, and `.envrc` secrets.

And from the story's closing checklist, line 547:

> - [x] Confirm no mainnet script, no `src/` contract and no `package.json` key was modified — `git status --porcelain` shows only `script/DeployMocks.s.sol`

That checkbox is **ticked** in the story document. It is false at `f929b5b`: `package.json:16` now
carries `LOCAL_PROMO_KENDU=true` inside the `dev` key.

For context, the fix story 079 was written to deliver (its remediation table, line 21):

> | `pps26l3` (L-03) | The Kendu promotion is armed unconditionally at the end of every local run, so the **dormant** promo state mainnet ships on day one is the one state `dev` can never produce | Gate the arming on a global boolean, default ON |

### The deviation

The contract-script half of that fix **landed correctly**. `DeployMocks.s.sol:398` reads
`armKenduPromo = vm.envOr("LOCAL_PROMO_KENDU", true)`, and a full dormant leg exists at `:400`,
`:1631-1639`, `:2044-2061` and `:2193-2199` — armed-by-default included, exactly as mandated.

The delta then added the assignment to the `dev` key itself:

```
"dev": "npm run clean:local && npm run start:anvil & sleep 3 && LOCAL_PROMO_KENDU=true npm run deploy:local && ./simulate-yield.sh && ..."
```

A command-prefix assignment **overrides the inherited environment**, so the toggle is inert from
outside. Verified:
`LOCAL_PROMO_KENDU=false bash -c 'LOCAL_PROMO_KENDU=true sh -c "echo \$LOCAL_PROMO_KENDU"'` → `true`
(control without the prefix → `false`). A developer who follows the instruction the script itself
prints cannot make it take effect.

The script contradicts its own entry point in three places:

- `DeployMocks.s.sol:210-213` (NatSpec): *"Set LOCAL_PROMO_KENDU=false to boot the DORMANT chain
  instead — the state mainnet actually ships on day one, and the one state this script could
  previously never produce."*
- `DeployMocks.s.sol:1634`, printed at the end of **every** `dev` run and captured verbatim in this
  run's live log: *"Set LOCAL_PROMO_KENDU=false to boot the DORMANT (day-one mainnet) chain"*.
- `DeployMocks.s.sol:1984`: *"Do not read the armed leg's behaviour as a prediction of mainnet's."*
  `dev` pins the rehearsal to precisely the leg its author says must not be read as a prediction.

The day-one mainnet configuration — `promoToken == address(0)`, `promoRewardBalance == 0`,
phUSD/Kendu streams whitelisted-but-unregistered — is therefore unreachable through `npm run dev`
without editing `package.json`. Story 076 (`complete/phStaging2-promotion-ready/076-…`, checklist
line 566) requires of the mainnet cutover:

> - [x] **No `startPromotion` call anywhere.**

So the shape the UI must render gracefully on day one is the one shape the entry point anyone runs
never produces, while the divergent armed shape is rehearsed every time.

This is **not an incomplete fix of L-03 as filed** — the fix landed complete. It is a correct fix
**partially reverted one layer up**, by one of the nine untagged commits in this delta.

### Consequence for triage (ledger)

- Ledger `L-03` / `pps26l3`, fingerprint `12bcca3b617c6c077babfad810a2457a1b8f3a5d352217b4acb135e8b9859e79`,
  status **`fix-pending`** — must be **HELD at `fix-pending`**.
- **Run-27's propose-fixed for this entry is WITHDRAWN.** The behaviour L-03 demands cannot be
  verified through the only entry point anyone runs, so no verification of the fix is possible from
  `dev` at `f929b5b`. A fix that cannot be exercised is not a verified fix.
- No status was changed by this run. This is a **proposal only**; apply nothing without
  `/ledger phoenix-phase-2-staging …`.

Local-only, so no funds are at risk. It is Low because it degrades the evidentiary value of the
rehearsal and silently undoes work a human triaged as `fix-pending` — the exact class the ledger's
INCOMPLETE-FIX rule exists to catch.

### Recommendation (verbatim from the finding record)

> Delete `LOCAL_PROMO_KENDU=true` from the `dev` key and let `vm.envOr`'s default supply the armed
> leg (identical behaviour, toggle restored). If an explicit armed default is wanted at the npm
> layer, add a second key (`dev:dormant` with `LOCAL_PROMO_KENDU=false`) rather than pinning the
> only one. Add a rehearsal obligation that BOTH legs are booted before a mainnet cutover, since
> only the dormant leg matches day one.

---

## F-02 — `_seedNudgeStream` gated behind the optional leg, disarming a load-bearing fee-on-transfer probe <!-- id: pps28f2 -->

**Fingerprint**: `beb259209f88e76e748c09fd10a3bdeb63339edcf9dab180b4bcacdc0caae798`
**Basis**: `lib/phoenix-phase-2-staging/script/DeployMocks.s.sol:_registerNudgeStreams / _seedNudgeStream:SafetyProbeGatedBehindOptionalLeg:dev`
**Location**: `lib/phoenix-phase-2-staging/script/DeployMocks.s.sol:2044-2061` (gating block); probe at `:2069-2096`
**Story graded against**: story 079
**Story document**: `/home/justin/code/product-owner/stories/phStaging2/complete/phStaging2-script-audit-26/079-rehearse-cutover-mechanics-toggle-kendu-promo-and-sweep-deployer-grant.md`
**State folder**: `complete`  ·  **Sprint folder**: `phStaging2-script-audit-26`

### The acceptance text this violates, verbatim

From *Implementation Notes*, lines 476-478:

> **Do NOT gate the Kendu nudge stream.** `_seedNudgeStream` (`:1781-1788`) mints MockKendu for the
> *nudge stream*, which is a different mechanism from the PhlimboV3 promotion and is unrelated to
> L-03. It stays unconditional.

The instruction is unambiguous, is bolded in the story, and gives its reason: the nudge stream is a
*different mechanism* from the PhlimboV3 promotion, so the promotion toggle has no business
governing it.

### The deviation

`git diff 1d8a3a7 f929b5b -- script/DeployMocks.s.sol` moves `nudgeStreamer.registerStream(phUSD)`,
`registerStream(mockKendu)` and **both** `_seedNudgeStream` calls inside `if (armKenduPromo) { … }
else { … }` at `:2044-2061`.

The consequence is concrete, not cosmetic. `_seedNudgeStream` is self-documented as doubling as the
fee-on-transfer probe and terminates at `:2096` in:

```solidity
require(received == amount, "nudge seed token is fee-on-transfer: streamer received < sent");
```

described in-source as *load-bearing, not decorative*. Under the gating, that assertion executes on
the **armed leg only**. The dormant leg — the one that matches day-one mainnet — performs no
seeding and therefore **runs no probe at all**, silently.

### Ordering hazard — state this before scheduling either fix

Today the probe does in fact run on every `npm run dev`, because F-01 pins `LOCAL_PROMO_KENDU=true`.
That is the *only* reason there is no live loss of coverage. The two defects therefore interlock:

- **Fixing F-01 alone ARMS F-02.** Unpin the env var without ungating the seed, and the very first
  `LOCAL_PROMO_KENDU=false` run — the dormant, day-one-mainnet rehearsal that F-01's whole purpose
  is to make reachable — becomes a rehearsal that quietly omits its own safety guard, with no error
  and no log line saying the probe was skipped.
- **F-01 and F-02 must be fixed together, F-02 first or simultaneously.** Ungate the seed (or hoist
  the probe out of it) *before or in the same change as* unpinning the `dev` key. Never the reverse
  order.

Low severity: local-only, no current loss of coverage. But it is a real Law-2 deviation with a
demonstrable safety consequence, and it landed on commits carrying no story tag at all.

### Recommendation (verbatim from the finding record)

> Either restore the seeding/probe as unconditional per story 079 (registering and seeding the
> phUSD/Kendu streams costs nothing on the dormant leg beyond two extra streams the UI is supposed
> to render gracefully anyway), or — if the dormant leg must genuinely leave them unregistered to
> mirror mainnet — hoist the fee-on-transfer probe out of `_seedNudgeStream` into an unconditional
> check that runs on both legs, and amend story 079 (or file a superseding story) rather than
> silently contradicting it.

---


---

## Law-1 override check

**No story graded in this run has an intended behaviour that would introduce an exploit.** Law 1 does
not override Law 2 anywhere here.

- **story-080** rehearses a V1→V2 cutover on a **local anvil, chain 31337 only**. Its most
  safety-relevant instruction — revoke V1's phUSD mint grant — ships in the **correct order** (after
  the drain assert), which is the ordering that avoids bricking the migration. Its relaxations are
  narrow and were verified: the USDe `maxLossBps = 100` band is the only one, DOLA and USDC are exact
  + 2 wei.
- **story-081** is purely defensive — it *adds* a freshness gate. Verified by execution to close the
  run-28 stale-anvil race, including the fork case (anvil preserves the forked deployer nonce, so
  forcing chainid 31337 does not disguise a fork).

Two Law-3 checks were applied and both passed the *surprise test*, so neither new finding is an
owner-misuse claim: a competent, non-malicious developer **would** be surprised that the documented
"~10 Antimatter" assertion is not the one that fires (`F-03`), and **would** be surprised that the
`tsc` guard the story names as the only drift guard cannot run at all (`F-04`).

## Remediation ordering

1. **`F-04` before `F-03`.** `F-04` is the one with a live drift surface — `dev` regenerates the
   interface on every run, and the two files already disagree by three keys. `F-03` is documentation
   and can follow at leisure.
2. **`F-03`'s two surfaces must be fixed together** (`verify-stable-staker.sh:6-10` **and**
   `package.json:36`). Fixing one leaves the other as the misleading one a developer reads first.
3. **`F-01` and `F-02` must be fixed together**, per the audit-28 ordering hazard retained above.
4. Record `F-03`'s fix as a story-080 Autonomous Decision, so the checklist tick and the shipped code
   agree — that is the deviation, more than the strings themselves.
