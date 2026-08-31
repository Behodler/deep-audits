# Story-Faithfulness Audit (Law 2) — stable-staker run-08

- **Project:** stable-staker
- **Scan type:** story-faithfulness (regression)
- **Submodule HEAD:** `f85450b6d73a728f530a97854ecc882151695cd8`
- **Scan timestamp:** 2026-06-08
- **Profile:** `reports/stable-staker/08/profiles/StableStaker.md`
- **Stories checked:** story-006 (`e7bb675`), story-007 (`f85450b`)
- **Intent sources:** the two `[story-NNN]` commit-message bodies; `lib/stable-staker/CLAUDE.md`
  ("Yield strategies", "Terminal migration mode", "Underwater withdraw block"); ledger triage
  notes `dc361b7d` (M-04 desync) and `0dca43f3` (M-05 emergencyWithdraw underwater loss) which
  the stories cite as their purpose. No `docs/` directory exists in this submodule.

---

## STORY-007 — "Relinquish strategy principal on buffer withdrawal" (`f85450b`)

### Quoted intent

> "When StableStaker pays a withdrawal from its setAsideBuffer (underwater path in `_routeExit`),
> call `strategy.relinquishPrincipal(token, amount)` after emitting `BufferWithdrawn` so the
> strategy's client balance stays in sync with the staker's own `poolInfo.totalStaked` accounting."
> — git commit `f85450b` body

> Purpose, per the M-04 triage `dc361b7d`: "A story-002 underwater buffer-path withdraw decrements
> `pool.totalStaked` without touching strategy principal, leaving `strategy.principalOf > totalStaked`.
> `initiateMigration` … under-drains the strategy, so the `require(principalOf == 0)` reverts on every
> attempt and the token can never enter terminal migration." — ledger `dc361b7d`

### Acceptance criteria
1. The buffer branch of `_routeExit` calls `strategy.relinquishPrincipal(token, amount)` after the
   `BufferWithdrawn` emit, before returning.
2. After a buffer-path withdrawal, `strategy.principalOf(token,this) == poolInfo[token].totalStaked`
   is preserved (so `initiateMigration`'s L410-413 post-check stays satisfiable).

### Conformance trace
- C1 — `_routeExit` buffer branch, `StableStaker.sol:701-704`: `emit BufferWithdrawn` (L702) then
  `strategy.relinquishPrincipal(token, amount)` (L703) then `return amount` (L704). **MATCHES** the
  story literally.
- C2 — `withdraw` does `pool.totalStaked -= amount` (L289); the buffer branch reduces
  `strategy.principalOf` by the same `amount` via L703 → reflax `_relinquishInternal`
  (`AYieldStrategy.sol:638-654`, decrements `clientBalances[this]` and `totalDeposited`). Both
  sides drop by the identical `amount`. In the maintained flow `amount <= user.amount <= totalStaked
  == principalOf`, so the protocol-favouring cap (`AYieldStrategy.sol:644-646`) never bites. The
  invariant **is** preserved; `initiateMigration` L410-413 becomes satisfiable again. **MATCHES.**

The literal story (the `withdraw` buffer path) is faithfully implemented and is the correct,
narrowly-scoped remediation of `dc361b7d`. The two questions in the brief are answered below as
non-findings, then the one residual gap is recorded.

### Question (a) — does `emergencyWithdraw` need to relinquish too? → NOT A FINDING
`emergencyWithdraw` calls `_routeExit(token, amount, false)` (L334, guard OFF, `StableStaker.sol:322-337`).
With guard OFF the buffer branch (L697) is never taken; it always hits the strategy-redeem branch
(L708-710), `strategy.withdraw(token, amount, this)`, which itself decrements `clientBalances[this]`
and `totalDeposited` by the (capped) `amount` (reflax `_withdrawInternal`, `AYieldStrategy.sol:719-720`).
So `emergencyWithdraw` keeps `principalOf` and `totalStaked` in lockstep through the *withdraw*
primitive — it does not need `relinquishPrincipal` and does not re-introduce the `dc361b7d` desync.
The story therefore correctly omits `emergencyWithdraw`; the desync is exclusively a buffer-branch
phenomenon, and only the buffer branch is reachable solely from `withdraw`. **Faithful by omission;
no gap.** (The separate `0dca43f3` / M-05 — `emergencyWithdraw` realizes an underwater haircut FCFS —
is an *economic loss-distribution* issue already acknowledged-deferred in the ledger, NOT a
principal-desync issue, and is out of scope for story-007's stated intent.)

### Question (b) — capped relinquish on an underwater `amount > principalOf`? → NOT A FINDING
For the cap to leave `totalStaked > principalOf`, `withdraw` would have to pass `amount > principalOf`.
But `withdraw` requires `user.amount >= amount` (L284) and `Σ user.amount == totalStaked == principalOf`
under the maintained invariant, so `amount <= principalOf` always holds and the cap is a no-op write-down
of exactly `amount`. "Underwater" (`_isUnderwater`, L666-668) compares `totalBalanceOf < principalOf`
(value below par) — it does **not** mean `principalOf < totalStaked`; principal accounting is unaffected
by negative *yield*. There is no maintained path that makes `principalOf < totalStaked` at withdraw
time, so the cap never under-relinquishes here. **No desync; no finding.** (The profile's own
trust-assumption note flags this only as a cross-contract liveness coupling — if the strategy
de-authorizes the farm, L703 reverts and the underwater withdrawal reverts — which is a deferred
interaction concern, not a faithfulness deviation.)

### STORY-007 VERDICT: **FAITHFUL** (no F-finding)

---

## STORY-006 — "Guard setYieldStrategy during migration + drain old strategy on swap" (`e7bb675`)

### Quoted intent

> "- Add M-02 guard: `require(!migrationInfo[token].active, "StableStaker: migrating")`
>  - Best-effort drain of old strategy's full position before reassignment"
> — git commit `e7bb675` body

> Purpose, per ledger `678e6fa2` (the "M-02" referenced): "…there is no `require(!migrationInfo[token].active)`
> guard. `batchMigrate`/`userMigrate` then `safeTransfer` from the now-empty idle pile and revert, so
> every migrant's principal is stranded… Owner confirmed (2026-06-08): valid footgun, will fix by adding
> `require(!migrationInfo[token].active, "StableStaker: migrating")` to `setYieldStrategy`."

### Acceptance criteria
1. `setYieldStrategy` reverts when `migrationInfo[token].active` (the M-02 guard).
2. When an old strategy is set, the old strategy's position is drained ("best-effort … full position")
   into the contract before reassignment.

### Conformance trace
- C1 — `StableStaker.sol:203`: `require(!migrationInfo[token].active, "StableStaker: migrating");` at the
  top of `setYieldStrategy`. **MATCHES** the commit body and the `678e6fa2` triage verbatim. Closes the
  acknowledged M-02 footgun.
- C2 — `StableStaker.sol:214-217`: reads `staked = poolInfo[token].totalStaked`, and if `staked > 0` calls
  `_routeExit(token, staked, false)` (guard OFF) to drain the old strategy before `forceApprove(old, 0)`
  (L220) and reassignment (L223). The commit explicitly scopes this as **"Best-effort drain"** and the
  source comment (L207-213) states it "caps at recoverable principal, underwater guard OFF — same
  realization path as `initiateMigration`." The implementation matches the *stated* "best-effort"
  semantics. **MATCHES the story as written.**

### The brief's drain question — under-drain with no post-check
`initiateMigration` pairs its identical guard-OFF realization (L405) with a hard post-check
`require(principalOf(this) == 0, "incomplete exit")` (L410-413) that aborts the *terminal* migration if
the realization under-drained. `setYieldStrategy`'s drain (L214-217) has **no** equivalent post-check.

This is a deliberate, documented asymmetry, and it is **safe given the story's own wording**, for two
reasons:
1. The commit body explicitly says **"Best-effort"** — i.e. the story does *not* claim a complete drain.
   The source docstring repeats this ("Best-effort: caps at recoverable principal"). Adding a
   `principalOf==0` post-check would *contradict* the story, not implement it. So the absence is faithful,
   not a deviation.
2. After reassignment the old strategy is **decoupled** (allowance revoked L220, pointer overwritten L223),
   so any residual `principalOf(this)` left on the abandoned old strategy is no longer read by
   StableStaker for *this* token — it cannot desync the live `principalOf == totalStaked` invariant the
   way the migration post-check guards against. The migration post-check exists because terminal mode is
   one-shot and pays a fixed snapshot from a single realized pile; the strategy-swap path has no such
   snapshot dependency.

Why `initiateMigration` *needs* the post-check and `setYieldStrategy` does **not**: terminal migration
freezes `P = totalStaked` and pays every migrant from the one-shot realized `R`; an under-drain there
silently strands value with no retry. A strategy swap re-deposits the recovered idle into the *new*
strategy (L231-234) and the pool stays live and re-drainable, so an under-recovery surfaces as the
normal underwater-haircut behaviour the protocol already absorbs (the profile's deferred
"swap-while-underwater leaves protocol-absorbed haircut" note), not as a one-way bricking. The
behaviour is therefore consistent with story-006 and with the project's documented "yield stays
protocol-owned / stakers get principal only" model.

### STORY-006 VERDICT: **FAITHFUL** (no F-finding)

---

## Summary of verdicts

| Story | Acceptance criteria met? | Law-1 override (intent unsafe)? | Verdict |
|---|---|---|---|
| story-007 (`f85450b`) | Yes — L703 relinquish present; `principalOf == totalStaked` preserved on the buffer path; `emergencyWithdraw` (guard OFF) keeps the books in sync via `strategy.withdraw`, so omitting it is correct; cap never under-relinquishes in the maintained flow | No — intent is the correct narrow remediation of `dc361b7d`; the residual `emergencyWithdraw` underwater-loss is the *separate, already-acknowledged* economic finding `0dca43f3`, not a principal desync re-opened by this story | **FAITHFUL** |
| story-006 (`e7bb675`) | Yes — `!active` guard at L203 (closes `678e6fa2`); old-strategy drain at L214-217 | No — the "best-effort" drain with no `principalOf==0` post-check is faithful to the story's *explicit* "best-effort" wording and is safe because the old strategy is decoupled and the pool stays live (no terminal one-shot dependency); an under-drain on an underwater old strategy surfaces as the already-deferred protocol-absorbed haircut, not a bricking | **FAITHFUL** |

**Findings produced: none (F-00).** Both stories are faithful to their `[story-NNN]` intent, and
neither intent is unsafe under Law 1. The brief's candidate gaps (a) `emergencyWithdraw` not
relinquishing and (b) capped relinquish were each checked and shown to be non-deviations: the
strategy-redeem path keeps the principal ledger in sync without `relinquishPrincipal`, and the cap
cannot bite while `amount <= totalStaked == principalOf`. The story-006 missing post-check is faithful
to the commit's explicit "best-effort" framing and harmless once the old strategy is decoupled.

### Cross-references (not new findings — already tracked)
- `0dca43f3` (M-05, acknowledged-deferred): `emergencyWithdraw` underwater FCFS loss socialization.
  story-007 does not address it and does not claim to; the fix is deferred pending the same reflax
  `relinquishPrincipal` primitive that story-007 now consumes. Re-check candidate: is
  `emergencyWithdraw` now pro-rata? It is **not** in `f85450b` (still guard-OFF share over-redemption,
  L334) — so M-05 remains open-deferred, unchanged by these two stories.
- `678e6fa2` (M-02, acknowledged): now **resolved** by story-006's L203 guard. Propose `/ledger`
  status → fixed on re-reconciliation.
- `dc361b7d` (M-04, acknowledged): now **resolved** by story-007's L703 relinquish. Propose `/ledger`
  status → fixed on re-reconciliation.
