# Economic Scan — phlimbo-ea run-10 (Tier 2)

- Submodule HEAD: `e32588d` (stories 029 & 030)
- Scope: `src/PhlimboV3.sol` reward economics
- Method: profile-first; source re-read on every value-flow leg (`_updatePool`, `_claimRewards`,
  `stake`/`withdraw`/`claim` debt realignment, `_updatePhUSDEmissionRate`, `IFlax`).

## Thread adjudications

### Thread 1 — PM-001 / DEDUP-04 (phUSD uncapped mint): CORRECTLY-SUPPRESSED (unchanged basis)
- **Reachable at HEAD?** Yes, by construction: `_claimRewards:863 phUSD.mint(beneficiary, pending)`
  with no funded-budget cap, driven by `_updatePool:813-816 phUSDReward = timeElapsed * phUSDPerSecond`.
- **Trigger:** owner commits `setDesiredAPY(bps)` with `bps > 0` → `_updatePhUSDEmissionRate:930`
  sets `phUSDPerSecond = totalStaked*bps/10000/SECONDS_PER_YEAR > 0` → any staker's claim mints
  phUSD. This is exactly DEDUP-04's "re-emit-if-nonzero-APY" trigger.
- **Did 029/030 alter the basis or reachability?** No. story-029 touched only the stable/promo
  transfer legs; story-030 removed `pauseWithdraw`. Neither touches the phUSD mint leg, the
  emission-rate formula, or the accumulator. Reachability and suppression basis are byte-for-byte
  unchanged from run-07.
- **Is it a bug?** No arithmetic over-mint: the phUSD rate carries no `PRECISION` factor
  (`phUSDPerSecond` is a raw token/sec), and `phUSDReward = timeElapsed*phUSDPerSecond` then
  `accPhUSDPerShare += phUSDReward*PRECISION/totalStaked` is dimensionally consistent — over one
  year at constant stake it mints exactly `bps/10000 * totalStaked`, i.e. the intended APY. Rate is
  recomputed on every `totalStaked` change (INV-7 / thread 4), so no share-drift over-emission.
- **Honest severity:** Not reportable as a new/independent finding. The phUSD APY reward is the
  core *designed* feature ("Staking yield farm for phUSD ... Linear Depletion reward") — Law-2
  faithful, owner-config-gated. The only residual is the protocol-wide "unbacked mint dilutes the
  phUSD peg" concern, which is a property of the `IFlax`/phUSD treasury contract (out of PhlimboV3
  scope) and is a documented, config-conditional design choice. Remains **correctly-suppressed**
  under DEDUP-04. No auto-suppression applied — re-derived from source; verdict is intended-design,
  not unfalsifiable-KI deference.

### Thread 2 — Banking economics / distribution cap (story-029): NO FINDING (author comment verified)
Re-derived rather than trusted. The cap at `_updatePool:799`
(`toDistribute = potentialReward > rewardBalance ? rewardBalance : potentialReward`) is correct
and `totalUnclaimableStable` must NOT be subtracted:
- Accrual sequence: `_updatePool` accrues `toDistribute` into `accStablePerShare:802` and
  **immediately debits** `rewardBalance -= toDistribute:805`. The banked amount was therefore
  already removed from `rewardBalance` at accrual time — *before* `_claimRewards` ever runs.
- Banking (`_claimRewards:876-877`) moves an already-accrued, already-debited amount from
  "payable now" to "payable on pull". The tokens never leave the contract; `rewardBalance` is not
  touched a second time.
- Therefore the cap already excludes banked stable. Subtracting `totalUnclaimableStable` again
  would **double-debit** → under-distribution / shortfall to honest stakers. Not subtracting is the
  correct direction (favours protocol solvency, never over-distributes).
- **No redistribution to other stakers:** each staker's slice of a given accrual is their own
  pro-rata `amount*Δacc/PRECISION`; the banked user's slice was allocated to *their* debt, and all
  three callers realign `stableDebt`/`promoDebt` AFTER `_claimRewards` returns (stake:675-676,
  withdraw:721-722, claim:768-769), zeroing their pending so it is neither re-paid nor handed to
  others. **No double-count, no dilution, no shortfall.**
- Solvency: contract must physically hold `rewardBalance + totalUnclaimableStable`; banked tokens
  are physically retained (never transferred), so the invariant holds. (Only `emergencyTransfer`/
  migrator `withdrawAll` sweep banked funds — the documented, accepted escape-hatch trade-off.)

### Thread 3 — Linear-Depletion (PM-002): STILL MITIGATED after story-029
Banking is strictly downstream of accrual. `rewardPerSecond` is never recomputed in `_updatePool`
(INV-3) and `_claimRewards` does not touch `rewardPerSecond` or `rewardBalance`. Whether a transfer
is paid or banked, the depletion curve is identical — `rewardBalance` is decremented exactly once,
at accrual (`:805`), for the same `toDistribute`. No rate re-anchoring introduced by 029. The
phlimbo Linear-Depletion rate-drift class does not reappear.

### Thread 4 — V3-M-05 / V3-M-06 closure
- **M-06 (pauseWithdraw over-mint): CLOSED, no incomplete-fix.** `pauseWithdraw` fully removed
  (verified absent from `PhlimboV3.sol` + interface). `totalStaked` mutates only at stake:678 and
  withdraw:724, each immediately followed by `_updatePhUSDEmissionRate` (:684, :735);
  `emergencyTransfer` never touches `totalStaked`. No path mutates the staked total without
  recomputing `phUSDPerSecond`. The emission-rate-bypass over-mint vector is gone.
- **M-05 (reverting reward transfer freezes principal): stated vector CLOSED; residual survives.**
  The reported M-05 trigger — a USDC-class `rewardToken` blocklisting the recipient — is fixed:
  stable (`:875-879`) and promo (`:899-905`) legs are now `_tryTransfer`-guarded with banking, so a
  blocklisted external reward recipient can no longer brick stake/withdraw/claim. **However the
  same root-cause class survives on the phUSD leg** (see ECON-10-01 below) — the one reward move
  story-029 did *not* make non-reverting. This is an incomplete-fix *of the class*, not of M-05's
  specific external-blocklist vector.

## Reportable finding

### ECON-10-01 (Low / operational footgun) — phUSD mint leg still bricks principal on mint revert
- **Contract/line:** `src/PhlimboV3.sol:861-864` (`_claimRewards`), reached by
  `stake`/`withdraw`/`claim`.
- **Root cause:** the phUSD reward leg is a bare `phUSD.mint(beneficiary, pendingPhUSDAmount)` — the
  single token move story-029 left un-wrapped (stable + promo were converted to non-reverting
  `_tryTransfer`+bank). `IFlax.mint` is authorization-gated (`authorizedMinters`/`canMint`,
  `mintVersion`, `revokeAllMintPrivileges`), so it *can* revert.
- **Trigger (owner footgun, Law 3):** if PhlimboV3 loses its phUSD minter authorization — owner
  calls `phUSD.revokeAllMintPrivileges()`, a `mintVersion` bump, or `canMint` cleared (e.g. during a
  phUSD incident, minter rotation, or migration) — then for **every** staker with pending phUSD
  (i.e. anyone who staked while `desiredAPYBps > 0`), `pendingPhUSDAmount > 0` → `phUSD.mint` reverts
  → the entire `withdraw`/`stake`/`claim` call reverts → **principal frozen**. Same freeze-via-
  reverting-reward-leg impact M-05 was meant to eliminate, on a different token.
- **Economic impact / affected parties:** all V3 stakers' principal locked until minter role is
  restored. No theft (recoverable), so not High.
- **Why not suppressed:** a competent, non-malicious owner would be *surprised* that revoking phUSD
  mint rights — a plausible incident-response or migration action — bricks all V3 withdrawals. That
  is a non-obvious consequence → in-scope footgun, not a "reckless admin" invalid.
- **Severity: Low.** Requires an owner-privileged mint-authorization change (or a phUSD-contract
  failure), not a permissionless/external trigger, so it is materially lower-likelihood than M-05's
  blocklist vector. Recoverable (restore mint role or re-grant). Surface as operational hazard with
  guidance: either wrap the phUSD mint leg in the same `_tryTransfer`/bank pattern (mint-then-bank
  is not directly possible, but a try/catch around `mint` that banks a phUSD IOU would preserve the
  principal path), or document that phUSD minter authorization must never be revoked while V3 holds
  stake. Matches profile watch-item A1.

## Summary verdict
- **Reportable now:** ECON-10-01 (Low, phUSD-mint-brick footgun / M-05 residual class).
- **Correctly-suppressed:** DEDUP-04 phUSD uncapped emission (intended APY design; 029/030 did not
  change basis or reachability).
- **Verified-closed / no finding:** thread 2 distribution cap (correct, no redistribution),
  thread 3 Linear-Depletion (still mitigated), M-06 (fully closed).
- **No new High/Medium** from the story-029/030 economic surface.
