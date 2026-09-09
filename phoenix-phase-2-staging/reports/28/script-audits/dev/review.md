# Script Audit Review — `dev`

**Project:** phoenix-phase-2-staging
**Entry point:** `npm run dev`
**Commit:** `f929b5b` (`f929b5b36629f73d17e350e383c77e2f24c40d71`)
**Delta:** `1d8a3a7..f929b5b` — 9 commits, **zero `[story-NNN]` tags**
**Run:** 28 · **Verification mode:** `local-anvil-real` (real end-to-end execution against a fresh anvil; not a mainnet fork preview)
**Executed from:** `workspace/phoenix-phase-2-staging` (writable clone). `lib/` was never executed from. Nothing in this audit broadcast to mainnet.

---

## Headline

**`dev` works.** A full clean run on a genuinely fresh anvil — port 8545 verified free, deployer nonce 0 at start — completed with:

```
ONCHAIN EXECUTION COMPLETE & SUCCESSFUL
```

394 transactions, 394 receipts, 71 `CREATE`, 323 `CALL`, blocks 1 → ~425, roughly 15 minutes wall clock (11:28:36 → 11:43) — the duration is a consequence of `--slow` against `--block-time 2`, not of anything going wrong. All six pipeline-B steps ran in order: `deploy:local` → `simulate-yield.sh` → `extract:addresses` → `generate:ts-anvil` → `serve`. Every declared post-condition in `DeployMocks.s.sol` passed, including the two that matter most:

- **Phase 7.4 completeness gate** — `PhlimboV2.totalStaked() == 0` after the chunked migration; stake conserved into V3 at `300000000000000000000`; `phUSD.setMinter(PhlimboV2, false)` mint authority revoked; `PhlimboV2.setMigrator(0)`.
- **Phase 7.6 conservation gate** — `hook.pull()` realised `5015015000000000000` phUSD, matching `hook.mintDebt()` exactly; the intermediate dispatcher window behaved in the correct direction (a mint would have reverted `OnlyDispatcher()`); `replaceDispatcher` preserved price/growth (`10040060 10`).
- **Terminal privilege sweep** — `phUSD.setMinter(deployer, false)` followed by the declarative 10-entry end-state ACL table: *"deployer + PhlimboV2 OUT, V3 + minter + staker + 5 hooks IN"*.

All four of story 003's acceptance criteria are met: anvil starts, all contracts deploy, the API serves on 3001, `/contracts` returns the address map, `/contracts/Phlimbo` resolves, `/health` returns success, `progress.31337.json` records 72 contracts, and the sequence follows `IntegrationChecklist.md`.

**Nothing in this report says the entry point is broken.** It is not. What follows concerns what `dev` *certifies* — because its own source says it is the local mirror of the mainnet cutover — and what it *silently diverged from* in an untagged nine-commit delta. Zero High findings is the honest outcome.

---

## 1. Does it do what it intends?

**Yes, on a clean machine — and its intent is larger than "boot the dev stack".**

`dev` is the **local rehearsal of the mainnet PhlimboV2→V3 cutover**, the dispatcher swap, and the terminal residual-privilege revoke — established by what it asserts (the Phase 7.4, Phase 7.6 and terminal-sweep post-conditions listed above) rather than by a comment. The intent to mirror mainnet is also stated in-source, though scoped more narrowly than the rehearsal as a whole: the NatSpec at `DeployMocks.s.sol:92-96` governs the `IPhlimboAPYLike` shim.

```solidity
/**
 * @notice Story 079. The shared admin surface of `PhlimboV2` and `PhlimboV3`, which are
 *         unrelated Solidity types. Byte-identical to the shim in
 *         `DeployMainnetPromotionReady.s.sol` so the local `_setDesiredAPYTwoStep` and the
 *         mainnet one are the same code operating through the same interface.
 */
interface IPhlimboAPYLike {
``` It rehearses those faithfully: Phase 7.4, Phase 7.6 at dispatcher index 1 (story 079 / ledger `L-01`'s fix landed), and `_sweepResidualPrivileges` as the last statement before `stopBroadcast` (story 079 / `L-04`'s fix landed).

Two intent gaps, both established rather than asserted:

**(a) The rehearsal is pinned to the leg its own author says must not be read as a prediction.** Story 076 specifies mainnet ships with the Kendu promotion **dormant** — "No `startPromotion` call anywhere". The delta added `LOCAL_PROMO_KENDU=true` to the `dev` key. Because `vm.envOr("LOCAL_PROMO_KENDU", true)` at `DeployMocks.s.sol:398` already defaults to `true`, the assignment changes nothing today — but a command-prefix assignment overrides the inherited environment, so the **dormant leg is unreachable through `dev` without editing `package.json`**. The script itself warns, at `DeployMocks.s.sol:1984`:

```solidity
///      Do not read the armed leg's behaviour as a prediction of mainnet's.
```

The day-one mainnet shape (`promoToken() == address(0)`, `promoRewardBalance() == 0`, phUSD/Kendu streams whitelisted-but-unregistered) is therefore never exercised by the entry point anyone runs. Filed as **F-01**; the dormant-leg post-conditions are recorded as `passed: null` — not tested — rather than assumed.

**(b) There is no terminating success signal.** `npm run serve` (`node server/index.js`) blocks forever, so `dev` has no exit-0 condition and none of its ~40 in-script assertions can be gated in CI. Success is judged by a human reading console output. Filed as **L-05** — and it is the mechanism by which the rest of this delta's defects survived nine commits undetected.

---

## 2. Does it introduce unintended side effects?

### 2.1 The `&` shell-precedence split (mechanism)

```json
"dev": "npm run clean:local && npm run start:anvil & sleep 3 && LOCAL_PROMO_KENDU=true npm run deploy:local && ./simulate-yield.sh && npm run extract:addresses && npm run generate:ts-anvil && npm run serve"
```

`&` binds **looser** than `&&`. The shell therefore parses this as **two pipelines, not one**:

- **Pipeline A (backgrounded):** `npm run clean:local && npm run start:anvil`. Its exit status is discarded — `npm run dev` reports success or failure for pipeline B alone.
- **Pipeline B (foreground):** `sleep 3 && … deploy:local && … && npm run serve`, gated on nothing but a fixed 3-second sleep. No port probe, no `cast block-number` poll, no check that the node answering on 8545 is the one pipeline A started.

Two consequences follow mechanically.

First, **`clean:local` runs concurrently with pipeline B, not before it**. In practice `rm` beats a 3-second sleep, but nothing enforces the ordering.

Second, `deploy:local` is itself defined as `npm run clean:local && forge script …` — so the wipe **runs a second time, while anvil is already live**. That second wipe:

- deletes `broadcast/*/31337`, the directory the immediately following `forge script … --broadcast` is about to write; and
- runs `rm -rf ~/.foundry/anvil/tmp/*`, reaching **outside the repository** to delete anvil scratch state belonging to the running node and to any other project on the machine.

`clean:local` also removes **git-tracked** files (`server/deployments/progress.31337.json`, `server/deployments/local.json`), guaranteeing working-tree dirt on every run. Filed as **L-06**.

### 2.2 The stale-anvil reproduction — the dangerous one (M-01, `pps28m1`)

This was reproduced, not argued. With an anvil already listening on 8545 (`anvil --port 8545 --chain-id 31337 --block-time 2`, pid 57286, block 11, deployer nonce 1), `npm run dev` produced:

```
pipeline A: Error: Address already in use (os error 98)      <- exit status DISCARDED (backgrounded)
pipeline B: [PIPELINE_B] proceeded, dollar-question=0
port 8545 still held by the ORIGINAL anvil (pid 57286)
```

`deploy:local` then simulated cleanly — including `end-state phUSD ACL asserted` and the full Phase 7.6 dispatcher-swap rehearsal — and **broadcast 265 transactions onto that non-genesis chain**, driving the deployer nonce `1 → 267`. Every DeployMocks post-condition passed. `progress.31337.json` was rewritten as if the chain were fresh. The run is byte-indistinguishable from a good one at the artefact level.

**This reproduction was itself cut short — disclosed.** The run was terminated mid-broadcast by the audit harness's own 590 s tool limit (`EXIT=124`) — a tool limit, not a script failure. The decisive evidence (265 receipts, nonce 1 → 267, all post-conditions green in forge's **local/simulation** pass) was captured before termination. Those post-condition results are therefore facts about forge's local pass, which precedes dispatch, not about a completed broadcast — the `ForgeLocalPassPrecedesBroadcast` distinction this project established in run-23, and precisely the confusion run-28 `L-02` is about. The finding does not depend on the broadcast completing: the defect is that the run was admitted onto the stale chain at all. The truncation independently established that `dev`'s deploy leg needs more than ten minutes under `--slow` at `--block-time 2`.

**The obvious guard does not close this.** Ledger entry `L-02 ce524709d965` (open) proposes `require(block.chainid == 31337)`. `cast chain-id --rpc-url http://localhost:8545` on the stale chain returned **31337**: the guard passes and catches nothing. The missing assertion is **genesis freshness** — `require(vm.getNonce(deployer) == 0)` — a distinct root cause with a disjoint remedy. M-01 is **pinned apart from ledger `L-02 ce524709d965`** for exactly that reason, on evidence rather than judgement, and the L-02 remediation should be annotated to say so.

**The precondition is manufactured by the normal exit path.** `serve` blocks forever, so Ctrl-C is the only way out; it kills the foreground pipeline and leaves pipeline A's anvil alive. Confirmed at teardown of the clean run: after `serve` was killed, `npm run dev` **returned exit 0** while its anvil was still listening on 8545 answering `eth_chainId` → `0x7a69`, and had to be killed by PID. Every ordinary `dev` session ends by arming the next one.

### 2.3 The wagmi silent drop (M-02, `pps28m2`)

> **OWNER TRIAGE 2026-09-08 — reclassified Low, status `wont-fix` (out of scope).** Verbatim: "pps28m2 is not medium as no funds are at risk. It's just a UI inconvenience that will be picked up at development time. It's also out of scope for this audit which was about a script." The audited entry point was the `dev` npm script; `wagmi.config.ts` artifact resolution and the `npm publish` packaging chain sit outside that closure. The technical description below stands as recorded — only its severity and disposal changed.

`wagmi.config.ts:75` requests:

```ts
'StableStaker.sol/StableStaker.json'
```

Story 080's retype landed `import {StableStakerV1} from "stable-staker/versions/v1/StableStakerV1.sol";` at `DeployMocks.s.sol:84`, and `lib/stable-staker/src/StableStaker.sol` no longer exists — so a clean build emits `out/StableStakerV1.sol/StableStakerV1.json` and **never** `out/StableStaker.sol/StableStaker.json`.

Locally this was masked by a **3-month-stale artifact**: `out/StableStaker.sol/StableStaker.json`, mtime `2026-06-12`, against fresh artifacts at `2026-09-07 11:14:53`, its metadata still recording the deleted source path. Removing it and running the generator for real:

```
$ npx wagmi generate
✔ Resolving contracts        <- all green, exit 0, no warning of any kind
$ git diff --stat hooks/generated.ts
 hooks/generated.ts | 710 ------------------------------------------
$ grep -c stableStakerAbi hooks/generated.ts
0
```

The entire `stableStakerAbi` export vanished with no error at generate time, no error at build time, and nothing a CI gate would catch. The amplifier is `update:hooks`, which chains generate → version patch → **`npm publish`**: a clean-checkout CI machine, which by construction has no stale `out/`, publishes a hooks package missing the export and reports success.

The masking deserves its own sentence, because it is why the drift went unnoticed for three months: the stale artifact's emitted ABI happened to be **signature-identical to StableStakerV1 — 63 entries vs 63, zero differences**. The local output was correct *by coincidence*, not by construction.

### 2.4 The progress artifact is a record of the dry run (L-02, `pps28l2`)

`run()` calls `_writeProgressFile()` at `DeployMocks.s.sol:1564`, *after* `vm.stopBroadcast()` at `:1560`. `_writeProgressFile` uses `vm.writeJson` — a cheatcode, not a transaction — so it executes during forge's **local simulation pass**, before a single transaction is dispatched, and is never re-run afterwards.

Mtimes from the clean run prove it: `progress.31337.json` at **11:28**; `ONCHAIN EXECUTION COMPLETE & SUCCESSFUL` and `broadcast/DeployMocks.s.sol/31337/run-latest.json` at **11:43**. The artifact asserting `"deploymentStatus": "completed"` for 72 contracts predates the 394 transactions that deploy them by roughly fifteen minutes. An earlier run whose broadcast was cut off partway still left a `completed` progress file behind.

This is **distinct from ledger `L-01 1e8cc0dc58ba`** (open), which records that the status string is hard-coded to `"completed"`. That is about the **value** written; this is about **when** it is written. Fixing the hard-coded string alone would not help — at write time the broadcast genuinely has not started and no honest status exists. The two are pinned apart on that basis: **value vs timing**.

The consumer side compounds it (**L-04**). With no chain running anywhere and `local.json` absent:

```
GET /health   -> 200 {"status":"ok", ..., "extractedAddressesLoaded": false}
GET /contracts -> 404
banner        -> Deployment Status: completed / Contracts Deployed: 72
```

`/health` (`server/index.js:88-100`) makes no RPC call at all, so `ok` is a statement about the Node process being alive. Story 003's `/health` criterion is satisfied **vacuously**.

---

## 3. Have other problems surfaced because of it?

### 3.1 The 246-key purge and 81 stranded ledger findings (M-03, `pps28m3`)

> **OWNER TRIAGE 2026-09-08 — OUT OF SCOPE for this `dev` audit; ledger status `wont-fix`, severity Medium left intact.**
> `dev` is `package.json:16` and runs only against chain 31337; this finding is anchored at `package.json:45-46`,
> the `promotion-ready:*` mainnet cutover block. The two share a file, not a call chain — `package.json` is in the
> `dev` closure because `dev` is defined there. The orphaned-runbook half belongs to the `promotion-ready:*` entry
> point and will mint a different fingerprint when filed there, so this disposal does not suppress it. The stranded-
> ledger half concerns the audit repo's own `ledger.json` rather than the audited code.

The delta deleted **246 `package.json` script keys** (287 → 41) and swept 108 files into `script/archives/**`, which `foundry.toml:32` excludes:

```toml
skip = ["script/archives/**"]
```

Of the promotion-ready cutover suite, **only `:snapshot` survives** (`package.json:45`), while four doc comments still instruct operators to run the deleted keys — most explicitly at `package.json:46`:

```
//order-of-execution:human-readable: promotion-ready:snapshot then promotion-ready:dry
then promotion-ready:broadcast. ... If the cutover fails, consult Claude on how to resume.
```

The archived scripts cannot be reinstated by path, because `skip` makes them uncompilable:

```
$ forge script script/archives/VerifyPromotionReady.s.sol:VerifyPromotionReady --rpc-url $RPC_MAINNET
Error: Could not find target contract
EXIT=1
```

Two facts stop this being mere tidying. First, `promotion-ready:verify` was created by **story 075** specifically to remediate fix-pending Medium `2c53e944caee` ("a broadcast run performs ZERO on-chain verification of its own outcome"); deleting it removes a remediation a human accepted, and **no story authorises the purge** — 075 *adds* `:verify` and nothing anywhere removes it. Second, **the cutover is already live on mainnet**: commit `4e5cca1` landed live addresses and `broadcast/DeployMainnetPromotionReady.s.sol/1/run-latest.json` is tracked. `:verify` and `:resume` are the post-hoc verification and recovery path for a migration that has already executed.

The stranding was quantified twice, independently: **81 live (open or fix-pending) ledger findings** had their `entryPoint` key deleted by this delta — largest cluster **`promotion-ready:broadcast` at 25** (23 open + 2 fix-pending), plus 3 on `:verify`, 4 on `:resume`, 1 on `:dry`, and the whole ys-swap and migration-saga families. A second pass over the same ledger reached **287 → 41 keys and 90 live findings with no surviving key, of which 9 already had no key at the diff base** — leaving the same 81 attributable to this delta. Their code survives under `script/archives/` but is uncompilable, so neither PoC replay nor `/recheck` has any path to re-prove or retire them.

`abandoned` is explicitly the **wrong** disposal here: the code is merged on master and nobody chose to live with these findings. Marking them abandoned would bury live bugs.

The same sweep also killed the local StableStaker verification harness (**L-03**): `verify-stable-staker.sh:56,67` invokes two scripts now under `script/archives/interactions/` (`No such file or directory (os error 2)`, EXIT=1). `dev` deploys and wires StableStaker across three pools — DOLA, USDC, USDe, rates set, 10% set-aside buffer, all observed live — and nothing exercises it afterwards. The `foundry.toml` comment justifying the exclusion claims nothing outside the directory references the archives; that sentence is falsified by the very script that references them, and it is the sentence the next sweep will be reasoned from.

### 3.2 OpenZeppelin canonicalization (L-01, `pps28l1`)

The delta canonicalizes every nested OpenZeppelin path onto one top-level **v5.6.1** checkout, overriding **six submodules that pin their own versions (5.1.0–5.5.0)**. HEAD builds clean under the substitution (`forge build` → exit 0). Roughly 96 reachable-file comparisons were made across the drifting submodules:

- `Ownable.sol` — **byte-identical in all six**.
- `SafeERC20.sol` — rewritten in 5.5.0 but behaviour-preserving; the `SafeERC20FailedOperation(address)` error selector is **unchanged**.
- `ERC4626.sol` — implementation not reachable; only `interfaces/IERC4626.sol` is imported.
- `EnumerableSet.sol` — core byte-identical; 5.x additions purely additive.

**One genuine divergence.** OZ 5.5.0 moved `ReentrancyGuard`'s `uint256 private _status` out of slot 1 into an ERC-7201 namespaced slot (`REENTRANCY_GUARD_STORAGE`). Four in-scope contracts inherit it while pinning pre-5.5.0 OZ: `StableYieldAccumulator` (pins 5.1.0; **live on mainnet at `0x0cD353bfda674D04823B2826ffafB83B560D21B6`**) and the three `AYieldStrategy` descendants `YieldStrategyDola`, `YieldStrategyUSDe`, `YieldStrategyUSDC` (vault pins 5.4.0). Under the top-level pin, every slot after the old slot 1 shifts by one **in the bytecode this repository builds and tests**.

**Rated Low, deliberately not inflated.** Nothing is upgradeable, no proxy is involved, and no first-party code reads a raw storage slot on those four contracts — checked for `sload`, `vm.load` and assembly slot access, result negative. Guard semantics are identical. What this is, precisely, is a **reproducibility gap**: the bytecode `dev` deploys and the suite tests is not the bytecode deployed to mainnet from the pinned sources.

**Reopen trigger, stated honestly:** this becomes more than build hygiene the moment anything *does* depend on layout — an upgrade path, a raw storage read, a `vm.load`-based test, or a forked-state comparison against the live `StableYieldAccumulator`. Any of those arriving should reopen L-01 at a higher severity. The recommended snapshot test exists precisely so that transition fails loudly.

### 3.3 Nothing to grade any of it against (F-03, `pps28f3`)

All nine delta commits are untagged. The full story tree was enumerated — `find ~/code/product-owner/stories/phStaging2 -type f -name '*.md'` → **81 files** across every state and sprint folder, highest number 080 — so this is an **established absence of acceptance criteria**, not an unavailability of external documents. Three cross-cutting changes have **no story anywhere**: the OZ pin (`5.6.1` appears nowhere in the tree), the 108-file archives sweep, and the 246-key purge. Story 080, the only story naming `f929b5b` as its base, sits on the unmerged branch `sprint/stable-staker-v2` — master carries the code without the story governing it. Two further changes **contradict story 079's own text**, which says verbatim *"Do NOT gate the Kendu nudge stream"* and *"Confirm no … `package.json` key was modified"*. This compounds standing ledger entry `Q-01 1c98937375ad` (open).

Each concrete defect above is filed on its own evidence; F-03 is the systemic root that explains why none of them were caught.

---

## Findings register

| Label | Sev | What | Mitigation | Where |
|---|---|---|---|---|
| **M-01** `pps28m1` | Medium | `&` splits `dev` into two concurrent pipelines; pipeline A's failure is discarded and pipeline B broadcasts a full 394-tx rehearsal onto a pre-existing chain with every assertion green. Reproduced: 265 tx, nonce 1→267. Pinned apart from ledger `L-02 ce524709d965` — the stale chain is also 31337, so a chain-id guard catches nothing. | Add `require(vm.getNonce(deployer) == 0, "chain is not fresh")` beside the chain-id gate before `vm.startBroadcast`; move `dev` into a `./dev-local.sh` (the fix is multi-line, so it cannot stay a JSON one-liner) that refuses to start when 8545 already answers, starts anvil directly so `$!` is anvil's own PID, replaces `sleep 3` with a `cast block-number` readiness loop, verifies the responder is that PID, and traps `EXIT INT TERM` to kill anvil; annotate the L-02 remediation that the chain-id guard alone does not close this. | `package.json:16` |
| **M-02** `pps28m2` | ~~Medium~~ **Low — `wont-fix`, out of scope** (owner triage 2026-09-08) | `wagmi generate` resolves `StableStaker.sol/StableStaker.json` — a path that no longer exists after the StableStakerV1 retype — leniently, exits 0 with all checkmarks green, and drops the entire `stableStakerAbi` export (710 lines, 0 occurrences left). `update:hooks` chains straight into `npm publish`. | Repoint the artifact to `StableStakerV1.sol/StableStakerV1.json` (export `stableStakerV1Abi`, or alias to keep the consumer-facing name); add a post-generate assertion to `update:hooks` that fails if any expected export name is absent from `hooks/generated.ts`, so a missing artifact can never reach `npm publish`; run `forge clean` before `wagmi generate` in CI so local and CI agree. | `wagmi.config.ts:75` |
| **M-03** `pps28m3` | Medium — **`wont-fix`, OUT OF SCOPE** (owner triage 2026-09-08; severity not downgraded) | The promotion-ready suite was cut to `:snapshot` alone while four doc comments still instruct operators to run the deleted keys; the archived scripts are uncompilable under `skip`; `:verify` was the accepted remediation for fix-pending Medium `2c53e944caee` on a cutover **already broadcast to mainnet**; 81 live ledger findings lost their entry point. | Restore `promotion-ready:verify` and `:resume` as compilable keys and scripts. For the rest, decide deliberately: keep the key and its script compiling, or delete key *and* orphaned doc comment together and retire the corresponding ledger findings explicitly via `/ledger`. If `script/archives/**` must stay in `skip`, add a CI check that every path referenced by a surviving `package.json` key or shell script resolves to a compilable target. | `package.json:45-46` |
| **L-01** `pps28l1` | Low | Top-level OZ v5.6.1 overrides six submodules pinning 5.1.0–5.5.0. One real divergence: 5.5.0 moved `ReentrancyGuard._status` to an ERC-7201 slot, shifting every later slot for four contracts, one live on mainnet. Tested bytecode ≠ deployed bytecode. | Pin top-level OZ at or below the lowest submodule pin (5.1.0), or bump the submodules to genuinely target 5.6.1 and redeploy the mainnet contracts from that build. Either way add a `forge inspect <contract> storage-layout` snapshot test for `StableYieldAccumulator` and the three strategies so a future bump fails loudly. File the story — this is a cross-cutting dependency change with no acceptance criteria. | `foundry.toml:35-95` |
| **L-02** `pps28l2` | Low | `_writeProgressFile` runs in the **simulation** pass (mtime 11:28) — ~15 min before the broadcast it certifies completes (11:43) — and is never refreshed, so a failed, interrupted or wrong-chain run still leaves `"completed"` with all 72 contracts. Pinned apart from ledger `L-01 1e8cc0dc58ba` (value vs timing). | Move the progress write out of the forge script into a post-broadcast step reading `broadcast/DeployMocks.s.sol/31337/run-latest.json` and deriving status from the actual receipts — minimally, a `node server/build-progress.js 31337` step in `deploy:local` after the forge call. Meanwhile have `_writeProgressFile` stamp `"deploymentStatus": "simulated"` so an unconverted artifact is self-identifying. | `script/DeployMocks.s.sol:1564` |
| **L-03** `pps28l3` | Low | `verify-stable-staker.sh` invokes two scripts swept into `script/archives/interactions/` (`os error 2`, EXIT=1), so the stake→warp→claim/withdraw harness proving the StableStaker wiring `dev` just deployed cannot run at all — and the `foundry.toml` comment justifying the exclusion is falsified by that reference. | Repoint both invocations at `script/archives/interactions/...` and narrow the `skip` glob so those two files still compile (explicit list, or `git mv` them back out as story 080 did for its own two). Correct the `foundry.toml` comment — it is not true that nothing outside the directory references the archives, and the next sweep will reason from that sentence. | `verify-stable-staker.sh:56,67` |
| **L-04** `pps28l4` | Low | `/health` returns 200 `"status":"ok"` with **no chain running anywhere**, and the startup banner asserts `completed / 72 contracts` from a committed progress file, while `/contracts` 404s. Story 003's `/health` criterion is satisfied vacuously. | Make `/health` probe liveness: attempt `eth_chainId`/`eth_blockNumber` against `http://localhost:8545` plus a code-size check on one address from `local.json`, and return non-200 (or `status:"degraded"` with explicit `chainReachable:false`/`addressesLoaded:false`) when either fails. Derive the banner from live chain reads, or label it "last recorded run". | `server/index.js:88-100` |
| **L-05** `pps28l5` | Low | `serve` blocks forever, so `dev` can never exit 0; its ~40 assertions cannot be gated in CI and only protect whoever runs it by hand and reads the output. Ctrl-C leaves the background anvil alive, arming M-01. | Split the chain: a `dev:ci` (or `bootstrap:local`) key running everything through `generate:ts-anvil` and exiting 0 — that is the part with assertions and the part CI needs — leaving `dev` as `npm run dev:ci && npm run serve` for interactive use. Add `trap 'kill $ANVIL_PID' EXIT` (or `concurrently --kill-others`) so terminating the foreground tears down anvil. Wire `dev:ci` into CI. | `package.json:16` |
| **L-06** `pps28l6` | Low | `clean:local` deletes git-**tracked** files and `rm -rf ~/.foundry/anvil/tmp/*` outside the repo; `deploy:local` re-runs it a second time while anvil is live, wiping scratch state from under the running node and deleting `broadcast/*/31337` that the next forge command writes. | Untrack the generated artefacts (`git rm --cached server/deployments/progress.31337.json server/deployments/local.json`, add both to `.gitignore`) so `clean:local` only removes build output — or drop them from the `rm` list and let the deploy overwrite them. Narrow the anvil scratch wipe to a project-scoped path. Remove the leading `npm run clean:local` from `deploy:local` so the wipe happens exactly once, before anvil starts. | `package.json:8-9` |
| **L-07** `pps28l7` | Low | `server/deployments/local.json` was de-tracked, so `generate:ts-anvil` and `serve` now fail standalone with no message naming the producing command — two previously independent entry points are hard-coupled to a full deployment. | Prefer not re-tracking generated output; instead make both consumers fail actionably — at `generate-ts-addresses.js:101-104` and `server/index.js:36-40`, name the producer: `local.json not found. Run: npm run extract:addresses (after npm run deploy:local)`. Document the dependency order in the `//local-deploy` comment beside the story-003 reference. | `server/generate-ts-addresses.js:101-104` |
| **F-01** `pps28f1` | Low | `dev` hardcodes `LOCAL_PROMO_KENDU=true`, making the dormant day-one mainnet leg unreachable through the only entry point developers run — partially reverting the story-079 fix for ledger `L-03`. | Delete `LOCAL_PROMO_KENDU=true` from the `dev` key and let `vm.envOr`'s default supply the armed leg (identical behaviour, toggle restored). If an explicit armed default is wanted at the npm layer, add a second key (`dev:dormant` with `LOCAL_PROMO_KENDU=false`) rather than pinning the only one. Add a rehearsal obligation that both legs are booted before a mainnet cutover. Hold ledger `L-03` at fix-pending — do not flip it to fixed. | `package.json:16` |
| **F-02** `pps28f2` | Low | Gating `_seedNudgeStream` on `LOCAL_PROMO_KENDU` silently disables a fee-on-transfer probe whose own comment calls it load-bearing, on exactly the leg that mirrors production — contrary to story 079's verbatim "Do NOT gate the Kendu nudge stream". | Restore the seeding/probe as unconditional per story 079 (registering and seeding the phUSD/Kendu streams costs nothing on the dormant leg beyond two extra streams the UI must render gracefully anyway) — or, if the dormant leg must genuinely leave them unregistered to mirror mainnet, hoist the fee-on-transfer probe out of `_seedNudgeStream` into an unconditional check running on both legs, and amend story 079 (or file a superseding story) rather than silently contradicting it. | `script/DeployMocks.s.sol:2044-2061` |
| **F-03** `pps28f3` | Low | Nine untagged commits; the OZ pin, the 108-file archives sweep and the 246-key purge have **no story anywhere** in the 81-file tree; story 080 sits unmerged on `sprint/stable-staker-v2` while master carries its code. The systemic root of the four defects above. | Write (or retro-write) stories with acceptance criteria for the three untracked changes before further work builds on them — at minimum a stated compatibility target for the OZ pin and an explicit retired-vs-swept list for the package.json purge. Merge `sprint/stable-staker-v2` or revert the story-080 code from master so code and story travel together. Restore `[story-NNN]` tagging; the nine untagged commits are what made this delta ungradeable. | `package.json` (repository-level) |
| **Q-01** `pps28q1` | QA | `_seedNudgeStream`'s NatSpec justifies its assertion with a claim about `collectNudge` that stopped being true when ledger `M-01 a753907e2a4c` was fixed — a self-designated load-bearing comment that now misdescribes the contract. | Rewrite the comment to describe current behaviour: `collectNudge` measures the received delta and caps it at `amount`, so the script-level `require(received == amount)` is now a stricter local check that the **mock** token is not taxed (which would silently change the seeded rate), not a defence against streamer over-credit. Cross-reference the M-01 fix so the two stay in sync. Propose ledger `M-01 a753907e2a4c` FIXED — proposal only; no ledger status was changed by this run. | `script/DeployMocks.s.sol:2069-2080` |
| **Q-02** `pps28q2` | QA | `dev` requires `ANVIL_PRIVATE_KEY` but neither sets it nor documents it anywhere the operator will look — it appears only in the project `CLAUDE.md:476`. First run fails at step 2 with an unhelpful error and an orphaned anvil left behind. | Use `vm.envOr("ANVIL_PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80))` — the standard public anvil account-0 key, safe to default because the script is 31337-only, and it removes the failure entirely. If explicit opt-in is preferred, set it in the `dev` key, add a `.env.example`, and add a `require` whose message names the variable. | `script/DeployMocks.s.sol:387` |

**Total as filed: 3 Medium, 7 Low, 3 Faithfulness (Low), 2 QA. Zero High.** **After owner triage on 2026-09-08 the standing count is 1 Medium, 8 Low, 3 Faithfulness (Low), 2 QA.** M-02 `pps28m2` was reclassified Low and disposed `wont-fix` (out of scope). M-03 `pps28m3` was disposed `wont-fix` as out of scope for a `dev` audit with its Medium severity intact — it is anchored at `package.json:45-46` (`promotion-ready:*`, mainnet), not on any path `dev` executes, and belongs to the `promotion-ready:*` entry point. Every record carries a non-empty `recommendation`; none had to be reconstructed.

---

## Ledger proposals (proposals only — no status was flipped by this run)

| Ledger entry | Current | Proposal | Basis |
|---|---|---|---|
| `M-01 a753907e2a4c` (`dev`) | fix-pending | **FIXED** | `NudgeStreamer.collectNudge` — the version phStaging actually builds via `remappings.txt:86` — snapshots `heldBefore` after `_settle`, measures `received` across exactly one inbound transfer, caps it (`if (received > amount) received = amount;`), reverts `NudgeStreamer__ZeroReceived` on zero, and credits `s.buffer += received`. Both directions closed. |
| `L-03 12bcca3b617c` (`dev`) | fix-pending | **HOLD at fix-pending** | F-01: the `dev` key's hardcoded `LOCAL_PROMO_KENDU=true` partially reverts the fix one layer up. Do not flip to fixed. |
| `L-02 ce524709d965` (`dev`) | open | **keep open; annotate** | The chain-id guard it proposes does not close M-01. Distinct root cause, disjoint remedy. |
| `L-01 1e8cc0dc58ba` (`dev`) | open | **keep open; keep separate** | Producer-side hard-coded value; run-28 L-02 is the consumer/timing defect. Resolve together, dedup separately. |
| `2c53e944caee` (`promotion-ready:*`) | fix-pending | **cited, not merged** | Entry point is folded into the fingerprint; cross-entry-point findings never collapse. M-03 reports that its remediation key was deleted. |
| 81 live entries with deleted entry points | open / fix-pending | **human decision required** | Not `abandoned` — the code is merged on master and nobody chose to live with them. Either restore compilable entry points (M-03) or retire them explicitly via `/ledger`. |

**Baseline note:** this run advanced `entryPointBaselines.dev` only. The project `lastAuditedCommit` (`0e190e8`) and `branchBaselines.master` were **not** the diff base and were **not** advanced.

---

## Label collision warning

Run-28 labels are **run-scoped**. On entry point `dev` the ledger already holds run-05 / run-21 / run-26 / run-27 findings under the same label strings with different fingerprints — in particular run-28 `M-01` (`pps28m1`, stale anvil) is **not** ledger `M-01 a753907e2a4c` (collectNudge), and run-28 `L-01`/`L-02`/`L-03`/`Q-01` are each distinct from the identically-labelled ledger entries. Never key an artifact, carryover copy or ledger operation on a label. Key on fingerprint or `issueId`.

---

## Method and limits

- **Mode `local-anvil-real`.** `dev` is a local-only entry point; the correct empirical verification is a real end-to-end run against a fresh anvil, which is what was performed. `RPC_MAINNET` was not required or used by any step.
- **Not verified:** the dormant leg's behaviour (`LOCAL_PROMO_KENDU=false`) — unreachable through `dev` as written, and reported as F-01 rather than worked around by editing the key.
- **Checked and negative:** that the OZ `ReentrancyGuard` slot shift changes any observable first-party behaviour. No proxy, nothing upgradeable, no first-party raw-slot access on the four affected contracts. Filed as a reproducibility gap and deliberately not inflated.
- The stale-anvil reproduction was cut short by the audit harness's own 590 s tool timeout mid-broadcast (EXIT=124). That is a tool limit, not a script failure; the decisive evidence — 265 receipts, nonce 1→267, all assertions green — was already captured.
