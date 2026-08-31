# Pattern matches — stable-staker (run 08, REGRESSION)

- **Project:** stable-staker
- **Target:** `lib/stable-staker/src/StableStaker.sol`
- **HEAD:** `f85450b` ([story-007] Relinquish strategy principal on buffer withdrawal)
- **Baseline (lastAuditedCommit):** `7e9ef80` ([story-005])
- **Scan type:** pattern-matching (regression, focused on the diff `7e9ef80..f85450b`)
- **Pattern DB:** `patterns/vulnerability-patterns.json` (v1.0, 30 patterns)
- **patternsChecked:** 30

## Changed surface in scope (the diff)

1. `setYieldStrategy` (story-006): new `require(!migrationInfo[token].active)` guard (L203) + best-effort
   drain of the old strategy via `_routeExit(token, staked, false)` (L214-217) on swap/clear.
2. `_routeExit` buffer branch (story-007): new external call `strategy.relinquishPrincipal(token, amount)`
   at L703, fired only on the underwater-but-buffer-covered `withdraw` path.

These two stories are the cross-submodule fix proposed for ledger findings **dc361b7d (M-04)** and
**0dca43f3 (M-05)** / **678e6fa2 (M-02)**. Matches below are scored against that intent.

---

## FINDINGS (medium/high confidence)

### PM-08-001 — YIELD-PRINCIPAL-ACCOUNTING-SKEW (Requested-vs-Received Principal Skew on Strategy Exit)
- **patternId:** `YIELD-PRINCIPAL-ACCOUNTING-SKEW`  → potential-high
- **confidence:** medium
- **contract / line:** `src/StableStaker.sol:691-711` (`_routeExit`), specifically the buffer branch L697-705
- **matchedSignatures:** `balanceBefore`, `totalBalanceOf`, `principalOf`, `yieldStrategy`, `relinquishPrincipal` (new)
- **vulnerableWhen hit:** "principal decremented by REQUESTED while user paid RECEIVED, gap not explicitly attributed"
- **analysis:** The new `relinquishPrincipal(token, amount)` (L703) is the story-007 reconciliation
  primitive: on a buffer-covered underwater withdraw the contract pays `amount` from its idle buffer and
  writes down the strategy's recorded principal by `amount` *without redeeming shares*. The caller
  (`withdraw`, L288-289) already decremented `user.amount` / `pool.totalStaked` by the **requested** `amount`.
  So on this branch requested == relinquished == paid, which is the *correct* direction and DIRECTLY closes
  the ledger-M-04 desync (`dc361b7d`: `totalStaked < strategy.principalOf` after a buffer withdraw). This is
  the `notVulnerableWhen` ("shortfall explicitly accrues to protocol-owned surplus") branch — story-007 is a
  genuine fix, not a new skew.
- **residual / why still medium not closed:** `relinquishPrincipal` is capped to the caller's *available*
  principal (per `IYieldStrategy` L41 "Over-requests are capped"). If a prior buffer withdraw or an external
  actor already drove `strategy.principalOf(this) < amount`, the relinquish silently writes down less than
  `amount`, and `pool.totalStaked` (decremented by full `amount`) again diverges below `principalOf` — the
  exact `dc361b7d` desync, now narrowed but not provably eliminated. The staker reads no return value from
  `relinquishPrincipal` (interface returns `void`, L41) so it cannot detect the cap. **Route to manual review
  / Tier-3 invariant:** assert `pool.totalStaked == strategy.principalOf(token, address(this))` after every
  buffer withdraw. Cross-reference dc361b7d (acknowledged) — this is its candidate fix and must be re-proven,
  not assumed closed.
- **references:** stable-staker + reflax-yield-vault strategy routing; ledger `dc361b7d`, `0dca43f3`.

### PM-08-002 — REENTRANCY-ERC777 (External call mid-function in non-guarded `setYieldStrategy`)
- **patternId:** `REENTRANCY-ERC777`  → potential-high (pattern severity), honest severity gated below
- **confidence:** medium
- **contract / line:** `src/StableStaker.sol:202-238` (`setYieldStrategy`); external calls at L216
  (`_routeExit`→`old.withdraw` L709), L227 (`forceApprove`), L233 (`strategy.deposit`)
- **matchedSignatures:** `transferFrom(`/`IERC20`, plus `.withdraw(` / `.deposit(` external calls with a
  state write (`yieldStrategy[token] = strategy`, L223) sequenced *between* two external interactions
- **vulnerableWhen hit:** "State changes after transfer" + "No reentrancy guard" + "Token type not restricted"
- **analysis:** `setYieldStrategy` is `onlyOwner` but, uniquely among principal-moving paths, carries **no
  `nonReentrant` modifier** (cf. `stake`/`withdraw`/`emergencyWithdraw`/`initiateMigration` all guarded).
  story-006 added two new external calls inside it: the old-strategy drain (`_routeExit`→`old.withdraw`) runs
  while `yieldStrategy[token]` still points at `old` (correct, by comment L211), then `yieldStrategy[token]`
  is overwritten (L223), then the idle balance is swept into the *new* strategy (L233). A malicious/ERC777-ish
  token or a hostile strategy reentering during `old.withdraw` would observe the *pre-swap* wiring; reentering
  during `strategy.deposit` observes post-swap wiring.
- **mitigations present (why not high):** caller is `onlyOwner` (Law 3 — trusted, non-malicious); the
  strategies are protocol-owned reflax adapters; tokens are stables (non-ERC777 in scope). A reentrancy
  exploit here requires either a malicious owner (out of scope, Law 3) or a malicious token/strategy the
  owner knowingly wired. **Footgun angle (in scope, Law 3):** if the owner wires a strategy whose
  `withdraw`/`deposit` reenters `setYieldStrategy` or another path, the missing guard removes the safety net
  every sibling function has. Surface as a defense-in-depth QA note (add `nonReentrant` for symmetry), NOT a
  standalone H/M. Confidence medium because the guard asymmetry is real and newly enlarged by story-006, but
  no concrete reentrant token/strategy in scope realizes it.
- **references:** OZ ReentrancyGuard; ledger `796f775f` (initiateMigration CEI-ordering QA, sibling pattern).

---

## MANUAL REVIEW (low confidence — routed, not dropped)

### PM-08-003 — TWO-STEP-COMMIT-WINDOW adjacent: setYieldStrategy drain reads live `totalStaked`
- **patternId:** `YIELD-PRINCIPAL-ACCOUNTING-SKEW` (drain leg) → potential-medium
- **confidence:** low
- **contract / line:** `src/StableStaker.sol:214-217`
- **analysis:** The story-006 drain requests `_routeExit(token, staked, false)` where `staked = totalStaked`.
  This mirrors `initiateMigration`'s `_routeExit(token, P, false)` (L405) which is paired with a hard
  post-check `principalOf == 0` (L410-413). `setYieldStrategy` has **no equivalent post-check**: if the old
  strategy is a tranche/queue vault that exits only partially, or is currently underwater so `withdraw`
  returns less than `staked`, the drain silently under-recovers and the idle sweep (L231-234) re-custodies
  only the recovered balance into the new strategy — leaving `pool.totalStaked > strategy.principalOf(new)`.
  Same desync family as `dc361b7d`, on the rewire path instead of the migration path. Because the drain uses
  `guardUnderwater=false` it does NOT take the relinquish branch, so story-007 does not reconcile it here.
- **why low:** owner-operated, healthy-pool rewire (cf. known issue #7 / ledger `678e6fa2` covers the
  migration-active case, now guarded by L203). Whether a partial-exit / underwater rewire under-recovers
  depends on the concrete strategy and is config-dependent. **Route:** code-scanner / econ-scanner to decide
  if a `principalOf == 0` (or `== recovered`) post-check is warranted on the rewire drain, and whether this
  is a distinct footgun from `678e6fa2`.

### PM-08-004 — RETURN-VALUE-IGNORE: relinquishPrincipal cap not observed
- **patternId:** `RETURN-VALUE-IGNORE` → potential-medium
- **confidence:** low
- **contract / line:** `src/StableStaker.sol:703`
- **analysis:** `relinquishPrincipal` is declared `void` (IYieldStrategy L34-41) and silently caps
  over-requests at available principal, so the staker has no signal when it wrote down less than `amount`.
  Strictly this is an interface-design constraint (no return to ignore), but the *effect* — books can diverge
  without the staker knowing — is the spirit of RETURN-VALUE-IGNORE and feeds PM-08-001's residual. **Route:**
  Tier-3 invariant on `totalStaked == principalOf` post buffer-withdraw; or a spec-conformance note that the
  primitive should return the actual amount written down.

---

## Patterns checked and NOT matched (regression scope)

- `ERC4626-INFLATION`, `FIRST-DEPOSITOR-ATTACK` — no share-minting/`totalSupply()==0` path in scope; staker
  is a MasterChef farm, not an ERC4626 itself. No change in diff.
- `ORACLE-STALE`, `ORACLE-ROUNDID`, `FLASH-LOAN-PRICE` — no oracle / spot-price reads in scope.
- `SIGNATURE-REPLAY`, `PERMIT-FRONTRUN`, `CROSS-CHAIN-REPLAY` — no signatures / cross-chain.
- `UNPROTECTED-INIT`, `STORAGE-COLLISION` — not upgradeable; constructor-only init.
- `MISSING-SLIPPAGE` — slippage is handled inside the reflax strategy (OOS root cause); staker forwards
  measured-received amounts.
- `DOS-UNBOUNDED-LOOP` — `batchMigrate` loop already tracked as ledger `59eebbf8` (open Low); unchanged by diff.
- `REWARD-ACCRUAL-ORDER`, `REWARD-RUNWAY-DEPLETION`, `EMISSION-WINDOW-BOUNDARY`, `MINT-ON-DEMAND-OVERMINT`,
  `BATCH-PAYOUT-FIXED-POT` — reward accounting (`_updatePool`/`accPhusdPerShare`) is explicitly UNTOUCHED by
  story-006/007 (diff only touches principal custody). Emission-cap invariant intact. No regression.
- `UNSAFE-DOWNCAST`, `DIVISION-PRECISION`, `INCORRECT-OPERATOR`, `SELFDESTRUCT-FORCE-ETH`, `DOUBLE-VOTING`,
  `TIMELOCK-BYPASS`, `FRONTRUN-APPROVE` — no matching signatures in the changed lines.
- `CENTRALIZATION-ADMIN` — owner-gated config; trusted owner (Law 3). Not reported.

## Ledger cross-reference (regression hygiene)

- **dc361b7d (M-04, acknowledged)** — story-007 `relinquishPrincipal` is its candidate fix. PM-08-001 keeps it
  OPEN-for-reverification: the cap-silent-write-down residual means the desync is narrowed, not proven gone.
  Do NOT auto-flip to fixed. Recommend `/recheck stable-staker dc361b7d` (PoC-replay against f85450b).
- **0dca43f3 (M-05, acknowledged-deferred)** — fix was DEFERRED pending the reflax `relinquishPrincipal`
  story, which has now landed (interface L41). `emergencyWithdraw` (L322-337) still passes
  `guardUnderwater=false` and does NOT call `relinquishPrincipal` (it takes the `strategy.withdraw`
  over-redemption branch L708-710), so the FCFS bufferless socialization is **NOT yet pro-rata**. M-05 stays
  live; the dependency has landed but the staker-side pro-rata fix has not been wired. Flag for human: the
  fixDependency precondition is now satisfied — M-05 is actionable.
- **678e6fa2 (M-02, acknowledged)** — story-006's L203 `require(!active)` guard is its committed fix. Present
  at HEAD. Recommend `/recheck stable-staker 678e6fa2`.
- **69c7666 (wont-fix, _routeExit buffer FCFS)** — buffer-at-par path unchanged in intent; story-007 only adds
  book reconciliation, not a haircut. wont-fix coverage intact. Not re-reported.
