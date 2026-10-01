# Story intents — yield-claim-nft run 20

Produced by project-manager `get_story_intent` (read-only). Audited range in `yield-claim-nft/src`:
`d4cc563264c7d57cf4c22e9ba561743484a305cd..2bfa0905b30a10dafcfd8944dad3503b3b802d18` (submodule on `master`; the
`sprint/Balancexit` commits are on `origin/master`). storyDir for yield-claim-nft = `yield-claim-nft`; for
phoenix-nft-staking = `nft-staking` (verified against `~/code/product-owner/registered-project-list.md`).

## Resolution table

| Tag | Governs | Story doc | State | Notes |
|---|---|---|---|---|
| story-048 | `src/dispatchers/UniPoolerV2.sol` (new), `IUniswapV2Pair` | `~/code/product-owner/stories/yield-claim-nft/auto-complete/yield-claim-nft-Balancexit/048-unipoolerv2-uniswap-v2-zap-pooler.md` | auto-complete (machine-approved, not human-reviewed) | 1 hit, unambiguous |
| story-049 | `src/dispatchers/PromotionUniV2_Eth.sol` Leg A | `~/code/product-owner/stories/yield-claim-nft/auto-complete/yield-claim-nft-Balancexit/049-promotion-univ2-eth-leg-a-uniswap-v2.md` | auto-complete (review status ISSUES_FOUND, cosmetic, polished in 2bfa090) | 1 hit, unambiguous |
| story-029 (pin bump) | `lib/phoenix-nft-staking` d75229d→5015f1b + `foundry.toml` remapping `yield-claim-nft/=src/` | `~/code/product-owner/stories/nft-staking/complete/multi-token-nudge/029-payment-token-as-nudge-token-budget-tracking.md` | complete (2026-07-25) | **Number collision:** the yield-claim-nft tree ALSO has a story-029 (`complete/yield-claim-nft-hook/029-dispatcher-v2-hook-mechanism.md`, the 2026-04 dispatch-hook mechanism). The bump commit 9c18020 has no `[story-NNN]` subject prefix; its subject says "phoenix-nft-staking ... story-029 budget-tracked refund", and the body matches the nft-staking story exactly. Resolved to the nft-staking story; the ycn-029 hit is unrelated. |
| story-043 | `src/dispatchers/NudgeRatchetDelayRelease.sol` (introduced f46a5cb, 2026-06-27, its only commit; never scanned before) | `~/code/product-owner/stories/yield-claim-nft/complete/yield-claim-nft-ratchet/043-nudge-ratchet-delay-release-dispatcher.md` | complete | 1 hit. Commit predates the range — it is in scope because it was never scanned, not because it changed. |

No story is in `incomplete/` or `review/`. Both new-contract stories (048, 049) sit in `auto-complete`: no human review happened.
Both carry a Required Human Action: **neither UniPoolerV2 nor PromotionUniV2_Eth may be deployed before this audit passes**
(this audit is half of phStaging2:103's `stage1-audit` gate).

## Commits in range (subject + body)

```
=== 2bfa0905b30a10dafcfd8944dad3503b3b802d18  (Thu Oct 1 10:54:13 2026 +0200)
[story-049] Polish: correct stale RPC-fallback comment in PromotionUniV2_Eth setUp

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>

=== a4d80f43f4994da05be859928d2e34b0777b13c0  (Thu Oct 1 10:50:52 2026 +0200)
[story-049] Rewrite PromotionUniV2_Eth Leg A to swap through the phUSD/sUSDS Uniswap V2 pair

Replace the Balancer V3 unlock/swap/settle/sendTo swap with Router02
swapExactTokensForTokens along [sUSDS, phUSD]. Remove BALANCER_VAULT,
BALANCER_POOL, unlockCallback, the IUnlockCallback inheritance and all
balancer interface imports. minPhusdOut must now be non-zero.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>

=== 157ba209008d2efacc2fc96c888077fa056f426a  (Thu Oct 1 10:50:06 2026 +0200)
[story-049] Add failing Leg A Uniswap V2 tests for PromotionUniV2_Eth

Seed the phUSD/sUSDS V2 pair on the fork, assert Leg A swaps through it,
honours minPhusdOut at the exact boundary and rejects a zero floor; skip
the fork suite cleanly when no archive RPC is configured.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>

=== f1670aba72d9d334d670e2238069e0425d5062fc  (Thu Oct 1 10:45:54 2026 +0200)
[story-048] Polish: silence false-positive unsafe-typecast lint in MockUniV2Amm

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>

=== 24862325040b70add3ecb771334af14918f7d3ff  (Thu Oct 1 10:42:12 2026 +0200)
[story-048] Add UniPoolerV2: Uniswap V2 zap replacement for BalancerPoolerV2

- UniPoolerV2 keeps BalancerPoolerV2's mint path (_dispatch/_psmDonate) verbatim,
  donation setters, authorized-pooler versioning and rescueERC20 (also the LP exit)
- pool(sUSDSIn, minPhusdOut, minLP) derives the swap amount on-chain from live
  reserves (closed-form 0.30%-fee zap), LP stays on the pooler; no price ceiling
- quotePool(sUSDSIn) view for the UI floors
- IUniswapV2Pair gains getReserves()/totalSupply()
- Tests: dust table + fuzz, front-run floors, empty pair, zero floors, auth,
  ported BalancerPoolerV2 dispatch/donation suite, mainnet fork vs Router02

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>

=== c43d1a9cd12ed2e5b3d14fb8479b79057b910304  (Thu Oct 1 10:37:23 2026 +0200)
[story-048] Add failing UniPoolerV2 tests

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>

=== 9c180204d262955f34b6d9b80e69febec0e9c400  (Sun Jul 26 02:46:16 2026 +0200)
Bump phoenix-nft-staking to 5015f1b (story-029 budget-tracked refund)

Pulls in the story-029 work on BatchNFTMinterMultiToken: the caller's credit
is now measured across the pull instead of trusting paymentAmount, making
paymentToken-as-nudge-token safe, plus the accompanying invariant and
boundary regression suites.

Also adds a "yield-claim-nft/=src/" remapping. phoenix-nft-staking's own
remappings.txt resolves that prefix to its uninitialised
lib/mutable/yield-claim-nft copy, which this repo does not vendor; pointing
it at our own src/ lets a clean checkout build without extra setup.

forge clean && forge build && forge test: 542 passed, 0 failed.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>

```

### Touched files per commit
```
--- 2bfa0905b30a10dafcfd8944dad3503b3b802d18
M	test/PromotionUniV2_Eth.t.sol
--- a4d80f43f4994da05be859928d2e34b0777b13c0
M	foundry.toml
M	src/dispatchers/PromotionUniV2_Eth.sol
M	test/PromotionUniV2_Eth.t.sol
--- 157ba209008d2efacc2fc96c888077fa056f426a
M	test/PromotionUniV2_Eth.t.sol
--- f1670aba72d9d334d670e2238069e0425d5062fc
M	test/mocks/MockUniV2Amm.sol
--- 24862325040b70add3ecb771334af14918f7d3ff
A	src/dispatchers/UniPoolerV2.sol
M	src/interfaces/uniswap/IUniswapV2Pair.sol
M	test/UniPoolerV2.fork.t.sol
M	test/UniPoolerV2.t.sol
M	test/mocks/MockUniV2Amm.sol
--- c43d1a9cd12ed2e5b3d14fb8479b79057b910304
A	test/UniPoolerV2.fork.t.sol
A	test/UniPoolerV2.t.sol
A	test/mocks/MockUniV2Amm.sol
--- 9c180204d262955f34b6d9b80e69febec0e9c400
M	foundry.toml
M	lib/phoenix-nft-staking
```

### Introducing commit for NudgeRatchetDelayRelease.sol (out of range, never scanned)
```
f46a5cb7a90726215d49619ce76cb297f56e290a  (Sat Jun 27 09:47:21 2026 +0200)
[story-043] Add NudgeRatchetDelayRelease dispatcher + tests

Sibling of NudgeRatchet that HOLDS USDC on _dispatch (no transfer),
adds a releasers whitelist (setReleaser), an onlyReleaser-gated
release(amount) forwarding held USDC to batchMinter, and an owner
rescueERC20 escape hatch. Mint-debt logic unchanged via the base hook.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>


A	src/dispatchers/NudgeRatchetDelayRelease.sol
A	test/NudgeRatchetDelayRelease.t.sol
```

## Cross-cutting design context

- `yield-claim-nft/src/docs/` does **not exist**. `src/CLAUDE.md` is generic (TDD, dependency layout, remappings); it contains nothing contract-specific. Note it lists only three remappings — the `yield-claim-nft/=src/` remapping added by 9c18020 is not reflected there.
- `src/README.md` exists (not story-specific).
- The authoritative design doc for 048/049 is **external**: phStaging2 `docs/BalancerWinddownPlan.md` (`git -C ~/code/reflax-mint/phase-2-staging show master:docs/BalancerWinddownPlan.md`, 513 lines). Relevant sections are reproduced verbatim below.
- The authoritative spec for nft-staking 029: `/home/justin/code/audits/docs/phoenix-nft-staking-payment-token-as-nudge-token-plan.md` (audit-side copy).
- **Plan vs story divergence (flag for faithfulness):** plan Stage 2 step 7 says "Register with the Pauser" for UniPoolerV2; story 048 Concerns says *Do NOT add a `pauser()`* (dispatchers have none; phStaging2:100 records skipping Pauser registration). Plan's test "Dispatch still works while the pooler is paused" contradicts `ATokenDispatcherV2.dispatch` being `whenNotPaused`; story 048 reinterprets it as "dispatch works while `pool()` is unavailable" (Autonomous Decision 5).
- Owner-memory context relevant to 029: `payment-token-as-nudge-token-decision` (collision permitted 2026-07-25; same-denomination arbitrage accepted; ycn19h1 + ad36260f fix-pending).

### BalancerWinddownPlan.md — §2.2 PromotionUniV2_Eth row, §4 Stage 1a, 1d, Stage 2, §5, §6 (verbatim)

### 2.2 Contracts

| Contract | Deployed? | Balancer dependency | Breaks on 30 Oct? | Action |
|---|---|---|---|---|
| `BalancerPoolerV2` (`lib/yield-claim-nft/src/dispatchers/BalancerPoolerV2.sol`), index 4, `0x7f68…11F1` | Live | `pool()` → `vault.unlock` → `addLiquidity(UNBALANCED)`. `getIdealBPT()` → Router query. `withdrawBPT()` | **`pool()` and `getIdealBPT()` only.** `_dispatch` (the mint path) touches only sUSDS `deposit` and the Sky PSM | Stop pooling. Exit the BPT. Replace the dispatcher at index 4 (section 4) |
| `BalancerPoolerMintDebtHook` `0x4A26…8bD7` | Live | None. The name is historical: it accrues phUSD mint debt on dispatch (ratio 50, recipient `NFTStaker` `0xc851…a13b`, debt currently 0) | No | Repoint to the new dispatcher with `setDispatcher` (no redeploy) |
| `NFTStaker` / `NFTStakerPriceScaled*` (`lib/nft-staking`) | Live | Imports the `IBalancerPoolerMintDebtHook` *interface* only (`pull()`, `mintDebt()`). It doesn't read Balancer or any price | No | None |
| `PromotionUniV2_Eth` (`lib/yield-claim-nft/src/dispatchers/PromotionUniV2_Eth.sol`) | **Not deployed** | Leg A hardcodes `BALANCER_VAULT` and `BALANCER_POOL` as constants and swaps sUSDS→phUSD through `vault.unlock/swap/settle/sendTo` | Would revert on its first `pool()` | Rewrite Leg A for the new venue **before** it is ever deployed |
| `Uniboost` EYE/SCX/FLX, indices 1/2/3 | Live | None. The comments cite `BalancerPoolerV2` as a design ancestor. These already zap into Uniswap V2 (factory `0x5C69…aA6f`) | No | None. **This is the template for the replacement** |
| `NudgeRatchetDelayRelease`, `MintPageView` | Live / superseded | Comments only | No | Refresh comments whenever a file is next touched |

**Why the mint path survives.** Dispatch only wraps and optionally donates:

```solidity
// BalancerPoolerV2._dispatch — no Balancer call anywhere in the mint path
if (poolingUSDS > 0) {
    IERC20(_primeToken).forceApprove(_sUSDS, poolingUSDS);
    IERC4626(_sUSDS).deposit(poolingUSDS, address(this));
}
if (donationEnabled) { ... try this._psmDonate(remainingUSDS) {} catch { ... } }
```

The live donation is currently disabled: `batchDonationSize == 0`, while `psm`, `batchMinter`, `nudgeStreamer` and `maxTout = 1%` are all set. The pooler holds 0 sUSDS and 4.7e-7 USDS of dust.


### Stage 1: Contracts, dress rehearsal, addresses, audit

#### 1a. `UniPoolerV2` (working name) in `yield-claim-nft`, TDD

It is `BalancerPoolerV2` with the Balancer parts removed and a Uniswap V2 zap in their place.

**What is kept:**
- The `_dispatch` override copied **verbatim**: the USDS→sUSDS wrap, the PSM donation through `NudgeStreamer`, and the `try/catch` isolation.
- Every donation setter, the authorized-pooler versioning, `rescueERC20` (which is also the LP exit), and `primeToken() == USDS`. The hook, NFT id and minter all see an identical dispatcher.

**What is removed:** `IUnlockCallback`, `unlockCallback`, `getIdealBPT`, `withdrawBPT`, and the vault and router immutables.

**What is new:**
- Immutables `_router` (Uniswap V2 Router02 `0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D`) and `_pair`. The constructor validates that `{pair.token0, pair.token1} == {sUSDS, phUSD}`.
- `pool(uint256 sUSDSIn, uint256 minPhusdOut, uint256 minLP)`, and the view `quotePool(uint256 sUSDSIn) returns (uint256 swapIn, uint256 phusdOut, uint256 expectedLP)`.

**The efficiency requirement is met by computing the swap amount on-chain.** The contract reads the pair's reserves at execution time and derives the exact swap from them:

```solidity
// r = live sUSDS reserve read inside pool(), a = sUSDSIn, 0.30% fee:
//   s = (sqrt(r * (r * 3988009 + a * 3988000)) - r * 1997) / 1994
// Swapping s leaves (a - s) sUSDS and phusdOut phUSD in exactly the post-swap reserve ratio,
// so addLiquidity consumes both sides with at most wei-level rounding dust.
```

**Why it can't be sized off-chain.** If the UI computed the swap amount itself, any price movement between quote and execution would leave one side over-supplied, and the router would refund the surplus. Deriving `s` from the reserves the swap actually executes against removes that failure mode entirely:
- A front-run changes `s` and the price we buy at, but not the leftover, which stays near zero.
- The worst the front-run can do is make us buy at a worse price, and that is what the slippage parameters bound.

**The UI's job** is to call `quotePool(sUSDSIn)` and then call `pool(sUSDSIn, minPhusdOut, minLP)`:
- `minPhusdOut` and `minLP` are `quotePool`'s outputs reduced by a tolerance.
- The UI never passes `s`.

**Configuration Safety:**
- `minPhusdOut` and `minLP` must be non-zero.
- There is **deliberately no price ceiling.** Pooling that pushes phUSD above the $1 mint price is intended: arbitrageurs then mint phUSD through `PhusdStableMinter` and sell it into the pair, and every such mint adds collateral to the yield strategies, which grows protocol-owned yield.

**Tests:**
- The zap consumes both sides to within dust across a range of reserve sizes and `sUSDSIn` values.
- A front-run reserve shift reverts on `minPhusdOut` or `minLP`, and never strands a refund.
- `pool()` reverts on an empty pair.
- Dispatch still works while the pooler is paused.
- The donation branch passes the existing `BalancerPoolerV2` dispatch suite unchanged.
- A mainnet-fork test runs against the real V2 router.

`PromotionUniV2_Eth` Leg A gets the same treatment in the same stage: replace the Balancer swap with a V2 `swapExactTokensForTokens(sUSDS→phUSD)`. It isn't deployed, so there's nothing to migrate.


#### 1d. Audit

**Audit** the new contracts plus the `DeployMocks` rehearsal. For consistency with previous stories, use the audit pipeline (code-scanner/econ-scanner on the contracts, script-auditor on the rehearsal).

**UI adjustments are out of scope for this project.** Their order relative to these stages is in section 7.

### Stage 2: Mainnet cutover npm keys, then audit

This is a new `script/DeployMainnetUniPoolerCutover.s.sol`. It carries the usual npm keys:

| npm key | Purpose |
|---|---|
| `unipooler-cutover:preview` | Fork simulation |
| `unipooler-cutover:broadcast` | Ledger broadcast. Not prefixed with the preview |
| `unipooler-cutover:verify` | Post-broadcast checks |

The script uses a progress file, `progress.unipooler-cutover.1.json`. **A crash mid-broadcast poisons the progress file**, so resume from receipts, not from the progress file.

**Ordering and preconditions.** The sequence below is the same one the Stage 1 rehearsal runs:

0. **Preconditions** (all `require`d):
   - The pooler's authorized-pooler set is revoked.
   - The pair doesn't exist, or its reserves are `(0,0)`.
   - Every configuration value is read live.
1. **Deploy `UniPoolerV2`,** but don't wire it in yet.
2. **Take the BPT out:** `BalancerPoolerV2.withdrawBPT(OWNER, fullBalance)`.
3. **Proportional exit:**
   - Before 30 Oct: `removeLiquidityProportional`.
   - After 30 Oct: `removeLiquidityRecovery`.
   - `minAmountsOut` is the live proportional share minus a tight tolerance. It is never 0.
4. **Seed the pair in one atomic helper call.** The helper runs `addLiquidity` with **all** the recovered sUSDS and phUSD, with `to = UniPoolerV2`. The proportional exit returns tokens in exactly the Balancer pool's reserve ratio, so seeding with both amounts carries the existing price over unchanged and leaves nothing behind (decision 3). Doing it in one call means the new price can't be sandwiched between creating the pair and the first add.
5. **Clean the hook ledger:** `BalancerPoolerMintDebtHook.pull()`.
6. **Repoint the hook:** `hook.setDispatcher(UniPoolerV2)`, then `UniPoolerV2.setHook(hook)`.
7. **Configure `UniPoolerV2`:**
   - `setMinter(NFTMinterV2)`. `replaceDispatcher` doesn't wire this, and without it index 4 bricks.
   - The PSM, `maxTout`, `batchMinter`, `nudgeStreamer` and `batchDonationSize` values, each copied live from the old pooler.
   - `setAuthorizedPooler` for the same four poolers as today (owner, `MultiPooler`, `0x186c…a77F`, `0x6309…d476`).
   - Register with the Pauser.
8. **Swap the dispatcher:** `NFTMinterV2.replaceDispatcher(4, UniPoolerV2)`.
9. **Move leftovers:** `BalancerPoolerV2.rescueERC20(sUSDS, UniPoolerV2, balance)` for sUSDS accrued since the holding pattern began, plus a USDS dust sweep.
10. **Retire the old pooler:** pause it and unregister it from the Pauser.
11. **Verify:**
    - `configs(4).dispatcher` is the new pooler.
    - `hook.dispatcher()` is the new pooler.
    - The pair's reserves match what was seeded.
    - The new pooler holds the LP.
    - A forked test mint dispatches, wraps and accrues debt.
    - A `pool()` preview with `quotePool` floors succeeds.

**Audit:** run script-auditor on the cutover (fork preview, intent conformance, side effects) before Stage 3 starts.

**Minimum viable fallback.** If Stages 1–2 slip past 30 October, nothing breaks and nothing is lost. Mints keep accruing sUSDS on `BalancerPoolerV2`. The BPT can still be recovered through `removeLiquidityRecovery`, and step 3 already allows for that.


## 5. The pooling strategy: single-sided add vs buy-and-pool vs donation

**On a 50/50 constant-product pool, all three ways of committing Δ sUSDS lift the price by the same amount.** Only who owns the result differs.

Take reserves `X` sUSDS-value and `Y` phUSD, with spot price `p = X / Y`:

| Method | Resulting reserves | New price | LP minted to us | Leakage |
|---|---|---|---|---|
| Balancer single-sided add (today) | `(X+Δ, Y)` | `(X+Δ)/Y` | Yes (BPT for Δ, minus swap fee on the implied imbalance) | Implied swap fee, mostly back to LPs (us) |
| **Buy-and-pool zap** (swap `s`, add rest) | `(X+Δ, Y)` (swap moves `s` in and `phUSD` out, then the add returns that phUSD) | `(X+Δ)/Y` | **Yes** (LP for the whole Δ, minus 0.3% on `s`) | 0.3% on `s ≈ Δ/2`. 5/6 of that accrues to LPs (≈ us), 1/6 to the Uniswap fee switch |
| Donation (`transfer` + `sync()`) | `(X+Δ, Y)` | `(X+Δ)/Y` | **No.** Value spreads pro-rata to all LP holders | ~1/6 of Δ to Uniswap `feeTo` at the next mint/burn (via the `√k` growth rule). Any non-protocol LP share also leaks. Sandwichable without a pre-check |

**Worked example at today's reserves** (X ≈ 33,804, Y ≈ 34,817, p ≈ 0.971):

| Δ (USDS value in sUSDS) | Price after |
|---|---|
| 250 | 0.978 |
| 500 | 0.985 |
| 1,000 | 0.9996 |

**The zap is the right choice.** It reproduces the current strategy's price-and-depth effect exactly, and the protocol keeps ownership of everything it adds. It is also the "protocol tokens approach" `Uniboost` already runs for EYE, SCX and FLX, so it is the design you suggested.

**Why not donate:**
- **Fee leak:** with the V2 fee switch live, a donation leaks about 1/6 of its value to Uniswap.
- **Sandwich exposure:** a searcher buys phUSD first, lets the donation lift the price, and sells into it. They capture about `Δ·a/(X+a)` for a front-run of size `a`, which is profitable once Δ exceeds roughly 0.6% of pool depth. At today's size that is about $200–400.
- **Mitigation, if ever needed:** a reserve-ratio pre-check makes donation safer. It still loses the 1/6 to the fee switch.
- **Uniswap V4's `donate()` is a different thing entirely:** it pays in-range LPs as fees and doesn't move the price at all.

**Pushing through the mint price is intended.**
- **The pool is shallow:** about $1k of sUSDS moves phUSD from 0.971 to peg, so a modest `pool()` can lift the price above $1.
- **Why that's wanted:** above $1, arbitrageurs mint phUSD 1:1 through `PhusdStableMinter` and sell it into the pair. Every such mint adds collateral to the yield strategies, and more collateral means more protocol-owned yield.
- **Consequence:** the pooler has no price ceiling. Only `minPhusdOut` and `minLP` bound each call, and they exist to stop sandwiches, not to cap price.

**Arbitrage doesn't need another phUSD venue.** The mint-and-sell loop runs through `PhusdStableMinter`, the pair, the sUSDS redeem and the Sky PSM, so it works even if we are the only phUSD liquidity on Uniswap V2.

## 6. Decisions and open questions

### Extension decision
**Recommendation: do not apply for the 30 Nov extension.**
- We need Balancer only for a proportional exit, and that stays available after 30 Oct through `removeLiquidityRecovery`.
- Our $16/day of volume doesn't justify asking Balancer to keep the pool running.
- Applying anyway would keep the swap route alive four weeks longer as a safety margin. That is worth it only if the Stage 4 cutover can't happen before 30 Oct.

### Decisions (2026-10-01)

| # | Question | Decision |
|---|---|---|
| 1 | Who owns the `0xc65f…e8db` LP (37%)? | Known to the owner, who will contact them directly |
| 2 | Uniswap V2 or Uniswap V4 hookless full-range? | **Uniswap V2**, 0.30% fee. V4 stays the fallback if routing to the V2 pair proves poor (see [3.4](#34-uniswap-v2-vs-uniswap-v4-hookless-full-range)) |
| 3 | Seeding price | Carry over the existing Balancer price |
| 4 | Recovered phUSD: re-pool or burn? | Moot. Carrying the price over re-pools all of it, because the proportional exit already returns tokens at that price ratio |
| 5 | LP custody | The new pooler contract |
| 6 | Pooler key | Keep both `BalancerPooler` and `UniPooler` until the wind-down is confirmed complete, then remove the old key and the Balancer keys |
| 7 | Authorized poolers | Re-authorize the same four on the new pooler |
| 8 | UI story | Out of scope for this project |



---

# FULL STORY DOCUMENT — story-048

Path: `/home/justin/code/product-owner/stories/yield-claim-nft/auto-complete/yield-claim-nft-Balancexit/048-unipoolerv2-uniswap-v2-zap-pooler.md`

## UniPoolerV2: Uniswap V2 zap replacement for BalancerPoolerV2 (TDD)

Current Sprint: 22
Base Commit: f1670aba72d9d334d670e2238069e0425d5062fc
Execution Type: new_worktree
Base Commit Updated: 2026-10-01T08:47:02Z

### ⚠️ Required Human Action On Completion

UniPoolerV2 is a new contract. It will be covered by the **yield-claim-nft project audit**, which the human runs after story 049 concludes. Contract changes in yield-claim-nft are audited with this project, not through phStaging2. Until that audit passes, UniPoolerV2 MUST NOT be deployed to mainnet.

### Story Overview

The Balancer V3 pool that `BalancerPoolerV2` (index 4, mainnet `0x7f6874332c4629429d70D15f685A8230323F11F1`) pools into is being wound down: pools are paused on 30 Oct 2026 and the V3 Vault is paused on 30 Nov 2026. This story builds the replacement dispatcher, `UniPoolerV2`, test-first.

`UniPoolerV2` is `BalancerPoolerV2` with the Balancer parts removed and a Uniswap V2 zap into a phUSD/sUSDS V2 pair put in their place. The mint path (`_dispatch`) is kept verbatim, so the NFT minter, the mint-debt hook and NFT index 4 all see an identical dispatcher.

Repo: `~/code/reflax-mint/yield-claim-nft` (product-owner project `yield-claim-nft`). Paths below are relative to the sprint worktree `worktrees/yield-claim-nft/Balancexit/` (branch `sprint/Balancexit`).

Source plan: `docs/BalancerWinddownPlan.md` §4 Stage 1a, in **phStaging2** (`~/code/reflax-mint/phase-2-staging`, master `3943ae3 "Balancexit plan"`). Read it with `git -C ~/code/reflax-mint/phase-2-staging show master:docs/BalancerWinddownPlan.md`. The relevant text is copied below.

This is the first story of the Balancexit plan. Downstream stories are yield-claim-nft 049 and phStaging2 100–107.

### Background

#### Plan §4 Stage 1a (verbatim)

> It is `BalancerPoolerV2` with the Balancer parts removed and a Uniswap V2 zap in their place.
>
> **What is kept:**
> - The `_dispatch` override copied **verbatim**: the USDS→sUSDS wrap, the PSM donation through `NudgeStreamer`, and the `try/catch` isolation.
> - Every donation setter, the authorized-pooler versioning, `rescueERC20` (which is also the LP exit), and `primeToken() == USDS`. The hook, NFT id and minter all see an identical dispatcher.
>
> **What is removed:** `IUnlockCallback`, `unlockCallback`, `getIdealBPT`, `withdrawBPT`, and the vault and router immutables.
>
> **What is new:**
> - Immutables `_router` (Uniswap V2 Router02 `0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D`) and `_pair`. The constructor validates that `{pair.token0, pair.token1} == {sUSDS, phUSD}`.
> - `pool(uint256 sUSDSIn, uint256 minPhusdOut, uint256 minLP)`, and the view `quotePool(uint256 sUSDSIn) returns (uint256 swapIn, uint256 phusdOut, uint256 expectedLP)`.
>
> **The efficiency requirement is met by computing the swap amount on-chain.** The contract reads the pair's reserves at execution time and derives the exact swap from them:
>
> ```solidity
> // r = live sUSDS reserve read inside pool(), a = sUSDSIn, 0.30% fee:
> //   s = (sqrt(r * (r * 3988009 + a * 3988000)) - r * 1997) / 1994
> // Swapping s leaves (a - s) sUSDS and phusdOut phUSD in exactly the post-swap reserve ratio,
> // so addLiquidity consumes both sides with at most wei-level rounding dust.
> ```
>
> **Why it can't be sized off-chain.** If the UI computed the swap amount itself, any price movement between quote and execution would leave one side over-supplied, and the router would refund the surplus. Deriving `s` from the reserves the swap actually executes against removes that failure mode entirely:
> - A front-run changes `s` and the price we buy at, but not the leftover, which stays near zero.
> - The worst the front-run can do is make us buy at a worse price, and that is what the slippage parameters bound.
>
> **The UI's job** is to call `quotePool(sUSDSIn)` and then call `pool(sUSDSIn, minPhusdOut, minLP)`:
> - `minPhusdOut` and `minLP` are `quotePool`'s outputs reduced by a tolerance.
> - The UI never passes `s`.
>
> **Configuration Safety:**
> - `minPhusdOut` and `minLP` must be non-zero.
> - There is **deliberately no price ceiling.** Pooling that pushes phUSD above the $1 mint price is intended: arbitrageurs then mint phUSD through `PhusdStableMinter` and sell it into the pair, and every such mint adds collateral to the yield strategies, which grows protocol-owned yield.
>
> **Tests:**
> - The zap consumes both sides to within dust across a range of reserve sizes and `sUSDSIn` values.
> - A front-run reserve shift reverts on `minPhusdOut` or `minLP`, and never strands a refund.
> - `pool()` reverts on an empty pair.
> - Dispatch still works while the pooler is paused.
> - The donation branch passes the existing `BalancerPoolerV2` dispatch suite unchanged.
> - A mainnet-fork test runs against the real V2 router.

#### Why the mint path survives (plan §2.2)

```solidity
// BalancerPoolerV2._dispatch — no Balancer call anywhere in the mint path
if (poolingUSDS > 0) {
    IERC20(_primeToken).forceApprove(_sUSDS, poolingUSDS);
    IERC4626(_sUSDS).deposit(poolingUSDS, address(this));
}
if (donationEnabled) { ... try this._psmDonate(remainingUSDS) {} catch { ... } }
```

On mainnet the live donation is currently disabled: `batchDonationSize == 0`, while `psm`, `batchMinter`, `nudgeStreamer` and `maxTout = 1%` are all set.

#### Existing BalancerPoolerV2 surface (from exploration)

```solidity
constructor(address sUSDS_, address pool_, address vault_, address router_, bool sUSDSIsFirst_, address initialOwner) ATokenDispatcherV2(initialOwner)
_primeToken = IERC4626(sUSDS_).asset();  authVersion = 1;
function setAuthorizedPooler(address pooler, bool authorized) external onlyOwner
function incrementAuthVersion() external onlyOwner
function setBatchDonationSize(uint256) / setBatchMinter(address) / setPSM(address) / setMaxTout(uint256) / setNudgeStreamer(address)  // all onlyOwner
function _dispatch(address, uint256 amount, bytes calldata) internal override   // copy verbatim
function _psmDonate(uint256 usdsAmount) external   // require(msg.sender == address(this))
function rescueERC20(address token, address to, uint256 amount) external onlyOwner
// to remove: pool(uint256 minBPT), unlockCallback, getIdealBPT, withdrawBPT(address,uint256), setPool, vault()
```

Base class `ATokenDispatcherV2`:
- `setMinter(address)` and `setHook(IDispatchHook)` are `onlyOwner`.
- `pause()` and `unpause()` are `onlyMinter`.
- `dispatch(...)` is `nonReentrant onlyMinter whenNotPaused`.

#### Zap template: Uniboost (and how it differs)

`src/dispatchers/Uniboost.sol`:

```solidity
function pool(uint256 amountIn, uint256 minPairOut, uint256 minTargetOut, uint256 minLP) external onlyAuthorizedPooler whenNotPaused nonReentrant
```

Uniboost does `swapExactTokensForTokens`, then a naive `pairBal / 2` swap, then `addLiquidity(..., 0, 0, address(this), block.timestamp)` followed by `require(liquidity >= minLP)`. Copy its **shape** (approvals, router calls, modifiers), but NOT its half-split. The closed-form `s` is new logic: Uniboost splits in half and lets the router refund the leftover, which is exactly the failure mode this story removes.

### File Locations

| File | Change |
|---|---|
| `src/dispatchers/BalancerPoolerV2.sol` (441 lines) | Source to copy. Do NOT modify (live contract; deleted later in story 050) |
| `src/dispatchers/UniPoolerV2.sol` | NEW: copy of BalancerPoolerV2 with Balancer parts removed and the UniV2 zap added |
| `src/dispatchers/Uniboost.sol` | Reference only: zap shape for `pool(...)` |
| `src/dispatchers/ATokenDispatcherV2.sol` (base) | Reference only. Do NOT add guards here |
| `src/interfaces/uniswap/IUniswapV2Pair.sol` | Extend: add `getReserves()` and `totalSupply()` (it currently has only `token0()`/`token1()`) |
| `src/interfaces/uniswap/IUniswapV2Router02.sol` | Existing; use for `swapExactTokensForTokens`/`addLiquidity` (extend only if a needed selector is missing) |
| `test/UniPoolerV2.t.sol` | NEW, written first: unit tests and a port of the BalancerPoolerV2 dispatch suite |
| `test/UniPoolerV2.fork.t.sol` (or a fork contract inside `test/UniPoolerV2.t.sol`) | NEW: mainnet-fork test against the real Router02 |
| `test/BalancerPoolerV2.t.sol` | Existing "dispatch suite". Source of tests to port. Keep passing, do not modify |
| `test/PromotionUniV2_Eth.t.sol` | Reference only: the fork-test pattern (`MAINNET_RPC_URL`, pinned `FORK_BLOCK`, `UNIV2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f`) |

### Technical Details

**Constructor.** Takes `sUSDS_`, `router_` (UniV2 Router02), `pair_` (the phUSD/sUSDS V2 pair) and `initialOwner`, plus whatever else is needed to identify phUSD; deriving it from the pair is fine. Requirements:
- `{IUniswapV2Pair(pair_).token0(), token1()} == {sUSDS, phUSD}`, checked in either order, with a loud revert otherwise. Record which index is sUSDS (by analogy with `sUSDSIsFirst_`).
- `_primeToken = IERC4626(sUSDS_).asset()` (USDS), and `authVersion = 1`.
- The pair may legitimately be empty at construction, because the cutover deploys the pooler before seeding the pair. Do not require reserves in the constructor.

**Kept verbatim.** `_dispatch`, `_psmDonate`, `setBatchDonationSize`, `setBatchMinter`, `setPSM`, `setMaxTout`, `setNudgeStreamer`, `setAuthorizedPooler`, `incrementAuthVersion` (with `authVersion = 1` initial), the `onlyAuthorizedPooler` mechanism, `rescueERC20` (also the LP exit), and `primeToken() == USDS`. Keep all events, errors and storage semantics the dispatch suite relies on.

**Removed.** `IUnlockCallback` inheritance, `unlockCallback`, `getIdealBPT`, `withdrawBPT`, `setPool`, `vault()`, and the vault/router/pool Balancer immutables. UniPoolerV2 must not import anything from `src/interfaces/balancer/`.

**`pool(uint256 sUSDSIn, uint256 minPhusdOut, uint256 minLP)`** is `onlyAuthorizedPooler whenNotPaused nonReentrant`.
1. `require(minPhusdOut > 0 && minLP > 0)`, a loud custom-error revert. Zero minimums are forbidden.
2. Read the live reserves via `getReserves()` and select `r` = the sUSDS reserve. Revert on an empty pair (either reserve == 0).
3. `s = (sqrt(r * (r * 3988009 + a * 3988000)) - r * 1997) / 1994` with `a = sUSDSIn`. Use OpenZeppelin `Math.sqrt` (or an equivalent) and make sure the intermediate products cannot overflow for realistic values. Document the bound.
4. Swap `s` sUSDS → phUSD via `router.swapExactTokensForTokens(s, minPhusdOut, [sUSDS, phUSD], address(this), block.timestamp)`.
5. `router.addLiquidity(sUSDS, phUSD, a - s, phusdOut, …, address(this), block.timestamp)` with `to = address(this)`: the LP stays on the pooler (plan decision 5, "LP custody: the new pooler contract"). Then `require(liquidity >= minLP)`.
6. Reset or clean approvals as Uniboost does. Emit an event carrying `sUSDSIn`, `s`, `phusdOut` and `liquidity`.

**`quotePool(uint256 sUSDSIn) view returns (uint256 swapIn, uint256 phusdOut, uint256 expectedLP)`.** It uses the same formula against the current reserves, `getAmountOut` maths with the 0.30% fee for `phusdOut`, and `expectedLP` from the post-swap reserves and `totalSupply()` (`min(amount0 * ts / r0, amount1 * ts / r1)`). It reverts (or returns zeros, documented) on an empty pair.

**No price ceiling.** Do not add one (see Configuration Safety above).

### Implementation Notes

- **TDD:** write `test/UniPoolerV2.t.sol` first, watch it fail, then implement.
- **Unit tests** can use a local UniV2 deployment if the repo already has a helper for one; otherwise use the fork test for router behaviour and a minimal mock pair/router for the unit cases. Check how `test/Uniboost.t.sol` sets up UniV2 and reuse that approach.
- **Fork test:** follow `test/PromotionUniV2_Eth.t.sol`: `MAINNET_RPC_URL` env, a pinned `FORK_BLOCK`, a clean skip if unset, factory `0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f`, Router02 `0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D`. The phUSD/sUSDS pair does not exist on mainnet yet, so the test creates and seeds it (with `deal` for sUSDS `0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD` and phUSD `0xf3B5B661b92B75C71fA5Aba8Fd95D7514A9CD605`) before deploying UniPoolerV2 against it.
- **Guard at the concrete, not the base:** any new guard or modifier belongs on UniPoolerV2, never on `ATokenDispatcherV2`. Live dispatchers share the base.
- **Commits:** every commit is `[story-048] <message>`. Stage files by explicit path; never `git add -A` / `git add .`.

### Checklist

- [x] Write `test/UniPoolerV2.t.sol` FIRST (failing), covering every test below; commit it as `[story-048] Add failing UniPoolerV2 tests`.
- [x] Extend `src/interfaces/uniswap/IUniswapV2Pair.sol` with `getReserves() returns (uint112, uint112, uint32)` and `totalSupply() returns (uint256)`.
- [x] Create `src/dispatchers/UniPoolerV2.sol` from `BalancerPoolerV2.sol`: keep `_dispatch` and `_psmDonate` verbatim, keep every donation setter, the authorized-pooler versioning (`authVersion = 1`), `rescueERC20` and `primeToken() == USDS`; remove `IUnlockCallback`, `unlockCallback`, `getIdealBPT`, `withdrawBPT`, `setPool`, `vault()` and the Balancer immutables; confirm with `grep -n -i balancer src/dispatchers/UniPoolerV2.sol` that only comments remain at most.
- [x] Add immutables `_router` and `_pair`; the constructor reverts unless `{token0, token1} == {sUSDS, phUSD}` (test both orders and a wrong-token pair).
- [x] Implement `pool(sUSDSIn, minPhusdOut, minLP)` (`onlyAuthorizedPooler whenNotPaused nonReentrant`) with on-chain closed-form `s` from live reserves, swap, then `addLiquidity` `to = address(this)` and `require(liquidity >= minLP)`; no price ceiling.
- [x] Implement the view `quotePool(sUSDSIn) returns (swapIn, phusdOut, expectedLP)`.
- [x] Test: the zap consumes both sides to within dust (assert the pooler's leftover sUSDS and phUSD after `pool()` are wei-level) across a table of reserve sizes and `sUSDSIn` values (small/large `a` relative to `r`, skewed reserves).
- [x] Test: a front-run reserve shift between `quotePool` and `pool()` reverts on `minPhusdOut` or `minLP`, and no refund is ever stranded on the pooler.
- [x] Test: `pool()` reverts on an empty pair (reserves 0,0).
- [x] Test: `pool()` reverts when `minPhusdOut == 0` or `minLP == 0`.
- [x] Test: `pool()` reverts for an unauthorized caller, and for all previously authorized poolers after `incrementAuthVersion()`.
- [x] Test: dispatch (the mint path via the minter) still works while `pool()` is unavailable (empty pair, or pooling reverting), with wrap and donation behaviour unchanged. See Concerns for why this is not "while paused".
- [x] Port the dispatch/donation tests from `test/BalancerPoolerV2.t.sol` to target UniPoolerV2 and confirm they pass unchanged in substance (same assertions, only the deployment target differs).
- [x] Mainnet-fork test against the real Router02 `0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D`: create and seed the phUSD/sUSDS pair, deploy UniPoolerV2, then run `quotePool` then `pool()` with the floors; it skips cleanly when `MAINNET_RPC_URL` is unset.
- [x] `forge build` passes with no new warnings in UniPoolerV2.
- [x] `forge test` passes (full suite, including the untouched `test/BalancerPoolerV2.t.sol`), and `MAINNET_RPC_URL=<rpc> forge test --match-contract UniPoolerV2` passes, including the fork test.
- [x] All commits use `[story-048] <message>` and stage files by explicit path; the worktree is clean at the end.
- [x] Final step: end your execution summary with a clearly marked block headed "⚠️ HUMAN ACTION REQUIRED" that restates the Required Human Action On Completion section verbatim, so the user is alerted. Do not perform the action yourself and do not mark it as done.

### Concerns

- **The plan's test "Dispatch still works while the pooler is paused" contradicts the code.** `ATokenDispatcherV2.dispatch` is `whenNotPaused`, so dispatch cannot work while the pooler is paused. The test is interpreted as "dispatch still works while the Balancer pool / `pool()` is unavailable". Implement it that way and record the interpretation as an Autonomous Decision.
- **Do NOT add a `pauser()`** to make the dispatcher Pauser-registrable. That is out of scope. `Pauser.register` requires `IPausable(c).pauser() == Pauser`, dispatchers have none, and no prior dispatcher cutover registered one. phStaging2 story 100 records the cutover decision to skip Pauser registration.
- **Guard at the concrete, not the base.** All new guards go on UniPoolerV2; never touch `ATokenDispatcherV2`.
- **`BalancerPoolerV2.sol` stays untouched.** It is the live mainnet contract, and phStaging2's rehearsal (101) still deploys it. Its deletion is story 050, after the wind-down.
- **Overflow:** `r * (r * 3988009 + a * 3988000)` overflows only for reserves around 1e35 wei and above, far beyond realistic. Still, document the bound and consider `Math.mulDiv` or checked maths.

---
### Autonomous Decisions
**Date**: 2026-10-01T08:43:02Z
**Command**: execute-story 048 in yield-claim-nft, sprint Balancexit --inline-delegation

#### Inline Delegation
**Mode**: --inline-delegation (workflow nesting limit)
**Steps run inline**: story-manager (discovery, failure-report check, base-commit stamp, completion validation, review transition), sprint-manager (sprint + dependency validation), repo-manager (worktree creation, env copy, commits), base-commit-validator, workflow-validator (pre-execution and post-transition), the step-6 implementation subagent
**Independence**: reduced — these verdicts were reached by the agent that also performed/observed the work

#### Decision 1: Story selection and worktree
- **Situation**: Argument "048 in yield-claim-nft, sprint Balancexit". `Balancexit` is sprint index 22; 048 is the lowest of 048/049/050 in it. No `worktrees/yield-claim-nft/` existed and the source repo had no `sprint/Balancexit` branch.
- **Decision**: Selected 048. Created `worktrees/yield-claim-nft/Balancexit` on new branch `sprint/Balancexit` from source `master` @ `9c18020` (source tree was clean, so no checkpoint commit was needed); copied `.envrc`; initialised submodules. Execution type `new_worktree`, Base Commit = `9c180204d262955f34b6d9b80e69febec0e9c400`.
- **Rationale**: Sprint-name match per execute-story step 1; base branch per base-commit rules (new worktree → source branch HEAD).
- **Alternatives**: None material. 048 has no blockers in story-dependencies.md (it is only a blocker for 049 and phStaging2:100), and there were no prior failure reports.

#### Decision 2: Constructor takes phUSD explicitly
- **Situation**: The spec allowed deriving phUSD from the pair, but deriving it would make the "wrong-token pair" check weaker: any pair containing sUSDS would pass.
- **Decision**: `constructor(sUSDS_, phUSD_, router_, pair_, initialOwner)`. It reverts `UniPoolerV2__PairTokenMismatch(token0, token1)` unless {token0, token1} == {sUSDS, phUSD} in either order. It records `sUSDSIsToken0` and does not read reserves, so an empty pair is accepted.
- **Rationale**: This makes the token-set validation meaningful. phStaging2:100's cutover script must pass phUSD (`0xf3B5…D605`).
- **Alternatives**: Derive phUSD as "the pair's other token". That is a 1-line change, but it loses the wrong-token guard.

#### Decision 3: Revert-string prefix changed from "BalancerPoolerV2:" to "UniPoolerV2:"
- **Situation**: `_dispatch` and `_psmDonate` are to be kept verbatim, but the checklist also requires `grep -i balancer` to show at most comments.
- **Decision**: The code is verbatim. Only the contract-name prefix in the three `_psmDonate` require strings and in the setter/rescue strings changed. The diff of `_dispatch` against BalancerPoolerV2 is empty, and `_psmDonate` differs only in those three strings. The one remaining `balancer` grep hit is a NatSpec comment (line 19).
- **Rationale**: This satisfies both requirements. Behaviour and storage semantics are unchanged.
- **Alternatives**: Keep the old prefix, which would fail the grep criterion and be misleading.

#### Decision 4: How the dispatch suite was ported
- **Situation**: The checklist says "same assertions, only the deployment target differs". Some BalancerPoolerV2 tests exercise removed surface (`setPool`, `vault()`, `pool()` address getter, `getIdealBPT`, `withdrawBPT`, `unlockCallback`, vault settlement, `pool(0)`).
- **Decision**: Every dispatch, donation, setter, auth, rescue, H-02 and mint-debt-hook test was ported to `test/UniPoolerV2.t.sol` with the same assertions. Only the contract-name prefix in expected revert strings changed. Tests of removed surface were dropped. Tests that called `pool(0)` now call `pool(a, quotedOut, quotedLP)` on a seeded pair, because zero floors are forbidden. `withdrawBPT`/`worksForBpt` became `test_rescueERC20_worksForLP` (rescueERC20 is the LP exit). The two "pool after donation" tests assert that `pool()` leaves the donation and parked USDS alone. `test/BalancerPoolerV2.t.sol` and `BalancerPoolerV2.sol` are byte-identical to base and still pass.
- **Rationale**: This is the only faithful port possible without the removed functions.
- **Alternatives**: None that keep the removed surface out.

#### Decision 5: "Dispatch still works while the pooler is paused" was reinterpreted (as the Concerns section directed)
- **Situation**: `ATokenDispatcherV2.dispatch` is `whenNotPaused`.
- **Decision**: These tests implement the reinterpretation:
  - `test_dispatch_worksWhilePoolUnavailable_emptyPair`: on an empty pair `pool()` reverts `EmptyPair`, while the wrap and donation stay unchanged across two dispatches.
  - `test_dispatch_worksAfterPoolReverts`.
  - `test_pause_blocksDispatchAsWellAsPool_baseBehaviour` pins the base behaviour that forced the reinterpretation.
  - No `pauser()` was added.

#### Decision 6: "Within dust" is a derived rounding bound, not a fixed "≤ 2 wei"
- **Situation**: The first test draft asserted leftover ≤ 2 wei, which proved too tight: leftovers of 3–15 wei appeared, and up to about 4 wei of phUSD worth of sUSDS at extreme prices.
- **Decision**: The bound now used is `_dustTol = (4 + 4·(rS/rP) + 4·(rP/rS)) · (2 + a/r0)` raw units, computed from post-pool reserves, zap size `a` and pre-pool sUSDS reserve `r0`. The derivation is in the helper's NatSpec. The closed form is exact over the reals, so the leftover comes only from integer floors. The getAmountOut floor (< 1 wei phUSD) propagates through the router's `quote` as about ε·p'·(1 + aRem/rS'). For a 1:1 pool with a ≤ r the bound is ≤ 24–36 wei. In every case the leftover is worth only a handful of wei of the scarcer token.
  - Verified across a reserve/size table: 8 reserve configs, including 1000:1 skews both ways and a 1e30 pool, × `a` from 0.01% to 20× r.
  - Verified with 50,001 fuzz runs.
  - Verified on the mainnet fork.
- **Rationale**: This is a bound that can be defended analytically, not a number tuned to pass. The contract was not changed to chase it.
- **Alternatives**: Sweep the residual phUSD/sUSDS dust into the next pool. This was rejected as unneeded complexity: the dust is left on the pooler and can be recovered with rescueERC20.

#### Decision 7: Front-run direction
- **Situation**: The plan says a front-run reserve shift reverts on `minPhusdOut` or `minLP`.
- **Decision**: The buy-phUSD shift is the adverse one. It is tested to revert on `minPhusdOut` (router `INSUFFICIENT_OUTPUT_AMOUNT`) and, with a loose phUSD floor, on `minLP` (`UniPoolerV2__InsufficientLP`). Both tests assert that no sUSDS is consumed and nothing is stranded. The opposite shift (phUSD dumped) is favourable to the pooler, giving more LP than quoted. It is tested to succeed with dust only, rather than forced to revert.

#### Decision 8: Router mins, extra guards, unit-test AMM, fork RPC
- **Router mins**: `addLiquidity` amountAMin/amountBMin are 0. Both sides are sized from the same in-tx reserves, and `minPhusdOut` + `minLP` bound the outcome. This is documented in NatSpec.
- **Extra pool() guards**: `NothingToPool` (a == 0), `InsufficientSUSDS` (a > balance) and `AmountTooSmall` (derived s == 0). All are on the concrete contract; `ATokenDispatcherV2` is untouched.
- **quotePool**: reverts on an empty pair, as documented. `expectedLP` assumes the factory fee is off. If the fee is on, actual LP can only be higher; the fork test asserts LP ≥ quote.
- **Unit tests**: use a new faithful-maths UniV2 pair and router mock (`test/mocks/MockUniV2Amm.sol`). Uniboost's mock router has no reserves and could not test dust.
- **Fork test** (`test/UniPoolerV2.fork.t.sol`):
  - Pinned `FORK_BLOCK = 25_550_000`, the same block as PromotionUniV2_Eth.
  - Accepts `MAINNET_RPC_URL`, or the `.envrc` name `RPC_MAINNET`; it **skips** when neither is set, with no public-node fallback.
  - Ran green against the archive RPC from `.envrc`.

#### Execution Summary
- **Commits on `sprint/Balancexit`**: `c43d1a9` [story-048] Add failing UniPoolerV2 tests (red: compile failure, no contract) → `2486232` [story-048] Add UniPoolerV2.
- **`forge build`**: no solc warnings and no forge-lint warnings in UniPoolerV2. It has only style `note`s of the same kinds BalancerPoolerV2 already carries.
- **`forge test`, full suite**: 644/644 with the RPC set; 641 passed + 3 clean skips without it. `forge test --match-contract UniPoolerV2` with the RPC set: 102/102 (99 unit + 3 fork).
- **Worktree**: clean.

#### ⚠️ HUMAN ACTION REQUIRED
> UniPoolerV2 is a new contract. It will be covered by the **yield-claim-nft project audit**, which the human runs after story 049 concludes. Contract changes in yield-claim-nft are audited with this project, not through phStaging2. Until that audit passes, UniPoolerV2 MUST NOT be deployed to mainnet.

(Not performed by the agent and not marked done.)

---
### Review Results
**Review Date**: 2026-10-01T08:45:03Z
**Review Command**: review-work yield-claim-nft:048 --inline-delegation
**Review Status**: PASSED

#### Executive Summary
UniPoolerV2 is implemented as specified. The kept surface (`_dispatch`, `_psmDonate`, every donation setter, `setAuthorizedPooler`, `incrementAuthVersion`, `rescueERC20`) was diffed function by function against BalancerPoolerV2. Once the contract-name prefix is normalised, every one is byte-identical. The Balancer surface is gone; the one remaining `balancer` grep hit is a NatSpec comment. The closed-form `s` matches the plan formula. `pool()` has the required modifiers, zero-floor and empty-pair reverts, LP custody on the pooler, and allowances reset afterwards. `BalancerPoolerV2.sol`, `test/BalancerPoolerV2.t.sol` and `ATokenDispatcherV2.sol` are byte-identical to the base commit. I re-ran the suites independently:
- `forge test`: 644/644 passed, with the `.envrc` RPC set.
- `forge test --match-contract UniPoolerV2`: 102/102 passed, including the 3 fork tests against the real Router02.

#### Validation Results
1. Base Commit Validation: ✓ Base `9c18020` equals the `sprint/Balancexit` branch point and source `master` HEAD (new_worktree). It is the only story in review on this worktree.
2. File Change Review: ✓ 2 commits, 5 files, all inside the story's File Locations (plus `test/mocks/MockUniV2Amm.sol`, which the Implementation Notes anticipate). Both commits are `[story-048]` and use the GitHub noreply author. No flags, so nothing was appended to FlaggedFiles.json.
3. Claim Validation: ✓ All 17 checked items were verified in code, tests or test runs.
   - Red-first commit `c43d1a9` contains tests and the mock only.
   - Constructor tests cover both orderings, a wrong pair and the same token twice.
   - The massRevoke test covers `pool()` for poolerA, poolerB and the setUp pooler after `incrementAuthVersion()`.
   - Dust coverage: an 8×6 table plus a fuzz test.
   - Both front-run directions are tested, and the dispatch-while-pool-unavailable test is present.
   - The worktree is clean.
4. Purpose Alignment: ✓ Delivers plan §4 Stage 1a. The UI never passes `s`. There is no price ceiling, no `pauser()`, and no guards on the base contract.

#### Issues Found
None blocking. Informational observations for triage:
- **Constructor signature differs from the plan's sketch.** The constructor is `(sUSDS, phUSD, router, pair, owner)`; phUSD is explicit (Autonomous Decision 2). phStaging2:100's cutover script must pass phUSD `0xf3B5…D605`.
- **"Within dust" is a derived bound, not a fixed number of wei.** `_dustTol = (4 + 4·(rS/rP) + 4·(rP/rS))·(2 + a/r0)` reaches roughly 88k wei at a 1000× price skew with a = 20r. That is still negligible in absolute terms (about 1e-13 of a token), and the contract was not altered to meet it.
- **New lint warnings in the test mock only.** `test/mocks/MockUniV2Amm.sol:36-37` adds 2 new forge-lint `unsafe-typecast` warnings. They are false positives, because a `uint112` bounds `require` guards both casts. `UniPoolerV2.sol` itself has no solc or lint warnings, only style `note`s of the kinds BalancerPoolerV2 already carries.
- **Expected LP assumes the protocol fee is off.** `quotePool.expectedLP` assumes the UniV2 protocol fee is off. With the fee on, LP units can only be higher, so the quote stays a valid floor. This is documented, and the fork test asserts `lp >= expectedLP`.
- **Human action still pending.** The ⚠️ Required Human Action (yield-claim-nft audit before any mainnet deploy) is still outstanding, and the executor correctly left it undone.

#### Files Changed Since Base Commit
- `src/dispatchers/UniPoolerV2.sol` (new, 483 lines)
- `src/interfaces/uniswap/IUniswapV2Pair.sol` (+`getReserves`, +`totalSupply`)
- `test/UniPoolerV2.t.sol` (new, 99 tests)
- `test/UniPoolerV2.fork.t.sol` (new, 3 fork tests)
- `test/mocks/MockUniV2Amm.sol` (new, faithful-maths UniV2 pair/router mock)

#### Autonomous Decisions
- **Situation**: No `.claude/agents/base-commit-validator.md` exists; only `base-commit-validator-template.md` does. **Decision**: Followed the template's review-work rules (cross-story ordering, worktree branch point). **Rationale**: It is the only definition of that role. **Alternatives**: Skip the step, which was rejected because the step must run.
- **Situation**: `flag-investigator.md` describes calling a reset script. **Decision**: Did not run it, because there were no flags. In any case, review-work's no-reversion rule overrides it. **Alternatives**: None.
- **Situation**: The fork test needs an archive RPC. **Decision**: Sourced the worktree's `.envrc` (`RPC_MAINNET`) for the independent test run. **Alternatives**: Run without the RPC (3 skips), which was rejected because it would leave the fork claim unverified.

#### Inline Delegation
**Mode**: --inline-delegation (workflow nesting limit)
**Steps run inline**: base-commit-validator, file-flagger, flag-investigator, change-validator, sanity-check
**Independence**: reduced. These verdicts were reached by the reviewing agent rather than by separate validator agents. The reviewer did not perform the work under review.
---

### Polish Pass 1

- **F1** (nit, comment-only) — **fixed**. Added `// forge-lint: disable-next-line(unsafe-typecast)` above each `uint112` cast in `_update()`; the preceding `uint112` bounds `require` makes both casts safe. No executable code changed. `forge build` clean (no unsafe-typecast warnings in the mock), `forge test` 641 passed / 0 failed / 3 skipped.
  - Files: `test/mocks/MockUniV2Amm.sol`
  - Commit: `f1670aba72d9d334d670e2238069e0425d5062fc` on `sprint/Balancexit`

#### Inline Delegation
**Mode**: --inline-delegation (workflow nesting limit)
**Steps run inline**: repo-manager (staging by explicit path and commit)
**Independence**: reduced — the commit was made by the agent that performed the polish

---
### Auto-Completed
**Date**: 2026-10-01T08:47:02Z
**Approved by**: story-batch workflow (machine approval — not human-reviewed)
**Review Status acted on**: PASSED
**Triage verdict**: non-blocking
**Fixed by the polish pass before completion** (verified in scope and correct by triage):
- [nit] `test/mocks/MockUniV2Amm.sol:36-37` false-positive forge-lint unsafe-typecast warnings — silenced with `forge-lint: disable-next-line(unsafe-typecast)` (commit `f1670ab`)
**Non-blocking findings carried forward**:
- [low] UniPoolerV2 constructor is `(sUSDS, phUSD, router, pair, owner)` with phUSD explicit (Autonomous Decision 2); the phStaging2:100 cutover script must pass phUSD `0xf3B5…D605` — downstream coordination note, not a defect
- [low] Test "within dust" tolerance is an analytically derived bound (~88k wei at 1000x skew, a = 20r, ~1e-13 token), not a fixed wei count; contract not altered to meet it
- [nit] `quotePool.expectedLP` assumes the UniV2 protocol fee is off; with fee on LP is only higher so the quote stays a valid floor (NatSpec-documented; fork test asserts `lp >= expectedLP`)
- [low] Required Human Action outstanding by design: the yield-claim-nft audit must pass before UniPoolerV2 is deployed to mainnet — needs a human, not a code change
**Base commit set to**: f1670aba72d9d334d670e2238069e0425d5062fc (previously 9c180204d262955f34b6d9b80e69febec0e9c400; no subsequent story in sprint `Balancexit` carries a base commit — 049/050 are unexecuted in `incomplete/` — so worktree HEAD was used)
**Base commit validation**: ✓ `f1670ab` descends from the branch point `9c18020` (= yield-claim-nft `master`); 048 is the only story in `review/` on `worktrees/yield-claim-nft/Balancexit`; worktree clean on `sprint/Balancexit`
**Reversal**: `git -C worktrees/yield-claim-nft/Balancexit log` from this base commit; move the story file
back to `review/` and delete this section to undo the completion.

#### Inline Delegation
**Mode**: --inline-delegation (workflow nesting limit)
**Steps run inline**: story-manager (location/validation, next-story lookup, stamp, move), repo-manager (worktree discovery, product-owner checkpoint), base-commit-validator (per `base-commit-validator-template.md`; no dedicated `base-commit-validator.md` exists), workflow-validator (transition validation)
**Independence**: reduced — these verdicts were reached by the auto-complete agent itself; the review and triage verdicts acted on came from separate workflow agents


---

# FULL STORY DOCUMENT — story-049

Path: `/home/justin/code/product-owner/stories/yield-claim-nft/auto-complete/yield-claim-nft-Balancexit/049-promotion-univ2-eth-leg-a-uniswap-v2.md`

## PromotionUniV2_Eth Leg A: replace the Balancer swap with Uniswap V2

Current Sprint: 22
Base Commit: 2bfa0905b30a10dafcfd8944dad3503b3b802d18
Execution Type: existing_worktree
Base Commit Updated: 2026-10-01T08:55:12Z

### ⚠️ Required Human Action On Completion

**Run the yield-claim-nft project audit now.** It covers stories 048 and 049: UniPoolerV2 and the rewritten `PromotionUniV2_Eth` Leg A. Passing it is half of the `stage1-audit` gate on phStaging2:103 (the other half is `audit-script dev`, run at the end of phStaging2:102). Neither `UniPoolerV2` nor `PromotionUniV2_Eth` may be deployed before this audit passes.

### Story Overview

`PromotionUniV2_Eth` is **not deployed**. Its Leg A hardcodes the Balancer V3 Vault and the phUSD/sUSDS Balancer pool, and swaps sUSDS→phUSD through `vault.unlock/swap/settle/sendTo`. The Balancer pool is paused on 30 Oct 2026, so the contract's first `pool()` would revert. This story rewrites Leg A to swap through the new phUSD/sUSDS **Uniswap V2** pair via Router02 `swapExactTokensForTokens`, before the contract is ever deployed. There is nothing to migrate.

Repo: `~/code/reflax-mint/yield-claim-nft` (product-owner project `yield-claim-nft`). Paths are relative to the sprint worktree `worktrees/yield-claim-nft/Balancexit/` (branch `sprint/Balancexit`).

Source plan: `docs/BalancerWinddownPlan.md` §2.2 and §4 Stage 1a (final paragraph), in **phStaging2** (`~/code/reflax-mint/phase-2-staging`, master `3943ae3`). Read it with `git -C ~/code/reflax-mint/phase-2-staging show master:docs/BalancerWinddownPlan.md`.

### Background

Plan §2.2 (verbatim row):

> | `PromotionUniV2_Eth` (`lib/yield-claim-nft/src/dispatchers/PromotionUniV2_Eth.sol`) | **Not deployed** | Leg A hardcodes `BALANCER_VAULT` and `BALANCER_POOL` as constants and swaps sUSDS→phUSD through `vault.unlock/swap/settle/sendTo` | Would revert on its first `pool()` | Rewrite Leg A for the new venue **before** it is ever deployed |

Plan §4 Stage 1a, final paragraph (verbatim):

> `PromotionUniV2_Eth` Leg A gets the same treatment in the same stage: replace the Balancer swap with a V2 `swapExactTokensForTokens(sUSDS→phUSD)`. It isn't deployed, so there's nothing to migrate.

Exploration findings:
- Constants `BALANCER_VAULT = 0xbA1333333333a1BA1108E8412f11850A5C319bA9` and `BALANCER_POOL = 0x642BB6860b4776CC10b26B8f361Fd139E7f0db04` are at lines ~92-94.
- `_swapSusdsForPhusd` is at line ~532 and `unlockCallback` at line ~547.
- The contract already imports `IUniswapV2Router02`.
- The fork test `test/PromotionUniV2_Eth.t.sol` uses `MAINNET_RPC_URL`, a pinned `FORK_BLOCK`, and `UNIV2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f`.

Mainnet addresses: Router02 `0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D`, sUSDS `0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD`, phUSD `0xf3B5B661b92B75C71fA5Aba8Fd95D7514A9CD605`.

### File Locations

| File | Change |
|---|---|
| `src/dispatchers/PromotionUniV2_Eth.sol` | Rewrite Leg A: remove the `BALANCER_VAULT`/`BALANCER_POOL` constants (~92-94), the `unlockCallback` (~547) and the `IUnlockCallback` inheritance; rewrite `_swapSusdsForPhusd` (~532) to use Router02 `swapExactTokensForTokens` along `[sUSDS, phUSD]` |
| `src/interfaces/uniswap/IUniswapV2Pair.sol` | Already extended by story 048 (`getReserves`, `totalSupply`); use it if needed |
| `test/PromotionUniV2_Eth.t.sol` | Update the fork test: create and seed the phUSD/sUSDS V2 pair on the fork, then exercise Leg A through it |

### Technical Details

- Leg A becomes `IUniswapV2Router02(router).swapExactTokensForTokens(amountIn, minOut, path=[sUSDS, phUSD], to, deadline)`. Keep whatever slippage parameter Leg A already accepts (min phUSD out). If Leg A currently has no non-zero floor, add a loud revert on a zero floor, consistent with UniPoolerV2's Configuration Safety.
- Use the router address the contract already holds, if it holds one; otherwise use the Router02 constant `0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D`.
- After the rewrite, nothing in `PromotionUniV2_Eth.sol` may reference `src/interfaces/balancer/*`.
- Do not change Legs other than A.

### Implementation Notes

- **Gate check first** (see Checklist).
- **TDD:** update `test/PromotionUniV2_Eth.t.sol` first so it fails against the Balancer Leg A (the Balancer pool route is no longer what the test seeds), then rewrite.
- On the fork the phUSD/sUSDS V2 pair does not exist yet, so the test must create and seed it: either via factory `createPair` plus a router `addLiquidity`, or `addLiquidity` alone, which creates the pair. Use `deal` for the tokens.
- **Fork-test convention:** `MAINNET_RPC_URL`, pinned `FORK_BLOCK`, skip cleanly if unset.
- **Commits:** every commit is `[story-049] <message>`, staged by explicit path.

### Checklist

- [x] Gate check: confirm that predecessor story yield-claim-nft:048 is in `stories/yield-claim-nft/complete/` or `stories/yield-claim-nft/auto-complete/` (NOT merely `review/`). If not, make NO code changes: append an Autonomous Decision stating which predecessor is missing, report "ABORTED: out-of-order execution — <reason>" in the output, and exit without moving the story.
- [x] Update `test/PromotionUniV2_Eth.t.sol` first: create and seed the phUSD/sUSDS V2 pair on the fork, and assert that Leg A buys phUSD through it (pair reserves move, phUSD is received, `minOut` honoured).
- [x] Remove `BALANCER_VAULT`, `BALANCER_POOL`, `unlockCallback` and the `IUnlockCallback` inheritance from `src/dispatchers/PromotionUniV2_Eth.sol`.
- [x] Rewrite `_swapSusdsForPhusd` to use Router02 `swapExactTokensForTokens(sUSDS→phUSD)` with a non-zero `minOut`.
- [x] `grep -n -i "balancer\|unlockCallback" src/dispatchers/PromotionUniV2_Eth.sol` returns nothing except, at most, an explanatory comment.
- [x] Test: a zero `minOut` reverts loudly, if the floor is caller-supplied.
- [x] `forge build` passes.
- [x] `forge test` passes (full suite), and `MAINNET_RPC_URL=<rpc> forge test --match-path test/PromotionUniV2_Eth.t.sol` passes.
- [x] All commits use `[story-049] <message>`, staged by explicit path; the worktree is clean.
- [x] Final step: end your execution summary with a clearly marked block headed "⚠️ HUMAN ACTION REQUIRED" that restates the Required Human Action On Completion section verbatim, so the user is alerted. Do not perform the action yourself and do not mark it as done.

### Concerns

- The dependency on 048 exists only because of the extended `IUniswapV2Pair` interface (same sprint, same branch, run after 048).
- The contract is not deployed, so storage layout and ABI changes are free. phStaging2 does not deploy `PromotionUniV2_Eth` today; confirm with a grep in phStaging2 if in doubt, and record the result.

---
### Autonomous Decisions
**Date**: 2026-10-01T09:05:00Z
**Command**: execute-story 049 in yield-claim-nft, sprint Balancexit --inline-delegation

#### Inline Delegation
**Mode**: --inline-delegation (workflow nesting limit)
**Steps run inline**: story-manager (selection, base-commit write, failure-report check, completion validation, review transition), sprint-manager (sprint + dependency validation), repo-manager (worktree health, commits), base-commit-validator, workflow-validator (pre-execution and post-transition), implementation subagent (step 6, bound by the subagent-constraints block)
**Independence**: reduced — these verdicts were reached by the agent that also performed/observed the work

#### Decision 1: Selection, sprint and dependency gate
- **Situation**: Argument names story 049 in sprint `Balancexit` (index 22 in `sprints.json`). Checklist item 1 requires yield-claim-nft:048 in `complete/` or `auto-complete/`.
- **Decision**: Proceeded. 048 is at `stories/yield-claim-nft/auto-complete/yield-claim-nft-Balancexit/048-unipoolerv2-uniswap-v2-zap-pooler.md` (machine-approved, terminal); `story-dependencies.md` row for 049 already reads "Unblocked". Gate passed, no code was touched before the check.
- **Rationale**: auto-complete/ is terminal and resolves dependencies exactly as complete/ does (CLAUDE.md).
- **Alternatives**: none — had 048 been absent the run would have aborted per the gate.

#### Decision 2: Base commit / execution type
- **Situation**: `worktrees/yield-claim-nft/Balancexit` (branch `sprint/Balancexit`) already existed, clean, HEAD `f1670ab` (048's tip and 048's recorded base-commit chain head). No failure reports in the story.
- **Decision**: `existing_worktree`, Base Commit = `f1670aba72d9d334d670e2238069e0425d5062fc`.
- **Rationale**: base-commit rules: existing worktree → worktree HEAD.
- **Alternatives**: none applicable.

#### Decision 3: Fork-test convention — skip cleanly instead of public-node fallback
- **Situation**: The story's fork-test convention is "MAINNET_RPC_URL, pinned FORK_BLOCK, skip cleanly if unset", but `test/PromotionUniV2_Eth.t.sol` fell back to `https://ethereum-rpc.publicnode.com` when unset (a pinned historical block on a non-archive node).
- **Decision**: Adopted the 048 `UniPoolerV2.fork.t.sol` convention: `MAINNET_RPC_URL` → `RPC_MAINNET` → empty; when empty `setUp` calls `vm.skip(true)` and the whole suite reports as skipped (verified: `0 passed; 0 failed; 1 skipped`). Updated the matching explanatory comment in `foundry.toml` (comment-only change; no config change).
- **Rationale**: Explicit story instruction; consistency with the sibling fork suite.
- **Alternatives**: restore the public-node fallback by reverting the 4-line `setUp` change.

#### Decision 4: Zero `minPhusdOut` floor now reverts; existing tests pass a floor of 1
- **Situation**: `pool()` already took `minPhusdOut` but accepted 0. The story requires a loud revert on a zero floor.
- **Decision**: `require(minPhusdOut > 0, "PromotionUniV2_Eth: zero phUSD floor")` in `pool()`, placed after the existing `nothing to pool` / `insufficient prime` checks (so those tests keep their revert reasons). Kept this contract's house style (string `require`), not UniPoolerV2's custom errors. Every existing test that called `pool(x, 0, …)` now passes `1` for `minPhusdOut`; the other floors are unchanged.
- **Rationale**: Story Technical Details; minimal ABI-stable change (signature unchanged).
- **Alternatives**: use a custom error to match UniPoolerV2 — would be inconsistent with the rest of this contract.

#### Decision 5: Router address and Balancer-free doc comments
- **Situation**: Contract already held `UNIV2_ROUTER = 0x7a25…488D` (Router02).
- **Decision**: Leg A uses `UNIV2_ROUTER` with exact `forceApprove` and reset-to-zero, `deadline = block.timestamp` (same as Legs B/C). Also reworded three doc comments that mentioned `BalancerPooler`/`BalancerPoolerV2` lineage so the checklist grep returns nothing at all. Legs B and C, the dispatch path and all setters are untouched.
- **Rationale**: Story: "use the router address the contract already holds"; grep item prefers zero hits.
- **Alternatives**: none material.

#### Decision 6: phStaging2 does not deploy PromotionUniV2_Eth (Concerns item)
- **Situation**: Story Concerns asks to confirm by grep.
- **Decision**: `git -C ~/code/reflax-mint/phase-2-staging grep PromotionUniV2_Eth master -- . ':!lib'` returns only `docs/BalancerWinddownPlan.md` (lines 74, 311). No deploy script, address file or wagmi config references it, so the ABI change (removed `BALANCER_VAULT()`/`BALANCER_POOL()`/`unlockCallback`) has no downstream consumer.
- **Rationale**: Confirms "nothing to migrate".
- **Alternatives**: n/a.

#### Execution Summary
- Commits on `sprint/Balancexit` (base `f1670ab`):
  - `157ba20` [story-049] Add failing Leg A Uniswap V2 tests for PromotionUniV2_Eth (red: 5 failing, 78 passing)
  - `a4d80f4` [story-049] Rewrite PromotionUniV2_Eth Leg A to swap through the phUSD/sUSDS Uniswap V2 pair
- Files: `src/dispatchers/PromotionUniV2_Eth.sol`, `test/PromotionUniV2_Eth.t.sol`, `foundry.toml` (comment only).
- New tests: `test_pool_revertsOnZeroPhusdFloor`, `test_legA_swapsThroughPhusdSusdsV2Pair` (pair sUSDS reserve rises, phUSD reserve falls by exactly `phusdAcquired`, which equals the 0.3%-fee V2 quote on pre-swap reserves; no sUSDS stranded), `test_legA_minPhusdOutHonouredAtExactBoundary` (exact output passes, +1 wei reverts `UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT`), `test_legA_doesNotTouchBalancerVault`. `test_pool_revertsWhenMinPhusdOutNotMet` now asserts the router's revert string.
- The phUSD/sUSDS pair is created in `setUp` via Router02 `addLiquidity` (asserting it does not pre-exist at FORK_BLOCK 25,550,000), seeded at the $1 peg with $1M per side.
- `forge build`: passes. `forge test` with `MAINNET_RPC_URL` set: 648 passed / 0 failed / 0 skipped (baseline 644). `--match-path test/PromotionUniV2_Eth.t.sol`: 83/83. Without an RPC: 562 passed, fork suites skipped.
- `grep -n -i "balancer\|unlockCallback" src/dispatchers/PromotionUniV2_Eth.sol`: no output.
- `forge fmt --check` is not clean on either file, but it was not clean at base either (pre-existing formatting); not in this story's checklist, so not reformatted to keep the diff focused.

#### ⚠️ HUMAN ACTION REQUIRED
**Run the yield-claim-nft project audit now.** It covers stories 048 and 049: UniPoolerV2 and the rewritten `PromotionUniV2_Eth` Leg A. Passing it is half of the `stage1-audit` gate on phStaging2:103 (the other half is `audit-script dev`, run at the end of phStaging2:102). Neither `UniPoolerV2` nor `PromotionUniV2_Eth` may be deployed before this audit passes.

---
### Review Results
**Review Date**: 2026-10-01T08:53:27Z
**Review Command**: review-work yield-claim-nft:049 --inline-delegation
**Review Status**: ISSUES_FOUND

#### Executive Summary
Leg A of `PromotionUniV2_Eth` now swaps sUSDS→phUSD through Router02 `swapExactTokensForTokens` along `[sUSDS, phUSD]`. The Balancer constants, imports, `unlockCallback` and the `IUnlockCallback` inheritance are gone, and a zero `minPhusdOut` reverts loudly. Legs B/C are untouched. Every checklist claim was verified independently: `forge build` passes, the full `forge test` with an archive RPC gives 648 passed / 0 failed / 0 skipped, the PromotionUniV2_Eth suite gives 83/83, and without an RPC it gives 1 skipped. One minor, non-functional issue: a stale code comment in the test `setUp`.

#### Validation Results
1. Base Commit Validation: ✓ — `f1670ab` exists, is an ancestor of HEAD, descends from the worktree's branch point from master (`9c18020`), and is 048's chain tip. 049 is the only story in `review/` for this worktree.
2. File Change Review: ✓ — 3 files: `src/dispatchers/PromotionUniV2_Eth.sol`, `test/PromotionUniV2_Eth.t.sol`, `foundry.toml` (a comment-only change, disclosed as Decision 3). Nothing was flagged, so nothing was written to FlaggedFiles.json and the flag-investigator had nothing to investigate.
3. Claim Validation: ✓ — all 10 checked items verified. The grep returns nothing (rc=1). The TDD order holds: `157ba20` is test-only and `a4d80f4` is the implementation. Both commits are `[story-049]`, authored with the noreply email, and the worktree is clean. The phStaging2 grep confirms the only reference is `docs/BalancerWinddownPlan.md`.
4. Purpose Alignment: ✓ — the change matches plan §2.2 / §4 Stage 1a exactly. It uses the existing `UNIV2_ROUTER`, with an exact approve and a reset to zero, and the scope is minimal.

#### Issues Found
1. **Minor (comment only, non-functional)**: `test/PromotionUniV2_Eth.t.sol:99`. The `setUp` comment still reads "…name used by the local .envrc); fall back to a public node for head runs." The code directly below now skips the suite when no RPC is set, and there is no public-node fallback. The test's NatSpec header (updated correctly) and the code contradict this comment.

Observations (not issues with this story):
- `forge fmt --check` is not clean, but it was not clean at the base commit either. The executor disclosed this, and it is not a checklist item.
- `FlaggedFiles.json` at the product-owner root is malformed JSON ("Extra data" at line 3402). This predates the review and was not touched.

#### Files Changed Since Base Commit
- `foundry.toml` (comment only)
- `src/dispatchers/PromotionUniV2_Eth.sol`
- `test/PromotionUniV2_Eth.t.sol`

#### Autonomous Decisions
- **Agent definition name**: `.claude/agents/base-commit-validator.md` does not exist; the definition is `.claude/agents/base-commit-validator-template.md` (`name: base-commit-validator`). I followed that file. Alternative: skip the step (rejected, since the step must run).
- **Fork RPC for test verification**: `MAINNET_RPC_URL` was unset in the environment. I took `RPC_MAINNET` from the worktree's `.envrc` (the value was not printed), which is the fallback the test itself accepts, so the 648-test claim could be verified with the fork suites live. I also ran the suite with both variables unset to confirm the clean skip.
- **No FlaggedFiles.json write**: there were no flags, so nothing was appended (file-flagger: "when unsure, don't flag"). The file's existing malformation is reported above and was not repaired.
- **Status choice**: ISSUES_FOUND rather than PASSED, because one concrete (cosmetic) defect exists. Whether it blocks is left to triage.

#### Inline Delegation
**Mode**: --inline-delegation (workflow nesting limit)
**Steps run inline**: base-commit-validator, file-flagger, flag-investigator, change-validator, sanity-check
**Independence**: reduced — these verdicts were reached by the agent that also performed/observed the work (the reviewer did not perform the work; executor was a separate workflow agent, but the inner validator layer was not independent of this reviewer)
---

### Polish Pass 1

- **F1** (low, comment-only) — **fixed**. Replaced the stale "fall back to a public node for head runs" wording in the `setUp` comment of `test/PromotionUniV2_Eth.t.sol` with "with neither set, the suite is skipped", matching the `vm.skip(true)` code and the NatSpec header. No executable code changed.
  - Files touched: `test/PromotionUniV2_Eth.t.sol`
  - Commit: `2bfa0905b30a10dafcfd8944dad3503b3b802d18` on `sprint/Balancexit`
  - Verification: `forge build` succeeded; `forge test` — 562 passed, 0 failed, 4 skipped.

#### Inline Delegation
**Mode**: --inline-delegation (workflow nesting limit)
**Steps run inline**: repo-manager (explicit-path staging and commit)
**Independence**: reduced — the commit was made by the agent that performed the edit

---
### Auto-Completed
**Date**: 2026-10-01T08:55:12Z
**Approved by**: story-batch workflow (machine approval — not human-reviewed)
**Review Status acted on**: ISSUES_FOUND
**Triage verdict**: non-blocking
**Fixed by the polish pass before completion** (verified in scope and correct):
- [low] Stale setUp comment at test/PromotionUniV2_Eth.t.sol:99 claimed a public-node fallback for head runs; code calls vm.skip(true) when no RPC is set. Fixed in 2bfa090.
**Non-blocking findings carried forward**:
- [nit] `forge fmt --check` fails on src/dispatchers/PromotionUniV2_Eth.sol and test/PromotionUniV2_Eth.t.sol; pre-existing at base commit, disclosed by executor, not a checklist item — out of scope for polish.
- [low] FlaggedFiles.json at product-owner root is malformed JSON ("Extra data" at line 3402); predates review, outside this story's codebase — needs separate repair via the flag-management path.
**Base commit set to**: 2bfa0905b30a10dafcfd8944dad3503b3b802d18
**Reversal**: `git -C worktrees/yield-claim-nft/Balancexit log` from this base commit; move the story file
back to `review/` and delete this section to undo the completion.

#### Base Commit Determination
- Next story in sprint Balancexit (050) is in `incomplete/` with no Base Commit (stamped at execution time), so the worktree HEAD was used.
- base-commit-validator (inline): VALID — `2bfa0905b30a10dafcfd8944dad3503b3b802d18` is HEAD of `sprint/Balancexit`; worktree clean; descends from 048's base `f1670ab` (auto-complete/) and from the branch point `9c18020`; 049 is the only story in `review/` for this worktree.

#### Inline Delegation
**Mode**: --inline-delegation (workflow nesting limit)
**Steps run inline**: story-manager, repo-manager, base-commit-validator, workflow-validator
**Independence**: reduced — these verdicts were reached by the agent that also performed the transition


---

# FULL STORY DOCUMENT — story-043 (governs NudgeRatchetDelayRelease.sol)

Path: `/home/justin/code/product-owner/stories/yield-claim-nft/complete/yield-claim-nft-ratchet/043-nudge-ratchet-delay-release-dispatcher.md`

## NudgeRatchetDelayRelease Dispatcher (held USDC + releaser-gated release)

Current Sprint: 17
Story Type: feature
Execution Type: existing_worktree
Base Commit: f46a5cb7a90726215d49619ce76cb297f56e290a
Base Commit Updated: 2026-06-27T00:00:00Z

### Story Overview

Add a new V2 token dispatcher, **`NudgeRatchetDelayRelease`**, that is a near-copy of the
existing **`NudgeRatchet`** dispatcher with one behavioural change plus three additions.
**Do NOT delete, move, or modify `NudgeRatchet`** — this is a new sibling contract.

Differences from `NudgeRatchet`:

1. **Hold instead of forward on dispatch.** Where `NudgeRatchet._dispatch` sweeps the full
   USDC balance straight to `batchMinter`, `NudgeRatchetDelayRelease._dispatch` does **not**
   transfer anything — the USDC is simply **held** on the contract.
2. **New `releasers` whitelist.** An owner-configurable `mapping(address => bool) public releasers`
   with an owner-only setter `setReleaser(address, bool)` (true = whitelist, false = revoke).
3. **New `release(uint256 amount)` function.** Callable **only by a whitelisted releaser**; it
   forwards the specified `amount` of held USDC to `batchMinter`. This gives admins direct
   control over the *rate* at which accumulated USDC reaches the batchMinter.
4. **Add `rescueERC20(address token, address to, uint256 amount)`** (owner-only) — `NudgeRatchet`
   deliberately has none (its self-sweep made it unnecessary); a contract that now *holds* funds
   wants the escape hatch, mirroring `BalancerPoolerV2`/`Uniboost`.

**The mint-debt logic is unchanged.** The abstract base `ATokenDispatcherV2.dispatch` still calls
`hook.onDispatch(minter, amount, extraData)` after `_dispatch`, so the `NudgeRatchetMintDebtHook`
continues to accrue phUSD mint-debt against `amount` on every dispatch. phUSD realisation by the
downstream staker (via the hook's `pull()`) is therefore **fully independent of** the USDC release
schedule — confirmed with the user: *"the downstream staker can start releasing phUSD independently
of the release to the batchMinter."*

### Background

The V2 dispatcher architecture uses a template-method split in the abstract base
`ATokenDispatcherV2` (`src/dispatchers/ATokenDispatcherV2.sol`):

- The non-virtual `dispatch(minter, amount, extraData)` is `external nonReentrant onlyMinter
  whenNotPaused`. It calls the concrete `_dispatch(...)`, then calls
  `hook.onDispatch(minter, amount, extraData)`.
- Concrete dispatchers override **only** `_dispatch`. They MUST NOT re-declare `onlyMinter`,
  `whenNotPaused`, or `nonReentrant` on `_dispatch`.
- `hook` defaults to a freshly-deployed `DefaultDispatchHook` (never zero) and is owner-swappable
  via the inherited `setHook`. Ownership is OpenZeppelin `Ownable` (so `onlyOwner` is available);
  `ReentrancyGuard` is inherited (so `nonReentrant` is available to concretes).

`NudgeRatchet` (`src/dispatchers/NudgeRatchet.sol`) is the template: an immutable `_token` (must be
6-decimal USDC, enforced at deploy), an owner-settable `batchMinter` sink, a hook-type guard
(Audit M-04, story 037), and a `_dispatch` that sweeps the full USDC balance to `batchMinter`
(story 038). `NudgeRatchetDelayRelease` keeps the constructor, the USDC guard, the hook-type
guard, `primeToken()`, `setBatchMinter`, and `batchMinter` verbatim — it only changes what
`_dispatch` does with the tokens and adds the releaser machinery + rescue hatch.

#### Backing/accounting (read before coding) — KNOWN/ACCEPTED, do not surface as audit findings

These are intentional, user-approved design properties. The contract NatSpec records them verbatim
(see the contract-level `@dev` block and `release`'s `@dev`) **specifically so an auditor does not
re-flag them as an unintended discrepancy.** Transcribe those comments exactly.

- On dispatch, the minter has already deposited `amount` USDC onto this contract (via
  `transferFrom`) before calling `dispatch`, exactly as for `NudgeRatchet`. The mint-debt hook
  accrues debt against `amount`. So **held USDC is backing** for the accrued debt; it simply
  lives on this contract until a releaser relocates it to `batchMinter`.
- `release(amount)` **moves** existing USDC; it never mints or burns. Total system backing is
  conserved across a release — only the *location* of the backing changes (dispatcher → sink).
- **Debt/release timing decoupling is intentional.** phUSD mint-debt accrues — and the downstream
  staker may realise phUSD — at *dispatch* time, while the backing USDC may still be held here,
  un-released. The resulting window (phUSD realised, USDC not yet at the batchMinter) is the
  deliberate admin rate-control mechanism, **not** an accounting bug, and creates no unbacked
  phUSD (the backing exists the whole time; only its location lags). phUSD can be realised before,
  after, or interleaved with USDC releases.

### File Locations

#### New files to create

| File | Purpose |
|------|---------|
| `src/dispatchers/NudgeRatchetDelayRelease.sol` | New dispatcher: holds USDC, releaser-gated `release`, `rescueERC20` |
| `test/NudgeRatchetDelayRelease.t.sol` | Foundry tests (model on `test/NudgeRatchet.t.sol`) |

#### Existing files to use as templates / references (DO NOT MODIFY)

| File | Why |
|------|-----|
| `src/dispatchers/NudgeRatchet.sol` | Primary template (constructor, USDC guard, hook-type guard, `batchMinter`, `setBatchMinter`, `primeToken`) |
| `src/dispatchers/ATokenDispatcherV2.sol` | Abstract base — `_dispatch` override contract, `dispatch`, `setHook`, `setMinter`, `Ownable`/`ReentrancyGuard`/`Pausable` |
| `src/dispatchers/BalancerPoolerV2.sol` | `rescueERC20(address,address,uint256)` reference (line ~350) |
| `src/dispatchers/Uniboost.sol` | `rescueERC20(address,address,uint256)` reference (line ~283) |
| `src/NFTMinterV2.sol` | `mapping(address => bool) public authorizedMinters` + `setAuthorizedMinter(addr,bool) onlyOwner` — the idiomatic public-mapping whitelist pattern to mirror for `releasers` |
| `src/BurnRecorder.sol` | `onlyBurner` modifier pattern (`require(_burners[msg.sender], ...)`) to mirror for `onlyReleaser` |
| `src/hooks/NudgeRatchetMintDebtHook.sol` | The mint-debt hook this dispatcher wires to (UNCHANGED). `HOOK_TYPE_ID = keccak256("NudgeRatchetMintDebtHook.v1")` |
| `src/interfaces/INudgeRatchetMintDebtHook.sol` | Hook interface used by the M-04 hook-type guard (`hookTypeId()`) |
| `test/NudgeRatchet.t.sol` | Test pattern (inline `MockUSDC` 6dp + `Mock18Decimals`, `MockMintable`, hook wiring, `NFTMinterV2` integration) |

(Paths relative to the repo root `/home/justin/code/reflax-mint/yield-claim-nft`. Note: dispatchers
live in `src/dispatchers/` and tests are flat in `test/` — the `src/V2/...` paths in older ratchet
stories are stale.)

### Technical Details

#### Target contract: `src/dispatchers/NudgeRatchetDelayRelease.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ATokenDispatcherV2} from "./ATokenDispatcherV2.sol";
import {ITokenDispatcherV2} from "../interfaces/ITokenDispatcherV2.sol";
import {INudgeRatchetMintDebtHook} from "../interfaces/INudgeRatchetMintDebtHook.sol";

/// @title NudgeRatchetDelayRelease
/// @notice A V2 token dispatcher that HOLDS its USDC on dispatch instead of forwarding it
///         immediately, and only releases it to the owner-settable `batchMinter` when a
///         whitelisted `releaser` calls `release(amount)`. This gives admins rate control over
///         how fast accumulated USDC reaches the batchMinter. Sibling of `NudgeRatchet`.
/// @dev The mint-debt side is UNCHANGED from NudgeRatchet: the base `dispatch` still calls
///      `hook.onDispatch(minter, amount, extraData)` after `_dispatch`, so the
///      NudgeRatchetMintDebtHook accrues phUSD mint-debt against `amount` on every dispatch.
///
///      KNOWN / ACCEPTED DESIGN PROPERTIES — these are intentional; DO NOT re-flag as findings:
///        * Debt/release timing is DECOUPLED ON PURPOSE. phUSD mint-debt accrues (and the
///          downstream staker may realise phUSD via the hook's `pull()`) at DISPATCH time, while
///          the USDC backing it can still be sitting on this contract, un-released. There is
///          therefore an intended, admin-controlled window in which phUSD has been realised but
///          the corresponding USDC has NOT yet reached the batchMinter. This is the whole point
///          of the contract (rate-controlled release), not an accounting bug.
///        * No unbacked phUSD is created by this. The USDC that backs the accrued debt is HELD on
///          this contract from dispatch onward; `release` only RELOCATES that existing backing to
///          the batchMinter (it never mints or burns), so total system backing is conserved at
///          all times. The only thing the release schedule changes is WHERE the backing sits
///          (dispatcher vs. sink), never WHETHER it exists.
///        * Release rate is a trusted admin lever. `release` is gated to an owner-managed
///          `releasers` whitelist; the owner deliberately controls how fast held USDC flows to
///          the batchMinter. Slow/withheld releases are an operational choice, not a liveness bug.
///        * `rescueERC20` can withdraw held `_token` (USDC). This is an accepted owner power with
///          the same trust assumption as `setBatchMinter`; see its NatSpec.
contract NudgeRatchetDelayRelease is ATokenDispatcherV2 {
    using SafeERC20 for IERC20;

    /// @notice The token this dispatcher acts on. Must be USDC (6 decimals). Immutable.
    address internal immutable _token;

    /// @notice Owner-settable nudge-reward sink that receives released USDC.
    address public batchMinter;

    /// @notice Owner-configurable whitelist of addresses permitted to call `release`.
    mapping(address => bool) public releasers;

    /// @dev Must equal NudgeRatchetMintDebtHook.HOOK_TYPE_ID. Kept as a local constant
    ///      (rather than importing) to avoid a hard dependency cycle; both derive from the
    ///      same literal string and must stay in sync. (Audit M-04)
    bytes32 private constant EXPECTED_HOOK_TYPE_ID = keccak256("NudgeRatchetMintDebtHook.v1");

    /// @notice Emitted when the batchMinter address is updated.
    event BatchMinterUpdated(address indexed oldBatchMinter, address indexed newBatchMinter);
    /// @notice Emitted when a releaser is added to or removed from the whitelist.
    event ReleaserUpdated(address indexed releaser, bool approved);
    /// @notice Emitted when a releaser releases held USDC to the batchMinter.
    event Released(address indexed releaser, uint256 amount);

    /// @dev Restricts a function to whitelisted releasers.
    modifier onlyReleaser() {
        require(releasers[msg.sender], "NudgeRatchetDelayRelease: caller is not releaser");
        _;
    }

    /// @param token_ The token this dispatcher acts on — must be 6-decimal USDC.
    /// @param batchMinter_ The initial nudge-reward sink to release tokens to.
    /// @param initialOwner The initial owner of this dispatcher.
    constructor(address token_, address batchMinter_, address initialOwner)
        ATokenDispatcherV2(initialOwner)
    {
        require(batchMinter_ != address(0), "NudgeRatchetDelayRelease: zero batchMinter");
        // Deploy-time USDC guard: batchMinter only accepts USDC (6-decimal) rewards.
        require(
            IERC20Metadata(token_).decimals() == 6,
            "NudgeRatchetDelayRelease: token must be 6-decimal USDC"
        );
        _token = token_;
        batchMinter = batchMinter_;
    }

    /// @inheritdoc ITokenDispatcherV2
    function primeToken() external view returns (address) {
        return _token;
    }

    /// @notice Updates the batchMinter sink. Only callable by the owner.
    function setBatchMinter(address newBatchMinter) external onlyOwner {
        require(newBatchMinter != address(0), "NudgeRatchetDelayRelease: zero batchMinter");
        address old = batchMinter;
        batchMinter = newBatchMinter;
        emit BatchMinterUpdated(old, newBatchMinter);
    }

    /// @notice Adds (`approved == true`) or removes (`approved == false`) a releaser. Owner only.
    function setReleaser(address releaser, bool approved) external onlyOwner {
        releasers[releaser] = approved;
        emit ReleaserUpdated(releaser, approved);
    }

    /// @notice Releases `amount` of held USDC to the batchMinter. Only callable by a releaser.
    /// @dev Reverts (via SafeERC20) if `amount` exceeds the held balance. KNOWN/ACCEPTED (not a
    ///      finding): the mint-debt backing this USDC was already accrued in the hook at DISPATCH
    ///      time and may already have been realised as phUSD by the downstream staker. This call
    ///      only RELOCATES already-held backing to the sink at an admin-controlled rate; it is
    ///      intentionally independent of phUSD realisation and creates no unbacked phUSD.
    function release(uint256 amount) external onlyReleaser nonReentrant {
        IERC20(_token).safeTransfer(batchMinter, amount);
        emit Released(msg.sender, amount);
    }

    /// @notice Owner escape hatch to recover ERC20s held by this contract. Mirrors
    ///         BalancerPoolerV2/Uniboost. NOT pause-gated, by design.
    /// @dev NOTE: this CAN withdraw held `_token` (USDC), which is backing for already-accrued
    ///      mint-debt. Using it on `_token` can leave debt under-backed and is an owner
    ///      responsibility; intended use is recovering non-`_token` assets sent here by mistake.
    function rescueERC20(address token, address to, uint256 amount) external onlyOwner {
        require(to != address(0), "NudgeRatchetDelayRelease: zero recipient");
        IERC20(token).safeTransfer(to, amount);
    }

    /// @notice Holds dispatched USDC on this contract; does NOT forward to the batchMinter.
    /// @dev Unlike NudgeRatchet (which sweeps to the batchMinter here), this variant retains the
    ///      token so a releaser can later forward it via `release(amount)` at an admin-controlled
    ///      rate. The hook-type guard is preserved so the base's post-`_dispatch`
    ///      `hook.onDispatch` still accrues mint-debt through the correct hook. Tokens arrive via
    ///      the minter's transferFrom before `dispatch` is called. The `amount` argument is the
    ///      basis for that mint-debt accrual (handled by the base after this returns); nothing is
    ///      transferred here.
    function _dispatch(address, uint256 /* amount */, bytes calldata /* extraData */)
        internal
        override
    {
        // Audit M-04 (story 037): refuse to dispatch through a missing/wrong hook. A no-op or
        // unrelated hook lacks hookTypeId(), so this call reverts loudly.
        require(
            INudgeRatchetMintDebtHook(address(hook)).hookTypeId() == EXPECTED_HOOK_TYPE_ID,
            "NudgeRatchetDelayRelease: hook is not NudgeRatchetMintDebtHook"
        );
        // Intentionally NO transfer: USDC is HELD until a releaser calls release(amount).
    }
}
```

#### Notes on the target

- `_dispatch`'s `amount` and `extraData` params are intentionally unnamed (`/* amount */`) to
  avoid unused-parameter warnings, since nothing is transferred here. The base still passes the
  named `amount` to `hook.onDispatch` for debt accrual.
- `release` is `nonReentrant` (inherited guard) as cheap defense-in-depth even though a USDC
  `safeTransfer` to a protocol-owned sink won't re-enter. It is NOT `whenNotPaused` (see Concerns).
- `releasers` is a `public` mapping (free getter), mirroring `NFTMinterV2.authorizedMinters`.
- No new interface or hook file is needed — this dispatcher reuses the existing
  `NudgeRatchetMintDebtHook` / `INudgeRatchetMintDebtHook` unchanged.

#### Wiring (deploy / integration order — same shape as NudgeRatchet)

1. Deploy `NudgeRatchetDelayRelease(usdc, batchMinter, owner)`.
2. Deploy a **fresh** `NudgeRatchetMintDebtHook(owner, address(nudgeRatchetDelayRelease), phUSD)`.
   (The hook gates `onDispatch` to a single `dispatcher`, so this dispatcher needs its own hook
   instance — or repoint an existing one via `setDispatcher`. Do NOT share NudgeRatchet's hook
   instance.)
3. `nudgeRatchetDelayRelease.setHook(hook)` — replaces the default no-op hook.
4. `nudgeRatchetDelayRelease.setMinter(nftStaker)` — authorize the `NFTMinterV2`-style consumer.
5. `nudgeRatchetDelayRelease.setReleaser(releaserAddr, true)` — whitelist the release operator(s).
6. `hook.setRecipient(...)` when ready to realise phUSD via `pull()` (independent of releases).
7. Register the dispatcher in the NFT staker (`NFTMinterV2.registerDispatcher(dispatcher, price,
   growthBP)`), exactly as `NudgeRatchet`/`BalancerPoolerV2` are registered.

### Implementation Notes

- **TDD**: the repo CLAUDE.md mandates writing failing tests first. Model the test file on
  `test/NudgeRatchet.t.sol` (inline `MockUSDC` 6dp, `Mock18Decimals`, `MockMintable`, hook wiring,
  `NFTMinterV2` integration). Foundry (`forge build` / `forge test`).
- **Do not modify** `NudgeRatchet.sol`, `ATokenDispatcherV2.sol`, the hook, or its interface.
- Keep `phUSD` naming everywhere (never pxUSD).
- Per project rule [[project_yield_claim_nft_guard_concrete_not_base]], the hook-type guard and the
  releaser guard live on this **concrete** dispatcher, never on the base.
- Round-in-favour-of-protocol is not in play here (no fractional math); `release` moves exact units.

### Concerns

- **Decision — `_dispatch` drops the `bal >= amount` guard.** `NudgeRatchet` keeps a
  `require(bal >= amount)` because it transfers in `_dispatch` and must never forward *less* than
  the debt basis. `NudgeRatchetDelayRelease` transfers nothing in `_dispatch`, so there is nothing
  to under-forward at dispatch time and the guard would be meaningless (held balance accumulates
  across dispatches and would trivially satisfy it). Backing is instead conserved structurally:
  held USDC equals deposited USDC until a releaser moves it. Flagged because it diverges from the
  template.
- **Decision — `release(amount)` is NOT pause-gated.** Mirrors the `rescueERC20` precedent in
  `BalancerPoolerV2`/`Uniboost` (deliberately functional during a pause). Releasing to the
  protocol-owned `batchMinter` is benign even under emergency pause, and rate-control is an admin
  function. If the user prefers `release` to halt under pause, add `whenNotPaused` — flag at review.
- **Decision — `rescueERC20` can drain held USDC backing.** Added per the explicit request. Because
  this contract now *holds* USDC that backs accrued mint-debt, an owner `rescueERC20(_token, ...)`
  could leave debt under-backed. This is an accepted owner power (same trust model as `setBatchMinter`),
  documented in NatSpec; intended use is recovering non-`_token` assets. Not restricted to non-`_token`
  to keep parity with the sibling rescue functions.
- **Decision — debt logic unchanged / decoupled from release.** Per the user, the downstream staker
  realises phUSD independently of USDC releases. Debt still accrues against `amount` on dispatch via
  the unchanged base+hook; this story changes only the *USDC* path. No base/hook edits.
- **Decision — fresh hook instance per dispatcher.** The mint-debt hook gates `onDispatch` to a
  single `dispatcher`, so this dispatcher must wire to its own hook instance (deploy-time concern,
  documented in Wiring); the existing NudgeRatchet hook is not shared.
- **Worktree note — `Execution Type: existing_worktree`.** Assigned to the existing `ratchet`
  sprint (index 17), whose prior stories (035–038) are complete and likely merged; the sprint
  worktree may have been pruned. Execution may need to recreate `worktrees/yield-claim-nft/ratchet`
  from `sprint/ratchet` (or master, if already merged). Confirmed with user to reuse `ratchet`
  rather than a new `delayed-ratchet` sprint.

### Execution Notes

- **Minor deviation from verbatim source (flag at review):** the spec's `_dispatch` is not marked
  `view`. As written it triggers a new compiler `Warning (2018): Function state mutability can be
  restricted to view` (it only reads `hook`, performs no transfer). To satisfy the hard "NO new
  warnings" constraint, `_dispatch` was declared `view` in the override (a more-restrictive
  mutability override of the non-`view` base virtual, which Solidity permits). Behaviour is
  identical; the only change is the `view` keyword. All NatSpec/`@dev` blocks are transcribed
  verbatim. Baseline had 2 pre-existing `Warning (2018)` (in `NFTMinterV2.t.sol`, `poc-H-01.t.sol`);
  after this change the count is still 2 — none from the new files.

### Checklist

#### Contract: `NudgeRatchetDelayRelease`
- [x] Create `src/dispatchers/NudgeRatchetDelayRelease.sol` extending `ATokenDispatcherV2`, modeled on `NudgeRatchet.sol`.
- [x] Keep the constructor `(address token_, address batchMinter_, address initialOwner)` with the non-zero `batchMinter_` check and the 6-decimal USDC deploy guard.
- [x] Keep immutable `_token`, public `batchMinter`, `primeToken()`, `setBatchMinter(...)` (onlyOwner, non-zero, emits `BatchMinterUpdated`).
- [x] Keep the `EXPECTED_HOOK_TYPE_ID` constant and the M-04 hook-type `require` in `_dispatch`.
- [x] Transcribe the auditor-facing "KNOWN / ACCEPTED DESIGN PROPERTIES" `@dev` block (contract-level) and the `release`/`rescueERC20` `@dev` notes **verbatim**, so the intentional debt/release timing decoupling and the `rescueERC20`-drains-backing power are not re-surfaced as unintended audit findings.
- [x] Implement `_dispatch` to **hold** the token: keep ONLY the hook-type guard, perform NO transfer (mark `amount`/`extraData` params unused to avoid warnings).
- [x] Add `mapping(address => bool) public releasers` and `setReleaser(address, bool)` (onlyOwner, emits `ReleaserUpdated`).
- [x] Add the `onlyReleaser` modifier (`require(releasers[msg.sender], ...)`).
- [x] Add `release(uint256 amount)` — `onlyReleaser nonReentrant`, `safeTransfer(_token → batchMinter, amount)`, emits `Released`.
- [x] Add `rescueERC20(address token, address to, uint256 amount)` — onlyOwner, non-zero recipient, `safeTransfer` (mirror BalancerPoolerV2/Uniboost).
- [x] Do NOT re-declare `onlyMinter` / `whenNotPaused` / `nonReentrant` on `_dispatch`.
- [x] Do NOT modify `NudgeRatchet.sol`, `ATokenDispatcherV2.sol`, `NudgeRatchetMintDebtHook.sol`, or its interface.

#### Tests: `test/NudgeRatchetDelayRelease.t.sol`
- [x] Model on `test/NudgeRatchet.t.sol` (inline `MockUSDC` 6dp, `Mock18Decimals`, `MockMintable`, deploy + `setHook` + `setMinter` wiring).
- [x] Constructor: rejects zero `batchMinter`; rejects non-6-decimal token; sets `_token`/`batchMinter`.
- [x] `dispatch` **holds** USDC: after a dispatch the contract balance equals the dispatched `amount` and `batchMinter` received nothing.
- [x] `dispatch` still accrues mint-debt in the hook (`mintDebt` == scaled `amount`), proving debt logic is unchanged.
- [x] `dispatch` reverts via the M-04 hook-type guard when the wrong/no-op hook is set.
- [x] `dispatch` is only callable by the minter and only `whenNotPaused` (base modifiers intact).
- [x] `setReleaser(addr, true)` whitelists (emits `ReleaserUpdated`); `setReleaser(addr, false)` revokes; non-owner reverts.
- [x] `release(amount)` by a whitelisted releaser transfers exactly `amount` to `batchMinter`, leaves the remainder held, and emits `Released`.
- [x] `release` reverts for a non-releaser ("caller is not releaser").
- [x] `release` reverts (SafeERC20) when `amount` exceeds the held balance.
- [x] Partial release then a second release (rate-control scenario) moves the cumulative amount and conserves backing.
- [x] `rescueERC20` by owner recovers an arbitrary (non-`_token`) ERC20; reverts for non-owner; reverts on zero recipient.
- [x] Integration through `NFTMinterV2`: register dispatcher, run a mint → debt accrues + USDC held; a releaser then releases to `batchMinter`.
- [x] `forge build` passes with no new warnings; `forge test` passes (new suite green, existing suite unaffected).

---
### Review Results
**Review Date**: 2026-06-27T00:00:00Z
**Review Command**: review-work yield-claim-nft 43
**Review Status**: PASSED

#### Executive Summary
Clean, focused implementation. The diff since base commit `4f80541` is exactly the two prescribed
new files (`src/dispatchers/NudgeRatchetDelayRelease.sol`, `test/NudgeRatchetDelayRelease.t.sol`) —
pure additions, zero modifications, no forbidden files touched. All checklist items verified against
code. `forge build` succeeds with the same 2 pre-existing baseline warnings (none from new files);
full suite 418 tests pass (new suite green). Design aligns with the stated hold-then-release purpose;
mint-debt path is genuinely unchanged/decoupled. NudgeRatchet left intact as a sibling.

#### Validation Results
1. Base Commit Validation: ✓ (base is immediate predecessor on sprint/ratchet, only story in review for this sprint)
2. File Change Review: ✓ (2 prescribed new files, no forbidden modifications)
3. Claim Validation: ✓ (all checked checklist items verified; build/tests green)
4. Purpose Alignment: ✓ (ALIGNED — hold/release + rate-control achieved, debt decoupled)

#### Issues Found
None blocking. Reviewer notes for human judgment (NOT defects — flagged for sign-off):
- **`release` not pause-gated** (story-flagged decision): during emergency pause, dispatches halt
  but releasers can still move held USDC to `batchMinter`. If `batchMinter` were compromised, pause
  is not the lever — owner must revoke releasers / repoint batchMinter. Confirm this is acceptable.
- **Releasers are a fully-trusted role**: held USDC is fungible/pooled; a releaser can relocate the
  entire held balance at any rate (only failsafe is the aggregate balance check). Confirm releaser
  set is trusted to the same degree as owner. (Consistent with decoupling design.)
- **`_dispatch` declared `view`** (story-documented deviation): more-restrictive override of the
  non-view base virtual to avoid a new Warning(2018). Behaviour identical; benign.
- KNOWN/ACCEPTED design properties (held-USDC backing, debt/release timing decoupling,
  rescueERC20-can-drain-backing, slow release as admin choice) were NOT re-flagged — documented
  verbatim in NatSpec as intended.

#### Files Changed Since Base Commit (4f80541 → f46a5cb)
- `src/dispatchers/NudgeRatchetDelayRelease.sol` (new, +144)
- `test/NudgeRatchetDelayRelease.t.sol` (new, +410)
---


---

# FULL STORY DOCUMENT — story-029 (nft-staking; pin bump 5015f1b)

Path: `/home/justin/code/product-owner/stories/nft-staking/complete/multi-token-nudge/029-payment-token-as-nudge-token-budget-tracking.md`

## Make `paymentToken ∈ nudgeWhitelist` structurally safe in `BatchNFTMinterMultiToken`

Current Sprint: 9
Story Type: feature
Execution Type: new_worktree
Base Commit: 5015f1b45aa196bc3f1d4f994d7413624dc960a8
Base Commit Updated: 2026-07-25T15:57:09Z

### Story Overview

Permit the batch minter's payment token to also be a nudge-whitelisted reward token, and make that
construct **safe by construction** rather than merely forbidden. The mechanism is a swap of the refund's
source of truth: from `paymentToken.balanceOf(address(this))` (which conflates three unrelated pools) to a
**locally-tracked `budget`** that is provably the caller's money and nothing else, combined with holding the
minter's allowance at an **absolute, per-mint exact price** instead of `type(uint256).max`.

Consequences that follow: the runtime payment-token skip in `_snapshotRewards` is removed (the payment token
is paid out through the normal reward path like every other whitelisted token), the admin-time rejection in
`setNudgeTokenWhitelist` is relaxed, and steps 9 and 10 of `batchMint` swap order.

This closes audit submission **`ycn19h1`** (CONDITIONAL High) at its root rather than gating a symptom.

**Authoritative spec:** `/home/justin/code/product-owner/scratchpad/planning-docs/phoenix/yield-claim-nft/audit-19/phoenix-nft-staking-payment-token-as-nudge-token-plan.md`
(audit-side copy: `/home/justin/code/audits/docs/phoenix-nft-staking-payment-token-as-nudge-token-plan.md`).
**Read the plan in full before writing code.** This story is an execution wrapper around it, not a
replacement for it. Where this story and the plan disagree, the plan wins — except where this story's
"Concerns" section records a deliberate deviation.

**Supersedes:** `/home/justin/code/audits/docs/phoenix-nft-staking-batchminter-approval-cap-plan.md`.
That plan's single-line allowance cap is subsumed by §3.1 here in a strictly tighter form.
**Do not implement both.**

### Background

#### The defect

`batchMint` already runs in the correct order — the snapshot (step 4) precedes the caller's payment pull
(step 5), so `paymentToken.balanceOf(address(this))` at snapshot time is the uncontaminated nudge pot.
`_snapshotRewards` then throws that clean reading away with `if (rewardToken == paymentToken) continue;`.

**The defect is not ordering — it is step 10.** The refund is derived from `balanceOf`, and after the mint
loop that single number conflates three pools that no reordering can separate after the fact:

| Pool | Belongs to | Size |
|---|---|---|
| `P` — the standing nudge pot | the next qualifying batch | streamer-fed, unbounded |
| `A − C` — unspent caller budget | `msg.sender` | ≤ `paymentAmount` |
| `D` — this batch's own donations | the *next* claimant (donate-forward, §4.2) | per-batch |

Step 10 hands `P + (A − C) + D` to `msg.sender`. With `count = 1 < nudgeSize` the batch does not qualify,
`_payRewards` pays nothing, and the entire pot exits as "residual". That is `ycn19h1`: **190 USDC extracted
from a 200 USDC pot for a 1 wei payment**, repeatable on every refill.

#### Why it holds after the change

Let `P` = pot at snapshot, `A` = `paymentAmount`, `C` = Σ mint prices, `D` = this batch's own donations.

| Step | Payment-token balance |
|---|---|
| after flush + snapshot (`P` captured) | `P` |
| after pull | `P + A` |
| after loop | `P + A − C + D` |
| after refund of `A − C` | `P + D` |
| after payout of `P` (qualifying) | `D` |

- **Solvency** — the refund needs `A − C`; the balance holds `P + A − C + D ≥ A − C`. Always solvent.
- **Pot integrity** — `refund ≤ budget ≤ A`. The pot can never leave through the refund, for any `count`,
  any `nudgeSize`, any dispatcher index.
- **`ycn19h1` is dead** — `count = 1`, `qualifies == false` ⇒ snapshot `0`, no payout; `refund = A − C`;
  pot untouched. The `paymentAmount = 1 wei` call now reverts at
  `BatchMint__PaymentBudgetExhausted(0, price, 1)` — the allowance is capped at the *exact* price and
  cannot be topped up out of the pot.
- **Donate-forward survives** — `D` arrives after the snapshot and is not part of `budget`, so it stays
  behind for the next claimant. Unchanged for the payment token and every other whitelisted token.
- **No self-funding** — the caller's `A` arrives after the snapshot, so it can never be paid back to them
  as a reward.

### File Locations

Repo: `nft-staking` (registered as `nft-staking:reflax-mint/nft-staking`; upstream name is
`phoenix-nft-staking`). Base is `main` @ `d75229d` — **all plan line numbers verified exact, no drift.**

| File | Change |
|---|---|
| `src/BatchNFTMinterMultiToken.sol` | Primary. All of §3 + all of §9 NatSpec edits. |
| `docs/multi-token-nudge.md` | §4.1 rewritten, §4.2 annotated as unchanged, §3 step order swapped. |
| `test/BatchNFTMinterMultiTokenNudge.t.sol` | 4 §4.1-group tests flip; 2 donate-forward tests stay green. |
| `test/PoC_PaymentTokenCollision.t.sol` *(new)* | Ported `ycn19h1` red test. |
| `test/BatchNFTMinterMultiTokenBudget.t.sol` *(new)* | Core properties + token-behaviour independence + boundaries. |
| `test/BatchNFTMinterMultiTokenBudgetInvariant.t.sol` *(new)* | First invariant harness for this contract. |
| `test/mocks/MockNonDecrementingAllowanceERC20.sol` *(new)* | §8.7. |
| `test/mocks/MockITokenMinterV2.sol` | Extend to record observed allowance per mint (§8.8). |

**Out of scope — do not touch:** `src/BatchNFTMinter.sol` (frozen, deployed, unfixable),
`test/BatchNFTMinter.t.sol`, `test/BatchNFTMinterNudge.t.sol`.

#### `src/BatchNFTMinterMultiToken.sol` line map (594 lines, @ `d75229d`)

| Site | Lines |
|---|---|
| Header — "pre-approves the minter for `type(uint256).max`" | 16–20 (phrase on 19) |
| Header — "admin time … structurally impossible to exploit" | 44–50 |
| Header — "honeypot framing does not apply" (keep; §6 cites it) | 61–70 |
| Header — dust-sweep paragraph | 72–77 |
| `DUST_THRESHOLD = 1e6` | 97–100 (decl on 100) |
| Custom-error block | 138–170 |
| `setNudgeTokenWhitelist` payment-token rejection | 253–256 |
| `batchMint` NatSpec — "derived payment token can never be whitelisted…" | 335–343 |
| `batchMint` NatSpec — `@param minRewards` | 370–387 |
| §4.2 `DO NOT "SIMPLIFY" THIS` block (shout line on 409) | 407–430 |
| Step 3.5 streamer flush | 437–451 |
| Step 4 `_snapshotRewards` call site | 453 |
| Step 5 pull | 455–456 |
| Steps 6/7/8 approve-max, loop, revoke | 458–467 |
| Step 9 payout | 469–477 |
| Step 10 dust sweep | 479–486 |
| `_resolvePaymentPath` NatSpec / body / `configs` read | 489–493 / 494–510 / 507 |
| `_snapshotRewards` NatSpec / sig / skip line | 512–548 / 549–553 / **558** |
| `_payRewards` NatSpec (names the runtime skip) / body | 568–583 / 584–593 |

### Technical Details

#### `INFTMinterV2.configs` — destructuring verified

Already imported at line 5:
```solidity
import {INFTMinterV2} from "yield-claim-nft/interfaces/INFTMinterV2.sol";
```
and already used with the exact idiom at line 507:
```solidity
(address dispatcher,,,) = INFTMinterV2(address(nftMinter)).configs(_dispatcherIndex);
```

Interface (`lib/mutable/yield-claim-nft/src/interfaces/INFTMinterV2.sol:86-90`):
```solidity
function configs(uint256 index)
    external view
    returns (address dispatcher, uint256 price, uint256 growthBasisPoints, bool disabled);
```

So `(, uint256 price,,)` yields `config.price` — **correct, no new import needed.**

#### Why the price must be re-read every iteration

`NFTMinterV2._executeMint` (`lib/mutable/yield-claim-nft/src/NFTMinterV2.sol:171-202`):
- `:179` `uint256 price = config.price;`
- `:183` `IERC20(token).safeTransferFrom(msg.sender, config.dispatcher, price);` ← the charge
- `:188` `config.price = price + (price * config.growthBasisPoints) / 10000;` ← the ramp

`configs` is read *before* the charge, so a pre-mint `configs()` read returns exactly what that mint will
charge. The price changes under us every iteration and must be re-read, not extrapolated.

#### Current source — `batchMint` steps 4–10 (453–487)

```solidity
        uint256[] memory snapshot = _snapshotRewards(minRewards, address(paymentToken), qualifies);

        // --- 5. Pull the caller's payment budget. ---
        paymentToken.safeTransferFrom(msg.sender, address(this), paymentAmount);

        // --- 6. Approve the pinned minter for the loop. ---
        paymentToken.forceApprove(address(nftMinter), type(uint256).max);

        // --- 7. Mint loop. ---
        for (uint256 i; i < count; ++i) {
            nftMinter.mint(_dispatcherIndex, recipient);
        }

        // --- 8. Revoke the approval. ---
        paymentToken.forceApprove(address(nftMinter), 0);

        // --- 9. Payout pass. ---
        //
        // `snapshot` was captured BEFORE the mint loop above and is deliberately
        // NOT re-read here. ... (comment retained, see 469-476)
        _payRewards(recipient, snapshot);

        // --- 10. Dust sweep of residual payment token back to msg.sender. ---
        uint256 remaining = paymentToken.balanceOf(address(this));
        if (remaining / DUST_THRESHOLD != 0) {
            paymentToken.safeTransfer(msg.sender, remaining);
            totalPaid = paymentAmount > remaining ? paymentAmount - remaining : 0;
        } else {
            totalPaid = paymentAmount;
        }
    }
```

#### Current source — `_snapshotRewards` (549–566)

```solidity
    function _snapshotRewards(uint256[] calldata minRewards, address paymentToken, bool qualifies)
        private view returns (uint256[] memory snapshot)
    {
        uint256 tokenCount = _nudgeTokens.length;
        snapshot = new uint256[](tokenCount);
        for (uint256 i; i < tokenCount; ++i) {
            address rewardToken = _nudgeTokens[i];
            if (rewardToken == paymentToken) continue;
            uint256 available = qualifies ? IERC20(rewardToken).balanceOf(address(this)) : 0;
            uint256 minReward = minRewards[i];
            if (available < minReward) {
                revert BatchMint__RewardBelowMinimum(rewardToken, minReward, available);
            }
            snapshot[i] = available;
        }
    }
```

#### Target — §3.1 replacement for steps 6–8

```solidity
        // --- 6 + 7. Mint loop, allowance held at the EXACT next mint price. ---
        //
        // `budget` is THIS CALLER'S money and nothing else. It is decremented by
        // the authoritative price the minter is about to charge, so it never
        // observes the pot, never observes this batch's own donations, and is
        // the ONLY source of the refund in step 9. DO NOT re-derive it from
        // `balanceOf` — that is the exact conflation this design removes.
        //
        // Every `forceApprove` below sets an ABSOLUTE target, never a delta.
        // For a well-behaved ERC20 that decrements allowance on `transferFrom`
        // the write is idempotent; for one that does NOT decrement it is
        // corrective. Correctness therefore does not depend on the token's
        // allowance-decrement behaviour at all.
        uint256 budget = paymentAmount;
        for (uint256 i; i < count; ++i) {
            (, uint256 price,,) = INFTMinterV2(address(nftMinter)).configs(_dispatcherIndex);
            if (price > budget) revert BatchMint__PaymentBudgetExhausted(i, price, budget);
            paymentToken.forceApprove(address(nftMinter), price);
            budget -= price;
            nftMinter.mint(_dispatcherIndex, recipient);
        }

        // --- 8. Revoke. Absolute and idempotent: zeroes any allowance a
        //        non-decrementing token left standing after the final mint. ---
        paymentToken.forceApprove(address(nftMinter), 0);
```

New error, appended after `BatchMint__RewardBelowMinimum` (line 170), matching the block's
`/// @dev Reverted when …` convention:

```solidity
    /// @dev Reverted when the caller's remaining budget cannot cover the next
    ///      mint's price. Replaces the opaque ERC20 allowance/balance revert that
    ///      an under-funded batch used to produce.
    error BatchMint__PaymentBudgetExhausted(uint256 mintIndex, uint256 price, uint256 remaining);
```

#### Target — §3.3 refund before payout

```solidity
        // --- 9. Refund the caller's UNSPENT BUDGET. Not a balance sweep. ---
        //
        // ORDER IS LOAD-BEARING: the caller's own money is returned BEFORE the
        // pot is distributed, so a payout can never be funded out of a refund
        // that is owed, and vice versa.
        //
        // `refund <= paymentAmount` HOLDS BY CONSTRUCTION, because `budget`
        // starts at `paymentAmount` and only ever decreases. The `available`
        // cap is a fail-safe for fee-on-transfer / rounding shortfall ONLY: it
        // can lower the refund, never raise it, and is never the source.
        uint256 available = paymentToken.balanceOf(address(this));
        uint256 refund = budget > available ? available : budget;
        if (refund / DUST_THRESHOLD != 0) {
            paymentToken.safeTransfer(msg.sender, refund);
            totalPaid = paymentAmount - refund;
        } else {
            totalPaid = paymentAmount;
        }

        // --- 10. Payout pass (see the §4.2 note on `_snapshotRewards`). ---
        _payRewards(recipient, snapshot);
```

`totalPaid` loses its `>` floor guard: `refund <= budget <= paymentAmount` makes `paymentAmount - refund`
unconditionally safe. That guard existing at all was the contract admitting the refund could exceed the
contribution; **its removal is the visible marker that the property now holds.** Do not reinstate it.

#### Build / test commands (repo `CLAUDE.md`)

```
forge build
forge test            # or -vvv
forge test --match-contract <ContractName>
forge test --match-test <testName>
forge fmt
forge snapshot
```

Hard repo rules that bind this story:
- **TDD mandatory** — red → green → refactor, Foundry only. No Hardhat/Truffle.
- **No `script/` directory.** Never add `script/*.s.sol`, broadcast config, RPC URL or private key.
  Deploy work belongs in `../phase-2-staging`.
- **`lib/mutable/` is interfaces only** — never reach into implementations. Reading
  `INFTMinterV2.configs` is compliant; reading `NFTMinterV2.sol` is for *justification only*, not for
  import. A cross-submodule interface change requires stopping and telling the user.
- OZ for anything standard; Solidity `^0.8.20`; keep `remappings.txt` in sync (`forge remappings > remappings.txt`).

#### Test conventions

No shared base test contract — each file declares its own `setUp()` and re-declares expected events.
`contract X is Test` (forge-std), pragma `^0.8.20`, SPDX MIT.

Standard fixture: `BatchNFTMinterMultiToken batch`, `MockITokenMinterV2 nftMinter`,
`MockTokenDispatcherV2 dispatcher`, `MockERC1155 nft`, `MockERC20 payToken`/`nudgeToken`/`rewardA,B,C`.
Constants: `DISPATCHER_INDEX = 7`, `START_PRICE = 1_000 ether`, `GROWTH_BPS = 250`, `NUDGE_SIZE = 5`,
`NUDGE_FUNDED_AMOUNT = 50_000 ether`. Actors: `owner = makeAddr("batchOwner")`, `caller = address(0xCAFE)`,
`recipient = address(0xBEEF)`, `pauser = makeAddr("batchPauser")`, `attacker = makeAddr("attacker")`.
Helpers in `BatchNFTMinterMultiTokenNudge.t.sol`: `_whitelist`, `_fundPots`, `_costNow(count)`, `_mins(...)`.
Naming: `test_<Property>`, `test_RevertWhen_<Condition>`. PoC precedent: `test/PoC_DepletionRateDrift.t.sol`.
Newest / cleanest template: `test/BatchNFTMinterMultiTokenNudgeStream.t.sol` (story 028).

Existing mocks under `test/mocks/`: `MockERC20`, `MockFeeOnTransferERC20` (covers §8.9),
`MockITokenMinterV2` (the workhorse — `configs`, `getPrice`, `setConfig`, `setPerMintDonation(s)`,
`setRevertAtCall`, `mintCallCount`, `donationCount`), `MockNoopMinter`, `MockReentrantERC20`,
`MockNudgeDonor`, `MockTokenDispatcherV2`, `MockERC1155`, `MockNFTMinter`,
`MockBalancerPoolerMintDebtHook`, `MockUniboostMintDebtHook`.

**Gaps this story must fill:** no non-decrementing-allowance ERC20 mock exists; `MockITokenMinterV2` does
not record observed allowances; there is no invariant harness for the batch minter (use
`test/NFTStakerSolvency.t.sol` as the `StdInvariant` pattern).

### Implementation Notes

- **`MockITokenMinterV2` ramp mismatch.** The mock ramps `c.price = price * (10_000 + g) / 10_000`; the real
  `NFTMinterV2` uses `price + (price * g) / 10000`. Arithmetically equal, but the intermediate rounding
  differs. This matters for the §8.2 "exactly" assertion — either align the mock to the real formula
  (preferred) or assert against the mock's own cumulative sum rather than a locally recomputed one.
- **`getPrice` alternative.** `ITokenMinterV2.getPrice(index)` is already on the pinned `nftMinter` type
  (`NFTMinterV2.sol:277-278`) and would avoid the `INFTMinterV2` cast. Either is acceptable; the plan's
  `configs` destructuring is specified and already precedented at line 507, so prefer it unless the cast
  proves awkward.
- **Do not take the gas optimisation.** Computing the ramp locally instead of re-reading `configs` is
  explicitly permitted by the plan *only* with a differential test pinning batcher arithmetic against the
  minter across ≥32 iterations. Default to re-reading — it keeps correctness by construction rather than
  by convention. If you do take it, the differential test is mandatory, not optional.
- **Gas is a deliberate regression.** One `configs` staticcall + one `forceApprove` SSTORE per mint,
  replacing two SSTOREs per batch — roughly `20 × (2.1k + 5k)` extra at `count = 20`. The batcher is a
  convenience wrapper, not a hot path, and the cost buys token-behaviour independence. Record the delta in
  a `forge snapshot`; do not treat it as a defect.
- **Under-quoting front-ends now revert loudly.** A batch that previously drew silently on contract balance
  gets `BatchMint__PaymentBudgetExhausted` naming the failing mint index and the shortfall. This is the
  intended regression and the reason the error carries all three values.
- **`_payRewards` NatSpec (580–583)** names "the entry was runtime-skipped as the current payment token" —
  it is in scope for §9 even though the plan's table does not list it.
- **`_snapshotRewards` signature shrinks** to `(uint256[] calldata minRewards, bool qualifies)`; there is
  exactly one call site (line 453).
- **PoC porting.** `run19-Tier3Nudge.t.sol` (pre-applied, easier than the `.patch`) is at
  `/home/justin/code/audits/reports/yield-claim-nft-19/pocs/run19-Tier3Nudge.t.sol`. Porting
  `Run19_T1_PaymentTokenCollision` requires its `Run19Base` fixture too. **PoC convention is
  PASS = defect reproduced**, so this test must flip red→green-by-reverting; a PoC that merely stops
  *compiling* is inconclusive bit-rot, not a fix.
- **`PoC_EconZeroPaymentSweep.t.sol` does not exist in this repo.** It is audit-side only
  (`/home/justin/code/audits/reports/phoenix-nft-staking-21/poc-replay.md:273`). See Concerns.

### Checklist

#### Phase 0 — Setup and pre-flight

- [x] Confirm worktree is `worktrees/nft-staking/multi-token-nudge` on branch `sprint/multi-token-nudge`,
      forked from `main` @ `d75229d` (story 028's HEAD).
- [x] Read the plan document in full before writing any code.
- [x] Confirm `src/BatchNFTMinterMultiToken.sol` line numbers still match the map above; if the file has
      drifted, re-anchor by symbol rather than line number.
- [x] `forge build` and `forge test` green on the untouched base. Capture a `forge snapshot` baseline into
      `scratchpad/validation-logs/story-029-gas-snapshot-baseline.txt`.

#### Phase 1 — RED (tests first, must fail)

- [x] Port `Run19_T1_PaymentTokenCollision` (+ its `Run19Base` fixture) into
      `test/PoC_PaymentTokenCollision.t.sol` as
      `test_PaymentTokenAsNudge_nonQualifyingBatchTakesNothing`: 20 honest mints seed a 200 USDC pot via
      the real `NudgeStreamer`; `setDispatcherIndex` to the USDC-prime index; attacker calls
      `batchMint(1, attacker, 1, …)`.
- [x] Confirm it **reproduces the defect on the unmodified contract** (extracts 190 USDC). Record the
      failing output in `scratchpad/validation-logs/story-029-red-phase.txt`.
- [x] Write `test_RefundEqualsUnspentBudgetExactly` — over-supply `paymentAmount` against a fat pot on a
      `growthBasisPoints > 0` dispatcher; assert `refund == paymentAmount − Σprices` **exactly** and pot
      delta `== −P` (qualifying) or `== 0` (non-qualifying).
- [x] Write `test_PaymentTokenAsNudge_qualifyingBatchIsPaidThePot` — `count >= nudgeSize` pays `P` to
      `recipient` via `_payRewards`, emitting `NudgePaid` for the payment token.
- [x] Write `test_OwnDonationsDoNotRefundToBatcher_paymentTokenArm` — `D` stays in the contract, is not
      refunded and is not paid to `recipient`.
- [x] Confirm all Phase 1 tests fail for the right reasons before proceeding.

#### Phase 2 — GREEN (§3 implementation)

- [x] §3.1 — replace steps 6–8 with the budget-tracked loop and per-mint absolute `forceApprove`.
- [x] §3.1 — add `error BatchMint__PaymentBudgetExhausted(uint256 mintIndex, uint256 price, uint256 remaining);`
      after line 170, with matching `/// @dev Reverted when …` NatSpec.
- [x] §3.2 — delete the `if (rewardToken == paymentToken) continue;` skip at line 558.
- [x] §3.2 — drop the now-unused `paymentToken` parameter from `_snapshotRewards` and update the call site
      at line 453.
- [x] §3.3 — swap steps 9 and 10; rewrite the sweep as a `budget`-sourced refund capped by `available`.
- [x] §3.3 — remove the `paymentAmount > remaining ? … : 0` floor guard from `totalPaid`.
- [x] §5.1 — relax `setNudgeTokenWhitelist`'s payment-token rejection (253–256). Either keep
      `BatchMint__RewardTokenIsPaymentToken` behind a comment marking it defence-in-depth for a release or
      two, or remove it — record which in Concerns. **Relaxing it is the point of the plan.**
- [x] `forge build` clean; `forge fmt`.
- [x] All Phase 1 tests now pass (the PoC by reverting `BatchMint__PaymentBudgetExhausted(0, price, 1)`).

#### Phase 3 — Invariants and token-behaviour independence

- [x] New mock `test/mocks/MockNonDecrementingAllowanceERC20.sol` whose `transferFrom` does **not**
      decrement allowance.
- [x] `test_NonDecrementingAllowanceToken_refundUnaffected` — refund identical to the well-behaved case,
      and `allowance(batch, minter) == 0` on exit.
- [x] Extend `MockITokenMinterV2` to record the allowance observed at each `mint` call (e.g.
      `uint256[] observedAllowances`), or add a dedicated recording mock.
- [x] `test_ApprovalIsAbsoluteNotDelta` — `allowance(batch, minter) == price_i` immediately before each
      inner mint, and `== 0` after the loop.
- [x] `test_FeeOnTransferPaymentToken_refundCapsAtAvailable` using `MockFeeOnTransferERC20` — pins
      `available` as a **cap**: refund shrinks, pot untouched, nothing reverts.
- [x] `invariant_RefundNeverExceedsPaymentAmount` — Foundry invariant over fuzzed
      `count`/`paymentAmount`/`nudgeSize`/pot. (Run-20 D-35 required this property be *established and
      tested*, not shipped as an unvalidated patch.)
- [x] `invariant_PotOnlyLeavesViaQualifyingPayout` — pot delta is `0` or `−P`, never partial.
- [x] Both invariants use `StdInvariant`, patterned on `test/NFTStakerSolvency.t.sol`.

#### Phase 4 — Boundaries and regression

- [x] Cumulative charge exactly equal to `paymentAmount` succeeds.
- [x] One wei short reverts `BatchMint__PaymentBudgetExhausted` at the **correct `mintIndex`**.
- [x] Ramping-price control (`growthBasisPoints > 0`) — caller must pass the true cumulative amount; the
      surplus refund still returns the excess.
- [x] Flip the four now-falsified tests in `test/BatchNFTMinterMultiTokenNudge.t.sol` §4.1 group
      (lines 159–294): `test_RevertWhen_WhitelistingPaymentToken` (167),
      `test_RuntimePaymentTokenCollisionIsSkippedNotReverted` (185 — this one currently *asserts*
      `ycn19h1` as correct behaviour), `test_RuntimeSkipAlsoAppliesBelowThreshold` (222),
      `test_PaymentTokenDustNotClaimableAsReward` (245). Rewrite them to assert the new contract, do not
      delete them.
- [x] Confirm `test_OwnDonationsDoNotRefundToBatcher` (295) and
      `test_SecondBatcherReceivesFirstBatchersDonations` (340) remain green **unmodified**.
- [x] Confirm `test/BatchNFTMinter.t.sol` and `test/BatchNFTMinterNudge.t.sol` (frozen twin) are untouched
      and still green.
- [x] Full `forge test` suite green. New `forge snapshot` recorded; gas delta documented in
      `scratchpad/validation-logs/story-029-gas-snapshot-after.txt`.

#### Phase 5 — Documentation (§9, mandatory, same commit as §3)

The contract currently tells the owner the exclusion is guaranteed *by construction*. Three claims become
wrong and one is inverted.

- [x] `:16-20` header — "pre-approves the minter for `type(uint256).max`" → per-mint exact approval.
- [x] `:44-50` header — "vetting the token set at admin time … structurally impossible to exploit" →
      rewrite: the conflict is **permitted and safe**, because the refund derives from a tracked budget
      rather than a balance.
- [x] `:72-77` header — dust-sweep paragraph, re-word for the budget refund.
- [x] `:335-343` — **delete.** "The derived payment token can never be whitelisted… the snapshot loop
      SKIPS that entry at runtime… while still keeping the payment-token balance out of the payout."
      This is the sentence that was affirmatively false at `d75229d`.
- [x] `:370-387` `@param minRewards` — delete the "…including any entry currently equal to the derived
      payment token, whose floor is ignored" clause. The floor is now live for that entry.
- [x] `:489-493` `_resolvePaymentPath` — rewrite or delete the "by construction, not by convention"
      claim, in step with the relaxed admin check.
- [x] `:512-548` / `:531-541` `_snapshotRewards` — **delete** "…skipping keeps `batchMint` live instead of
      bricking it, while the payment-token balance stays out of the payout." This is the property
      `ycn19h1` proved does not hold; it must not survive as a stale comment.
- [x] `:580-583` `_payRewards` — remove the "runtime-skipped as the current payment token" language.
- [x] **New**, at the loop: the **DO NOT re-derive `budget` from `balanceOf`** warning verbatim from §3.1,
      in the style of the existing §4.2 `DO NOT "SIMPLIFY" THIS` block (line 409).
- [x] **New**, at step 9: the **ORDER IS LOAD-BEARING** note — the snapshot must stay before the pull,
      and the refund before the payout. Two ordering constraints now hold this function up, not one.
- [x] `docs/multi-token-nudge.md` §4.1 (line 156, body to 183) — rewritten; the "Two distinct failures the
      pair prevents" list naming the step-5 pull and step-10 sweep is falsified and must go.
- [x] `docs/multi-token-nudge.md` §4.2 (line 185, body to 203) — substance unchanged; **say so explicitly.**
- [x] `docs/multi-token-nudge.md` §3 "Execution order (normative)" (line 127; step 10 described at 152) —
      swap steps 9 and 10.
- [x] Leave the §6 "honeypot framing does not apply" quote at `:61-70` **intact** — the arbitrage
      acceptance (below) cites it.

#### Phase 6 — Close-out

- [x] `forge fmt` and full suite green one final time.
- [x] All commits use `[story-029] <message>`.
- [x] Write a completion summary to
      `scratchpad/analysis-reports/nft-staking-story-029-completion-summary.md` covering: which §5.1
      option was taken (keep vs remove the admin guard), the gas delta, whether the `configs` re-read
      optimisation was taken, and the resolution of each Concern below.

### Concerns

Decisions taken during planning, per the plan's own §5 "consequences to accept" plus gaps found in the repo:

- **`PoC_EconZeroPaymentSweep.t.sol` (plan §8.12) does not exist in this repo.** It is audit-authored and
  lives only in the audit workspace (`/home/justin/code/audits/reports/phoenix-nft-staking-21/poc-replay.md:273`).
  **Decision:** treat §8.12 as *not blocking* this story. Verify the equivalent property with the ported
  `Run19_T1` PoC instead, and note in the completion summary that the audit-side
  `PoC_ZeroPaymentSweep_MultiToken` re-run must be done in the audit workspace by the auditor. The
  `PoC_ZeroPaymentSweep_DeployedBatchNFTMinter` arm is *expected to keep reproducing* — the deployed twin
  is frozen and unfixed, and its continuing to pass is the correct result.
- **Sprint/branch choice.** `complete/multi-token-nudge/` already exists (story 025 lineage). The story is
  nonetheless filed under sprint 9 `multi-token-nudge` because that is the sprint this contract's nudge
  work belongs to and the sprint name must match the worktree/branch. A fresh sprint was not created.
- **Dependency on story 028 (sprint 13, `nudge-streamer`, in review).** 028 wired the `NudgeStreamer`
  flush at `batchMint` step 3.5, directly upstream of everything this story rewrites, and its commits are
  `d75229d` = base `HEAD`. This story forks off it cleanly. **028 must not be reverted or re-worked while
  029 is in flight**; if 028 fails review, re-base 029 before continuing.
- **`setNudgeTokenWhitelist` guard — keep or remove?** The plan permits either. **Decision:** keep
  `BatchMint__RewardTokenIsPaymentToken` for now behind an explicit defence-in-depth comment, so the
  admin-time surface changes in one release and the runtime surface in another. If the executing agent
  finds this makes the §4.1 test rewrite incoherent, removing it is also acceptable — record which was
  chosen.
- **Same-denomination nudge arbitrage is ACCEPTED, owner decision 2026-07-25. DO NOT RE-FILE.**
  Once the payment token is a nudge token, cost and reward share a denomination, so `pot > Σ(nudgeSize
  mint prices)` becomes arithmetic any bot can do in one `eth_call`. This is intended: the pot is by
  construction a fraction of the cost of the qualifying mints, so every claim is net-positive for the
  protocol. Making the arithmetic legible does not change the economics. **Still reportable, and out of
  scope for this acceptance:** any path where the pot leaves without the caller paying for `nudgeSize`
  real mints; any path where `refund > paymentAmount`; any path where a non-qualifying batch extracts
  pot-sized value; and the aggregate over-funding class.
- **Ledger consequences are the auditor's to apply, not this story's.** For the record: `ad36260f…`
  (M-07, approval) moves `wont-fix` → **`fix-pending`** because this plan splits it from the `a62fe01a…`
  dedupe. `fcaca0025…` and `7a1718e9a…` stay `wont-fix` (scoped to the frozen deployed twin).
  `2d34673536…` / `ycn19h1` stay open until §8 passes. `fb17fc6d07…` (M-06, `setDispatcherIndex` guard)
  stays open and should be re-weighed to QA *after* this lands, **not before** — it is live at `d75229d`.
- **Operational pre-flight is outside this story but blocks shipping.** Before any code ships, someone
  must read `dispatcherIndex` on the deployed instance, resolve that index's dispatcher `primeToken()`,
  and test it with `isNudgeToken(...)`. A whitelisted result means the pot is drainable *now* and
  operational action precedes the code change. Also still open: `919b71fd…` — `pauser() == address(0)`
  on both live instances; setting a non-zero pauser is free and immediate.
- **The frozen deployed `src/BatchNFTMinter.sol` is untouched and unfixable.** Compensating control: do
  not route payment token to either live instance.

### Autonomous Decisions

Recorded during headless execution on 2026-07-25. Nothing below changed the
story's scope; each is a fork in the road resolved without stopping.

#### 1. §5.1 — the admin guard was KEPT (matches the Concerns decision)

**Situation.** The plan permits either keeping or removing
`BatchMint__RewardTokenIsPaymentToken`; the story's Concerns pre-decided "keep,
behind an explicit defence-in-depth comment", with removal allowed if keeping it
made the §4.1 test rewrite incoherent.

**Decision.** Kept. Keeping it is *more* coherent, not less: the collision now
has to be reached the way production reaches it — by repointing
`tokenMinter`/`dispatcherIndex` out from under an existing whitelist entry — which
is exactly the scenario `ycn19h1` describes. Every new test builds its fixture
that way (whitelist while the dispatcher points elsewhere, then repoint), so the
guard is exercised rather than worked around, and
`test_RevertWhen_WhitelistingPaymentToken` survives with only a rewritten
rationale.

**Alternatives.** Removing it would have let the fixtures whitelist the payment
token in one call. Marginally shorter setup, but it would have deleted the only
test proving the admin surface still narrows the blast radius, and it would have
moved both surfaces in one release — the thing the Concerns decision exists to
avoid.

#### 2. The `MockITokenMinterV2` ramp "mismatch" does not exist

**Situation.** The story's Implementation Notes warn that the mock's
`price * (10_000 + g) / 10_000` and the real `NFTMinterV2`'s
`price + (price * g) / 10000` are "arithmetically equal, but the intermediate
rounding differs", and that this matters for the §8.2 "exactly" assertions.

**Decision.** Took the preferred remedy (aligned the mock to the real formula),
but the premise is false and the story should not carry it forward. The two are
**bit-identical for every input**: `p * (10000 + g) / 10000 = p + p*g/10000`, and
for integer `p`, `floor(p + x) = p + floor(x)`. There is no divergent rounding to
be exposed. Empirical confirmation: aligning the mock changed **zero** of the 509
pre-existing tests, including `test_gas_batchMintN_25` and
`test_NoRewardWhenNudgeSizeZero` (count = 25), which exercise 25 successive ramp
applications where any rounding difference would have compounded.

**Rationale for aligning anyway.** Free, and it pins the "exactly" assertions
against the real minter's expression rather than a paraphrase of it. It also
slightly reduces overflow headroom risk (`p * g` overflows later than
`p * (10000 + g)`).

#### 3. A dedicated recording mock, not a flag on `MockITokenMinterV2`

**Situation.** §8.8 needs the allowance observed at the head of each `mint`. The
story allows either extending the shared mock or adding a dedicated one.

**Decision.** Added `test/mocks/MockAllowanceRecordingMinterV2.sol`.
`MockITokenMinterV2` drives 500+ tests and every gas benchmark; an extra
`SLOAD`/`SSTORE` per mint there — even behind an opt-in flag — would have
contaminated the story-029 gas delta with a test-harness artefact, and the delta
is a required deliverable.

**Alternative considered.** Making `mint` `virtual` and overriding it in a
subclass. Rejected: `external` -> `public virtual` changes calldata handling and
would still have moved the shared mock's numbers.

#### 4. Two falsified tests beyond the story's list of four

**Situation.** The story enumerates four §4.1-group tests to rewrite. Two more
were falsified by the change and were not listed.

**Decisions.**
- `test/BatchNFTMinterMultiTokenCore.t.sol::test_batchMint_donationToHelperFlowsToCaller`
  **failed** after §3.3. It asserted `callerBefore - expected + donation` — that a
  third-party payment-token donation returns to the caller as a windfall. That
  behaviour *is* the `ycn19h1` mechanism (once the payment token is a nudge token,
  "donation" includes the whole pot). Rewritten as
  `test_batchMint_donationToHelperStaysForTheNextClaimant`.
- `test/BatchNFTMinterMultiTokenNudgeCore.t.sol::test_batchMint_paysNudgeBeforeRefundSweep`
  still **passed** — its assertions are order-agnostic by design — but its name and
  section header asserted the step order §3.3 reverses. Renamed to
  `test_batchMint_refundsBudgetAndPaysNudge` with the header corrected. Leaving a
  green test whose name states a falsified ordering is exactly the stale-comment
  failure mode Phase 5 exists to prevent.

#### 5. No StdInvariant precedent exists in this repo

**Situation.** The story and the execution brief both cite
`test/NFTStakerSolvency.t.sol` as the `StdInvariant` pattern to follow.

**Decision.** That file contains no invariant harness — no `StdInvariant` import
and no `invariant_*` function. `grep -rn "StdInvariant\|invariant_" test/` at
`d75229d` returns exactly one hit: a *unit* test named
`test_solvency_invariant_holds_after_every_state_change`. There is no
`StdInvariant` harness anywhere in the repo, so
`test/BatchNFTMinterMultiTokenBudgetInvariant.t.sol` is genuinely the first, and
was built from `forge-std/StdInvariant.sol` directly using the standard
handler + `targetSelector` pattern. `NFTStakerSolvency.t.sol` was still used as
the naming/prose model.

**Design choices inside the harness.** Violations are recorded into sticky
booleans rather than asserted inline, so one bad sequence cannot be masked by a
later good one and Foundry shrinks against the invariant rather than a handler
revert. `afterInvariant()` carries anti-vacuity tripwires requiring the
qualifying branch, the non-qualifying branch AND the revert branch to have all
been exercised — without them, both invariants could pass over a run in which
every call reverted.

#### 6. Stack-too-deep: block scoping, NOT `via_ir` or the optimizer

**Situation.** The §3.1 + §3.3 locals (`budget`, `available`, `refund`) pushed
`batchMint` past the legacy code generator's stack limit:
`Stack too deep. Try compiling with --via-ir ... while enabling the optimizer.`

**Decision.** Block-scoped the step-3.5 streamer flush and the step-9 refund, and
left the build configuration alone. Two comments in the source say why the braces
are there, so a future reader does not "tidy" them away.

**Rationale.** Enabling `via_ir` or the optimizer would have moved every number in
the gas snapshot, invalidating the baseline captured in Phase 0 and the delta the
story requires. It is also independently hazardous here: `via_ir` caches
`block.timestamp`, which breaks repeated `vm.warp` — and the `NudgeStreamer`
tests warp repeatedly.

#### 7. Gas delta is ~3.7x the plan's estimate; kept the design regardless

**Situation.** Plan §5.4 estimates roughly `20 x (2.1k + 5k)` extra at
`count = 20`, i.e. ~7.1k per mint. Measured marginal cost is **~26k per mint**
(`batchMintN_25`: 520,111 -> 1,170,867).

**Decision.** Kept the design exactly as specified and documented the true cost
rather than optimising toward the estimate.

**Cause.** The plan assumed the per-iteration allowance write is a 2,900-gas
non-zero -> non-zero `SSTORE`. It is not: each `mint`'s `transferFrom` *consumes*
the allowance, zeroing the slot, so the next iteration writes `0 -> price` with
`current == original == 0` and pays `SSTORE_SET` (20,000). The figures are gross
of EIP-3529 refunds, so real net cost is lower. Full breakdown in
`scratchpad/validation-logs/story-029-gas-snapshot-after.txt`.

**Not clawed back.** The obvious saving — one up-front
`forceApprove(paymentAmount)` — is the superseded
`batchminter-approval-cap-plan` this plan explicitly replaces "in a strictly
tighter form", and it would reinstate the property the change exists to remove.

#### 8. The `configs` re-read optimisation was NOT taken

Per the story's explicit instruction. `configs(dispatcherIndex)` is read fresh on
every iteration; the ramp is never extrapolated locally. No differential test was
therefore required (it is mandatory only if the optimisation is taken).

#### 9. PoC port: mocks for the `yield-claim-nft` implementations

**Situation.** `Run19_T1_PaymentTokenCollision` imports `NFTMinterV2`,
`NudgeRatchet`, `NudgeRatchetDelayRelease`, `Uniboost` and `GatherV2` from
`yield-claim-nft`. This repo exposes that sibling as **interfaces only**
(`lib/mutable/`), so importing them is prohibited.

**Decision.** Ported using this repo's `MockITokenMinterV2` /
`MockTokenDispatcherV2` for the minter and the two dispatchers (USDC-prime at
index 1, PAY-prime at index 7), while keeping the **real** `NudgeStreamer` (it
lives here), the **real** `BatchNFTMinterMultiToken` under test, and the **real**
`collectNudge` donor path via `MockNudgeDonor`. A local 6-dp `MockUSDC6` keeps the
audit's units, so the reproduction reports the same 200 USDC pot and 190 USDC
extraction as the original. No cross-submodule interface change was needed.

**One fidelity note.** The mock minter has no dispatcher routing, so
`_mintThroughRatchet` drives the honest mint and the donation leg explicitly
rather than having `NudgeRatchet.dispatch` forward the mint's own USDC. Both legs
are real and the streamer buffer tripwire (`buffer == 20 * RATCHET_PRICE`) still
proves the donations landed; only the internal plumbing between them is stubbed.

#### 10. PoC uses `encodeWithSignature`, not the typed selector

`BatchMint__PaymentBudgetExhausted` does not exist on the pre-change contract, so
referencing it as `BatchNFTMinterMultiToken.BatchMint__PaymentBudgetExhausted.selector`
would have made the PoC file fail to **compile** during the RED phase — which the
story correctly calls "inconclusive bit-rot, not a fix". The PoC therefore matches
the revert by signature string, so the same file compiles and runs against both
revisions. The Phase 4 boundary tests, which are written after the change lands,
use the typed selector.

Additionally, `_extractedByCount1Attack()` performs the attack via a low-level
`call` rather than `vm.expectRevert`, so one test body measures the same quantity
whether the contract lets the sweep through (pre-change: 190 USDC leaves, printed
in the failure message) or rejects the batch (post-change: reverts, nothing
moves).

#### 11. `:335-343` was corrected in place, not deleted outright

The story says "**delete**" the "derived payment token can never be whitelisted…"
paragraph. The affirmatively false sentence is gone, but the `@dev` block now
carries a short *correct* statement of what happens when the owner repoints the
dispatcher, because that question is the first thing a reader of this function
asks and silence would invite the wrong answer. Same treatment in
`_snapshotRewards`: rather than deleting the justification paragraph, it now
records that the old claim was falsified by `ycn19h1` and why. Deleting both
outright would have satisfied the letter of the checklist while losing the reason
the code looks the way it does.

#### 12. `forge fmt` collateral damage on frozen files

`forge fmt` with no arguments reformats the whole repo, and on first run it
modified nine pre-existing files including the **frozen**
`src/BatchNFTMinter.sol` and `test/BatchNFTMinterNudge.t.sol`. Reverted them to
`d75229d` and amended, then used targeted `forge fmt <paths>` for the rest of the
story. Verified at the end that
`git diff d75229d --stat -- src/BatchNFTMinter.sol test/BatchNFTMinter.t.sol test/BatchNFTMinterNudge.t.sol`
is empty.

#### 13. Tests added beyond the story's enumeration

The floor for the colliding whitelist entry goes from "silently ignored" to
"live", which is a behaviour change with no test in the story's list. Added
`test_PaymentTokenEntryFloorIsLive`,
`test_RuntimePaymentTokenCollisionFloorIsLive` and
`test_RuntimeCollisionBelowThresholdFloorIsLive`. Also added
`test_RevertWhen_BudgetCannotCoverTheFirstMint` (the `ycn19h1` shape reduced to
arithmetic, at `mintIndex == 0`), and control/qualifying/repeatability arms in the
PoC file so the fix is shown not to have bricked the feature it makes safe.

#### 14. §8.12 `PoC_EconZeroPaymentSweep.t.sol` — confirmed absent, treated as non-blocking

As the Concerns section anticipated, that file does not exist in this repo
(`find . -name "PoC_Econ*"` is empty; the only PoC here is
`test/PoC_DepletionRateDrift.t.sol`, plus the one this story adds). The equivalent
property — a zero/negligible-payment batch cannot sweep the pot — is verified by
`PoC_PaymentTokenCollisionTest::test_PaymentTokenAsNudge_nonQualifyingBatchTakesNothing`
and `..._underFundedBatchRevertsWithBudgetExhausted`. The audit-side
`PoC_ZeroPaymentSweep_MultiToken` re-run remains the auditor's to perform in the
audit workspace.

#### 15. Story premise corrected — `MockITokenMinterV2` ramp formulas are bit-identical

Recorded at the orchestrator level after execution, on independent validation.
Confirms and strengthens decision **2** above, which reached the same conclusion
from inside the execution run.

**Situation.** The story's "Implementation Notes" (~lines 324-329) assert that the
mock's `price * (10_000 + g) / 10_000` and the real `NFTMinterV2`'s
`price + (price * g) / 10000` differ in intermediate rounding.

**Decision.** Treat that premise as **FALSE**. Independently proven:
`floor(p·(10000+g)/10000) = p + floor(pg/10000)` exactly, because `10000p` is
divisible by `10000`, so the truncated remainder is contributed solely by `pg` in
both expressions. Brute-forced over **200,108** structured and random `(p, g)`
pairs with **zero** mismatches. The mock was nonetheless aligned to the real
formula for overflow headroom — `p·(10000+g)` overflows at a lower `p` than `p·g`
does — which is the only genuine divergence between the two expressions.

**Rationale.** The story instructed a fix for a non-existent defect. The
"exactly" assertions in Phase 1/4 were never at risk from rounding, so no
assertion needed weakening and no test outcome hinged on the alignment. Future
readers of this story should not carry the rounding claim forward.

**Alternatives.** Leaving the mock unaligned would also have been correct for all
non-overflowing inputs; the alignment is a headroom improvement, not a
correctness fix.

---
### Review Results
**Review Date**: 2026-07-25T15:33:52Z
**Review Command**: `review-work nft-staking 29`
**Review Status**: ISSUES_FOUND
**Full Report**: `scratchpad/analysis-reports/nft-staking-story-029-review-report-2026-07-25.md`

#### Executive Summary

Genuine root-cause remediation of `ycn19h1`, well executed, with clean scope discipline. The refund's
source of truth really did move from `balanceOf` to a tracked `budget`; the runtime skip, the `totalPaid`
floor guard and every falsified NatSpec claim are gone. **530/530 tests green, independently reproduced
three times.** Three issues found, none warranting reversion: the central "pot can never leave through
the refund" claim is stated **unconditionally** in the contract header and step-9 comment, but is
conditional on the pull crediting `paymentAmount` — and the fee-on-transfer test that appears to cover
that gap does not, while its own NatSpec quietly concedes the dependency the header denies.

#### Validation Results
1. Base Commit Validation: ✓ (base commit **is** the `main` branch point; 3 commits, all `[story-029]`)
2. File Change Review: ✓ (no flags; frozen files byte-identical by blob hash; no build-config change)
3. Claim Validation: ✓ (every Phase 0–6 box substantively true; one PARTIAL — see below)
4. Purpose Alignment: ✓ ALIGNED (root cause, not symptom — but see Finding A)

#### Issues Found

- **A — medium: the pot-integrity claim is unconditional in the header but conditional in fact.**
  `budget = paymentAmount` (`src/BatchNFTMinterMultiToken.sol:554`) is the one place left in `batchMint`
  where a quantity is *trusted rather than measured*. For a fee-on-transfer payment token that also holds
  the pot, a **non-qualifying** batch shrinks the pot (reproduced: 5% fee, `count=1`, pot 10,000 → 4,950).
  Griefing as written — the shortfall goes to the token's fee sink — but **direct extraction if the
  attacker controls that sink**, which is explicitly inside the "still reportable" carve-out of the
  2026-07-25 arbitrage acceptance. Inverted second arm: a *qualifying* batch in the same config
  **reverts** inside `_payRewards`. Low materiality today (payment token is USDC/phUSD/USDS via the
  pinned dispatcher's `primeToken()`, none fee-on-transfer). Sharpest element: the header `:73-77` and
  step-9 comment `:583-584` state it absolutely, while
  `test/BatchNFTMinterMultiTokenBudget.t.sol:455-458` concedes the shortfall "is necessarily absorbed by
  whatever payment-token balance is present". Fix is one line —
  `budget = balanceAfterPull − balanceBeforePull` — or downgrade the wording.
- **B — low-medium: `test_FeeOnTransferPaymentToken_refundCapsAtAvailable` does not test its own case.**
  The taxed token is the payment token but the pot is in `rewardB`, so
  `"POT INTEGRITY: the nudge pot is untouched"` is **vacuously true** for the colliding arm. Plan §8.9's
  middle requirement is skipped, and per Finding A it is false once the taxed token holds the pot. The
  invariant harness does not cover it either (well-behaved `MockERC20` only, `D = 0` throughout).
- **C — low: a falsified claim survives in `docs/multi-token-nudge.md:122-123`** — "its floor is ignored,
  see §4.1", contradicting the contract's own new `:429-431` ("Every entry's floor is live") and
  cross-referencing a §4.1 that Phase 5 rewrote to say the opposite. Phase 5 covered docs §3/§4.1/§4.2
  and missed §2.
- **PARTIAL — Phase 6 "`forge fmt` green":** repo-wide `forge fmt --check` exits 1 on 8 files, **all
  byte-identical to `d75229d`** (pre-existing, 028-era; two are frozen twins). Restricted to story 029's
  10 files it exits 0. Not a regression — Autonomous Decision 12's targeted-fmt approach was correct —
  but the bare checkbox reads as "repo is fmt-clean", which it is not.

Non-blocking observations (10, incl. the 6-decimal `DUST_THRESHOLD` reality being 1 whole USDC, the
§5.1 admin guard leaving the purpose half-delivered at the admin surface by design, three undocumented
§4.1 test renames, and the now-moot "028 is in review" prose) are in the full report.

#### Autonomous Decisions

1. **Story selection** — `nft-staking 29`: `29` is not a sprint name in `sprints.json`, so it was read as
   a story identifier. Story 029 was the **only** file in `stories/nft-staking/review/`. No ambiguity.
2. **`flag-investigator` invoked despite zero flags, re-scoped** to independently spot-check the
   no-flags conclusion plus resolve the flagger's two unresolved nits. *Rationale:* skipping it would
   leave the flagger unchecked by any second party. It paid off — it corrected the flagger's claim that
   `test_RevertWhen_WhitelistingPaymentToken` was renamed (comment-only edit) and verified the −53,171
   gas drop by trace. *Alternative:* report "nothing to investigate" — cheaper, ships an unaudited clean
   bill of health.
3. **Findings A/B/C independently re-verified at file level** before reporting, since all three came from
   one validator and A rested on a probe this orchestrator did not observe. All confirmed. The re-read
   surfaced Finding A's sharpest element (header denies what the test concedes), which the validator did
   not frame that way. *Alternative:* relay verbatim — faster, would have missed the contradiction.
4. **Status ISSUES_FOUND, not PASSED**, even though all five stages returned passing verdicts. *Rationale:*
   Finding A sits inside the owner's own reportable carve-out; PASSED would bury the thing needing a
   decision. The *work* passes every structural check — the *claims* need one. *Alternatives:* PASSED with
   notes (inverts the signal); FAILED (unwarranted — no regression, suite green, large net improvement).
5. **No reversion considered, recommended, or performed.** Every validator was given an explicit
   no-revert constraint, including `flag-investigator`, whose definition otherwise permits it. All git
   operations across all five validators were read-only; worktree verified clean at HEAD before and
   after; no story status changed.
---

---
### Human Review — 2026-07-25 (instructions)

**Command:** `human-review nft-staking 29`
**Question asked:** "There's an assumption that a token amount is received. Is it
not possible to do a balance delta to be sure?"
**Outcome:** balance delta implemented. Closes review Findings **A**, **B** and
**C**. Story **remains in `review/`**.
**Commit:** `5015f1b` — `[story-029] Measure the caller's credit across the pull…`
**Verification log:** `scratchpad/validation-logs/story-029-credited-delta-verification.md`

#### What changed

`batchMint` step 5 measures instead of trusting:

```solidity
uint256 budget;
{
    uint256 heldBeforePull = paymentToken.balanceOf(address(this));
    paymentToken.safeTransferFrom(msg.sender, address(this), paymentAmount);
    uint256 credited = paymentToken.balanceOf(address(this)) - heldBeforePull;
    budget = credited < paymentAmount ? credited : paymentAmount;
}
```

`uint256 budget = paymentAmount;` is gone from the head of the mint loop. Nothing
inside the loop changed — it still decrements by the authoritative per-mint price.

#### Faithfulness to "no `balanceOf` identity abuse"

The user's constraint was to get the delta **without** reintroducing the
conflation the story exists to remove. The rule now written into the source at
both sites is that what matters is *what the reading is of*:

| reading | sees | verdict |
|---|---|---|
| single absolute reading, anywhere after step 5 | `P + (A − C) + D` | forbidden — this is `ycn19h1` |
| difference across the **one** step-5 transfer | that transfer alone (`P` cancels, `D` has not happened) | permitted, and **only** here |
| difference bracketing the **mint loop** | `−price + D` | forbidden — explicitly called out in the loop comment |

The `DO NOT RE-DERIVE budget FROM balanceOf` block keeps its force and gains the
carve-out plus the loop-bracketing prohibition, so the narrow exception cannot be
read as a general licence.

`min(credited, paymentAmount)` rather than the bare delta: a bare delta is
unbounded above. A callback-bearing token lets a third party push funds in during
the pull — `nonReentrant` blocks re-entering `batchMint`, not an inbound transfer
— and those funds would be credited to `msg.sender`. That is `D` re-routed to the
batcher. The `min` takes the tighter of measured and quoted, so
`refund <= budget <= paymentAmount` still holds by construction.

#### Findings closed

- **A** — was: pot-integrity stated unconditionally in the header, conditional in
  fact. RED reproduced it exactly (pot 10,000 → 9,742.37, the loss being precisely
  the 5% fee on the pull) plus the inverted arm (qualifying batch reverts inside
  `_payRewards`). Both green after. Header, step-5, step-9 and loop comments
  rewritten to state the property and its basis together.
- **B** — was: `test_FeeOnTransferPaymentToken_refundCapsAtAvailable` held its pot
  in a second token, making its pot-integrity assertion vacuous. Renamed to
  `test_FeeOnTransferPaymentToken_refundIsTheCreditedBudget`, NatSpec now says
  what it does and does not cover; two new tests put the tax and the pot in the
  **same** asset. Invariant harness parameterised over token behaviour — baseline
  now generates donate-forward `D` (was `0` throughout), plus a second run over a
  500 bp taxed token holding the pot, with pot integrity asserted as an exact
  end-balance rather than a bound.
- **C** — `docs/multi-token-nudge.md` §2 "its floor is ignored" corrected; §3
  step 5 rewritten normatively; §3 step 9 and §4.1 re-characterise `available` as
  belt-and-braces and distinguish quoted `A` from credited `A'`.

#### Evidence

- 531 tests green (was 530: +3 new, 1 renamed); invariants 4 green at 128,000
  calls per run, 0 reverts.
- **Mutation check:** reverting step 5 to `budget = paymentAmount` turns the taxed
  invariant run red on **both** invariants while the well-behaved baseline stays
  green — the new coverage detects the defect it was added for and is not passing
  vacuously. Source restored and diff verified afterwards.
- Gas: **+3,318 flat per batch** (two `balanceOf` staticcalls), constant in
  `count` and in reward-token count. Against the ~26k **per mint** already
  accepted in Autonomous Decision 7, immaterial.
- Frozen twins verified byte-identical to `d75229d`. `forge fmt` applied to the
  four touched files only (Autonomous Decision 12 still stands).

#### Not changed

§5.1 admin guard (kept, per Concerns); per-iteration `configs` re-read (no local
ramp extrapolation); build configuration (legacy codegen, no `via_ir`, no
optimizer — both new blocks are block-scoped to stay inside the stack limit).

#### Still open from the review

The non-blocking observations remain as filed, and the operational pre-flight in
Concerns (read `dispatcherIndex` on the deployed instance, resolve its
`primeToken()`, test with `isNudgeToken(...)`; set a non-zero `pauser()` on both
live instances) is unaffected by this pass and still blocks shipping.

---
### Completion — 2026-07-25T15:57:09Z

**Command:** `set-complete nft-staking 29`
**Base Commit:** `5015f1b45aa196bc3f1d4f994d7413624dc960a8` — worktree HEAD.
029 is the highest-numbered story in the project, so there is no subsequent
story to chain from; per the base-commit rule the completed story takes HEAD.

**Sprint:** 9 `multi-token-nudge` · **Worktree:**
`worktrees/nft-staking/multi-token-nudge` @ `sprint/multi-token-nudge`, clean.

**Commits (4, all `[story-029]`, from base `d75229d`):**
- `8f3b982` RED: port `ycn19h1` PoC and budget-refund core properties
- `0318089` GREEN: budget-tracked refund makes paymentToken as nudge token safe
- `9bef5a6` Invariants, token-behaviour independence and boundary regression
- `5015f1b` Measure the caller's credit across the pull instead of trusting
  `paymentAmount` (human-review pass — closes review Findings A, B and C)

**State at completion:** 531 tests green; 4 invariants green at 128,000 calls per
run; frozen twins byte-identical to `d75229d`; no build-config change.

**Carried forward — not closed by this story.** The operational pre-flight in
Concerns still blocks shipping: read `dispatcherIndex` on the deployed instance,
resolve that index's dispatcher `primeToken()` and test it with
`isNudgeToken(...)` (a whitelisted result means the pot is drainable *now* and
operational action precedes the code change); and `919b71fd…` — `pauser() ==
address(0)` on both live instances. Ledger consequences remain the auditor's to
apply. The sprint branch is unmerged; the worktree must be retained until the
sprint is merged.


---

# Number-collision note — yield-claim-nft story-029 (NOT the pin-bump story)

Path: `/home/justin/code/product-owner/stories/yield-claim-nft/complete/yield-claim-nft-hook/029-dispatcher-v2-hook-mechanism.md`

Header only, for disambiguation:

## Dispatch Hook Mechanism for V2 Dispatchers (onDispatch Callback)

Current Sprint: 12
Story Type: feature
Base Commit: 69357d4d2c56430d9774c04ad38f73d9fdfa9af5
Execution Type: new_worktree
Base Commit Updated: 2026-04-18T00:00:00Z

### Story Overview

Introduce a pluggable hook mechanism on the V2 dispatchers so that an external contract implementing `IDispatchHook` can react to every dispatch. Refactor `ATokenDispatcherV2` so the external `dispatch` is no longer virtual — it becomes a non-virtual entry point that runs a new internal virtual `_dispatch` (the concrete implementation) and then calls `hook.onDispatch(...)` with the same arguments. Add `nonReentrant` on the external `dispatch` to defend the new callout, and gate a `setHook(IDispatchHook)` setter on owner. The `hook` reference is never null — the abstract deploys a default no-op hook in its constructor so concrete dispatchers avoid an `if (hook != address(0))` branch.

