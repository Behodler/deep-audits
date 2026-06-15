# Code Scan — stable-staker story-013 (`InPlaceMigrator._reinjectWithTopup`)

- **Scope:** `src/InPlaceMigrator.sol` @ `d95f4a6` (diff baseline `ffa4947`)
- **Mode:** regression, implementation-bug lens (economic design deferred to econ-scanner)
- **Context read:** `StableStaker.sol` (`depositFor` 616-638, `_routeDeposit` 757-763, `_pullToken` 740-745), `interfaces/IStableStaker.sol`, profile LOCAL-001..005
- **Scan timestamp:** 2026-06-15

## Summary of verified-safe items (no finding)

- **Div-by-zero in `mulDiv(amt-credited, amt, credited)`** — NOT reachable. `credited = amountAfter - amountBefore`, and `info.amount` is only ever incremented by the principal `depositFor`, which itself `require(credited > 0)` (StableStaker.sol:632). So the delta is ≥ 1. Confirmed safe.
- **`amt - credited` underflow** — guarded by `if (credited < amt)`. Safe.
- **`amountAfter - amountBefore` / `finalAmount - amountBefore` underflow** — `info.amount` is monotonically non-decreasing across a `depositFor` (line 633 `+=`); `_settle` touches only `rewardDebt`/`accPhusdPerShare`, never `info.amount`. Snapshot delta is exactly the credited principal. Profile LOCAL-005 confirmed against source. Safe.
- **`info.amount` is the right field** — yes; it is the credited-principal accumulator. Reward bookkeeping is in `rewardDebt`, untouched by the delta. Safe.
- **Re-entrancy between snapshots** — `migrateIn` is `nonReentrant`; helper is `private`. No re-entry can contaminate the before/after pair. Safe.

---

## Findings (concrete implementation bugs)

### CODE-001 — Top-up `depositFor` can revert with `"StableStaker: amount=0"` when shortfall is 1 wei (batch DoS)
- **Severity hypothesis:** Low (availability / dust-edge DoS)
- **Location:** `src/InPlaceMigrator.sol:273-284` (esp. 276, 284)
- **Mechanism:** When `credited == amt - 1` (a 1-wei haircut), `topup = mulDiv(1, amt, credited)`. For `amt <= credited` this would be ≥1, but the real hazard is the opposite rounding: when the shortfall is tiny relative to `credited`, `mulDiv` rounds **down** and can yield a `topup` that is still ≥1, so the second `depositFor(topup)` runs — but if that top-up's own credit is also 1 wei it still satisfies `> 0`. The genuine break is when `amt - credited == 0`: handled by the `if`. The narrow live failure: a haircut so small that `mulDiv(amt-credited, amt, credited)` truncates to **0** while `credited < amt` is still true. Then `staker.depositFor(token, user, 0)` hits `require(amount > 0, "StableStaker: amount=0")` (StableStaker.sol:622) and reverts the **entire** atomic batch.
  - Reachable when `(amt - credited) * amt < credited`, i.e. `shortfall < credited/amt`. For `amt` near 1e18 and a 1-wei shortfall, `shortfall*amt = 1e18` and `credited ≈ 1e18`, so `topup ≈ 1` — borderline. For sub-unit-decimals tokens or `amt < credited` it can truncate to 0.
- **Why it matters:** the `if (credited < amt)` predicate and the `topup > 0` precondition of `depositFor` are not aligned. A shortfall too small to gross up into a non-zero deposit bricks the whole `migrateIn` slice rather than being absorbed by the `amt/1000` tolerance. The `finalCredited >= amt - amt/1000` backstop would happily have accepted `credited` as-is, but control never reaches it because the `depositFor(0)` reverts first.
- **Fix direction:** guard the second deposit with `if (topup > 0)` (and let the final `require` absorb the residual), or `require(credited < amt && topup > 0)` before depositing.
- **Confidence:** medium (depends on token decimals / haircut granularity to be triggerable; clear logic gap regardless).

### CODE-002 — Surplus check `balanceOf(this) - totalParked[token]` underflows → revert instead of clean "exhausted" error
- **Severity hypothesis:** Low (wrong-revert / DoS clarity; not loss)
- **Location:** `src/InPlaceMigrator.sol:280-283`
- **Mechanism:** `require(topup <= IERC20(token).balanceOf(address(this)) - totalParked[token], ...)`. The RHS subtraction is unchecked-of-intent but checked-math at runtime. After the principal `depositFor(amt)` has already pulled `amt` from balance, if the migrator's balance has fallen **below** the remaining `totalParked[token]` (e.g. under-funded migrator, a fee-on-transfer-like discrepancy in `_pullToken`'s balance-delta accounting, or surplus swept mid-migration per LOCAL-004), the subtraction underflows and reverts with a **panic (0x11)** rather than the intended `"top-up surplus exhausted"` string.
- **Why it matters:** purely an implementation-quality / diagnosability bug — the operator sees an arithmetic panic instead of the designed error, and the batch DoS root cause (insufficient surplus, LOCAL-001) is masked. No fund loss; CEI ordering is otherwise sound (`totalParked` decremented before the helper, profile-verified).
- **Fix direction:** compute `uint256 surplus = bal >= parkedRem ? bal - parkedRem : 0;` and compare, or use `Math.saturatingSub`, so the require fails with the intended message.
- **Confidence:** medium.

### CODE-003 — Widened `forceApprove(staker, balanceOf(this))` leaves a dangling allowance after the batch
- **Severity hypothesis:** Low (lingering allowance; bounded by immutable trusted target)
- **Location:** `src/InPlaceMigrator.sol:225-227`
- **Mechanism:** Approval was widened from `forceApprove(staker, total)` (exact principal slice) to `forceApprove(staker, balanceOf(this))` (whole balance). The loop only pulls `total` (principal) + Σ`topup` (≤ surplus). The approval is the **full balance**, which generally exceeds `total + Σtopup` (the operator is told to over-fund surplus). After `migrateIn` returns, the residual allowance `balanceOf - (total + Σtopup)` **remains granted to `staker`**.
  - Each subsequent `migrateIn` call `forceApprove`s afresh (overwrites), so no monotonic accumulation. But between batches a non-zero allowance to `staker` for the migrator's full token balance persists.
- **Why it matters / why bounded:** `staker` is `immutable` and trusted (pinned StableStaker), and it only pulls via `depositFor`'s `_pullToken` during a migration the owner drives — so this is **not** an exploit path under the owner-trust law. It is a hygiene regression vs the prior tight approval: the comment claims "no dangling allowance," which is **inaccurate** — `forceApprove` overwrites on the *next* call but does not zero the residual at batch end. Worth flagging because the code comment asserts a property the code does not provide.
- **Fix direction:** approve exactly `total + projectedTopups`, or `forceApprove(staker, 0)` at the end of `migrateIn` after the loop.
- **Confidence:** high (the dangling allowance is real; severity low because target is immutable+trusted).

### CODE-004 — `amt/1000` tolerance truncates to 0 for `amt < 1000`, turning the soft backstop into a hard exact-par requirement
- **Severity hypothesis:** Low (edge DoS for tiny principals)
- **Location:** `src/InPlaceMigrator.sol:292`
- **Mechanism:** `require(finalCredited >= amt - amt / 1000)`. For `amt < 1000` (raw token units — realistic for tokens with low decimals, or dust positions), `amt / 1000 == 0`, so the requirement collapses to `finalCredited >= amt` — i.e. **exact par with zero tolerance**. Because the gross-up `mulDiv` rounds **down**, `finalCredited` is generically a few wei *short* of `amt`, so for a small `amt` with any non-trivial haircut the assert reverts the whole batch even though the top-up logic worked as designed.
- **Why it matters:** the "0.1% slack absorbs the integer-division residual" guarantee (dev comment line 289-291) silently evaporates below `amt = 1000` units. Combined with CODE-001, small parked positions are the most fragile under this code path.
- **Fix direction:** use an absolute floor too (e.g. `finalCredited + maxResidual >= amt` with `maxResidual = max(amt/1000, K)` for small constant `K`), or document that `migrateIn` requires `amt >= 1000` units.
- **Confidence:** medium.

### CODE-005 — Per-user surplus consumption is greedy within and across batches (stale surplus view for later users) — implementation note
- **Severity hypothesis:** informational / Low (overlaps LOCAL-002; econ-scanner owns the economic framing)
- **Location:** `src/InPlaceMigrator.sol:280-284` (re-read of live `balanceOf` per iteration)
- **Mechanism:** The surplus `require` re-reads live `balanceOf(this)` each iteration, so user *k*'s top-up reduces the balance seen by user *k+1*. Within a single atomic batch this is benign (all-or-nothing). Across **separate** paginated `migrateIn` calls there is no reservation of surplus against the still-parked remainder: an earlier slice can legitimately drain surplus and succeed, leaving a later slice's haircut users to trip the require and revert. The implementation correctly reflects live balance — there is no *accounting* bug here — but the absence of a per-batch surplus reservation is the mechanical root of LOCAL-002.
- **Note:** flagged as implementation context; the exploitability/economic sizing is econ-scanner's (LOCAL-002 / M-07 lineage). No standalone code defect beyond CODE-002's masking of the revert reason.
- **Confidence:** high (behavior), informational (as a code finding).

---

## Cross-references
- CODE-001 and CODE-004 compound: small-`amt` haircut users are simultaneously the most likely to (a) gross up to a 0 top-up and (b) fail the zero-tolerance assert. Both fail-modes are batch-atomic reverts (DoS), never silent under-credit (ss12m1 stays fixed).
- CODE-002 masks the LOCAL-001 under-funding revert with an arithmetic panic.
- CODE-003 contradicts the in-code "no dangling allowance" comment; bounded by immutable trusted `staker` so not an exploit under owner-trust.
- All findings are availability/quality-flavoured (Medium ceiling at most); none re-introduce the silent under-payment that story-013 fixes. No High implementation defect found in the diff.
