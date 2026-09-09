# Static Analysis - reflax-yield-vault (reflax-yield-vault)

- **Project:** reflax-yield-vault (submodule `lib/reflax-yield-vault`)
- **Scan timestamp:** 2026-05-25
- **Scan type:** static (deterministic SAST)
- **Build:** workspace copy `workspace/reflax-yield-vault`, `forge build` OK (artifacts in `out/`), solc 0.8.x (pragma `^0.8.13`)
- **Tools:** Slither 0.11.3, Aderyn 0.6.8, Semgrep 1.163.0 (`p/smart-contracts`, 50 solidity rules)

## In-scope files
- `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol`
- `src/AMMAdapters/CurveAMMAdapter.sol`
- `src/AMMAdapters/IAMMAdapter.sol`
- `src/AMMAdapters/ICurveRouterNG.sol`

Scope context (not reported, base class): `src/AYieldStrategy.sol`. Everything else (test/, mocks/, Legacy/, other strategies incl. `ERC4626YieldStrategy.sol`) is out-of-scope and filtered.

## Raw finding counts (before scope/noise filter)
| Tool | Raw findings |
|------|--------------|
| Slither | 31 results (96 detectors over 23 contracts) |
| Aderyn | 15 issues (1 high, 14 low) |
| Semgrep | 64 findings (all INFO) |
| **Total raw** | **110** |

## After filtering (scope + C4 noise detectors)
- **Slither:** 13 in-scope results kept (after dropping out-of-scope ERC4626YieldStrategy/AYieldStrategy/mocks/OZ findings; `timestamp`, `missing-zero-check`, `immutable-states` dropped as QA/info).
- **Aderyn:** 1 high is out-of-scope (`AYieldStrategy.sol:263`). In-scope: all 14 low-tier are QA/info (centralization, push0, pragma, literal-vs-constant, naming/shadowing, modifier-order). Listed but none rise above QA.
- **Semgrep:** 0 kept. All 64 are gas/best-practice INFO rules (short revert strings, use-custom-error, prefix increment, Ownable2Step, non-payable constructor). Discarded.

---

## Normalized in-scope findings (deduplicated)

Severity = tool-reported. Confidence raised where corroborated across tools.

### Slither

| # | check | sev | conf | file:line | function | description |
|---|-------|-----|------|-----------|----------|-------------|
| S1 | reentrancy-no-eth | Medium | Medium | ERC4626MarketYieldStrategy.sol:302 | `_withdrawInternal` | External call `ammAdapter.swap()` (line 328) before state write `totalDeposited[token] -= amount` (336). clientBalances also written post-call. State-change-after-external-call pattern. |
| S2 | reentrancy-no-eth | Medium | Medium | ERC4626MarketYieldStrategy.sol:368 | `_totalWithdraw` | External `ammAdapter.swap()` (390) before `clientBalances[...] = 0` / `totalDeposited -= ...` (393-394). |
| S3 | reentrancy-benign | Low | Medium | ERC4626MarketYieldStrategy.sol:267 | `_depositInternal` | External `ammAdapter.swap()` (283) before `clientBalances += amount` / `totalDeposited += amount` (287-288). |
| S4 | reentrancy-benign | Low | Medium | ERC4626MarketYieldStrategy.sol:302 | `_withdrawInternal` | Benign-classified variant of the withdraw reentrancy (duplicate locus of S1). |
| S5 | reentrancy-events | Low | Medium | CurveAMMAdapter.sol:120 | `swap` | `Swapped` event emitted after external `router.exchange()` (138). Event-after-call only. |
| S6 | incorrect-equality | Medium | High | ERC4626MarketYieldStrategy.sol:368 | `_totalWithdraw` | Dangerous strict equality `totalShares == 0 \|\| totalDeposited[token] == 0` (374) used as guard. |
| S7 | incorrect-equality | Medium | High | ERC4626MarketYieldStrategy.sol:462 | `_skimSurplusBatch` | Dangerous strict equality `surplus == 0` (475) used to skip clients. |
| S8 | uninitialized-local | Medium | Medium | CurveAMMAdapter.sol:74 | `setRoute` | `lastToken` local never initialized; relies on loop to set. If `path` were all-zero it stays 0 (guarded by require, but flagged). |
| S9 | uninitialized-local | Medium | Medium | ERC4626MarketYieldStrategy.sol:467 | `_skimSurplusBatch` | `totalShares` local never explicitly initialized (defaults 0; accumulated in loop). |
| S10 | calls-loop | Low | Medium | ERC4626MarketYieldStrategy.sol:462 | `_skimSurplusBatch` | External call `vault.convertToShares()` (476) inside per-client loop — gas/DoS scaling with `clients.length`. |
| S11 | shadowing-local | Low | High | ERC4626MarketYieldStrategy.sol:97 | constructor | Param `_owner` shadows `Ownable._owner`. Corroborated by Aderyn A4. |
| S12 | shadowing-local | Low | High | CurveAMMAdapter.sol:48 | constructor | Param `_owner` shadows `Ownable._owner`. Corroborated by Aderyn A4. |

### Aderyn (in-scope, all QA/info tier)

| # | title | sev | file:line(s) | note |
|---|-------|-----|--------------|------|
| A1 | Centralization Risk | Low | CurveAMMAdapter.sol:20,68; ERC4626MarketYieldStrategy.sol:190,242,254 | onlyOwner `setRoute`, `setSlippageTolerance`, `depositAsOwner`, `withdrawAsOwner`. Expected design (multisig owner). |
| A2 | nonReentrant Not First Modifier | Low | ERC4626MarketYieldStrategy.sol:210,228,242,254 | `nonReentrant` after auth modifiers. Auth/pause checks run before guard — review ordering but generally benign. |
| A3 | Loop Contains require/revert | Low | ERC4626MarketYieldStrategy.sol:468 | `require(client != address(0))` inside `_skimSurplusBatch` loop — one zero address reverts whole batch. |
| A4 | Local Var Shadows State Var | Low | CurveAMMAdapter.sol:48; ERC4626MarketYieldStrategy.sol:97 | Dup of S11/S12. |
| A5 | Public Function Not Used Internally | Low | CurveAMMAdapter.sol:115 | `isPairFullyConfigured` public but unused internally. QA. |
| A6 | Large Numeric Literal | Low | ERC4626MarketYieldStrategy.sol:43 | `MAX_BPS = 10000`. QA. |
| A7 | Literal Instead of Constant | Low | CurveAMMAdapter.sol:65-103; ICurveRouterNG.sol:29-32 | Magic array sizes (11, 5). QA. |
| A8 | Unspecific Pragma / PUSH0 / push0 | Low | all in-scope files :2 | `^0.8.13` floating pragma; PUSH0 opcode targeting. QA. |

Out-of-scope Aderyn high (NOT reported): `abi.encodePacked()` hash collision at `src/AYieldStrategy.sol:263` (base class, scope context only).

### Semgrep
0 kept. 64 raw findings, all INFO gas/best-practice (use-custom-error-not-require x28, use-short-revert-string x28, prefix-increment x2, unnecessary-checked-arithmetic-in-loop x2, non-payable-constructor x2, state-variable-read-in-a-loop x1, use-ownable2step x1). All discarded per C4 noise policy.

---

## Notable in-scope items worth manual review

1. **Reentrancy on the AMM-swap boundary (S1, S2, S3).** `_withdrawInternal`, `_totalWithdraw`, and `_depositInternal` all perform `ammAdapter.swap()` (which calls external Curve Router) BEFORE updating `clientBalances`/`totalDeposited`. The external `deposit`/`withdraw`/`depositAsOwner`/`withdrawAsOwner` entrypoints carry `nonReentrant` from AYieldStrategy, so cross-function reentrancy is the question: confirm every state-mutating entrypoint is guarded and that the swap target (Curve Router NG) / vault-share token cannot trigger a callback into an unguarded path. Note A2: `nonReentrant` is not the first modifier — verify the guard still covers the swap.

2. **`_skimSurplusBatch` external call in loop (S10) + revert in loop (A3).** Per-client `vault.convertToShares()` inside the loop scales gas with `clients.length` and the `require(client != address(0))` reverts the entire batch on a single bad entry. Caller controls `clients[]` — assess griefing / unbounded-array DoS.

3. **Strict-equality guards (S6, S7).** `totalShares == 0 || totalDeposited == 0` and `surplus == 0` short-circuit core flows. Generally fine for these counters, but confirm no path makes `totalDeposited` and on-hand shares disagree (the strategy decrements principal by REQUESTED not RECEIVED amount, so share balance and `totalDeposited` can diverge over time — worth tracing whether an attacker can drive `totalShares` to 0 while `totalDeposited > 0`, or vice-versa, to skip/abuse a branch).

4. **`uninitialized-local` (S8, S9)** are low-risk here (loop-populated, guarded), but S8 in `setRoute` is worth a glance: if a route's `path` had all-zero entries after slot 0, `lastToken` stays 0 and the `lastToken == tokenOut` require would catch it — confirm the require fully covers the partial-zero-path case.

5. **Manual-review depth, not tool-flagged:** the reentrancy/incorrect-equality flags point at the principal-vs-received accounting (decrement by requested amount, shortfall to protocol) and the AMM minOut/slippage math (`idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS`). These are the right loci for the code-scanner/econ-scanner to probe for value leak — outside this agent's deterministic remit.

## Tool notes
- All three tools installed and ran cleanly (exit 0). No `missingTools`.
- Slither analyzed the whole project (23 contracts); out-of-scope results filtered post-hoc.
- Aderyn compiled with solc 0.8.30 (its own resolution); Slither/forge used 0.8.28. No compile failures.
