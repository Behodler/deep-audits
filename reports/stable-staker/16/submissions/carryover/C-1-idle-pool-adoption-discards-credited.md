<!--
ID: ss6m1
CARRYOVER COPY — stable-staker run-16
Fingerprint: dab5a65613c7af50bb124ac4bcde1ed259355c7e1ba654a732031c9511fed510
Label this run: C-1 (carryover; NOT a centralization label)
Severity: MEDIUM (carried) · Ledger status: fix-pending (human-set, never auto-closed)
Bucket: FIX-PENDING (fix not yet landed) — NOT an incomplete fix
Source of this copy: reports/stable-staker/06/submissions/M-01-idle-pool-adoption-discards-credited.md (FULL COPY, verbatim below)
Prior carryover copies (verified present): reports/stable-staker/08/submissions/carryover/M-01-idle-pool-adoption-carryover.md, reports/stable-staker/09/submissions/carryover/M-01-idle-pool-adoption-haircut.md
DANGLING POINTER IN THE LEDGER (do not follow): the ledger field `carryover_run15` names reports/stable-staker/15/submissions/M-01-C2.md, which DOES NOT EXIST. reports/stable-staker/15/submissions/M-01.md is a different finding (ss15m1, par-exit front-run). Ledger not modified by this document; flagged for a human at /ledger.
HOLD: HTQ-14-02 — ARMED. Do not propose `fixed`.
Run: stable-staker-16 · Commit: fa06de5 (branch `master`)
-->

# [C-1] *(carryover)* Idle-pool strategy adoption discards `creditedPrincipal`, shorting last withdrawers

> **PoC artifact — status, stated honestly.** The original submission below cites
> `workspace/stable-staker/test/PoC_M01_AdoptionHaircut.t.sol`. **That file is not present in the
> writable workspace at this run's commit** (`workspace/stable-staker/test/` was verified; the file is
> absent — the workspace has since been synced forward). The PoC was recorded `passing` on 2026-06-06 at
> run-06 and has **not** been re-run this run; its transcript is reproduced below as the historical
> record it is. Treat the finding as carried on its run-06 evidence, not as re-proven at `fa06de5`. This
> is bit-rot in the artifact, **not** evidence that the finding is fixed.

> **This is a FULL COPY, not a stub.** Audit policy: carryover findings are reproduced in full so the
> submission bundle stands on its own and a reader never has to chase a prior run's directory. The
> original run-06 submission is reproduced verbatim below the carryover header.

## Carryover status — read before the finding

| | |
|---|---|
| **Ledger fingerprint (verbatim)** | `dab5a65613c7af50bb124ac4bcde1ed259355c7e1ba654a732031c9511fed510` |
| **Ledger status** | **`fix-pending`** — human-set 2026-08-29 (corrected from `acknowledged` per `HTQ-14-01`) |
| **Severity** | **Medium**, carried unchanged. Not re-classified this run. |
| **First seen / last seen** | `stable-staker-06` / `stable-staker-10` (`125f585`) |
| **Contract / function** | `src/StableStakerV2.sol` / `setYieldStrategy` (path drift repaired at run-15; fingerprint unchanged) |
| **Bucket this run** | **FIX-PENDING (fix not yet landed)** |
| **HOLD** | **`HTQ-14-02` — ARMED.** Do **not** propose `fixed`. |

**Why the bucket is "fix not yet landed" and NOT "incomplete fix".** The two are different signals and
must not be conflated: an **incomplete fix** means code changed, was intended to close the finding, and
the finding survived — which ranks second only to a regression, because it reads as done. That is **not**
the case here. This run's range (`2146428..fa06de5`, stories 022 / 023 / 024) **did not touch this code
range at all** — no patch for this finding was written, attempted, or landed in the range. The finding is
simply still open with a fix owed. Recording it as an incomplete fix would send a reader to inspect a
patch that does not exist.

**Why it is carried at all, and why it was not suppressed.** `fix-pending` is *not* a disposal. Unlike
`acknowledged` — which means "accepted and disposed of, we are living with it" and does suppress —
`fix-pending` means "accepted and a fix is owed" and is never suppressed: it is rescanned, carried over,
and shown by `/open-issues` exactly like `open`, until a human marks it `fixed`. This entry was in fact
mis-filed as `acknowledged` and corrected to `fix-pending` on 2026-08-29 (`HTQ-14-01`) precisely because
the suppression was removing a live bug from every future scan while a fix was still owed.

**Why no `fixed` is proposed, despite a standing proposal on the entry.** The ledger carries
`proposedStatus: fixed` at `proposedFixCommit: 125f585` — story-010's `setYieldStrategy` empty-pool gate
(`require(poolInfo[token].totalStaked == 0, "StableStaker: pool not empty")`), which makes the in-place
adoption sweep over a non-empty pool structurally unreachable. **That proposal remains HELD under
`HTQ-14-02`**: the very same empty-pool gate is what makes the `ss14m1` / `d1aa4060` idle-sweep desync
**permanent**, so this entry must not be flipped to `fixed` until that side effect has an owner. Only a
human at `/ledger` may act on it.

**Not re-targeted this run.** Silence is not evidence. No finding in run-16 addressed `setYieldStrategy`'s
discarded `creditedPrincipal` return; the entry was not looked for and did not resurface. `lastSeenRun` is
deliberately not bumped, and the human's fix commitment stands.

**Ledger writes performed by this document: 0.**

---

# Original submission, reproduced in full (run-06, `stable-staker-06`)

*Reproduced verbatim. Note for navigation: the contract was renamed `src/StableStaker.sol` →
`src/StableStakerV2.sol` at run-15 (story-019 V1/V2 split), so the paths and line anchors below refer to
the pre-rename tree. The fingerprint is unchanged and remains this entry's identity; the entry was matched
across the rename by **function + root-cause class**, never by path, and was not re-filed as new.*

---

<!--
ID: ss6m1
C4 Submission Metadata
Title: [M-01] Idle-pool yield-strategy adoption discards `creditedPrincipal`, silently shorting the last withdrawer
Severity: Medium (plausible)
Root Cause Link: https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L213-L216
PoC File: workspace/stable-staker/test/PoC_M01_AdoptionHaircut.t.sol
Commit: 7e9ef80a916081148e28df60ef6daf83c9157a3b
-->

## Finding description and impact

### Summary

`setYieldStrategy` sweeps any pre-existing idle pool into a newly adopted strategy but discards the
`creditedPrincipal` value that `IYieldStrategy.deposit` now returns. When a market / haircutting
strategy is adopted over a non-empty idle pool, `poolInfo.totalStaked` is left at its full nominal
value while the strategy only books a haircut amount of principal. This re-opens the exact
`totalStaked > principalOf` desynchronisation that the "story-005" fix was meant to close, and the
gap is paid for — silently, with no revert — by the last user(s) to withdraw.

### Vulnerability details

The `reflax-yield-vault` dependency was bumped (to `2306719`) so that `IYieldStrategy.deposit` now
returns `uint256 creditedPrincipal`. A market / haircutting strategy books

```
creditedPrincipal = amount * (MAX_BPS - slippageToleranceBps) / MAX_BPS   // < amount
```

and treats the `(amount - creditedPrincipal)` gap as protocol-owned surplus. Its `withdraw` caps
redemption to the booked principal and does **not** revert on over-request.

The story-005 fix correctly updated the user deposit paths (`stake`, `depositFor`, `_routeDeposit`)
to credit the **returned** value. However, `setYieldStrategy`'s first-adoption idle sweep was
missed ([StableStaker.sol#L213-L216](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L213-L216)):

```solidity
// Sweep any idle balance already sitting in the contract into the new strategy so that
// accounting is consistent immediately (at first adoption this equals staked principal).
uint256 idleBalance = IERC20(token).balanceOf(address(this));
if (idleBalance > 0) {
    strategy.deposit(token, idleBalance, address(this)); // <-- return value discarded
}
```

When a haircutting strategy is adopted over a non-empty idle pool, the sweep deposits `idleBalance`
but discards `creditedPrincipal`. The result is:

```
poolInfo[token].totalStaked == idleBalance                          // unchanged, full nominal
strategy.principalOf(token, address(this)) == idleBalance * (1-slip) // haircut
```

The inline comment at L211-L212 even asserts the now-false invariant that the post-sweep strategy
principal equals the staked principal.

The protocol's safety net does not catch this. The withdraw underwater guard (`_isUnderwater` /
`withdrawDisabled`) compares the strategy's own `totalBalanceOf` against its `principalOf` — both at
the haircut basis, so they are at par. The guard never compares against the farm's inflated
`totalStaked`, so `withdrawDisabled` stays `false` and the strategy looks perfectly healthy while the
farm's accounting is overstated.

### Impact

- **Last-withdrawer FCFS shortfall.** Early withdrawers redeem their full staked principal. Because
  the strategy caps redemption to its booked (haircut) principal and never reverts, the last
  withdrawer(s) silently receive `idleBalance * slip` less than their staked principal — with **no
  revert and no underwater block**. Real user principal is lost on the ordinary, healthy withdraw
  path.
- **Crystallised, unrecoverable surplus.** The `idleBalance * slip` gap is booked as skimmable
  protocol surplus, permanently unrecoverable by the shorted users.
- **Secondary (distributional, subsumed by the fix).** Pre-adoption stakers retain inflated reward
  weight, since `user.amount / totalStaked` is computed on the overstated `totalStaked`. The emission
  cap itself is **not** violated (it is enforced independently by `_updatePool`); this is purely a
  distributional skew and is fixed by the same correction.

Migration is **not** the loss path: `initiateMigration` distributes the haircut uniformly across all
migrants (`p_i · min(R,P)/P`), which is fair. The loss is specific to the **healthy withdraw path**
for a non-migrating pool.

### Severity justification

Medium is the honest label, matching the C4 "value leak with stated assumptions and external
requirements" definition.

- It is **not High**: it requires the owner to adopt a market / haircutting strategy over a
  non-empty idle pool. That is a documented, intended, correctly-performed operation (per-token
  opt-in `setYieldStrategy`), but it is still an external/config precondition that caps the issue
  below High.
- It is **not demotable to Low / centralization**: the owner does nothing wrong — no privilege
  abuse and no admin mistake. The loss is a protocol accounting bug triggered by a sanctioned
  operation, silently shifting real user principal into skimmable surplus on the healthy withdraw
  path.

This is distinct from the project's known issues:

- **Not** known-issue #7 (replacing an *in-use* strategy): this is *first adoption* over a live idle
  pool, which is presented as a supported operation.
- **Not** known-issue #5 (exit-time slippage being protocol-owned): this is a deposit/adoption-time
  haircut shorting a non-migrating withdrawer.
- **Not** the wont-fix "underwater buffer FCFS" Medium (a transient, mean-reverting buffer dip in
  `_routeExit` — different function, mechanism, and victim), nor the previously submitted
  "non-uniform AMM haircut" Medium (`migrateOut`, since removed).

## Recommended mitigation steps

Capture and reconcile the sweep's return value in `setYieldStrategy` so that `totalStaked` is kept
equal to strategy-recoverable principal:

```solidity
uint256 idleBalance = IERC20(token).balanceOf(address(this));
if (idleBalance > 0) {
    uint256 credited = strategy.deposit(token, idleBalance, address(this));
    if (credited < idleBalance) {
        // Socialise the unavoidable adoption haircut pro-rata across current stakers.
        poolInfo[token].totalStaked -= (idleBalance - credited);
    }
}
```

Reducing `totalStaked` by `(idleBalance - credited)` socialises the unavoidable adoption haircut
pro-rata across all current stakers, instead of dumping it entirely on whoever withdraws last.

Alternatively, restrict adoption of a haircutting strategy to `totalStaked == 0` (mirroring the
existing replace-only-while-empty operational guidance) and document the restriction.

Either approach keeps `totalStaked == strategy.principalOf(token, address(this))`, so no withdrawer
is silently shorted.

## Proof of Concept

A runnable Foundry PoC is provided in the writable workspace clone:

- **File:** `workspace/stable-staker/test/PoC_M01_AdoptionHaircut.t.sol`
- **Test:** `test_M01_adoptionSweepHaircut_lastWithdrawerShortfall`
- **Mock:** `test/mocks/MockYieldStrategy.sol` — faithfully mirrors
  `ERC4626MarketYieldStrategy`: `deposit` books `amount * (MAX_BPS - slip) / MAX_BPS` and returns
  it; `withdraw` caps redemption to the booked principal and does not revert on over-request.

Run:

```bash
forge test --match-path test/PoC_M01_AdoptionHaircut.t.sol -vvv
```

Scenario and observed results:

1. `addToken(dai)`; `userA` stakes `100`, `userB` stakes `100`, no strategy set
   → `totalStaked == 200`, contract holds `200` idle.
2. Owner calls `setYieldStrategy(dai, marketMock @ 1% slip)`: the sweep deposits `200`; the mock
   books `principalOf == 198`, but `totalStaked` stays at `200`
   (`assertGt(totalStaked, bookedPrincipal)`; shortfall `== 2e18 == idleBalance * slip`).
3. `userA` withdraws `100` → receives `100.0` (full principal).
4. `userB` withdraws `100` → the strategy caps redemption to the remaining `98`, so `userB`
   receives `98.0` with **no revert** (`assertLt(receivedB, 100e18)`; `STAKE - receivedB == 2e18`).
5. `withdrawDisabled == false` throughout — the underwater guard is structurally blind to the
   inflated `totalStaked`.

Observed output: `userA` received `100.0`, `userB` received `98.0`, `userB` shortfall `2.0`.

The mock's fidelity to the real strategy was confirmed, and the loss vanishes at zero slippage,
proving the discarded `deposit` return value is the direct cause of the shortfall.
