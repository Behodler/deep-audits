# [CARRYOVER] M-05 — `emergencyWithdraw` socializes the underwater shortfall FCFS onto the last caller

> **Carryover stub, not new analysis.** Reported in a prior run, still **open** at HEAD `c3ec65b`.
> This run (`125f585..c3ec65b`, story-011 `depositFor` guard) did **not** touch `emergencyWithdraw`.
> Reproduced so it is not lost between runs. Triage with `/ledger stable-staker`.

- **Fingerprint:** `0dca43f3`
- **Title:** `emergencyWithdraw` realizes underwater loss FCFS via direct share over-redemption (bufferless par bank-run): early exiters whole, late exiters absorb the entire shortfall
- **Severity:** Medium
- **Status:** acknowledged (fix **unblocked** — reflax-yield-vault `relinquishPrincipal` dependency landed 2026-06-08 via story-045/046; not yet wired on `emergencyWithdraw`)
- **Proposed status:** none
- **Location:** `src/StableStaker.sol` — `emergencyWithdraw` (L304-318, `_routeExit(token, amount, false)`, guard OFF)
- **Original report:** [reports/stable-staker-07/submissions/M-05-emergencyWithdraw-fcfs-socialization.md](../../../stable-staker-07/submissions/M-05-emergencyWithdraw-fcfs-socialization.md)

## Why still open

`emergencyWithdraw` passes `guardUnderwater = false`, so `_routeExit` redeems the requested principal
from the strategy at the depressed price: first callers receive full principal (over-redeeming
shares), late callers receive less or revert, absorbing the pre-existing shortfall. The upstream
`relinquishPrincipal` primitive this fix was deferred pending **landed in reflax-yield-vault on
2026-06-08** (story-045 + story-046 hoist, `AYieldStrategy.sol:620/638`) and is already consumed on
the stable-staker side by the buffer/`withdraw` path (story-007), so the fix is now **unblocked** — but `emergencyWithdraw`
itself is still **non-pro-rata** (unchanged at `c3ec65b`), so the FCFS socialization persists. Owner
acceptance (acknowledged, valid Medium, fix deferred) is authoritative; severity is not re-escalated.

## Resolve

```
/ledger stable-staker fixed 0dca43f3 --commit <commit>   # once emergencyWithdraw is made pro-rata
```
