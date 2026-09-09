# Profile: src/CrossVersionMigrator.sol + src/InPlaceMigrator.sol @ fa06de5

## CrossVersionMigrator (242 LOC, Ownable)

**Diff in range 2146428..fa06de5: NatSpec only.** `git diff` touches lines 12, 35-36, 55-57 —
"phUSD" → "reward token / Antimatter on V2 and onward". **Zero executable change.**

| Function | Access | Reads | Writes | External calls |
|---|---|---|---|---|
| `initiateMigration(token)` | onlyOwner | `newStaker`, `oldStaker` | none | `newStaker.getStakedTokens()` (staticcall probe), `newStaker.migrator()` (staticcall probe), `oldStaker.initiateMigration(token)` |
| `migrate(token,users[])` | onlyOwner | `oldStaker`, `newStaker` | none (stateless) | `oldStaker.batchMigrate`, `IERC20.forceApprove(newStaker,total)`, `newStaker.depositFor` per user, `STAKER_VERSION()` staticcall x2 |
| `versionOf(a)` | view | — | — | `a.STAKER_VERSION()` staticcall |

Properties:
- **CVM-1 (VERIFIED-BY-READING)** — no mutable storage at all; `oldStaker`/`newStaker` are
  `immutable`, aliasing rejected in the constructor :128. No retarget vector.
- **CVM-2 (VERIFIED-BY-READING)** — `total = Σ amounts` :164-167 and the approval is `forceApprove(total)`
  :173; `depositFor` pulls exactly `amounts[i]` per user, so the allowance is fully consumed and
  never left dangling. Σ deposits == total received.
- **CVM-3 (VERIFIED-BY-READING)** — zero-credit users skipped :177, not reverted.
- **CVM-4 (VERIFIED-BY-READING)** — the pre-flight probes fail **open**: `_isRegisteredOn` returns
  `true` on probe failure :235, `_migratorOf` returns `probed=false` and the require is
  `!probed || …` :150. Deliberate (documented section C) but means the guard is advisory.
- **CVM-5 (ASSUMED)** — `batchMigrate` transfers the aggregate to this contract before returning.
  Not checked here (no balance assertion around the call). If the source staker's transfer fails
  silently the `depositFor` loop simply reverts on insufficient balance.
- Unbounded loops: `migrate` over `users[]` and `_isRegisteredOn` over `getStakedTokens()`, both
  owner-only.

**Value flow:** old staker → (aggregate credit) → this contract → per-user `depositFor` → new
staker. No reward token is ever touched here; the reward mint happens inside the source staker's
`_exitPosition`. Rounding: none introduced — amounts are passed through verbatim.

**Trust boundaries:** `oldStaker`/`newStaker` (immutable, trusted staker implementations typed on
the golden-rule triad); `IERC20(token)` (standard). Runbook obligations that are NOT enforced:
destination is an approved minter of ITS OWN reward token (Antimatter for V2, phUSD for V1), and
source-side `setMigrator`.

**Story-023 note (VERIFIED):** the migrator is reward-token agnostic by construction — it never
imports or references either token. A V1→V2 hop therefore mints **phUSD** on the way out of V1 and
credits principal into a V2 pool that will emit **Antimatter**. That asymmetry is real and correct,
and is now documented at :35-36 and :55-57.

---

## InPlaceMigrator (384 LOC, Ownable + ReentrancyGuard)

**Diff in range 2146428..fa06de5: NatSpec only.** Lines 53, 156, 302: "earned phUSD" → "earned
reward". **Zero executable change.**

| Function | Access | Reads | Writes | External calls |
|---|---|---|---|---|
| `initiateMigration(token)` | onlyOwner | `staker` | — | `staker.initiateMigration` |
| `migrateOut(token,users[])` | onlyOwner, nonReentrant | — | `parked`, `migrationBegin`, `_parkedUsers`, `totalParked` | `staker.batchMigrate` |
| `migrateIn(token,start,end)` | onlyOwner, nonReentrant | `_parkedUsers`, `parked` | `parked`:=0, `migrationBegin` del, `totalParked`−, `_parkedUsers` remove | `IERC20.balanceOf` x2, `forceApprove(staker, fullBalance)`, then per user `staker.userInfo` x3, `staker.depositFor` x1-2 |
| `claimTimedOut(token)` | permissionless, self-only, nonReentrant | `parked`, `migrationBegin`, `migrationTimeout` | same clears | `IERC20.transfer` |
| `rescueERC20(token,to,amt)` | onlyOwner | `totalParked` | — | `IERC20.balanceOf`, `IERC20.transfer` |
| views | `parkedUserCount`, `parkedUsersRange`, `claimableAt`, `parked`, `totalParked`, `MIN_TIMEOUT=1 days`, `MAX_TIMEOUT=30 days` |

Properties:
- **IPM-1 (VERIFIED-BY-READING)** — `staker` and `migrationTimeout` are `immutable`; timeout bounded
  to [1 day, 30 days] at construction :131-137. Re-injection can only ever target the one staker.
- **IPM-2 (VERIFIED-BY-READING) — parked-principal floor.** `rescueERC20` :339-341 computes
  `surplus = balance − totalParked[token]` and reverts above it, so the owner can never touch parked
  principal. `totalParked` is incremented in `migrateOut` and decremented in exactly two places
  (`migrateIn` :227, `claimTimedOut` :318), both alongside zeroing `parked[user]`. Accounting
  identity `totalParked[token] == Σ parked[token][*]` holds.
- **IPM-3 (VERIFIED-BY-READING) — strict CEI.** Both `migrateIn` :224-228 and `claimTimedOut`
  :313-317 zero all state before the external call; under `nonReentrant` a re-entry sees
  `parked == 0` and skips.
- **IPM-4 (VERIFIED-BY-READING) — index-shift safety.** `migrateIn` snapshots the slice into memory
  :199-206 before removing from the `EnumerableSet`.
- **IPM-5 (VERIFIED-BY-READING) — top-up is surplus-funded only.** `_reinjectWithTopup` :271-277
  requires `topup <= balance − totalParked`, i.e. it can never spend another user's parked
  principal. Gross-up `topup = mulDiv(amt−credited, amt, credited)`; backstop
  `finalCredited >= amt − amt/1000` :293 forgives only integer-division residual (0.1%).
- **IPM-6 (ASSUMED)** — `staker.depositFor` reverts on zero credit (so `credited > 0` and the
  `mulDiv` cannot divide by zero). True of `StableStakerV2` :713 but not enforced here.
- **IPM-7 (VERIFIED-BY-READING)** — `migrateIn` approves the migrator's **entire** token balance
  :215-217, not the slice total. Documented as deliberate (section E) to cover both legs; the
  allowance is overwritten by `forceApprove` on the next call and the only spender is the immutable
  staker, so the exposure is bounded to that one trusted contract. Worth restating in the report as
  a design note, not a finding.

**Value flow:** staker → (aggregate snapshot credit) → migrator custody (`parked`) → either back
into the same staker via `depositFor` (+ surplus top-up) or out to the user via `claimTimedOut`.
Rounding occurs only inside the staker; the migrator's gross-up deliberately over-shoots and relies
on the staker's floor to land at par.

**Trust boundaries:** `staker` (immutable, trusted); `IERC20(token)` (standard, measured deltas not
used here — `parked` is credited from `batchMigrate`'s return values, which is a trust in the
staker's return array matching the actual transfer).

**Story-022 interaction (VERIFIED-BY-READING):** the NatSpec claim at :53 and :302 — "earned reward
was already minted to the user at `migrateOut`" — is still TRUE after story-022, and is in fact now
stronger: `_exitPosition` mints `pending + unclaimedReward`, i.e. the whole backlog, not just the
live pending. `claimTimedOut` correctly returns principal only. No change needed.
