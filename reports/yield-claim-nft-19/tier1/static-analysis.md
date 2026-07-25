# Tier-1 Static Analysis — yield-claim-nft (run 19)

- **Target:** `/home/justin/code/audits/workspace/yield-claim-nft` @ `d4cc563` ([story-047] Route BalancerPoolerV2's PSM donation through INudgeStreamer)
- **Scope:** first-party `src/**` only. Excluded: project's own `lib/**` (openzeppelin, forge-std, pauser, phoenix-nft-staking), `test/**`, `script/**`.
- **`lib/` never touched** — all execution against the writable workspace clone.
- **Scan date:** 2026-07-25
- **Machine-readable:** `static-analysis.json` (alongside this file)

## Per-tool run status

| Tool | Version | Status | Raw | Notes |
|---|---|---|---|---|
| Slither | 0.11.3 | OK | 40 | 65 contracts, 96 detectors. Exit 255 = findings present, not failure. |
| Aderyn | 0.6.8 | OK | 17 (2 high + 15 low classes) | 34 first-party files ingested, 88 detectors. Run from project root so `foundry.toml` remappings resolved. |
| Semgrep | installed | OK but **low signal** | 197 | `p/smart-contracts`, 50 rules, 34 files. **Zero security findings.** |

No tools missing.

### Slither filter sanity check (the previously-burned failure mode)

`--filter-paths "lib/"` was **not** used. The anchored filter `yield-claim-nft/lib/|/test/|/script/` was used instead, and the result set was verified non-empty on first-party code:

> Slither reported on `src/dispatchers/BalancerPoolerV2.sol`, `Uniboost.sol`, `PromotionUniV2_Eth.sol`, `NudgeRatchet.sol`, plus `src/NFTMinterV2.sol` and `src/MultiPooler.sol`.

First-party results are present, so the false-clean 0-finding outcome did **not** occur.

### Semgrep coverage gap (recorded, not counted as coverage)

All 197 findings are gas/performance/style, none security:

| n | rule |
|---|---|
| 107 | `use-custom-error-not-require` |
| 55 | `use-short-revert-string` |
| 13 | `non-payable-constructor` |
| 7 | `use-ownable2step` |
| 15 | misc (nested-if, prefix-increment, encodeCall, loop arithmetic) |

Solidity security coverage in this run rests **entirely on Slither + Aderyn**. This reconfirms the standing note that Semgrep has no useful Solidity security ruleset.

## Counts

- Raw across all tools: **254**
- Filtered as noise/QA-only: **229**
- Normalized findings retained: **25**

Filtered detectors: `naming-convention`, `solc-version`/`unspecific-pragma`, `assembly`, `missing-zero-check` / `address-state-var-set-without-checks` (12+10), `unused-state`, `dead-code`, `missing-inheritance`, `PUSH0`, `literal-instead-of-constant`, `modifier-invoked-once`, `unused-import`, `public-fn-not-used-internally`, `large-numeric-literal`, `empty-block`, `centralization-risk` (69 — Law 3, owner trusted), plus all 197 Semgrep gas/style.

**Timestamp / block-dependency findings were deliberately NOT dropped** (run policy: this protocol is time-driven).

`low-level-calls` was retained in one case (`rescueETH`) under the value-transfer carve-out.

---

## Findings on the 4 changed contracts (story-046/047)

### `src/dispatchers/BalancerPoolerV2.sol`

| ID | Type | Sev guess | Fn / line | Tools |
|---|---|---|---|---|
| SA-001 | unchecked external call return | potential-medium | `_psmDonate` :335 | slither + aderyn |
| SA-002 | unchecked external call return | potential-medium | `_dispatch` :282 | slither + aderyn |
| SA-003 | unchecked external call return | potential-low | `pool` :361 | slither + aderyn |
| SA-004 | unchecked external call return | potential-low | `unlockCallback` :394/:395 | slither + aderyn |
| SA-005 | divide-before-multiply | potential-medium | `_psmDonate` :322→:331 | slither |
| SA-006 | strict equality on balance | potential-medium | `getIdealBPT` :407 | slither |
| SA-007 | reentrancy-events | potential-low | `_psmDonate` :309 | slither |
| SA-008 | reentrancy-events | potential-low | `unlockCallback` :365 | slither |
| SA-009 | state change after ext. call | potential-low (**likely FP**) | `constructor` :152 | aderyn (HIGH) |
| SA-023 | state change without event | potential-low | :182 | slither + aderyn |
| SA-024 | nonReentrant not first modifier | potential-low | `pool` :356 | aderyn |

**SA-001 is the highest-signal item on the new PSM→streamer path.** `buyGem`'s return is discarded and the whole downstream chain — `forceApprove(streamer, gemAmt)` then `collectNudge(batchMinter, gem, gemAmt)` — is sized on the *locally computed* `gemAmt`, never on USDC actually received.

**SA-005** is documented in-code as an intentional floor ("dust accrues to the protocol, never over-credits"); flagged for confirmation, not asserted as a bug.

**SA-009** is a constructor; retained at low confidence per no-silent-drop rather than discarded.

### `src/dispatchers/NudgeRatchet.sol`

| ID | Type | Sev guess | Fn / line | Tools |
|---|---|---|---|---|
| SA-010 | state change after ext. call | potential-low (**likely FP**) | `constructor` :84 | aderyn (HIGH) |

Nothing else fired. The `collectNudge` hop at :160 drew **no** detector from either tool.

### `src/dispatchers/Uniboost.sol`

| ID | Type | Sev guess | Fn / line | Tools |
|---|---|---|---|---|
| SA-014 | unchecked external call return ×3 | potential-medium | `pool` :276, :289, :302 | slither + aderyn |
| SA-015 | block.timestamp deadline / comparison | potential-low | `pool` :266, :276, :289, :305 | slither + aderyn |
| SA-024 | nonReentrant not first modifier | potential-low | `pool` :270 | aderyn |

Swaps do carry `minPairOut` / `minTargetOut` / `minLP` floors. The `collectNudge` hop at :250 drew no detector.

### `src/dispatchers/PromotionUniV2_Eth.sol`

| ID | Type | Sev guess | Fn / line | Tools |
|---|---|---|---|---|
| SA-016 | unchecked external call return ×2 | potential-medium | `_legB` :504, :510 | slither + aderyn |
| SA-017 | unchecked return + **zero min-amounts** | potential-medium | `_addPhusdPromoLiquidity` :468 | slither |
| SA-018 | unchecked external call return ×2 | potential-low | `unlockCallback` :561, :562 | slither + aderyn |
| SA-019 | raw ETH `.call{value:}` | potential-low | `rescueETH` :584 | slither |
| SA-025 | block.timestamp deadline | potential-low | :504, :523 | aderyn |
| SA-024 | nonReentrant not first modifier | potential-low | :429 | aderyn |

**SA-017 deserves manual attention:** `addLiquidity(..., 0, 0, address(this), block.timestamp)` passes **zero for both `amountAMin` and `amountBMin`**; the only protection is the post-hoc `require(liquidity >= minLP)` at :471. Confirm `minLP` alone bounds the ratio exposure.

### Other first-party contracts (context)

SA-013 (`NFTMinterV2.sol:263`, `abi.encodePacked` hash collision, Aderyn HIGH — needs confirmation that >1 dynamic arg is present), SA-020/SA-021 (`MultiPooler.pool:60`, external call in loop + event ordering), SA-022 (`NFTMinterV2.setDispatcherActive:309`), SA-011/SA-012 (constructor FPs in `NudgeRatchetDelayRelease`, `UniboostMintDebtHook`).

---

## Tool negatives (meaningful clean results)

- **No** `reentrancy-eth`, `reentrancy-no-eth`, `arbitrary-send-eth`, `arbitrary-send-erc20`, `controlled-delegatecall`, `unprotected-upgrade`, `suicidal`, `tx-origin`, `weak-prng`, `uninitialized-state/-storage/-local`, `unchecked-transfer`, or `shadowing-*` anywhere in first-party `src/**`.
- On the new `INudgeStreamer.collectNudge` hop in all four dispatchers: **no reentrancy detector fired**, and no unchecked-transfer / arbitrary-from detector fired on the `forceApprove` → `collectNudge` sequence.
- **`nudgeStreamer` zero-address is not flagged** because it is genuinely guarded: every call site has `require(streamer != address(0), "<C>: nudgeStreamer unset")` immediately before use, and every `setNudgeStreamer` rejects `address(0)`.

## Handoff notes — SAST blind spots (for code-scanner / econ-scanner / story-faithfulness)

These are **not** tool findings. They are things no static tool can decide, surfaced so they are not lost.

1. **Allowance-consumption assumption.** All four dispatchers do `forceApprove(streamer, amount)` and rely on the in-code claim that *"`collectNudge` consumes the whole allowance in this same transaction, so nothing lingers."* That is an assumption about an **external** contract (`phoenix-nft-staking` `NudgeStreamer`). If any streamer implementation ever pulls less than approved, a residual allowance persists on a USDC-class token. Verify against the NudgeStreamer source.

2. **Deliberate revert-swallowing in BalancerPoolerV2.** `_dispatch` wraps the donation in `try this._psmDonate() {} catch { emit DonationSkipped(...) }`, and story-047 placed the streamer hop **inside** that envelope on purpose. A streamer misconfiguration (unset / `NudgeStreamer__NotRegistered` / `NudgeStreamer__NotWhitelisted`) therefore silently parks USDS instead of reverting the mint. Documented as intentional; a static tool cannot rank it.

3. **Asymmetry across the four dispatchers.** `NudgeRatchet`, `Uniboost` and `PromotionUniV2_Eth` do **not** wrap `collectNudge` in try/catch — a streamer misconfiguration there **bricks dispatch outright**, whereas `BalancerPoolerV2` parks quietly. The dev comments frame this as deliberate; confirm it is intended for all four.

4. **Semgrep gap** (see above) — do not read "Semgrep clean" as security coverage.
