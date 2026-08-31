# `dev` (DeployMocks) — script audit review

**Project:** `phoenix-phase-2-staging` · **Entry point:** `dev` · **Run:** `phoenix-phase-2-staging-21`
**Audited commit:** `3fb4e34` · **Story scope:** 073 (related: 072) · **Date:** 2026-07-29

**How this was audited.** The `dev` chain was executed end to end — for real, not statically — against a
throwaway anvil (`--chain-id 31337 --block-time 2`) spawned from `workspace/`, followed by
`simulate-yield.sh`, `extract-addresses.js`, `generate-ts-addresses.js` and the `:3001` server. Every
number below is empirical unless explicitly marked *static*. Nothing was broadcast to mainnet; `lib/` was
not modified.

---

## Verdict

**The `dev` chain is in good shape, and story 073 landed.** The run completed cold with **352
transactions, 67 contract creations, 0 failed receipts, ~151.0M gas** (`side-effects.json` →
`executed`). Every in-script pre-condition and post-condition passed. The address pipeline reproduced the
**committed** artifacts from a wiped state: `progress.31337.json` is **md5-identical**
(`f4bb1d9f42d24416dd8a4622ab6b21c7`), and `local.json` / `addresses.ts` / `local-addresses.ts` differ only
in their ISO timestamps. The API served **57 contracts** with health green.

The three headline numbers story 073 reports were **self-reported console output with no on-chain
assertion behind them**, so they were re-derived independently with `cast` after the deploy. **All three
confirmed**: `duration == 21600` (6h) on all three streams, phUSD buffer `5,000e18`, Kendu `50,000e18`,
USDC `44855551` = 44.855551 (the story's "44.86"). `pendingStream` was non-zero on all three.

The mock/real partition is also right: **every Phoenix contract in the graph is the genuine article** from
the submodule pins — 39 real first-party contracts plus 9 canonical third-party ones (WETH9 and the
Uniswap V2 factory/router deployed from real creation bytecode). Only the **external world** is faked (19
mocks).

| Severity | Count |
|---|---|
| High | **0** |
| Medium | **2** (M-01, M-02) |
| Low | **9** (L-01 … L-09) |
| QA | **4** (Q-01 … Q-04) |

**The single highest-value action before you broadcast anything to mainnet.** M-01 and L-09 point at the
same unarmed switch. Mainnet is sanctioned — verbatim, by both stories — to register a stream for **USDC
only**, leaving phUSD and Kendu whitelisted-but-unregistered. That is what keeps M-01 off the live
surface today. But "whitelisted-but-unregistered" is an **arm-switch, not a wall**: one routine-looking
`registerStream(newBatchMinter, KENDU, D)` converts M-01 from a defect proven in test into live custody
loss. **Tick story 072 Preflight line 514 against the real Kendu token
`0xaa95f26e30001251fb905d264aa7b00ee9df6c18` before any mainnet broadcast.** Story 073's fee-on-transfer
probe does not discharge it — it runs against `MockKendu`, which the story itself defines as fee-free.

---

## 1. Is it faithful to story 073?

**Yes, substantially.** The faithfulness pass checked **37 discrete requirements** drawn from the story's
checklist and its in-body mandates; the large majority are **IMPLEMENTED**, and where the code appears to
diverge it is because the story's own Autonomous Decisions sanctioned the divergence.

**The story's own open HIGH issue was closed by `3fb4e34`.** The embedded review
(`Review Status: ISSUES_FOUND`, 2026-07-29T12:00Z) raised as Issue 1 that a Verification checkbox was
ticked with no implementing code behind it — the phUSD/Kendu `collectNudge` seed, now line 540. That is
**genuinely remediated**: `_seedNudgeStream` exists at `DeployMocks.s.sol:1645-1666` with a real
balance-delta assertion (`require(received == amount)` at `:1661`, `require(bufferAfter - bufferBefore ==
amount)` at `:1664`), and the on-chain result confirms it — all three streamer balances **exactly** equal
their credited buffers.

**The flat-90% budget move is faithful, not a deviation.** `_runStakerMigration` moves
`movable = (REHEARSAL_STAKER_BUDGET * 90) / 100` (`DeployMocks.s.sol:1831`) — 90% of a *hard-coded
constant*, not of the live balance, which on the surface contradicts the story's step 7 ("move the
budget"). It does not: the story's **Autonomous Decision #4 mandates exactly this**, with a sound and
independently verifiable reason (a forge script builds calldata in the simulation pass, where every
rehearsal transaction shares one timestamp, so `committedDebt()` reads 0 and the broadcast would replay a
stale number). The code implements AD#4 literally.

And the realised divergence errs **conservative**. Measured on chain:

| | value |
|---|---|
| V1 phUSD balance at migration | **1015.014** |
| seed constant `REHEARSAL_STAKER_BUDGET` | 1000 |
| minted in by `UniboostMintDebtHook` during the 3 seed mints | **15.014** |
| moved to V2 (90% of the constant) | 900 |
| **actual fraction moved** | **88.67%** |
| stranded per staker / across all three | 115.014 / **345.042 phUSD** |

Because the hook's contribution is excluded, the script moves strictly *less* than 90% of the live
balance — it cannot breach `committedDebt`. The residual is an inaccurate in-source comment ("flat 90%",
`:1722-1728` vs `:1772`) and 345.042 phUSD stranded in three **untracked** rehearsal contracts. That is
state handling plus a wrong comment: **Q-01**, QA, deliberately downgraded from Low on the faithfulness
axis. Its do-not-port instruction is **not** downgraded — see §4.

Four items the faithfulness pass initially could not verify resolved as **genuinely spec-mandated**: the
six-donor `setNudgeStreamer` fan-out, the three-token whitelist, the 6-hour stream window, and the
index-7 dispatcher pin. Note the boundary carefully: **the seed magnitudes are executor discretion, not
spec.** Nothing in story 073 fixes phUSD at 5,000e18 or Kendu at 50,000e18; those are the executor's
choice for UI ergonomics, and no mainnet meaning attaches to them.

**Where faithfulness is imperfect — three ticked boxes with nothing behind them.** This is the *same
class* the story's own reviewer caught as HIGH Issue 1, and it recurs:

- **L-08 / F-02** — line 544 is ticked and certifies **four** clauses (`configs(1..5,7)` resolve; index 7
  is a `NudgeRatchet`; all six donors' `nudgeStreamer()` return the streamer; the three `UniboostStaker*`
  keys point at V2 instances holding the migrated totals). In source, **one** clause is asserted:
  `require(ratchetIndex == 7)` at `:889`. The six-donor clause spans seven `setNudgeStreamer` calls, of
  which exactly one — StableYieldAccumulator at `:1129` — is post-asserted. No out-of-band evidence is
  recorded for the rest, unlike AD#8, which moves the stream-accrual check out of band explicitly and for
  a documented reason.
- **L-07 / F-01** — `test:balancer-donation` is ticked (lines 505/539) as the index-4 streamer regression
  test. The script was never modified by story 073, never calls `batchMint`, and asserts against the
  batch minter rather than the streamer. A green run proves nothing about the repair — on the one leg
  whose breakage was **silent**.
- **Q-04 / F-03** — the preflight `grep` sweep at line 491 missed two `batchMint` call sites. See §4.

The one unticked box, line 536 (`forge fmt --check`, `forge build --sizes`, `forge test -vvv` all exit 0),
is consistent with the story's own review, which recorded `forge test` at 18 pass / 1 fail — a
pre-existing `RPC_MAINNET` fork test, unrelated to 073.

---

## 2. Is the mocking behaviour reasonable?

The question is **not** "is it mainnet-faithful" — perfect fidelity is not the bar and you have said so.
The bar is: *does it serve as a good trial run for the key aspects before mainnet?* So each mock is graded
on **what it fails to rehearse**, and whether that gap could let a real bug reach mainnet unseen.

**The answer is yes, with one sharp caveat.** The partition is well chosen: fake the external world
(tokens, ERC4626 yield vaults, the Balancer V3 stack, the Sky PSM, the Curve USDe route), run the real
Phoenix code. **13 of the 19 mocks are adequate** for what they stand in for, and `MockSkyPSM` is
genuinely good — `buyGem` mirrors `DssLitePsm._buyGem` exactly, the pooler's inverse math at
`BalancerPoolerV2.sol:322/:331` round-trips against it, and reserve exhaustion is actually modelled
(`MockSkyPSM.sol:64-67`).

### The pattern that matters: every mock that models *price* is a constant-function stub

The risk is not "less detail". In three places the simplification is **structural impossibility** — the
mainnet failure mode cannot be represented at all, so no amount of local testing can find it.

**`MockMarketAMMAdapter`** (`src/mocks/MockMarketAMMAdapter.sol`, 99 LOC) is the most fidelity-conscious
mock in the set — it routes through the real `MockSUSDe` vault and skims a 10 bps per-leg haircut. But
`ERC4626MarketYieldStrategy` computes every slippage floor *from that same vault*
(`convertToShares` at `:139`, `convertToAssets` at `:167/:224/:275`), and the mock produces its output
from the vault minus a constant — **the reference price and the realized price are the same number by
construction**, so AMM/NAV decoupling is impossible to reproduce. Price impact is also completely
independent of trade size (`:79`, `:88`): the aggregate exit at
`ERC4626MarketYieldStrategy.sol:262-281`, which deliberately collapses N client positions into **one**
swap, is rehearsed at the same 10 bps as a dust trade. Note the deploy script's own comment at
`DeployMocks.s.sol:449-455` records measured exit-leg losses of **5–32 bps** — the observed worst case
already exceeds the 30 bps tolerance it configures.

**`MockAutoDOLA` / `MockAutoUSDC`** (125 LOC, deployed twice — `:390`, `:409`) are plain OZ ERC4626 with
`totalAssets()` = raw balance. No deposit or withdrawal fee, no withdrawal queue, no destination-vault
liquidity, no `maxRedeem`/`maxWithdraw` limiting, and — the load-bearing one — **`previewRedeem` is OZ's
un-overridden, pure, non-reverting view**. That makes the mock **structurally incapable** of reproducing
the Tokemak Autopool behaviour that already bricked this project's YS-swap suite (ledger **YS-01**): real
Autopools mutate state inside `previewRedeem` and revert `StateChangeDuringStaticCall` in a static frame.
Related contract-level observation parked as **MR-DEV-001**, §5.

**`MockBalancerRouter` + `MockBalancerVault`** are the largest omission jointly. The router is **22
lines** and quotes a flat `sum(inputs)` as BPT — dimensionally wrong (it returns a sUSDS amount as a BPT
amount), with no rate provider, weights, swap fee or price impact. The vault mints BPT 1:1
(`MockBalancerVault.sol:96-107`). Consequences: `minBPT` **can never bind** (`getIdealBPT`,
`BalancerPoolerV2.sol:405-419`, and `addLiquidity` return the same number), so the pooler's sole
MEV/slippage protection is un-rehearsed and `scripts/compute-min-bpt-poolerv2.js` is untestable; and
**`settle()` is a no-op that echoes its argument** (`:120-123`), which makes `BalanceNotSettled` —
Balancer V3's defining integration hazard and the commonest way a V3 integration bricks in production —
**structurally unreachable**. Also: `addLiquidity` never verifies the tokens arrived (`:99-102`), the
query is `pure` so it runs in any frame (the real router's query only executes inside an `eth_call`), and
the query can never revert (the old sUSDS→waUSDC route died precisely because the real query reverted
`MaxImbalanceRatioExceeded()`).

### The conclusion, stated plainly

**A green `dev` run proves the graph is wired and the ABIs line up. It is a null economic rehearsal.**

That is a legitimate and useful thing for it to be — it is exactly the trial run that catches wiring,
ordering and interface regressions, and it caught them. But do not read a green run as economic
validation. Every mock that models price is a constant-function stub, so no swap, quote, slippage floor
or redemption is being tested for behaviour, only for shape.

### Bounded gaps worth carrying forward

- **`MockPhUSD` burn semantics are inverted** vs the real `FlaxToken`: the mock's `burn(holder, amount)`
  requires **minter authorization and ignores allowance** (`MockPhUSD.sol:57-61`); the real token
  **spends the `holder → msg.sender` allowance** with no minter check (`FlaxToken.sol:77-83`). The one
  first-party contract that burns phUSD, `PromotionUniV2_Eth.sol:452`, gets it right via an infinite
  self-allowance in its constructor (`:218`) — but that contract is **not deployed by DeployMocks**, so
  its correctness came from reading the real token, not from local testing. The next dispatcher that
  burns phUSD will not get it free, and the local rig will bless it. Also: real phUSD is already deployed
  with a live `mintVersion` and an existing minter set (mock starts at `1`, real at `0`).
- **`MockSUSDe` has no 7-day cooldown**, and this is *safe today only by architecture*:
  `ERC4626MarketYieldStrategy` never calls `vault.deposit`/`vault.redeem` — it reaches sUSDe exclusively
  through `ammAdapter.swap`. If the plain `ERC4626YieldStrategy` (which *does* call `vault.redeem` at
  `:135, :165, :194, :241, :254`) is ever pointed at real sUSDe, every withdrawal bricks and the local
  rig will show it working perfectly. Carry this as a standing constraint.
- **`MockRewardToken` (USDC) has no blocklist and no pause.** USDC is pushed to user-controlled addresses
  in the streamer settle, Uniboost prime-token flows, PhlimboEA payouts and NudgeRatchet. The PSM
  donation path is already insulated behind `try/catch`; those are not.
- **`MockERC4626Wrapper` (waUSDC) and `MockBalancerVault.swap`/`setSwapRate` are dead scaffolding** for a
  route removed in story-034 (`BalancerPoolerV2.sol:23-29`, "structurally dead"). The wrapper is still
  deployed, still pre-funded with **1,000,000 mock USDC** (`DeployMocks.s.sol:686`), and still exported to
  the UI as `WaUSDC`. **Q-02** — delete rather than port.

### Nothing downstream marks a mock as a mock

`server/extract-addresses.js:107` does a blind prefix strip:

```js
const displayName = name.startsWith('Mock') ? name.slice(4) : name;
```

**Empirically confirmed on the live run:** `local.json`, `addresses.ts`, `local-addresses.ts` and the
`:3001` API contain **zero** keys beginning with `Mock`. All 57 served entries read like real contract
names — `MockPhUSD` → `PhUSD`, `MockKendu` → `Kendu`, `MockAutoDOLA` → `AutoDOLA`. The strip hits 17
names; three more mocks bypass it entirely because they are tracked under an already-stripped key
(`MockUSDe` as `"USDe"` `:327`, `MockSUSDe` as `"SUSDe"` `:333`, `MockMarketAMMAdapter` as
`"USDeAMMAdapter"` `:446`) — so the file carries two conventions for one job.

The real defect (**L-05**) is the **missing collision guard**. The strip runs *before* the drop-lists
(`:110`, `:116`, `:122`) and the `V2`→base rename (`:137-141`), and the final write at `:144` is an
unguarded assignment. No collision exists today (verified across all 99 track keys), but a contract
tracked as `MockNFTMinterV2` would become `NFTMinterV2` → hit the V2 rename → silently clobber the real
`NFTMinter`; `MockNFTMigrator` would be silently dropped. Because the mainnet key set is hand-maintained
and must mirror the generated interface exactly, a silent overwrite points the UI at the wrong contract
with no error. **Add a duplicate-key assertion at `:144`.**

---

## 3. Does it work when integrated, and does it prepare the UI for mainnet?

**Yes — this is the strongest result in the audit, and it is the script's stated main purpose.**

**Integration.** The cold run from a wiped state completed with 352/352 successful receipts and zero
reverts. All eight in-script pre-conditions passed, including the one the author flags in-source as **"the
single highest-risk line in this story"** — `require(balancerPoolerV2.primeToken() == usds)` at `:1586`,
observed `0x9fE46736…` (MockUSDS). The full dispatcher table resolves as designed: indices 1/2/3 Uniboost,
4 BalancerPoolerV2, 5 GatherV2, 6 the bugged-pooler placeholder **confirmed `disabled == true` on chain**
(so the standing watch-note on it is cleared), 7 `NudgeRatchet` — which `MintPageView` hard-codes, and
which `require` at `:889` enforces.

All six donors plus the batch-minter sink were read back on chain and **all seven point at the streamer**
(`0xA7c59f01…`). A live `batchMint(26, batcher, 400e18, [0,0,0])` succeeded and emitted `NudgePaid` for
all three tokens.

**UI preparation.** The address pipeline works end to end and is **deterministic**:

`progress.31337.json` (71 entries) → `local.json` (57) → `addresses.ts` + `local-addresses.ts` →
`:3001`, health `{"status":"ok","deploymentsLoaded":true,"extractedAddressesLoaded":true,
"chainId":31337,"network":"anvil"}`, **57 contracts served**, `Kendu` and `NudgeStreamer` both present.

That the regenerated artifacts are byte-identical to the committed ones (modulo timestamps) is a real
quality signal: the pipeline is reproducible and the committed state is honest.

**Rough edges on this path, none blocking:**

- **L-01** — `deploymentStatus: "completed"` is a **hard-coded string literal** (`:1922`) written after
  `vm.stopBroadcast()`, i.e. during forge's local-execution phase, before any transaction is broadcast.
  Confirmed empirically: file mtime 12:14:24 while the broadcast was still in flight at 12:17:45 at nonce
  160/352. Benign on anvil (nothing reads it), **not** benign as a pattern — `package.json`'s
  `//uniboost-cutover:resume` comment records this exact shape already poisoning three committed mainnet
  progress files.
- **Q-03** — `GET /` advertises a stale hand-written list of 18 contracts; `GET /contracts` serves 57.
- Six contracts (three V1 `NFTStakerDepletion`, three `NFTStakerMigrator`) are deployed and left holding
  value/authority but are **never tracked**, so they are invisible to every downstream artifact. The three
  V1 stakers collectively hold **345.042 phUSD**.
- The deployer EOA ends the run holding a **live, never-revoked phUSD minter grant**
  (`authorizedMinters(0xf39F…) == (true, 1)`; granted at `:1648` and `:1731`, revoked nowhere). Harmless
  on anvil; see §4.
- `dev` backgrounds anvil with a single `&` and never kills it (contrast `test:nft-flow`, which ends with
  `kill %1`), and readiness is a fixed `sleep 3` rather than a health probe. A repeat `dev` fails on the
  port-8545 bind. Local ergonomics only.
- `addresses.ts` / `local-addresses.ts` survive `clean:local`. If the chain aborts mid-way, the repo is
  left with committed TypeScript address files pointing at a chain that no longer exists, distinguished
  only by an ISO comment.

---

## 4. The differential mainnet script — what to add, change, and refuse

You did not ask this, but it is the next thing you do, so it is the most consequential section.

### 4.0 The frame

**The entire story-073 surface has zero mainnet counterpart.** Confirmed by an exhaustive `new X(` matrix
across every `script/*.s.sol` other than DeployMocks:

| Contract | Mainnet coverage | Only in |
|---|---|---|
| `NudgeStreamer` | **NONE** | `DeployMocks.s.sol:1563` |
| `BatchNFTMinterMultiToken` | **NONE** | `:1568` |
| `NFTStakerDepletionV2` | **NONE** | `:1699` |
| `NFTStakerMigrator` | **NONE** | `:1797` (rehearsal only) |
| six-donor `setNudgeStreamer` fan-out | **NONE** | — |

And the live mainnet stack is the one story 073 retires: `DeployMainnetUniboostCutover.s.sol` still
imports and deploys `NudgeRatchetDelayRelease` (`:12`, `:525`) and three **V1** `NFTStakerDepletion`
instances (`:17`, `:484`). **So the port is not additive — it is a cutover**, deploying the new stack
*and* swapping out the retired live one. Cutovers are where this project's ledger history concentrates
(YS-01, YS-20, YS-21, YS-25/26, YS-31).

**On the deploy ladder.** The ladder is **anvil → mainnet by design** (owner decision, 2026-07-29). The
fork `PREVIEW_MODE` run and the script's own pre/post-condition asserts **are** the safety net — that is
the design, not a shortfall. The correct consequence is that **the assertion gaps matter more**: with the
economic rehearsal null (§2) and the fork preview plus in-script asserts carrying the load, **L-06** (one
of seven `setNudgeStreamer` legs post-asserted) and **L-08** (line 544 ticked with one of four clauses
implemented) are the load-bearing weaknesses, not a missing rung.

### 4.1 Structural templates

Best available: **`DeployMainnetNudgePoolerV2`** (a full-stack handoff, and the file that establishes
mainnet index 4 is USDS-primed — `SUSDS = 0xa3931d71…fbD` at `:130`, live pooler constructed with it at
`:439`) and **`DeployMainnetNFTStaking`**, whose NatSpec already states it "mirrors Phase 3.7 of
DeployMocks". `DeployMainnetUniboostCutover` remains the best skeleton for phasing, double chain guards
(`setUp():176` *and* `run():184`), resume-aware preconditions (`:284-287`) and a post-teardown
`_verifyFinalState()` (`:627`). Take `DeployMainnetUniboostBatchMinters`'s `_isDeployed`, which
additionally requires `a.code.length > 0` (`:214`) — the direct fix for progress-file poisoning; the other
five scripts' `_isDeployed` would treat a never-landed contract as done. Do **not** use
`DeployMainnetNFTV2.s.sol`: it does not compile and sits in `foundry.toml`'s `skip` list.

### 4.2 MUST NOT PORT

- **The flat-90% `_runStakerMigration` sizing** (`:1831`). The author explicitly marks it unsolved and
  hands the question to story 072: *"Do not read this 90% as a validated answer; the rehearsal proves
  nothing about sizing."* The sharper reason is §1's measurement: the formula takes 90% of a **constant**,
  and on mainnet — where the mint-debt hook has been minting phUSD into live stakers for months — 90% of
  that constant could be almost **any** proportion of the real balance. **Port the ordering** (settle and
  freeze via `initiateMigration` *before* moving the budget, so `committedDebt` is final); compute
  `balance - committedDebt` at execution time, which mainnet can do because every `*:broadcast` npm entry
  uses `--skip-simulation` and the forge simulate-then-replay artefact that forced the constant does not
  apply. (That artefact is real, incidentally: staker #3 ended with `committedDebt == 1` wei while #1 and
  #2 ended at 0.)
- **The V1 teardown sequence verbatim.** All three V1 stakers end `paused`, unregistered from the global
  Pauser, with `pauser` repointed to the deployer EOA, and `finalizeAndReset` **never called**. The
  in-source note must survive the port: *"the unregister is mandatory, not tidiness: leaving a contract
  registered whose `pauser` is no longer the Pauser would make a later global `Pauser.unpause()` revert
  for everyone."* On mainnet the global Pauser is a live break-glass mechanism.
- **`phUSD.setMinter(deployer, true)` with no revoke** (`:1648`, `:1731`) — on mainnet a standing
  unlimited mint grant to an EOA.
- **`vm.roll(block.number + 1)` inside the broadcast section** (`:1053`, between `startBroadcast():292` and
  `stopBroadcast():1367`) — you cannot roll a block on mainnet; split PhlimboEA's two-phase
  `setDesiredAPY` across two transactions.
- **`vm.envUint("ANVIL_PRIVATE_KEY")`** (`:285`). No mainnet script in this repo reads a key from env.
- Unrestricted mock mints, the whole Uniswap V2 bring-up (`:1450-1486`, incl. 300 ETH into WETH9), the
  fabricated Phase 9/9.5/9.55/9.6 seeding through the **real** `PhusdStableMinter.mint`, the index-6
  bugged-pooler mirror (mainnet index 6 is already occupied; a second would push NudgeRatchet to 8 and
  break `MintPageView`), the whole migration rehearsal, and the dead `MockERC4626Wrapper` /
  `MockBalancerVault.swap` scaffolding.

### 4.3 MUST ADD

1. **`require(addr != address(0))` on every address sourced from `mainnetAddresses`.** The trigger is
   live in-repo: `server/deployments/mainnet-addresses.ts` carries `Kendu` (`:64`) and `NudgeStreamer`
   (`:131`) as `0x0` placeholders, type-indistinguishable from real addresses because the
   `ContractAddresses` interface is **regenerated from anvil data** with every field a required plain
   `string` (**L-03**). And `:136,:142,:144-145` actively misdescribe reality — comments claiming
   `NudgeRatchet` / `RatchetNFTStaker` / `RatchetBatchNFTMinter` are "not yet deployed… zero placeholders"
   sit next to **real non-zero mainnet addresses** `0xd4ea91f6…`, `0x299b0071…`, `0x81896f48…` (**L-04**).
   That file inverts precisely the distinction the port turns on.
2. **`require(dispatcher.nudgeStreamer() == expected)` after all six donor legs (seven calls).** Today
   only the StableYieldAccumulator leg models this, at `DeployMocks.s.sol:1129` (**L-06**). Note the
   index-4 leg (`:784`) is the one whose failure does **not** announce itself — assert that the donation
   actually lands, not merely that the setter returned. (Correction to the earlier framing: the swallow is
   *bounded*, not a value leak — `BalancerPoolerV2` does emit `DonationSkipped(remainingUSDS)` at
   `:291-293` and the swept USDS parks on the pooler and is re-swept by the next dispatch. The residual
   risk is operational quietness.)
3. **A `block.chainid == 1` guard in both `setUp()` and `run()`.** DeployMocks has **no chain guard at
   all** — `:290` merely logs the chain id (**L-02**), despite the project's own `CLAUDE.md` mandating that
   anvil relaxations sit behind an explicit `block.chainid == 31337` branch.
4. **A `PREVIEW_MODE` branch** (uniform across the seven mainnet scripts:
   `vm.envOr("PREVIEW_MODE", false)` → `vm.startPrank(OWNER_ADDRESS)` vs argument-less
   `vm.startBroadcast()`, signer via `--ledger --hd-paths "m/44'/60'/46'/0/0"`), **a checkpoint/resume
   mechanism that reads its own progress file** (DeployMocks reads none — no `vm.readFile`/`parseJson`
   anywhere), **a progress file not written before broadcast**, **untouched-state assertions** in the
   style of `DeployMainnetUniboostBatchMinters:167-169`, and **a phase split**. The local run was 352
   transactions; a monolithic mainnet equivalent is a 352-signature Ledger session, and the
   `//uniboost-cutover:resume` note records a 67-tx session dying at tx 12 on a transient gas error.
5. **The `primeToken() == USDS` require, verbatim, before the first whitelist call.**
   `setNudgeTokenWhitelist` derives the payment token from the *pinned dispatcher* and rejects any nudge
   token equal to it (`BatchNFTMinterMultiToken.sol:324-336`) — so if the batch minter is pinned to any
   USDC-primed index (1/2/3 or 7) instead of 4, `setNudgeTokenWhitelist(USDC, true)` reverts, and since
   `registerStream` requires `isNudgeToken`, **the only stream mainnet plans to have cannot be created**.
   Do **not** copy `DeployMainnetNudgePoolerV2:666-689`, whose "no active dispatcher uses USDC as
   primeToken" assertion is now **false** on mainnet.
6. **Documentation of one irreversible consequence.** `StableYieldAccumulator.setRewardToken` carries a
   conditional guard (`:452-458`) that arms once the nudge path is live. The mainnet SYA is *already*
   deployed with `rewardToken`, `nudge` and `nudgeSplit` set, so the moment a mainnet script calls
   `setNudgeStreamer`, **the guard arms permanently** — any future `setRewardToken` then reverts unless a
   stream for the new token was registered on the *current* `nudge` address first. Write that into the
   script's NatSpec; do not merely execute it.

### 4.4 Signature change, not arity — and a preflight sweep that missed two sites (Q-04)

Legacy `batchMint(uint256, address, uint256, uint256 minReward)` becomes V2
`batchMint(uint256, address, uint256, uint256[] calldata minRewards)`
(`BatchNFTMinterMultiToken.sol:470`). The arity is unchanged, so **the compiler does not help you** — the
fourth argument changed type. Story 073's preflight sweep (line 491) missed two call sites still bound to
the scalar form:

- `script/PreviewBatchMint40.s.sol:55` and `:145`
- `script/interactions/SimulateMainnetNudgeMint.s.sol:77`

Both break on the story-072 cutover, and neither is in the feedback list. Worse, `SimulateMainnetNudgeMint`
wraps the call in a `try/catch` that only logs `"REVERT low-level"` — so it fails **quietly**, in the one
tool meant to predict mainnet mint success.

### 4.5 Constants that are local by design — and one that is not codified anywhere

| Constant | Local | Mainnet |
|---|---|---|
| `MOCK_NUDGE_SIZE` | 25 (`:106`) | 40 |
| `LOCAL_STREAM_DURATION` | 6 hours (`:117`) | **see below** |
| Registered streams | 3 (USDC/phUSD/Kendu) | **1 (USDC only)** |
| phUSD / Kendu nudge seeds | 5,000 / 50,000 | no donor exists |
| `REHEARSAL_STAKER_BUDGET` | 1,000 phUSD | n/a |

The author's guardrails apply in reverse — `:113-116` ("DELIBERATELY 6 hours… Do NOT 'fix' this to match
mainnet") and `:1557-1560` ("Do not read local behaviour as a prediction of mainnet's").

**The "mainnet 7 days" figure is not codified anywhere.** It exists only as a comment at
`DeployMocks.s.sol:113`; grepping `7 days|604800` across `src/`, `script/`, `docs/` and `CLAUDE.md` finds
no mainnet stream duration at all. **It is an unimplemented author intention, not a value to copy** — your
new script is the first place it will be written down, so treat it as a decision needing explicit sign-off.

---

## 5. Findings register

| Label | Sev | What | Where |
|---|---|---|---|
| **M-01** | Medium | `NudgeStreamer.collectNudge` does `safeTransferFrom` then `s.buffer += amount` with no balance-delta measurement, while custody is **pooled per token** across `(batchMinter, token)` pairs and the payout cap in `_accrued` is **per stream**. PoC **4/4 PASS** against the real contract with a 5% FoT token: buffer 100,000e18 vs custody 95,000e18; two pairs of one token drain each other and the second pair's `pullPendingStream` **reverts**; and because `batchMint` loops `pullPendingStream` over the whole whitelist in one transaction, **one tainted token bricks the mint path for every reward token**. The contract NatSpec at `:194-196` asserts the opposite — *"the buffer cap guarantees the streamer can never transfer more than it holds"* — true per-stream, false across pairs. | `NudgeStreamer.sol:149-150` |
| **M-02** | Medium | `BatchNFTMinterMultiToken.setNudgeStreamer` is the **only one of six** streamer setters with no zero-address guard, **and the only one that fails silently** (the five siblings revert: `BalancerPoolerV2:247`, `Uniboost:191`, `NudgeRatchet:106`, `PromotionUniV2_Eth:349`, `StableYieldAccumulator:514`). Proven live, 2/2 PASS: with the streamer zeroed, the **same** `batchMint(26)` **succeeds** with no revert and no event, paying **189,464** instead of 45,045,015 USDC + 5,000e18 phUSD + 50,000e18 Kendu — the whole matured pot stranded in the streamer. Escalated from the auditor's proposed Low: the trigger (L-03's `0x0` placeholder) is live in-repo, and the same class was already accepted as Medium in `yield-claim-nft` `c91bef813d`. | `BatchNFTMinterMultiToken.sol:299-302` |
| L-01 | Low | `deploymentStatus:"completed"` hard-coded and written before broadcast | `:1922` |
| L-02 | Low | No `block.chainid` guard of any kind (also **F-05**, cross-reference only) | `:290` |
| L-03 | Low | `Kendu` / `NudgeStreamer` `0x0` placeholders indistinguishable from real addresses | `mainnet-addresses.ts:64,131` |
| L-04 | Low | Comments claiming "not yet deployed" next to real mainnet addresses | `mainnet-addresses.ts:136-145` |
| L-05 | Low | Unguarded `Mock`-prefix strip, no duplicate-key detection | `extract-addresses.js:107,144` |
| L-06 | Low | 1 of 7 `setNudgeStreamer` legs post-asserted | `:1129` |
| L-07 | Low | `test:balancer-donation` ticked as the streamer regression test; it tests neither | story 505/539 |
| L-08 | Low | Line 544 ticked; 1 of 4 clauses implemented | story 544 |
| **L-09** | Low | **The Kendu FoT guard is vacuous in the reassuring direction.** The probe at `:1661` runs against `MockKendu`, which the story defines as fee-free — so an operator has now *watched an FoT assertion pass*. Story 072 line 514, the real-token round-trip, is **unticked**. Low only because mainnet registers USDC alone; carries a **REOPEN-AS-MEDIUM** trigger and a blocking pre-broadcast action. | `:1661` / story 072:514 |
| Q-01 | QA | Constant-derived rehearsal sizing (88.67%, 345.042 phUSD stranded) — faithful to AD#4; **do-not-port instruction retains full weight** | `:1831` |
| Q-02 | QA | `MockERC4626Wrapper` dead, pre-funded 1M USDC, exported to the UI | `:677,:686` |
| Q-03 | QA | Server root doc advertises 18 contracts; 57 served | `server/index.js` |
| Q-04 | QA | Preflight `batchMint` sweep missed two call sites, one failing quietly | see §4.4 |

Spec-conformance routing (Law 2) is indexed separately in `findings/spec-conformance.md`:
F-01→L-07, F-02→L-08, F-03→Q-04, F-04→L-09, F-05→L-02 (cross-reference only, not double-counted).

---

## 6. Caveats, limits, and what I could not verify

**Known-issues suppression was BLOCKED this run — zero findings were suppressed.**
`registered-projects.json` declares `knownIssuesFile: lib/phoenix-phase-2-staging/known-issues.md` with 11
cached issues (snapshot `2026-01-09`), but **the file does not exist on disk**. Under Law 1 nothing was
suppressed on an unfalsifiable list. **Q-02** (dead pre-funded mock) is the one finding a live list would
plausibly have caught under "mock contracts with unlimited minting (testing infrastructure only)"; it is
kept live and flagged for explicit human triage. Recommend re-extracting known issues from the submodule
at HEAD, or clearing `knownIssuesFile`/`knownIssues` from the registry.

**MR-DEV-001 is parked, not filed.** `ERC4626YieldStrategy.previewRedeem` / `previewDeposit`
(`lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626YieldStrategy.sol:73-85`) are declared
`external view` ⇒ Solidity emits a **STATICCALL**. Against a real Tokemak Autopool they revert for every
caller, always; against `MockAutoDOLA` they return a clean number, always. Twenty lines below, `:110-115`
hardened **one** adjacent call site with an in-source comment naming Tokemak explicitly — the fix is
one-directional. This is a `reflax-yield-vault` contract defect, **outside this entry point's slice**, so
filing it as a `dev` finding would file a vault bug against a devnet script. **Recommended: file it
against `reflax-yield-vault`**, with disclosure vs ledger entry `28d5044e4e` (medium, `acknowledged`,
`_acquireShares` — a **different function**, hence a different fingerprint; must not be auto-suppressed
under it, and its status must not be altered). Blast radius today is UI/keeper reads, which is why it is
parked rather than asserted as a Medium.

**Both stories' acceptance criteria are non-final.** Story 073 moved `review/` → `complete/` mid-run and
still carries `Review Status: ISSUES_FOUND`; story 072 is `incomplete/` with line 514 unticked. This is
recorded as **confidence, not severity inflation**. **Close trigger:** if line 544's four clauses are
actually asserted across all seven legs, and line 514 is ticked against the **real** Kendu token, **L-08
and L-09 may be closed.**

**Two pre-existing audit PoCs no longer compile** after the story-039 `V2/` flatten —
`poc-BMR-M-01.t.sol` and `AuditRatchetMainnetDeploy.t.sol`. A `/recheck` on their findings would return
**INCONCLUSIVE from bit-rot, not from a fix**; do not read a failure there as evidence either way.

**Carryover.** Ledger entry `0b497be32114…` (QA, open, `entryPoint: dev`) was **not re-observed** this
run. Because this run was story-073-scoped rather than a full project scan, **absence is not evidence of a
fix** — it is left `open`, `lastSeenRun` not bumped, and carried forward in full at
`findings/carryover/qa-report-05.md`. `lastAuditedCommit` was deliberately **not** advanced; it remains
`0e190e8`, with only the per-entry-point `dev` baseline moved to `3fb4e34`. No pre-existing ledger entry's
`status`, `triageReason` or `reclassNote` was modified.

### What I could not verify

- **Anything economic.** Every price-modelling mock is a constant-function stub (§2), so no swap, quote,
  slippage floor, BPT valuation or redemption behaviour was tested. Those remain open on the fork preview.
- **`tsc --strict`** on the regenerated address files — TypeScript is not installed in the worktree. The
  story's own review recorded the same limitation and verified key parity by count instead (57 == 57).
- **Real-token semantics for Kendu Inu.** No on-chain read of
  `0xaa95f26e30001251fb905d264aa7b00ee9df6c18` was performed; that is exactly what story 072 line 514
  demands, and it is the blocking pre-broadcast action.
- **Exhaustive event enumeration.** All 352 receipts are status `0x1`, but events were sampled at the
  wiring-relevant emissions (`NudgeStreamerUpdated` ×6, `StreamRegistered` ×3, `NudgeCollected` ×2,
  `NudgeTokenWhitelistChanged` ×3, `NudgePaid` ×3 under test) rather than catalogued in full.
- **`DEV-04`** (the bounded `DonationSkipped` swallow) is **static** — source-verified at
  `BalancerPoolerV2.sol:287-293`, not separately executed.
- **Mainnet state itself.** No mainnet RPC read was performed for this entry point; every mainnet claim
  above is sourced from committed script constants and address files, which §4.3 shows are themselves
  partly wrong.
