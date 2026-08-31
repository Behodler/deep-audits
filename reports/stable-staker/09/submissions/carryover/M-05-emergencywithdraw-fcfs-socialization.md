# [CARRYOVER] M-05 — `emergencyWithdraw` socializes the underwater pool shortfall FCFS onto the last caller

> **This is a carryover stub, not new analysis.** This finding was reported in a prior run and is
> **still live** at the current HEAD `93b7ce6`; it is owner-**acknowledged** with the fix deliberately
> **deferred**. It is reproduced here so it is not lost between runs. Triage it with
> `/ledger stable-staker`.

- **Severity:** Medium
- **Status:** acknowledged (fix deferred; still-live, re-confirmed this run)
- **Location:** `src/StableStaker.sol` — `emergencyWithdraw` (`_routeExit(token, amount, false)`, guard OFF) and the `_routeExit` underwater buffer branch
- **First seen:** stable-staker-07  ·  **Still present as of:** stable-staker-09 (HEAD `93b7ce6`)
- **Original report:** [reports/stable-staker/07/submissions/M-05-emergencyWithdraw-fcfs-socialization.md](../../../07/submissions/M-05-emergencyWithdraw-fcfs-socialization.md)
- **Fingerprint:** `0dca43f3`

## Status this run

Still **live** at HEAD `93b7ce6`. When a token's strategy is underwater, normal `withdraw` is blocked
and stakers funnel into `emergencyWithdraw`, which calls `_routeExit` with the underwater guard **off**
and over-redeems shares at the depressed price: the first exiters walk away whole while the last exiter
absorbs the entire pre-existing shortfall — an inter-user value transfer (early stakers made whole at
the direct expense of late stakers). Total payout never exceeds realizable value (no protocol theft);
the already-incurred loss is mis-distributed FCFS rather than pro-rata.

**`relinquishPrincipal` landed (story-007), but `emergencyWithdraw` is still non-pro-rata.** The
upstream reflax-yield-vault `relinquishPrincipal` primitive this fix was deferred pending has now
landed and is consumed by the buffer/`withdraw` path — so the fix is **unblocked**. However
`emergencyWithdraw` (and the `_routeExit` underwater buffer branch) still pay the full `amount` /
call `relinquishPrincipal(amount)` with **no pro-rata haircut**, so the FCFS socialization persists.
The M-05 fix is **unblocked-but-unapplied** at `93b7ce6`. Severity is **not** re-escalated — prior
owner acceptance (acknowledged, valid Medium) is authoritative.

Not re-reported with a full submission (acknowledged ledger Medium); this stub is the visibility
pointer. See the
[original report](../../../07/submissions/M-05-emergencyWithdraw-fcfs-socialization.md)
for the full description, impact, attack path, PoC, and recommendation.
