# Static Analysis — stable-staker

- **Project:** stable-staker
- **Submodule commit:** f524cc3
- **Scan type:** static (deterministic SAST)
- **Scan timestamp:** 2026-06-01
- **In-scope contracts:** `src/StableStaker.sol`, `src/StableStakerMigrator.sol`
- **solc:** 0.8.28 (via foundry)
- **Run dir for tools:** `workspace/stable-staker` (writable clone at the same commit as `lib/`; paths map 1:1 to the in-scope filenames). `lib/` left untouched (read-only).

## Tools

| Tool | Version | Status |
|------|---------|--------|
| Slither | 0.11.x | ran (22 contracts, 96 detectors, 32 raw results) |
| Aderyn | 0.x (Cyfrin) | ran (88 detectors, 1 high + 8 low) |
| Semgrep | 1.x (`p/smart-contracts`, 50 rules) | ran (40 findings, all INFO gas/style — discarded) |

No tool failed to run. No `missingTools`.

## Filtering notes

- Restricted to findings whose source location touches `src/StableStaker.sol` or `src/StableStakerMigrator.sol`. OZ/forge-std/dependency-internal findings discarded.
- Dropped C4 QA-only / invalid detectors: `solc-version`, `pragma`/`unspecific-solidity-pragma`, `push-zero-opcode`, `too-many-digits`, `missing-inheritance`, `modifier-used-only-once`, `state-no-address-check` (dup of missing-zero-check), and all Semgrep `INFO` performance/style rules (`use-custom-error-not-require`, `use-ownable2step`, `use-prefix-increment-not-postfix`, `unnecessary-checked-arithmetic-in-loop`, `non-payable-constructor`, `state-variable-read-in-a-loop`, `array-length-outside-loop`, `use-nested-if`, `use-short-revert-string`, `non-payable-constructor`).
- `centralization-risk` (Aderyn, 9 instances) retained as informational context only — it matches the project's documented owner-trust design decisions (addToken/phUSDPerDay/setMigrator/setPauser/setYieldStrategy are intentionally onlyOwner). Listed but not promoted.
- Semgrep contributed **no** security-relevant findings on the in-scope files; every hit was gas/style INFO.

## Detector coverage on the requested categories

| Category | Fired? | Detail |
|----------|--------|--------|
| Reentrancy | YES | Slither `reentrancy-no-eth` x3 (`stake`, `depositFor`, `migrateOut`), `reentrancy-events` x3; Aderyn `reentrancy-state-change` HIGH on `migrateOut` (line 327). Corroborated across both tools. |
| Arbitrary-call / arbitrary-send | NO | No `arbitrary-send-eth/-erc20`, `controlled-delegatecall`, `tx-origin`, `suicidal`. No untrusted external-call-with-attacker-controlled-target detector fired. |
| Access control | NO direct detector | No `unprotected-upgrade`/`suicidal`. Aderyn `centralization-risk` flags owner power (by design). No missing-modifier finding. |
| Arithmetic | NO | No `divide-before-multiply`, `incorrect-equality`, `weak-prng`. `unchecked` arithmetic-in-loop is Semgrep gas INFO only. |
| Uninitialized state | PARTIAL | No `uninitialized-state`/`-storage`. `uninitialized-local` x3 fired (loop accumulators defaulting to 0 — benign, see below). |

---

## Findings (normalized)

### Potential-Medium

#### M-static-1 — Reentrancy (state change after external call): `migrateOut`
- **tool:** slither + aderyn (corroborated) — confidence raised
- **detector:** `reentrancy-no-eth` (Slither, Medium) / `reentrancy-state-change` (Aderyn, **High**)
- **severity:** potential-medium
- **contract:** `src/StableStaker.sol`
- **function:** `migrateOut`
- **line:** 327 (external call `phUSD.mint(u, pending)`); state writes `info.amount=0` (320), `info.rewardDebt=0` (321), `pool.totalStaked -= amt` (322) — Aderyn flags the post-call state change at/after 327
- **description:** Inside the per-user loop, `phUSD.mint(u, pending)` is an external call, after which pool/user accounting (`info.amount`, `info.rewardDebt`, `pool.totalStaked`) is mutated. Classic state-change-after-external-call. Exploitability depends on whether `phUSD` (FlaxToken) or the mint target can re-enter `StableStaker`; `migrateOut` is migrator-permissioned, which constrains the attack surface.

#### M-static-2 — Reentrancy (no-eth): `stake`
- **tool:** slither
- **detector:** `reentrancy-no-eth` (Medium / Medium)
- **severity:** potential-medium
- **contract:** `src/StableStaker.sol`
- **function:** `stake`
- **line:** 221 (fn); external calls `_settle → phUSD.mint` (226/451), `_routeDeposit → strategy.deposit` (229/475); state writes `user.amount`/`pool.totalStaked`/`user.rewardDebt` (230-232) and `_stakers[token].add` (233) after the calls
- **description:** `stake` performs external calls (reward mint via `_settle`, principal routing via `strategy.deposit`) before finalizing user/pool accounting. A malicious yield strategy or a re-entrant phUSD could re-enter. Strategy is owner-configured (trusted by design); the primary residual concern is the external `phUSD.mint`.

#### M-static-3 — Reentrancy (no-eth): `depositFor`
- **tool:** slither
- **detector:** `reentrancy-no-eth` (Medium / Medium)
- **severity:** potential-medium
- **contract:** `src/StableStaker.sol`
- **function:** `depositFor`
- **line:** 344 (fn); external calls `_settle → phUSD.mint` (354/451), `_routeDeposit → strategy.deposit` (357/475); state writes `info.amount`/`pool.totalStaked`/`info.rewardDebt` (358-360), `_stakers[token].add` (361) after
- **description:** Same pattern as `stake`, on the migrator-permissioned `depositFor` path. External calls precede accounting writes.

#### M-static-4 — Unused return: `EnumerableSet.add/remove` ignored
- **tool:** slither
- **detector:** `unused-return` (Medium / Medium)
- **severity:** potential-low (downgraded — informational impact; set membership is functionally idempotent here)
- **contract:** `src/StableStaker.sol`
- **functions / lines:** `stake` add@233; `depositFor` add@361; `withdraw` remove@250; `emergencyWithdraw` remove@287; `migrateOut` remove@323
- **description:** Return value of `_stakers[token].add(...)` / `.remove(...)` discarded. Generally benign for `EnumerableSet` (return only signals whether membership changed); flagged for completeness, low real impact.

### Potential-Low

#### L-static-1 — Reentrancy events emitted after external call
- **tool:** slither
- **detector:** `reentrancy-events` (Low / Medium)
- **severity:** potential-low
- **contracts/functions/lines:**
  - `src/StableStaker.sol` `setYieldStrategy` @181 — `YieldStrategySet` emitted after `strategy.deposit` (198)
  - `src/StableStakerMigrator.sol` `migrate` @45 — `Migrated` emitted after `oldStaker.migrateOut` (46) and `newStaker.depositFor` (62)
- **description:** Events emitted after external calls; can yield misleading off-chain event ordering under re-entrancy. Low impact.

#### L-static-2 — External call inside loop (calls-loop / costly-loop)
- **tool:** slither + aderyn (corroborated)
- **detector:** `calls-loop` (Slither, Low) / `costly-loop` (Aderyn, Low)
- **severity:** potential-low
- **contracts/functions/lines:**
  - `src/StableStaker.sol` `migrateOut` — `phUSD.mint(u, pending)` in loop @327 (Aderyn costly-loop @312)
  - `src/StableStakerMigrator.sol` `migrate` — `newStaker.depositFor(...)` in loop @62
- **description:** External calls executed per loop iteration over a user array. DoS / gas-griefing surface if the array is large or a callee reverts/consumes gas. Both functions are migrator-permissioned (batch size operator-controlled), limiting severity.

#### L-static-3 — Missing zero-address check on setters
- **tool:** slither + aderyn (corroborated)
- **detector:** `missing-zero-check` (Slither) / `state-no-address-check` (Aderyn) — both Low
- **severity:** potential-low
- **contract:** `src/StableStaker.sol`
- **functions/lines:** `setMigrator(_migrator)` write @159 (param @158); `setPauser(_pauser)` write @166 (param @164)
- **description:** `migrator` and `pauser` set without a zero-address guard. onlyOwner setters — admin-mistake class (QA at best per project conventions).

#### L-static-4 — Uninitialized local accumulators
- **tool:** slither + aderyn (corroborated)
- **detector:** `uninitialized-local` (Slither) / `uninitialized-local-variable` (Aderyn) — both Medium impact, low real risk
- **severity:** potential-low
- **contracts/functions/lines:**
  - `src/StableStaker.sol` `migrateOut` — `totalPrincipal` @311
  - `src/StableStakerMigrator.sol` `migrate` — `total` @48, `migratedCount` @59 (Aderyn flags @59)
- **description:** Loop accumulators declared without explicit initialization. They default to `0` and are written before read, so behaviour is correct; flagged as a style/clarity nit, not a bug.

### Informational (context, not promoted)

- **Centralization risk** (Aderyn `centralization-risk`, 8 in-scope instances): owner-gated functions on `StableStaker` (lines 41, 138, 150, 158, 164, 181, 521) and `StableStakerMigrator` (22, 45). Matches documented owner-trust design decisions (addToken / phUSDPerDay / setMigrator / setPauser / setYieldStrategy / migrator role). Not a finding.

---

## Summary of detector hits on in-scope files

| Detector | Tool(s) | Impact | In-scope hits |
|----------|---------|--------|---------------|
| reentrancy-no-eth | slither | Medium | 3 (`stake`, `depositFor`, `migrateOut`) |
| reentrancy-state-change | aderyn | High | 1 (`migrateOut`) — corroborates above |
| reentrancy-events | slither | Low | 3 (`setYieldStrategy`, `migrate` x2) |
| unused-return | slither | Medium | 5 |
| uninitialized-local | slither + aderyn | Medium | 3 |
| calls-loop / costly-loop | slither + aderyn | Low | 2 + 1 |
| missing-zero-check / state-no-address-check | slither + aderyn | Low | 2 + 2 |
| centralization-risk | aderyn | Low/Info | 8 (by design) |
| (Semgrep security) | semgrep | — | 0 (only INFO gas/style) |

Raw tool outputs: `slither-output.json`, `aderyn-report.json`, `semgrep-output.json` in this directory.
