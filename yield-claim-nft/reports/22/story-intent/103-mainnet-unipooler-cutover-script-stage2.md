# Mainnet UniPooler cutover script, verify, fork test, patcher and npm keys: STAGE 2

Current Sprint: 34

## ⛔ Execution Gate (BLOCKING)
This story must not execute until the human has cleared BOTH gates:
- `stage1-audit`: yield-claim-nft project audit AND `audit-script dev` both passed.
- `holding-broadcast`: story 099's `incrementAuthVersion()` revoke tx has been broadcast on mainnet (evidence: tx hash).

The human clears it by adding these exact lines, filled in, to THIS file directly under this section (both required):
`GATE CLEARED: stage1-audit — <date> — <evidence, e.g. audit report path or tx hash>`
`GATE CLEARED: holding-broadcast — <date> — <evidence, e.g. audit report path or tx hash>`

GATE CLEARED: holding-broadcast — 2026-10-01 — 0xa8e8f24d15fb5b4b6a68f8b7305c5e5dbdb0381e6ac5ae9f1e456b2e11bc548d

## ⚠️ Required Human Action On Completion

**STAGE 2 GATE.** Run `audit-script` with the cutover npm key(s) `unipooler-cutover:*` as the apex. Its pass clears `stage2-audit` in story 104. Story 104 must not start until it passes. Clear it by adding `GATE CLEARED: stage2-audit — <date> — <audit report path>` to story 104. Do NOT broadcast the cutover yet: that is Stage 4, listed in story 105's human action.

## Story Overview

This story builds the mainnet cutover tooling for NFT index 4, moving from BalancerPoolerV2 to UniPoolerV2:
- a forge script built on `script/helpers/UniPoolerCutoverCore.sol` (story 100);
- a read-only verify script;
- a full fork test, including the recovery-exit path;
- a guarded `mainnet-addresses.ts` patcher;
- npm keys, plus a guard test pinning the keys.

Nothing is broadcast. The human broadcasts in Stage 4.

Repo: `~/code/reflax-mint/phase-2-staging` (product-owner project `phStaging2`). Paths are relative to the sprint worktree `worktrees/phStaging2/Balancexit/` (branch `sprint/Balancexit`).

Source plan: `docs/BalancerWinddownPlan.md` §4 Stage 2 (repo master `3943ae3`).

## Background

### Plan §4 Stage 2 (verbatim, abridged to the action text)

> This is a new `script/DeployMainnetUniPoolerCutover.s.sol`. It carries the usual npm keys:
>
> | npm key | Purpose |
> |---|---|
> | `unipooler-cutover:preview` | Fork simulation |
> | `unipooler-cutover:broadcast` | Ledger broadcast. Not prefixed with the preview |
> | `unipooler-cutover:verify` | Post-broadcast checks |
>
> The script uses a progress file, `progress.unipooler-cutover.1.json`. **A crash mid-broadcast poisons the progress file**, so resume from receipts, not from the progress file.
>
> 11. **Verify:**
>     - `configs(4).dispatcher` is the new pooler.
>     - `hook.dispatcher()` is the new pooler.
>     - The pair's reserves match what was seeded.
>     - The new pooler holds the LP.
>     - A forked test mint dispatches, wraps and accrues debt.
>     - A `pool()` preview with `quotePool` floors succeeds.
>
> **Minimum viable fallback.** If Stages 1–2 slip past 30 October, nothing breaks and nothing is lost. Mints keep accruing sUSDS on `BalancerPoolerV2`. The BPT can still be recovered through `removeLiquidityRecovery`, and step 3 already allows for that.

### Cutover sequence (implemented in `UniPoolerCutoverCore`, story 100; the plan's version is corrected)

0. Preconditions `require`d: authorized-pooler set revoked (story 099); pair absent or reserves (0,0); every config value read live from the old pooler.
1. Deploy UniPoolerV2 (not wired).
2. `BalancerPoolerV2.withdrawBPT(OWNER, fullBalance)`.
3. Exit the OWNER's whole BPT balance: `removeLiquidityProportional` before 30 Oct, `removeLiquidityRecovery` after, selected by parameter (env `RECOVERY_EXIT=true`). `minAmountsOut` is never 0.
4. Router02 `addLiquidity(sUSDS, phUSD, allRecoveredSUSDS, allRecoveredPhUSD, min, min, to = UniPoolerV2, deadline)` from the owner; this creates the pair.
5. `BalancerPoolerMintDebtHook.pull()`, then `require(mintDebt() == 0)`.
6. `hook.setDispatcher(UniPoolerV2)`, THEN `UniPoolerV2.setHook(hook)`.
7. `setMinter(NFTMinterV2)`; copy PSM, maxTout, batchMinter, nudgeStreamer and batchDonationSize live; `setAuthorizedPooler` for the same four poolers. No Pauser registration: dispatchers have no `pauser()`.
8. `NFTMinterV2.replaceDispatcher(4, UniPoolerV2)`, asserting that price/growth are preserved.
9. `rescueERC20(sUSDS, UniPoolerV2, balance)` + USDS dust sweep.
10. `old.setMinter(OWNER)` then `old.pause()`. No Pauser unregister.

### Templates, best first (exploration)

1. `script/archives/DeployMainnetPromotionReady.s.sol` `_phase4a_pooler()` (lines ~1305-1450). This is the most recent index-4 pooler swap:
   - `HOOK_POOLER.pull()` then require `mintDebt()==0`;
   - deploy, then mirror config live from `OLD_POOLER` (`psm()`, `maxTout()`, `batchDonationSize()`), plus `setNudgeStreamer`;
   - `setMinter(NFT_MINTER_V2)`, `setAuthorizedPooler(MULTI_POOLER,true)`;
   - `hook.setDispatcher(new)` then `new.setHook(hook)`;
   - `_moveBPT()` with 6 guard rails, then USDS `rescueERC20`;
   - `replaceDispatcher(4,new)` with price/growth preservation asserted;
   - `_isConfigured("pooler_*")` / `_trackConfig` progress gating.
2. `script/archives/DispatcherReplaceSkyPoolerAtIndex4.s.sol` (story 056): `withdrawBPT(OWNER, bal)`, sUSDS `rescueERC20`, `setMinter` with a slot read-back proving `_minter` was set, `replaceDispatcher(4, …)`, PREVIEW_MODE prank vs broadcast, and a preview-only E2E mint via `deal`.
3. `script/CutoverStableStakerV2Mainnet.s.sol` (2,390 lines) is the current live-script convention: `PREVIEW_MODE` via `_previewModeFromEnv()`; `PROGRESS_FILE = "server/deployments/progress.stable-staker-v2-cutover.1.json"`; `_loadProgressFile()` / `_writeProgress(status)`.
4. `script/archives/DeployMainnetUniboostCutover.s.sol` is the source for UniV2 mainnet constants (Router02 `0x7a250d…`).

Archives do not compile (`skip = ["script/archives/**"]`), so copy patterns only.

**Off-chain quoting.** `scripts/compute-min-bpt-poolerv2.js` shows how an off-chain `cast call` quote feeds an env var (`MIN_BPT_WEI=$(node …)`). This matters because Balancer V3 router queries revert outside a static call.

**Mainnet script pattern:**
- `PREVIEW_MODE=true` means `vm.startPrank(OWNER)` on a fork; otherwise `vm.startBroadcast()` with a Ledger.
- Steps are gated by `_isConfigured`/`_trackConfig`; deployments by `_isDeployed`/`_trackDeployment`.
- The progress file `server/deployments/progress.<name>.1.json` carries `deploymentStatus` (`completed` or another value).
- Poisoned progress files are kept as `*.POISONED.<ts>.bak`; see `progress.uniboost-cutover.1.POISONED*.bak`.

**npm key template** (package.json `stable-staker-v2-cutover:*`):
- `:preview` = `PREVIEW_MODE=true forge script script/X.s.sol:X --rpc-url $RPC_MAINNET --sender 0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6 --slow -vvv`
- `:broadcast` = `node scripts/backup-mainnet-addresses.js && export CUTOVER_GAS_PRICE_WEI=${CUTOVER_GAS_PRICE_WEI:-300000000} && forge script script/X.s.sol:X --rpc-url $RPC_MAINNET --sender 0xCad1… --broadcast --skip-simulation --slow --ledger --hd-paths "m/44'/60'/46'/0/0" --legacy --with-gas-price $CUTOVER_GAS_PRICE_WEI --gas-estimate-multiplier 200 -vvv && node scripts/patch-mainnet-addresses-<x>.js && npm run <x>:verify && npm run <x>:preview`
- `:verify` = `forge script script/VerifyX.s.sol:VerifyX --rpc-url $RPC_MAINNET -vvv` (read-only)
- Each group gets a `"//<Name>"` comment key with the story number and rationale.
- `test/VerifyStableStakerV2CutoverGuards.t.sol` pins key ordering by reading `package.json` (fs_permission exists).

**Patcher conventions** (best template `scripts/patch-mainnet-addresses-stable-staker-v2.js`; also `scripts/patch-mainnet-addresses-dispatcher-replace-sky-pooler.js`):
- CommonJS with `#!/usr/bin/env node`, and a docblock covering the story number, WHAT IT TOUCHES and WHAT IT NEVER DOES.
- Reads `progress.<name>.1.json` and refuses unless `chainId === 1 && deploymentStatus === "completed"`.
- `FIELDS = [{ tsField, progressKey }]`. `fillFlatField` overwrites ONLY zero placeholders: the same address is SAME, any other address is a COLLIDE.
- Rewrites stale comment blocks by regex and inserts an `// Updated <date>: <HEADER_MARKER> (story N)` header.
- Re-checks that the key-set equals the `ContractAddresses` interface (parses `addresses.ts`).
- Exit codes 0-4, then a single `fs.writeFileSync`.

**Fork tests:**
- `vm.envOr("RPC_MAINNET", "")`, skip cleanly if unset, then `vm.createSelectFork(rpc, FORK_BLOCK)`.
- Harness subclasses override `_previewModeFromEnv()` to return true and expose phases.

**BPT moved off the pooler** (from `broadcast/Temp.s.sol/1/run-*.json`): `withdrawBPT` sent 150 to `0xE74EBCBd1b4415c605c1D5EC85aADD0304af1322`, 200 to `0x5f972f06A95C2185d435c0C84D69d563dfad53d2`, 202.30 to the owner `0xCad1…`, and 1,847.77 to `0xde4409B56f9d45124e31D27E10b096BBaa303D07`. Only BPT the owner holds is in scope. "Owner BPT" must be checked on-chain and reported.

### Shared phStaging2 facts

- Owner/sender `0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6`, Ledger hd-path `m/44'/60'/46'/0/0`. Env vars `RPC_MAINNET`, `RPC_SEPOLIA`, `DEPLOYER_SEPOLIA_pk`.
- `foundry.toml`: `via_ir = true`, `optimizer_runs = 10000`, `skip = ["script/archives/**"]`. fs_permissions are read-write on `./server/deployments` and `./script/migration-inputs`, and read on `./script` and `./package.json`.
- Mainnet: BalancerPool `0x642BB6860b4776CC10b26B8f361Fd139E7f0db04`, BalancerVault `0xbA1333333333a1BA1108E8412f11850A5C319bA9`, BalancerRouter `0x5C6fb490BDFD3246EB0bB062c168DeCAF4bD9FDd`, BalancerPooler (V2, index 4) `0x7f6874332c4629429d70D15f685A8230323F11F1`, MultiPooler `0xd1E5774159381915f5579dFd68507E2614f67b51`, BalancerPoolerMintDebtHook `0x4A26ad83306a2F17155799fDD9449f77eb3F8bD7`, NFTMinter `0x39af088408e815844c567037c157b31d48d2e10f`, NFTStaker `0xc8514f821a3d801fa8a8c435840a992a4365a13b`, NudgeStreamer `0xF7e26179D6971985107AF66b078932D6484eBEAA`, BatchNFTMinter `0x068395556b8c43eDf257DC54D109EA5910aE15c7`, Pauser `0x7c5A8EeF1d836450C019FB036453ac6eC97885a3`, SUSDS `0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD`, USDS `0xdC035D45d973E3EC169d2276DDab16f1e407384F`, PhUSD `0xf3B5B661b92B75C71fA5Aba8Fd95D7514A9CD605`, SkyPSM `0xA188EEC8F81263234dA3622A406892F3D630f98c`, UniV2 Router02 `0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D`, UniV2 factory `0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f`.
- Authorized poolers on the live pooler: owner, MultiPooler, `0x186c77B80Bbfd21b01C7D7FA44bA27031322a77F`, `0x630966B668b321Cc6441754f96519a55F72Cd476`.
- `mainnet-addresses.ts` is HAND-MAINTAINED. Never regenerate it. Only patch it via `scripts/patch-mainnet-addresses-*.js`. Its key-set must equal the `ContractAddresses` interface in `server/deployments/addresses.ts`.
- The repo `CLAUDE.md` is stale. Do not rely on it for paths.
- Deadlines: 30 Oct pools paused (proportional exit → `removeLiquidityRecovery`); 30 Nov V3 vault paused (recovery exit still works).

## File Locations

| File | Change |
|---|---|
| `script/DeployMainnetUniPoolerCutover.s.sol` | NEW: mainnet cutover using `UniPoolerCutoverCore` |
| `script/helpers/UniPoolerCutoverCore.sol` | Use it; change only to fix a genuine bug (record it) |
| `script/VerifyUniPoolerCutover.s.sol` | NEW: read-only verify (by analogy with `script/VerifyStableStakerV2Cutover.s.sol`) |
| `test/UniPoolerCutoverMainnet.fork.t.sol` | NEW: full-cutover fork test (by analogy with `test/CutoverStableStakerV2Mainnet.fork.t.sol`) |
| `scripts/quote-balancer-exit-min-amounts.js` (name may vary) | NEW: off-chain `cast call` quote for `minAmountsOut` → env var (pattern: `scripts/compute-min-bpt-poolerv2.js`) |
| `scripts/patch-mainnet-addresses-unipooler-cutover.js` | NEW patcher (template `scripts/patch-mainnet-addresses-stable-staker-v2.js`) |
| `server/deployments/progress.unipooler-cutover.1.json` | Written by the script at runtime; do NOT commit a preview artefact unless the convention says so |
| `package.json` | `"//UniPoolerCutover"`, `unipooler-cutover:preview`, `:broadcast`, `:verify` |
| `test/VerifyUniPoolerCutoverGuards.t.sol` (or extend an existing guard test) | Pin npm key ordering and the presence of the patcher, by analogy with `test/VerifyStableStakerV2CutoverGuards.t.sol` |

## Technical Details

- **Script header** must state: "A crash mid-broadcast poisons the progress file: resume from broadcast receipts, not the progress file, and rename the poisoned file to `progress.unipooler-cutover.1.POISONED.<ts>.bak`."
- **Exit parameters:**
  - `RECOVERY_EXIT` (bool env, default false) selects `removeLiquidityRecovery`.
  - `MIN_SUSDS_OUT_WEI` and `MIN_PHUSD_OUT_WEI` (or similar) are computed off-chain by the quote helper via `cast call`.
  - The script `require`s both to be non-zero. In preview it also checks them against the live proportional share computed from pool balances and the BPT total supply.
- **Progress:** `PROGRESS_FILE = "server/deployments/progress.unipooler-cutover.1.json"`, with `_loadProgressFile()` / `_writeProgress(status)` and step gating via `_isConfigured`/`_trackConfig`. Track `UniPooler` and `PhusdSusdsPair` (the progress keys the patcher reads) and set `deploymentStatus = "completed"` at the end.
- **Preconditions:** the script itself `require`s the revocation on-chain (all four poolers unauthorized on `0x7f68`) and pair absence or (0,0) reserves.
- **Preview-only E2E:** a test mint at index 4 via `deal` that dispatches, wraps and accrues debt, plus a `quotePool`-floored `pool()` preview.
- **Verify script** (read-only):
  - `configs(4).dispatcher == new`;
  - `hook.dispatcher() == new`;
  - pair reserves == seed (from the progress file);
  - the new pooler holds the LP;
  - the old pooler is paused and holds 0 sUSDS and 0 BPT;
  - owner BPT is **reported** (a log line, a warning if non-zero);
  - a `quotePool`-floored `pool()` preview succeeds (simulated via prank in the script context).
- **Fork test:**
  - Case 1 runs the whole cutover via a harness subclass (proportional exit), including one test mint at index 4 that dispatches, wraps and accrues debt, then runs the verify checks.
  - Case 2 runs the recovery-exit path. Mock the Balancer pause on the fork if feasible (e.g. `vm.mockCall` on the vault's pause query, or etching); otherwise record why not as an Autonomous Decision.
  - Before running, the fork test must perform the revocation (as in 099), because at the pinned block the poolers are still authorized.
- **Patcher:**
  - Fills only the zero placeholders `UniPooler` and `PhusdSusdsPair`.
  - Never overwrites `BalancerPooler` (or any other key).
  - Refuses unless `chainId === 1 && deploymentStatus === "completed"`.
  - Re-checks the key-set against `addresses.ts`, uses exit codes 0-4, and does a single write.
  - Add a fixture-based test or a dry run against a copy if practical.
- **npm keys:**
  - `unipooler-cutover:preview` (PREVIEW_MODE fork simulation).
  - `unipooler-cutover:broadcast`: `backup-mainnet-addresses` head, Ledger flags as in the template, then a tail of patcher + `unipooler-cutover:verify` + `unipooler-cutover:preview`. It must NOT be prefixed with the preview.
  - `unipooler-cutover:verify`.
  - `"//UniPoolerCutover"`, citing story 103, `RECOVERY_EXIT` and the quote helper.

## Implementation Notes

- **Gate check first** (see Checklist). It requires BOTH GATE CLEARED lines and predecessors 099 and 102.
- **TDD:** write the fork test and the guard test first.
- Never broadcast. If `RPC_MAINNET` is unavailable, record that, and the fork test and preview must be run by the human.
- **Commits:** every commit is `[story-103] <message>`, staged by explicit path.

## Checklist

- [ ] Gate check: confirm a line beginning `GATE CLEARED: stage1-audit` AND a line beginning `GATE CLEARED: holding-broadcast` exist under the Execution Gate section, and that its predecessor stories (phStaging2:099 and phStaging2:102, i.e. `stories/phStaging2/{complete,auto-complete}/*/099-*.md` and `102-*.md`) are in complete/ or auto-complete/ (NOT merely review/). Also abort unless yield-claim-nft:052 is in complete/ or auto-complete/ (`stories/yield-claim-nft/{complete,auto-complete}/*/052-*.md`) AND the pinned `lib/yield-claim-nft` commit contains `src/migration/UniPoolerCutoverEscrow.sol` (after the bump, `git -C lib/yield-claim-nft ls-tree -r HEAD --name-only | grep src/migration/UniPoolerCutoverEscrow.sol` must print the path, or equivalent). If any of these fails, make NO code changes: append an Autonomous Decision stating which gate or predecessor is missing, report "ABORTED: out-of-order execution — <reason>" in the output, and exit without moving the story.
- [ ] Write `test/UniPoolerCutoverMainnet.fork.t.sol` first: case 1 (proportional exit, full cutover, test mint at index 4 dispatches/wraps/accrues debt, verify checks pass); case 2 (recovery exit, or a recorded reason why it cannot be simulated).
- [ ] Write the guard test pinning `unipooler-cutover:*` key ordering, the `//UniPoolerCutover` comment key, the `backup-mainnet-addresses` head, the patcher tail, and that `:broadcast` does not start with the preview.
- [ ] Create `script/DeployMainnetUniPoolerCutover.s.sol` on `UniPoolerCutoverCore` with the PREVIEW_MODE convention, the progress file `server/deployments/progress.unipooler-cutover.1.json`, the poisoned-file header note, the `RECOVERY_EXIT` env and non-zero `minAmountsOut` env requirement, on-chain revocation and pair preconditions, and a preview-only E2E mint.
- [ ] Create the off-chain `minAmountsOut` quote helper (via `cast call`, following `scripts/compute-min-bpt-poolerv2.js`) that prints env-var assignments with a tolerance argument.
- [ ] Create `script/VerifyUniPoolerCutover.s.sol` (read-only) with all the checks in Technical Details, including the owner BPT report.
- [ ] Create `scripts/patch-mainnet-addresses-unipooler-cutover.js`: fills only the `UniPooler` and `PhusdSusdsPair` zero placeholders, never overwrites `BalancerPooler`, refuses unless chainId 1 and completed, re-checks the key-set, exit codes 0-4, single write; `node scripts/patch-mainnet-addresses-unipooler-cutover.js` with no progress file exits non-zero without writing (show the output).
- [ ] Add npm keys `unipooler-cutover:preview`, `unipooler-cutover:broadcast`, `unipooler-cutover:verify` and `"//UniPoolerCutover"`.
- [ ] `forge build` passes; `forge test` (full suite) passes; `RPC_MAINNET=<rpc> forge test --match-path test/UniPoolerCutoverMainnet.fork.t.sol -vvv` passes.
- [ ] `RPC_MAINNET=<rpc> npm run unipooler-cutover:preview` runs clean against a fork. If the live poolers are not yet revoked on mainnet the preview must fail on the precondition, and you should record which outcome occurred. Paste the key log lines.
- [ ] `git status` shows no stray preview progress file committed (or it follows the established convention; record which).
- [ ] All commits use `[story-103] <message>`, staged by explicit path; the worktree is clean.
- [ ] (yield-claim-nft:052) Fork test invariant: the owner EOA's BPT, sUSDS, phUSD and USDS balances never increase at any step of the cutover.
- [ ] (yield-claim-nft:052) Fork assertion: on a paused pool, `removeLiquidityProportional` reverts and `removeLiquidityRecovery` succeeds (or record why it cannot be simulated).
- [ ] (yield-claim-nft:052) Fork test: exercise the owner's real pre-existing mainnet BPT (202.30 at planning time; read the live balance) being transferred owner -> escrow, and compute `minAmountsOut` over the escrow's COMBINED BPT balance (the old pooler's BPT, ~20,401.8 at planning time, plus the owner's BPT), then assert `exitAndSeed` succeeds with those floors.
- [ ] (yield-claim-nft:052) Bump `lib/yield-claim-nft` to a commit containing 052 (`src/migration/UniPoolerCutoverEscrow.sol`), committed on its own as a separate `[story-103]` commit; `forge build` passes after the bump.
- [ ] (yield-claim-nft:052) Rewire `script/helpers/UniPoolerCutoverCore.sol` to the escrow flow. Step 2 drops the skim entirely: neither `newPooler` nor the escrow exists at step 2, so step 2 only asserts the pair is empty (reserves AND balances (0,0)) or records its state, and any unsynced donation is skimmed to `newPooler` inside `escrow.exitAndSeed`. Deploy the escrow (operator = OWNER) in the same broadcast after step 3 (`_step3DeployPooler`, UniPoolerV2 deployed against the step-1 canonical pair) and before step 4 (`withdrawBPT`), because the escrow constructor reads `newPooler.pair()`. Step 4 becomes `withdrawBPT(escrow, bal)`. Then add an explicit owner -> escrow transfer of the owner's pre-existing BPT (202.30 at planning time; read the live balance). Replace steps 5+6 with `escrow.exitAndSeed(mode, minAmountsOut, deadline)`. The core still checks `minAmountsOut` against the live proportional share (`_checkMinAmountsOut`, today in step 5 on `balanceOf(owner)`), but it must now compute that check after the owner -> escrow transfer and on the escrow's COMBINED BPT balance: the old pooler's ~20,401.8 plus the owner's 202.30 at planning time, both read live. Parked USDS goes via `rescueERC20(usds, escrow, x)` then `escrow.wrapUsds()`.
- [ ] (yield-claim-nft:052) Update the DeployMocks anvil rehearsal (story 101) and `test/UniPoolerCutoverCore.t.sol` (story 100) to the escrow flow, including the invariant that the owner's BPT/sUSDS/phUSD/USDS balances never increase at any step on the local stack.
- [ ] Final step: end your execution summary with a clearly marked block headed "⚠️ HUMAN ACTION REQUIRED" that restates the Required Human Action On Completion section verbatim, so the user is alerted. Do not perform the action yourself and do not mark it as done.

## Concerns

- **Pauser:** no register/unregister. Dispatchers have no `pauser()` (see story 100).
- **Old-pooler pause:** done via `old.setMinter(OWNER)` + `old.pause()` after `replaceDispatcher`, because `setDispatcherActive` is unreachable once `replaceDispatcher` deletes `dispatcherToIndex`.
- **BPT held by third parties** (`0xE74E…1322`, `0x5f97…d2`, `0xde44…3D07`) is out of scope. Only owner-held BPT is exited, and verify reports any residual owner BPT.
- **Recovery-exit simulation** on a fork may not be faithful if the pool is not actually in recovery mode at the pinned block. Record the approach.

## Upstream Change (planned 2026-10-01): yield-claim-nft:051 / phStaging2:108

Same ordering change as story 100: createPair before deploying UniPoolerV2 (constructor canonical-pair check from yield-claim-nft:051); the precondition (line 150) must check pair balances as well as reserves and skim unsynced pre-donations. createPair is permissionless, so a griefer can donate+sync between creation and seeding to break the (0,0) precondition — follow the mitigation phStaging2:108 documents. The runbook should name `incrementAuthVersion()` as UniPoolerV2's pool-only kill switch. Step 9 'USDS dust sweep' becomes an explicit parked-USDS transfer with a zero-balance verify. This story now depends on phStaging2:108.

## Upstream Change (2026-10-07): no funds through any EOA (yield-claim-nft:052)

- **Requirement:** the human requires that no protocol funds (BPT, sUSDS, phUSD, USDS) transit the owner EOA `0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6` or any other EOA during the cutover, so that it is provable on-chain, for tax and accounting, that these funds move contract-to-contract.
- **New dependency:** this story now depends on yield-claim-nft:052 (`UniPoolerCutoverEscrow`) being in complete/ or auto-complete/, audited, and pinned here via a `lib/yield-claim-nft` bump.
- **Core changes** (from 052's Follow-ups):
  - escrow deployment (operator = OWNER, same broadcast): after step 3 (UniPoolerV2 deployed against the step-1 canonical pair) and before step 4 (`withdrawBPT`), because the escrow constructor reads `newPooler.pair()`;
  - step 2: drops the skim entirely. `newPooler` and the escrow do not exist yet at step 2, so step 2 only asserts the pair is empty (reserves AND balances (0,0)) or records its state; the skim to `newPooler` happens inside `escrow.exitAndSeed`;
  - step 4: `withdrawBPT(escrow, bal)`;
  - the owner's pre-existing 202.30 BPT is transferred owner -> escrow explicitly (read the live balance), after step 4;
  - `minAmountsOut` share check (`_checkMinAmountsOut`, today in step 5 on the owner's balance): computed after the owner -> escrow transfer, on the escrow's COMBINED BPT balance (old pooler's ~20,401.8 + owner's 202.30 at planning time; read both live);
  - steps 5+6: replaced by `escrow.exitAndSeed`;
  - parked USDS: `rescueERC20(usds, escrow, x)` + `escrow.wrapUsds()`.
- **Ownership of edits:** these changes touch `script/helpers/UniPoolerCutoverCore.sol` and the DeployMocks rehearsal from the auto-completed stories 100 and 101. This story owns those edits.
- **Checklist:** two items were added to the Checklist above (owner-balance never-increases invariant; paused-pool Proportional-reverts / Recovery-succeeds assertion). A third was added on 2026-10-07 from 052's review: the fork test must exercise the owner's real BPT transfer into the escrow and `minAmountsOut` over the combined balance.
