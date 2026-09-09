# Intent — migrate:saga2.1-deploy (MigrateSaga2Deploy.s.sol)

Saga 2 "InPlaceMigrator route", Script 1 of 3 — **Deploy & Freeze**. Deploys all new infra, wires it,
replicates V1 minter config onto V2, revokes V1 / grants V2 phUSD mint, carries USDe as dormant,
sets `staker.setMigrator`, records V1 principals, and (broadcast only) writes the cross-script handoff
`script/migration-inputs/saga2-deployments.json`. **It drains nothing.** Steps 2.2 (migrate) and 2.3
(rewire) are OUT OF SCOPE — judged here only on whether 2.1 sets up their preconditions and whether
2.1 itself introduces a problem.

Source: `script/MigrateSaga2Deploy.s.sol` + `docs/stable-staker-migrations/combined-inplace-and-minter-v2-migration-plan.md` (§5 Script 1, §7 sign-off, §8 implementation).

## Stated purpose (from header comment + docs §5)
- [ ] Deploy `InPlaceMigrator(staker, 14 days, owner)` (timeout in [1d, 30d]).
- [ ] Fund the migrator in-place allotment by transferring `DOLA_ALLOTMENT`/`USDC_ALLOTMENT` from owner (top-up cushion consumed by `migrateIn` surplus-funded top-up in 2.2).
- [ ] Deploy two new fixed `ERC4626YieldStrategy`: ysDolaV2(owner, DOLA, autoDOLA), ysUsdcV2(owner, USDC, autoUSDC).
- [ ] Deploy phUSD minter V2 `PhusdStableMinter(phUSD)`.
- [ ] Wire new strategies: `setClient(staker)`, `setClient(minterV2)`, `setWithdrawer(accumulator)` on each.
- [ ] Carry forward the staker set-aside buffer at **10%** on each new strategy, recipient sourced live from the old strategy (fallback staker).
- [ ] USDe carry-over: `setClient(minterV2)` on the USDe market YS (leave V1 authorized, dormant); register USDe on V2 against the same market YS.
- [ ] Register DOLA/USDC on V2 against the new strategies, replicating V1's live exchangeRate/decimals, `maxMintPerDay = 4000e18` each (USDe too).
- [ ] phUSD mint authority: `setMinter(V1, false)` (freeze V1 liability) + `setMinter(V2, true)` (grant V2).
- [ ] `staker.setMigrator(migrator)`.
- [ ] Record V1 DOLA/USDC `principalOf` for the post-mortem ledger; (broadcast only) write `saga2-deployments.json` and patch `mainnet-addresses.ts`.

## Declared pre-conditions (require BEFORE the prank/broadcast block)
- `setUp`: `block.chainid == 1` (mainnet only).
- `run` top: `DOLA_ALLOTMENT > 0 && USDC_ALLOTMENT > 0` — the **allotment tripwire** (refuses to run with the as-shipped 0 values). SAFE configuration-safety pattern.
- `_preflight`: `DOLA.balanceOf(owner) >= DOLA_ALLOTMENT`.
- `_preflight`: `USDC.balanceOf(owner) >= USDC_ALLOTMENT`.
- `_preflight`: `staker.owner() == OWNER_ADDRESS`.
- `_registerOnV2` internal: `rate > 0` ("V1 exchangeRate is zero - cannot replicate config").
- `_v1Strategy` internal: `ys != address(0)` ("V1 strategy unset for token").

## Declared post-conditions (require/assert AFTER the writes)
- **NONE.** The script has **no post-condition assertions.** It does not assert that V2 was granted mint, that V1 was revoked, that `staker.migrator() == migrator`, that the new strategies are wired, or that the buffer was set. Every wiring step is fire-and-forget. `_printSummary` only logs. (This absence is itself a finding — see candidate-findings `MissingPostConditionAsserts`.)
- 2.3 (out of scope) later asserts `setAsideBufferSize(staker) == 10` on the new strategies, so the hardcoded-10 write is internally consistent with the downstream gate (but NOT with the live old-strategy value of 25 — see drift finding).

## Handoff contract (to 2.2 / 2.3, broadcast-only write)
Writes JSON keys: `migrator, ysDolaV2, ysUsdcV2, minterV2` (quoted hex addresses), `v1DolaPrincipal, v1UsdcPrincipal` (quoted decimal strings), `timestamp` (unquoted number).
- 2.2 reads `.migrator .ysDolaV2 .ysUsdcV2 .minterV2` via `vm.parseJsonAddress`.
- 2.3 reads `.ysDolaV2 .ysUsdcV2 .minterV2` via `vm.parseJsonAddress`.
- Key names and shapes MATCH; principals are written but never read. No handoff mismatch.
