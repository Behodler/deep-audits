# Deduplicated findings — stable-staker run-16

- **Project:** stable-staker · **Commit:** `fa06de5` · **Range:** `2146428..fa06de5` (stories 022 / 023 / 024)
- **Agent:** deduplicator · **Date:** 2026-08-31
- **Inputs consumed:** `profiles/*.md` (LOCAL-001/002/003/004, LOCAL-V01), `scan-code.md` (CODE-001..005),
  `scan-econ.md` (ECON-16-01..04 + §0/§1/§2/§3), `scan-patterns.md` (PATTERN-001/002, MR-001..003, §3 refutations, §4),
  `scan-static.md` (S-01/02/03 + §3 false positives), `spec-conformance-draft.md` (F-01..F-04).
- **Source labels in:** 24 · **Consolidated security findings out:** 10 · **Spec-conformance (Law 2) kept separate:** 4
  · **Manual review:** 3 · **Reconcile-only:** 5 · **Cleared/refuted (preserved with evidence):** 18
- **Nothing was dropped.** Every source label appears exactly once below, in a finding, in MANUAL REVIEW,
  in RECONCILE-ONLY, or in CLEARED/REFUTED. **No severity triage and no known-issue suppression was applied
  here** — that is the sanitizer's and severity-classifier's job next.

---

## 1. Consolidated security findings

### DEDUP-001 — Empty-pool emission cliff: 1 wei of stake converts a dormant zero-cost pool into a full-rate, permissionlessly-capturable phUSD dilution stream

| | |
|---|---|
| **Severity (preliminary, carried)** | **HIGH** (ECON-16-02's label; ECON-16-02 records its own honest counter-argument for Medium — carried verbatim, not resolved here) |
| **File:line** | `src/StableStakerV2.sol:817-824` (`_updatePool`), `:318-339` (`stake`), `:214-220` (`antimatterPerDay`), `:385` (`claim` mint); premise at `lib/antimatter/src/Antimatter.sol:263` |
| **Source labels absorbed** | **ECON-16-02** (primary, fullest treatment) · **PATTERN-002** (`REWARD-RUNWAY-DEPLETION`, folded in as supporting missing-control evidence, *not* filed separately) · **scan-econ §0** (the premise derivation) · **scan-econ §2** (the cap bound that shows this is not a cap violation) |
| **PoC status** | **PASSING** — `test/poc/Run16_H01_EmptyPoolEmissionCliff.t.sol`. 1 wei of USDC captures exactly `elapsed * antimatterPerSecond` (899,999.99 AM over 90 days, `assertEq`), realized through a real `annihilate` into ≈899,999.99 **unbacked** phUSD. |
| **Confidence** | high |

**Claim (strongest version preserved).** `_updatePool` computes `reward = elapsed * antimatterPerSecond`
with no reference to `totalStaked` (`:822`), and returns early emitting nothing when `totalStaked == 0`
(`:817-819`). Cost to the protocol is therefore a **step function of participation**: an empty pool costs
zero, a pool holding one wei costs the full `antimatterPerDay`, and the sole staker captures 100% of it.
Under story-023 each emitted AM is a bearer claim on ~1e18 of **unbacked** phUSD via the permissionless
`Antimatter.annihilate` (`:263`), so this is **net new dilution, not redistribution** — in a genuinely
empty pool the emission would never have existed.

**Four reachable windows, all ordinary operation, none a misconfiguration** (carried from ECON-16-02):
(a) **launch**, between `antimatterPerDay` and the first genuine staker — this is the documented wiring
order in `CLAUDE.md` verbatim; (b) **post-revival**, between `finalizeAndReset` (`:673-684`) and the
migrator's `depositFor`; (c) **retired pool** — nothing zeroes `antimatterPerSecond` on the way out;
(d) **organic emptying**. (c) and (d) are the *default* end-state.

**PATTERN-002's contribution (missing-control lens, absorbed).** The `REWARD-RUNWAY-DEPLETION` pattern's
three `notVulnerableWhen` conditions are **all three absent**: no `windowEnd` cap on `elapsed`, no
solvency invariant `balance == rewardBudget + committedDebt`, and no per-window emission budget —
`StableStakerV2` has no budget concept at all, and `Antimatter` has no supply cap. This is the same root
cause seen as a missing control; it is folded here rather than filed, per the run's overlap ruling.

**Law-3 framing (carried).** Non-obvious owner footgun: a competent non-malicious owner would be
surprised that a pool with zero users still carries a live, permissionlessly-triggerable dilution
liability, and that the required hygiene is `antimatterPerDay(token, 0)` on every pre-launch, drained
and retired pool.

**Ledger interaction — visible, not resolved here.** ECON-16-02 is the **same root cause** as two open
ledger entries whose QA rationale rested on the now-void phUSD premise: `ss9l1`
(*"finalizeAndReset revives pool without resetting emission rate"*, stated impact *"no principal is at
risk"*) and `86fcf00ef786f496…` / `ss12l3` (*"emission-dilution only"*). Both are `open`, so neither is
suppressed. **Action for the sanitizer/human: severity re-weigh with a recorded reason, preserving
fingerprints — not a re-file.** See §5.

---

### DEDUP-002 — `_exitPosition`'s inline mint is the sole principal exit during `Migrating`; an Antimatter mint failure traps 100% of the pool's principal with no hatch

| | |
|---|---|
| **Severity (preliminary, carried)** | **MEDIUM** (CODE-001 = Medium; LOCAL-002 = medium-local; F-01 = potential-medium) |
| **File:line** | `src/StableStakerV2.sol:620` (mint), block `:596-623` (`_exitPosition`); gates at `:347` (`withdraw`), `:396` (`emergencyWithdraw`), `:578` (`userMigrate`), `:675-677` (`finalizeAndReset`); `:60` (`antimatter` is `immutable`) |
| **Source labels absorbed** | **CODE-001** (primary, fullest treatment) · **LOCAL-002** (profiler original) · **scan-patterns §4** (the structural re-verification and the CLAUDE.md over-broad-claim observation) |
| **Cross-referenced, NOT absorbed** | **SPEC-F-01** — the Law-2 faithfulness half. Kept as a separate spec-conformance finding per the run ruling; see §3. |
| **PoC status** | **PASSING** — `test/poc/Run16_M01_MigrationExitMintTrap.t.sol`. Reproduces the exact revert `Antimatter.NotApprovedMinter`, selector **`0x6830132b`**; **100% of `totalStaked` trapped**; recovery by re-approval demonstrated in the same test. |
| **Confidence** | high |

**Claim (strongest version preserved).** Story-022's thesis is that principal handling no longer depends
on the reward token, and that holds for `stake` / `withdraw` / `emergencyWithdraw`. It does **not** hold
for the terminal-migration exit, which still mints inline at `:620`. `_exitPosition` is the **only** way
out of a pool in `Migrating`, because `withdraw` (`:347`) and `emergencyWithdraw` (`:396`) both require
`Active`. When `Antimatter.mint` reverts — the realistic trigger being
`Antimatter.setApprovedMinter(staker, false)` as incident response or as the natural decommissioning
order — then: `userMigrate` reverts for every affected user (no self-rescue); `batchMigrate` reverts on
the **first** such user in the loop (the migrator cannot page around it); `finalizeAndReset` requires
`stakerCount == 0 && totalStaked == 0` so the pool can never return to `Active`; and `rescueERC20`
(`:911-913`) is exactly tight during migration (`yieldStrategy == address(0)` ⇒ `reserved = totalStaked`,
`bal ≤ reserved`), so nothing is rescuable.

**Remedy enumeration (required before any permanence claim — carried in full).**
Recoverable: (1) `Antimatter.setApprovedMinter(staker, true)` restores the mint and unblocks migration —
this is the common case and is *why this is Medium, not High*. (2) `antimatterPerDay(token, 0)` does
**not** help: `owed` is already accrued and rate changes are not retroactive.
**Non-recoverable tail:** `antimatter` is `immutable` (`:60`), constructor-only (`:196`), no setter.
If the Antimatter deployment is retired, its owner key lost, or a replacement AM deployed, the trapped
pool is **permanently** unrecoverable.

**Law-3 framing.** Revoking a minter role is a routine, obviously-safe-looking operation whose
consequence (freezing an unrelated pool's *principal*) is invisible from Antimatter, invisible from
`emergencyWithdraw`, and **actively contradicted by this contract's own NatSpec** (`:387-390`, `:828-831`)
and by `CLAUDE.md:12-13`. Per the in-source-NatSpec rule, docs that self-certify exhaustively and are
wrong **raise** severity rather than suppress.

**Prior-entry disclosure (Law 1 / re-file rule) — flagged, not decided here.** Ledger entry
`e4567dc343…` (*"Terminal migration has no mint-free escape hatch if phUSD minter rights are revoked
mid-migration"*, Low, **wont-fix** 2026-06-08) is the same structural defect. Its closure rested on
**Law 3** (*"an obvious admin misstep… and recoverable"*), **not** on the redemption premise, so it is not
an expired closure on the premise axis. Three things changed in this range that the sanitizer must weigh
explicitly rather than auto-suppress: (i) a **passing PoC** now exists; (ii) the old token had
`revokeAllMintPrivileges()` and Antimatter has only per-minter revocation, which arguably makes accidental
blanket revocation *less* likely — i.e. the wont-fix rationale got **stronger**, not weaker; (iii) the
**over-broad documentation claim is new in this range** and is the genuinely new material. Do not
silently override the prior `triageReason`; name it.

**Recommended mitigation (carried).** Mirror `claim`'s shape — leave the amount booked
(`unclaimedReward[token][account] = owed`, do not zero it) and drop the inline mint; `claim` is not
`poolState`-gated and handles a zero position. Principal then leaves unconditionally. If the inline mint
must stay, wrap it in `try/catch` falling back to booking. Either way, correct `CLAUDE.md:12-13` and
`docs/deferred-reward-accrual-plan.md:37-38`.

---

### DEDUP-003 — `emergencyWithdraw` shrinks `totalStaked` without `_updatePool`, recycling forfeited emissions to survivors

| | |
|---|---|
| **Severity (preliminary, carried)** | **LOW** (CODE-002 = Low; LOCAL-001 = low-local; PATTERN-001 = potential-low) |
| **File:line** | `src/StableStakerV2.sol:405`, block `:394-411` |
| **Source labels absorbed** | **CODE-002** (primary; contains the independently re-derived cap proof) · **LOCAL-001** (profiler original) · **PATTERN-001** (`REWARD-ACCRUAL-ORDER`, STRONG signature match) |
| **PoC status** | none — and none is owed: all three agents independently concluded there is **no profitable exploit** (see below) |
| **Confidence** | high |

**Three independent agents agree on both halves of the claim**, and the agreement is the finding's
strength, not a reason to weaken it:

1. **The emission cap is NOT broken.** Re-derived from scratch by CODE-002 rather than inherited:
   let `C = Σ_i (amount_i·acc/PREC − rewardDebt_i) + Σ_i unclaimed_i`. At `:402-405` the leaver's three
   terms all go to zero and `acc` is untouched, so `C` strictly *decreases*. The next `_updatePool` adds
   `Δacc = floor(reward·PREC / totalStaked)` over the **survivors**, so the added claim is
   `totalStaked·Δacc/PREC ≤ reward = elapsed·antimatterPerSecond`. Cap holds.
   PATTERN-001 reaches the same result via profiler P1 (exactly one writer of `accAntimatterPerShare`)
   and P3 (`Σ amount_i·Δacc ≤ reward`).
2. **This is redistribution only, with no profitable exploit.** The leaver forfeits both the live pending
   *and* the `unclaimedReward` backlog (`:404`), and can only reduce **their own** contribution to
   `totalStaked`; post-exit `totalStaked ≥` the honest float, so a paired dust address captures
   `dust/(H+dust) ≈ 0`. In the degenerate sole-staker case both addresses are the attacker's and the
   total is unchanged. Every variant is a donation to honest survivors.

**Distinguished from prior art, deliberately.** PATTERN-001 records why this is *not* the same severity as
the `phoenix-nft-staking` `emergencyWithdraw` over-emission (`911c54fd`, wont-fix): there the reward was a
per-position rate with no shared denominator, so the skip produced genuine over-emission; here the
MasterChef accumulator caps it. **The story-023 premise change must NOT pull this one upward** — the
defect emits nothing extra.

**Why it is still worth reporting (carried from CODE-002).** (a) Under the run-16 premise, "forfeited
reward is recycled and minted" vs "never minted" is a genuine, bounded difference in *realized* dilution,
and the NatSpec's "forfeiting ALL reward" does not say which. (b) `pendingReward` / `claimableReward` step
discontinuously for survivors with no event — visible to any polling integrator.

**Mitigation.** Add `_updatePool(token);` as the first statement of `emergencyWithdraw`. Note this makes
the hatch depend on nothing external — `_updatePool` never touches Antimatter — so it does **not**
reintroduce DEDUP-002.

**Verified:** `totalStaked` has exactly four mutation sites (`:335`, `:355`, `:405`, `:616`); `:405` is the
only one not preceded by `_updatePool`. `:616` is safe by a different argument — it runs only while
`Migrating`, where `_updatePool` is a deliberate no-op (`:809-811`) and the index was already settled by
`initiateMigration` (`:471`).

---

### DEDUP-004 — `pendingReward` reads **zero** for a fully-owed user after any `stake` / `withdraw` / `depositFor`

| | |
|---|---|
| **Severity (preliminary, carried)** | **LOW** |
| **File:line** | `src/StableStakerV2.sol:731`, block `:722-754`; interacts with `_settle` `:832-839` |
| **Source labels absorbed** | **CODE-003** (sole source) |
| **PoC status** | none (deterministic view-function behaviour, worked example inline) |
| **Confidence** | high |

Story-022 kept `pendingReward`'s ABI and changed its meaning to the live projection only, excluding the
settled backlog. `_settle` books pending into `unclaimedReward` **and** callers immediately re-base
`rewardDebt` (`:336`, `:356`, `:716`), so after a top-up `pendingReward` returns
`101·acc/PREC − 101·acc/PREC = 0` while `claimableReward` correctly returns `P`. **A user who tops up sees
their displayed pending reward drop to zero.** No value is lost (`claim` pays `unclaimedReward + pending`),
but it is load-bearing for callers that *branch* on the value.

**Cross-repo watch item (preserved, not filed as a stable-staker finding).**
`lib/phoenix-phase-2-staging/script/interactions/ClaimWithdrawStableStaker.s.sol:57-63` does
`require(pending > 0, "no reward accrued …")`, which would abort falsely on any V2 pool where the user
staked more than once. That script currently targets V1/phUSD, so this is a **watch item for the next
`/audit-script` on phStaging** — routed to §4, not dropped.

---

### DEDUP-005 — `depositFor` has no zero-address recipient guard; the consequence is an unfixable `Migrating` brick

| | |
|---|---|
| **Severity (preliminary, carried)** | **LOW (defensive hardening)** |
| **File:line** | `src/StableStakerV2.sol:695`, block `:694-719` |
| **Source labels absorbed** | **CODE-004** (sole source) |
| **PoC status** | none — **reachability is blocked today**, see below |
| **Confidence** | medium (mechanism high, reachability blocked) |

No `require(user != address(0))`. If a migrator ever credited `address(0)`: it joins `_stakers[token]`
permanently (it can never call `userMigrate`/`withdraw`/`emergencyWithdraw` to remove itself);
`_exitPosition(token, address(0))` with `owed > 0` reverts inside OZ `ERC20._mint` with
`ERC20InvalidReceiver(address(0))`; excluding it from the batch does not help because `finalizeAndReset`
(`:675-676`) requires an empty staker set; and by DEDUP-002's `reserved = totalStaked` arithmetic the
residual principal is not rescuable — permanently, since `antimatter` is `immutable`.

**Reachability today: blocked, stated honestly.** `depositFor` is `onlyMigrator`, and both shipped
migrators skip zero-credit users — `CrossVersionMigrator.migrate:176-180` (`if (amounts[i] > 0)`) and
`InPlaceMigrator.migrateOut:170-179` (`if (amt > 0)`) — and `_exitPosition` returns 0 for an empty
position (`:599-601`). Filed as hardening because the guard is one line, the failure mode is
unfixable-by-construction, and `migrator` is an **owner-settable pointer**, so the protection currently
lives entirely outside the contract that suffers the consequence.

---

### DEDUP-006 — Retired stakers must remain approved Antimatter minters (and unpaused) forever, against a token with no mass revocation

| | |
|---|---|
| **Severity (preliminary, carried)** | **LOW** (ECON-16-04's label; its argument for Medium on incident-response availability is carried verbatim, not resolved here) |
| **File:line** | `src/StableStakerV2.sol:376-388` (`claim`, no `PoolState` gate), `:373-374` (NatSpec), `:599-601` (`_exitPosition` early return); `lib/antimatter/src/Antimatter.sol:164-168` (`setApprovedMinter`), `:186-188` (`approvedMinters()`) |
| **Source labels absorbed** | **ECON-16-04** (primary; the protocol-level consequence) · **LOCAL-004** (profiler original; the local half) |
| **Cross-referenced, NOT absorbed** | **SPEC-F-03** — the Law-2 half (story-022 Autonomous Decision 3's "nothing is stranded" argument depends on an assumption story-023 removed). Kept separate per the run ruling; see §3. |
| **PoC status** | none |
| **Confidence** | high |

Story-022 made the reward backlog outlive the position: `unclaimedReward` survives a full withdraw,
`claim` is deliberately reachable with no position, and `_exitPosition` early-returns before it could
confiscate such a backlog. So after a V1→V2 or V2→V3 hop, users who had already withdrawn to zero keep an
unminted backlog **on the old staker**, and paying it requires that decommissioned staker to remain an
approved Antimatter minter and unpaused indefinitely.

**The protocol-level consequence.** A monotonically growing minter set that can never be collapsed.
Antimatter's only revocation is per-minter; there is **no** equivalent of `FlaxToken.revokeAllMintPrivileges()`
(`FlaxToken.sol:363`, checked at `:333-344`), which bumps `mintVersion` and invalidates every minter at
once. Story-023 therefore moved V2's emissions onto a token with **strictly weaker incident response**, at
the same moment the emitted unit became redeemable against phUSD backing. Every retired staker is a
standing, individually-revocable mint surface on a token that mints unbacked phUSD on redemption.

**Argument for Medium (recorded, not applied):** a compromise requiring mass revocation must enumerate
`n` minters across `n` transactions; `approvedMinters()` makes enumeration possible but not atomic.

**Mitigation.** Add a `mintVersion`-style mass revocation to Antimatter (out of this repo's scope but in
the same owner's control); or give `StableStakerV2` an owner-callable terminal sweep that mints residual
backlogs in one batch so a retired staker's minter role can be dropped immediately.

---

### DEDUP-007 — Sliced migration re-injection hands the first slice the entire **emission** budget of the inter-slice interval

| | |
|---|---|
| **Severity (preliminary, carried)** | **LOW** |
| **File:line** | `src/InPlaceMigrator.sol` `migrateIn`, `src/CrossVersionMigrator.sol` `migrate`, against `src/StableStakerV2.sol:700-719` (`depositFor`) and `:822` (time-denominated accrual) |
| **Source labels absorbed** | **ECON-16-03** (sole source) |
| **PoC status** | none (worked 3-page arithmetic inline) |
| **Confidence** | high |

Both migrators re-inject in pages, each page a separate transaction. Because destination emission is
time-denominated and TVL-independent (`:822`), page-1 users draw the **full** `antimatterPerDay` for the
entire interval before page 2 lands, despite every parked user's principal having been equally immobilised
throughout. Worked case: 3 pages × ~1M USDC, one per day, `antimatterPerDay = 10_000e18` → page-1 users
capture ≈18,333 AM against a fair ≈10,000 AM, an **83% over-share** (≈8,333 AM ≈ 8,333 phUSD) transferred
from page-3 users to page-1 users.

**Not incremental dilution** — total AM emitted over the interval is unchanged, so unlike DEDUP-001 this
is pure redistribution among legitimate users. Page order is owner-chosen, so it is not user-exploitable;
it is an unfair allocation the owner imposes without meaning to, and a user who knows the page order can
lobby for or trade on inclusion in page 1.

**Mitigation.** `antimatterPerDay(token, 0)` for the duration of the re-injection, restored once the last
page lands; or complete `migrateIn` in a single transaction. Belongs in the `CLAUDE.md` migration runbook,
which currently documents page-wise re-injection without the caveat.

---

### DEDUP-008 — `_reinjectWithTopup`'s per-user reverts sit inside the `migrateIn` batch loop, and the shared **top-up surplus** is consumed in slice order

| | |
|---|---|
| **Severity (preliminary, carried)** | **LOW** (S-01/02/03 are explicitly "nothing rises to High or Medium from deterministic SAST"; S-02 is an availability observation) |
| **File:line** | `src/InPlaceMigrator.sol:281-284` (surplus-exhausted `require`), `:294` (`par not restored` `require`), both inside the `migrateIn` slice loop; call sites `:231`, `:263` |
| **Source labels absorbed** | **S-02** (sole source) |
| **PoC status** | none |
| **Confidence** | medium |

One user whose gross-up exceeds the remaining surplus reverts the **entire batch**, and the surplus is
consumed in slice order — earlier users drain the budget later ones need. Self-limiting:
`migrateIn(token, start, end)` is paginated so the owner can re-slice around a blocker, and any user can
self-rescue via the permissionless `claimTimedOut` hatch once `migrationTimeout` elapses. Consequence is
a **stuck owner batch, not stuck user funds**.

**KEPT SEPARATE from DEDUP-007 — justification (the run asked for an explicit decision).**
These are **two distinct defects** that merely share the surface trait "slice ordering matters":

| | DEDUP-007 (ECON-16-03) | DEDUP-008 (S-02) |
|---|---|---|
| **Contended resource** | the destination pool's **AM emission stream** (time-denominated, unbounded, minted on demand) | the migrator's **finite stablecoin top-up surplus** held as `balanceOf(this) - totalParked[token]` |
| **Root cause** | emission is TVL-independent (`StableStakerV2.sol:822`) so wall-clock between pages allocates reward | a shared finite budget is drawn first-come inside a loop with a per-user `require` |
| **Locus** | `StableStakerV2._updatePool` (destination) | `InPlaceMigrator._reinjectWithTopup` (migrator) |
| **Consequence** | value **redistributed between users**; batch completes normally | batch **reverts**; no value moves; later users under-restored if the owner re-slices badly |
| **Present without the other?** | Yes — occurs with zero top-up surplus in play | Yes — occurs with `antimatterPerDay == 0` |
| **Mitigation** | zero the emission rate across the re-injection, or single-tx `migrateIn` | pro-rata the surplus across the slice, or size the surplus before slicing |

Separate root causes, separate mitigations, and neither subsumes the other ⇒ **two findings**, per the
"keep both when same pattern but different root causes / separate mitigation required" rule.

---

### DEDUP-009 — Two same-named `FlaxToken` build artifacts, with no CI pin on the vendored copy

| | |
|---|---|
| **Severity (preliminary, carried)** | **QA** |
| **File:line** | `remappings.txt:3` and `:7`; `src/versions/v1/vendor/FlaxToken.sol` + `IFlax.sol` (new); `.github/scripts/check-migration-surface.sh` |
| **Source labels absorbed** | **CODE-005** (primary) · **LOCAL-V01** (profiler original) |
| **Cross-referenced, NOT absorbed** | **SPEC-F-04** — the Law-2 half (absence of a hash pin, the story's factually-false CI premise, and the `PreToolUse` hook that does not guard `src/versions/v1/`). Kept separate per the run ruling; see §3. |
| **PoC status** | n/a (build hazard) |
| **Confidence** | high |

`flax-token/` → `src/versions/v1/vendor/`, `@phUSD/` → `lib/antimatter/lib/flax-token-v2/src/`. Both are
commit `f5300117` today (profiler verified byte-identical), so `forge build` emits two same-named
`FlaxToken` artifacts from different paths. Two consequences: (i) artifact-by-name resolution
(`vm.getCode("FlaxToken.sol")`, `deployCode("FlaxToken")`) becomes ambiguous — **grep confirms no such
call site exists in the first-party tree today**, so nothing breaks now, but any future script or
downstream consumer inherits it; (ii) a future `lib/antimatter` submodule bump silently drifts the two
copies apart with **no check**, because `check-migration-surface.sh` asserts `FROZEN.sha256` holds exactly
two entries and deliberately does not pin the vendored pair.

**Note the deliberate scoping split.** `spec-conformance-draft.md` adjudicates the *duplicate artifact
itself* as **within story-024's declared intent** (the story scopes the transitive tree out twice with
human sign-off) and therefore not a Law-2 deviation — it routes the residual build-hygiene item here, to
qa-bundler. The **absence of any hash pin** is the reportable spec half and stays as SPEC-F-04. Both
halves are preserved; neither is dropped.

**Mitigation.** CI assertion that `src/versions/v1/vendor/{FlaxToken,IFlax}.sol` hash-match the `@phUSD/`
copies (or pin their hashes outright), so a submodule bump fails loudly.

---

### DEDUP-010 — `setYieldStrategy` and `finalizeAndReset` are the only state-mutating entry points without `nonReentrant`

| | |
|---|---|
| **Severity (preliminary, carried)** | **QA / hardening** ("real as an observation, not exploitable as written") |
| **File:line** | `src/StableStakerV2.sol:249` (+ `:279`, `:286`, `:296`), `:673`; mirrored at `src/versions/v1/StableStakerV1.sol:257`, `:287`, `:304` |
| **Source labels absorbed** | **S-01** (primary) · **MR-003** (pattern-matcher's `REENTRANCY-CROSS-FUNCTION` route — same three functions, same conclusion) |
| **PoC status** | none — not exploitable as written |
| **Confidence** | high |

Every other mutator carries `nonReentrant`. `setYieldStrategy` makes two external calls into the **old**
strategy and one into the **new** one before/around writing `yieldStrategy[token]`. **Not exploitable:**
the `require(poolInfo[token].totalStaked == 0, "StableStaker: pool not empty")` gate at `:258` makes the
`staked > 0` branch at `:279` unreachable, so the only live external call is the idle sweep and the
strategy is owner-wired (Law 3: trusted, obvious). `finalizeAndReset` makes no external call at all.
OZ's guard is contract-wide, so reentry from `initiateMigration`'s `strategy.withdraw` (`:486`) into
`stake`/`withdraw`/`claim` is blocked; only the three owner-gated functions are reachable, making any
exploit owner-driven and obvious.

**Reconcile, do not re-derive.** MR-003 notes the ledger already carries an open `info` entry
*"initiateMigration writes state after the external strategy.withdraw call"* that should be reconciled
against this reasoning next run.

---

## 2. MANUAL REVIEW (Law 1 visible parked channel — routed with reason, NOT dropped)

Mirrored to `/home/justin/code/audits/reports/stable-staker/16/manual-review.json`.

### MR-16-01 — `CrossVersionMigrator.migrate` has no shortfall top-up, unlike `InPlaceMigrator._reinjectWithTopup`

- **Source label:** **S-03** · **routed, not filed as new, and not dropped**
- **File:line:** `src/CrossVersionMigrator.sol:173-181` (`depositFor` at `:178`); contrast
  `src/InPlaceMigrator.sol` `_reinjectWithTopup` `:263-294`
- **Reason for routing:** **pre-existing code, not a run-16 change.** Both migrators have **NatSpec-only
  diffs** across `2146428..fa06de5` and **zero executable change** (confirmed independently by
  `scan-code.md`, `scan-patterns.md §5`, and `Migrators.profile.md`). Filing it as new would mis-attribute
  it to this range.
- **The lead, preserved in full:** `InPlaceMigrator._reinjectWithTopup` deliberately snapshots `userInfo`
  around `depositFor` and grosses up the shortfall — that helper **exists precisely to close this gap**
  (it is the ss12m1 / M-07 fix). `CrossVersionMigrator.migrate` calls the same `depositFor` with **no
  snapshot and no gross-up**, so if the destination staker haircuts the credit the user is **silently
  underpaid**. It also lacks `nonReentrant`.
- **Why it is not resolvable statically:** whether the destination `depositFor` can credit less than it
  pulls depends on the destination's yield-strategy wiring, which SAST cannot settle. Needs a
  fork/harness answer against a real destination strategy.
- **Confidence:** medium. **Preliminary severity if confirmed:** Medium (it is the same class as ss12m1/M-07).
- **Recommended next step:** targeted `/recheck`-style verification, or a Tier-3 harness that wires a
  haircutting strategy on the destination and measures `userInfo.amount` after `migrate`. Do **not**
  close this by assuming the haircut cannot happen — memory note *mock-no-op-stub-fakes-permanence* applies.

### MR-16-02 — Pause does not freeze reward minting on the migration path

- **Source label:** **MR-001** (`MINT-ON-DEMAND-OVERMINT`, match **SUPERFICIAL**, confidence **low**)
- **File:line:** `src/StableStakerV2.sol:376` (`claim` is `whenNotPaused`) vs `:619-621`
  (`_exitPosition` mint, reached by `batchMigrate`/`userMigrate`, neither `whenNotPaused`)
- **Reason for routing:** low confidence and **no over-mint occurs** — `owed` is the frozen already-accrued
  figure and `_updatePool` no-ops while `Migrating` (`:809-811`). It is a *completeness gap in the pause*,
  not a value bug. Kept visible because the story-023 premise change makes "reward minting continues
  during an incident pause" a materially different statement than it was when the reward token was inert.
- **Confidence:** low. **Preliminary severity:** QA / informational unless the premise change escalates it.

### MR-16-03 — Cross-repo watch: phStaging `ClaimWithdrawStableStaker.s.sol` breaks against a V2 staker

- **Source label:** carried out of **CODE-003** (see DEDUP-004) and CODE-005's watch-items section
- **File:line:** `lib/phoenix-phase-2-staging/script/interactions/ClaimWithdrawStableStaker.s.sol:57-63`
- **Reason for routing:** **not a stable-staker defect** — it is a defect in a *sibling repo's* script, so
  it cannot be filed against this project, but it must not vanish. The script hard-requires
  `pendingReward > 0` (falsely zero under DEDUP-004) **and** asserts on a phUSD balance delta after `claim`
  (V2 pays AM). Both break against a V2 staker. It currently targets V1/phUSD, so it is latent.
- **Action:** carry into the **next `/audit-script` on phoenix-phase-2-staging**.

---

## 3. SPEC CONFORMANCE (Law 2) — kept separate from the security findings, by design

These are **not** duplicates of the security findings above and must not be collapsed into them. A Law-2
deviation is a distinct defect class with a distinct remedy (correct the story/docs, or implement the
missing requirement) and is reported through `spec-conformance.md`, not through the H/M submissions.

| Label | Claim | Severity (carried) | File:line | Absorbed | Security twin (cross-ref only) |
|---|---|---|---|---|---|
| **SPEC-F-01** | story-022's headline robustness criterion (*"the principal paths never call phUSD at all"*, and the explicit test *"with the minter role revoked, `stake`, `withdraw` and `emergencyWithdraw` all still succeed"*) is **not met on the migration exit**, and `CLAUDE.md:12-13` + `docs/deferred-reward-accrual-plan.md:37-38` state it **unconditionally, with no migration carve-out**. The story's own requirements (a) and (b) are mutually inconsistent; the implementation executed (b) and silently dropped (a). No test in the story or suite exercises "migration exit with the minter revoked". | potential-medium | `src/StableStakerV2.sol:620` (range `598-621`) | F-01 | **DEDUP-002** |
| **SPEC-F-02** | story-023 swaps the emissions token to one with a **permissionless redemption path** and is **silent** on the consequence (`grep` for dilut/unbacked/backing/redeem over the whole story returns two hits, neither the point); it additionally **laundered story-022's token-specific risk conclusion into a token-agnostic one** — `git diff 045d13c 2d609cb` shows the *subject* substituted (`phUSD peg` → `reward-token`) while the *conclusion* (`not a solvency one`) was preserved untouched, though that conclusion followed **from** phUSD's properties. Aggravated by the story asserting the area is clear while refuting a vector nobody raised (lines 207-209) and by framing the residual as cosmetic dust (lines 341-345). Law-3 footgun rider: an `antimatterPerDay` rate calibrated under the phUSD premise is now a phUSD **dilution** rate. | potential-medium | story-023; `src/StableStakerV2.sol:214-218`, premise `lib/antimatter/src/Antimatter.sol:226-267` | **F-02** + **ECON-16-01** (absorbed — same claim; ECON-16-01 contributes the additional doc site: `CLAUDE.md`'s *"Core safety invariant"* section still frames the emission cap as a pure accounting bound without stating it is now a **dilution budget denominated in phUSD backing**) | **DEDUP-001** |
| **SPEC-F-03** | story-022 Autonomous Decision 3's *"nothing is stranded"* argument has an **unstated third precondition** — the old staker must remain an approved Antimatter minter and unpaused **indefinitely**. Story-023 changed the revocation model (no `mintVersion` mass revocation) and never revisited Decision 3. De-approving a decommissioned staker is the obvious, correct-looking hygiene step and permanently strands every residual backlog, with no on-chain guard and no runbook entry. Non-obvious consequence of an ordinary owner action ⇒ footgun, in scope. | potential-low | `src/StableStakerV2.sol:598-601`, `:375` | F-03 | **DEDUP-006** |
| **SPEC-F-04** | The vendored pair is the **compile-time definition of the frozen V1's imports** and is protected by **no gate**; the story declined to pin it on a premise that is **factually wrong**. Story-024 called the CI constraint *"not a trade-off to weigh"*, but `manifest_count != ${#FROZEN_FILES[@]}` compares against a **hard-coded array two lines above** (`check-migration-surface.sh:88`, `:103-105`) — adding both paths keeps CI green in a two-line edit to a script this repo owns. **Compounding:** the story's stated second line of defence does not exist — `.claude/hooks/protect-migration-surface.sh` guards only `PROTECTED=(initiateMigration batchMigrate depositFor)` (`:38`, used `:155`/`:177`/`:236`); `grep -n "src/versions"` returns only two prose comments. So the frozen pair has **one** gate, and the vendored pair has **zero**. | potential-low | `src/versions/v1/vendor/IFlax.sol`, `.../FlaxToken.sol`; `.github/scripts/check-migration-surface.sh:88,103-105`; `.claude/hooks/protect-migration-surface.sh:38` | F-04 | **DEDUP-009** |

**Also carried from `spec-conformance-draft.md`, verbatim, because it conditions every acceptance
criterion above:** all three stories resolve to `auto-complete/` — **machine approval, not human review**.
Stories 023 and 024 were auto-completed on a review status of **`ISSUES_FOUND`**, triaged non-blocking by
the same automated workflow; only story-022 closed on `PASSED`; every review ran `--inline-delegation`
with self-declared *"Independence: reduced"*. The acceptance criteria are authoritative **text**, but
their sign-off carries **no independent-human weight**.

**Spec-conformance observations carried with no finding** (preserved, not dropped): story-023's public
ABI break (`phUSD()` → `antimatter()` etc., breaks `reflax-mint`/`phase-2-staging` on its next pin bump —
relevant to `/audit-script`, not a defect here); `MigratedOut.reward` semantics change to
`pending + unclaimed`; story-023 commit `2d609cb` spelling the literal sentinel `GOLDEN-RULE-OVERRIDE` in
its body, which `protect-migration-surface.sh` substring-matches (gate green, but it makes future
commit-message auditing unreliable); story-024's stale 58 MB git-module dir despite a ticked box.

---

## 4. RECONCILE-ONLY — already in the ledger, deliberately not re-filed

Listed so the sanitizer reconciles rather than re-mints, and so nothing looks dropped.

| Item | Source labels | Ledger entry | Note |
|---|---|---|---|
| `amountPerDay / 86400` floors `antimatterPerSecond` to zero | **MR-002** (`EMISSION-WINDOW-BOUNDARY` + `DIVISION-PRECISION`), scan-econ §1.5 | `d47619d29f…` (open Low) | Arithmetic identical after the phUSD→AM rename. **The ledger title is stale** (says phUSD) and should be corrected rather than the entry re-minted. AM is 18-dec, so an 86400-wei/day budget is economically absurd; stays Low. |
| Requested-vs-received withdrawal skew (`withdraw:355` decrements requested, `:366-367` pays measured) | scan-patterns §3 (`YIELD-PRINCIPAL-ACCOUNTING-SKEW`) | `69c7666e` (wont-fix, owner-confirmed intended) + `0dca43f3` (acknowledged) | **No executable change in this range.** Do not re-file. |
| Unbounded per-user external-call loop in `batchMigrate` + `CrossVersionMigrator` | scan-patterns §3 (`DOS-UNBOUNDED-LOOP`) | open Low | All sites `onlyOwner`/`onlyMigrator`; `getStakersRange:774` is the paginated read path. Reconcile-only. |
| Dust-stake grief of `setYieldStrategy`'s empty-pool gate (`:258`) | scan-econ §1.5 | `787e9faceb…` / `ss10l1` (L-01, submitted-qa) | Severity basis **unchanged** by story-023 — availability nuisance with no dilution leg; recovery via re-run migration intact. |
| `InPlaceMigrator:227` approves `balanceOf(this)` while its NatSpec `:191-192` claims *"the EXACT slice total"* | scan-patterns §5 | `ss13l4` (open QA) | Real contradiction, but untouched by this range (NatSpec-only diff). |

---

## 5. PREMISE RECONCILIATION — expired suppressions, surfaced not resolved

**This is the load-bearing carryover of the run and must reach the human.** Story-023 voided the premise
*"the reward token has no user redemption path, so over-crediting is opportunity cost, not loss"* **for V2
only**. The frozen V1 still emits phUSD directly and is unaffected.

The pattern-matcher searched all 53 ledger entries and reports the honest result: **no stable-staker
ledger entry states that rationale in its `triageReason`.** The premise lived at the **scanner** level, as
standing memory notes that suppressed the class *before a finding was ever minted* — which is worse than a
stale ledger entry, because there is no artifact to re-open.

| Item | Status | Void rationale | Action (for sanitizer / human — **not applied here**) |
|---|---|---|---|
| `ss9l1` — finalizeAndReset revives pool without resetting the emission rate | **open** (not suppressed) | *"the emission CAP is NOT violated and **no principal is at risk**"* | **VOID as a Low.** Same root cause as **DEDUP-001** (windows b/c). Re-weigh upward or merge; its recommendation (*"zero the rate on revival"*) is DEDUP-001's primary mitigation. **Preserve the fingerprint; name the void premise explicitly.** |
| `86fcf00ef786f496…` / `ss12l3` — revived-pool permissionless-stake window before `migrateIn` | **open** (qa) | *"Sole residual: **emission-share dilution … not a leak**"* | **VOID.** Under Antimatter that inference is inverted — emission dilution **is** the leak, realised at `Antimatter.sol:263`. Its refutation of the *theft* angle remains correct; only the "so the residual is harmless" step fails. Describes DEDUP-001 window (b) precisely. |
| Memory `minter-cushion-socialized-losses-intended` | — | *"minters can't redeem so there's no user-vs-user vector"* | **VOID for V2's reward leg** (AM holders redeem permissionlessly). Still valid for the phUSD minter role generally and for frozen V1. |
| Memory `externally-derived-yield-opportunity-cost-not-loss` | — | *"over-payment is misallocation/marketing spend, never economic loss"* | **VOID for V2's reward leg** — AM emissions are freshly-minted claims on phUSD backing, not external yield. Still valid for the Phoenix pots it was written about. |
| Memory `phstaging-ys12-minter-immune` | — | same premise, about the phUSD minter | **Unaffected as written**, but flagged so the reasoning pattern is not transplanted to AM by analogy. |
| Class-level: *any* future `REWARD-ACCRUAL-ORDER` / `MINT-ON-DEMAND-OVERMINT` / `ROUNDING-DIRECTION` hit on the V2 reward leg | — | — | Must be **severity-derived fresh**, never auto-downgraded to opportunity cost. |

If the human prefers to keep `ss9l1` and `86fcf00e` at QA and carry DEDUP-001 as the single High, that is
coherent — **but the two entries' stated rationales must then be corrected**, because as written they
instruct a future reader that emission dilution is harmless.

---

## 6. CLEARED / REFUTED — checked, disproved, and preserved with evidence

Per Law 1 these survive into the report as explicit *"checked and cleared"* items so a future run does not
re-derive them, and so a future scan does not re-raise them as new.

### 6.1 The four named refutations

1. **No double-mint across `claim` and `_exitPosition` — structurally impossible.**
   Exactly two `.mint(` sites: `:385` (`claim`) and `:620` (`_exitPosition`). `claim` zeroes the backlog
   **and** re-bases the debt in the same transaction (`:383-384`), so a subsequent `_exitPosition` computes
   `pending == 0` and `unclaimedReward == 0` ⇒ `owed == 0` ⇒ no mint. Checked **specifically for the
   Migrating window**, where `claim` is *not* `poolState`-gated (profiler P12): `_updatePool` no-ops while
   Migrating so `acc` is frozen, and the `:384` re-base is exact against that frozen `acc`. Independently
   confirmed by `scan-code.md` and `scan-patterns.md §3`. **Also cleared:** a duplicate address inside one
   `batchMigrate` batch — the second `_exitPosition` hits the `amt == 0` early return (`:599-601`) and
   contributes 0.
2. **No decimal fail-open (6dp stablecoin vs 18dp AM) — does not reproduce the sibling
   `stable-yield-accumulator` M-01.** Three independent reasons: **(a)** `grep -n "decimals"
   src/StableStakerV2.sol` returns **nothing** — the staked-token decimals **cancel** in the pro-rata
   (`acc += reward·1e18/totalStaked` then `pending = amount·acc/1e18`), so the payout is in AM units
   regardless and there is no conversion to fail open. Worked example: `totalStaked = 1e12` (1M USDC),
   100 AM/day, one day → holder of all 1e12 gets 99.99e18 AM. **(b)** Precision is comfortable and 6dp is
   the *favourable* direction (smaller divisor ⇒ larger `acc` increment); worst case 100M USDC at
   10,000 AM/day, 1-second window → `acc += 1.157e21`, no truncation to zero; overflow headroom ~1.15e77
   vs a realistic ~3.6e42. **(c)** The one decimal conversion in the chain fails **CLOSED**:
   `Antimatter.toStableAmount:283-304` reverts on four axes (`UnsupportedDecimals`, `DecimalsUnavailable`,
   `DecimalsMismatch`, `AmountNotRepresentable`). Residual: sub-1e12 AM dust is unannihilatable —
   immaterial, in an out-of-scope contract, noted for completeness.
3. **Zero rounding residual — every leg floors toward the protocol.** `perSecond` `:216`, `acc +=` `:824`,
   `pending` `:353`/`:380`/`:609`, `rewardDebt` `:336`/`:356`/`:384`/`:716`, migration
   `credit = (amt*S)/P` `:605` — all floor. The **reward-debt baseline uses the identical formula to the
   pending computation**, so the two truncations **cancel rather than compound**. Round-trip tested
   (stake → withdraw 1 wei → re-stake): `pending` is computed against the *same* floored `rewardDebt` the
   previous leg wrote, so the residual is **zero**, not accumulating, and the aggregate is bounded by
   `Σ amount_i·Δacc ≤ reward` regardless. No site rounds up; no leg rounds the user's receipt up or their
   obligation down. **No attacker-repeatable extraction.** This refutation is explicitly worth keeping
   because the premise change would have made a 1-wei AM loop a real drain.
4. **Flash-stake / same-block stake-then-claim earns exactly zero.** `stake:320` calls `_updatePool`,
   which returns immediately on `block.timestamp <= pool.lastRewardTime` (`:814-816`), so `acc` is
   unchanged; `stake` then sets `rewardDebt = user.amount·acc/ACC_PRECISION` (`:336`) at that same `acc`.
   A same-block `claim` computes `pending = 0` (`:380`) and **reverts** on
   `require(owed > 0, "StableStaker: nothing to claim")` (`:382`). Relatedly: staking just before a large
   accrual window closes gains nothing retroactively — ordering is `_updatePool` → `_settle` →
   `user.amount += credited` (`:320`/`:322`/`:334`, and `:706`/`:708`/`:714` in `depositFor`), so the
   elapsed window is folded into `acc` **before** the new principal joins `totalStaked`.

### 6.2 Further cleared items (preserved)

5. **Emission cap holds; no out-of-band mint path exists.** Bound:
   `Σ_users unclaimedReward + Σ minted ≤ Σ elapsed × antimatterPerSecond`. Verified by: exactly **one**
   writer of the index (`:824`, `grep -c == 1`, `+=` only, never reset by `finalizeAndReset`); exactly
   **two** mint sites, both paying `unclaimedReward + pending` and zeroing in the same transaction;
   accrual **frozen while Migrating** (`:810-812`, with `_pendingReward:748` applying the identical guard
   so views and state agree); and the migration gap never retro-accrued (`finalizeAndReset:680` sets
   `lastRewardTime = block.timestamp`). Paths individually checked and negative: `emergencyWithdraw`,
   `depositFor`, re-staking after a full exit, `batchMigrate`/`userMigrate`, and the full migration
   round-trip. **DEDUP-001 is not a cap violation** — it is a statement about the cap's *cost basis*.
6. **Full reentrancy-class walk — every row cleared, with the reason.** Classic single-fn (all value
   entry points `nonReentrant` + strict CEI); cross-contract A→B→A (only external callees are
   `IERC20(token)`, `IYieldStrategy`, `antimatter.mint`, and every re-entrable A-side function shares the
   lock); cross-function (OZ guard is **contract-wide**; the unguarded set is `onlyOwner`/`onlyPauser`);
   **read-only reentrancy** (no view is a price/exchange-rate oracle — `totalStaked` is a raw principal
   counter, not a NAV; the two transient windows are named and neither is consumable); ERC721/ERC1155
   (**N/A**, no NFT surface); ERC777 (all hook-firing sites sit inside `nonReentrant` functions and the
   outbound ones are last-statement CEI).
7. **V1→V2 migration boundary — no double-count, no user-timeable arbitrage.** Reward legs are disjoint
   in time; denominations differ by design and `CrossVersionMigrator` never imports either token; users
   have **no timing control** (`initiateMigration`/`migrate`/`batchMigrate`/`depositFor` are all
   `onlyOwner`/`onlyMigrator`); a user staked on both stakers is not double-credited. The one real
   boundary effect is the page-ordering unfairness, filed as **DEDUP-007**.
8. **`ERC4626-INFLATION` / `FIRST-DEPOSITOR-ATTACK` — correctly no-match.** This is a MasterChef
   `accAntimatterPerShare`/`rewardDebt` accumulator, **not** a share-price vault; there is no
   `totalAssets()`-derived exchange rate to inflate.
9. **`FEE-ON-TRANSFER-ACCOUNTING` — not vulnerable.** `_pullToken:840-846` credits
   `balanceAfter - balanceBefore`, and `stake:334-335` / `depositFor:714-715` use the strategy's returned
   `credited` in place of the requested amount. The pattern's `notVulnerableWhen` clause is satisfied exactly.
10. **`FRONTRUN-APPROVE` — skipped per DB note, but signature-checked anyway.** The codebase uses
    `SafeERC20.forceApprove` **exclusively** (`StableStakerV2:283/290/521`, `CrossVersionMigrator:173`,
    `InPlaceMigrator:227`) and never raw `approve`. No plausible H/M twist found.
11. **Index-vs-settle ordering, exhaustively.** All five settle-equivalent sites (`:329`, `:353`+`:362`,
    `:380`, `:609`, `:708`) are immediately preceded by a `_updatePool` that is either effective or a
    deliberate frozen no-op. No path settles against a stale index, and no path other than **DEDUP-003**
    moves supply against a stale index.
12. **Access control on the new emissions path.** `antimatterPerDay` is `onlyOwner` + `poolExists` and
    settles at the old rate first (`:215`) ⇒ **no retroactive re-pricing** in either direction.
    `antimatter` is `immutable` with no setter ⇒ no rewardDebt-invalidating repoint — a safety property
    here, and simultaneously the reason DEDUP-002's tail case is unrecoverable.
13. **State machine.** Only two transitions exist. `emergencyWithdraw:396` and `userMigrate:576` both omit
    `poolExists`, but neither is exploitable on an unregistered token: `PoolState.Active` is the zero
    value, and the follow-on `user.amount > 0` checks cannot pass because `user.amount` is written only by
    `stake`/`depositFor`, both `poolExists`-gated.
14. **Post-`finalizeAndReset` revival.** `accAntimatterPerShare` is deliberately **not** reset. A user with
    a surviving `unclaimedReward` and `amount == 0` who re-stakes gets `rewardDebt` at the current `acc`
    ⇒ no windfall, no underflow. Profiler P6 re-verified against all three zeroing sites (`:356`, `:402`, `:614`).
15. **Story-022 makes the *destination* side of a migration safe.** If the new staker is not yet an
    approved AM minter when `depositFor` seeds it, nothing reverts — the backlog accumulates in
    `unclaimedReward` and `claim` works once the role is granted. This is exactly the property
    **DEDUP-002** shows is missing on the *source* side.
16. **LOCAL-003 (informational, preserved).** `antimatterPerDay` during `Migrating` does not settle
    (`:215` calls `_updatePool`, which no-ops). Harmless because accrual is frozen and
    `finalizeAndReset:681` fast-forwards `lastRewardTime`. **Recorded so that a future edit removing the
    fast-forward is recognised as a regression.**
17. **`vm.getCode` / `deployCode` ambiguity is latent, not live.**
    `grep -rn 'getCode("\|deployCode("' --include=*.sol` over the first-party tree returns **only**
    `lib/forge-std` self-tests. Supports DEDUP-009's "nothing breaks now".
18. **The 18 static-analyser false-positive classes in `scan-static.md §3` are preserved as-is and must
    not be re-raised** — `reentrancy-no-eth`/`reentrancy-benign`/`reentrancy-events` (Slither does not
    model OZ `ReentrancyGuard`), Aderyn's only High class (same rows), `unused-return` on
    `EnumerableSet.add/remove` ×12 and on `_routeExit`/`strategy.deposit`/tuple-destructuring,
    `uninitialized-local` ×8 (loop accumulators, zero is the intended start), `timestamp` ×12 (9 are not
    timestamp comparisons at all; the 3 genuine ones are second-granularity MasterChef accrual and a
    multi-hour timeout), `low-level-calls` ×3 (`staticcall` probes where a revert is a *meaningful*
    answer and each site checks `ok`), `missing-inheritance`, `unimplemented-functions` on an interface,
    `missing-zero-check` ×4, and **EIP-170 / contract oversize** (settled policy: this repo builds
    unoptimized and oversize on purpose; the deploy profile uses optimizer + via_ir).
    **Semgrep's silence is evidence of nothing** — all 153 combined hits are performance/best-practice
    rules and `p/smart-contracts` contains **no** Solidity security rules; it is not cited anywhere.

### 6.3 Coverage assertions preserved (so a green run cannot be mistaken for a clean one)

- **7/7 in-scope files analysed by all four tools.** Slither anchored its filter to `stable-staker/lib/`,
  **not** bare `lib/` (which would have filtered every first-party file and produced a false clean).
  Aderyn ingested all 10 `src/` files. **Semgrep's built-in default ignore list silently dropped both
  `src/versions/v1/vendor/*.sol` files** — `--no-git-ignore` does not lift it; worked around by copying to
  a scratch dir with an empty `.semgrepignore`, giving 7/7. 4naly3er was invoked with `basePath` = the
  submodule root and a 7-entry scope list (no symlink).
- **Both migrators are reconcile-only this run: NatSpec-only diff, zero executable change** in
  `2146428..fa06de5`, confirmed independently three times.
- `src/versions/v1/**` is **additive only** (the vendored pair); the frozen V1 `.sol` files are untouched,
  and `FROZEN.sha256` retains exactly its two original lines.
- **`lib/antimatter` is not in this run's scope.** Every economic conclusion depends on
  `Antimatter.annihilate:226-267` and specifically the unbacked mint at `:263`. **A future run must
  re-confirm `:263` before relying on this scan.**
- `IYieldStrategy` behaviour is imported from `reflax-yield-vault` and is **unverified from this repo**
  (profiler P11). DEDUP-001's 1-wei entry assumes an idle-hold pool or a strategy that credits 1 wei; a
  strategy rounding a 1-wei deposit to zero credit would trip `require(credited > 0)` (`:333`) and raise
  the attack's entry cost — **only to the strategy's minimum credit**, still negligible against a
  multi-day emission stream. It changes the size of the dust, not the finding.
- **No "malicious owner" vectors were filed anywhere** (Law 3). Every owner-facing item above is filed as
  a **non-obvious footgun** with the surprise test applied explicitly.

---

## 7. Label map (traceability — every source label accounted for)

| Source label | Disposition |
|---|---|
| LOCAL-001 | → DEDUP-003 (merged) |
| LOCAL-002 | → DEDUP-002 (merged) |
| LOCAL-003 | → §6.2 item 16 (informational, preserved) |
| LOCAL-004 | → DEDUP-006 (merged) |
| LOCAL-V01 | → DEDUP-009 (merged) |
| CODE-001 | → DEDUP-002 (primary) |
| CODE-002 | → DEDUP-003 (primary) |
| CODE-003 | → DEDUP-004 (sole) + MR-16-03 (cross-repo half) |
| CODE-004 | → DEDUP-005 (sole) |
| CODE-005 | → DEDUP-009 (primary) |
| ECON-16-01 | → SPEC-F-02 (absorbed; contributes the `CLAUDE.md` doc site) |
| ECON-16-02 | → DEDUP-001 (primary) |
| ECON-16-03 | → DEDUP-007 (sole) |
| ECON-16-04 | → DEDUP-006 (primary) |
| PATTERN-001 | → DEDUP-003 (merged) |
| PATTERN-002 | → DEDUP-001 (folded in as supporting missing-control evidence, per ruling) |
| MR-001 | → MR-16-02 (manual review) |
| MR-002 | → §4 reconcile-only (`d47619d29f…`) |
| MR-003 | → DEDUP-010 (merged with S-01) |
| S-01 | → DEDUP-010 (primary) |
| S-02 | → DEDUP-008 (sole; **kept separate** from DEDUP-007, justified in-line) |
| S-03 | → MR-16-01 (manual review, pre-existing-code context recorded) |
| F-01 | → SPEC-F-01 (kept separate from DEDUP-002, by ruling) |
| F-02 | → SPEC-F-02 (absorbs ECON-16-01) |
| F-03 | → SPEC-F-03 (kept separate from DEDUP-006) |
| F-04 | → SPEC-F-04 (kept separate from DEDUP-009) |

**Zero source labels were removed without a destination.** The only outright consolidations are exact/near
duplicates (LOCAL-001/CODE-002/PATTERN-001; LOCAL-002/CODE-001; LOCAL-V01/CODE-005; ECON-16-04/LOCAL-004;
S-01/MR-003; ECON-16-02/PATTERN-002; ECON-16-01/F-02), each traceable via the `Source labels absorbed`
row of its merged finding.
