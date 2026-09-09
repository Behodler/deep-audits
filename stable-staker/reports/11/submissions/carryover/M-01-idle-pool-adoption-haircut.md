# [CARRYOVER] M-01 — Idle-pool strategy adoption discards `creditedPrincipal`, shorting last withdrawers

> **Carryover stub, not new analysis.** Reported in a prior run; status is acknowledged with a
> **propose-fixed @ `125f585`** (story-010 empty-pool gate) **awaiting human `/ledger` confirmation**.
> This run (`125f585..c3ec65b`, story-011 `depositFor` guard) did **not** touch `setYieldStrategy` and
> did **not** re-verify this proposal. Reproduced for visibility. Triage with `/ledger stable-staker`.

- **Fingerprint:** `dab5a656`
- **Title:** Idle-pool strategy adoption discards `creditedPrincipal`, shorting last withdrawers
- **Severity:** Medium
- **Status:** acknowledged (will-fix)
- **Proposed status:** **fixed @ `125f585`** (run-10 — story-010 empty-pool gate), awaiting human confirmation
- **Location:** `src/StableStaker.sol` — `setYieldStrategy` (idle-sweep deposit; gated by `require(totalStaked == 0)` at L228 post-story-010)
- **Original report:** [reports/stable-staker/06/submissions/M-01-idle-pool-adoption-discards-credited.md](../../../06/submissions/M-01-idle-pool-adoption-discards-credited.md)

## Why still open

The `setYieldStrategy` adoption sweep `strategy.deposit(token, idleBalance, address(this))` discarded
the returned `creditedPrincipal`, so adopting a haircutting strategy over a non-empty idle pool left
`totalStaked` at full nominal value while `principalOf < totalStaked`, producing a silent
last-withdrawer FCFS shortfall. Run-10's story-010 empty-pool gate (`require(totalStaked == 0)` at
L228) makes the non-empty in-place adoption sweep **structurally unreachable** (profile G-5,
verified), collapsing the root cause — hence the **propose-fixed @ `125f585`**. The authoritative
status is human-acknowledged (will-fix), so the fix is **proposed, not auto-flipped**, and this run's
scoped story-011 change neither re-verified nor altered it. It stays a visible carryover until a human
confirms.

## Resolve

```
/ledger stable-staker fixed dab5a656 --commit 125f585
```
