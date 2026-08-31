# Differential gap — what a mainnet port of `DeployMocks` must add, change, and refuse

Written for the stated next step: **a differential mainnet deployment script derived from
`DeployMocks.s.sol`.** There is precedent — `package.json`'s `//uniboost-cutover` describes itself
as a "mainnet differential deploy promoting Story 070's DeployMocks" — so this is a repeatable
manoeuvre, and the last one is the best available template.

---

## 0. The two facts that frame everything

**The deploy ladder is anvil → mainnet, by design.** Sepolia was retired by owner decision
(2026-07-29); the absent testnet rung is **intentional and is not a finding or a gap** — it must not
be filed as one here or in any future run. Independently verified as consistent with that decision:
exactly two distinct chain-id literals are compared anywhere in `script/` or `src/` (`1` and
`31337`); no testnet name, chain id, RPC endpoint, or `progress.11155111.json` exists; `foundry.toml`
has no `[rpc_endpoints]` and its `[etherscan]` block names only mainnet. The single apparent
exception, `DispatcherReplaceSkyPoolerAtIndex4.s.sol:140` (`chainid == 1 || chainid == 31337`), is an
anvil **mainnet-fork** path, not a deployment rung.

The consequence is not that a rung is missing, but that the remaining pre-broadcast surfaces carry
the full load: `PREVIEW_MODE=true` against a mainnet fork, plus the script's own pre/post-condition
asserts, **are** the safety net by design. Combined with `mock-fidelity.md`'s conclusion — that the
local rig is a good *wiring* rehearsal and a **null economic rehearsal** — this is precisely why the
assertion gaps matter more than they otherwise would: see **L-06** (only 1 of 7 `setNudgeStreamer`
legs post-asserted) and **L-08** (checklist line 544 ticked with 1 of 4 clauses implemented). Those
should be judged harder, not offset by adding a testnet.

**The whole story-073 surface has zero mainnet counterpart.** Confirmed by exhaustive `new X(`
matrix across every `script/*.s.sol` except DeployMocks:

| Contract | Mainnet coverage | Only in |
|---|---|---|
| `NudgeStreamer` | **NONE** | `DeployMocks.s.sol:1563` |
| `BatchNFTMinterMultiToken` | **NONE** | `DeployMocks.s.sol:1568` |
| `NFTStakerDepletionV2` | **NONE** | `DeployMocks.s.sol:1699` |
| `NFTStakerMigrator` | **NONE** | `DeployMocks.s.sol:1797` (rehearsal only) |
| six-donor `setNudgeStreamer` fan-out | **NONE** | — |

The only other file mentioning any of them is `script/interactions/TestNudgePayout.s.sol`, which is
a local anvil test (loads `progress.31337.json`, uses `evm_increaseTime`). Story 072 exists **only
as forward references inside DeployMocks** (`:62, :1609, :1675, :1680, :1780, :1787`) — no script,
no npm entry, no commit.

**And the live mainnet stack is the one story 073 retires.** `DeployMainnetUniboostCutover.s.sol`
still imports and deploys `NudgeRatchetDelayRelease` (`:12`, `:525`) and three V1
`NFTStakerDepletion` instances (`:17`, `:484`). So mainnet today runs the story-070/071 generation:
DelayRelease at index 7, three V1 stakers, **no streamer at all**.

> **The port is not additive.** It must deploy the new stack *and* swap out the live retired one.
> That is a cutover, not a deployment — and cutovers are where this project's ledger history
> concentrates (YS-01, YS-20, YS-21, YS-25/26, YS-31).

---

## 1. Structural template

Seven `DeployMainnet*.s.sol` exist. `DeployMainnetNFTV2.s.sol` **does not compile** — it is in
`foundry.toml`'s `skip` list (`:25`) because it is hard-wired to V1 yield-claim-nft contracts
removed by story-039. Do not use it.

**Primary template: `DeployMainnetUniboostCutover.s.sol`.** It is the only script with all of:

1. **Double chain guard** — `setUp():176` *and* `run():184`. (B/C/E guard only in `run()`; D only in `setUp()`.)
2. **Constant-sanity `require`s before any broadcast** (`:198-203`) — refuses to run on placeholder config.
3. **`_phase0_preconditions()` invoked at `:210`, before the prank/broadcast branch** (`:217/:218`), so preview and broadcast validate identically.
4. **Resume-aware preconditions** (`:284-287`, rationale `:278-283`): each mutated slot must hold *either* the pre-cutover value *or* the progress-loaded replacement, so re-entry after a partial broadcast is legal. No other script tolerates a partially-applied broadcast.
5. **`_trackConfig`** (`:786`) so setter-only steps checkpoint, not just deployments.
6. **Post-teardown `_verifyFinalState()`** (`:627`, called `:243`).
7. **Phase-named `run()`** (`_phase0…_phase5`) rather than a flat step list.

**Secondary template: `DeployMainnetUniboostBatchMinters.s.sol`**, for three things the cutover lacks:

- **`_isDeployed` additionally requires `a.code.length > 0`** (`:214`, rationale `:212-213`). This is
  the direct fix for progress-file poisoning. The cutover's own `_isDeployed` (`:770`) and those of
  NFTStaking (`:477`), NFTV2 (`:708`), NudgePoolerV2 (`:1007`) and NudgeRatchet (`:766`) all skip the
  code check and would happily treat a never-landed contract as done. **Take this one.**
- A parameterised deploy helper (`:129`, invoked 3× at `:96-98`).
- **Explicit *untouched-state* assertions** (`:167-169`: `Uniboost.recipient()` unchanged before and
  after) — the strongest post-condition form for a differential deploy, and the one most missing
  from DeployMocks.

**Recommended: cutover skeleton + BatchMinters' code-length `_isDeployed`, parameterised helper, and untouched-state asserts.**

Preview mechanism is uniform across all seven and should be copied verbatim:
`isPreview = vm.envOr("PREVIEW_MODE", false)` → `vm.startPrank(OWNER_ADDRESS)` vs argument-less
`vm.startBroadcast()`, with the signer supplied by CLI `--ledger --hd-paths "m/44'/60'/46'/0/0"`.
**No mainnet script reads a private key from env** — `DeployMocks.s.sol:285`'s
`vm.envUint("ANVIL_PRIVATE_KEY")` must not survive the port.

---

## 2. The ordering contract — port it as asserted steps, not comments

### 2.1 Batch-minter / streamer bring-up (mandatory)

Quoted from `DeployMocks.s.sol:1545-1555`:

> "THE CALL ORDER BELOW IS MANDATORY, not stylistic:
>   1. `setTokenMinter` + `setDispatcherIndex` — `setNudgeTokenWhitelist` runs `_resolvePaymentPath()`
>      on every add and reverts `BatchMint__MinterNotConfigured` / `BatchMint__DispatcherNotConfigured`
>      without them.
>   2. whitelist the reward tokens — `NudgeStreamer.registerStream` calls `isNudgeToken(token)` and
>      reverts `NudgeStreamer__NotWhitelisted` otherwise. (That same call is the structural guard that
>      only a MultiToken batch minter can ever be registered with the streamer — a legacy
>      `BatchNFTMinter` has no such view.)
>   3. `registerStream` per token.
>   4. `setNudgeStreamer` on the batch minter and, later, on all six donors."

The same ordering is mandated in the contracts themselves — `NudgeRatchet.sol:39-43` and
`Uniboost.sol:38-41` both carry an identical "Required ops ordering" block.

**What breaks if violated.** Whitelist before config → `BatchMint__MinterNotConfigured`.
`registerStream` before whitelist → `NudgeStreamer__NotWhitelisted`. `setNudgeStreamer` on a donor
*before* its stream exists → **every dispatch on that index reverts** `NudgeStreamer__NotRegistered()`.
Leaving a donor's streamer unset is equally fatal on indices 1/2/3 and 7 (`"Uniboost: nudgeStreamer
unset"`, `"NudgeRatchet: nudgeStreamer unset"`). Both sources note this is an accepted consequence
of the mandatory-streamer decision — which is exactly why the mainnet script must encode it as
asserted steps.

### 2.2 The six-donor fan-out, and the one silent failure

| # | Donor | Call site | Failure mode if unset |
|---|---|---|---|
| 1–3 | UniboostEYE/SCX/FLX | `_finalizeUniboost:1534` | loud revert on every mint |
| 4 | `BalancerPoolerV2` (idx 4) | `:784` | **SILENT** |
| 5 | `NudgeRatchet` (idx 7) | `:844` | loud revert on every dispatch |
| 6 | `StableYieldAccumulator` | `:1127`, asserted `:1129` | loud |

`DeployMocks.s.sol:780-783` states the index-4 case plainly:

> "the index-4 donation branch is streamer-gated. Without this the donation reverts inside
> `_psmDonate` and `_dispatch`'s try/catch swallows it — the mint succeeds but zero USDC ever
> reaches the batch minter (the exact silent breakage this story fixes)."

**Correction from the empirical pass — the swallow is bounded, not a value leak.** The `catch` does
emit `DonationSkipped(remainingUSDS)` (`BalancerPoolerV2.sol:291-293`), and the swept USDS **parks
on the pooler and is re-swept by the next dispatch** (`:287-289`). So a swallowed donation is
observable and recoverable. The residual risk is *operational quietness*, not lost funds — the
operator must watch `DonationSkipped` and the pooler's USDS balance.

**The mainnet script must nonetheless assert the index-4 donation actually lands**, not merely that
the setter returned. It is the one leg whose failure does not announce itself.

> Note: the ledger's `SYA.setNudgeStreamer` post-assert (`:1129`) is the **only** one of the seven
> `setNudgeStreamer` calls with a post-condition. Port a post-assert for all seven.

### 2.3 `SYA.setRewardToken` before the nudge trio — and it arms permanently

`DeployMocks.s.sol:1064-1068`:

> "STORY 073 — ORDERING IS LOAD-BEARING. yield-accumulator:027 added a conditional guard to
> `setRewardToken`: once the nudge path is live (`nudgeSplit != 0 && nudgeStreamer != 0 && nudge != 0`)
> it requires the streamer to already hold a registered stream for the NEW reward token. Calling
> `setRewardToken` FIRST … keeps the guard dormant at deploy time. Do not reorder."

Verified at `StableYieldAccumulator.sol:452-458`.

**Mainnet consequence is worse than local.** The mainnet SYA is *already deployed* with
`rewardToken`, `nudge` and `nudgeSplit` set. The moment a mainnet script calls `setNudgeStreamer`,
**the guard arms permanently**. Any future `setRewardToken` — a USDC contract migration, a
reward-asset change — then reverts unless a stream for the new token was registered on the *current*
`nudge` address first. This corroborates the existing ledger note that the guard is one-directional
with three residual paths. **Document the arming as an irreversible operational consequence in the
script's own NatSpec; do not just execute it.**

### 2.4 The `primeToken == USDS` require — port it verbatim

`DeployMocks.s.sol:1586` is flagged in-source as **"THE SINGLE HIGHEST-RISK LINE IN THIS STORY."**
Mechanism: `BatchNFTMinterMultiToken.setNudgeTokenWhitelist` derives the payment token from the
*pinned dispatcher* and rejects any nudge token equal to it
(`BatchNFTMinterMultiToken.sol:324-336`). So **the whitelist's contents are a function of which
dispatcher index the batch minter is pinned to**:

- Pin to index 4 (BalancerPoolerV2, prime = `IERC4626(sUSDS).asset()` = USDS) → USDC is whitelistable. ✅
- Pin to **any** of indices 1/2/3 (Uniboost, USDC-primed) or 7 (NudgeRatchet, USDC-primed) →
  `setNudgeTokenWhitelist(USDC, true)` **reverts**, and since `registerStream` requires
  `isNudgeToken`, the entire USDC stream — the only stream mainnet plans to have — cannot be
  created. **The whole story-073 wiring becomes unreachable.**

Mainnet fact-check: `DeployMainnetNudgePoolerV2.s.sol:130` pins `SUSDS = 0xa3931d71…fbD` and
constructs the live pooler with it (`:439`), so mainnet index 4 *is* USDS-primed and the DeployMocks
comment's mainnet claim holds. **Verified locally**: `balancerPoolerV2.primeToken()` returned
`0x9fE46736…` (MockUSDS). **Port this require, resolving the live pooler address, before the first
whitelist call.**

Two caveats:
- The rejection is annotated "DEFENCE IN DEPTH, NOT A SAFETY REQUIREMENT"
  (`BatchNFTMinterMultiToken.sol:327-332`) — `batchMint` no longer depends on it. It is an
  *admin-time* obstacle that may be removed upstream, not a runtime invariant.
- **Do not copy `DeployMainnetNudgePoolerV2.s.sol:666-689`**, which asserts "no active dispatcher
  uses USDC as primeToken". That assertion is now **false on mainnet** — Uniboost at 1/2/3 and
  NudgeRatchet at 7 are all USDC-primed.

---

## 3. What must NOT be ported

### 3.1 The 90% budget sizing — the author disclaims it, and it is worse than the disclaimer says

`DeployMocks.s.sol:1783-1789`, verbatim:

> "SIZING IS NOT THE FINDING, AND IS NOT SOLVED HERE. This rehearsal moves a flat 90% of the seeded
> budget — a script-local expedient forced by forge's simulate-then-replay model… It is NOT
> `balance - committedDebt`, it is not exact, and it leaves an arbitrary 10% stranded in V1. Story
> 072 inherits the question of how much a mainnet migration should move as OPEN. **Do not read this
> 90% as a validated answer; the rehearsal proves nothing about sizing.**"

```solidity
uint256 movable = (REHEARSAL_STAKER_BUDGET * 90) / 100;   // :1831 — 90% of a CONSTANT
v1.rescueERC20(IERC20(address(phUSD)), deployer, movable); // :1832
```

**Empirically measured on the live chain, this is not 90%:**

| | value |
|---|---|
| V1 actual phUSD balance at migration | **1015.014** |
| seed constant `REHEARSAL_STAKER_BUDGET` | 1000 |
| extra minted in by `UniboostMintDebtHook` during the 3 seed mints | **15.014** |
| moved to V2 (90% of the *constant*) | 900 |
| **actual fraction moved** | **88.67%** |
| stranded per staker | **115.014** (11.33%) |
| **stranded across all three** | **345.042 phUSD** |

The formula takes 90% of a *hard-coded seed constant*, not of the *actual balance*. The mint-debt
hook's contribution is excluded entirely. **On mainnet, where the hook has been minting phUSD into
the live stakers for months, the constant would be an arbitrary and possibly small fraction of the
real balance — so "90%" could move almost any proportion.** That is a sharper reason not to port it
than the author's own disclaimer.

Also empirically confirmed: **staker #3 ended with `committedDebt == 1` wei** while #1 and #2 ended
at 0 — direct evidence that the accrual-during-broadcast effect the constant works around is real,
not theoretical.

**What to do instead.** The forge simulate-then-replay defect that forced the constant is a
*script-local artefact*: mainnet broadcasts run with `--skip-simulation` (every `*:broadcast` npm
entry). So a mainnet script **can and should** compute `balance - committedDebt` at execution time,
or move the budget in a separate transaction after `initiateMigration` has frozen `committedDebt`.

**What IS portable** (`:1778-1781`):

> "ORDERING IS THE FINDING THE REHEARSAL EXISTS TO PRODUCE: settle and freeze (`initiateMigration`)
> BEFORE moving the budget, so `committedDebt` is final rather than still growing under the
> transfer. Story 072's mainnet Phase 6 must apply that correction."

**Port the ordering. Do not port the number.**

### 3.2 The V1 teardown sequence — destructive on a live chain

Verified post-run state of all three V1 stakers: `paused == true`, `pauser == deployer EOA`,
unregistered from the global Pauser, `migrator` = the NFTStakerMigrator, **`finalizeAndReset` never
called** (grep returns only the comment at `:1812`), residual phUSD retained.

The order is documented and correct *for a dev chain* (`:1764-1769`), and one sentence in it must
survive the port:

> "**The unregister is mandatory, not tidiness: leaving a contract registered whose `pauser` is no
> longer the Pauser would make a later global `Pauser.unpause()` revert for everyone.**"

On mainnet the global Pauser is a live break-glass mechanism (`UnpauseStakerBreakGlass.s.sol`
exists for it). Repointing a live staker's pauser to an EOA **without** unregistering it would brick
global unpause for the entire protocol. This is a Law-1-adjacent operational hazard, not a
three-liner. Gate it, assert it, and pair it with a documented restoration path.

Separately, `finalizeAndReset` is never called, so V1 is left in `Migrating` state indefinitely with
a live `migrator` — an open surface on mainnet.

### 3.3 Everything else that is anvil-only

| # | Item | Sites | Why |
|---|---|---|---|
| 1 | **`phUSD.setMinter(deployer, true)`, never revoked** | `:1648`, `:1731` | No `setMinter(…, false)` exists in the file. **Verified live: `authorizedMinters(deployer) == (true, 1)` after the run.** On mainnet this is a standing unlimited phUSD mint grant to an EOA. If needed, pair with an unconditional revoke in the same broadcast plus a post-condition assert. |
| 2 | **Cheatcode inside the broadcast section** | `vm.roll(block.number + 1)` at `:1053`, between `startBroadcast():292` and `stopBroadcast():1367` | Exists only to satisfy PhlimboEA's two-phase `setDesiredAPY` (`:1049` preview, `:1056` commit). You cannot roll a block on mainnet — split across two transactions/blocks or the commit fails the same-block guard. |
| 3 | **Raw private key** | `vm.envUint("ANVIL_PRIVATE_KEY"):285` → `startBroadcast(key):292` | Mainnet uses argument-less `startBroadcast()` + Ledger. |
| 4 | **Unrestricted mock mints** | `:686` (1M USDC→waUSDC), `:706` (1M USDC→PSM), `:955`, `:1219`, `:1251`, `:1463-1468`, `:1649`, `:1651`, `:1732`, `:1740` | Each becomes impossible or a real treasury spend. |
| 5 | **The whole Uniswap V2 bring-up** | `_deployUniswapAndPools:1450-1486`, incl. `IWETH9Like(weth9).deposit{value: 300 ether}()` at `:1460` | Mainnet uses the canonical router and existing pools, asserted sane by `_assertPoolSane` (`DeployMainnetUniboostCutover.s.sol:303`). |
| 6 | **Fabricated protocol seeding** | Phases 9 / 9.5 / 9.55 / 9.6 (`:1192-1255`) | 5000 DOLA + 5000 USDC through the *real* `PhusdStableMinter.mint`, then 1000 each injected directly into the vaults to fake share-price yield. On mainnet these mint real phUSD against real collateral. |
| 7 | **The index-6 "bugged pooler" mirror** | `:618-632` | Mainnet index 6 is *already* occupied by the real disabled bugged pooler. Deploying another would push NudgeRatchet to index 8, breaking `MintPageView`'s hard-coded 7 and the `require` at `:889`. **Verified locally: `configs(6).disabled == true`, so the local placeholder is inert — the watch-note is cleared.** |
| 8 | **The whole migration rehearsal** | `_rehearseStakerMigration:1682-1714`, `_seedV1Position:1725-1756`, `_runStakerMigration:1790-1846` | See 3.1/3.2. Also `_seedV1Position` installs the deployer as `migrator` (`:1748`) to fake three user stakes via `depositFor` — the comment at `:1719-1723` admits this substitutes for "three separately-signed user `stake()` calls, which a single-key broadcast script cannot produce". On mainnet the positions are real and must be enumerated from chain events. |
| 9 | **`MockERC4626Wrapper` + `MockBalancerVault.swap`** | `:677`, `:686` | Dead scaffolding for a route removed in story-034. Delete, don't port. |

### 3.4 Locally-tuned constants

| Constant | Local | Mainnet | Source |
|---|---|---|---|
| `MOCK_NUDGE_SIZE` | **25** (`:106`) | **40** | `DeployMainnetNudgePoolerV2:174`, `DeployMainnetNudgeRatchet:126`, `MigrateBatchNFTMinter:338` |
| `LOCAL_STREAM_DURATION` | **6 hours** (`:117`) | claimed 7 days — **but see below** | `DeployMocks:113` |
| Registered streams | **3** (USDC/phUSD/Kendu) | **1** (USDC only) | `DeployMocks:1557-1560` |
| phUSD / Kendu nudge seeds | 5,000 / 50,000 (`:123-124`) | **no donor exists** | `DeployMocks:118-120` |
| `REHEARSAL_STAKER_BUDGET` | 1,000 phUSD (`:128`) | n/a | `:125-128` |
| Rehearsal actors | anvil accounts #1/#2/#3 (`:133-135`) | n/a | `:129-135` |

> ⚠️ **The "mainnet 7 days" figure is not codified anywhere.** It exists *only* as a comment at
> `DeployMocks.s.sol:113`. Grepping `7 days|604800` across `src/`, `script/`, `docs/` and
> `CLAUDE.md` finds no mainnet stream duration at all (the one `604800` is PhlimboEA's unrelated
> depletion window). **The 7 days is an unimplemented author intention, not a value to copy.** Your
> new script is the first place it will be written down — treat it as a decision needing explicit
> owner sign-off.

The author's guardrails should be honoured in reverse: `:113-116` "DELIBERATELY 6 hours, NOT
mainnet's 7 days… Do NOT 'fix' this to match mainnet"; `:1557-1560` "Do not read local behaviour as
a prediction of mainnet's."

---

## 4. What the port must ADD (absent from DeployMocks entirely)

1. **`require(block.chainid == 1)` in both `setUp()` and `run()`.** DeployMocks has *no* chain guard
   at all (`:290` only logs it) — see finding **DEV-05**.
2. **A `PREVIEW_MODE` branch.** DeployMocks has none; it is broadcast-only. Given there is no
   Sepolia rung, the fork preview is the only rehearsal.
3. **A checkpoint/resume mechanism that reads its own progress file.** DeployMocks never reads one
   (no `vm.readFile`/`parseJson` anywhere); it is cold-deploy-only, and `clean:local` deletes the
   file first. A 352-transaction mainnet session **will** be interrupted.
4. **A progress file that is not written before broadcast.** DeployMocks hard-codes
   `deploymentStatus: "completed"` (`:1922`) and emits it during forge's local-execution phase —
   **empirically confirmed**: the file was written at 12:14:24 while the broadcast was still in
   flight at 12:17:45 (nonce 160/352). `package.json`'s `//uniboost-cutover:resume` comment records
   this exact shape already poisoning three committed mainnet progress files. Use
   `DeployMainnetUniboostBatchMinters.s.sol:214`'s `code.length > 0` check as the source of truth.
5. **Post-conditions for the story-073 state.** DeployMocks asserts none of the stream state — no
   `duration`, no non-zero buffer, no `pendingStream`. (The author's technical reason is sound and
   documented at `TestNudgePayout.s.sol:157-168`: a forge script's `require`s all execute in the
   simulation pass, where every statement shares one timestamp, so `pendingStream` reads 0 there
   regardless. **The fix is not an in-script assert — it is an out-of-band `cast` verification step
   in the runbook**, exactly as this audit performed.)
6. **A fee-on-transfer probe that is not vacuous.** Port `_seedNudgeStream`'s balance-delta assert
   (`:1654-1664`) — it is described in-source as "load-bearing, not decorative" and it costs nothing
   — but note it only guards *deploy-time* donations. See **DEV-01** for the runtime hole it does
   not close.
7. **Untouched-state assertions**, in the style of `DeployMainnetUniboostBatchMinters.s.sol:167-169`.
   For a cutover this is the single most valuable post-condition class and DeployMocks has none.
8. **An explicit transaction-count budget and Ledger session plan.** The local run was **352
   transactions / 150,993,148 gas** in one script. A monolithic mainnet equivalent is a
   352-signature Ledger session — the `//uniboost-cutover:resume` note records a 67-tx session dying
   at tx 12 on a transient gas error. **Split the port into phased scripts.**

---

## 5. Suggested phase split

Derived from the ordering contract in §2 and the cutover template. Each phase = one script, one
Ledger session, its own progress file, `PREVIEW_MODE` dry-run first.

| Phase | Content | Risk |
|---|---|---|
| **M-1** | Deploy `NudgeStreamer` + `BatchNFTMinterMultiToken`. No wiring. Patch `mainnet-addresses.ts` (replaces the two `0x0` placeholders — see **DEV-06**). | Low — pure CREATE |
| **M-2** | `setTokenMinter` + `setDispatcherIndex(4)`; **assert `primeToken() == USDS` first** (§2.4); `setNudgeTokenWhitelist(USDC)`; `registerStream(batchMinter, USDC, <duration — needs owner sign-off>)`; `setNudgeStreamer` on the sink. | Medium — the §2.4 revert lives here |
| **M-3** | Six-donor `setNudgeStreamer` fan-out, each post-asserted. **SYA last**, and only after confirming the `setRewardToken` arming consequence (§2.3) is accepted. | Medium — arms the SYA guard permanently |
| **M-4** | Index-7 cutover: retire `NudgeRatchetDelayRelease`, install streamer-aware `NudgeRatchet`, **assert index == 7** (`MintPageView` hard-codes it). | High — live dispatcher swap |
| **M-5** | Staker migration V1 → `NFTStakerMigrator` → `NFTStakerDepletionV2`, ×3. Enumerate real stakers from chain events. **Compute the budget as `balance - committedDebt` after `initiateMigration`, never as a fraction of a constant** (§3.1). Handle the pauser repoint/unregister/restore explicitly (§3.2). | **Highest** — never rehearsed anywhere but the anvil rehearsal, whose sizing is disclaimed |
| **M-6** | Verification-only: assert index-4 donation lands (§2.2), `getNudgeTokens()`, stream durations, all seven `nudgeStreamer` reads, V2 staker totals, global Pauser registrations restored. | Read-only |

---

## 6. Address-book hygiene (blocks M-1)

`server/deployments/mainnet-addresses.ts` is annotated `: ContractAddresses`, and that interface is
**regenerated from ANVIL data** by `generate-ts-addresses.js` with every field typed as a plain
required `string`. A purely local mock addition therefore forces a placeholder into the mainnet
address book — which is exactly what story-073 commit `d241e61` did.

Two defects to fix before the port sources anything from that file:

- **`Kendu` (`:64`) and `NudgeStreamer` (`:131`) are `0x0` placeholders, type-indistinguishable from
  real addresses.** See **DEV-06**. Note the empirical correction: all six donor contracts *reject*
  `setNudgeStreamer(address(0))`, so a mis-wire there fails **loudly**. The genuinely silent
  consumer is `BatchNFTMinterMultiToken.setNudgeStreamer`, which has no guard — see **DEV-03**.
- **`mainnet-addresses.ts:136,142,144-145` actively misdescribe reality**: the comments claim
  `NudgeRatchet` / `RatchetNFTStaker` / `RatchetBatchNFTMinter` are "not yet deployed on mainnet…
  Zero placeholders", while the values are **real non-zero mainnet addresses**
  (`0xd4ea91f6…`, `0x299b0071…`, `0x81896f48…`). This misdescribes precisely the placeholder/real
  distinction the port turns on. See **DEV-07**.

Also note `server/deployments/mainnet-essential-addresses.json` documents itself as "the durable
preservation source merged into mainnet-addresses.ts on every chainId-1 codegen run" — but that
codegen path now hard-refuses chainId 1 and a repo-wide grep finds **zero consumers**. The comment
is false.
