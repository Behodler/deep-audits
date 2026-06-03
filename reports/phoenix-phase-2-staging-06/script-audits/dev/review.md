# Script Audit Review — `dev`

| Field | Value |
|-------|-------|
| **Project** | `phoenix-phase-2-staging` |
| **Entry point** | `dev` (npm script) |
| **Run** | `phoenix-phase-2-staging-06` |
| **HEAD commit** | `bd2290c` — *[story-052] Wire StableStaker into global Pauser (Phase 8) + config audit* |
| **Regression window** | `912f57c..bd2290c` |
| **Verification mode** | Local-Anvil **preview** (chain-id `31337`) — *not* a mainnet fork |
| **Tooling** | forge / anvil `1.5.1-stable (b0a9dd9)` |

### Verification mode note

The `dev` entry point is structurally local-only: it broadcasts to `http://localhost:8545`
(chain-id `31337`) using the publicly-known default Anvil key, and every contract is freshly
`CREATE`-deployed by the script at deterministic Anvil nonces. There are no pre-existing on-chain
addresses to corroborate (`forkAvailable=false`), so the standard `/audit-script` **mainnet-fork
side-effect verification is N/A** for this entry point. Verification was instead performed
empirically by running the full deploy on a **fresh local Anvil from `workspace/`** (never `lib/`)
and reading the resulting state back with `cast`.

---

## Closure (brief)

The `dev` chain is a clean orchestration sequence:

```
clean:local → start:anvil → deploy:local → simulate-yield.sh → extract:addresses → generate:ts-anvil → serve
```

The single **in-focus** step is `deploy:local`
(`forge script script/DeployMocks.s.sol:DeployMocks --broadcast --slow`). The remaining
shell/node steps (`simulate-yield.sh`, the address-extraction and TS-binding generators, and the
Express `serve` API) are auxiliary off-chain tooling the user verifies manually; they are not
deep-mapped here.

StableStaker (from the nested submodule `lib/stable-staker` @ `f5f6039`) is the audit subject:

- **Deployed** — `script/DeployMocks.s.sol:660`
  (`new StableStaker(IFlaxStaker(address(phUSD)), deployer)`).
- **Minter-authed** — `script/DeployMocks.s.sol:665`
  (`phUSD.setMinter(address(stableStaker), true)`), enabling the reward-mint path.
- **Pooled (DOLA / USDC / USDe)** — `script/DeployMocks.s.sol:675-684`
  (per-token `addToken` + strategy `setClient` + `setYieldStrategy` + `phUSDPerDay`).
- **Pauser-wired (story-052)** — `script/DeployMocks.s.sol:849-855`
  (`stableStaker.setPauser(pauser)` then `pauser.register(stableStaker)`).

The deploy executed end-to-end with **163 transactions, no reverts**.

---

## Q1 — Does it do what it intends?

**Yes.** story-052's stated purpose — wire the already-deployed StableStaker (story-051) into the
global Pauser so a single global `pause()` halts the farm alongside the other six pausable
contracts — is achieved and proven end-to-end on local Anvil.

**Empirical results (cast, chain-id 31337):**

- `StableStaker.pauser() == Pauser` — the deployed Pauser at `0x0B306BF915C4d645ff596e518fAf3F9669b97016`.
- `Pauser.isRegistered(StableStaker) == true` — StableStaker is the **7th and last** of 7 entries
  in `getPausableContracts()`.
- **End-to-end pause works:** after minting + approving 1000 `MockEYE` (burned by the Pauser),
  a global `Pauser.pause()` flips `StableStaker.paused()` `false → true`, and a subsequent
  `stake()` reverts with `EnforcedPause()` (`0xd93c0665`).
- **Recovery works:** owner `Pauser.unpause()` flips `paused()` back to `false` and clears the
  `EnforcedPause` gate on `stake()` (the residual revert afterward is a benign
  `ERC20InsufficientAllowance` from the static `eth_call`, confirming `whenNotPaused` no longer
  blocks).

**Ordering is correct.** `Pauser.register` (`lib/pauser/src/Pauser.sol:92`, `onlyOwner`) validates
`IPausable(target).pauser() == address(this)` (lines 98-99). The broadcast runs
`StableStaker.setPauser` (tx 127) immediately before `Pauser.register(StableStaker)` (tx 128),
satisfying the precondition. The deployer owns both StableStaker and the Pauser
(`0xf39Fd6…92266`), so both `onlyOwner` calls succeed.

---

## Q2 — Does it introduce unintended side effects?

**No.** story-052 introduced **exactly two** state writes, both intended and both proven:

| Contract | Write | From → To | Tx | Intended |
|----------|-------|-----------|----|----------|
| StableStaker | `pauser` | `0x0` → `0x0B30…7016` (Pauser) | 127 | yes |
| Pauser | `isRegistered[StableStaker]` + `_pausableContracts.push` | `false` → `true` | 128 | yes |

No other effects were observed:

- No clobbering of the 6 pre-existing Pauser registrations (minter, PhlimboEA,
  StableYieldAccumulator, NFTMinter, NFTMinterV2, NFTStaker) — the array still holds 7 total with
  StableStaker appended last.
- No ownership change.
- No double-registration.

The full `DeployMocks` deploy completed successfully (163 txs, no reverts). Every StableStaker /
Pauser write in the broadcast maps to a stated purpose (the story-051 pool wiring at lines 675-684
plus the story-052 `setPauser`/`register` pair).

---

## Q3 — Have other problems surfaced (cluster / knock-on)?

**No new problems.** On the `dev` Anvil, only two sibling scripts share the StableStaker contract:

- `script/interactions/StakeStableStaker.s.sol` — stakes 1000 DOLA (story-051 verification, first half).
- `script/interactions/ClaimWithdrawStableStaker.s.sol` — after +1 day, claims phUSD and withdraws
  principal, asserting ~10 phUSD reward (story-051 verification, second half).

Both are story-051 verification interactions run against the same local deployment, and both exercise
the reward-mint path that relies on the `phUSD.setMinter(stableStaker)` authorization wired at line
665. Nothing is broken by story-052's change.

No other `script/*.s.sol` both touches StableStaker and shares the `dev` deployment. The many
Pauser-referencing mainnet deployment/governance scripts build their own (mainnet) context, target a
different chain, and share no `dev` address — they are out of this closure.

---

## Ledger outcome

| ID | Title | Status |
|----|-------|--------|
| **L-01** | StableStaker deployed with `pauser == address(0)` | **FIXED** at `bd2290c` |
| **Q-01** | StableStaker deployed with `migrator == address(0)` | **STILL-OPEN** (QA) |
| candidate | DeployMocks has no `block.chainid` guard | **SUPPRESSED** (documented known issue) |

### L-01 → FIXED at `bd2290c` (story-052)

The prior-run finding *"StableStaker deployed with pauser == address(0): farm has no working
emergency stop and is excluded from the global Pauser"*
(`reports/phoenix-phase-2-staging-05/findings/low/L-01-stablestaker-pauser-zero.json`,
fingerprint `c294d93f…`) is **resolved** by story-052.

**Fix evidence:** `script/DeployMocks.s.sol:849-855` now calls `setPauser(pauser)` then
`pauser.register(stableStaker)`. Empirically @ `bd2290c` on local Anvil: `StableStaker.pauser()`
equals the deployed Pauser, `Pauser.isRegistered(StableStaker) == true` (7th registered), a global
`Pauser.pause()` flips `StableStaker.paused()` and `stake()` reverts `EnforcedPause()`
(`0xd93c0665`), and owner `unpause()` recovers. The ledger entry is marked `fixed` with
`fixedAtCommit = bd2290c`.

### Q-01 → STILL-OPEN (QA)

*"StableStaker deployed with `migrator == address(0)`: terminal-migration path is permanently
unreachable"* (fingerprint `0b497be3…`,
original `reports/phoenix-phase-2-staging-05/findings/qa/Q-01-stablestaker-migrator-zero.json`)
remains **STILL-LIVE @ `bd2290c`**: `StableStaker.migrator()` is still `address(0)`, story-052 did
not touch it, and `StableStakerMigrator` is not deployed by the `dev` stack. The post-condition
check `StableStaker.migrator() set` correctly reports `false`.

This is **local-dev-only**, and migration is an optional / terminal feature, so it remains
**QA-level**, not a functional defect of the `dev` deploy. Carryover stub:
`reports/phoenix-phase-2-staging-06/findings/qa/Q-01-CARRYOVER.md`.

### Candidate "no `block.chainid` guard" → SUPPRESSED

`DeployMocks` only `console.log`s `block.chainid` and never enforces
`require(block.chainid == 31337)`. This is **suppressed** as a documented local-dev known issue
(CLAUDE.md "Local Development Only" / "Configuration Safety"). The `dev` entry point is structurally
local-only (targets `localhost:8545`, chain-id `31337`), so there is no realistic misfire path.
Noted for completeness only.

---

## Bottom line

story-052 cleanly fixes **L-01** (StableStaker is now wired into the global Pauser, with end-to-end
pause/unpause proven on local Anvil) and does so with **no regressions and no new findings** — its
footprint is exactly the two intended state writes at `DeployMocks.s.sol:849-855`. The only
outstanding item is the pre-existing **QA-level Q-01** (unset `migrator`), which is intentional for
the dev stack and remains open for triage.
