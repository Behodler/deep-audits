# Script Review — `dev` (phoenix-phase-2-staging, run 29)

**Project**: phoenix-phase-2-staging · **Run**: `phoenix-phase-2-staging-29`
**Commit**: `9563c68094e516a91d27684252e6a103271d69cf` (`9563c68`), branch `master`
**Baseline**: `f929b5b` (`entryPointBaselines.dev`, set by run 28)
**Entry point**: `dev` → `./dev-local.sh`; sibling `test:stable-staker` surfaced and audited cold
**Delta**: `ac70af6` [story-080], `9563c68` [story-081]
**Mode**: local-anvil **real execution**, chain 31337. 11 executed tests. No mainnet fork, nothing broadcast to any real network.
**Result**: **0 High, 0 Medium**, 6 Low, 1 QA (2 of which are Law-2 faithfulness). One prior Medium verified fixed by execution.

---

## Headline — run-28's Medium is a complete fix, proved by running it

The most important thing this run has to report is a **positive result**.

Run-28 filed Medium `11311795cd60…` — *"`dev` is two concurrent shell pipelines with no anvil-ownership or
genesis-freshness check, so DeployMocks broadcasts onto a pre-existing chain and every post-condition still
passes."* Story-081 set out to close it. **It closed it.** The verdict rests on execution, not on reading the
patch:

1. **Port pre-flight refuses any answering node.** `dev-local.sh:48-55` runs `cast block-number` against
   `:8545` and exits when it *succeeds*. Tested against a leftover anvil at deployer nonce 0 **and** at nonce 1
   (test C1): both refused, with `Error: something is already answering on http://localhost:8545. … Kill it
   (pkill anvil) and re-run.` The leftover node was correctly left alive rather than killed by our trap.
2. **The Solidity freshness gate fires when the pre-flight is bypassed.**
   [`DeployMocks.s.sol#L443`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/script/DeployMocks.s.sol#L443)
   `require(block.chainid == 31337, "DeployMocks: local only")` and
   [`#L445-L446`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/script/DeployMocks.s.sol#L445-L446)
   `require(vm.getNonce(deployer) == 0, "DeployMocks: chain is not fresh - a prior deployment is already on
   8545; kill it and re-run")`. Test C2 reached the second gate through the *new standalone* `deploy:local:forge`
   key — the path any developer or sibling script can call without touching `dev-local.sh` — and observed
   `VM::getNonce(0xf39Fd6e5…) -> 1` then the revert with the exact declared string.
3. **The one variant that could have defeated it was tested, and fails closed.** A mainnet-forked anvil forced
   to `--chain-id 31337` slips past the chainid gate by construction. Test F ran exactly that against a live
   mainnet fork (block 25943238): the chainid gate did **not** fire, but anvil **preserves the forked nonce**,
   and the deployer is anvil's publicly-known account 0 — `cast nonce 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`
   → **7893**. The freshness gate fired. `grep -c 'deployed at:'` → **0**: not one mock landed on the fork.
   **State this honestly**: the gate is decisive here *because of which key anvil hands out*, not because the
   script reasons about forks. A fork of a chain on which that address had never transacted would still be
   adopted. For the mainnet this repo actually forks, the gate holds.
4. **The teardown works.** SIGINT to the process group (interactive Ctrl-C) printed `Tearing down Anvil
   (pid 48640)…`, anvil gone, `:8545` refusing connections — closing run-28's specific complaint that
   `npm run dev` exited 0 with its own anvil still alive. A *failed* run tears down too (test B).

**Proposed** ledger action: `11311795cd60` → `fixed`. Not applied — see *Ledger proposals* below.

### The happy path

Test A ran the whole stack end to end on a clean machine: forge simulation, then
`ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.` — **477 transactions, 74 CREATE, 403 CALL, 55 distinct contracts,
0 failed receipts** — then `simulate-yield.sh`, `extract:addresses`, `generate:ts-anvil`, and `npm run serve`
bound and answering **HTTP 200** on `:3001`. Every story-080 post-condition passed: Phase 6.5a
(`STAKER_VERSION()==2`, `isApprovedMinter` by read-back, `phUSDMintAvailable`, `autoAnnihilateAvailable` ×3,
`claimEnabled` still false) and Phase 6.5b (12 stakers seeded per pool, `batches > 1` per pool,
`_assertStableStakerCutover` ×3, V1 drained, V2 sum matching, terminal ACL sweep asserted).

### Phase 7.6 — run-26's L-01 closed, and observed executing

Story-080 also lands `_rehearseDispatcherSwap`, the dispatcher-swap rehearsal that answers run-26 L-01
`eda17642828a…` (*"setDispatcher/replaceDispatcher/hook.pull() execute ZERO times"*). It was **observed
executing**, both in the simulation transcript and as mined broadcast transactions, in the fail-closed order:

| # | Target | Call | Status |
|---|---|---|---|
| 433 | `NFTMinterV2` | `mint(uint256,address)` — seeds the debt | `0x1` |
| 434 | `UniboostMintDebtHook` | `pull()` | `0x1` |
| 435 | `Uniboost` | CREATE (replacement) | `0x1` |
| 438 | `UniboostMintDebtHook` | `setDispatcher(address)` | `0x1` |
| 439 | `Uniboost` | `setHook(address)` | `0x1` |
| 440 | `NFTMinterV2` | `replaceDispatcher(uint256,address)` | `0x1` |

Realised mint debt through `pull()`: **5015015000000000000 wei** — non-zero, which matters, because the
conservation assertion is gated by an explicit anti-vacuity `require` at `DeployMocks.s.sol:1917-1918` that
refuses to proceed on a zero debt. The conservation check itself is a `require`, so a failure aborts in
simulation and nothing broadcasts; the run reached `ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.`. The call site
[`DeployMocks.s.sol#L1364`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/script/DeployMocks.s.sol#L1364)
is straight-line and unconditional — no `if`, no env toggle, no `try/catch`.

**Provenance caveat, stated rather than glossed**: test A's own per-function broadcast list did not survive
cleanup (`run-latest.json` was restored to the committed artifact; the surviving cache file records only
`{"rpc": …}` per entry, confirming 477 txs but no function names). The enumerated ordering above comes from an
**independent re-run at the same commit `9563c68`** (`npm run deploy:local:forge` against a fresh anvil), which
reproduced the identical 477 tx / 477 receipt / 0 failed shape and the identical realised pull amount. The
artifact `classified-findings.json` still labels this proposal *"source-level evidence only"*; that grading
predates the executed evidence in `side-effects.json`, which supersedes it.

---

## (1) Does the script do what it intends?

**Yes.** All four declared shell pre-conditions and both Solidity gates behaved as specified under test, and
every declared post-condition passed on the happy path. One declared pre-condition **fails on a clean shell**,
and one is soft by design:

| Gate | Where | Verdict | Evidence |
|---|---|---|---|
| P1 port pre-flight | `dev-local.sh:48-55` | **PASS** (hard) | C1 — refused at nonce 0 and nonce 1 |
| P2 anvil pid alive + answering | `dev-local.sh:73-91` | **PASS** (hard) | C5 — caught `Address already in use`, `Anvil (pid 52042) died during startup.` |
| P3 listener pid == our anvil | `dev-local.sh:99-116` | **PASS**, **soft** | A confirmed ownership; C4 proved the warn-and-continue branch when neither `ss` nor `lsof` exists |
| P4 block-number ≤ 100 | `dev-local.sh:118-128` | **PASS** | A/B — `Block number at hand-off: 0` |
| P5 `block.chainid == 31337` | `DeployMocks.s.sol:443` | **PASS** | A trace |
| P6 `vm.getNonce(deployer) == 0` | `DeployMocks.s.sol:445-446` | **PASS** | C2 fired with the exact declared string; C3 confirmed the proof is sound |
| P7 `ANVIL_PRIVATE_KEY` present | `DeployMocks.s.sol:419` | **FAIL** | B — absent on a clean shell; supplied only by an untracked, gitignored `.envrc` → **Q-02** |

Two negative results worth recording because they were *attempted defeats* that did not succeed:

- **C3 — dirty chain, deployer nonce still 0.** Another account deployed a contract and 152 blocks were mined;
  the freshness gate did not fire and the rehearsal proceeded. This is **not** a defeat. With `nonce(deployer)==0`
  the CREATE addresses are byte-identical to a fresh chain (`MockPhUSD 0x5FbDB231…`, `Antimatter 0x325c8Df4…`,
  `StableStakerV2 0x627b9A65…`, all matching test A), and no prior DeployMocks state can exist without a deployer
  transaction. `nonce(deployer)==0` is a sound proof of the specific harm run-28 named.
- **C6 — the block-height gate is effectively unreachable as a sole guard.** P1 refuses any answering node before
  P4 is evaluated, and P3 covers the race window whenever `ss` or `lsof` exists. Noted, not filed.

**Law 2.** Story-080 and story-081 both sit in `auto-complete` with **self-reported** verification; story-080
self-reports `independence: reduced` (*"these verdicts were reached by one agent rather than five"*) and was
machine-approved on a `PASSED` review that itself carried a `[medium] Verification gap` — its reviewer never
re-executed `npm run test:stable-staker`. **This run closed that gap by executing it**, which is how **F-03**
was found. Story-081's four gates were hand-run only; **all four were independently re-verified by execution
here**. Story-080 deviated from its own checklist in five further places, all **safe and honestly recorded** —
including the **inversion**, where the checklist said to repoint `verify-stable-staker.sh` at
`script/archives/interactions/` and the implementation instead `git mv`'d the files *out* of that directory.
That is the correct call: `foundry.toml:32` carries `skip = ["script/archives/**"]`, so a target under that
path cannot compile and **no path repair could make the literal instruction work**. Two checklist items are
ticked but not met: **F-03** and **F-04**. Full grading, including the verbatim acceptance text, is in
[`submissions/spec-conformance.md`](../../submissions/spec-conformance.md) and is not duplicated here.
**F-01** and **F-02** (story-079's *"Do NOT gate the Kendu nudge stream"*) are **carried forward unchanged** —
neither delta commit touches `_seedNudgeStream`.

---

## (2) Does it introduce unintended side effects?

**On chain: none beyond intent.** All 477 transactions land on the throwaway local chain; the closure's
`onChain` set is empty by construction, so no pre-existing deployed contract is addressed by this entry point.

**On files**, one pre-existing defect gets a sharper edge. `clean:local` deletes two **git-tracked** files —
`broadcast/DeployMocks.s.sol/31337/run-latest.json` and `server/deployments/progress.31337.json` — and only
later legs recreate them. Test B showed the consequence: **a failed run leaves both ` D` — deleted and never
regenerated**, so the developer is left with a dirty tree and no stack. This is the same root cause as existing
ledger entry **`bd268808fbd5`** (same file, same step, same entry point), a worse manifestation of one defect
rather than a second defect, and it was **deliberately not minted as a new fingerprint** — splitting it would
split that entry's history. One scope note belongs on it: the *"…AndLiveNode"* half of its `rootCauseClass` no
longer holds for `dev` (story-081 moved `clean:local` to run *before* anvil starts), but still holds for
`deploy:local` as invoked by `verify-stable-staker.sh`. That is a **note only** — editing the `rootCauseClass`
string would re-mint the fingerprint.

Two side effects **improved**: story-081 removed the out-of-repo `rm -rf ~/.foundry/anvil/tmp/*` from
`clean:local` (confirmed untouched this run), and `hooks/generated.ts` is provably outside this closure
(md5 `fdc861be…` unchanged across a full run). `addresses.ts` and `local-addresses.ts` differ by **one line** —
the header timestamp — across two independent full runs; the deterministic CREATE addresses reproduce
byte-identically.

**On processes**, one real gap: a `SIGINT`/`SIGTERM` delivered to `dev-local.sh`'s **own pid** rather than its
process group leaves anvil running, because bash defers a trapped signal until the foreground child returns and
`npm run serve` never returns. Interactive Ctrl-C is unaffected. Filed as **L-07**.

**The Medium candidate that was walked back.** `verify-stable-staker.sh` (`npm run test:stable-staker`) has no
`kill -0` check in its readiness loop, so when its own anvil dies on bind failure the loop falls through on a
*foreign* node's answer, prints `Anvil is up.` about a dead process, and runs the entire story-080 V1→V2 cutover
verification against a node it does not own — then reports `ALL ASSERTIONS PASSED` and leaves that node alive and
dirty at deployer nonce 480. Test D2 reproduced this exactly. It was **proposed Medium** on the false-assurance
channel and **honestly walked back to Low** once the misleading variants were tested rather than assumed: the
only adoptable node is one that was *fresh* at hand-off, in which case the deployment is functionally identical
to a self-started one and the verification result is legitimate; and the variant that could have made the result
genuinely false — a mainnet fork forced to 31337 — **fails closed** (test F). Both remaining consequences are
loud, not silent: the next `npm run dev` refuses at its pre-flight and the next `npm run test:stable-staker`
reverts on the freshness gate. The walk-back is itself a result and is recorded as one. Filed as **L-05**.

---

## (3) Have other problems surfaced because of it?

- **A new entry point entered the ledger.** `test:stable-staker` had no baseline; story-080 retargeted
  `verify-stable-staker.sh` in this same delta, so it was audited **cold**. Two findings originate there
  (**L-05**, **F-03**) and a cold baseline at `9563c68` was created.
- **Cluster items assessed and cleared**, with reasons, so a later reader does not re-open them:
  - **The dropped live `StableStakerV1` mainnet address `0xbce8ABC0…`** — cleared. No in-repo consumer reads
    `mainnetAddresses.StableStaker`; the live address is hardcoded in `scripts/gather-migration-inputs.js:52`
    and nine `script/*.sol` files, and the retirement is recorded in the file's own comment. The only readers
    are external UI projects, for which the removal *is* the intended retirement signal.
  - **wagmi / `hooks/generated.ts`** — fix landed. `stableStakerV2Abi` and `antimatterAbi` are present and
    `stableStakerAbi` is gone (grep 2 and 0). Relates to ledger `8aa45828a222` (wont-fix); not re-filed.
  - **`StableStakerV1` losing its phUSD mint grant** — faithful. The revoke at `DeployMocks.s.sol:2308` is
    sequenced **after** `_assertStableStakerCutover` at `:2296` proves `stakerCount==0` / `totalStaked==0` for
    all three pools; revoking first would have bricked the migration being asserted. No `pause()` wrapper is
    owed here (contrary to the stable-staker `ss15m1` operational obligation) because **V1 self-locks**:
    `initiateMigration` moves the pool to `PoolState.Migrating` and stake/withdraw/claim each
    `require(poolState[token] == PoolState.Active)` (`StableStakerV1.sol:331/352/396`).
- **Known-issue suppression was withheld.** The registry's `knownIssuesFile` (`src/known-issues.md`) does not
  exist at HEAD, and the 11 cached entries are an unfalsifiable registry-only cache with `knownIssuesSource: null`.
  **No finding was suppressed on their basis.** Resemblances are annotated per finding for human triage.

---

## Findings register

Seven findings, all filed, none suppressed. `setAside` is empty **by result, not by omission**: 0 known-issue
suppressions, 0 C4 known-invalid matches, 0 Law-3 owner-misuse drops, 0 ledger suppressions.

| Label | Sev | What | Mitigation | Where |
|---|---|---|---|---|
| **L-05** `pps29l5` | Low | `verify-stable-staker.sh` adopts whatever node already holds `:8545` when its own anvil fails to bind — runs the V1→V2 cutover verification on a node it does not own, prints `Anvil is up.` about a dead pid, and leaves the foreign node alive and dirty | Give it the three guards `dev-local.sh` now has (port pre-flight, `kill -0` in the readiness loop, `ss`/`lsof` ownership check) — ideally as one shared helper both source — and upgrade to `set -Eeuo pipefail` with `trap cleanup EXIT INT TERM` | [`verify-stable-staker.sh#L51-L57`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/verify-stable-staker.sh#L51-L57) · entryPoint `test:stable-staker` · [record](../../findings/low/L-05-unowned-node-absorbs-rehearsal.json) · fp `2f86e3864eadb6e29715fda85d1f5df51a5acf56dff39466505d7defadb69551` |
| **L-06** `pps29l6` | Low | Phase 6.5b leaves `CrossVersionMigrator` holding the `migrator` role on **both** stakers, unlike the Phase 7.4 cutover 400 lines below it, and the terminal residual-privilege sweep has no migrator row | Mirror Phase 7.4: after `_assertStableStakerCutover` passes, `setMigrator(address(0))` with a read-back require, and add a migrator row to `_sweepResidualPrivileges` using the same table idiom as `_requireLiveMinter` — or assert positively that V2 is meant to keep its migrator | [`DeployMocks.s.sol#L2304-L2312`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/script/DeployMocks.s.sol#L2304-L2312) · `_rehearseStableStakerCutover` · [record](../../findings/low/L-06-missing-post-step-configuration.json) · fp `08adbb6928403acea22a033a75ad797e7fe88f7bd15aff8c16af81f554cc3cd8` |
| **L-07** `pps29l7` | Low | A `SIGINT`/`SIGTERM` delivered to `dev-local.sh`'s own pid rather than its process group leaves anvil running — bash defers the trap until the foreground child returns, and `npm run serve` never returns | Have `cleanup` also kill anvil's process group, and stop blocking on a child that ignores the queued trap — background `npm run serve` and `wait` on it, or `exec` the server; at minimum document that the stack must be stopped with Ctrl-C, not `kill <pid>` | [`dev-local.sh#L35-L46`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/dev-local.sh#L35-L46) · `cleanup`/`trap` · [record](../../findings/low/L-07-deferred-trap-during-foreground-child.json) · fp `49b9904ee12a1abe85b63d458fee5ede6f8dd447a309191e51b4efd40a220a56` |
| **Q-02** `pps28q2` | QA→Low *(proposed)* | `npm run dev` cannot run on a clean shell: `ANVIL_PRIVATE_KEY` is hard-required but set nowhere in the repo, and the `.env.example` the docs promise does not exist | Default it via `vm.envOr(…, 0xac0974…ff80)` — safe precisely because `:443` already requires chainid 31337 and the key is anvil's public account 0 — or export it in `dev-local.sh`; either way commit the `.env.example` `CLAUDE.md:93`/`:454` already promise | [`DeployMocks.s.sol#L419`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/script/DeployMocks.s.sol#L419) · **UPDATE to existing ledger entry**, not a new one · [record](../../findings/qa/Q-02-undeclared-ambient-env-dependency.json) · fp `d3aa1e35c995a93509a1c3ce85cbd6654319dd5623b20a67b0e7852f81bf602f` |
| **Q-03** `pps29q3` | QA | `dev-local.sh` duplicates `start:anvil`'s flags inline (byte-identical today), so editing the `start:anvil` key no longer reaches `npm run dev` and the two local environments can diverge silently | Keep the direct launch — the pid reasoning is correct — but define the flags once (a shared `ANVIL_FLAGS` source, or read them from `package.json`); at minimum comment the `start:anvil` key pointing at `dev-local.sh:69` | [`dev-local.sh#L69-L71`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/dev-local.sh#L69-L71) · [record](../../findings/qa/Q-03-duplicated-configuration-surface.json) · fp `111b6f04c9b72ba71e4ad9eb7d2dc5df01790dce7e97d1fe95e093d0ef9b41af` |
| **F-03** `pps29f3` | Low *(Law-2)* | `verify-stable-staker.sh`'s header comment and the `package.json` doc key both state a `~10 Antimatter` assertion the harness no longer makes — it asserts the caller's **pro-rata share** | Update both strings to say pro-rata share of the pool's 10 Antimatter/day (quoting `ClaimWithdrawStableStaker.s.sol:86-91`), and record it as a story-080 Autonomous Decision so the checklist tick matches what shipped | [`verify-stable-staker.sh#L6-L10`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/verify-stable-staker.sh#L6-L10); `package.json:36` · [record](../../findings/faithfulness/F-03-documented-assertion-diverges-from-implementation.json) · fp `c476a12b04faf476e46dca810c87bb18357daab3760584328074bb7273267856` |
| **F-04** `pps29f4` | Low *(Law-2)* | Story-080's declared drift guard between `mainnet-addresses.ts` and the regenerated `ContractAddresses` interface does not exist, and the two files **already disagree** (3 `Burner*` keys) | Add a minimal `tsconfig.json` covering `server/deployments/*.ts` with `strict: true`; either declare the three `Burner*` keys via the `_trackDeployment` codegen path story-080 itself insists on, or drop them — then wire `tsc --noEmit` into the workflow that already runs `forge fmt --check` / `forge build --sizes` / `forge test` | [`mainnet-addresses.ts#L39`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/server/deployments/mainnet-addresses.ts#L39) · [record](../../findings/faithfulness/F-04-unenforceable-declared-drift-guard.json) · fp `ee5aae66ac651277953db1b477d4ba66939701ec5aa7ffe013c2b26b9865e678` |

All seven `recommendation` fields are populated; none of the Mitigation cells above is empty.

**Labels** are scoped to this run directory. `L-01`, `L-03`, `L-04`, `M-01`, `F-01`, `F-02` are already occupied
by carryover entries, so new labels start above them. **`Q-02` deliberately keeps its label** because it is an
**update to existing ledger entry `d3aa1e35c995`**, not a new entry.

**One item flagged for human triage**: `Q-03` is the weakest of the seven and sits close to the
maintainability line. It is retained because it has a concrete divergence scenario and because dropping it to
tidy the report is exactly the trade Law 1 forbids — a human may reasonably re-triage it at `/ledger`.

---

## Severity and proportion

`dev` is a **local developer rehearsal harness on a throwaway anvil chain**. There are no user funds in its
blast radius, it broadcasts to no real network, and it has no external attacker. The one harm channel that
matters is **false assurance about the mainnet cutover it certifies** — a rehearsal that reports success while
proving nothing.

That channel is real, and it is what earned run-28 its Medium. This run tested it per finding rather than
assuming it, and it does not reach Medium anywhere here: for **L-05** it is empirically closed (both misleading
variants fail closed on the freshness gate, and the only adoptable node produces a legitimate result); for
**L-06** it is prospective only (the mainnet cutover script does not yet exist). **0 High, 0 Medium** is the
honest outcome, not a rounding down. C4 requires a coded PoC for High/Medium only; none is owed.

---

## Ledger proposals — four, none applied

`fix-pending` is human-set and **never auto-closed**. Every entry below stays live in the scan and is carried
forward in `submissions/carryover/` in full. These are proposals for a human to apply at `/ledger`:

| Fingerprint | Prior | Proposed | Basis |
|---|---|---|---|
| `11311795cd60` (run-28 M-01) | fix-pending | **fixed** | **COMPLETE FIX, execution-verified** — tests C1, C2, C4, C5, F and the Ctrl-C teardown. Residuals **L-05** (sibling entry point) and **L-07** (trap deferral) are filed separately and are **not** incomplete fixes of this entry |
| `eda17642828a` (run-26 L-01) | fix-pending | **fixed** | Phase 7.6 observed executing — txs #433/#434/#438/#439/#440 all `0x1`, non-vacuous conservation assert, unconditional call site at `:1364` |
| `b8e3d59139ae` (run-26 L-04) | fix-pending | **fixed**, **scoped strictly to phUSD mint authority** | `_sweepResidualPrivileges(deployer)` is the terminal statement before `stopBroadcast`. The sweep does **not** cover the migrator role — that gap is **L-06** and must not close with this entry |
| `d3aa1e35c995` | open, qa | **severity → low** + note | Consequence escalates from undocumented to entry-point-unrunnable (test B). `rootCauseClass` left verbatim; changing it would re-mint the fingerprint |

Two entries had **no evidence this run** and stay `fix-pending`, carried forward untouched: `12bcca3b617c`
(run-26 L-03, `_armLocalKenduPromotion` — 0 hits in the delta diff) and `a753907e2a4c` (run-21 M-01, lives in
`lib/nft-staking/src/NudgeStreamer.sol`; `git diff f929b5b..HEAD -- lib` is empty). A note append is also
proposed on `bd268808fbd5` — **note only, no fingerprint change**.

---

## Baselines

Only **`entryPointBaselines.dev`** advanced, to `9563c68`, plus a **new cold baseline for
`test:stable-staker`** at the same commit. The project-level **`lastAuditedCommit` was deliberately held at
`0e190e8`** and **`branchBaselines.master` was left untouched**.

This is not an oversight. This run scanned **one entry point's transitive closure**, not the whole project and
not the whole branch. Advancing either baseline would tell the next regression scan that code it never examined
had been audited, silently dropping it from the diff — a Law-1 failure. Precedent: runs 20 through 28.

---

## Artifact correction

`entry-manifest.json` records the two `run()` gates at `DeployMocks.s.sol:458` and `:459`. At `9563c68` they are
at **`:443`** (chainid) and **`:445-446`** (freshness) — verified identical in `<project>/src` and
`<project>/work` (`diff -q` → IDENTICAL). Line numbers are corrected throughout the run artifacts; the manifest
itself was left unedited. A first draft of this audit also cited the V1 mint-grant revoke at `:2311`; the
authoritative line is **`:2308`**.

Toolchain: forge/anvil `1.5.1-stable b0a9dd9`, node `v24.12.0`, npm `11.6.2`.
