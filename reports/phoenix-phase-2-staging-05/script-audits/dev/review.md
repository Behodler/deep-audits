# Script Review — `dev` (StableStaker slice of `DeployMocks` Phase 3.7)

**Project:** phoenix-phase-2-staging (run 05)
**Entry point:** `dev` (`npm run dev`)
**Scope:** the StableStaker introduction (Story 051) only — `DeployMocks.s.sol` Phase 3.7
**Mode:** local Anvil (chain-id 31337), mock contracts, no mainnet fork applicable
**Sibling review:** [`../verify-stable-staker/review.md`](../verify-stable-staker/review.md) — the end-to-end smoke check that exercises the same Phase 3.7 wiring.

## Scope and method

The `dev` entry point is a composite local bring-up:

```
clean:local -> start:anvil -> deploy:local (DeployMocks) -> simulate-yield.sh -> extract:addresses -> generate:ts-anvil -> serve
```

The StableStaker work lives entirely in `deploy:local` → `script/DeployMocks.s.sol` Phase 3.7 (lines ~654-685). The JS tail (`extract-addresses.js`, `generate-ts-addresses.js`, `index.js`) and `simulate-yield.sh` only *consume* the deployed StableStaker address; they do not configure the farm. This review therefore scopes to Phase 3.7 and the related Phase 8 (Pauser Registration), and treats the rest of the chain as address hand-off.

Because this is a local mock flow on chain-id 31337, "preview" means running `deploy:local` for real against a fresh Anvil and inspecting the resulting state with `cast`. Every claim below is corroborated by a direct on-chain read; there is no mainnet bytecode to corroborate against.

This review is structured around the three audit-script questions.

---

## 1. Does it do what it intends?

**Yes — every stated wiring step in Phase 3.7 was executed and empirically `cast`-verified correct.**

Phase 3.7 deploys `StableStaker(IFlax(MockPhUSD), deployer)` and wires three pools. The deployment exited 0 and the end-state matches the intent spec exactly:

| Intended end-state | Verified value | Method |
|---|---|---|
| `owner == deployer` (anvil acct0) | `0xf39F...` | `cast owner()` |
| `phUSD` immutable == MockPhUSD | `0x5FbD...` | `cast phUSD()` |
| StableStaker is an authorized phUSD minter | `authorizedMinters(SS) = (true, 1)` | `cast` on MockPhUSD |
| 3 pools registered: DOLA, USDC (MockRewardToken), USDe | `getStakedTokens() = 3 tokens` | `cast` |
| DOLA emission 10 phUSD/day | `phusdPerSecond = 115740740740740` | `cast poolInfo(DOLA)` |
| USDe emission 10 phUSD/day | `phusdPerSecond = 115740740740740` | `cast poolInfo(USDe)` |
| USDC emission 5 phUSD/day (intentionally reduced) | `phusdPerSecond = 57870370370370` | `cast poolInfo(USDC)` |
| Each pool's ERC4626 strategy wired **two-sided** | `yieldStrategy(token)` non-zero (staker side) + `authorizedClients(SS) = true` on all three strategies (client side) | `cast` |

The two-sided strategy authorization is the load-bearing detail: without the client-side `strategy.setClient(StableStaker, true)`, stake/withdraw revert. Both sides are present for all three strategies (`YieldStrategyDola`, `YieldStrategyUSDC`, `YieldStrategyUSDe`), and `setYieldStrategy` additionally `forceApprove`d each strategy for unlimited token. `paused() == false`, so normal operations are enabled.

The reduced USDC rate (5 vs 10 phUSD/day) is intentional per the Story-051 concerns ("so the reduced rate is visible in the UI") and is confirmed on-chain. The deploy ordering is acyclic and correct: Phase 1 tokens → Phase 2.x strategies → Phase 3.7 StableStaker, with no forward references.

The sibling `verify-stable-staker` review independently confirms this wiring is not merely present but *functional* end-to-end: a stake → 1-day warp → claim/withdraw round-trip runs GREEN against it.

---

## 2. Does it introduce unintended side effects?

**No unintended on-chain state writes.** Every write Phase 3.7 makes was enumerated and `cast`-verified as intended (constructor immutables, the minter authorization on MockPhUSD, the three pool registrations and rates, the three `yieldStrategy` slots, and the three strategy-side client authorizations). No collateral storage was mutated and no out-of-scope contract was touched.

The cluster check on `simulate-yield.sh` Phase 9.5 — which injects above-par DOLA into `MockAutoDOLA` (the vault behind `YieldStrategyDola`, a StableStaker client) — was examined for principal-accounting corruption and found **benign**: `withdrawDisabled(DOLA) == false` at deploy end (the vault is above par, not underwater), and above-par yield is protocol-owned by design — stakers receive principal plus phUSD only. The sibling verify run recovered principal with 1 wei dust and restored the baseline, confirming no corruption.

**The defect here is state that was *not* written, not state written incorrectly.** Two configuration slots that the deployment's own pattern would otherwise set are left at `address(0)`:

- `StableStaker.pauser() == 0x0` — `setPauser` is never called.
- `StableStaker.migrator() == 0x0` — `setMigrator` is never called.

These are the seed of the two findings discussed next.

---

## 3. Have other problems surfaced (cluster / knock-on)?

Two configuration-gap findings surfaced, both rooted in Phase 3.7 / Phase 8. No High or Medium emerged.

### L-01 — StableStaker has no working emergency stop and is excluded from the global Pauser

[`script/DeployMocks.s.sol#L654-L846`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/script/DeployMocks.s.sol#L654-L846) — Phase 3.7 + Phase 8 `run`. (`pps5l1`)

Phase 3.7 deploys and wires StableStaker but never calls `setPauser`. Phase 8 (Pauser Registration) then wires `setPauser` + `pauser.register` for **every other** `IPausable` protocol contract — PhusdStableMinter, PhlimboEA, StableYieldAccumulator, NFTMinter, NFTMinterV2, NFTStaker (6 `setPauser` + 6 `register` calls, source lines ~810-846) — while **omitting StableStaker entirely**. It is the only `IPausable` protocol contract left unregistered.

The consequence was verified empirically. `StableStaker.pause()` is `onlyPauser` (`require(msg.sender == pauser)`); with `pauser == address(0)` no caller can satisfy it. A negative test confirms it: `cast send StableStaker pause()` as the **owner** reverts with `StableStaker: only pauser`. The farm therefore can never be paused — the `whenNotPaused` guard on stake/withdraw/claim is dead code — and the ecosystem-wide EYE-burn Pauser trigger skips StableStaker because it was never registered. The farm has no functioning emergency stop while every sibling protocol contract has one.

This is classified **Low**, not Medium: it manifests on a local mock/anvil bring-up so no production assets are at risk; the staker's healthy stake/withdraw/claim paths function normally (the sibling verify run is green); and the owner can call `setPauser` + `register` post-deploy at any time without a redeploy. Its merit is that it is a silent deviation from the script's own established Phase-8 pattern and a template defect that would carry into any deployment cloned from `DeployMocks` — a production copy of this omission would leave a live farm without its emergency stop.

**Recommendation:** in Phase 3.7 (or Phase 8, alongside the other six) call `stableStaker.setPauser(address(pauser))` and `pauser.register(address(stableStaker))`, preserving the same "setPauser BEFORE register" ordering used for the other contracts.

### Q-01 — Migrator left inert; healthy exit paths unaffected

[`script/DeployMocks.s.sol#L654-L685`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/script/DeployMocks.s.sol#L654-L685) — Phase 3.7 `run`. (`pps5q1`)

`setMigrator` is never called, so `StableStaker.migrator() == address(0)` (confirmed via `cast`). The `onlyMigrator` entrypoints `initiateMigration` / `batchMigrate` / `depositFor` are consequently unreachable, and the `StableStakerMigrator` orchestrator is inert in this deployment. Critically, the healthy-path `withdraw` / `emergencyWithdraw` / `_routeExit` do **not** depend on `migrator` (a read of `StableStaker.sol` confirms `migrator` is referenced only by the migration entrypoints), so normal exits are unaffected — the sibling verify run withdrew principal cleanly. This is **QA**: a half-configured local-dev deployment whose only consequence is that the optional terminal-migration escape hatch is inert, fixable by a single owner `setMigrator` call post-deploy.

**Recommendation:** if the dev flow is meant to exercise migration, deploy `StableStakerMigrator` and call `stableStaker.setMigrator(migrator)` in Phase 3.7; otherwise document that migration is intentionally out of scope for local dev.

### Known issues checked and NOT re-reported

- **Phlimbo / StableYieldAccumulator circular-reference ordering hazard (known issue #7).** Checked and confirmed **not applicable** to StableStaker: the farm only consumes phUSD and the three ERC4626 strategies; it is **not** part of the Phlimbo/SYA cycle. The deploy ordering tokens → strategies → StableStaker is acyclic. Not re-reported (pre-existing known issue, and StableStaker confirmed outside the loop).
- **StableStaker dual-unpause (known issue #5).** Checked and not re-reported as a new finding; it is a documented design property. Note that in *this* deployment the dual-unpause is moot regardless — with `pauser == address(0)` the farm can never enter the paused state in the first place (see L-01).

---

## Verdict

Phase 3.7 does what it intends: StableStaker is deployed and fully wired for normal operation (3 pools, correct emission rates, two-sided strategy auth, minter rights), and this is empirically `cast`-verified and independently confirmed functional by the sibling `verify-stable-staker` run. It introduces no unintended on-chain writes. The two findings are both *omitted* configuration — the missing `setPauser`/`register` (L-01, Low) and the missing `setMigrator` (Q-01, QA) — neither of which affects a healthy user path and both of which are owner-recoverable post-deploy. **No High or Medium severity issue emerged.**
