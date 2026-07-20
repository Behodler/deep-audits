# FORK-PARITY-4WAY — phoenix-nft-staking staker family

Run: phoenix-nft-staking-20
Submodule HEAD: `0d1a0b2`
Story under review: `[story-021]` @ `f65aec9` — "Add NFTStakerPriceScaledMigrateReady with ported migration block"
Watch note extended: `WATCH-17-maintenance-coupling-drift` — now covers **FOUR** hand-maintained copies.

| # | File | LOC | Emission model | Migratable |
|---|------|-----|----------------|------------|
| 1 | `src/NFTStaker.sol` | 621 | APY/runway (`R = S·A/yr`, `S = totalStaked·latestPrice`) | no |
| 2 | `src/NFTStakerPriceScaled.sol` | 660 | APY/runway + `priceScale` | no |
| 3 | `src/NFTStakerDepletion.sol` | 854 | linear depletion (`R = budget/windowSeconds`, totalStaked-independent) | yes |
| 4 | `src/NFTStakerPriceScaledMigrateReady.sol` | 1005 | APY/runway + `priceScale` | **yes (new)** |

Diff basis: `diff -u` on raw files, plus a comment-stripped `diff` (`grep -v '^\s*//|^\s*///|^\s*\*|^\s*/\*|^\s*$'`) so
that documentation churn is separated from executable divergence. Both are reproduced in full below by classification.

---

## 0. Blast-radius verification (story-021 "untouched" claim)

`git show f65aec9 --stat`:

```
 src/NFTStakerPriceScaledMigrateReady.sol           | 1005 ++++++++++++++++++++
 test/NFTStakerPriceScaledMigrateReady.t.sol        |  717 ++++++++++++++
 test/NFTStakerPriceScaledMigratorOrchestrators.t.sol |  399 ++++++++
 3 files changed, 2121 insertions(+)
```

**VERIFIED.** The commit is purely additive. `NFTStaker.sol`, `NFTStakerPriceScaled.sol`,
`NFTStakerDepletion.sol`, `NFTStakerMigrator.sol`, `InPlaceNFTStakerMigrator.sol` and
`INFTStakerMigratable.sol` are byte-for-byte untouched, exactly as the commit message claims.
Zero deletions, zero modifications. The live audited `NFTStaker` and the deployed
`NFTStakerPriceScaled` (RatchetNFTStaker `0x299b0071def42d35eaf5ea24cc0a71cf10655a64`) are unaffected.

---

## 1. Leg A — `NFTStaker.sol` → `NFTStakerPriceScaled.sol` (re-verified, run-17 baseline)

Comment-stripped diff, complete:

```
contract NFTStaker            -> contract NFTStakerPriceScaled
+    uint256 public immutable priceScale;
     constructor(..., uint256 _dispatcherIndex)  ->  (..., uint256 _dispatcherIndex, uint256 _priceScale)
+        require(_priceScale != 0, "NFTStaker: zero price scale");
+        priceScale = _priceScale;
+        latestPrice = latestPrice * priceScale;      // in _recomputeSchedule
```

**Exactly the three documented deltas** (contract name, `priceScale` immutable + ctor guard/assignment,
the single multiply). No drift. This re-confirms the run-17 finding — no fix has leaked in either direction
across this leg in the intervening three stories.

---

## 2. Leg B — `NFTStakerPriceScaled.sol` → `NFTStakerPriceScaledMigrateReady.sol` (the new leg)

15 hunks / 554 diff lines raw; the comment-stripped diff reduces to the deltas classified below.
**Every executable delta is accounted for. Nothing exists beyond the story-021 stated intent.**

### 2.1 INTENDED — matches story-021 verbatim

| # | Delta | Location (new file) | Story-021 clause |
|---|-------|---------------------|------------------|
| B-01 | `import INFTStakerMigratable`; `contract … is …, INFTStakerMigratable` | L15, L21–L28 | "the `INFTStakerMigratable` interface" |
| B-02 | `enum PoolState {Active, Migrating}`, `PoolState public poolState`, `address public migrator` | L214–226 | migration block |
| B-03 | `error Rescue__ZeroRecipient()` | L233 | `rescueERC20` port |
| B-04 | 7 new events: `Rescued`, `MigratorSet`, `MigrationInitiated`, `MigratedOut`, `UserMigrated`, `DepositedFor`, `PoolReset` | L273–289 | migration block |
| B-05 | `modifier onlyMigrator` | L300–303 | migration block |
| B-06 | `setMigrator(address)` `onlyOwner` | L339–342 | `setMigrator` |
| B-07 | `rescueERC20(IERC20,address,uint256)` `onlyOwner`, reward-token-guarded | L433–444 | `rescueERC20` |
| B-08 | `_safePay(uint256)` delegates to new `_safePayTo(address,uint256)`; transfer target `msg.sender` → `account` | L680–718 | `_safePayTo` split |
| B-09 | `_updatePool` early-return + `lastRewardTime` fast-forward while `Migrating` | L498–501 | freeze hook |
| B-10 | `pendingReward` forward projection gated on `poolState == Active` | L950 | freeze hook |
| B-11 | `totalDebt` returns `committedDebt` while `Migrating` | L979 | freeze hook |
| B-12 | migration primitives: `initiateMigration`, `batchMigrate`, `userMigrate`, `_exitPosition`, `depositFor`, `finalizeAndReset`, `userInfo` | L774–945 | migration block |

### 2.2 INTENDED — the four declared PRICE-SCALED deltas (all four present and correct)

| # | Delta | Location | Verified |
|---|-------|----------|----------|
| PS-1 | `_recomputeScheduleIfActive()` introduced; `_syncBudget` (both branches), `stake` tail, `unstake` tail routed through it. `_syncBudget`'s recompute stays **unconditional** (not inflow-gated) unlike the depletion variant. | L463, L469, L482–485, L642, L663 | **YES** — 4 call sites, all accrual-path; matches "the frozen snapshot cannot move while Migrating" for the accrual path. |
| PS-2 | `depositFor` carries a tail `_recomputeSchedule()` — load-bearing because `R = totalStaked·latestPrice·A/yr`. | L923 | **YES** — unguarded, correct, because `depositFor` already `require(poolState == Active)` at L881. |
| PS-3 | `finalizeAndReset` re-derives the schedule against the drained pool (`Active` first, then `_recomputeSchedule()`), matching unstake-to-zero (`S == 0` → `rate 0`, `windowEnd == now`). | L925–933 | **YES** — and this is a **fix-forward** relative to `NFTStakerDepletion`, see §3.2. Test `testFinalizeAndResetMatchesUnstakeToZero` covers it. |
| PS-4 | `depositFor` settles existing pending via `_safePayTo(user, …)` rather than `_safePay(…)`, which would pay the migrator. | L887 | **YES** — and this is a **fix-forward** relative to `NFTStakerDepletion`, see §3.1. |

### 2.3 UNACCOUNTED-FOR deltas

**None.** Every executable line in the comment-stripped diff maps to a row in §2.1 or §2.2.
Claim 1 ("`NFTStakerPriceScaled` verbatim plus the migration block plus 4 price-scaled deltas") is
**VERIFIED EMPIRICALLY**, not accepted on assertion.

---

## 3. Leg C — `NFTStakerDepletion.sol` migration block → `NFTStakerPriceScaledMigrateReady.sol` migration block

This is the leg the story-021 port copied *from*. Both copies now carry a nominally identical migration block, so
divergence here is the highest-value drift signal. Two divergences are fix-forwards that leave the depletion copy
carrying the defect.

### 3.1 DRIFT-01 — `depositFor` pays the MIGRATOR on `NFTStakerDepletion` (reverse drift; live defect on copy #3)

`src/NFTStakerDepletion.sol:756`:

```solidity
    function depositFor(address user, uint256 amount) external override nonReentrant onlyMigrator {
        ...
        if (info.amount > 0) {
            uint256 pending = (info.amount * accRewardPerShare) / ACC_PRECISION - info.rewardDebt;
            if (pending > 0) {
                pending = _safePay(pending);          // <-- pays msg.sender == the MIGRATOR
                if (pending > 0) emit Claimed(user, pending);
            }
        }
```

vs `src/NFTStakerPriceScaledMigrateReady.sol:887`:

```solidity
                pending = _safePayTo(user, pending);  // <-- correct
```

`NFTStakerDepletion` **already defines `_safePayTo`** (L603) and already uses it correctly in `_exitPosition`
(L733) — so this is a missed call-site, not a missing primitive. `depositFor` is `onlyMigrator`, so
`msg.sender` is always an orchestrator contract, never the user. Effect: an existing staker's earned phUSD is
transferred to the migrator contract while `Claimed(user, pending)` is emitted — the event lies about where the
money went.

Reachability: only when the `depositFor` target **already holds a non-zero position** with non-zero pending —
i.e. an `InPlaceNFTStakerMigrator` partial round-trip, or migrating a user into a staker they are already in.
Recoverability differs by orchestrator:
- `InPlaceNFTStakerMigrator` has `rescueERC20` (L~250) → owner can recover and hand-distribute.
- `NFTStakerMigrator` has **no rescue function of any kind** → phUSD is permanently stranded in the migrator.

**Classification: DRIFT.** The fix landed in copy #4 (story-021) and was explicitly called out in the commit
message ("`_safePay(...)`, which would pay the migrator") but was **not** mirrored back into copy #3.
The story-021 author knowingly identified the defect and left the sibling unpatched.
Direction of required mirror: copy #4 → copy #3. **Recommend a finding against `NFTStakerDepletion.sol:756`.**

### 3.2 DRIFT-02 — `finalizeAndReset` does not re-arm the schedule on `NFTStakerDepletion` (the known L-02)

`src/NFTStakerDepletion.sol` `finalizeAndReset` ends at `emit PoolReset()` with **no** `_recomputeSchedule()`;
copy #4 adds one (L931). On the depletion model this is the ledgered Low **L-02** ("finalizeAndReset revives pool
without re-arming window"). It is **not a new drift** — it is the previously-recorded open Low — but it is now
*asymmetric*: the analogue is **FIXED in copy #4** and still **OPEN in copy #3**. Recorded here so the next
depletion pass does not read copy #4 as evidence the class is closed.

On the price-scaled model the omission would have been strictly worse than on the depletion model (the stale
`rewardRate` was sized against the *pre-migration* `totalStaked`, so the first post-reset `_updatePool` would
accrue at a rate an empty/refilled pool never justified). The port correctly recognised this. **INTENDED, correct.**

### 3.3 Remaining Leg-C deltas (all INTENDED, model-driven)

| Delta | Copy #3 (Depletion) | Copy #4 (PriceScaled MigrateReady) | Verdict |
|-------|---------------------|-------------------------------------|---------|
| `_syncBudget` recompute | inflow-gated (`if (inflow > 0) _recomputeSchedule()`), no-hook branch does **not** recompute | unconditional, via `_recomputeScheduleIfActive()` | INTENDED — see §4 (DANGEROUS-MIRROR check) |
| `stake` / `unstake` tail recompute | **removed** (story-020) | **retained**, routed through `_recomputeScheduleIfActive()` | INTENDED — see §4 |
| `depositFor` tail recompute | present, cosmetic ("pin `windowEnd` for parity") | present, **load-bearing** | INTENDED (PS-2) |
| `_recomputeScheduleIfActive` helper | absent (not needed — no accrual-path recompute survives story-020) | present | INTENDED (PS-1) |
| `priceScale` immutable + ctor arg/guard + multiply | absent | present | INTENDED (inherited from Leg A) |
| `depletionWindowMonths` / `setDepletionWindow` | present | absent | INTENDED (different emission model) |

---

## 4. DANGEROUS-MIRROR check — story-020's depletion rate/window fix

**Standing direction (`WATCH-17` / run-19): story-020's `NFTStakerDepletion` rate-drift fix must NOT be mirrored
into the APY/runway copies.** The fix (a) inflow-gates the `_syncBudget` recompute and (b) deletes the
`stake` / `unstake` tail recomputes. On a depletion staker the rate is `budget / windowSeconds`, independent of
`totalStaked`, so the tails are pure parity decoration and their removal is safe. On an **APY/runway** staker
`R = totalStaked · latestPrice · A / SECONDS_PER_YEAR`, so the tails are the M-03 fix itself — deleting them
would leave `R` sized for the pre-mutation pool and let surviving stakers over-collect.

Verification on all three APY/runway copies at HEAD `0d1a0b2`:

| Copy | `_syncBudget` no-hook branch | `_syncBudget` hook branch | `stake` tail | `unstake` tail | Mirrored? |
|------|------------------------------|---------------------------|--------------|----------------|-----------|
| `NFTStaker.sol` | `_recomputeSchedule()` | unconditional `_recomputeSchedule()` | present | present | **NO** ✅ |
| `NFTStakerPriceScaled.sol` | `_recomputeSchedule()` | unconditional `_recomputeSchedule()` | present | present | **NO** ✅ |
| `NFTStakerPriceScaledMigrateReady.sol` | `_recomputeScheduleIfActive()` | unconditional `_recomputeScheduleIfActive()` | present (`…IfActive`) | present (`…IfActive`) | **NO** ✅ |

**CLEAR.** The story-020 fix has not leaked into any APY/runway copy. The new copy #4 preserves the unconditional
recompute and both tails, wrapping them only in the `Migrating` freeze guard — which suppresses them *while frozen*,
never *while Active*. Behaviour while `poolState == Active` is byte-equivalent to `NFTStakerPriceScaled`.
The story-021 message states this explicitly ("`_syncBudget`'s recompute here is unconditional, unlike the
depletion variant, and the stake/unstake tails recompute too") — **faithful**.

---

## 5. Inherited prior-ledger findings — is copy #4 carrying a known bug?

| Prior finding | Origin | Present in copy #4? | Notes |
|---|---|---|---|
| **L-08** priceScale magnitude unchecked | `NFTStakerPriceScaled.sol` (run-17, open Low) | **YES — inherited verbatim** | Ctor L317 checks only `_priceScale != 0`; no upper bound. A mis-sized `priceScale` (e.g. `1e18` instead of `1e12`) inflates `S` by 10^6 and the emission rate with it. Immutable → unrecoverable without redeploy. Copy #4 inherits the identical footgun. See LOCAL-004. |
| **M-02** `emergencyWithdraw` over-emission | `NFTStaker.sol` (run-16, **WON'T-FIX**, owner-acked 2026-06-09) | **YES — inherited verbatim** | `emergencyWithdraw` (L735) decrements `totalStaked` with **no** trailing recompute (by design: it must never touch `_syncBudget`/`_updatePool`, per the CLAUDE.md "ID change never strands principal" invariant). On an APY/runway model `R` therefore stays sized for the pre-exit pool and survivors over-collect until the next interaction. Structurally identical to the acked M-02. **Not re-filed** — disclosed as inherited-unchanged per the audit's wont-fix disclosure rule. The wont-fix rationale (deployed + no migrate-on-behalf + `pullAndRefresh` mitigation) transfers: copy #4 is not yet deployed, and it additionally has `pullAndRefresh` **and** a migrator, so the mitigation surface is strictly larger, not smaller. |
| **run-19 L-01** in-place migrator narrative ("hatch + floor INTACT, only `migrateIn` bricks") | `InPlaceNFTStakerMigrator.sol` + `NFTStakerDepletion` | **Analogue present, and slightly WIDENED** | The narrative holds: if the staker cannot return to `Active`, `migrateIn` reverts on `depositFor`'s `require(poolState == Active)` but the `claimTimedOut` hatch and the `totalParked` floor are untouched, so parked stake always exits to its owner. **Widening:** copy #4's `finalizeAndReset` now makes two external calls via `_recomputeSchedule()` (`nftMinter.configs(dispatcherIndex)` and `dispatcherHook.mintDebt()`); the depletion `finalizeAndReset` makes none. A reverting hook/minter therefore newly bricks the *revival* path on copy #4. Remedy exists (`setDispatcherHook(address(0))` has no guard and no recompute) → LOCAL-005, Low. **Do not re-point the migrator to a new staker id** — that was the run-19 incomplete-fix trap and it still applies. |
| **M-01** depletion rate-drift | `NFTStakerDepletion.sol` (run-18, fixed by story-020) | **N/A** | Class does not exist on the APY/runway model. Confirmed not mirrored (§4). |

---

## 6. Migrator interoperability (`INFTStakerMigratable`) — claim 5

`INFTStakerMigratable` declares exactly four members. Copy #4 implements all four with `override`:

| Interface member | Implementation | Modifiers | Conformant |
|---|---|---|---|
| `initiateMigration()` | L774 | `override nonReentrant onlyMigrator`, `require(poolState == Active)` | ✅ |
| `batchMigrate(address[]) returns (uint256[])` | L797 | `override nonReentrant onlyMigrator`, `require(poolState == Migrating)`, idempotent (zeroed user → 0) | ✅ |
| `depositFor(address,uint256)` | L879 | `override nonReentrant onlyMigrator`, `require(amount > 0)`, `require(poolState == Active)` | ✅ |
| `userInfo(address) returns (uint256,uint256)` | L942 | `external view override` | ✅ |

Interface is **fully and correctly implemented**; no member is missing, no signature drifts, no modifier is weaker
than the interface NatSpec requires. `userMigrate` / `finalizeAndReset` / `setMigrator` are deliberately outside
the interface (permissionless hatch, owner-only, owner-only respectively) — matching copy #3.

**`NFTStakerMigrator` (cross-staker):** `migrate()` calls `oldStaker.batchMigrate` → sums → `setApprovalForAll` →
per-user `newStaker.depositFor`. Copy #4's `depositFor` pulls via `safeTransferFrom(msg.sender, …)`; the approval
covers it. Works in both roles (source and target). Test `testCrossStakerHappyPathPriceScaledToPriceScaled` and the
**cross-model** `testCrossModelDepletionToPriceScaled` (depletion source → price-scaled target) both pass in-repo.
Note the migrator is typed only on the interface, so a *cross-model* pairing is structurally permitted — that is by
design here, but it means a depletion **source** carries DRIFT-01 (its `depositFor` is unused in that direction, so
the cross-model test does **not** exercise the bug — DRIFT-01 remains untested and unnoticed by the suite).

**`InPlaceNFTStakerMigrator` (in-place rewire):** `migrateOut` → `batchMigrate`; `migrateIn` → per-user
`depositFor`. Compatible. Two operational notes:
- Per-user cost on copy #4 is materially higher than on copy #3: each `depositFor` runs `_syncBudget`
  (external `dispatcherHook.pull()`) **plus** a tail `_recomputeSchedule()` (external `configs()` + `mintDebt()`)
  — 3 external calls per user per loop iteration, versus 1 storage-only recompute on the depletion copy.
  `migrateIn(start, end)` slices must be sized conservatively. QA-level.
- The intended operator order is `migrateOut …` → `finalizeAndReset` → rewire → `migrateIn …`. Copy #4's
  `finalizeAndReset` re-derives against an empty pool (rate 0), and each subsequent `depositFor` re-sizes `R`
  through its own tail — the schedule converges correctly across a partial `migrateIn`.

---

## 7. Maintenance-coupling watch — updated directive

`WATCH-17-maintenance-coupling-drift` now spans **four** files. The pairwise mirror obligations, as of `0d1a0b2`:

```
NFTStaker.sol  ──(priceScale only)──▶  NFTStakerPriceScaled.sol  ──(migration block)──▶  NFTStakerPriceScaledMigrateReady.sol
                                                                                                    ▲
NFTStakerDepletion.sol ─────────────────(migration block source)────────────────────────────────────┘
```

Directives for the next run:
1. **Diff all four** files pairwise. A three-way diff is no longer sufficient.
2. **Any `NFTStaker` / `NFTStakerPriceScaled` fix must be mirrored into copy #4.** Copy #4 is downstream of both.
3. **Story-020's depletion rate/window fix must still NOT be mirrored into copies #1, #2, #4.** Re-run §4's table.
4. **DRIFT-01 is an open mirror debt in the reverse direction** (copy #4 → copy #3). If the next run sees
   `NFTStakerDepletion.sol:756` still calling `_safePay`, the drift is unresolved.
5. Copy #4 is the only APY/runway copy with a `poolState`. Any new accrual-path recompute added to copies #1/#2
   must, when mirrored here, be routed through `_recomputeScheduleIfActive()` — mirroring a bare
   `_recomputeSchedule()` would silently break the migration freeze.
