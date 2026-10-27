# Intent — dev (`npm run dev` → `./dev-local.sh`), run-42, regression dfbf2f9..d0060cb

Target chain: a **fresh local anvil (31337)** that the script starts and owns. Owner ruling 2026-09-15:
DeployMocks/dev is a UI-testing mock stack, not a mainnet rehearsal. Mirror-mainnet fidelity is not graded.

## Authoritative intent (stories, all resolved in ~/code/product-owner/stories/phStaging2/)
| story | state | what it asks of dev |
|---|---|---|
| 081 (context) | auto-complete | honest orchestration: own the anvil, refuse a foreign/dirty node, nonce-0 gate |
| 103/106/107 | auto-complete | UniPoolerV2 at index 4 directly; Balancer mocks/keys removed; cutover rehearsal retired |
| 104 | auto-complete | address interface/extract/generate pipeline shared with Sepolia |
| 109/110/111 | auto-complete | UniswapHelper + venue mocks on anvil (Phase 11.8), `UniswapHelper` UI key |
| 112 | auto-complete | deepen phUSD/sUSDS seed to mainnet x10 (Phase 11.9), LP to UniPoolerV2, no address shift |
| 113/114 | auto-complete | AntimatterPoolSeeder + Antimatter/sUSDS cutover dress rehearsal (Phase 11.10) |
| 115 | auto-complete | SYAHarvester infra: Router NG mock, crvUSD, Curve pools, V4 PoolManager + ETH/USDC pool (11.11) |
| 116 | auto-complete | register USDe with SYA, deploy+configure SYAHarvester, contiguous routes, smoke harvest (11.12) |
| 117 | incomplete | CurveAMMAdapter last-non-zero (OUT OF SCOPE, note only) |

`dev-local.sh` delta commit 9762281 (API-port pre-flight, +47 lines) is **untagged** — no story backs it.

## Stated purpose (checklist)
- [ ] Pre-flight: API port (3001) free; nothing answering on :8545
- [ ] `clean:local` removes prior 31337 artifacts before anvil starts
- [ ] Start an owned anvil (chain 31337, `--block-time 2`), readiness poll, listener pid == anvil pid, block ≤ 100
- [ ] `DeployMocks` broadcasts the full mock stack (all phases incl. 11.7–11.12) with every `require` passing
- [ ] Story 116: USDe registered with SYA (`setTokenConfig(usde,18,1e18)`, `addYieldStrategy`, `setWithdrawer(SYA,true)`); SYA carries 3 strategies
- [ ] Story 116: SYAHarvester deployed (owner, PoolManager, SYA, RouterNG); `setEthPool` ETH/USDC fee 3000 ts 60 no hooks
- [ ] Story 116: DOLA route 1 hop → USDC; USDe route 2 hops via crvUSD → USDC; USDC has **no** route; all routes Router-NG contiguous
- [ ] Story 116: yield seeded so `calculateClaimAmount > 0` for DOLA, USDe, USDC; caller holds a claim NFT + approval
- [ ] Story 116: smoke harvest sells DOLA and USDe, ETH out > 0, gas check passes ("`ethOut >= (gasUsed + 60_000) * tx.gasprice`")
- [ ] Story 116: harvester owner per `_sweepResidualPrivileges` conventions; approval revoked; harvester empty; yield re-seeded
- [ ] Story 116: `SYAHarvester` tracked for the UI; mainnet/Sepolia keys zero; drift guard green
- [ ] `simulate-yield.sh` mints 2300 DOLA into MockAutoDOLA
- [ ] `extract:addresses` → local.json; `generate:ts-anvil` → local-addresses.ts + addresses.ts (interface)
- [ ] Story-116 commit claim: regenerated artifacts move **no existing address** (only `SYAHarvester` added)
- [ ] `serve` brings up the API on 3001

## Declared pre-conditions (before broadcast)
- `block.chainid == 31337` ("DeployMocks: local only") — DeployMocks.s.sol:433
- `vm.getNonce(deployer) == 0` (fresh chain) — DeployMocks.s.sol:434-437
- `ANVIL_PRIVATE_KEY` set (vm.envUint, no default) — DeployMocks.s.sol:409
- shell: port 3001 free, :8545 silent, listener pid == anvil pid, block ≤ 100

## Declared post-conditions (selected; all are loud `require`s in forge simulation)
- Phase 11.7 (106): configs(4) == UniPoolerV2, growth 10, enabled; index-6 placeholder disabled; test mint wraps + accrues debt; `pool()` adds depth
- Phase 11.8 (110): helper resolves the pair; MockSkyPSM tin == 0
- Phase 11.9 (112): router took the sized deepening; reserves ≥ targets; UniPoolerV2 holds LP
- Phase 11.10 (114): AM/sUSDS pair canonical; phUSD supply fell by exactly AM minted; seeder AM-minter revoked; deployer holds AM LP; seeder empty
- Phase 11.11 (115): USDe route → USDC in 2 hops, DOLA route → USDC in 1 hop; V4 pool seeded (≥99 ETH, ≥199k USDC)
- Phase 11.12 (116): SYA 3 strategies; harvester immutables/owner/ETH key; routes contiguous; USDC unrouted; smoke: ethOut>0, DOLA & USDe sold, NFT burned, harvester empty, gasUsed < 3M, `ethOut >= 3.06M * 50 gwei`
- Terminal sweep: deployer phUSD minter revoked; 12-row phUSD ACL table; SYAHarvester owner == deployer, no deployer approval, empty, all 3 strategies claimable

## Note on where the post-conditions run
Every `require` above executes in forge's **local simulation**, before the broadcast. The broadcast chain is
checked by receipts only (status 1). Empirical on-chain re-reads of the key end-state are in side-effects.json.
