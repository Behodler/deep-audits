# Script Review — `dev` (phoenix-phase-2-staging)

**Project**: phoenix-phase-2-staging · **Run**: `phoenix-phase-2-staging-30` · **Report dir**: `reports/30`
**Entry point**: `dev` → `./dev-local.sh` → `forge script script/DeployMocks.s.sol:DeployMocks --broadcast --slow`
**Commit under review**: `e6eded024108929b62424951f1df0c801b48d2ee` — subject *"slimmed down"*, **untagged**
**Baseline**: `9563c68` (`entryPointBaselines.dev`, set by run 29) · **Branch**: `master`
**Mode**: real local-anvil execution (chainId 31337, block time 2, genesis-fresh at hand-off) **plus** read-only
mainnet-fork `cast` calls at block **25949772**. Nothing was broadcast to mainnet.
**Execution basis**: `<project>/work/` (writable clone). `<project>/src/` was never written to.

---

## The owner's question, answered

> *The `dev` local-deployment script was slimmed to remove rehearsals of cutovers that have already
> executed on mainnet, keeping two exceptions. Were unrealistic shortcuts taken in the slimming?*

**Yes — in three places. All three are losses of local assurance, not value at risk.** Nothing in this
commit puts an asset, a user position, or a mainnet contract in danger, and this run raises **0 High and
0 Medium**. The slimming is, on the evidence, a competent and largely correct piece of work: the local
chain still deploys, still ends green, and both retained exceptions execute and assert end-to-end. What
it cost is *proof* — specific detectors that used to fail loudly, and that now do not exist.

The three shortcuts, in the order they matter:

1. **A `fix-pending` remediation was deleted.** Story-079's `_rehearseDispatcherSwap` (Phase 7.6) is gone,
   which regresses ledger entry `eda17642…` (`pps26l1`) — a finding a human accepted **and owed a fix on**.
   Three separate runs had recorded a propose-fixed against it; all three rested on the deleted helper and
   are withdrawn by this run.
2. **A detector was removed and proven gone.** The single index-1 rehearsal mint was the only executable
   proof that `Uniboost.setNudgeStreamer` had landed on indices 1/2/3. A four-run controlled experiment
   shows the local run now exits 0 with that wiring deliberately broken.
3. **A fidelity divergence was frozen into a literal.** `PhlimboV3`'s local depletion window is hard-coded
   to `604800` (7 d) where mainnet V2 and V3 both carry `2592000` (30 d) — a 4.29× faster window — and the
   comment justifying the literal makes a claim about mainnet that the fork disproves.

A fourth item is a **false rationale rather than a risk**: the comment accompanying the `PhlimboEA`
address-book deletion asserts that mainnet PhlimboV2 is "NOT paused so a late staker can still exit". The
fork says `paused() == true`. **No value is stranded by this** — that contract holds `totalStaked() == 0`
and zero phUSD/USDC balances. The defect is the unchecked assertion, not a trapped user.

**Findings**: 0 High · 0 Medium · **5 Low** · **3 QA** · **1 regression** · **1 still-open reconciliation**.

---

## Lens 1 — Intent

### What the commit says it does
`e6eded0` carries no `[story-NNN]` tag; its stated intent exists only in the source comments it added:

- Retire the local rehearsals of cutovers that have already executed on mainnet — PhlimboV1→V2→V3,
  NFTStakerDepletion V1→V2, and the index-1 Uniboost dispatcher swap.
- Deploy `PhlimboV3` as the only phlimbo generation; drop `PhlimboEA`, `PhlimboV2`, `MigratorV2V3`,
  `NFTStakerDepletion` (V1), `NFTStakerMigrator`, `DepositView`, `DepositPageView`.
- Keep **two exceptions**: the StableStakerV1→V2 cutover (story-080) and the index-6
  `buggedPoolerV2Index6` disabled placeholder.
- Keep the local chain fully working for the UI.

Measured against that statement, the commit does what it says. `script/DeployMocks.s.sol` goes 3,057 → 2,500
lines; direct imports 74 → 65; the broadcast goes 477 → 350 transactions (74 → 63 `CREATE`, 403 → 287 `CALL`).
Every declared pre-condition and every surviving post-condition **passed** on the real local run
(`artifacts/forge-head.log:362` — *ONCHAIN EXECUTION COMPLETE & SUCCESSFUL*), and the four downstream steps
(`simulate-yield.sh`, `extract:addresses`, `generate:ts-anvil`, `serve`) all exited 0.

### Where intent is not reviewable — the authorisation gap (F-01, `pps30f1`)

Be precise about this, because a sweeping version of the claim would be wrong. The story tree was read in
full, not sampled:

- An exhaustive glob of `~/code/product-owner/stories/phStaging2/` across **every** state folder
  (`complete`, `auto-complete`, `incomplete`, `review`, `archive`) and every sprint/worktree folder returns
  **82 documents, topping out at story 081**. There is no 082 and no decimal insertion above 081.
- A whole-tree grep for the vocabulary such a story would need — `slim`, `retire-the-rehearsal`,
  `remove-old-cutover` — returns **zero** matches. `trim` matches exactly twice, in
  `074-persist-bpt-cutover-baseline-across-resume-legs.md` (hand-trimming a resume state file) and
  `045-mainnet-deploy-nft-staking-differential.md` ("trim it to the three", a JS patch script). Neither
  concerns `DeployMocks.s.sol` or the rehearsal.

Under `storyPolicy` that is the standard for a negative: **the story genuinely does not exist** — this is
not a report that a story was external or unavailable.

Story-079 sits in `complete/` with all six of its `L-01` acceptance items ticked. `e6eded0` unwinds five of
them (536, 537, 538, 539, 541) and retains one (540, `_pinNudgeRatchetStaticClaims`). Items 533–535 (the
`LOCAL_PROMO_KENDU` toggle) and 542 (the privilege sweep) are **untouched**. That selectivity is itself the
evidence that this is a deliberate, scoped reversal rather than a botched revert.

**In fairness to the change**: the in-source comments make a *coherent* obsolescence argument, and it may
well be right. This review does not claim the three deleted rehearsals are still needed. The finding is that
**the judgement is unreviewable as filed** — a `fix-pending` remediation was withdrawn on reasoning that
exists only in code comments, in a commit nobody was asked to approve.

### Priority 1 — the regression (L-02, `pps26l1`, fingerprint `eda17642828a6dd3bce6890d9900add9d27a317f80b78212a30f123301d17fd4`)

Ledger entry `eda17642…` — *"`dev` rehearses the cutover's end state but not its cutover mechanics"* — is
status **`fix-pending`**. Under this repository's rules that is the one human-set status which is *not* a
disposal: the finding was accepted **and a fix is owed**, so it is never suppressed and never auto-closed.
Story-079 landed that fix. `e6eded0` deletes it.

Measured against the committed baseline broadcast artifact:

| selector | baseline `9563c68` | head `e6eded0` |
|---|---|---|
| `UniboostMintDebtHook.pull()` | 1 | **0** |
| `UniboostMintDebtHook.setDispatcher(...)` | 1 | **0** |
| `NFTMinterV2.replaceDispatcher(...)` | 1 | **0** |
| `NFTMinterV2.mint(uint256,address)` | 10 | **0** |
| `NFTStakerDepletion*.topUp(uint256)` | 6 | **0** |
| `NFTStakerDepletion.depositFor(address,uint256)` | 9 | **0** |
| `NFTStakerMigrator.migrate(address[])` | 3 | **0** |
| `MigratorV2V3.seedUsers` / `migrate` | 3 | **0** |

*(`artifacts/s1-selector-counts-head.log`, `s1-selector-counts-baseline.log`, `s1-baseline-targets.log`; the
deleted helper is preserved verbatim at `artifacts/s3-deleted-rehearsal.txt`.)*

The ordering this rehearsal exercised is the one the mainnet key's own documentation says "LEAKS VALUE
SILENTLY" when run in reverse: `pull()` → `hook.setDispatcher(new)` → `new.setHook(hook)` →
`replaceDispatcher(idx, new)`. At the baseline the local chain executed all four exactly once. At head it
executes none.

**Three standing propose-fixed recommendations are withdrawn by this run** — run-27 `DEV27-V01`, run-28
`run28Proposal`, and run-29's EXECUTED-grade reaffirmation. Each rested on `_rehearseDispatcherSwap`, which
no longer exists in the tree; carrying any of them forward would close a live finding on the strength of
removed code. **No `/ledger … fixed pps26l1` command is emitted by this run**, and the entry's status
remains `fix-pending`.

---

## Lens 2 — Side effects

The `dev` key has no `:preview` or `:dry` sibling; it always really broadcasts. Side effects below were
therefore observed on a throwaway local chain, not inferred.

### The proven shortcut — a removed detector (L-01, `pps30l1`)

`_finalizeUniboost` (`script/DeployMocks.s.sol:1733-1744`) writes
`dispatcher.setNudgeStreamer(address(nudgeStreamer))` on each of indices 1/2/3 and **never reads it back** —
unlike the `StableYieldAccumulator` idiom one screen away at `:1267`, which does `require` the read-back. At
the baseline that omission was caught *transitively*: story-079's `_accrueIndex1MintDebt` drove one real
`NFTMinterV2.mint` through index 1, and an unset streamer reverts that mint.

A four-run controlled experiment settles whether the detector is weakened or gone. The break is a single-line
comment-out at `:1736` (`artifacts/s3-break-patch.diff`):

| run | wiring | probe mint | exit | result |
|---|---|---|---|---|
| CONTROL | intact | none | `0` | `artifacts/s3-control-sim.log` |
| BROKEN | **removed** | none | **`0`** | `artifacts/s3-broken-sim.log` — **the script goes green while misconfigured** |
| BROKEN + PROBE | **removed** | one mint | **`1`** | `artifacts/s3-broken-with-mintprobe.log` — `Error: script failed: Uniboost: nudgeStreamer unset` |
| PRISTINE + PROBE | intact | one mint | `0` | `artifacts/s3-pristine-with-mintprobe.log` |

Rows 2 and 3 are the finding: the misconfiguration is still *detectable*, and the mint was the only thing
detecting it. The detector is gone, not degraded.

**Why this is Low and not Medium.** The Medium case is real and was stated at its strongest before being
rejected: the misconfiguration this used to catch reverts *every* mint on indices 1/2/3, which is a
protocol-availability shape. It does not reach Medium because the availability impact is not caused by this
defect — it requires a *different*, hypothetical operator error that has not occurred, and that error would
also have to evade the mainnet path's own detector. **It would not**:
`script/archives/DeployMainnetPromotionReady.s.sol:2455-2465` carries an explicit bidirectional wiring
assertion phase that `require`s a `nudgeStreamer()` read-back on all three Uniboosts, the pooler, the ratchet,
the SYA and the batch minter, each with a named failure string. The deleted local rehearsal was a redundant
earlier layer, never the sole detector. The blast radius of its loss is local.

### The fidelity divergence — a frozen literal (L-03 leg (b), `pps30l3`)

Mainnet Phase 4e builds `PhlimboV3`'s constructor arguments by reading them **live off the predecessor**:

```solidity
// script/archives/DeployMainnetPromotionReady.s.sol:1752
address v2Reward   = address(v2.rewardToken());
uint256 v2Duration = v2.depletionDuration();
```

The slimmed local helper replaces that with a literal (`script/DeployMocks.s.sol:2258-2263`),
`uint256 oneWeekInSeconds = 604800`, whose NatSpec justifies the value as "the ones V2 carried and V3
inherited at the mainnet cutover".

| | mainnet (fork @ 25949772) | local anvil @ `e6eded0` |
|---|---|---|
| `PhlimboV2.depletionDuration()` | 2,592,000 (30 d) | contract no longer deployed |
| `PhlimboV3.depletionDuration()` | 2,592,000 (30 d) | **604,800 (7 d)** |

The stated justification is false, and the local window runs **4.29× faster** than mainnet's.

**Two things keep this Low.** First, the divergence itself *predates* `e6eded0` — the local V2 was also
constructed with `604800`, so the live read used to resolve to the same wrong number; what this commit adds
is the false claim and the loss of the read. Second, and decisively, **the literal has no mainnet consumer
and cannot propagate**: mainnet Phase 4e still reads the value live off V2 at `:1746`, Phase 4e has already
executed (mainnet PhlimboV3 is live with 13,684 phUSD staked), and its script is archived with its
`promotion-ready:dry` / `:broadcast` npm keys deleted (ledger `3b7430a7`, wont-fix). Nothing is pending
against this divergence.

### The false rationale — and why no funds are stranded (L-03 leg (a), `pps30l3`)

The comment replacing the deleted `PhlimboEA` key in `server/deployments/mainnet-addresses.ts:46-56` states
that V2 "still exists on mainnet wound down, mint-revoked and **NOT paused so a late staker can still
exit**". The same claim is repeated in `script/archives/interactions/AddressLoader.sol:86-92`.

Fork @ 25949772 (`artifacts/s5-mainnet-phlimboea.log`, spot-reproduced by the orchestrator):

```
paused()            = true
totalStaked()       = 0
depletionDuration() = 2592000
phUSD.balanceOf()   = 0
USDC.balanceOf()    = 0
```

**Say this plainly: nothing is stranded.** The contract holds no stake and no balances, so there is no late
staker and no trapped value. This is a **false-rationale** finding — an irreversible edit justified by an
assertion about mainnet that was never checked — not a stranded-value one. It is filed at Low on exactly
that basis.

The related worry that deleting the key strands `AddressLoader.getPhlimboV2()` was **investigated and
refuted**: `AddressLoader.get()` reads `server/deployments/local.json` (not `mainnet-addresses.ts`), is
hard-gated `require(block.chainid == 31337)`, fails **loudly** with a named message, and every importer bar
one lives under `script/archives/**` (excluded from the build) — the one exception,
`ClaimWithdrawStableStaker.s.sol`, only mentions it in a comment.

### Other observed side effects

- **Q-01 (`pps30q1`)** — the three `NFTStakerDepletionV2` instances (`UniboostStakerEYE/SCX/FLX`) are
  published to the UI with `totalStaked = 0`, `phUSD.balanceOf = 0`, `rewardBudget = 0`, `rewardRate = 0`,
  and `depletionWindowMonths = 12`. `topUp` (6→0) and `depositFor` (9→0) were the only producers, and
  `_deployUniboostStaker` never tops up. **Not bricking**: `setDepletionWindow(12)` against a zero budget is
  inert (rate 0, `windowEnd = now + 365 d`, verified live), and the state **self-heals on the first
  `hook.pull()`** (`NFTStakerDepletionV2.sol:435-450`). The cost is representativeness, not function.
- **`StableStakerV1`/`V2` retain the `CrossVersionMigrator` role** at end of run (tx 297/298, never stood
  down). **Pre-existing**, ledger `08adbb69…` (open) — not introduced by this commit, and not re-filed.
- **Off-chain artefacts** moved coherently: `progress.31337.json` 73 → 70 keys; `addresses.ts` 58 → 57;
  `local-addresses.ts` addresses all shifted (CREATE-nonce ordering changed, expected).
  `mainnet-addresses.ts` was **hand-edited**, which is the L-03/F-04 surface.

---

## Lens 3 — Knock-on effects across the cluster

| cluster member | relation | outcome |
|---|---|---|
| `dev-local.sh` | orchestrator | unchanged; all gates passed (port free, pid ownership, block ≤ 100 — observed block 2) |
| `script/archives/DeployMainnetPromotionReady.s.sol` | mirror-target | the two divergences above; **its own assertions are intact**, which is why both stay Low |
| `verify-stable-staker.sh` (`test:stable-staker`) | sibling-consumer | **no breakage** — its targets are all inside retained exception #1, verified end-to-end |
| `simulate-yield.sh` | successor (step 6) | **no breakage** — MockAutoDOLA totalAssets 7,200.24 → 9,500.24 DOLA, exit 0 |
| `script/archives/interactions/AddressLoader.sol` | stranded-consumer | **REFUTED** (see above) |
| `script/interactions/FundTestUser.s.sol` | evidence | ledger `65db3324` (open) — bricked by the terminal sweep, which the slimming **retains**; unchanged, not re-filed |
| `Temp.s.sol`, `StakeStableStaker.s.sol`, `ClaimWithdrawStableStaker.s.sol` | sibling | no interaction |

**Q-02 (`pps30q2`)** is the one knock-on worth acting on: two in-source references to the deleted Phase 7.4
survive. `:408` is a stale navigational pointer (harmless). `:2031` is not — inside the **retained** story-080
cutover, the justification for revoking `StableStakerV1`'s phUSD mint grant is a comparison to
"PhlimboV2's treatment in the Phase 7.4 cutover", a comparator that no longer exists. The revoke executes
regardless; what is lost is its reviewability. An unverifiable justification for a live privileged action is
worse than an absent one, because it reads as reasoned. This carries a **binding triage dependency** on open
ledger entry `08adbb69…` (run-29 L-06), which states its own basis on the same vanished landmark — restate
it on `_deployPhlimboV3:2314-2321`, the live in-file precedent, or a re-triage will produce a false "cannot
reproduce".

**Q-03 (`pps30q3`)** — `DepositView.sol` and `DepositPageView.sol` are now first-party in-scope contracts
with **zero deployers**, retained only as `wagmi.config.ts` ABIs and an `extract-addresses.js` revival guard.
Both are typed against the V1/V2-shaped `IPhlimbo` 3-tuple `userInfo`; pointed at `PhlimboV3`'s 4-tuple they
**silently mis-decode rather than revert**. No asset impact today (nothing deploys them), and the fix must
not run ahead of fix-pending entry `6b63ef65…`, which still owes an obligation on `DepositPageView` at a
different entry point.

---

## What the slimming got right

This deserves real space, because the answer to the owner's question is not "the slimming was reckless" — it
was mostly careful, and in one place it made the system strictly safer.

**1. The displaced `DepositPageView` registration was removed, and that *improves* the failure mode.**
At the baseline the `deposit` key was written three times (`setPage` at tx 471 → old view, 475 → the V3 view),
so a dropped repoint left the router quietly serving a V1-shaped page. At head the key is written **once**
(tx 348 → `DepositPageViewV3` at `0x5322471a…`), and until that call lands the key is **unset**. A consumer
hitting an unset key reverts loudly instead of silently receiving mis-decoded data. This is the correct
direction for a failure mode and it was done deliberately, per the story-078 keyless-page rule.
*(`artifacts/s8-viewrouter-and-promo.log`.)*

**2. Both compensating safety mechanisms from prior audits survive intact and execute.**
`_sweepResidualPrivileges` — story-079 item 542, the terminal residual-privilege sweep — is retained and ran,
asserting the full 11-row end-state phUSD ACL table (`forge-head.log:260-262`: deployer and StableStakerV1
**out**; PhlimboV3, the minter, StableStakerV2 and five hooks **in**). The `LOCAL_PROMO_KENDU` toggle
(items 533–535) is likewise untouched and exercised. The reversal was surgical: it took story-079's `L-01`
half and nothing else.

**3. The privileged-grant ordering is still correct.** The deployer's phUSD minter grant is taken at tx 31
and tx 142, the last deployer-as-minter mint is tx 143 (`_seedNudgeStream`, 5000e18), and the grant is
revoked at tx 349 — the docstring's claim about ordering is accurate as executed
(`artifacts/s8c-minter-grant-order.log`).

**4. The Kendu promotion timing shift is cosmetic, and was checked rather than assumed.**
Arming moved from tx 417/477 (59 txs remaining) at baseline to tx 41/350 (308 txs remaining) at head. In
wall-clock terms on the local chain that is block 85 (ts 1789076345) versus a last block of 393
(ts 1789077023) — **678 s of an 86,400 s local promo window, or 0.78%**. Decisively,
`PhlimboV3.accPromoPerShare()` is **literally 0** at hand-off, so nothing accrued during the shifted
interval. Material impact: none.

**5. Nothing that was kept is broken.** A retained-but-broken exception would have been the worst available
outcome of this exercise, and it did not occur — see the next section.

---

## The two retained exceptions — both verified working

**Exception #1 — StableStakerV1 → StableStakerV2 cutover (story-080).** Retained untouched and verified
end-to-end on the live local run. `StableStakerV1` is deployed (deliberately untracked) at
`0xccf1769D…`, seeded via `depositFor` with **12 stakers across 3 pools**, drained through
`CrossVersionMigrator` in **2 batches per pool** (`migrate` 6→6, unchanged from baseline), and its phUSD mint
grant is revoked at **tx 308** (`phUSD.setMinter(StableStakerV1, false)`). All cutover post-conditions
asserted. *(`artifacts/forge-head.log:169-190`, `exceptions-verified.log`.)*

**Exception #2 — the index-6 `buggedPoolerV2Index6` placeholder.** Retained and verified live:

```
configs(6) = (0x4631BCAbD6dF18D94796344963cB60d44a4136b6, 1e19, 10, disabled = true)
configs(7) = (0xeF31027350Be2c7439C1b0BE022d49421488b72C  <- NudgeRatchet, 1e7, 10, false)
```

The placeholder does exactly its job: it consumes index 6 so `NudgeRatchet` lands on **index 7**, matching
mainnet. *(`artifacts/exceptions-verified.log`.)*

---

## Findings register

| Label | Sev | What | Mitigation | Where |
|---|---|---|---|---|
| **L-02** *(regression)*<br>`pps26l1`<br>`eda17642828a6dd3bce6890d9900add9d27a317f80b78212a30f123301d17fd4` | Low | Story-079's Phase 7.6 `_rehearseDispatcherSwap` deleted, returning `setDispatcher` / `replaceDispatcher` / `pull` / NFT-mint to zero executions; regresses a **`fix-pending`** ledger entry | Reopen `eda17642` as a regression rather than proposing it fixed; if the swap rehearsal is genuinely obsolete, that needs a story explicitly superseding story-079 items 536–541, not an untagged deletion | `script/DeployMocks.s.sol:1269-1274` (`run`)<br>`reports/30/findings/low/L-02-rehearsal-omits-cutover-mechanics.json` |
| **F-01**<br>`pps30f1`<br>`d862aec474e0f2e8bb06b2c8c9ab8d79b66a8e23bcd10e0a5a867503ae97d76a` | Low | `e6eded0` is untagged, has no story anywhere in the tree, and silently unwinds 5 of story-079's 6 `L-01` acceptance criteria while it sits in `complete/` | Write the story: name story-079 items 536–541 and story-073's staker rehearsal as deliberately superseded, record the retained-exceptions rule and its two members, and carry the compensating assertions (the `setNudgeStreamer` read-back, a non-zero staker budget) so the lost coverage is replaced rather than dropped | `script/DeployMocks.s.sol` (`run`, whole file)<br>`reports/30/findings/faithfulness/F-01-unauthorised-reversal-of-completed-story.json` |
| **L-01**<br>`pps30l1`<br>`4fd01c83c32d0e5476a156c25537ef5053405426b1507c70a53a58079be68bcc` | Low | Deleting the index-1 rehearsal mint removed the only executable proof that `Uniboost.setNudgeStreamer` landed on indices 1/2/3; the run now exits 0 with all three dispatchers unmintable | Add `require(dispatcher.nudgeStreamer() == address(nudgeStreamer), "<label>: nudgeStreamer not wired")` as the last line of `_finalizeUniboost`, matching the SYA idiom at `:1267` — cheaper than restoring the mint and closes the same gap | `script/DeployMocks.s.sol:1733-1744` (`_finalizeUniboost`)<br>`reports/30/findings/low/L-01-unasserted-setnudgestreamer-write.json` |
| **L-03**<br>`pps30l3`<br>`85754b285c30ad497228a2184b853f3fd297201d5cbffe94e272bbb7df837f00` | Low | Two deletions justified by in-source claims about live mainnet state that the fork disproves: (a) PhlimboV2 asserted "NOT paused", fork says `paused() == true`; (b) the new `604800` depletion literal claimed to mirror mainnet, which carries `2592000` | Correct both comments against the chain. For the depletion window either use `2592000` to mirror mainnet, or state the 7-day value as a deliberate local divergence with a reason, the way `LOCAL_STREAM_DURATION` and `LOCAL_PROMO_DURATION` already do | `server/deployments/mainnet-addresses.ts:46-56`; leg (b) at `script/DeployMocks.s.sol:2258-2263`<br>`reports/30/findings/low/L-03-unverified-mainnet-claim-as-deletion-rationale.json` |
| **F-04** *(still open, run 29)*<br>`pps29f4`<br>`ee5aae66ac651277953db1b477d4ba66939701ec5aa7ffe013c2b26b9865e678` | Low | A live mainnet contract's only published resolution path was deleted to satisfy an interface constraint that is unenforced (a `console.error` string, no `tsc`) and already violated by three other keys | Restore the `PhlimboEA` key as a commented historical entry alongside the Burner precedent, or delete the three Burner keys so the rule is real; then make the guard executable (a `tsc --noEmit` over `server/deployments/`, or a node key-set diff wired into `generate:ts-anvil`) | `server/deployments/mainnet-addresses.ts:46-110`<br>`reports/30/findings/faithfulness/F-04-C1-unenforceable-declared-drift-guard.json` |
| **Q-02**<br>`pps30q2`<br>`66671224826b16690cf8dda784af7fc04b650c2f23e13fcfef50c57e243ce574` | QA | Stale references to the deleted Phase 7.4 survive — including the load-bearing justification for a still-live mint-grant revoke inside the retained cutover | Repoint `:2031` at `_deployPhlimboV3:2287-2321`, the live in-file precedent for both the mint grant and the role stand-down, and drop the Phase 7.4 pointer at `:408`; when re-triaging L-06, restate its basis on `_deployPhlimboV3:2314-2321` | `script/DeployMocks.s.sol:408` and `:2031`<br>`reports/30/findings/qa/Q-02-stale-cross-reference-to-deleted-code.json` |
| **Q-01**<br>`pps30q1`<br>`bb029fb3cabf67c8cdbd406e6ddce62f04c9b74d68d1609729d48146b5b31061` | QA | The three `UniboostStakerV2` instances are published to the UI with zero stake and a zero phUSD reward budget: `topUp`/`depositFor` were the only producers and `_deployUniboostStaker` never tops up | Either call `staker.topUp(REHEARSAL_STAKER_BUDGET)` once per staker inside `_deployUniboostStaker` (the constant already existed at `9563c68`), or restore the single index-1 mint so `hook.pull()` funds them organically; assert `rewardRate > 0` afterwards so a future removal fails loudly | `script/DeployMocks.s.sol:2407-2434` (`_deployUniboostStaker`)<br>`reports/30/findings/qa/Q-01-producer-removed-consumer-retained.json` |
| **Q-03**<br>`pps30q3`<br>`e15cd2e251414517607a2cc9e2d4a7a8892448bba9ad1d330f178a331747ea14` | QA | `DepositView.sol` and `DepositPageView.sol` are now first-party in-scope contracts with zero deployers, retained only as wagmi ABIs and a revival guard, and silently mis-decode `PhlimboV3`'s 4-tuple `userInfo` | Delete both sources and their wagmi entries, or add a compile-time impossibility (retype against `IPhlimboV3`, which will not compile against the 3-tuple); keep the `extract-addresses.js` guard entries either way and note them as deliberate. Preferred: the retype, because deletion would moot the open fix-pending obligation on `6b63ef65…` | `src/views/DepositView.sol`, `src/views/DepositPageView.sol`<br>`reports/30/findings/qa/Q-03-orphaned-first-party-depositview.json` |

Severity ruling for the run, stated once: **the central question was whether a local rehearsal that goes
green while a mainnet-fatal misconfiguration is present is a Medium on protocol-availability grounds.** It is
not — it is a reduction in assurance. Medium was explicitly considered and rejected on evidence for L-01,
L-02 and L-03; the decisive facts are the mainnet path's own retained assertions
(`DeployMainnetPromotionReady.s.sol:2455-2465`), its live `depletionDuration()` read (`:1746`), and the fact
that the cutover the impact story invokes has **already executed** on a script that is now archived with its
npm keys deleted.

**Known-issues suppression was BLOCKED for this entire run.** The declared source
`phoenix-phase-2-staging/src/known-issues.md` does not exist at `e6eded0` (re-verified: `ls` fails and
`git ls-tree -r --name-only HEAD | grep -iE 'known|issue'` returns zero rows). The 11 cached entries are a
registry-only 2026-01-09 snapshot that cannot be falsified against its declared source, so **zero findings
were suppressed on known-issue grounds** — the third run in a row to reach that disposition (watch-note
KI-24-01). The entry a naive reading would have invoked — KI #2, "mock contracts … testing infrastructure
only" — is recorded as considered and **not applied**.

---

## Manual review — parked for a human, deliberately not decided here

### MR-30-DEV-01 — four OPEN run-27 entries are anchored on the deleted helper. **Do not auto-close them.**

| fingerprint | run-27 label | root-cause class |
|---|---|---|
| `6af1ae30ed82…` | L-02 | `PartialRehearsalCoverage` |
| `19e2e0c2d6a3…` | L-03 | `AssertionRestatesPremiseNotConsequence` |
| `9ee101a0cc41…` | L-04 | `RetiredContractRetainsValueNoSweep` |
| `9067d8a232b5…` | Q-01 | `IncompleteAssertionCoverage` |

All four describe defects **inside** the Phase 7.6 dispatcher-swap rehearsal. That code no longer exists at
`e6eded0`, so a naive regression scan will observe them as no-longer-flagged and may propose them fixed.

**Ruling: do not flip any of the four to `fixed`, and do not propose it.** Closing them by deletion would
**ratify precisely the reversal** that L-02 and F-01 report as unauthorised, and all four re-materialise the
moment the rehearsal is restored — which is exactly what L-02's recommendation asks for. The correct
disposition is a human decision taken on the same record as L-02/F-01: either the rehearsal comes back (all
four are live again), or a superseding story retires it (and then they close **with that story cited**, not
silently).

### MR-30-DEV-02 — broken ledger `reportPath` prefixes

Both carryover sources this run record paths under the **pre-restructure** prefix that no longer resolves:
`eda17642` → `reports/phoenix-phase-2-staging/26/…`, `ee5aae66` → `reports/phoenix-phase-2-staging/29/…`.
The live files were located under the current per-project layout at `reports/26/…` and `reports/29/…` and both
were verified present. Harmless where a human resolves it, but a downstream stage that copies `reportPath`
literally will fail to find the file and may emit a pointer stub instead of a full carryover — a Law-1
carryover failure. **Action (human)**: normalise `reportPath` across the ledger, or teach finding-manager to
strip the legacy prefix.

### MR-30-DEV-03 — the L-03 anchor question (split recommended, **not applied**)

L-03 is anchored at `server/deployments/mainnet-addresses.ts`, but **leg (b) — the `604800`-vs-`2592000`
depletion literal, the only leg with ongoing effect — lives in `script/DeployMocks.s.sol:2258-2263`.** The
severity classifier **recommended splitting leg (b)** into its own entry as the recall-safer option, and
deliberately did **not** re-anchor: re-anchoring re-mints the fingerprint (`85754b28…` would be replaced by a
hash over the `DeployMocks.s.sol` path), which is a human/ledger decision, not an agent one. The record is
filed at the anchor it arrived with and **both legs are pinned in its `instances` array** so neither can be
dropped downstream. **Binding: leg (b) must survive whatever anchoring is chosen.**

### Also still binding, carried without change

- **F-04's inherited DO-NOT-COLLAPSE** against `pps29f3` / `c476a12b04fa…` — respected; the two were not
  merged. F-04 is likewise **not** collapsed with L-03 (`85754b28…`), which touches the same file and the
  same deletion but is a different root cause with a non-overlapping fix.
- **SAN-26-DEV-02** — `c294d93f772bf5cb` (fixed) and `0b497be32114147a` (open, QA) still carry **no**
  `rootCauseClass`, so their fingerprints remain unauditable. Backfill still owed, human-only.
- **FR-28-03** — `1e8cc0dc58ba` still records a TIMING class string on a VALUE finding. The `/ledger`
  correction and the fingerprint re-mint it implies are still pending.
- **SAN-26-DEV-04** — `a37137b3e369` (Q-03) must be **split, not closed**, if only its manifest half is fixed.
- **MR-26-DEV-01**, **MR-22-01** — still parked, not triggered by this run.

---

## Tooling limitation — state honestly

**4naly3er could not analyse `script/DeployMocks.s.sol`**, which is the entry point's own script and the
location of **Q-01 and Q-02**. solc fails the file with `DeclarationError: Identifier already declared`: the
script imports across several top-level submodules, each vendoring its own nested copy of the shared
dependencies (`pauser`, `vault`, `phlimbo-ea`, …). `foundry.toml` canonicalises those with literal-path
redirect remappings, and 4naly3er's import resolver does not apply them the way forge does, so two physical
files supply the same interface. **forge builds the same file green**, so this is a tool limitation on this
repository, not a defect in the script.

**Its silence on `DeployMocks.s.sol` is not a clean result for that file.** Q-01 and Q-02 rest on manual
review and on this run's own execution artifacts.

It did run clean over **22 other first-party files** (`src/views/` 6, `src/mocks/` 16) with **0 AST failures**,
using a `remappings.txt` materialised in `work/` from the 68-entry `remappings` array in `src/foundry.toml`.
Report: `reports/30/submissions/4naly3er-report.md`.

---

## What was not tested

Stated so the evidence is not read as stronger than it is.

- **No fresh baseline re-run at `9563c68`.** The head side of every selector-count comparison **is fresh** —
  produced by this run's real local broadcast. The baseline side is read from the **committed** broadcast
  artifact (`git show 9563c68:broadcast/DeployMocks.s.sol/31337/run-latest.json`). A committed artifact can in
  principle diverge from what a re-run would produce today; it was not re-executed.
- **`npm run serve` was exercised only for the `/health` re-check.** It was started and probed to confirm the
  run-28 finding `8cd3c3ba…` is still open (it returns `{"status":"ok","deploymentsLoaded":true}` even with
  anvil killed). No UI session, no route coverage, no consumer of the regenerated `local-addresses.ts` was
  driven.
- **The Kendu materiality call rests on arithmetic plus one observation, not a simulation.** It combines
  elapsed-time arithmetic over the observed block timestamps with the live reading
  `PhlimboV3.accPromoPerShare() == 0` at hand-off. **No UI session was simulated** against the shifted promo
  window.
- **No mainnet write of any kind.** The fork was used for read-only `cast call`s at block 25949772.
- **Q-01's self-healing claim is read from source, not executed.** `NFTStakerDepletionV2.sol:435-450` was read
  to establish that the first `hook.pull()` refills the budget and restarts the schedule; no `pull()` was
  driven on the local chain to demonstrate it.

---

## Bottom line

The slimming is defensible work with three real shortcuts in it, none of which endangers an asset. In
priority order for the owner: **restore or explicitly supersede the deleted Phase 7.6 rehearsal** (it is the
one item that regresses an accepted, fix-owed finding, and it drags four other open entries with it); **add
the one-line `setNudgeStreamer` read-back** to `_finalizeUniboost` (cheap, and it replaces the detector the
deleted mint used to provide); and **correct the two false in-source claims about mainnet** — the `paused()`
assertion and the `604800` justification — so that no future deletion is argued from them. Then write the
story, so the next reader can weigh the obsolescence argument the code comments already make well.
