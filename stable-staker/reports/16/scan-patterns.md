# Pattern-match scan — stable-staker run-16

- **Project:** stable-staker
- **Commit:** `fa06de5` (range `2146428..fa06de5`)
- **Scan type:** pattern-matching (Tier 1, deterministic signature sweep + condition check)
- **Pattern DB:** `patterns/vulnerability-patterns.json` v1.1
- **patternsChecked:** 35 (all patterns in the DB parsed cleanly; 0 parse errors)
- **patternsSkipped:** 1 — see §5
- **Scope scanned:** `src/StableStakerV2.sol`, `src/CrossVersionMigrator.sol`, `src/InPlaceMigrator.sol`,
  `src/versions/v1/vendor/FlaxToken.sol`, `src/versions/v1/vendor/IFlax.sol`
- **errors[]:** none — every in-scope file was readable and scanned.
- **Profiles consumed first:** `StableStakerV2.profile.md`, `Antimatter.context.md`,
  `Migrators.profile.md`, `FlaxToken.vendor.profile.md`

**Headline.** One STRONG signature match (`REWARD-ACCRUAL-ORDER` at `emergencyWithdraw`), and one
PARTIAL structural match (`REWARD-RUNWAY-DEPLETION`) that exists *only because* the story-023
premise change made it exist. Two patterns that would normally be the loudest hits
(`MINT-ON-DEMAND-OVERMINT`, `ROUNDING-DIRECTION`) are **demonstrably prevented by the code** and are
recorded here as refuted, not filed. The single most consequential result of this run is not a new
match at all — it is §4, the expired-closure audit.

---

## 1. Findings (medium/high confidence)

### PATTERN-001 — REWARD-ACCRUAL-ORDER · `emergencyWithdraw` mutates `totalStaked` without settling

| | |
|---|---|
| patternId | `REWARD-ACCRUAL-ORDER` (HIGH, staking-yield) |
| match strength | **STRONG (signature) / PARTIAL (impact)** |
| confidence | **high** (that the pattern applies) |
| severity | **potential-low** — see the honest impact derivation below; *not* potential-high |
| contract | `src/StableStakerV2.sol` |
| line | 394-411 (mutation at :405) |
| reconciles with | profiler `LOCAL-001`; prior-art `phoenix-nft-staking` emergencyWithdraw over-emission (`911c54fd`, wont-fix) |

Matched signature: *"totalStaked / share balance mutated before `_updatePool()` settles pending at
the old rate"*.

```solidity
394:    function emergencyWithdraw(address token) external nonReentrant {
397:        require(poolState[token] == PoolState.Active, "StableStaker: pool not active");
401:        user.amount = 0;
402:        user.rewardDebt = 0;
404:        unclaimedReward[token][msg.sender] = 0;
405:        poolInfo[token].totalStaked -= amount;      // <-- supply change, no _updatePool above it
406:        _stakers[token].remove(msg.sender);
```

`_updatePool` is called at :215, :327, :351, :378, :471 and :707 — i.e. at the head of
`antimatterPerDay`, `stake`, `withdraw`, `claim`, `initiateMigration` and `depositFor`. It is
**absent from `emergencyWithdraw` alone**. The pattern's `notVulnerableWhen` clause
*"`_updatePool()` runs at the head of every stake/unstake/claim before any share mutation"* is
therefore not satisfied. The signature match is unambiguous.

**Mitigation that partly defeats it — state this, do not inflate.** `_updatePool` :806-828 folds in
exactly `elapsed * antimatterPerSecond` per call regardless of `totalStaked`:

```solidity
822:            pool.accAntimatterPerShare += (reward * ACC_PRECISION) / pool.totalStaked;
```

Because `Σ_users amount_i · Δacc ≤ reward` (profiler P3) and `accAntimatterPerShare` has exactly one
writer (P1), the missing settle **cannot over-emit**. What it does is *redistribute*: the window
`[lastRewardTime, now]` that the exiter was a member of is later divided across the reduced
denominator, so survivors receive the exiter's slice of that window. The exiter forfeits all reward
by design (:402-404), so the value is not destroyed — it changes hands.

This is the structural difference from the `phoenix-nft-staking` instance of the same shape, and it
is why this is **not** the same severity: there the reward was a per-position rate with no shared
denominator, so the skip produced genuine over-emission; here the MasterChef accumulator caps it.

**Does the story-023 premise change escalate it? No — and that matters.** Antimatter being
redeemable makes *over-emission* a real dilution liability, but this defect emits nothing extra. Do
not let the premise change pull this one upward; the honest bucket is a Low/QA-grade undocumented
redistribution that also makes `pendingReward` jump discontinuously for survivors.

**Residual worth reporting:** the redistribution is undocumented, and the `Active`-only gate at :397
means it can only fire outside terminal migration, so the migration snapshot is unaffected.

---

### PATTERN-002 — REWARD-RUNWAY-DEPLETION · emission has no funded budget, and the premise that made that safe is void

| | |
|---|---|
| patternId | `REWARD-RUNWAY-DEPLETION` (HIGH, staking-yield) |
| match strength | **PARTIAL** (structural; no code defect, a design premise that expired) |
| confidence | **medium** |
| severity | **potential-medium** — route to econ-scanner for the value bound |
| contract | `src/StableStakerV2.sol` |
| line | 214-219 (`antimatterPerDay`), 806-828 (`_updatePool`), 385 / 620 (mint sites) |

Matched signatures: `rewardRate` (as `antimatterPerSecond`), `lastRewardTime`, `mint(`.

The pattern's `notVulnerableWhen` list asks for **`elapsed` capped at `min(now, windowEnd)`**, a
**solvency invariant `balance == rewardBudget + committedDebt`**, and a **per-window emission cap**.
StableStakerV2 has *none of the three*, because it has no budget concept at all:

```solidity
214:    function antimatterPerDay(address token, uint256 amountPerDay) external onlyOwner poolExists(token) {
215:        _updatePool(token);
216:        uint256 perSecond = amountPerDay / SECONDS_PER_DAY;
217:        poolInfo[token].antimatterPerSecond = perSecond;
```

```solidity
820:        uint256 elapsed = block.timestamp - pool.lastRewardTime;
821:        uint256 reward = elapsed * pool.antimatterPerSecond;
```

There is no `windowEnd`, no runway, no funding assertion, and `Antimatter` has **no supply cap**
(`Antimatter.context.md`). Emission is perpetual mint-on-demand at an owner-set rate.

**Under the old design this was correct and not a finding.** phUSD emissions were bounded by the
minter-cushion reasoning: the reward token had no user redemption path, so an unfunded emission was
opportunity cost, not loss. **Story-023 voids that.** `Antimatter.annihilate` (:226-267) lets any
holder convert 1 AM + 1 stablecoin-equivalent into 2 phUSD, of which the AM half is minted
**unbacked** (`_phUSD.mint(recipient, amount)` :263). So each AM emitted is a bearer claim on
unbacked phUSD, and AM is freely transferable with no cap.

**Honest framing.** This is not a code bug — no path emits more than `elapsed * rate`, and the rate
is `onlyOwner`. It is a **Law-3 footgun test**: would a competent, non-malicious owner be surprised
that `antimatterPerDay` is now a *dilution* rate against phUSD rather than a marketing budget, with
no on-chain cap, no runway, and no funding check? The premise flipped in a sibling repo, with no
compensating control added on this side. I judge that surprising, and therefore in scope — but the
value bound (capped by the annihilate exchange rate and the redeemer's own capital, per
`Antimatter.context.md` item 4) belongs to econ-scanner, not to this tier. I am not asserting a
severity beyond "medium, needs the economic bound".

---

## 2. Manual review (low confidence — routed, not dropped)

### MR-001 — MINT-ON-DEMAND-OVERMINT · pause does not freeze reward minting on the migration path

- patternId `MINT-ON-DEMAND-OVERMINT` · match **SUPERFICIAL** · confidence **low** ·
  `src/StableStakerV2.sol` :376 vs :620

`claim` is `whenNotPaused` (:376). `batchMigrate` and `userMigrate` are **not**, and both reach
`_exitPosition`, which mints:

```solidity
619:        if (owed > 0) {
620:            antimatter.mint(account, owed);
621:        }
```

So a pause withholds the reward backlog from `claim` but **not** from a migration exit. No
over-mint occurs — `owed` is the frozen, already-accrued figure and `_updatePool` no-ops while
Migrating (:809-811) — so this is a completeness gap in the pause, not a value bug. It is routed
here rather than dropped because the premise change makes "reward minting continues during an
incident pause" a materially different statement than it was when the reward token was inert. If
econ-scanner concludes AM emission during an incident is itself the hazard, this is where it lands.

### MR-002 — EMISSION-WINDOW-BOUNDARY / DIVISION-PRECISION · `amountPerDay / 86400` floors to zero

- patternId `EMISSION-WINDOW-BOUNDARY` + `DIVISION-PRECISION` · match **PARTIAL** · confidence
  **low** · `src/StableStakerV2.sol` :216
- **Reconcile-only — already in the ledger** as the open Low *"phUSDPerDay sub-86400-wei/day budget
  floors phusdPerSecond to 0 (silent zero emission)"*. Carried forward unchanged; only the token
  name in the title is now stale (phUSD → Antimatter). Antimatter is 18-decimal
  (`Antimatter.context.md`), so an 86400-wei/day budget is economically absurd and the finding stays
  Low. Flagged so the ledger title is corrected rather than the entry being re-minted.

### MR-003 — REENTRANCY-CROSS-FUNCTION · owner-only functions outside the shared lock

- patternId `REENTRANCY-CROSS-FUNCTION` · match **SUPERFICIAL** · confidence **low**
- `setYieldStrategy` (:249), `finalizeAndReset` (:673) and `rescueERC20` (:910) lack `nonReentrant`
  while every user-facing mutator has it. OZ's guard is contract-wide, so reentry from
  `initiateMigration`'s `strategy.withdraw` (:486) into `stake`/`withdraw`/`claim` is blocked; only
  the three owner-gated functions are reachable. That makes any exploit owner-driven and obvious —
  **Law 3 suppression, correctly applied.** Routed only because the ledger already carries an open
  `info` entry *"initiateMigration writes state after the external strategy.withdraw call"* that
  should be reconciled against this reasoning rather than re-derived next run.

---

## 3. Checked, matched on signature, **defeated by the code** (filed as refuted, not as findings)

These are the patterns most likely to be re-raised by a future scan under the new premise. Each is
recorded with the specific code that prevents it, so the refutation does not have to be re-derived.

**MINT-ON-DEMAND-OVERMINT — no double-mint path. NOT VULNERABLE.**
There are exactly two `.mint(` sites, :385 (`claim`) and :620 (`_exitPosition`). They cannot both
pay the same accrual: `claim` zeroes the backlog *and* re-bases the debt —

```solidity
383:        unclaimedReward[token][msg.sender] = 0;
384:        user.rewardDebt = (user.amount * pool.accAntimatterPerShare) / ACC_PRECISION;
```

— so a subsequent `_exitPosition` computes `pending == 0` and `unclaimedReward == 0`, hence
`owed == 0` and no mint. I checked this specifically for the Migrating window, where `claim` is
*not* poolState-gated (profiler P12): because `_updatePool` no-ops while Migrating, `acc` is frozen,
and the :384 re-base is exact against that frozen `acc`. The double-mint is structurally impossible,
not merely unlikely.

**ROUNDING-DIRECTION — every rounding decision floors toward the protocol. NOT VULNERABLE.**
`perSecond` :216, `acc +=` :822, `pending` :353/:380/:609, `rewardDebt` :336/:356/:384/:716 and
migration `credit = (amt * S) / P` :605 all floor. I tested the round-trip the pattern warns about
(stake → withdraw 1 wei → re-stake): `pending` is computed against the *same* floored `rewardDebt`
the previous leg wrote, so the residual is zero rather than accumulating, and the aggregate is
bounded by `Σ amount_i · Δacc ≤ reward` regardless. There is no attacker-repeatable extraction. This
refutation is worth keeping because the premise change would have made a 1-wei AM loop a real drain.

**FEE-ON-TRANSFER-ACCOUNTING — mitigated by measured deltas. NOT VULNERABLE.**
`_pullToken` :840-846 credits `balanceAfter - balanceBefore`, and `_routeDeposit` returns the
strategy's `credited`, which `stake` :334-335 and `depositFor` :714-715 use in place of the
requested amount. The pattern's `notVulnerableWhen` clause is satisfied exactly.

**YIELD-PRINCIPAL-ACCOUNTING-SKEW — matches, but is entirely pre-existing and already triaged.**
`withdraw` :355 decrements by the **requested** `amount` while :366-367 pays the **measured**
`payout`. This is the known requested-vs-received skew, already carried as `69c7666e` (wont-fix,
owner-confirmed intended) and `0dca43f3` (acknowledged). **No executable change in this range**
touches it. Reconcile-only; do not re-file.

**DOS-UNBOUNDED-LOOP — matches, owner/migrator-gated, already in the ledger.**
`batchMigrate` :576, `CrossVersionMigrator.migrate` :165/:176, `_isRegisteredOn` :237,
`InPlaceMigrator` :170/:215/:231/:371. All `onlyOwner` or `onlyMigrator`; `getStakersRange` :774 is
the paginated read path. Already carried as the open Low *"Unbounded per-user external-call loop in
StableStaker.batchMigrate + CrossVersionMigrator"*. Reconcile-only.

**Zero grep hits (checked, no match — normal, not an error):** `ORACLE-STALE`, `ORACLE-ROUNDID`,
`SIGNATURE-REPLAY`, `PERMIT-FRONTRUN`, `FLASH-LOAN-PRICE`, `MISSING-SLIPPAGE`, `UNSAFE-DOWNCAST`,
`UNPROTECTED-INIT`, `STORAGE-COLLISION`, `CROSS-CHAIN-REPLAY`, `TIMELOCK-BYPASS`, `DOUBLE-VOTING`,
`WEAK-PRNG`, `SELFDESTRUCT-FORCE-ETH`, `ERC4626-INFLATION`, `FIRST-DEPOSITOR-ATTACK`,
`REENTRANCY-ERC777`, `REENTRANCY-ERC721-RECEIVE`, `REENTRANCY-READONLY`, `BATCH-PAYOUT-FIXED-POT`,
`TWO-STEP-COMMIT-WINDOW`, `INCORRECT-OPERATOR`, `RETURN-VALUE-IGNORE`, `CENTRALIZATION-ADMIN`
(matches `onlyOwner` but is DB-noted as Low/QA and adds nothing over the existing ledger).

Note on `ERC4626-INFLATION` / `FIRST-DEPOSITOR-ATTACK`: correctly no-match. This is a MasterChef
`accAntimatterPerShare`/`rewardDebt` accumulator, **not** a share-price vault — there is no
`totalAssets()`-derived exchange rate to inflate. Ledger entry `86fcf00e` (QA) already records this
refutation for the revived-pool window; it holds identically here.

---

## 4. Expired-closure audit — the premise that just died

**This is the load-bearing section of the run.** The task asked me to enumerate every pattern
instance whose suppression rested on *"reward over-credit is harmless because the reward token has
no redemption path"*. I searched all 53 ledger entries for that rationale. The honest answer is more
specific than expected, and I am reporting what I actually found rather than what would have been
tidier:

**No stable-staker ledger entry states that rationale in its `triageReason`.** The premise was never
written down here — it lived at the *scanner* level, as the standing memory notes
`minter-cushion-socialized-losses-intended` and
`externally-derived-yield-opportunity-cost-not-loss`, which suppressed the whole class before a
finding was ever minted. That is worse than a stale ledger entry, because there is no artifact to
re-open. Concretely, the class-level suppressions now void for V2 are:

1. **Reward over-credit is not economic loss.** VOID. Per `Antimatter.context.md` items 1-3, an AM
   over-credit is realisable by an arbitrary third party via permissionless `annihilate`. Any future
   `REWARD-ACCRUAL-ORDER` / `MINT-ON-DEMAND-OVERMINT` / `ROUNDING-DIRECTION` hit on the reward leg
   must be severity-derived fresh, **not** auto-downgraded to opportunity cost.
2. **The minter cannot redeem, so socialised reward error is inert.** VOID for V2 — AM is freely
   transferable, so the holder and the redeemer need not be the same party.
3. **Frozen V1 is unaffected.** V1 still emits phUSD directly; the premise change is V2-only. The
   two vendored files (`FlaxToken.sol`, `IFlax.sol`) are verified byte-identical to the deleted
   `lib/flax-token` submodule at `f5300117`, so nothing in V1's reward leg moved.

**One ledger entry needs a re-read, for a different reason than expected.** `e4567dc3` — *"Terminal
migration has no mint-free escape hatch if phUSD minter rights are revoked mid-migration"*, Low,
**wont-fix** — is the exact shape of the profiler's `LOCAL-002` and of the mint-on-exit-brick family.
Its closing rationale did **not** rest on the redemption premise; it rested on Law 3 (*"an obvious
admin misstep… and recoverable"*). So it is **not** an expired closure on the premise axis, and I am
not claiming it is. But two of its factual supports moved under story-023 and should be re-checked
by the code/econ tiers rather than assumed:

- The old token had `revokeAllMintPrivileges()` (a *mass* revocation an owner might plausibly fire in
  an incident). Antimatter has **only** per-minter `setApprovedMinter` and no mass revocation, which
  makes accidental blanket revocation *less* likely — the rationale arguably got **stronger**, not
  weaker.
- The structural defect is unchanged and still live: `_exitPosition` :619-621 is the **sole** exit
  while Migrating (`emergencyWithdraw` :397 and `withdraw` :347 both require `Active`), so a mint
  failure traps 100% of pool principal with no hatch, and `finalizeAndReset` :676 requires an empty
  pool. The contract's own NatSpec at :829-831 — *"Never calls Antimatter, so a revoked minter role
  cannot brick the principal paths that reach here"* — is true of `_settle` but is quoted in
  CLAUDE.md as a blanket property, which it is not. That over-broad claim is new in this range and is
  the part worth raising, per profiler `LOCAL-002`.

---

## 5. patternsSkipped

| patternId | reason |
|---|---|
| `FRONTRUN-APPROVE` | DB `note`: *"C4 typically considers this QA/known issue"*, and it is on the project's known-invalid list. Signature check run anyway: the codebase uses `SafeERC20.forceApprove` exclusively (`StableStakerV2` :283/:290/:521, `CrossVersionMigrator` :173, `InPlaceMigrator` :227) and never raw `approve`. **No plausible HM twist found**, so nothing was routed to manualReview. Skip is recorded here rather than being silent. |

Related but **not** skipped: `InPlaceMigrator` :227 approves `balanceOf(address(this))` while its own
NatSpec at :191-192 claims *"set to the EXACT slice total"*. That contradiction is real but is (a)
already carried as open QA `ss13l4`, and (b) untouched by this range — `InPlaceMigrator`'s only diff
in `2146428..fa06de5` is NatSpec (`"earned phUSD"` → `"earned reward"`, lines 53/156/302). Both
migrators are **reconcile-only this run: zero executable change**, confirmed against
`Migrators.profile.md`.

---

## 6. Summary counts

- `patternsChecked`: **35**
- `patternsSkipped`: **1** (`FRONTRUN-APPROVE`)
- `findingsCount`: **2** (PATTERN-001 low-severity-but-high-confidence, PATTERN-002 medium)
- `manualReviewCount`: **3** (MR-001, MR-002, MR-003)
- refuted-with-evidence: **6** (§3)
- `errors[]`: **0**
