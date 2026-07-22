# Tier-3 stateful invariants — story-023 settlement-capture forwarding

- **Run:** `phoenix-nft-staking-21`
- **Workspace:** `/home/justin/code/audits/workspace/phoenix-nft-staking` @ `c881a42`
- **Subjects:** `src/NFTStakerMigrator.sol`, `src/InPlaceNFTStakerMigrator.sol` (`_depositForAndForward`, `claimForwarded`, `rescueERC20`)
- **Date:** 2026-07-21
- `lib/**` untouched. No tracked upstream test modified.

## Artefacts

| Path | Role |
|---|---|
| `/home/justin/code/audits/workspace/phoenix-nft-staking/test/InvariantMigratorForwarding.t.sol` | stateful invariant harness (8 invariants + `afterInvariant` anti-vacuity tripwire) |
| `/home/justin/code/audits/workspace/phoenix-nft-staking/test/PoC_MigratorEscrowSoundness.t.sol` | 7 deterministic probes, incl. **two INV-2 counterexamples** |
| `/home/justin/code/audits/workspace/phoenix-nft-staking/medusa.json` | Medusa config (see TOOL GAP below) |

## Suite-level regression

Baseline before this work (poc-replay.md §3): 482 tests, 475 passed, 7 failed.
After: **508 tests, 501 passed, 7 failed.** The 7 failures are byte-identical to the
pre-existing set (4 × `InvariantBatchNudge` + 3 × inverted `PoC_Drift01_*`). **No regression.**

---

## 1. Campaign parameters

Foundry invariant runner, two independent campaigns (default seed and `--fuzz-seed 0xC0FFEE`):

```
FOUNDRY_INVARIANT_RUNS=256  FOUNDRY_INVARIANT_DEPTH=500  FOUNDRY_INVARIANT_FAIL_ON_REVERT=false
=> 256 runs x 500 calls = 128,000 handler calls per invariant, per campaign
```

Handler drives `InPlaceNFTStakerMigrator` against the **buggy** `NFTStakerDepletion`
(`_safePay` → `msg.sender`), i.e. the staker on which the forwarding branch is actually live.
13 actions: `advanceTime`, `stakeDirect`, `doInitiate`, `doMigrateOut`, `doFinalize`,
`doMigrateInOne`, `restakeParkedAndWait`, `setRecipientMode`, `doClaimForwarded`,
`unblockAndClaim`, `doForeignClaim`, `donate`, `ownerRescue`. Five users, one of them
**permanently unpayable** (`ModalPhUSD.permaBlocked`, the profile §5.3 shape).

### Honesty statement

**A passing campaign here is "no counterexample found in 256 sequences / 128,000 calls" —
absence of evidence, not proof of safety.** Nothing below is a proof. The two BROKEN
results are the deliverable; the HELD results record how hard the property was pushed on,
nothing more.

---

## 2. Anti-vacuity: what was actually reached

The prior run's failure mode (a mock that never failed ⇒ guarded state never written ⇒ every
assertion comparing `0 == 0`) is explicitly defended against here on three levels.

**(a) Seeded non-trivial state.** `setUp` drives two full migration cycles by hand and
`require`s, before any fuzzing, that a non-zero amount was **forwarded**, a non-zero amount was
**escrowed**, `totalUnforwarded > 0`, all five users are parked, and every parked user has
`pendingReward > 0`. If any of that stops holding the suite fails at setUp with
`SEED VACUOUS: ...`.

**(b) Branch counters count HANDLER-reached calls only.** Seed-phase value is carried into the
conservation ledger via `seedGhost`, but the *coverage* counters start at zero, so the tripwire
cannot be satisfied by `setUp`.

**(c) `afterInvariant()` tripwire, evaluated once per RUN.** It is deliberately not an
`invariant_` function: Foundry evaluates `invariant_*` once at depth 0, before any handler call,
so an `invariant_`-shaped tripwire fails trivially on that initial probe. Required each run:

```
g_migrateInCalls > 0                      // the measured leg actually executed
g_nonZeroOwed    > 0                      // reached a re-injection with real pending
g_capturedCalls  > 0                      // `captured` was non-zero
g_forwardCalls + g_escrowCalls > 0        // a payout branch was taken with a non-zero amount
```

All four held in **256/256 runs of both campaigns**. Representative per-run coverage
(`--fuzz-seed 0xC0FFEE`, printed by `invariant_zzz_coverageReport`):

| counter | value |
|---|---|
| `migrateIn` calls completed | 21 |
| `migrateIn` internal reverts | 0 |
| re-injections with non-zero `owed` | 18 |
| `captured > 0` | 18 |
| forward branch taken (non-zero) | 6 |
| **escrow branch taken (non-zero)** | **12** |
| `claimForwarded` succeeded | 6 |
| tripwire trips | 0 |
| full migration cycles completed | 4 |
| direct stakes | 91 |
| captured total | 137,203.47e18 |
| forwarded total | 37,344.53e18 |
| escrow credited total | 99,858.94e18 |
| claimed total | 64,548.05e18 |
| donated / rescued | 69,864.26e18 / 64,558.01e18 |

**No invariant in this report is vacuous.** The forward/escrow *split* within a single run is
not controllable by a uniform random walk, so the tripwire requires `forward + escrow > 0`
rather than both; **both** branches are additionally covered deterministically in
`PoC_MigratorEscrowSoundness.t.sol`.

### Two disclosed harness restrictions

Both narrow the state space and are stated so a reader can discount accordingly:

1. **`doInitiate` is gated on `parkedUserCount() == 0`.** An operator does not open a new
   migration round while the previous round's users are still parked. Without this the random
   walk repeatedly reset the parked cohort to the inert `owed == 0` shape (profile §7) and the
   forwarding branch was reached in only ~40 % of runs.
2. **`restakeParkedAndWait` is a composite** of two ordinary user actions (stake + time passing)
   applied to all currently-parked users. It is only real contract calls; it raises the
   probability of reaching the live-branch state, it does not bypass anything.

---

## 3. Results

| # | Invariant | Verdict | Runs × calls | Reverts |
|---|---|---|---|---|
| 1 | `invariant_1_conservation_noUnattributedSurplus` | HELD | 256 × 500 = 128,000 | 0 |
| 1b | `invariant_1b_conservation_perUser` | HELD | 128,000 | 0 |
| **2** | `invariant_2_escrowSoundness_balanceCoversEscrow` | **HELD in-campaign / BROKEN by construction** | 128,000 | 0 |
| 2b | `invariant_2b_escrowSoundness_recoveryPathsLive` | same as INV-2 | 128,000 | 0 |
| 3 | `invariant_3_attribution_sumEqualsTotal` | HELD | 128,000 | 0 |
| 3b | `invariant_3b_attribution_noOverClaim` | HELD | 128,000 | 0 |
| 4 | `invariant_4_tripwire_neverTripsInNormalOperation` | HELD | 128,000 | 0 |
| 5 | version-agnostic self-disable | HELD (deterministic) | 1 | 0 |

`reverts: 0` at the Foundry level is expected: the handler wraps every target call in
`try/catch` and counts internal reverts itself (`g_migrateInReverts`, 0 in both campaigns).

---

### INV-1 — Conservation. **HELD.**

> Statement: every reward token the migrator holds is either escrowed user value or an
> un-rescued third-party donation. Formally
> `balanceOf(migrator) == totalUnforwarded + Σdonations − Σrescued`, and per user
> `capturedFor[u] == forwardedTo[u] + unforwarded[u] + claimedBy[u]`.

Held over 128,000 calls including 69,864e18 of adversarial donations and 64,558e18 of owner
rescues in a single run. **No unattributed surplus was ever retained by the migrator, and no
value was created.** The per-user ledger (INV-1b) is the sharper of the two: it would catch
cross-user mis-attribution inside a batch, which the aggregate form would not.

### INV-2 — Escrow soundness. **BROKEN.** ⚠ the one that matters

> Statement: `rewardToken.balanceOf(migrator) >= totalUnforwarded` at all times.
> If it inverts, `rescueERC20` underflow-reverts at `balance - totalUnforwarded` **and**
> `claimForwarded` reverts on insufficient balance — both recovery paths brick simultaneously.

**Not broken by the fuzzer** (128,000 calls, two seeds, with a standard-ERC20-shaped reward
token and both documented forward-failure modes). **Broken deterministically by two
constructed reward tokens**, confirming profile §5.2's two flagged rows and — critically —
confirming the *consequence*, which was previously reasoned but never executed.

#### Counterexample A — `transfer` that MOVES tokens and returns `false`

`test_INV2_BROKEN_movesAndReturnsFalse_bricksBothRecoveryPaths` — **PASS (break reproduced).**

Minimized sequence:
```
1. alice stakes 10 units;                       warp 20 days
2. owner: initiateMigration -> migrateOut([alice]) -> finalizeAndReset
3. alice re-stakes 5 units;                     warp 10 days        // owed = 27,397.26e18
4. rewardToken.transfer(mig -> alice) is set to MOVE the tokens and return false
5. owner: migrateIn(0, 1)
```
Observed:
```
balanceOf(migrator)   =                              0
totalUnforwarded      = 27,397.260273972602304e18   // == owed, credited in full
```
Both consequences execute:
- `rescueERC20(rewardToken, owner, 1)` → **Panic 0x11 (arithmetic underflow)**, permanently.
- `alice.claimForwarded()` → **revert** (`ERC20InsufficientBalance`).
- A donation of `totalUnforwarded − 1` does **not** un-brick the rescue: it still underflows.

#### Counterexample B — sender-side fee-on-transfer reward token (5 %)

`test_INV2_BROKEN_senderFeeOnTransfer_underbacksLaterEscrow` — **PASS (break reproduced).**

Minimized sequence (order is load-bearing — bob escrows first, leaving a balance that alice's
successful forward then pays its fee out of):
```
1. bob and alice each stake 10 units;            warp 20 days
2. owner: initiateMigration -> migrateOut([bob, alice]) -> finalizeAndReset
3. both re-stake;                                warp 10 days
4. rewardToken: 5 % fee charged to the SENDER; bob's forward returns false (no move)
5. owner: migrateIn(0, 2)
```
Observed:
```
balanceOf(migrator)   = 11,706.102117061020984436e18
totalUnforwarded      = 12,453.300124533001047272e18
shortfall             =    747.198007471980062836e18
```
Same two consequences: `rescueERC20` underflow-reverts, `bob.claimForwarded()` reverts.

#### Honest scoping

phUSD is a standard ERC20 (revert-on-failure, no fee, no sender-side charge), so **neither
counterexample is reachable against today's reward token.** What the fuzzer *does* establish
is that no reachable sequence over the standard-token state space inverts the invariant —
128,000 calls, 12 escrow events and 6 claims in the sampled run, with donations and owner
rescues interleaved. The finding is the **brittleness of the failure mode**, now
demonstrated rather than argued: the desync is not recoverable by any actor, and the profile's
recommended one-line clamp
(`surplus = balance > totalUnforwarded ? balance - totalUnforwarded : 0`) converts a
permanent double-brick into a graceful "nothing rescuable". Weight: token-conditional, but
the *consequence* is now executed evidence rather than reasoning.

### INV-3 — Escrow attribution. **HELD.**

> `Σ unforwarded[u] == totalUnforwarded`; no user can claim another's credit; no user can
> claim twice.

Held over 128,000 calls. Actively probed, not merely observed:
- `doForeignClaim(a, b)` asserts `unforwarded[b]` is unchanged by `a`'s claim.
- `unblockAndClaim` performs an immediate second `claimForwarded()` inside the same action and
  `revert`s the whole handler call if it succeeds (`DOUBLE CLAIM: second claimForwarded
  succeeded`) — never triggered.
- `test_claimForwarded_isNotReentrant`: a callback-bearing reward token re-enters
  `claimForwarded` from the recipient's receive hook. Reentry is **attempted** (asserted via
  `reentryAttempted`) and **fails**; the credit is paid exactly once and both counters clear.

### INV-4 — Tripwire. **HELD in normal operation; blast radius CONFIRMED batch-wide.**

> `require(captured <= owed)` must never fire in normal operation, and externally-measured
> `captured` must never exceed `owed`.

`g_tripwireTrips == 0` and `g_maxOverCapture == 0` across 128,000 calls in both campaigns.
This corroborates the profile §4 / econ `refuted[1]` conclusion that `captured == owed`
bit-exactly on both in-repo stakers — the fuzzer found no reachable sequence that even reaches
`captured < owed`, let alone `captured > owed`, without a privileged mis-wiring.

Reachability of `captured > owed` and its **blast radius** are proved in
`test_INV4_tripwireBlastRadius_oneBadUserKillsTheWholeSlice` (PASS). A dispatcher hook whose
`recipient` is mispointed at the migrator and which mints on its **3rd** `pull()` (so users 1
and 2 would have migrated perfectly):

```
owner: migrateIn(0, 3)  ->  revert "Migrator: capture exceeds owed"
  parkedUserCount()          == 3      // NOT 1 — all three users lost
  balanceOf(alice)  unchanged           // innocent user 1 paid nothing
  balanceOf(bob)    unchanged           // innocent user 2 paid nothing
  totalUnforwarded()         == 0       // no partial escrow either
```
It is not transient — every retry of the same slice reverts. **Per-user slicing does not route
around it**: the offending `pull()` is positional, so `migrateIn(0,1)` succeeds twice and then
reverts on the third, forcing the operator to bisect. **Blast radius = the whole slice, one bad
user takes down every user in it.** This is the executed evidence behind econ finding ECON-007
(Low, ceiling Medium).

### INV-5 — Version-agnostic self-disable. **HELD.**

`test_INV5_selfDisablesAgainstSafePayToStaker` (PASS). Against
`NFTStakerPriceScaledMigrateReady` (which pays via `_safePayTo(user, …)`):

```
balanceOf(alice) delta   == owed        // paid exactly ONCE, by the staker
balanceOf(migrator)      == 0           // captured nothing
totalUnforwarded()       == 0           // no escrow created
```
No double payment, no revert, branch inert. Confirms profile G2.

### Bonus — profile §6 residual gap now has the regression test it asked for

`test_SEC6_batchMigrateLegLeavesNoUnmeasuredCapture_inPlace` and `…_crossStaker` (both PASS)
assert `rewardToken.balanceOf(migrator)` is **unchanged across `batchMigrate`**. Today both
in-repo stakers settle the exit leg with `_safePayTo(account, …)`, so this holds. The tests
exist so that a future staker settling the exit leg to `msg.sender` fails loudly instead of
silently turning user reward into owner-sweepable surplus above the `totalUnforwarded` floor —
which is `pns20h1` reproduced on the sibling leg. This closes the first of the four coverage
gaps the profile listed in §9.

---

## 4. Re-run of `InvariantBatchNudge.t.sol` — all 4 breaks REPRODUCE

Cold corpus (`rm -rf cache/invariant`), 256 runs × 200 depth, against real
`src/BatchNFTMinterMultiToken.sol`. Already filed — not re-derived here.

| Invariant | Verdict | Counterexample this run |
|---|---|---|
| `invariant_nudgeSolvency` | BROKEN (reproduces) | `paid=30,000,000` vs `prePot=15,000,000` (2× over-pay), `count=8`, `listLen=2`, token `0xc718…0bB1` |
| `invariant_nudgeNoSelfFund` | BROKEN (reproduces) | `excess=12,000,000` |
| `invariant_sweep` | BROKEN (reproduces) | caller **net gain = 19,000e18** (a second cold run gave 15,080.76e18 — the magnitude is seed-dependent, the break is not) |
| `invariant_fotFloor` | BROKEN (reproduces) | `delivered=95.0e18` vs declared floor `100.0e18` |

The prior run's figures (`36,000,000/18,000,000`, `18,969.39e18`) differ only in the fuzzer's
chosen magnitudes; the shrunk shape (duplicate token listing, single `batchMint`) is identical.
`invariant_fotFloor`'s known triage caveat (raise on "declared floor is nominal, not actual",
**not** as an FoT-support request) stands unchanged.

---

## 5. TOOL GAPS — record, do not read as clean

1. **Medusa: ran, but the campaign was VACUOUS. Zero weight.**
   `medusa fuzz --config medusa.json` completed 100,085 calls / 577 sequences and reported
   "22 test(s) passed, 0 failed". **That result carries no evidence and must not be cited.**
   Medusa does not drive Foundry's `targetContract` / `targetSelector` handler machinery: it
   fuzzes the *target contract's own* external functions. The LCOV report
   (`medusa-corpus/coverage/lcov.info`) confirms **not one `ForwardingHandler` function was
   ever called** — no `doMigrateInOne`, no `stakeDirect`, no `doInitiate`, no
   `unblockAndClaim`. Every one of those 100,085 calls re-evaluated the invariants against the
   frozen post-`setUp` state. Retried with `testing.testAllContracts: true`; the handler was
   still never reached. **This is exactly the vacuity failure mode this task was briefed on,
   and it is being reported as such rather than counted as a pass.** Driving the migrator
   under Medusa would need a purpose-built constructor-argument-free harness; not built this
   run.
2. **Echidna: not installed** (`which echidna` → not found). Not run.
3. The Foundry campaign is the only stateful-fuzzing evidence in this report.

## 6. Candidates for the symbolic-analyzer

INV-2 and INV-4 are the two properties where a fuzz pass is weakest and a proof would be
worth having:

- **`captured == owed` exactly** (profile §4) — currently supported by fuzzing (0/128,000
  deviations) and by source derivation, but never proved. A Halmos `[PASS]` over
  `pendingReward` vs `_updatePool` on `NFTStakerDepletion` would convert ECON-007's
  "brittle-but-not-triggerable" from argument to proof, and would tell a future staker author
  exactly what interface contract they are signing.
- **`balance >= totalUnforwarded` under a standard-ERC20 model** — the fuzzer explored 128,000
  calls without inverting it; a symbolic proof under an explicit "transfer either moves exactly
  `amount` and returns true, or moves nothing" token model would close the standard-token case
  cleanly and leave only the non-standard-token counterexamples above, which are already
  executed.
