# Intent — stable-staker-v2-cutover (run-35, delta 84e2324..7ac6e70)

Sources @ 7ac6e70:
- `script/CutoverStableStakerV2Mainnet.s.sol` (`:preview` / `:broadcast`)
- `script/VerifyStableStakerV2Cutover.s.sol` (`:verify`)
- `scripts/patch-mainnet-addresses-stable-staker-v2.js` (the `:broadcast` tail)

npm lines 49–55.

Stories (all one glob hit each, state folder `auto-complete`, machine-approved): 082–088 carried from run-34, plus **088** (e98ef26/e3bf6aa, now in range), **089** (DeployMocks: out of scope as rehearsal fidelity, per owner ruling), **091** (5abbf05), and **092** (ad3c09a). Hard runtime dependency: **090** (the initiate script).

Unchanged since run-34 and still checked by the fork run: Phases 0–8 as audited in run-34. This file lists only what the delta adds or changes.

## Stated purpose — delta (story ACs authoritative)
### Story 088
- [x] `ERC4626_MAX_LOSS_BPS` 2 → 5. The Phase 0 strategy Pauser-registration assert was added. Phase 7 coverage gaps are documented in NatSpec + the runbook (HALT CAVEAT).
- [~] The `//stable-staker-v2-cutover:broadcast` comment still reads "Every other halt point, including every Phase 7 one, keeps the breaker live" (Q-04 residual, see ledger).
### Story 091 — source/destination split
- [x] V1 exits through the hard-coded SOURCE map. V2 deposits into the DESTINATION, which for DOLA is a new `ERC4626YieldStrategy(OWNER, DOLA, sDOLA)`.
- [x] Phase 3b does four things:
  - preflights `sDOLA.asset()==DOLA` and `maxDeposit >= V1 DOLA principal`
  - deploys the strategy and persists it (`contracts.ERC4626YieldStrategySDOLA`), failing closed on an unrecorded candidate
  - wires `setPauser(Pauser)` → `Pauser.register` while unpaused
  - runs `setWithdrawer(SYA)`
- [x] Per-user bound = source + destination bps (DOLA 10). The exit-realization bound uses the source bound.
- [x] Fork run: V2 DOLA principal lands in the sDOLA strategy and V1 principal on 0x1760 is 0.
### Story 092 — minter collateral, SYA, retire autoDOLA
- [x] Phase 0 requires the minter withdrawal Initiated with `initiatedAt+6h <= now` and `now + 6h < initiatedAt+78h` (`WINDOW_SAFETY_MARGIN` 6h). The check is skipped once the minter's autoDOLA principal == 0.
  - The story wording was "principal 0 AND repoint done". The documented deviation (Decision 4) is justified.
- [x] Phase 6b runs only after Phase 6: `V1 DOLA pool Migrating && principalOf(DOLA,V1)==0`.
- [x] Record the minter DOLA config (rate/decimals/enabled/maxMintPerDay) into `minterMove`, then `setStablecoinEnabled(DOLA,false)`.
- [x] Execute `totalWithdrawal(DOLA, minter)`. R = OWNER DOLA delta, bounded below by P·5bps+1000 wei, and persisted.
- [x] Steps: `sdola.setClient(minter)`, `minter.approveYS`, OWNER `approve(minter,0)` then `approve(minter,R)`, then `noMintDeposit(sdola, DOLA, R)`.
  - The story had `forceApprove`. The re-seed now runs BEFORE registration (Decision 1, documented).
- [ ] **AC: "Assert OWNER's DOLA balance is back to its level before execution, so no DOLA is left on OWNER."** The require exists but is evaluated only in forge's local pass. On a real (anvil) broadcast the mined R differed and **0.002309 DOLA stayed on OWNER while `:verify` passed** (see side-effects.json).
- [x] `registerStablecoin(DOLA, sdola, same rate, same decimals)` → `setMaxMintPerDay(prev)` → restore enabled.
  - Side effect: `mintedToday` and `lastMintTimestamp` are reset. The story acknowledges this as "clears mint-window state".
- [x] SYA `addYieldStrategy(sdola, DOLA)` and `removeYieldStrategy(0x1760)` (by value). Source `setWithdrawer(SYA,false)`. The sDOLA withdrawer is asserted.
- [x] Retire the source: clients off, then `setPauser(OWNER)` → `Pauser.unregister` → `pause`. This is the second one-tx global-pause dead window (halt g).
- [x] Phase 8 and the verifier assert the full end state (registration, cap, SYA list, withdrawers, retired source, registrant sweep).
- [x] Patch script:
  - `YieldStrategyDola` 0x1760 → sDOLA strategy (PATCH/SAME/COLLIDE)
  - fill `YieldStrategyDolaLegacy`
  - confirm `SDOLA`
  - the key-set drift guard is kept (fork: interface 57 = data 57, despite conflict markers in addresses.ts)
- [x] Runbook: initiate → wait ≥6h, status EXECUTABLE → preview → top up → broadcast (patch → verify → preview), plus the re-initiate path.
- [~] Doc drift in the runbook:
  - The `:broadcast` comment still says "46 transactions" and "EXCEPT the one forced tx" (now 67 txs and two dead windows).
  - `CUTOVER_GAS_BUDGET` is 22M against 22.98M measured.

## Declared pre-conditions (delta)
- Phase 0: `WAITING_PERIOD/EXECUTION_WINDOW == 6h/72h` on 0x1760; SYA owner == OWNER; the minter DOLA registration ∈ {0x1760, recorded sDOLA strategy}; the retired-source branch skips the pause/registration checks. The window preflight is described above.
- Broadcast only: OWNER on-chain ETH ≥ `22,000,000 × CUTOVER_GAS_PRICE_WEI × 1.2`, read via `eth_getBalance` (story 087).
- Phase 3b: DOLA ∈ V1 tokens; `sDOLA.asset()==DOLA`; no unrecorded sDOLA-shaped registrant and no V2 DOLA routing; `maxDeposit ≥ V1 DOLA principal`. The CREATE happens before the capacity check (disclosed in 091).
- Phase 6b:
  - the sDOLA strategy is known
  - the V1 DOLA pool is Migrating and V1's principal on the source is 0
  - the recorded config requires registration == 0x1760 at record time and rate > 0
  - `_requireMinterWithdrawalExecutable(margin 0)` holds immediately before the execute (local pass)

## Declared post-conditions (delta)
- After the execute: minter autoDOLA principal == 0; status reset to None; `P − R ≤ P·5bps + 1000 wei`. All local pass.
- After the re-seed: `_doneMinterReseeded()` (principal + R·5bps + 1000 ≥ R) and `DOLA.balanceOf(OWNER) == ownerDolaBeforeExec`. Both are local-pass only, and the second is **violated on chain** (above).
- `_doneMinterRepointed`, `_doneSyaListRepointed`, `_doneSourceWithdrawerRevoked`, `_doneSdolaStrategyWithdrawer`, `_doneSourceDolaRetired`
- Phase 8: the registrant sweep excludes the retired source; the story-092 end state.
- `:verify` re-reads all of these from chain. The R check is a lower bound against the **recorded (local-pass) R**. It does not check that OWNER's DOLA returned to its pre-execution level.
