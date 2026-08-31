# Intent — dev (DeployMocks.s.sol:DeployMocks)

Regression window: `912f57c..bd2290c`. The only closure-relevant source change is the 9-line
Phase-8 Pauser-registration block for StableStaker at `script/DeployMocks.s.sol:849-855`
([story-052] "Wire StableStaker into global Pauser"). Scope is tightened to that change plus the
two open ledger findings it bears on (L-01, Q-01).

## Stated purpose (from story-052 commit + in-script comments + closure manifest)
- [x] Wire the already-deployed StableStaker (story-051) into the global Pauser so a single global
      `pause()` (burn 1000 EYE) also pauses the StableStaker farm alongside
      PhusdStableMinter / PhlimboEA / StableYieldAccumulator / NFTMinter / NFTMinterV2 / NFTStaker.
- [x] Concretely: `stableStaker.setPauser(address(pauser))` then `pauser.register(address(stableStaker))`.

## Declared pre-conditions (enforced by the contracts the block calls, not by explicit `require`s in the script)
- StableStaker owner == deployer (so `setPauser` — `onlyOwner` — succeeds). VERIFIED: owner == deployer `0xf39Fd6…92266`.
- Pauser owner == deployer (so `register` — `onlyOwner` — succeeds). VERIFIED: Pauser owner == deployer.
- `setPauser(pauser)` MUST run before `register` — `Pauser.register` validates
  `IPausable(target).pauser() == address(this)` (Pauser.sol:98-99). VERIFIED ordering: broadcast tx 127
  (`StableStaker.setPauser`) immediately precedes tx 128 (`Pauser.register(StableStaker)`).
- StableStaker must implement `pauser()` getter (IPausable). VERIFIED: `StableStaker.pauser()` exists and is read by `register`.

## Declared post-conditions (proven empirically on local anvil, chain-id 31337)
- [x] `StableStaker.pauser() == Pauser` (`0x0B30…7016`).
- [x] `Pauser.isRegistered(StableStaker) == true`; StableStaker is the 7th/last entry of `getPausableContracts()`.
- [x] **End-to-end pause works**: `Pauser.pause()` (after minting+approving 1000 MockEYE, burned by the
      Pauser) flips `StableStaker.paused()` false→true, and a `stake()` call then reverts with
      `EnforcedPause()` (`0xd93c0665`).
- [x] **Recovery works**: owner `Pauser.unpause()` flips `paused()` back to false and clears the
      `EnforcedPause` gate on `stake()`.

## Notes on what is NOT configured (in scope per user, bears on Q-01)
- `StableStaker.setMigrator(...)` is never called by DeployMocks. `migrator()` stays `address(0)` →
  terminal-migration path (`initiateMigration`/`batchMigrate`/`depositFor`, all `onlyMigrator`) is
  unreachable in the dev stack. story-052 did not touch this; StableStakerMigrator is not deployed by dev.

## Known issues deliberately NOT reported (per known-issues.md scope)
Dual-unpause redundancy (owner OR pauser can unpause), mock unlimited minting (MockEYE/MockDola
open `mint`), local-dev unrestricted permissions / no `block.chainid==31337` guard on DeployMocks,
two-step APY commit. These are documented and out of finding scope.
