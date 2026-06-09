# Sanitizer reconciliation — RESIDUAL B (stable-staker-08)

## Candidate

**Title:** `setYieldStrategy` underwater-swap silently erases the underwater-withdraw protection and FCFS-concentrates the loss.

- **Contract / function:** `src/StableStaker.sol` :: `setYieldStrategy` (L202-238)
- **Root-cause locus:** guard-OFF drain at L214-217 (`_routeExit(token, staked, false)`) + redeposit at L231-233, with `pool.totalStaked` never rewritten.
- **rootCauseClass (proposed):** `underwater-swap-erases-withdraw-protection` (FCFS-loss-concentration via guard-OFF strategy swap)
- **Fingerprint:** `b3a03fe3598745e5dbc13b86a7988620965bf9a87f85fa01d08f6d2a9c353e80`
  (`sha256("src/StableStaker.sol:setYieldStrategy:underwater-swap-erases-withdraw-protection")`, entryPoint=null)

## VERDICT: **KEEP** (new, in-scope, distinct)

## Mechanism — verified against source @ HEAD

Confirmed line-by-line in `src/StableStaker.sol`:

- `setYieldStrategy` L214-217: when an old strategy is present and `totalStaked > 0`, it calls
  `_routeExit(token, staked, false)` — **`guardUnderwater = false`**. In `_routeExit` (L691-711) the
  underwater branch (L697) is gated on `guardUnderwater`, so with the guard OFF it falls straight to
  L708-710 `strategy.withdraw(token, staked, ...)` and returns the **actual balance delta**. On an
  underwater old strategy this delta `R_old < staked`.
- L231-233: the recovered idle balance (`R_old`) is redeposited into the NEW strategy.
- **`pool.totalStaked` is never rewritten** anywhere in `setYieldStrategy` (verified — no `totalStaked`
  assignment in L202-238). The pool still believes `totalStaked = staked`, but only `R_old` of backing
  was moved.
- New strategy reads at-par: `_isUnderwater` (L666-667) compares `totalBalanceOf` vs `principalOf` of
  the *new* strategy, which just received `R_old` and books it as principal → equal → **false**.
- `withdrawDisabled(token)` (L612-617) returns `_isUnderwater(...)` → flips **TRUE → FALSE**.
- The non-migrating `withdraw` underwater guard (L697) no longer fires; withdraws proceed at-par,
  realizing the `staked - R_old` shortfall **FCFS**: first withdrawer paid full principal, last
  withdrawer eats the deficit. PoC outcome (Alice 50e6 full, Bob 40e6 / loses 10e6) is consistent
  with the code path.

Claims hold. The finding is real.

## Known-issue reconciliation

### KI #6 — Underwater withdraw block — **does NOT cover (it is VIOLATED)**
KI #6 documents the *protection*: while `totalBalanceOf < principalOf`, `withdraw` reverts so a
non-migrating user is not forced to realise a loss; only `emergencyWithdraw` / `migrateOut` bypass it.
This candidate is the opposite: an owner strategy-swap **silently lifts** that very protection (flips
`withdrawDisabled` TRUE→FALSE and re-enables an at-par `withdraw` over an unbacked pool). KI #6 is the
invariant this finding shows being **broken**, not a blessing of the behaviour. A known issue that
documents a protection cannot suppress a finding that the protection is silently defeated. **No
suppression.**

### KI #7 — "Replacing an in-use strategy does NOT auto-migrate" — **does NOT cover (premise superseded)**
KI #7's safe-config ("operator must drain first or replace only while `totalStaked == 0`") rests on the
premise that `setYieldStrategy` does **not** auto-drain. story-006 (commit `e7bb675`) **changed that** —
`setYieldStrategy` now best-effort auto-drains (L207-217). The footgun here is a consequence of the NEW
drain behaviour, and KI #7 states **no** new safe-config for the underwater-swap case ("only swap
at/above par"). A known issue whose factual premise has been superseded by a later story cannot suppress
a finding arising from the superseding code. **No suppression.**

### KI #8 — owner trust / centralization for `setYieldStrategy` — **does NOT cover**
KI #8 / Law 3 trusts a **non-malicious** owner and excludes "malicious owner could…" vectors. This is
not that: the owner is taking a *remedial* action (swapping to a healthy strategy), the call neither
reverts nor warns, and a competent non-malicious owner would be **surprised** that the swap silently
disables the underwater protection and concentrates a realized loss on the last withdrawer. Per the
CLAUDE.md Law-3 exception, a non-obvious owner footgun that unknowingly breaks a Law-2 protection / KI
invariant is **in scope** as an operational hazard. **Not suppressed.** Not the invalid "reckless admin
mistake" category — the harm is non-obvious, not an obvious misconfig.

## Ledger reconciliation (`reports/ledgers/stable-staker.json`)

No fingerprint collision. Per-entry analysis:

- **`678e6fa2` (M-02, acknowledged, rootCauseClass `missing-migration-guard`)** — same function, but it is
  the **`active`-during-migration** case: re-approving a strategy after `initiateMigration` parked R as
  idle, sweeping R back in, bricking `userMigrate`. story-006 fixes it via `require(!migrationInfo[token].active)`
  (now present at L203). The candidate is in the **HEALTHY** (non-migrating) regime with an
  **underwater** old strategy — a different precondition, different rootCauseClass, different victim
  (FCFS withdraw loss vs stranded migrant principal). The L203 guard does NOT touch this path.
  **Distinct.**

- **`dab5a656` (M-01, submitted, rootCauseClass `accounting-desync`)** — same function, also a
  totalStaked-vs-actual desync, but its trigger is adopting a **haircutting (market)** strategy over a
  **non-empty idle pool** (the idle-sweep `strategy.deposit` discards `creditedPrincipal` at L231-233 →
  `principalOf < totalStaked` on the NEW strategy side). The candidate's desync is created on the
  **drain** side (guard-OFF `_routeExit` under-recovers from an **underwater old** strategy, `R_old <
  staked`) and the distinctive harm is the **TRUE→FALSE flip of `withdrawDisabled`** — the new strategy
  is at-par, NOT haircutting, so `dab5a656`'s mechanism (new-strategy slippage) does not apply. Related
  symptom (totalStaked overstated), genuinely different upstream cause and trigger. **Distinct, not a
  duplicate.** (Worth a cross-reference note in the report.)

- **`0dca43f3` (M-05, acknowledged-deferred, rootCauseClass `fcfs-loss-socialization`)** — same FCFS
  loss-socialization *family*, but keyed on **`emergencyWithdraw`** (guard-OFF by design as the escape
  hatch). The candidate's loss is realized on the **normal `withdraw`** path that was supposed to be
  **blocked** — the novelty is precisely that an owner swap **re-enables** the blocked path. Different
  function, different entry trigger (owner swap vs user emergency exit). **Distinct.**

- **`69c7666e` (M-02 run-01, wont-fix, rootCauseClass `fcfs-loss-socialization` on `_routeExit`)** — the
  intended buffer-at-par FCFS path. The wont-fix is explicitly **buffer-scoped on `_routeExit`** and
  rests on the design that `withdraw` stays **blocked** while underwater except through the reserve
  buffer. This candidate does NOT use the buffer branch (it is the guard-OFF drain branch), and crucially
  it **silently flips the underwater flag off** so the protection the wont-fix relies on is gone. The
  wont-fix coverage note for M-05 already establishes that bufferless/distinct-trigger FCFS exposures do
  **not** inherit `69c7666e`. Same reasoning applies here, a fortiori (this one additionally erases the
  flag). **Does not inherit the wont-fix. Distinct.**

## Origin classification

No ledger fingerprint match → **origin: `new`**. Proceeds to severity-classification and reporting.
(Recommended cross-references in the eventual report: `dab5a656` and `678e6fa2` as same-function siblings
distinguished by rootCauseClass; `69c7666e` / `0dca43f3` as the FCFS family this does not inherit.)

## Answers to the four key questions

1. **KI #6?** No — KI #6 is the *protection* being silently lifted; the finding demonstrates its
   violation, not an instance of it.
2. **KI #7?** No — story-006 superseded KI #7's "does not auto-migrate" premise; KI #7 states no
   safe-config for the underwater-swap case.
3. **Duplicate of `69c7666e` / `678e6fa2` / `0dca43f3` / `dab5a656`?** No — distinct fingerprint,
   distinct trigger/precondition, and the `withdrawDisabled` TRUE→FALSE flip is novel to this finding.
4. **Reckless admin mistake (invalid) or non-obvious footgun (in scope)?** Non-obvious footgun, in scope
   (Law-3 exception): remedial action, no revert/warning, surprising consequence to a competent
   non-malicious owner.

## Sanitization report (JSON)

```json
{
  "sanitizationReport": {
    "timestamp": "2026-06-08T00:00:00Z",
    "project": "stable-staker",
    "run": "stable-staker-08",
    "inputFindings": 1,
    "removedFindings": 0,
    "passedFindings": 1,
    "flaggedForReview": 0,
    "kept": [
      {
        "findingId": "RESIDUAL-B",
        "title": "setYieldStrategy underwater-swap silently erases underwater-withdraw protection and FCFS-concentrates the loss",
        "contract": "src/StableStaker.sol",
        "function": "setYieldStrategy",
        "lineStart": 214,
        "lineEnd": 233,
        "rootCauseClass": "underwater-swap-erases-withdraw-protection",
        "fingerprint": "b3a03fe3598745e5dbc13b86a7988620965bf9a87f85fa01d08f6d2a9c353e80",
        "origin": "new",
        "reason": "no known-issue match (KI#6 violated not covered; KI#7 premise superseded by story-006; KI#8 Law-3 exception applies); no ledger collision (distinct from dab5a656/678e6fa2/0dca43f3/69c7666e); non-obvious owner footgun"
      }
    ],
    "removals": [],
    "flagged": []
  }
}
```
