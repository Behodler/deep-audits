# UniPoolerCutoverEscrow: one-shot custody contract so no cutover funds touch an EOA

Current Sprint: 22
Base Commit: 267660b96b92160a21919b043e571f2dbe51d216
Execution Type: existing_worktree
Base Commit Updated: 2026-10-06T23:32:19Z

## ⚠️ Required Human Action On Completion

1. **Audit the escrow.** Run the yield-claim-nft project audit covering `src/migration/UniPoolerCutoverEscrow.sol`. The escrow must not be deployed to mainnet before the audit passes.
2. **Then bump phStaging2.** phStaging2 bumps `lib/yield-claim-nft` to include this story and rewires `script/helpers/UniPoolerCutoverCore.sol` (see Follow-ups). phStaging2:103 must not execute before that.
3. **Decide on the red CI fork job.** CI has no mainnet RPC secret, so `test/UniPoolerCutoverEscrow.fork.t.sol` fails in CI by design: it fails loudly rather than skipping (see Autonomous Decision 1). The human must either add a mainnet RPC secret to CI or accept the red fork job. The `forge fmt --check` and `forge build --sizes` failures in CI predate this story (see Autonomous Decision 7).

## Story Overview

The Balancexit cutover (phStaging2:103, built on phStaging2 `script/helpers/UniPoolerCutoverCore.sol`) currently moves protocol funds through the owner EOA `0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6` (a Ledger), across separate broadcast transactions:

- **Step 2:** `pair.skim(p.owner)`.
- **Step 4:** `BalancerPoolerV2.withdrawBPT(p.owner, bal)` (~20.4k BPT).
- **Step 5:** the Balancer V3 exit runs from the owner, so ~19.1k sUSDS and ~21.9k phUSD land on the owner.
- **Step 11:** parked USDS goes `rescueERC20(usds, p.owner, x)` then `sUSDS.deposit(x, newPooler)`. This branch runs on mainnet because `batchDonationSize == 0`.

The human requires this for tax and accounting: it must be provable on-chain that these funds are protocol liabilities moving contract-to-contract, never through the owner's EOA or any other EOA. See `scratchpad/legal/tax-notes/2026-10-sa-tax-position-behodler.md`, "Design the migration contracts to reinforce the deposit-liability position".

This story adds a small one-shot custody contract. Its only possible outflows are to the new `UniPoolerV2` (forward) or back to the old `BalancerPoolerV2` (abort). No function anywhere takes a caller-chosen recipient.

- **Repo:** `~/code/reflax-mint/yield-claim-nft`
- **Worktree:** `worktrees/yield-claim-nft/Balancexit/`
- **Branch:** `sprint/Balancexit` (== master == `267660b`, which is also the phStaging2 Balancexit pin)
- **Expected execution:** existing worktree

## Design (decided with the human)

### Access: immutable operator, not Ownable

- No owner, no `transferOwnership`, no renounce. A single immutable `operator` gates every state-changing function. It is the cutover sender, mainnet `0xCad1…D0B6`.
- **Why not permissionless:** a permissionless trigger would let a stranger choose timing and slippage floors:
  - sandwiching via Balancer swaps before 30 Oct;
  - front-running between the owner's `withdrawBPT` and `exitAndSeed`, which would revert the forge broadcast mid-cutover before any wiring step;
  - griefing `abort`.
- The custody guarantee itself does not depend on the gate, because no function can pay out to a chosen address.

### Immutables

- **`operator`:** constructor arg, non-zero.
- **`newPooler`:** UniPoolerV2, constructor arg. At construction, read `pair()`, `router()` (Router02), `sUSDS()` and `phUSD()` from it.
- **`oldPooler`:** BalancerPoolerV2, constructor arg; mainnet `0x7f6874332c4629429d70D15f685A8230323F11F1`. At construction, read from it:
  - `pool()`, the BPT. Snapshot it, because `pool` is mutable on the old pooler via `setPool`.
  - `primeToken()`, which is USDS.
  - Require `oldPooler.sUSDS() == newPooler.sUSDS()` and `IERC4626(sUSDS).asset() == USDS`.
- **`v3Router`:** the Balancer V3 Router, constructor arg; mainnet `0x5C6fb490BDFD3246EB0bB062c168DeCAF4bD9FDd`. BalancerPoolerV2 keeps its router private, so it must be passed in.
- The constructor rejects zero addresses.

### `exitAndSeed(ExitMode mode, uint256[] calldata minAmountsOut, uint256 deadline)`

`onlyOperator`, `nonReentrant`, atomic.

1. **The pair must be empty.** If pair token balances are non-zero but reserves are (0,0), call `skim(newPooler)`. The recipient is fixed and is a protocol contract. Then require reserves (0,0) AND pair balances (0,0), otherwise revert. A griefer's synced donation can only DoS, never redirect funds.
2. **BPT in:** `bptIn = BPT.balanceOf(this)`; require > 0. This includes any BPT the owner transferred in. The owner already holds 202.30 BPT from an earlier `Temp.s.sol` withdrawal, and phStaging2 will transfer it owner -> escrow explicitly.
3. **Argument checks:**
   - `minAmountsOut.length == 2`, and every entry > 0 (Balancer pool-token order).
   - Deadline > `block.timestamp` and <= `block.timestamp + 1 days`. This mirrors the core's bound.
4. **Exit:**
   - `forceApprove(v3Router, bptIn)`. The V3 Router burns the caller's BPT by spending the ROUTER's BPT allowance; mainnet reverts `ERC20InsufficientAllowance(router, ...)` without it.
   - Then call `removeLiquidityProportional(pool, bptIn, minAmountsOut, false, "")` or `removeLiquidityRecovery(pool, bptIn, minAmountsOut)`, chosen by `mode`. `mode` is a parameter and is never derived from the clock.
   - Reset the approval to 0. Require the escrow's BPT balance == 0.
5. **Seed** with the escrow's WHOLE sUSDS and phUSD balances. This is balance-based, so stray tokens anyone sent are swept into protocol liquidity rather than stranded.
   - `forceApprove` Router02 for the exact amounts, then `addLiquidity(sUSDS, phUSD, s, p, s, p, newPooler, deadline)`.
   - Into an empty pair the router consumes the desired amounts exactly. So the amount mins equal the desired amounts, and no seed-min parameter is needed.
   - Require `a == s && b == p`, `liquidity > 0`, the LP balance of `newPooler` increased by `liquidity`, and reserves == seeded amounts.
   - Reset the approvals to 0.
6. **Post-conditions:** require the escrow's BPT, sUSDS and phUSD balances all == 0 afterwards. Emit `Seeded(bptIn, sUSDS, phUSD, liquidity, mode)`.

### `wrapUsds()`

`onlyOperator`, `nonReentrant`.

- `amt = USDS.balanceOf(this)`; require > 0.
- `forceApprove(sUSDS, amt)`, `IERC4626(sUSDS).deposit(amt, newPooler)`, reset the approval, require the USDS balance is 0.
- Emit `UsdsWrapped(amt, shares)`.
- Used for the old pooler's parked USDS, which phStaging2 will move with `rescueERC20(usds, escrow, x)`.

### `abort()`

`onlyOperator`, `nonReentrant`.

- Transfer the escrow's entire BPT, sUSDS, phUSD and USDS balances to `oldPooler` only. All four are recoverable there via the old pooler's `rescueERC20`/`withdrawBPT`.
- Emit `Aborted(...)`.

### Other surface

- No `receive`/`fallback`. Router calls pass zero ETH.
- No other functions besides views.

### Local interfaces only

- Do NOT import `src/interfaces/balancer/*` or `src/dispatchers/BalancerPoolerV2.sol`: yield-claim-nft:050 deletes them.
- Declare minimal file-local interfaces. Name them so no identifier or comment matches 050's grep `interfaces/balancer|BalancerPoolerV2|IBalancer|IUnlockCallback|BalancerTypes`, e.g. `IV3RouterExit`, `ICutoverOldPooler`. In prose, call the old pooler "the old pooler" or "the Balancer-era pooler".
- Router02, pair and factory may use the repo's `src/interfaces/uniswap/*`, which 050 keeps.
- V3 Router exit signatures, verified against mainnet bytecode (selectors `0x51682750` and `0x08c04793`):

```solidity
function removeLiquidityProportional(address pool, uint256 exactBptAmountIn, uint256[] memory minAmountsOut, bool wethIsEth, bytes memory userData) external payable returns (uint256[] memory amountsOut);
function removeLiquidityRecovery(address pool, uint256 exactBptAmountIn, uint256[] memory minAmountsOut) external payable returns (uint256[] memory amountsOut);
```

### Location

- New folder: `src/migration/UniPoolerCutoverEscrow.sol`. It is not a dispatcher; `src/dispatchers/` holds only `ATokenDispatcherV2` subclasses.
- Do not touch `ATokenDispatcherV2` or any existing src file.

## Background (exploration of 267660b)

### Conventions (from `src/dispatchers/UniPoolerV2.sol`)

- `// SPDX-License-Identifier: MIT`, `pragma solidity ^0.8.20;`.
- OZ v5.5.0 named imports via `@openzeppelin/contracts/`: `IERC20`, `SafeERC20`, `IERC4626`, `ReentrancyGuard`.
- Custom errors `UniPoolerCutoverEscrow__Reason(args)` for new checks. `require("UniPoolerCutoverEscrow: ...")` is acceptable for the constructor zero checks.
- Full NatSpec on the contract, functions, errors and events.
- Past-tense events with indexed addresses.
- `forceApprove(exact)` then reset to 0. Never infinite approvals.
- Immutables are `_camelCase` with forge-lint disable comments, as UniPoolerV2 does.
- `src/MultiPooler.sol` is the closest standalone non-dispatcher template.

### UniPoolerV2

- Constructor `(sUSDS_, phUSD_, router_, pair_, initialOwner)` requires `pair_` to be the router factory's canonical sUSDS/phUSD pair (it may be empty).
- It keeps LP on itself. `pool()` reverts `UniPoolerV2__EmptyPair` until seeded. LP exit is owner `rescueERC20(pair, to, amount)`.
- phUSD sent to it is only recoverable via `rescueERC20`, because its `pool()` never consumes held phUSD. That is acceptable, but the seed should leave none.

### Old pooler

- `BalancerPoolerV2.withdrawBPT(recipient, amount)` and `rescueERC20(token, to, amount)` are `onlyOwner` and not pause-gated. There is no recipient restriction beyond non-zero (rescue).

### Test infrastructure

- `test/mocks/MockUniV2Amm.sol`:
  - `MockUniV2AmmPair` has mint/swap/skim/sync and MINIMUM_LIQUIDITY, but no burn.
  - `MockUniV2AmmRouter(pair)` has real optimal-amount logic, consumes exact desired amounts on an empty pair, and checks the deadline.
- `test/mocks/MockERC4626.sol` is the sUSDS stand-in, with `deposit(assets, receiver)`.
- Inline 18-decimal ERC20s for USDS/phUSD: see the `test/UniPoolerV2.t.sol` setUp.
- No mock implements Balancer V3 exits. This story adds one.
- Fork tests use `vm.envOr("MAINNET_RPC_URL", vm.envOr("RPC_MAINNET", ""))` and `vm.createSelectFork(rpc, FORK_BLOCK)`. Existing suites use `FORK_BLOCK = 25_550_000`.

### Mainnet addresses

| Contract | Address |
|---|---|
| USDS | `0xdC035D45d973E3EC169d2276DDab16f1e407384F` |
| sUSDS | `0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD` |
| phUSD | `0xf3B5B661b92B75C71fA5Aba8Fd95D7514A9CD605` |
| Uniswap V2 Router02 | `0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D` |
| Uniswap V2 Factory | `0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f` |
| BPT pool | `0x642BB6860b4776CC10b26B8f361Fd139E7f0db04` |
| Balancer V3 Vault | `0xbA1333333333a1BA1108E8412f11850A5C319bA9` |
| Balancer V3 Router | `0x5C6fb490BDFD3246EB0bB062c168DeCAF4bD9FDd` |
| Old pooler (BalancerPoolerV2) | `0x7f6874332c4629429d70D15f685A8230323F11F1` |
| Owner EOA / operator | `0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6` |

The mainnet V2 factory `feeTo` is LIVE. Do not assume fee-off LP maths.

### Known audit lessons

- Permissive fixtures make tests unfalsifiable.
- `onlyForked`/`vm.skip` shows as a pass when there is no RPC.

### CI

CI runs `forge fmt --check`, `forge build --sizes` and `forge test -vvv`.

## File Locations

| File | Change |
|---|---|
| `src/migration/UniPoolerCutoverEscrow.sol` | NEW |
| `test/mocks/MockV3ExitRouter.sol` | NEW: V3 Router exit mock (plus a minimal mintable/burnable BPT if needed) |
| `test/UniPoolerCutoverEscrow.t.sol` | NEW: unit tests |
| `test/UniPoolerCutoverEscrow.fork.t.sol` | NEW: mainnet fork test |

## Checklist

- [x] Write the V3 exit-router mock. It burns BPT via `transferFrom`/burn against the ROUTER's allowance, so a missing approve must fail as it does on mainnet. It pays tokens pro rata in pool order, enforces every `minAmountsOut`, and has a `paused` switch under which `removeLiquidityProportional` reverts and `removeLiquidityRecovery` succeeds.
- [x] Write failing unit tests first (red commit), then implement (green commit). Unit tests must cover:
  - [x] Constructor: zero-address rejections; an sUSDS mismatch between the poolers is rejected; USDS != `sUSDS.asset()` is rejected; immutables are read from the poolers.
  - [x] Access: every state-changing function reverts for a non-operator; there is no owner/`transferOwnership` surface.
  - [x] `exitAndSeed` happy path in PROPORTIONAL and RECOVERY modes: all BPT exited, LP minted to `newPooler`, reserves == seeded amounts, escrow holds 0 BPT/sUSDS/phUSD, operator's BPT/sUSDS/phUSD/USDS balances unchanged.
  - [x] PROPORTIONAL reverts on a paused mock pool while RECOVERY succeeds.
  - [x] Reverts: zero BPT; any zero `minAmountsOut`; wrong length; deadline in the past or > 1 day ahead; non-empty pair reserves; `minAmountsOut` not met.
  - [x] An unsynced donation on the pair is skimmed to `newPooler` (not the caller) and the seed proceeds; a synced donation reverts.
  - [x] Stray sUSDS/phUSD sent to the escrow before the seed ends up in the seeded liquidity, with nothing left on the escrow.
  - [x] `wrapUsds` deposits to `newPooler`; `abort` returns all four tokens to `oldPooler` only.
  - [x] A property/fuzz test: for any sequence of operator calls, no token ever leaves the escrow to an address other than `newPooler`, the pair, the routers (as spender during the call) or `oldPooler`.
- [x] Fork test on mainnet (`test/UniPoolerCutoverEscrow.fork.t.sol`):
  - Case 1: deploy UniPoolerV2 against a freshly created canonical pair, deploy the escrow, `vm.prank` the real old-pooler owner to `withdrawBPT(escrow, fullBalance)`, run `exitAndSeed(PROPORTIONAL, ...)` with `minAmountsOut` = live proportional share minus a tight tolerance. Assert LP on `newPooler`, reserves == recovered, escrow empty, and the owner EOA's BPT/sUSDS/phUSD/USDS balances unchanged.
  - Case 2: the Recovery path. If Recovery Mode cannot be enabled on the fork at the chosen block, record why.
  - The fork test must FAIL (not skip or pass silently) when no RPC env var is set, or must assert that the fork actually ran. Show RPC proof in the completion notes.
- [x] Grep proof: `grep -rn --include=*.sol -E "interfaces/balancer|BalancerPoolerV2|IBalancer|IUnlockCallback|BalancerTypes" src/migration test/UniPoolerCutoverEscrow* test/mocks/MockV3ExitRouter.sol` returns nothing.
- [x] No existing src file modified: `git diff --stat 267660b -- src` shows only `src/migration/`.
- [ ] `forge fmt --check`, `forge build --sizes` and `forge test` (full suite) pass.
- [x] All commits use `[story-052] <message>`, staged by explicit path.
- [ ] Final step: ⚠️ HUMAN ACTION REQUIRED — audit `src/migration/UniPoolerCutoverEscrow.sol` before any mainnet deployment; then phStaging2:103 bumps the pin.

## Follow-ups (not in this story)

- **phStaging2 (the content of the phStaging2:103 amendment):**
  - Bump `lib/yield-claim-nft` to include 052.
  - Rewire `UniPoolerCutoverCore`:
    - **Escrow deployment placement:** deploy the escrow (operator = OWNER) in the same broadcast, after step 3 (`_step3DeployPooler`, which deploys UniPoolerV2 against the canonical pair created in step 1) and before step 4 (`withdrawBPT`). The escrow constructor reads `newPooler.pair()`, so UniPoolerV2 must already be deployed with its pair. Step 4 needs the escrow address as its recipient.
    - **Step 2 drops the skim entirely:** at step 2 neither `newPooler` nor the escrow exists yet, so step 2 does not skim to anyone. It only asserts that the pair is empty (reserves AND balances (0,0)), or records its state. Any unsynced donation is skimmed to `newPooler` later, inside `escrow.exitAndSeed` (its step 1).
    - step 4 -> `withdrawBPT(escrow, bal)`;
    - the owner's pre-existing 202.30 BPT is transferred owner -> escrow explicitly (read the live balance), after step 4 and before `exitAndSeed`;
    - **minAmountsOut over the combined balance:** the core's check of `minAmountsOut` against the live proportional share (`_checkMinAmountsOut`, which today runs inside step 5 with `bptIn = balanceOf(owner)`; step 0 only checks length and non-zero) must, once it runs before `exitAndSeed`, be computed on the escrow's COMBINED BPT balance after the owner -> escrow transfer: the old pooler's BPT (~20,401.8 at planning time) plus the owner's 202.30. Read both balances live. `exitAndSeed` exits `BPT.balanceOf(escrow)`, so a floor computed on the old pooler's BPT alone is mis-sized;
    - steps 5+6 -> `escrow.exitAndSeed`;
    - parked USDS -> `rescueERC20(usds, escrow, x)` + `escrow.wrapUsds()`.
  - Update the anvil rehearsal (101 inherits the core) and the 103 fork test with an invariant that the owner's sUSDS/phUSD/USDS/BPT balances never increase across the cutover.
  - Add a fork assertion that `removeLiquidityProportional` reverts and `removeLiquidityRecovery` succeeds on a paused pool.
  - **phStaging2:103 fork-test coverage of the owner's BPT:** this story's own fork test does not exercise the owner's real pre-existing BPT. The phStaging2:103 fork test must transfer the owner's actual mainnet BPT (202.30 at planning time) into the escrow and compute `minAmountsOut` over the combined escrow balance (old pooler's BPT + owner's BPT).
- **yield-claim-nft:050:** must keep `src/migration/` and the escrow tests, because the deployed bytecode's source must stay reproducible for the tax/accounting proof. Its grep needs an exclusion list; it already fails today on `IBalancerPoolerMintDebtHook.sol`/`BalancerPoolerMintDebtHook.sol`, which 050 itself says to keep. Raised to the human, not changed here.

## Concerns

- **Trigger access:** immutable `operator` instead of Ownable or permissionless. The human agreed; rationale under Design.
- **Seed minimums:** dropped as a parameter because an empty pair consumes the desired amounts exactly; the contract requires exact consumption instead. `minAmountsOut` on the Balancer exit remains the slippage guard.
- **Pair donation:** skimmed to `newPooler` (fixed, protocol-owned) rather than the owner. A synced donation reverts (DoS only).
- **Whole-balance seed:** the seed uses the escrow's whole sUSDS/phUSD balance, not exit deltas, so nothing can be stranded on the escrow. A stray donation becomes protocol liquidity at the Balancer price ratio only if it is proportional; otherwise stray tokens slightly shift the seeded price. This is bounded by the operator choosing when to call. Flag for the auditor.
- **On-chain share check:** the escrow does not recompute the live proportional share (the phStaging2 core does that off the escrow before calling); it only enforces non-zero `minAmountsOut`. Operator-gated, so acceptable. Flag for the auditor.
- **Source retention:** the escrow's source must survive 050 (see Follow-ups).

---
## Autonomous Decisions
**Date**: 2026-10-07T00:00:00Z
**Command**: execute-story yield-claim-nft:052 (implementation subagent)

### Decision 1: Fork test fails (does not skip) without an RPC, even though CI has none
- **Situation**: The story requires the fork test to FAIL, not skip, when no RPC env var is set. The repo's existing fork suites (`PromotionUniV2_Eth.t.sol`, `UniPoolerV2.fork.t.sol`) skip instead. CI (`.github/workflows/test.yml`) runs `forge test -vvv` and passes no RPC env, so CI will now show this suite's `setUp()` as failing.
- **Decision**: `setUp` does `require(rpc != "")` with an explicit message. Every test also asserts `block.chainid == 1`, `block.number == FORK_BLOCK` and live code at the old pooler. There is no opt-out env var. The CI workflow is not modified.
- **Rationale**: The story is explicit, and the audit lesson is that a skip reads as a pass. Changing CI is outside this story's file list, and the right fix (adding a `MAINNET_RPC_URL` secret) needs a human.
- **Alternatives**: (a) the human adds `env: MAINNET_RPC_URL: ${{ secrets.MAINNET_RPC_URL }}` to the CI test step, which is recommended; (b) CI excludes the suite with `--no-match-path 'test/UniPoolerCutoverEscrow.fork.t.sol'`; (c) add an explicit `SKIP_FORK=true` escape hatch that calls `vm.skip`.

### Decision 2: Fork block 26_136_000 instead of 25_550_000
- **Situation**: The story leaves the block open ("may need a recent block").
- **Decision**: `FORK_BLOCK = 26_136_000`. At that block the old pooler holds 20,401.809… BPT, its `owner()` is `0xCad1…D0B6`, the sUSDS/phUSD V2 pair does not exist, the pool is neither paused nor in Recovery, and the factory `feeTo` is live (`0xf385…5f85`).
- **Rationale**: It is close to the live state the cutover will actually run against.
- **Alternatives**: Any later block where the old pooler still holds BPT and the pair does not exist yet.

### Decision 3: Recovery Mode on the fork is reached through Balancer governance
- **Situation**: Case 2 needs the pool in Recovery Mode. The pool has no pause manager (`getPoolRoleAccounts` returns all zeros).
- **Decision**: The test does `vm.prank(0xA29F61256e948F3FB707b4b3B138C5cCb9EF9888)`, the sole holder in the Vault's authorizer `0xA331…3aE6` of both the `pausePool` and `enableRecoveryMode` action ids, then calls `vault.pausePool(BPT)`. Next, `enableRecoveryMode(BPT)` is called from an arbitrary address; it is permissionless once the pool is paused. Then: PROPORTIONAL reverts with the Vault's `PoolPaused(BPT)`, the operator `abort`s, the BPT goes back to the old pooler, and the full cutover re-runs via RECOVERY and passes.
- **Rationale**: This is the realistic governance path, with no mocked authorizer.
- **Alternatives**: Use `vm.mockCall` on the authorizer's `canPerform`. Not needed.

### Decision 4: Mock recovery needs a `recoveryMode` flag, independent of `paused`
- **Situation**: The checklist says the mock's `paused` switch makes proportional revert and recovery succeed. On mainnet, recovery also requires Recovery Mode.
- **Decision**: `MockV3ExitRouter` has two flags. `paused` makes proportional revert. `recoveryMode` is required for recovery, and recovery ignores `paused`. The paused-pool unit test sets both. A separate test shows RECOVERY reverts outside Recovery Mode.
- **Rationale**: This matches mainnet, and the fixture stays falsifiable.
- **Alternatives**: Have recovery succeed whenever `paused` is set. That would be more permissive than mainnet.

### Decision 5: USDS's sUSDS-vault deposit counts as an allowed escrow outflow
- **Situation**: The property's allowed set lists `newPooler`, the pair, the routers and `oldPooler`. `wrapUsds` necessarily moves USDS into the sUSDS ERC4626 contract (`deposit`), with the shares minted to `newPooler`.
- **Decision**: In the property and invariant tests, each token has its own allowed destinations. BPT may go to the V3 router (pulled, then burned) or to `oldPooler`. sUSDS/phUSD may go to the pair (seed) or to `oldPooler`. USDS may go to the sUSDS vault (deposit, shares to `newPooler`) or to `oldPooler`. The invariant also asserts the operator never holds any of the four tokens, no allowance survives, strangers never succeed, and at most one seed happens.
- **Rationale**: This is the design's own `wrapUsds` flow, and it is the tightest per-token set.

### Decision 6: Extra defensive checks and surface beyond the spec text
- **Situation**: Small gaps in the spec.
- **Decision**:
  - The constructor also rejects zero values read from the poolers (`pair`, `router`, `sUSDS`, `phUSD`, `pool`, `primeToken`).
  - `exitAndSeed` reverts `NothingToSeed` if either side is zero.
  - A `PairSkimmed(recipient, amount0, amount1)` event is added.
  - `exitAndSeed`/`wrapUsds` return `liquidity`/`shares`.
  - `abort` with nothing held is a no-op that still emits `Aborted`.
  - Views: `operator`, `newPooler`, `oldPooler`, `v3Router`, `bpt`, `usds`, `sUSDS`, `phUSD`, `pair`, `uniRouter`, plus the constant `MAX_DEADLINE_WINDOW`.
- **Rationale**: These give a clearer failure mode and observability. None adds a recipient choice or admin surface.

### Decision 7: Repo-wide `forge fmt --check` and `forge build --sizes` fail on PRE-EXISTING files, so that checklist item is left unticked
- **Situation**: At base `267660b`, with forge 1.5.1-stable:
  - `forge fmt --check` reports diffs in 9 existing files: `src/interfaces/uniswap/IUniswapV2Router02.sol`, `src/dispatchers/{PromotionUniV2_Eth,NudgeRatchet,NudgeRatchetDelayRelease,Uniboost}.sol`, `test/{PromotionUniV2_Eth,BalancerPoolerMintDebtHook,NudgeRatchetDelayRelease}.t.sol` and `test/mocks/MockERC4626.sol`.
  - `forge build --sizes` exits 1 because the existing `PromotionUniV2_Eth` is 24,770 B, over EIP-170. The repo has no optimizer setting.
- **Decision**: These are not fixed. Fixing them would modify existing `src/` files, which this story forbids. All four new files pass `forge fmt --check`. The escrow is 11,449 B runtime with 13,127 B margin. The full `forge test` passes with RPC (709/709). The checklist item "fmt/build/test pass" stays unticked, so a human sees it.
- **Alternatives**: A separate story that runs `forge fmt` repo-wide and enables the optimizer (or slims `PromotionUniV2_Eth`).

### Decision 8: The Router02 approval reset is defensive and unobservable
- **Situation**: Mutation testing showed that removing the post-`addLiquidity` `forceApprove(router02, 0)` survives the tests. The router consumes the exact approval in full, and `SeedNotExact` reverts otherwise, so the reset is always a no-op.
- **Decision**: The reset stays, per the "reset to 0" convention. This is documented here rather than with an artificial test.
- **Mutation results (unit suite)**: The following mutants are all killed: removing the BPT approve (11 failures), skim to the caller (4, including the invariant), LP to the caller (11), abort to the caller (3, including both invariants), wrap to the caller (2, including the invariant), and leaving an infinite BPT approval (4, including the invariant).

---
## Autonomous Decisions
**Date**: 2026-10-06T23:51:27Z
**Command**: execute-story yield-claim-nft 52 (orchestrator)

### Decision 1: Move to review with the fmt/build checklist item unticked
- **Situation**: The checklist item "`forge fmt --check`, `forge build --sizes` and `forge test` (full suite) pass" cannot be fully satisfied. `forge test` passes 709/709 with RPC and the four new files pass `forge fmt --check`, but repo-wide `forge fmt --check` (9 pre-existing files) and `forge build --sizes` (`PromotionUniV2_Eth` 24,770 B > 24,576 B) fail identically at base `267660b`. change-validator confirmed this independently in a /tmp worktree of the base commit.
- **Decision**: Leave the item unticked and move the story to review/.
- **Rationale**: The failures predate this story and fixing them requires editing existing `src/` files, which the story forbids. The story introduces no new fmt or size failure. The review transition rule's "no build errors" is read as "no build errors introduced by this story".
- **Alternatives**: Send back and fold a repo-wide `forge fmt` plus a `PromotionUniV2_Eth` size fix into this story (breaks the no-existing-src rule), or plan a separate cleanup story (recommended).

### Decision 2: Accept the fork suite failing in CI without an RPC
- **Situation**: The story requires the fork test to FAIL rather than skip when no RPC is set. CI's `forge test -vvv` has no RPC secret, so CI will fail on `test/UniPoolerCutoverEscrow.fork.t.sol` setUp.
- **Decision**: Keep the fail-loud behaviour as specified; do not edit `.github/workflows/test.yml` (outside the story's file list).
- **Rationale**: The story's explicit requirement and its audit lesson ("`onlyForked`/`vm.skip` shows as a pass when there is no RPC") outrank CI greenness. CI is already red on the pre-existing fmt/size failures.
- **Alternatives**: Add a `MAINNET_RPC_URL` secret to the CI test step, or exclude the suite in CI with `--no-match-path`, in a follow-up.

---
## Review Results
**Review Date**: 2026-10-06T23:59:05Z
**Review Command**: review-work yield-claim-nft 52
**Review Status**: ISSUES_FOUND
**Full Report**: See detailed report at: scratchpad/analysis-reports/story-052-yield-claim-nft-review-report-2026-10-06T235905Z.md

### Executive Summary
All four validators passed. The escrow delivers the custody guarantee: every outflow goes to an immutable protocol address, and no function takes a recipient. Tests pass: escrow suite 37/37, fork 4/4 on mainnet, full suite 709/709. One medium finding remains: the Follow-ups do not tell phStaging2:103 where to deploy the escrow (after core step 3), what to do with the step 2 skim (drop it), or that minAmountsOut must cover the combined ~20,401.8 + 202.30 BPT.

### Key Findings
- Base Commit: Valid. 267660b is the sprint tip before 052, and 052 is the only story in review.
- File Changes: Exactly the 4 listed files. No existing src, config or CI changes. The one post-RED test edit makes an assertion stricter.
- Claims: Verified. The unticked fmt/sizes item is justified because the failures predate this story.
- Purpose: Aligned. No path leads to the operator or any EOA.
- Other findings, all LOW or INFO:
  - The canonical pair can be blocked by a synced donation or a first mint, which DoS-es the cutover but cannot redirect funds. Raise with the auditor.
  - Losing the operator key strands escrow funds.
  - The fork test does not cover the owner's 202.30 BPT transfer in.
  - CI goes red on the fork suite, and this is not listed under Required Human Action.
  - There is no rescue for tokens outside the four.
  - The seed price is inherited from the Balancer ratio.

### Autonomous Decisions
- **Status choice.** Situation: every validator returned PASSED or ALIGNED, but sanity-check raised a MEDIUM finding about under-specified phStaging2 follow-ups. Decision: ISSUES_FOUND. Rationale: the review must not soften a finding, and triage or the human decides what blocks. Alternative: PASSED with notes.
- **Report location.** Situation: the report exceeds 5KB, and the scratchpad root is off-limits. Decision: write it to the gitignored `scratchpad/analysis-reports/`. Alternative: `scratchpad/planning-docs/`, which is tracked.
---

## Review Fixes (2026-10-07)

Documentation-only amendments made in response to the 2026-10-06 review. No code, checkboxes, status or metadata changed.

- **MEDIUM (under-specified phStaging2 follow-ups), fixed in Follow-ups and in phStaging2:103:**
  - The escrow is deployed after core step 3 (UniPoolerV2 plus its canonical pair) and before step 4 (`withdrawBPT`), because the constructor reads `newPooler.pair()`.
  - Step 2 drops the skim entirely and only asserts that the pair is empty. The skim to `newPooler` happens inside `exitAndSeed`.
  - `minAmountsOut` is checked on the escrow's combined BPT balance, after the owner -> escrow transfer.
  - Verified against `script/helpers/UniPoolerCutoverCore.sol` in the phStaging2 Balancexit worktree. The step numbering matches the review. The live-share check (`_checkMinAmountsOut`) currently runs in step 5, not step 0, and the wording says so.
- **LOW (fork-test gap), fixed:** phStaging2:103 gains an unticked checklist item. Its fork test must exercise the owner's real BPT transfer into the escrow and `minAmountsOut` over the combined balance. Mirrored in Follow-ups.
- **LOW (red CI fork job not listed), fixed:** added item 3 to Required Human Action On Completion.
- **Accepted / for the auditor, no change:**
  - Canonical-pair griefing before `exitAndSeed` (a synced donation or a first mint) is pre-existing. It is DoS only, because `abort()` returns funds to the old pooler. Raise it with the auditor.
  - Losing the operator key strands escrow funds. This is the human's design choice (immutable operator, not Ownable).
  - There is no general rescue for arbitrary airdropped tokens outside the four handled tokens (INFO).
  - The seed price is inherited from the Balancer pool ratio, about 18,656 sUSDS : 22,456 phUSD at the fork block. The human should confirm the resulting phUSD price before phStaging2:103 runs.
