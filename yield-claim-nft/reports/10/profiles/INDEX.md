# yield-claim-nft — Contract Profiles (run-10, cold scan)

- **Source (read-only):** `lib/yield-claim-nft` @ `cf75ec9` — `[story-034] Redirect BalancerPoolerV2 donation to Sky PSM in _dispatch; pool() becomes pure LP add`
- **Solidity:** `^0.8.20` (checked arithmetic throughout)
- **Profiles:** 15 (9 V2 focus + 6 V1 context)

## Architecture (V2)

```
User --pay primeToken--> NFTMinterV2.mint(index, recipient)
        |  (token = dispatcher.primeToken(), H-01 fix)
        |  transferFrom user -> dispatcher (balance-delta / FOT-safe)
        |  config.price bumped (CEI)
        v
   ATokenDispatcherV2.dispatch(minter, amount, extraData)   [nonReentrant, onlyMinter, whenNotPaused]
        |  _dispatch(...)  (concrete)        then  hook.onDispatch(minter, amount, extraData)
        |                                          |
        |                                          +-- DefaultDispatchHook (no-op, default)
        |                                          +-- BalancerPoolerMintDebtHook (accrues phUSD mint-debt)
        v
   concrete dispatcher:
     - BurnerV2   : IBurnable(token).burn(amount) + BurnRecorder.burn
     - GatherV2   : token.safeTransfer(recipient, amount)
     - BalancerPoolerV2 : wrap (amount - donation) USDS->sUSDS;  donation USDS --PSM.buyGem--> USDC to batchMinter (try/catch)
                          later: pool(minBPT) [authorized pooler] -> Balancer V3 single-sided LP add -> BPT custodied
        v
   NFTMinterV2._mint(recipient, index, 1)   (ERC1155; onERC1155Received callback)

NFTMigrator.migrate(): burns caller V1 NFTs -> v2.mintFor(mappedIndex, caller) per unit
```

## Profile files

### V2 FOCUS (9)
| Contract | Profile | Role | Notable local findings |
|---|---|---|---|
| `src/V2/NFTMinterV2.sol` | `NFTMinterV2.profile.json` | ERC1155 paid/free minter, dispatcher registry | mintFor bypasses pause+disable (LOCAL-NMV2-001); post-dispatch receiver reentrancy surface; replaceDispatcher carries old price |
| `src/V2/NFTMigrator.sol` | `NFTMigrator.profile.json` | V1->V2 NFT migration | unbounded inner mint loop / gas DoS (LOCAL-MIG-001); init-staleness brick (LOCAL-MIG-002); no nonReentrant |
| `src/V2/dispatchers/ATokenDispatcherV2.sol` | `ATokenDispatcherV2.profile.json` | abstract base, template-method dispatch + hook | hook in dispatch trust path; nonReentrant + onlyMinter + whenNotPaused on external dispatch |
| `src/V2/dispatchers/BalancerPoolerV2.sol` | `BalancerPoolerV2.profile.json` | USDS->sUSDS wrap + PSM donation + Balancer LP add | stranded-USDS-on-disable edge (LOCAL-BPV2-001); donation sweeps full balance vs gross-amount debt (LOCAL-BPV2-004); PSM rounding (floor) |
| `src/V2/dispatchers/BurnerV2.sol` | `BurnerV2.profile.json` | burn prime token + record | recorder trusts passed amount (FOT note) |
| `src/V2/dispatchers/GatherV2.sol` | `GatherV2.profile.json` | forward prime token to recipient | none |
| `src/V2/hooks/BalancerPoolerMintDebtHook.sol` | `BalancerPoolerMintDebtHook.profile.json` | accrue + pull phUSD mint-debt | ratio cap doc/code off-by-one (LOCAL-HOOK-001, allows 50 vs documented <50); unilateral phUSD mint authority |
| `src/V2/hooks/DefaultDispatchHook.sol` | `DefaultDispatchHook.profile.json` | null-object hook | none |
| `src/V2/interfaces/IDispatchHook.sol` | `IDispatchHook.profile.json` | hook interface | n/a |

### V1 CONTEXT (6) — for diffing only, NOT primary scope
| Contract | Profile | Key V1->V2 diff |
|---|---|---|
| `src/NFTMinter.sol` | `NFTMinter.profile.json` | caller passes `token` (equality-checked) vs V2 reads primeToken(); has getDispatchers; no mintFor/replaceDispatcher |
| `src/dispatchers/ATokenDispatcher.sol` | `ATokenDispatcher.profile.json` | no ReentrancyGuard, no hook, dispatch is external virtual |
| `src/dispatchers/BalancerPooler.sol` | `BalancerPooler.profile.json` | pools synchronously per mint (H-02 coupling); no PSM/donation; unguarded |
| `src/dispatchers/Burner.sol` | `Burner.profile.json` | same burn logic, inline dispatch override |
| `src/dispatchers/Gather.sol` | `Gather.profile.json` | same forward logic, inline dispatch override |
| `src/BurnRecorder.sol` | `BurnRecorder.profile.json` | shared infra used by both V1+V2 burners |

## Key trust assumptions (axioms for downstream agents)

1. **Owner is trusted (non-malicious)** across all contracts — registers honest dispatchers, sets sane prices/ratios/recipients, wires minter/burner/pooler roles. Report only *non-obvious* owner footguns.
2. **NFTMinterV2 is the sole `_minter`** of each dispatcher; only it can call `dispatch` and pause/unpause dispatchers.
3. **Hooks live inside the dispatch trust boundary** — `hook` is never zero, owner-set, and a reverting hook reverts the mint. `BalancerPoolerMintDebtHook` holds **phUSD mint authority** (privileged).
4. **External protocol trust:** sUSDS = canonical Sky ERC4626 over USDS; PSM = canonical Sky `UsdsPsmWrapper` (USDS<->USDC, `tout` bounded by owner `maxTout`, default 1%); Balancer V3 vault honors unlock/addLiquidity/settle.
5. **Prime tokens (USDS / phUSD) are standard, non-FOT, non-rebasing** ERC20s; balance-delta accounting handles incidental FOT but weird tokens are out of scope (except USDT per house rules).
6. **NFTMigrator must be wired** as authorizedBurner on V1 *and* authorizedMinter on V2 — the central cross-contract edge enabling migration.

## Top candidate areas for interaction-level scanners

1. **story-034 donation path (BalancerPoolerV2 `_dispatch` + `_psmDonate`)** — the headline change. Probe: (a) the full-balance USDS sweep donating more than this dispatch's share interacting with the gross-amount phUSD mint-debt; (b) the `try this._psmDonate{} catch` self-call executing under the dispatch nonReentrant lock with `PSM.buyGem` as a semi-trusted external call; (c) stranded-USDS recovery semantics across enable/disable toggles and `maxTout`/`tout` movements; (d) floor-rounding dust accumulation.
2. **phUSD mint-debt economics (BalancerPoolerMintDebtHook + BalancerPoolerV2 + Balancer pool)** — for econ-scanner: relationship between `batchDonationSize` (USDC out), `hook.ratio` (≤50% phUSD minted), sUSDS pooled, and whether minted phUSD is collateral-backed. Cross-contract value-flow / solvency question, not local.
3. **Mint flow reentrancy across dispatchers** — `NFTMinterV2.mint` is unguarded; `_mint`'s `onERC1155Received` fires after the dispatcher's nonReentrant `dispatch`. Confirm no cross-dispatcher or price-state invariant break via a reentrant mint/mintFor from the receiver callback.
4. **NFTMigrator** — gas-DoS on large holders (LOCAL-MIG-001), init-staleness brick if V1 registers new dispatchers post-init (LOCAL-MIG-002), and unguarded `migrate()` reentrancy via the V2 receiver callback during the burn-then-mint loop. Verify burn/mint atomicity cannot double-credit.
5. **Balancer V3 unlock/settle correctness (BalancerPoolerV2.pool/unlockCallback)** — single-sided add with `_sUSDSIsFirst` ordering, `minBPT` slippage floor supplied by the authorized pooler, and `settle` amount matching the transferred sUSDS. MEV/slippage exposure on `pool()`.
6. **Privileged role wiring & pause coupling** — `mintFor` ignoring pause/disable (LOCAL-NMV2-001), dispatcher pause controlled only via NFTMinterV2 (`setDispatcherActive`), and `rescueERC20`/`emergencyWithdraw` reach over parked/custodied funds. Confirm pause semantics across the mint->dispatch->hook chain.
