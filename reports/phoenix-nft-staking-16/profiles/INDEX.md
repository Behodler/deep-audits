# Contract Profiles — phoenix-nft-staking (run 16)

- **Submodule HEAD:** `5f863d27ebbab5df20131a4592996537cd8bf503`
- **Solidity:** `^0.8.20`
- **Profiled:** 2026-06-07
- **Producer:** contract-profiler (local analysis only; cross-contract / economic concerns deferred)

## Files

| Profile | Contract | Scope | Loops | Reentrancy guard | Local findings |
|---|---|---|---|---|---|
| `BatchNFTMinter.profile.json` | `src/BatchNFTMinter.sol` | PRIMARY | 1 (caller-bounded mint loop) | none on `batchMint` | 2 (local-low / local-info) |
| `NFTStaker.profile.json` | `src/NFTStaker.sol` | context (in-scope) | 0 | stake/unstake/claim/emergencyWithdraw | 0 |
| (interface only) | `src/INFTSupply.sol` | OUT OF SCOPE | — | — | — |

## INFTSupply (OUT OF SCOPE — trust boundary only)

Minimal local interface combining `ERC1155Supply.totalSupply(uint256)` and
`NFTMinterV2.configs(uint256)`. Declared locally so `NFTStaker` does not reach
into the `yield-claim-nft` sibling implementation. Production wiring is a direct
cast of the deployed `NFTMinterV2` address.

- `totalSupply(uint256 id) view -> uint256` — declared but **not consumed** by the
  shipped `NFTStaker` (rate is sized on `totalStaked`, not `totalSupply`, post-M-03).
- `configs(uint256 index) view -> (address dispatcher, uint256 price, uint256 growthBasisPoints, bool disabled)`
  — `price` is the NEXT mint price; `NFTStaker` recovers `latestPrice = price / r`.

Treat all `INFTSupply` / `ITokenMinterV2` / `ITokenDispatcherV2` /
`IBalancerPoolerMintDebtHook` calls as trusted-but-mutable OOS sibling boundaries;
exploitability of those siblings belongs to interaction analysis.

## Story timeline (intended behavior)

| Commit | Story | What it did |
|---|---|---|
| `b9c460e`/`38b0c94`/`6dc1ca1` | story-009 | BatchNFTMinter as a **stateless** mint looper (no funds, no owner, no pause). Originally took the minter as a call parameter — safe while stateless. |
| `031ffda` | story-014 | **Pin** `dispatcherIndex` to owner state; **derive** `paymentToken` from the pinned dispatcher's `primeToken()`. Caller inputs shrink to `(count, recipient, paymentAmount)`. Closes prior **H-01** (caller-supplied no-op minter draining the nudge pot via the numeric `count>=nudgeSize` gate). |
| `9be4a87` | story-015 | Add `minReward` **slippage floor**; revert `BatchMint__RewardBelowMinimum` if deliverable nudge < minReward. Mitigates the **loser side** of M-01 MEV (does not stop the front-runner winning the pot — M-01 acknowledged). |
| `5f863d2` | story-016 | **Snapshot the nudge pot BEFORE the mint loop** so a qualifying batcher is paid only the PRIOR pot; this batch's own per-mint donations stay to seed the next claimant ("donate-forward"). |

## Nudge pot — locus of prior findings

- **Funding:** external (yield funnel sends e.g. USDC in) + per-mint donations the
  dispatcher pushes into the contract during the loop.
- **Snapshot:** `nudgeAmount = balanceOf(nudgePaymentToken)` read BEFORE payment pull
  and loop (BatchNFTMinter.sol:271–275).
- **Consume:** after loop + allowance revoke, `safeTransfer(recipient, nudgeAmount)`
  before the dust refund (lines 294–297).
- **Gate:** `nudgeSize != 0 && count >= nudgeSize && nudgePaymentToken != 0`.
- **Floor:** `nudgeAmount < minReward => revert` (lines 290–292).
- **H-01** (value-blind drain): FIXED by story-014. **M-01** (MEV front-run of the
  balance-based payout): ACKNOWLEDGED; story-015 only protects the loser.

## Headline local-invariant candidates (for invariant-generator)

### BatchNFTMinter
1. **NUDGE-SNAPSHOT-SOLVENCY** — at the nudge transfer, contract nudge balance >= snapshotted `nudgeAmount` always (balance only grows post-snapshot; payment pull cannot touch it since nudge != payment token). Transfer never reverts for insufficiency, never over-pays the prior pot.
2. **NUDGE-PAYOUT-BOUND** — payout <= nudge balance at function entry; this batch's donations never refund to the current caller.
3. **MIN-REWARD-FLOOR** — any success with `minReward>0` delivered `nudgeAmount >= minReward`.
4. **ALLOWANCE-HYGIENE** — minter allowance set to max then reset to 0 within the same call; no residual approval persists.
5. **PAYMENT-TOKEN-DERIVATION** — `paymentToken == dispatcher.primeToken()` always; never caller-supplied.

### NFTStaker
1. **SOLVENCY (strong)** — `balanceOf(this) == rewardBudget + committedDebt` at all times (M-01).
2. **NO-OVERPAY** — never transfers more than balance; `_safePay` reverts on shortfall.
3. **RATE-FORMULA / RUNWAY** — `rewardRate == S*A/Y` with `S = totalStaked*latestPrice`; `windowEnd == now + budget/rewardRate`.
4. **APY-AS-FLOOR (M-03)** — per-NFT emission `= latestPrice*A/Y`; latest minter earns exactly `A`; no `N/totalStaked` multiplier.
5. **PRINCIPAL-NEVER-TRAPPED** — `emergencyWithdraw` always returns principal regardless of hook/minter/recompute health, callable while paused.
6. **RECONFIG-LOCK** — `setDispatcherIndex`/`setNFTMinter`/`setStakedId` only while `totalStaked == 0`.

## Notes for downstream agents

- **`docs/design.md` is partially stale** (fixed-window 540d model). The authoritative
  specs are the submodule `CLAUDE.md` "Critical Invariants" section and
  `docs/runway-dynamics-and-apy-as-policy.md` (variable-runway APY-target model).
- `batchMint` is **permissionless and unguarded for reentrancy**; safety rests on the
  owner-configured tokens being callback-free standard ERC20s. Reentrancy exploitability
  is a token-dependent interaction concern — deferred.
- Owner (Law 3) can `rescueERC20` the nudge pot and disable features; treated as trusted,
  not an attack. Setting `nudgePaymentToken == primeToken` is a loud up-front revert
  (config invariant), not a hidden footgun.
