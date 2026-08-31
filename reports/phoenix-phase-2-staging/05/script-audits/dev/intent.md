# Intent — dev (StableStaker slice of DeployMocks Phase 3.7)

Scope: the StableStaker introduction only. `dev` = `clean:local -> anvil -> deploy:local
(DeployMocks) -> simulate-yield.sh -> extract -> generate -> serve`. The StableStaker work lives
entirely in `deploy:local` -> `script/DeployMocks.s.sol` Phase 3.7 (lines ~654-685). The JS tail and
`simulate-yield.sh` only *consume* the deployed address; they do not configure StableStaker.

## Stated purpose (from Phase-3.7 comments + StableStaker NatSpec + lib/stable-staker CLAUDE.md wiring steps)
- [ ] Deploy `StableStaker(IFlax(MockPhUSD), deployer)` — MockPhUSD as the phUSD reward token, anvil acct0 as owner.
- [ ] Authorize StableStaker as a phUSD minter (`phUSD.setMinter(StableStaker, true)`) so it can mint rewards on claim/withdraw.
- [ ] Register 3 pools: DOLA, USDC (MockRewardToken), USDe (`addToken` each).
- [ ] Wire each pool's ERC4626 yield strategy **two-sided**: `strategy.setClient(StableStaker, true)` (client side) AND `staker.setYieldStrategy(token, strategy)` (staker side). Without the client side, stake/withdraw revert.
- [ ] Set per-pool emission budgets: DOLA = 10 phUSD/day, USDe = 10 phUSD/day, USDC = 5 phUSD/day (`phUSDPerDay`). The reduced USDC rate is intentional (story-051 Concerns, "so the reduced rate is visible in the UI").

## Declared pre-conditions
StableStaker's constructor `require`s `address(_phUSD) != address(0)` (MockPhUSD is non-zero).
`addToken` requires non-zero token and no duplicate; `setYieldStrategy`/`phUSDPerDay` require `poolExists`.
There are **no script-level `require` guards** in Phase 3.7 itself (anvil-local mock flow; the CLAUDE.md
"Configuration Safety" gate is gated to real networks via `block.chainid` elsewhere, not applied here).

## Declared post-conditions
There are **no script-level asserts** after Phase 3.7. The deployment's *implied* end-state spec (from the
wiring steps and the parallel Phase-8 pattern applied to every other pausable contract) is:
- `owner == deployer`; `phUSD == MockPhUSD`.
- 3 pools registered with the stated rates (DOLA/USDe = 115740740740740 wei/s, USDC = 57870370370370 wei/s).
- StableStaker is an authorized phUSD minter.
- Each of the 3 strategies authorizes StableStaker as a client.

## Known configuration gaps (not asserted, recorded by closure mapping)
- `setPauser` is NEVER called in Phase 3.7 — `pauser` stays `address(0)`.
- `setMigrator` is NEVER called — `migrator` stays `address(0)`.
- Phase 8 (`Pauser Registration`) wires `setPauser` + `pauser.register` for 6 other pausable contracts
  (PhusdStableMinter, PhlimboEA, StableYieldAccumulator, NFTMinter, NFTMinterV2, NFTStaker) but **omits
  StableStaker entirely** — it is the only `IPausable` protocol contract left unregistered.
