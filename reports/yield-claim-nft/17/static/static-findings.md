# Static Analysis — yield-claim-nft (run-17)

- **Project:** yield-claim-nft
- **Submodule HEAD:** `8dd8963` (story-044)
- **scanType:** static (deterministic SAST)
- **Primary target:** `src/dispatchers/PromotionUniV2_Eth.sol` (NEW, 401 LOC)
- **Also in changed set:** `src/interfaces/uniswap/IUniswapV2Router02.sol` (modified — pure interface, no logic)
- **solc:** 0.8.20 (pragma `^0.8.20`); forge build OK
- **Tools:** Slither 0.11.3 (ran, 63 contracts / 96 detectors / 58 results), Aderyn 0.6.8 (ran, 88 detectors / solc 0.8.30), Semgrep 1.163.0 (`p/smart-contracts`, ran, 50 rules / 173 findings)
- **missingTools:** none. 4naly3er deferred (QA phase; remappings-staging gotcha not exercised this run).

## Tooling caveats (heeded from prior runs)
1. Slither run WITHOUT `--filter-paths "lib/"` — that filter would have dropped every first-party file (all abs paths contain `.../audits/lib/yield-claim-nft/...`). Confirmed first-party results present (false-clean avoided).
2. **Semgrep `p/smart-contracts` here contains ONLY gas/style/optimization rules** (`use-custom-error-not-require`, `use-short-revert-string`, `non-payable-constructor`, `use-ownable2step`, `inefficient-state-variable-increment`, `use-prefix-increment-not-postfix`, `use-nested-if`, `use-abi-encodecall-instead-of-encodewithselector`, `unnecessary-checked-arithmetic-in-loop`). **NO Solidity security detectors fired — a clean/noise-only Semgrep result is NOT evidence of all-clear.** All 173 Semgrep findings are non-security and filtered.
3. Reentrancy detectors did **not** fire on the new dispatcher: `pool()` carries `nonReentrant` and `unlockCallback` is gated by `require(msg.sender == BALANCER_VAULT)`. Absence of a tool hit here is expected, not a proof of safety — flagged the modifier-ordering hardening note below for the manual reviewer.

---

## KEPT — normalized, security-adjacent findings (target: PromotionUniV2_Eth.sol)

All are `potential-low` (no tool produced a High/Medium *exploit* path on the target; the Slither "Medium" impacts are the `unused-return` class, mitigated on-chain by explicit min-out floors — see rationale). Kept for downstream dedup/severity, not dropped.

### STATIC-001 — Unchecked router return values on the ETH swap path (Leg B)
- **source:** slither (`unused-return`, Medium/Medium) + aderyn (`Unchecked Return`) — CORROBORATED
- **contract:function:** `PromotionUniV2_Eth._legB`
- **line:** 337 (`swapExactTokensForETH`), 343-345 (`swapExactETHForTokens`)
- **category:** unchecked-return / slippage-path
- **severity hint:** potential-low
- **rationale:** Return `amounts[]` of both UniV2 swaps are ignored; Leg B instead reads `address(this).balance` between the two swaps. Value-loss is bounded by the explicit `minEthOut`/`minPromoOut` floors, so this is not a direct loss — but the ignored return is the exact swap+pool path flagged for review; keep for confirmation that the min-out floors are the sole slippage guard.

### STATIC-002 — Swap/pool deadline is `block.timestamp` (no deadline protection)
- **source:** aderyn (`Using block.timestamp for swap deadline offers no protection`) + slither (`timestamp`, Low/Medium) — CORROBORATED
- **contract:function:** `PromotionUniV2_Eth._legB` / `PromotionUniV2_Eth.pool`
- **line:** 300 (`addLiquidity`), 337 (`swapExactTokensForETH`), 343-345 (`swapExactETHForTokens`)
- **category:** deadline-handling / MEV
- **severity hint:** potential-low
- **rationale:** Every router call passes `block.timestamp` as the deadline, which is always "now" and therefore provides no protection against a validator/relayer holding the tx to a more adverse block. Time-driven suite → timestamp findings retained per suite policy. Residual MEV risk is bounded by `minEthOut/minPromoOut/minPhusdOut/minLP`; let severity-classifier weigh whether the floors fully subsume it (the pooler is authorized-only, which further caps exposure).

### STATIC-003 — `nonReentrant` is not the first modifier on `pool()`
- **source:** aderyn (`nonReentrant is Not the First Modifier`)
- **contract:function:** `PromotionUniV2_Eth.pool`
- **line:** 277-282 (modifier order: `onlyAuthorizedPooler`, `whenNotPaused`, `nonReentrant`)
- **category:** reentrancy-hardening
- **severity hint:** potential-low
- **rationale:** Reentrancy-guard best practice places `nonReentrant` first so the lock wraps all preceding modifier logic. Here the preceding modifiers only read state (no external calls), so practical risk is minimal — but this is squarely in the "reentrancy around external router calls" focus area, so surfaced rather than dropped.

### STATIC-004 — Unchecked Balancer V3 `settle` return in `unlockCallback`
- **source:** slither (`unused-return`, Medium/Medium)
- **contract:function:** `PromotionUniV2_Eth.unlockCallback`
- **line:** 376 (`settle`), 375 (`swap` — first two return values ignored, `amountOut` captured)
- **category:** unchecked-return / vault-settlement
- **severity hint:** potential-low
- **rationale:** `IBalancerVault.settle` return (the settled credit) is ignored. Amounts are exact-in and the callback pays-then-settles the same `sharesIn`, so a mismatch would surface as a vault revert rather than silent loss; kept so the reviewer confirms the settle amount can never diverge from `sharesIn`.

### STATIC-005 — `addLiquidity` return: `amountA`/`amountB` ignored (residual dust)
- **source:** slither (`unused-return`, Medium/Medium)
- **contract:function:** `PromotionUniV2_Eth.pool`
- **line:** 299-301
- **category:** unchecked-return / dust-accounting
- **severity hint:** potential-low
- **rationale:** Only `liquidity` is captured; the actually-consumed `amountA`/`amountB` are dropped. The router refunds the excess side and the code documents "residual dust accrues on the dispatcher for the next pool()", so this is by-design and recoverable via `rescueERC20`. Low; retained only to corroborate the documented dust behavior.

---

## Value-handling paths reviewed CLEAN by tools (no finding, noted for completeness)
- `rescueETH` (L393-397): Slither `low-level-calls` (Informational). Uses `to.call{value:amount}("")` **with** success-check (`require(ok,...)`) and zero-recipient check, `onlyOwner`. Correct native-ETH pattern — not a defect.
- `receive() external payable {}` (L400): required to accept the `swapExactTokensForETH` unwrap in Leg B. No logic; no finding.
- `unlockCallback` (L361-379): vault-only gate present (`require(msg.sender == BALANCER_VAULT)`); no reentrancy detector fired.

---

## FILTERED — dropped as noise (with reason)

| Item | Source | Line(s) | Reason dropped |
|---|---|---|---|
| `use-custom-error-not-require` ×18, `use-short-revert-string` ×13, `non-payable-constructor`, `inefficient-state-variable-increment`, `use-abi-encodecall-instead-of-encodewithselector` (all Semgrep, target) | semgrep | various | Pure gas/style optimization; no security impact. (Whole project: 173 such findings, all filtered.) |
| Centralization Risk ×11 | aderyn | 173,192,201,208,215,223,229,241,387,393 | Owner-trusted (Law 3); owner-only setters/escape-hatches are not reportable. |
| `missing-zero-check` on `setBatchMinter` / `Address State Variable Set Without Checks` | slither (Low) + aderyn | 223-224 | By-design: `address(0)` intentionally disables the donation (documented at L94-95, L221-222). |
| `unused-state` WAD | slither (Info) + aderyn | 63 | QA-only dead constant; no security impact. |
| `Unused Import` (L8), `Unspecific Solidity Pragma`, `PUSH0 Opcode`, `Literal Instead of Constant`, `Modifier Invoked Only Once` | aderyn (Low) | 2,8,216,257,125 | QA/style; in the CLAUDE.md noise denylist. |
| `timestamp` "dangerous comparison" on `liquidity >= minLP` | slither (Low) | 302 | Spurious: the flagged comparison is `minLP`, not a time comparison (block.timestamp appears only in the same call's deadline arg — captured under STATIC-002). |
| `too-many-digits` ×6 | slither | OZ `Bytes.sol`/`Math.sol` | Third-party `lib/immutable/` (OZ); root cause OOS. |

## Non-target first-party findings (NOT in the changed set — context only, not this run's focus)
Slither flagged pre-existing contracts also present in the project (out of the story-044 changed set): `BalancerPoolerV2` (`divide-before-multiply` @L240-264, `incorrect-equality` in `getIdealBPT` @L318-332, `reentrancy-events`), `MultiPooler` (`calls-loop` @L64, `reentrancy-events`), `NFTMinterV2` (`reentrancy-events` — ERC1155 receiver hooks). These are unchanged by story-044; carried here only so they are not mistaken for new. Route to a full-scope scan if a cold audit is desired.

---
## Raw tool outputs
- `slither-output.json`
- `aderyn-report.json`
- `semgrep-output.json`
