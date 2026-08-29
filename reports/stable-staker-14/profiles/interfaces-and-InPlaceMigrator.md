# Contract Profiles — interfaces + InPlaceMigrator (sibling comparison)

## src/interfaces/IStableStakerMigratable.sol — NEW (story-014)

Pure interface, `^0.8.20`, no state, no implementation. Declares exactly three functions — the perpetual
"golden rule" triad — with **frozen signatures**:

| Function | Signature | Selector | Returns |
|---|---|---|---|
| `initiateMigration` | `initiateMigration(address)` | `0x71726c92` | — |
| `batchMigrate` | `batchMigrate(address,address[])` | `0x0ad9aeb9` | `uint256[] amounts` |
| `depositFor` | `depositFor(address,address,uint256)` | `0xb3db428b` | — |

**Verified properties**
- IF-01: Deliberately excludes `userMigrate` and `finalizeAndReset` — single-version lifecycle functions,
  not part of a version hop. Every additional member would be a permanent obligation on all future versions.
  **verified**
- IF-02: The leading `token` parameter is load-bearing (`StableStaker` is multi-pool). A one-pool redesign
  could not implement this interface, breaking the rule *by construction* — the NatSpec makes that a
  deliberate confrontation rather than a late discovery. **verified**
- IF-03: The documented return contract of `batchMigrate` (`Σ amounts ≤ R`, per-user
  `p_i·min(R,P)/P`, `0` for empty/self-migrated) **matches the `StableStaker` implementation exactly**
  (cross-checked against `_exitPosition` `:530`). No interface/implementation drift. **verified**
- IF-04: Enforcement is four-layer — compiler (`is IStableStaker`), a `PreToolUse` hook, a CI script, and
  selector-pinning tests. The hook layer has a **self-declared blind spot**: it only fires when
  `stable-staker` is the session project root, and this repo is normally driven as a submodule
  (`.claude/hooks/README.md`). The CI gate does not share that gap. **Noted, not adjudicated.**

## src/interfaces/IStableStaker.sol — CHANGED (story-014)

Now `is IStableStakerMigratable` and declares only one additional member: `userInfo(address,address)
returns (uint256 amount, uint256 rewardDebt)`, kept **out** of the triad on purpose (a convenience read for
`InPlaceMigrator._reinjectWithTopup`, not part of a version hop). Consumed by `InPlaceMigrator`;
`CrossVersionMigrator` deliberately types on the narrower `IStableStakerMigratable` instead.

## src/versions/IStableStakerV1.sol — NEW (story-015), 203 lines

Frozen snapshot of the deployed V1 surface at `0xbce8ABC09BaEDCabE93419bF875f6186e182079A` (Ethereum
mainnet). `interface IStableStakerV1 is IStableStakerMigratable`. Declares 34 members: owner config
(`addToken`, `phUSDPerDay`, `setMigrator`, `setPauser`, `setYieldStrategy`, `finalizeAndReset`,
`rescueERC20`), pausing, staking (`stake`/`withdraw`/`claim`/`emergencyWithdraw`/`userMigrate`), and the
view surface (`poolInfo`, `userInfo`, `poolState`, `migrationInfo`, `yieldStrategy`, `migrator`, `phUSD`,
`ACC_PRECISION`, `SECONDS_PER_DAY`, `withdrawDisabled`, staker enumeration).

**Verified**
- V1-01: Not deployed (interface), so it costs nothing against `forge build --sizes`. **verified**
- V1-02: `is IStableStakerMigratable` as the ritual requires — the golden rule is a compile-time obligation
  on the snapshot too. **verified**
- V1-03: `poolState` is declared as `uint8`, not the project enum — correct for a frozen wire-format record.
  **verified**

**Could NOT verify**
- V1-U1: **Whether this file actually matches the deployed V1 bytecode.** It declares `poolState`,
  `migrationInfo`, `withdrawDisabled` and `finalizeAndReset` — features that landed in recent stories. If
  the on-chain V1 predates them, the "only accurate description of that live instance" claim is false. This
  needs an on-chain ABI/bytecode comparison against `0xbce8…079A`. **Deferred to fork verification.**
- V1-U2: The file's own header concedes it imports `IYieldStrategy` from a submodule that tracks `master`,
  so "if that interface ever changes shape, this frozen snapshot inherits the churn." A frozen record with a
  moving import is not frozen. **Deferred.**

## src/InPlaceMigrator.sol — NatSpec-only change

The d95f4a6→HEAD diff is **15 lines, 100% comment**: three references to the deleted `StableStakerMigrator`
were repointed to `CrossVersionMigrator`. **No code, no signature, no storage change.** Profiled here only
as the comparison baseline for the new sibling.

Storage: `staker` (immutable), `migrationTimeout` (immutable, `MIN_TIMEOUT=1 days ≤ t ≤ MAX_TIMEOUT=30 days`),
`parked[token][user]`, `migrationBegin[token][user]`, `_parkedUsers[token]` (EnumerableSet),
`totalParked[token]`.

Entry points: `initiateMigration` (onlyOwner), `migrateOut` (onlyOwner, nonReentrant),
`migrateIn(token,start,end)` (onlyOwner, nonReentrant), `claimTimedOut(token)` (**permissionless**,
nonReentrant, self-scoped, gated on `migrationTimeout`), `rescueERC20` (onlyOwner, fenced below
`totalParked`), plus three views.

### The four structural differences from `CrossVersionMigrator`

| Dimension | `InPlaceMigrator` | `CrossVersionMigrator` |
|---|---|---|
| Custody window | **Multi-transaction.** Parks principal across `finalizeAndReset` + `setYieldStrategy`. | **Single-transaction.** Zero residual per call (delta-zero conservation). |
| Haircut compensation | `_reinjectWithTopup`: grosses up `topup = mulDiv(amt − credited, amt, credited)`, funded from live surplus, with a `finalCredited ≥ amt − amt/1000` backstop. | **None.** Explicitly rejected in NatSpec (E). The user eats the destination-side slippage. |
| Rescue path | `rescueERC20`, fenced by the `totalParked` floor. | **None at all** — nothing sent to it can ever be recovered. |
| User escape hatch | `claimTimedOut` — permissionless, self-scoped, opens after the timeout, guarantees unilateral recovery if the operator is incapacitated. | **None.** Users' only recourse if a cross-version migration stalls is `oldStaker.userMigrate`, which exits them from the system entirely (tokens to their own wallet, no destination credit). |

`ReentrancyGuard` is inherited by `InPlaceMigrator` but **not** by `CrossVersionMigrator`.

Both share the immutable-target rationale (sections (D) and (B) respectively): an owner-mutable
`depositFor` target is a drain vector, so a new pair of stakers means a new deployment plus re-wiring
`setMigrator` on both sides.

### Verified properties (unchanged from run-13, re-confirmed)
- IPM-01: `totalParked[token]` is a hard floor `rescueERC20` cannot cross — invariant (C) holds even
  against the owner. **verified**
- IPM-02: Two and only two exits for parked principal: `migrateIn → depositFor(original user)` and
  `claimTimedOut → transfer(self)`. **verified**
- IPM-03: `migrateIn` snapshots the slice into memory before mutating the set (removal shifts live indices).
  **verified**
- IPM-04: Strict CEI under `nonReentrant` in both `migrateIn` and `claimTimedOut` — `parked` is zeroed
  before every external call, so a token callback re-entering sees `parked == 0`. **verified**
- IPM-05: `migrateIn` approves the migrator's **full balance** (not the slice total), because the top-up leg
  pulls surplus beyond `total`; `forceApprove` overwrites so nothing dangles. Contrast with
  `CrossVersionMigrator`, which approves exactly `total`. **verified**

### Could NOT verify
- IPM-U1: The surplus-funded top-up's economic correctness depends on where the surplus comes from and
  whether it is guaranteed present. `require(topup ≤ balance − totalParked)` reverts the whole batch when
  exhausted — a live availability question. **Deferred (unchanged from run-13, already ledgered).**
