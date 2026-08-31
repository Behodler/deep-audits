# Static Analysis — stable-staker (run 12)

- **Project:** stable-staker
- **Scan type:** static (deterministic SAST), regression-scoped
- **Submodule HEAD:** ffa494783f585bcd2ce1ff60dd756345717287f1 (`[story-012] Add InPlaceMigrator`)
- **Compiled from:** writable workspace `/home/justin/code/audits/workspace/stable-staker` synced to ffa4947 (lib/ untouched, read-only)
- **Focus file:** `src/InPlaceMigrator.sol` (316 LOC, sole in-scope change this run)
- **Context files in scope:** `src/StableStaker.sol`, `src/StableStakerMigrator.sol`
- **solc:** 0.8.28
- **Scan timestamp:** 2026-06-15
- **Tools:** Slither 0.11.x, Aderyn (latest), Semgrep 1.x (`p/smart-contracts`)

## Compilation note

The default `forge build` fails because five out-of-scope files in `test/` reference a removed
3-field `migrationInfo` tuple and a stale `IYieldStrategy` mock interface (pre-story-009 scratch).
These are NOT in scope. To get a clean compile of the three in-scope `src/` contracts, the `test/`
directory was temporarily relocated in the disposable workspace during the Slither foundry-compile,
then restored. `src/` compiles cleanly (exit 0, all three artifacts produced). lib/ was never
touched. Slither analyzed 23 contracts / 96 detectors; Aderyn compiled 4 files / 88 detectors;
Semgrep scanned 4 files / 50 rules.

## Raw → kept

| Tool | Raw | Filtered (noise) | Kept |
|------|-----|------------------|------|
| Slither | 49 | 38 | 11 |
| Aderyn  | 51 | 45 | 6  |
| Semgrep | 89 | 89 | 0  |
| **Total** | **189** | **172** | **17** (deduped to **9** normalized) |

### Filtered as noise (per three-law hierarchy; timestamp findings KEPT per the time-driven-protocol rule)

- **All Semgrep findings (89):** every result is INFO-severity gas/style
  (`use-short-revert-string`, `use-prefix-increment-not-postfix`, `use-custom-error-not-require`,
  `use-nested-if`, `use-multiple-require`, `array-length-outside-loop`,
  `state-variable-read-in-a-loop`, `non-payable-constructor`,
  `unnecessary-checked-arithmetic-in-loop`). No WARNING/ERROR rule fired. `use-ownable2step`
  (single-step ownership) is a deliberate, consistent suite-wide design choice → QA at best, dropped.
- **OpenZeppelin `Math.sol` (OOS external lib v5.6.1):** Slither `incorrect-exp` (1, High),
  `divide-before-multiply` (9, Medium), `too-many-digits` (1). All are the documented
  Newton's-method `mulDiv`/`invMod` internals — well-known false positives, root cause out of scope.
- **`missing-inheritance`** (StableStaker should inherit IStableStaker): informational, intentional.
- **EnumerableSet `unused-return`** on `.add()`/`.remove()` (Slither `unused-return`, Aderyn
  `Unchecked Return`): the discarded bool is the membership-changed flag; ignoring it is the
  standard idiom and harmless here (set membership is the source of truth, re-add/re-remove is
  idempotent). Dropped as noise, EXCEPT see F-09 note (kept once for visibility on migrateOut/in).
- **`uninitialized-local`** on `total`/`count` accumulators (InPlaceMigrator:148/149/194/206,
  StableStakerMigrator:75): Solidity zero-initializes these; they are pure summation counters.
  Benign false positive, dropped.
- **Aderyn `PUSH0 Opcode`, `Unspecific Solidity Pragma`, `Modifier Invoked Only Once`,
  `Centralization Risk` (16):** QA/informational; centralization is owner-trust (Law 3, suppress
  obvious-owner items). Dropped.

---

## Normalized findings

> Confidence reflects tool agreement + manual code read. None of these are auto-promoted to a real
> vulnerability by the static pass; they are leads for the code-scanner / econ-scanner. The
> reentrancy items in `InPlaceMigrator` are explicitly CEI-structured under `nonReentrant` in the
> source (verified by read) — kept at LOW with that caveat, NOT as the High the raw tools assign.

### SA-001 — Reentrancy: state written after external call in `migrateIn` loop
- **id:** SLITHER-001 / corroborated ADERYN-H
- **source:** slither (`reentrancy-no-eth`, Medium/Medium), aderyn (`Reentrancy: State change after external call`, High)
- **severity:** potential-low (tools say High/Medium; downgraded on read — see note)
- **contract:** `src/InPlaceMigrator.sol`
- **function:** `migrateIn(address,uint256,uint256)`
- **line:** 215–223 (call at 223)
- **rawCheck:** reentrancy-no-eth
- **confidence:** low (CEI verified)
- **description:** Slither/Aderyn flag that `staker.depositFor(token,user,amt)` at L223 is an
  external call after which per-iteration state for the *next* user could be written; the
  cross-function reentrancy surfaces `parked`/`migrationBegin`/`totalParked` (readable by
  `claimableAt`, `rescueERC20`). **Manual read:** each user's `parked`/`migrationBegin`/`totalParked`
  is zeroed/decremented BEFORE that user's `depositFor` (strict CEI, L215–217 precede L223), the
  function is `onlyOwner nonReentrant`, and the re-injection target is the immutable trusted
  `staker`. Real reentrancy requires a malicious staker, which contradicts the immutable-trusted-target
  design. Lead retained for the code-scanner to confirm no value can be double-credited across a
  reverting/partial `depositFor` mid-batch.

### SA-002 — `depositFor` external call inside `migrateIn` loop (batch-DoS surface)
- **id:** SLITHER-002
- **source:** slither (`calls-loop`, Low/Medium)
- **severity:** potential-low
- **contract:** `src/InPlaceMigrator.sol`
- **function:** `migrateIn(address,uint256,uint256)`
- **line:** 223
- **rawCheck:** calls-loop
- **confidence:** medium
- **description:** `staker.depositFor` is invoked once per user inside the slice loop. If any single
  user's `depositFor` reverts (e.g. that user's pool state, a paused new pool, or a token-side
  callback), the entire `migrateIn` slice reverts and no user in the slice is re-injected. The
  `claimTimedOut` hatch mitigates permanent loss, but a poison user can DoS an operator batch until
  excluded. Worth a code-scanner look at whether `depositFor` can be made to revert for one user
  without affecting others. Time/availability relevance per Law 1 — kept.

### SA-003 — Reentrancy (benign): state written after `batchMigrate` in `migrateOut`
- **id:** SLITHER-003 / corroborated ADERYN-H
- **source:** slither (`reentrancy-benign`, Low/Medium), aderyn (`Reentrancy`, High @ L146)
- **severity:** potential-low
- **contract:** `src/InPlaceMigrator.sol`
- **function:** `migrateOut(address,address[])`
- **line:** 146 (call), 153–156 (writes)
- **rawCheck:** reentrancy-benign
- **confidence:** low (benign)
- **description:** `parked`/`migrationBegin`/`totalParked`/`_parkedUsers` are written after
  `staker.batchMigrate` (L146). `onlyOwner nonReentrant` + immutable trusted `staker`. The writes
  fold in the just-returned `amounts`, so reentrancy cannot inflate them. Benign; recorded for
  completeness because Aderyn rates it High.

### SA-004 — Timestamp dependence in `claimTimedOut` escape hatch
- **id:** SLITHER-004
- **source:** slither (`timestamp`, Low/Medium)
- **severity:** potential-low
- **contract:** `src/InPlaceMigrator.sol`
- **function:** `claimTimedOut(address)`
- **line:** 242–245
- **rawCheck:** timestamp
- **confidence:** medium
- **description:** `block.timestamp >= migrationBegin[token][msg.sender] + migrationTimeout` gates
  the permissionless principal-reclaim hatch. **KEPT (not dropped)** per the time-driven-protocol
  rule: the hatch window is load-bearing — too short lets a user front-run the operator's
  `migrateIn` and double-exit logic; too long neuters the safety hatch. Constructor bounds the
  timeout (`MIN_TIMEOUT`/`MAX_TIMEOUT`, L114), which mitigates. Lead for econ-scanner: can a user
  reclaim via `claimTimedOut` AND still be re-injected by a concurrently-submitted `migrateIn`
  slice? (migrateIn zeroes `parked` first and skips `parked==0`, so likely safe — confirm ordering
  under mempool races.)

### SA-005 — `nonReentrant` is not the first modifier on `migrateOut` / `migrateIn`
- **id:** ADERYN-001
- **source:** aderyn (`nonReentrant is Not the First Modifier`, Low)
- **severity:** potential-low
- **contract:** `src/InPlaceMigrator.sol`
- **function:** `migrateOut` (L145), `migrateIn` (L183)
- **line:** 145, 183
- **rawCheck:** nonReentrant-not-first
- **confidence:** low
- **description:** Both functions declare `onlyOwner nonReentrant` (guard runs after `onlyOwner`).
  Harmless here because `onlyOwner` (Ownable) performs no external call, so no reentrancy window
  opens before the guard engages. Style/best-practice note only.

### SA-006 — Costly storage operations inside loop (`migrateOut` / `migrateIn`)
- **id:** ADERYN-002
- **source:** aderyn (`Costly operations inside loop`, Low)
- **severity:** potential-low
- **contract:** `src/InPlaceMigrator.sol`
- **function:** `migrateOut` / `migrateIn`
- **line:** ~153–156 / ~215–217
- **rawCheck:** costly-loop
- **confidence:** low
- **description:** Per-iteration storage writes (`parked`, `totalParked`, set add/remove) inside the
  batch loops. Gas/availability concern: very large batches may exceed the block gas limit and force
  smaller slices — relevant to operational batch-sizing, not a vulnerability. Operator already builds
  batches off-chain. Informational.

### SA-007 — Reentrancy in `StableStaker.setYieldStrategy` (context contract)
- **id:** SLITHER-005
- **source:** slither (`reentrancy-no-eth` / `reentrancy-events`, Medium/Low)
- **severity:** potential-low
- **contract:** `src/StableStaker.sol`
- **function:** `setYieldStrategy(address,IYieldStrategy)`
- **line:** 219–271 (calls at 249/266/786/792, event at 270)
- **rawCheck:** reentrancy-no-eth / unused-return (strategy.deposit @266)
- **confidence:** low
- **description:** `_routeExit` (`strategy.relinquishPrincipal`@786 / `strategy.withdraw`@792) then
  `strategy.deposit`@266, with `YieldStrategySet` emitted after. Pre-existing context code, not part
  of the story-012 change, and gated by `totalStaked == 0` (empty-pool-only, per CLAUDE.md +
  ledger). `StableStaker.sol:786` (`relinquishPrincipal`) is the line flagged in memory as the live
  F-03 integration gate — surfaced here so the regression scanner re-evaluates it, but no NEW issue
  introduced by InPlaceMigrator. `strategy.deposit` return ignored (`unused-return`) is the
  documented "forward actual received, account requested" rounding rule. Lead only.

### SA-008 — Reentrancy in `StableStakerMigrator.migrate` (context contract)
- **id:** SLITHER-006
- **source:** slither (`reentrancy-events`, Low/Medium)
- **severity:** potential-low
- **contract:** `src/StableStakerMigrator.sol`
- **function:** `migrate(address,address[])`
- **line:** 61–84 (calls at 62/78, events after)
- **rawCheck:** reentrancy-events
- **confidence:** low
- **description:** `Migrated` event emitted after `oldStaker.batchMigrate` / `newStaker.depositFor`.
  Both stakers are trusted/configured. Pre-existing context code, event-ordering only. Recorded for
  completeness; no action expected.

### SA-009 — Missing zero-address checks on setters (context)
- **id:** SLITHER-007 / ADERYN-003
- **source:** slither (`missing-zero-check`, Low), aderyn (`Address State Variable Set Without Checks`)
- **severity:** potential-low
- **contract:** `src/StableStaker.sol` (2 instances)
- **function:** owner setters (e.g. pauser/migrator wiring)
- **rawCheck:** missing-zero-check
- **confidence:** low
- **description:** Owner-set address state variables without `!= address(0)` guards. Owner-trust
  (Law 3): setting these to zero is an obvious misconfig, not a non-obvious footgun → low/QA.
  InPlaceMigrator's own constructor DOES guard the staker address (L111) and timeout bounds
  (L114). Recorded as QA.

---

## Cross-tool corroboration summary

- **InPlaceMigrator reentrancy (migrateIn @223, migrateOut @146):** Slither + Aderyn agree on
  location; both raise it (Slither Medium/Low, Aderyn High). Manual read confirms strict CEI under
  `nonReentrant` with an immutable trusted target → downgraded to LOW leads, NOT High. This is the
  single most-corroborated cluster and the right thing for the code-scanner to disprove definitively.
- Everything Slither rated High (`incorrect-exp`) and most of its Medium (`divide-before-multiply`)
  live in OZ `Math.sol` and are out-of-scope false positives.
- Semgrep contributed zero security-relevant findings (all 89 are gas/style INFO).

## Handoff

The 9 normalized findings are leads, not confirmed vulnerabilities. Priority for downstream agents:
1. **SA-002 (calls-loop / batch-DoS)** and **SA-004 (timeout-window race)** are the most
   security-interesting InPlaceMigrator-native leads — hand to code-scanner + econ-scanner.
2. **SA-001/003** reentrancy cluster: code-scanner to formally confirm CEI holds across a
   partial/reverting `depositFor` mid-batch.
3. **SA-007** re-surfaces StableStaker.sol:786 — feeds the pending F-03 Medium re-eval noted in the
   reflax/stable-staker ledger memory; not a new story-012 issue.
