# Script Audit — `migrate:ss-initiate-mainnet` (InitiateYieldStrategyWithdrawal)

**Project:** phoenix-phase-2-staging
**Entry point:** `migrate:ss-initiate-mainnet`
**Forge target:** `script/InitiateYieldStrategyWithdrawal.s.sol:InitiateYieldStrategyWithdrawal` (`run`)
**Story:** 054 — Mainnet StableStaker migration, **set 1 of 2 (phase-1 "initiate")**
**HEAD commit:** `ddf7a414e290199cefe82ed29ba5ec2cf72ceff0`
**Fork verification:** live, mainnet RPC (`RPC_MAINNET`) @ block ~25232738
**Outcome:** Does what it intends; no unintended side effects; three Low knock-on findings (no asset-loss path).

---

## 1. Closure summary

The Solidity closure of this entry point is deliberately shallow. The script imports only `forge-std`
(`Script.sol`, `console.sol`); all audited behavior is reached **on-chain** through an inline minimal
interface, `ILiveYieldStrategy`, rather than through a Solidity import. The interface exposes six
selectors — `owner()`, `underlyingToken()`, `paused()`, `principalOf(address,address)`,
`withdrawalStates(address,address)`, and the single state-changing `totalWithdrawal(address,address)`.
The interface is intentionally narrow: per the script's own comment, the deployed bytecode predates the
EnumerableSet client refactor, so the script avoids importing the newer in-repo `AYieldStrategy` whose
`getAuthorizedClients`/`authorizedClientCount` getters would revert against the live contracts.

The authoritative semantics for what `totalWithdrawal` does are defined in the nested submodule
`lib/vault/src/AYieldStrategy.sol` (reached on-chain, not imported): `WAITING_PERIOD = 24h`,
`EXECUTION_WINDOW = 48h`, `TOTAL_DURATION = 72h`, the `WithdrawalStatus {None, Initiated, Executable, Expired}`
state machine, `_initiateWithdrawal`, and the `WithdrawalInitiated` event. The concrete deployed type is
consistent with `lib/vault/src/concreteYieldStrategies/ERC4626YieldStrategy.sol` (the `market()` probe
reverts on all three live addresses, ruling out `ERC4626MarketYieldStrategy`); the concrete type does not
alter the closure, since the two-phase logic lives in the `AYieldStrategy` base.

**On-chain surface (mutated):** three live ERC4626 yield strategies —
- DOLA `0xE7aEC21BF6420FF483107adCB9360C4b31d69D78`
- USDC `0x8b4A75290A1C4935eC1dfd990374AC4BD4D33952`
- USDe `0xFc629bC5F6339F77635f4F656FBb114A31F7bCB3`

**On-chain surface (referenced):** `client = PHUSD_STABLE_MINTER 0x435B0A1884bd0fb5667677C9eb0e59425b1477E5`
(the snapshotted minter whose principal is withdrawn), `OWNER_ADDRESS 0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6`
(ledger signer, HD path `m/44'/60'/46'/0/0`), and the three token constants asserted against each
strategy's `underlyingToken()`.

**Off-chain state:** none mutated at runtime. `server/deployments/mainnet-addresses.ts` is cited in a
source comment as the provenance of the strategy addresses but is **not read** by the script (no
`vm.readFile`/fs access); all addresses are hardcoded constants. No node pre/post scripts wrap either
variant (`jsChain` empty) — this is a pure forge invocation. The broadcast variant will write a
`broadcast/.../run-latest.json` as a normal `--broadcast` artifact, but no JS chain consumes it.

**Chain gating:** `setUp()` requires `block.chainid == 1`, reverting `"Wrong chain ID - expected Mainnet (1)"`
otherwise.

**Variants:**

| Variant | Command shape | Broadcasts | Signing / impersonation |
|---|---|---|---|
| preview | `PREVIEW_MODE=true forge script … --slow -vvv` | no | `vm.startPrank(OWNER_ADDRESS)` |
| broadcast | `forge script … --broadcast --skip-simulation --slow --ledger --hd-paths "m/44'/60'/46'/0/0" -vvv` | yes | `vm.startBroadcast()`, ledger signs each `totalWithdrawal` |

---

## 2. Does it do what it intends?

**Yes.**

### Stated intent

Story 054 phase 1 of 2 opens a 24h total-withdrawal window on the three live mainnet yield strategies so
they can later be drained and replaced by versions supporting `setAsideBuffer`. The script calls
`totalWithdrawal(token, client)` exactly once per strategy with `client = PHUSD_STABLE_MINTER`. Because each
strategy is in `WithdrawalStatus.None`, each call routes into phase-1 `_initiateWithdrawal`, which snapshots
the client's principal, sets status `Initiated`, and emits
`WithdrawalInitiated(token, client, balance, initiatedAt, executableAt = initiatedAt + 24h)`. **No funds move**
in this phase; token transfers belong to phase 2 (story 055), which re-calls the same function inside
`[executableAt, executableAt + 48h]` to execute the drain.

### Implementation vs. intent

The implementation matches the stated intent. Per strategy, the script asserts the documented
pre-conditions before calling `totalWithdrawal`:

| Pre-condition | Purpose |
|---|---|
| `strategy.owner() == OWNER_ADDRESS` | `onlyOwner` gate — fail loud early |
| `strategy.underlyingToken() == token` | wrong-token drift guard |
| `!strategy.paused()` | `totalWithdrawal` is `whenNotPaused` |
| `strategy.principalOf(token, minter) > 0` | empty position reverts in `_initiateWithdrawal` |
| `withdrawalStates(token, minter).status == None(0) \|\| Expired(3)` | guards in-waiting-period revert and accidental re-run after execute |

The one intent-vs-implementation gap is on the **output** side, not the action: the script encodes **no
post-condition** — it does not read `withdrawalStates` back to confirm the transition to `Initiated`, and
the `executableAt` it logs is **recomputed in the script** (`block.timestamp + WAITING_PERIOD`) rather than
read from the contract. The intended state writes all occur correctly under current code, but the script
does not *prove* them. This is captured as L-02 below.

### Live-fork preview result

Preview was executed live against a mainnet fork (RPC `RPC_MAINNET`) at block 25232738, owner-impersonated
(`vm.startPrank(0xCad1a78…)`), no broadcast, `reverted: false`:

- **9/9 non-negotiable preflight asserts passed** across the three strategies (owner == deployer,
  underlyingToken == token, `!paused`, principal > 0, status == None). Observed principals: DOLA
  `13328667173916334458804`, USDC `11834021432`, USDe `3763926783848240421169` — all `> 0`; all three at
  status `0 (None)`, so initiation is valid right now.
- **3/3 `totalWithdrawal` calls succeeded**, each routing through `_initiateWithdrawal` (status was `None`).

Initiation is valid at HEAD against current mainnet state.

---

## 3. Does it introduce unintended side effects?

**No.** Empirically verified on the fork:

### Fork side-effects table

| Effect class | Observed | Intended? |
|---|---|---|
| State writes | **exactly 3** — `withdrawalStates[token][minter]` per strategy, `None(0) → Initiated(1)`, balance = snapshotted principal, `initiatedAt = 1780440035` | yes |
| Events | **exactly 3** `WithdrawalInitiated`, one per strategy, `executableAt = 1780526435` (= initiatedAt + 24h), `balance` matching each `principalOf` | yes |
| Token transfers | **0** | n/a (phase 1 moves no funds) |
| `Deposited` / `Withdrawn` / `WithdrawalExecuted` / ERC-20 `Transfer` events | **0** | n/a |
| Off-chain file writes | **none** (addresses hardcoded; `mainnet-addresses.ts` referenced in a comment only, never read) | n/a |
| `unintendedEffects` | **`[]`** | — |

Per-strategy state writes and emitted balances (fork):

| Strategy | Address | From → To (status) | Snapshot balance | executableAt |
|---|---|---|---|---|
| DOLA | `0xE7aEC2…` | None(0) → Initiated(1) | `13328667173916334458804` | `1780526435` |
| USDC | `0x8b4A75…` | None(0) → Initiated(1) | `11834021432` | `1780526435` |
| USDe | `0xFc629b…` | None(0) → Initiated(1) | `3763926783848240421169` | `1780526435` |

The observed effect surface equals the intended effect surface exactly: three withdrawal-state transitions
and three matching events, with zero token movement and zero off-chain mutation.

---

## 4. Have other problems surfaced because of it?

**Yes — three Low findings.** All are knock-on / half-configured-state concerns surfaced operationally by
this entry point's two-phase design. **None is an asset-loss path**; phase-2 withdraw caps to available
principal, and re-initiation is permitted from `Expired`, so funds are never permanently stuck.

### L-01 — Phase-2 executor absent (story-055 drain script missing)

- **File:** [`reports/phoenix-phase-2-staging/07/findings/low/L-01-phase2-executor-absent.md`](../../findings/low/L-01-phase2-executor-absent.md)
- **Location:** `script/InitiateYieldStrategyWithdrawal.s.sol` — `run`
- **Category:** cluster-interaction · **Root cause:** MissingPostStepConfiguration · **Fork-verified:** yes

Story 054 is an explicit two-set operation, but a repository-wide search for the phase-2 executor turns up
nothing — no script/JSON/TS matching `story 055` / `ExecuteYieldStrategyWithdrawal` / `ss-execute`. The
migration is therefore committed half-configured: the broadcastable phase-1 step exists, its phase-2
counterpart does not. If set 2 does not re-call `totalWithdrawal` within `[executableAt, executableAt+48h]`
(24h–72h after this run), the three windows lapse to `Expired`, the migration silently stalls, and it must
be restarted (re-snapshotting principal). Operational risk is a stalled/restarted migration, not loss.

### L-02 — No post-condition read-back

- **File:** [`reports/phoenix-phase-2-staging/07/findings/low/L-02-missing-postcondition-readback.md`](../../findings/low/L-02-missing-postcondition-readback.md)
- **Location:** `script/InitiateYieldStrategyWithdrawal.s.sol` — `_initiate`
- **Category:** intent-mismatch · **Root cause:** MissingPostConditionAssert · **Fork-verified:** yes

The script asserts only pre-conditions; after `totalWithdrawal` it never reads `withdrawalStates(token, minter)`
back to confirm `status == Initiated(1)` and `balance == principal`. The logged `executableAt` is recomputed
in the script, not read from the contract, so a contract-side anomaly (divergent transition, different
snapshot, version skew) would go uncaught. This is compounded in the broadcast variant by `--skip-simulation`,
which removes forge's own pre-broadcast safety net — leaving the operator with no on-chain confirmation that
the window opened as expected. Defense-in-depth / operational-confidence gap, not a fund-loss path; under
current code the fork end state is correctly `Initiated` for all three.

### L-03 — Stale snapshot across the two-phase window

- **File:** [`reports/phoenix-phase-2-staging/07/findings/low/L-03-stale-snapshot-two-phase-window.md`](../../findings/low/L-03-stale-snapshot-two-phase-window.md)
- **Location:** `lib/vault/src/AYieldStrategy.sol` — `_executeWithdrawal` (external lib, surfaced operationally)
- **Category:** cluster-interaction · **Root cause:** StaleSnapshotAcrossTwoPhaseWindow · **Fork-verified:** yes

Phase 1 snapshots principal into `withdrawalStates[token][minter].balance`; phase 2's `_executeWithdrawal`
drains the **cached snapshot**, not live principal, then resets status to `None`. Verified against source:
`withdrawalStates` gates nothing but `totalWithdrawal` — `deposit`, `withdraw`, `totalBalanceOf`,
`principalOf`, and `skimSurplus` do not consult it. Initiation is a pure timer, so phUSD mint/redeem and
yield accrual continue normally through the 24–72h window. Consequently a **net deposit** in the interim
leaves residual undrained principal after phase 2 (**incomplete migration**); a **net withdrawal** makes
the cached amount exceed available principal, and phase-2 withdraw caps to available — under-draining
gracefully with no overdraw and no revert. The root cause lives in the external `vault` base but is
admissible here because this entry point's two-phase design opens the snapshot window. Realistic failure
mode is an incomplete migration requiring a follow-up sweep, not an exploit.

---

## 5. Cluster analysis

The strongest cluster link is the **pending successor**: story 055 (set 2, "execute"). This entry point
leaves all three strategies in `WithdrawalStatus.Initiated`; the migration is only complete once set 2
re-calls `totalWithdrawal` in the execution window to drain. No `migrate:ss-execute-mainnet` npm key or
companion execute script exists at HEAD (grep over `story 055` / `ExecuteYieldStrategyWithdrawal` /
`ss-execute` is empty) — the gap that drives L-01. Shared addresses: all three strategies + the minter.

The nearest existing templates for the missing set-2 executor are sibling two-phase `totalWithdrawal` flows
already in the repo:

| Template | Entry point | Story | Relation / value |
|---|---|---|---|
| `RebalanceUSDeInitiate.s.sol` | `mainnet:rebalance-usde-initiate` | 038 | Same initiate pattern on DOLA + USDC; reference implementation to diff intent against. |
| `RebalanceUSDeExecute.s.sol` | `mainnet:rebalance-usde-execute` | 038 | Phase-2 execute counterpart; **closest model** for the missing story-055 executor (window timing, funds-to-owner branch). |
| `PartialMigrationInitiate.s.sol` | `mainnet:partial-migrate-initiate` | 034 | Two-phase initiate on AutoPool strategy; corroborates the 24h-window semantics. |
| `PartialMigrationExecute.s.sol` | `mainnet:partial-migrate-execute` | 034 | Phase-2 execute; shows the **unpause-before-execute** step set 2 will likely also need. |
| `AutoUSDC/FullMigration{Initiate,Execute}.s.sol` | `mainnet:autousdc-migrate-{initiate,execute}` | none | Same mechanic on AutoUSDC; lower priority (only the minter client is shared by convention). |

None of these target the three story-054 strategies for the execute leg, confirming the absence is specific
to this migration rather than a missing pattern.

---

## 6. Operator checklist — before broadcasting set 1

Set 1 (`migrate:ss-initiate-mainnet`) and set 2 (story 055) are an atomic operational pair. Do not broadcast
set 1 until all of the following hold:

1. **Author + stage the story-055 executor (closes L-01).** Write and fork-verify the phase-2 drain script
   (model it on `RebalanceUSDeExecute` / `PartialMigrationExecute`, including any unpause-before-execute
   step), and stage it before opening the windows. Treat set 1 and set 2 as a single committed operation so
   the 72h window cannot lapse half-migrated.
2. **Confirm minter quiescence or pause (closes L-03).** Either pause the three strategies / freeze the
   minter's deposits + redemptions for the migration window, or confirm the minter is quiescent across the
   24–72h window, so the cached principal snapshot cannot drift and leave residual undrained principal. If
   quiescence cannot be guaranteed, have phase 2 re-read live principal and reconcile any residual.
3. **Add post-condition read-backs (closes L-02).** After each `totalWithdrawal`, read
   `withdrawalStates(token, minter)` back and `require(status == Initiated(1) && balance == principal)`; log
   the **contract's** `executableAt`, not a script-recomputed value. This is especially important given the
   broadcast variant runs with `--skip-simulation`.

---

## Verification provenance

Fork verification was **live** against mainnet (RPC `RPC_MAINNET`) at block ~25232738, HEAD
`ddf7a414e290199cefe82ed29ba5ec2cf72ceff0`, preview variant, owner-impersonated, no broadcast. Preflight:
9/9 asserts passed; calls: 3/3 succeeded; `unintendedEffects: []`; token transfers: 0.

**Path written:** `reports/phoenix-phase-2-staging/07/script-audits/InitiateYieldStrategyWithdrawal/review.md`
