> **Carryover QA report — audit 01** (copied from `sya-harvester/reports/01/submissions/qa-report.md`; [original](../../../01/submissions/qa-report.md)).
> Retained below (still open / untriaged as of audit 02, master @ `6b862aa`): **L-01, L-02, L-03, L-04, Q-01, Q-02, Q-03, Q-04, Q-05, Q-06, Q-07** — all 11 entries.
> Removed as no longer live: **none** (no entry of this report has been fixed, acknowledged, wont-fix, false-positive or abandoned), so the body below is the whole original report, unpruned.
> Labels are the originals. Line numbers and links were accurate at the originating commit `62c19c8`; re-verify against current HEAD. Relative links in the body (`./4naly3er-report.md`, `./M-01-submission.md`) resolve against `reports/01/submissions/`, not this directory. M-01 is carried separately as [`../M-01-C1.md`](../M-01-C1.md) (fix-pending, `fixed` proposed).
> Triage with `/ledger sya-harvester`.

| Label | Issue ID | Fingerprint | Ledger status | Run-02 status note |
|---|---|---|---|---|
| L-01 | sh1l1 | `d7744b9d2400d7bde1e1b89ec20eb85b0c45aee30e148d5d78eff4f72288c8da` | open | Still live; `_sellYield` untouched by the 62c19c8..6b862aa diff. |
| L-02 | sh1l2 | `464b94269170a41b1f22c0e8fdc901faf0f402b9d2365d41e406b618c1f6619c` | open | Still live; profit floors unchanged. Unprofitable gas check still unexercised by invariants (gasprice 0). |
| L-03 | sh1l3 | `4994fe853f916ac91f7b79b6789e0644535a7687c65ba889481fcc0baac0d51b` | open | Still live, **extended (k=0 addendum)**: after an SYA `setRewardToken`, the canonical k=0 route stored for the old reward token becomes reachable if a strategy delivers the old token; Router NG always executes hop 0 and reverts with empty data (swap = address(0)) rather than `RouteNotConfigured`, and `harvest.sh` cannot decode it. Fail-loud, no strand; severity unchanged. Related: F-06. |
| L-04 | sh1l4 | `8cc1530764fe5a82b97f32c17df0ca2ab803093cd8404ed11705cfb166a4adee` | open | Still live. The diff added 4 setRoute-only errors to `KNOWN_ERRORS` (selectors verified correct), but the root is unaddressed. **Two new missing instances**: `SafeERC20FailedOperation(address)` and `SafeCastOverflowedUintToInt(uint256)` are harvester-reachable and absent from `KNOWN_ERRORS`. Small positive: the zero-intermediate empty-revert case is no longer reachable. |
| Q-01 | sh1q1 | `e95e3c9bae91d923ba6c1a25d0610ade70582d461dba4afc61ca802493134d97` | open | Still live; borrow buffer unchanged. Arithmetic group B/C not re-run symbolically. |
| Q-02 | sh1q2 | `0df667c2a685c4502488bf818e39f2211c6cd2a02544bd015d8cd79a033f23ce` | open | Still live; V4 swap code untouched. |
| Q-03 | sh1q3 | `fed35932d0f1f9975c900873be488504bf360f872861a35276050c07e146c200` | open | Still live; no rescue path added. |
| Q-04 | sh1q4 | `dd56134239f856d7fb56b6a4ec790899b596d91b4d46b6ff6dcab75c0cfca354` | open | Still live; slippage/deadline handling unchanged. |
| Q-05 | sh1q5 | `bec3cacbc1eff78a646aeed7ef43720e4fc61715ab3354067e9c44f3766bf5d0` | open | Still live (sanitizer: still-open; no fix in the 62c19c8..6b862aa diff). |
| Q-06 | sh1q6 | `500b52898dea503576aef9ccf36106eb332ad4c7c39257f47305dd25fcfc8e81` | open | **Partly fixed.** Sub-issue 2 (mock mirrors the validator) FIXED: `MockCurveRouter` now resolves delivery at the first empty pool slot and is written independently of `setRoute`. Sub-issues 1 (vacuous `test_noHarvestFunction`) and 3 (MockSYA never over-delivers) unchanged. New residual 4: the mock accepts and executes swap_type >= 9 (hides L-05), reverts `NoHop` instead of modelling hop-0-always-executes, and its revert payloads differ from the real router. Stays open; consider re-scoping the title at triage. |
| Q-07 | sh1q7 | `23efa795964de4115a8f95d706bdb0a9f3597203e51d9bfae2784df6dd1884ea` | open | Still live; `harvest.sh` change was KNOWN_ERRORS-only. |

---

# QA Report for sya-harvester

- **Run**: `sya-harvester-01` (full audit, cold)
- **Source**: https://github.com/Behodler/sya-harvester @ `62c19c86be1594dcf82e8af794fcd6c28f9a8fc0` (branch `master`)
- **In scope**: `src/SYAHarvester.sol`, `src/interfaces/ICurveRouterNG.sol`, and the operator script `script/harvest.sh` (story-005). Test files are cited only where a finding concerns test fidelity (Q-06).
- **Automated baseline**: [4naly3er-report.md](./4naly3er-report.md). This is the raw bot output for the two Solidity files. It is untriaged, and its own `L-n`/`M-n` labels are **not** this audit's labels.
- **Not in this bundle**: M-01 (`sh1m1`) is submitted separately ([M-01-submission.md](./M-01-submission.md)). The faithfulness tags F-01 to F-05 belong in the spec-conformance report. They are cross-referenced below but not restated.

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 4 |
| QA (non-security hardening, doc and test fidelity) | 7 |
| Centralization | 0 |
| **Total** | **11** |

**Centralization: none.** The owner can only register routes and the ETH pool (`setRoute`, `clearRoute`, `setEthPool`). The contract holds no user funds between calls. Under Law 3, owner-privilege vectors are not reported. The one owner action with a non-obvious consequence is filed as the footgun **L-03**.

| Label | Issue ID | Title (short) | F-tag | Fingerprint |
|---|---|---|---|---|
| L-01 | sh1l1 | Raw-balance `_sellYield`: dust bricks harvest | F-03 | `d7744b9d2400d7bde1e1b89ec20eb85b0c45aee30e148d5d78eff4f72288c8da` |
| L-02 | sh1l2 | Profit floors ignore the burned claim NFT | F-01 | `464b94269170a41b1f22c0e8fdc901faf0f402b9d2365d41e406b618c1f6619c` |
| L-03 | sh1l3 | Routes/ethPool go stale on SYA `setRewardToken` (owner footgun) | none | `4994fe853f916ac91f7b79b6789e0644535a7687c65ba889481fcc0baac0d51b` |
| L-04 | sh1l4 | `harvest.sh` cannot decode SYA/strategy/router reverts | F-05 | `8cc1530764fe5a82b97f32c17df0ca2ab803093cd8404ed11705cfb166a4adee` |
| Q-01 | sh1q1 | 1% borrow buffer rests on a false "~10% over-estimate" premise | F-04 | `e95e3c9bae91d923ba6c1a25d0610ade70582d461dba4afc61ca802493134d97` |
| Q-02 | sh1q2 | Exact-input V4 swap with a price limit can partially fill | none | `0df667c2a685c4502488bf818e39f2211c6cd2a02544bd015d8cd79a033f23ce` |
| Q-03 | sh1q3 | No rescue path; whole-balance payout | none | `fed35932d0f1f9975c900873be488504bf360f872861a35276050c07e146c200` |
| Q-04 | sh1q4 | Single aggregate slippage bound, no deadline | none | `dd56134239f856d7fb56b6a4ec790899b596d91b4d46b6ff6dcab75c0cfca354` |
| Q-05 | sh1q5 | Wrong "double fee" mechanism documented for USDe route | none | `bec3cacbc1eff78a646aeed7ef43720e4fc61715ab3354067e9c44f3766bf5d0` |
| Q-06 | sh1q6 | Test-double fidelity gaps hide M-01 / Q-01 regressions | none | `500b52898dea503576aef9ccf36106eb332ad4c7c39257f47305dd25fcfc8e81` |
| Q-07 | sh1q7 | `harvest.sh` operator residuals (deadline, re-run, relay) | none | `23efa795964de4115a8f95d706bdb0a9f3597203e51d9bfae2784df6dd1884ea` |

---

## Low Risk Findings

### [L-01] `_sellYield` acts on the raw token balance, so 1-wei donations (or a strategy's own sub-dust delivery) brick every harvest <!-- id: sh1l1 -->

- **Issue ID**: `sh1l1` · **Fingerprint**: `d7744b9d2400d7bde1e1b89ec20eb85b0c45aee30e148d5d78eff4f72288c8da`
- **Location**: [SYAHarvester.sol#L312-L318](https://github.com/Behodler/sya-harvester/blob/62c19c86be1594dcf82e8af794fcd6c28f9a8fc0/src/SYAHarvester.sol#L312-L318) (`_sellYield`)
- **Faithfulness**: F-03 (story-002 Flow step 5, *story-unsafe*, Law 1). See spec-conformance.

**Description.** `_sellYield` reads `IERC20(token).balanceOf(address(this))` for each non-exempt strategy token. It does not use the amount SYA delivered in this call, and it does not mirror SYA's paused-token skip. Any non-zero balance therefore triggers one of two reverts inside the loop:

- If the token has no route, the loop reverts `RouteNotConfigured(token)` (L315).
- If the token has a route, `router.exchange(...)` is called on a dust amount (L318). Curve Router NG reverts on amounts below roughly 1e13 wei ("Received nothing").

Either revert takes down the whole harvest. The rule comes straight from story-002 Flow step 5: *"Skip if `balanceOf(this) == 0`. Otherwise, if `!routes[token].configured`, revert."* That rule assumes the contract "holds no balances between calls", and any outsider can break that assumption with a donation.

**This happens without an attacker.** The invariant suite runs `invariant_liveness_naturalDust`, and it **fails in the honest configuration** (forge and Medusa): a non-exempt USDe strategy delivered a sub-threshold 298,075 wei surplus, the router reverted "Received nothing", and the harvest failed. A griefer makes it worse by donating 1 wei of the token of any strategy that delivers 0 in that round. Fork tests show the effect:

- `test_audit_dust_routed_oneWeiDonation_bricks`: the call fails with revert data `0x`.
- `test_audit_dust_unrouted_oneWeiDonation_bricks`: the baseline harvest returns `ethOut` 2512669567563236; after the donation it reverts `RouteNotConfigured(DOLA)`.

**Impact.** Availability only, with no loss of value. The harvest reverts atomically and the unharvested yield stays in the strategies, where a later claim can collect it. Likelihood is high because the honest dust path fires in normal operation, which is why this is Low and not QA. The caller has a same-block workaround: put the offending strategy in `exemptStrategies`, and `_sellYield` skips exempt tokens. **L-04 blocks that workaround in practice**, because `harvest.sh` cannot say which strategy caused the revert.

**Recommendation.**
- Snapshot each strategy token's balance before `sya.claim` and sell only the delta. Alternatively, skip balances below a per-token dust threshold, or skip tokens that SYA reports as paused.
- Add an owner sweep for stray tokens (see Q-03).
- Amend story-002 Flow step 5 (F-03).

```solidity
// before sya.claim(...)
uint256[] memory pre = _snapshot(strategyTokens);
sya.claim(nftIndex, 0, exempt);
// in _sellYield
uint256 delivered = IERC20(token).balanceOf(address(this)) - pre[i];
if (delivered < DUST[token]) continue;
```

**Cross-project**: none. No ledger entry in stable-yield-accumulator has this root cause. The nearest is SYA L-01 (`sya11l1`), which has a different root.

---

### [L-02] Neither the on-chain `Unprofitable` check nor `harvest.sh`'s `minEthOut` floor prices the claim NFT burned by SYA, so the default config sends net-loss harvests <!-- id: sh1l2 -->

- **Issue ID**: `sh1l2` · **Fingerprint**: `464b94269170a41b1f22c0e8fdc901faf0f402b9d2365d41e406b618c1f6619c`
- **Location**: [SYAHarvester.sol#L248-L252](https://github.com/Behodler/sya-harvester/blob/62c19c86be1594dcf82e8af794fcd6c28f9a8fc0/src/SYAHarvester.sol#L248-L252) (`harvest`, gas check) · [harvest.sh#L235-L247](https://github.com/Behodler/sya-harvester/blob/62c19c86be1594dcf82e8af794fcd6c28f9a8fc0/script/harvest.sh#L235-L247) (step 4, `minEthOut`)
- **Faithfulness**: F-01 (`src/CLAUDE.md` Purpose versus story-003/005, a spec self-contradiction, Law 2). See spec-conformance.

**Description.** Both profit gates count gas only:

- On-chain: `(g0 - gasleft() + GAS_OVERHEAD) * tx.gasprice`.
- Script: `GAS_FLOOR = gasLimit * maxFee + MIN_PROFIT_WEI`, where `MIN_PROFIT_WEI` defaults to 0.

`src/CLAUDE.md` Purpose defines a profitable claim as one where the yield's value minus the payment exceeds **gas + NFT cost**. The settled "Gas check" decision, story-003 and story-005 all specify gas only, so the spec contradicts itself.

**Impact.** The caller loses up to about one claim-NFT mint price per harvest. No third party extracts value, and the protocol is unaffected. Fork measurements:

- At the reference state, a "profitable" full harvest pays 10.822 USD of ETH and burns NFT index 1, which has a mint price of 10.783 USDC (`getPrice(1)` = 10782880). That is about -0.45 USD after gas.
- story-005's own validation run nets about -2.2 USD.
- A USDe-only harvest pays 2.65 USD for a 10.78 USD NFT, and `harvest.sh` would still send it under the default config.
- The NFT-adjusted break-even is about 36 USD of pending yield for index 1, or about 233 USD for index 7. At today's base fee, the script fires once pending yield exceeds roughly 1-2 USD.

**Recommendation.** This is a self-inflicted loss, so the fix is a safer operator default:
- In `harvest.sh`, read `nftMinter.getPrice(NFT_INDEX)`, convert it to ETH (V4 `slot0` or the simulated USDC/ETH rate), and add it to `GAS_FLOOR`.
- Default `MIN_PROFIT_WEI` to that value, or refuse to run without it. Document the NFT cost in the README.
- The owner should reconcile the Purpose text with the Gas-check decision (F-01).

**Cross-project**: none with the same root cause. For context only, SYA QA-01 (`sya12qa1`, open): the first claimer captures the whole discount.

---

### [L-03] Routes and `ethPool` are checked against `sya.rewardToken()` only when they are set, so an SYA `setRewardToken` bricks harvest and the harvester owner cannot pre-stage the new config (owner footgun) <!-- id: sh1l3 -->

- **Issue ID**: `sh1l3` · **Fingerprint**: `4994fe853f916ac91f7b79b6789e0644535a7687c65ba889481fcc0baac0d51b`
- **Location**: [SYAHarvester.sol#L139-L140](https://github.com/Behodler/sya-harvester/blob/62c19c86be1594dcf82e8af794fcd6c28f9a8fc0/src/SYAHarvester.sol#L139-L140) (`setRoute`) · [#L174](https://github.com/Behodler/sya-harvester/blob/62c19c86be1594dcf82e8af794fcd6c28f9a8fc0/src/SYAHarvester.sol#L174) (`setEthPool`) · [#L280](https://github.com/Behodler/sya-harvester/blob/62c19c86be1594dcf82e8af794fcd6c28f9a8fc0/src/SYAHarvester.sol#L280) (`unlockCallback`, live read)

**Description.** `setRoute` requires each route's last hop to equal `sya.rewardToken()`. `setEthPool` requires `currency1 == sya.rewardToken()`. Both checks run only at write time, but `unlockCallback` reads `sya.rewardToken()` live. When the SYA owner rotates the reward token:

- Every harvest reverts (fork: USDC→USDT; `WrappedError 0x90bfb865` from the V4 currency transfer).
- The harvester owner **cannot pre-stage** the new config. Routes and the pool for the new token are rejected before the switch, and the old pool is rejected after it (`InvalidEthPool 0xc70c704d`).

story-001 accepted the set-time check as harmless and did not expect the pre-staging lock-out.

**Impact.** A temporary, fail-loud harvest outage between SYA's `setRewardToken` and the harvester owner re-registering every route and the `ethPool`. No value is at risk, and recovery is an ordinary owner call. This is a cross-owner **footgun**: a competent owner would expect to be able to stage the new config ahead of a migration.

**Recommendation.** Check `Currency.unwrap(ethPool.currency1) == sya.rewardToken()` at the top of `harvest` and revert with a named error (for example `RewardTokenChanged()`), so the outage reads clearly and not as a V4 `WrappedError`.

**Safe-config guidance (runbook).** Add a step to the SYA reward-token migration runbook: **"Immediately after `setRewardToken`: (1) `clearRoute` every registered yield token; (2) `setRoute` each token with a path ending in the new reward token; (3) `setEthPool` with `currency1` = the new reward token; (4) dry-run `harvest.sh` with `DRY_RUN=1` before any operator resumes."** Pause any harvest automation for the window between the switch and step 3. These calls cannot be staged in advance.

**Cross-project**: related to SYA M-02 (`sya14m02`, fingerprint `5292756503a71502cb14ded061791109e1c92b6cded78c250ae69516931c51ec`, **fixed** at 6eab35c), where SYA's own `setRewardToken` re-keyed the nudge stream and bricked `SYA.claim()`. That is a different root cause: this one is the harvester's own cached config, so it is not suppressed. Also related to SYA L-10 (`sya14l10`, open), the same cross-owner rotation hazard with a different root.

---

### [L-04] `harvest.sh` cannot decode SYA, strategy, oracle or Router NG reverts, so the operator cannot tell which strategy to exempt (story-005 "readable reason on any simulated revert" unmet) <!-- id: sh1l4 -->

- **Issue ID**: `sh1l4` · **Fingerprint**: `8cc1530764fe5a82b97f32c17df0ca2ab803093cd8404ed11705cfb166a4adee` (split from the Q-07 parent `23efa795…84ea`)
- **Location**: [harvest.sh#L152-L180](https://github.com/Behodler/sya-harvester/blob/62c19c86be1594dcf82e8af794fcd6c28f9a8fc0/script/harvest.sh#L152-L180) (`KNOWN_ERRORS` / `decode_revert`)
- **Faithfulness**: F-05 (story-005 Acceptance, Law 2). See spec-conformance.

**Description.** `KNOWN_ERRORS` lists only SYAHarvester's own errors. The following print as raw 4-byte selectors:

- SYA errors: `ZeroAmount` `0x1f2a2005`, `NoValidNFT` `0x0d78b379`, `ExemptStrategyNotRegistered`.
- `EnforcedPause`.
- Tokemak `InvalidDataReturned` `0x8d54ba1f`.

Router NG dust reverts return empty data, and in that case no token is named at all. The script still meets the narrower step-2 mandate, but story-005's acceptance criterion, *"aborts with a readable reason on any simulated revert"*, is not met.

**Impact.** No direct impact: abort-before-send still holds. However, this removes the operator's means of applying **L-01's workaround** (exempt the offending strategy). When L-01 fires naturally, the operator sees a bare selector or nothing and has to guess, and harvesting stalls. That availability consequence on an unmet acceptance criterion is why this is Low and not QA.

**Recommendation.**
- Add the SYA, strategy and oracle selectors to `KNOWN_ERRORS`.
- On empty revert data, re-simulate with each strategy exempted in turn (or call `sya.getYield` per strategy) and print the offending token.

```bash
KNOWN_ERRORS+=( "ZeroAmount()" "NoValidNFT()" "ExemptStrategyNotRegistered(address)" "EnforcedPause()" "InvalidDataReturned()" )
```

---

## QA Findings

### [Q-01] Borrow/allowance is `calculateClaimAmount * 1.01` on a false "~10% over-estimate" premise; DOLA runs with only 1% headroom, and over-delivery beyond it reverts the claim <!-- id: sh1q1 -->

- **Issue ID**: `sh1q1` · **Fingerprint**: `e95e3c9bae91d923ba6c1a25d0610ade70582d461dba4afc61ca802493134d97`
- **Location**: [SYAHarvester.sol#L265-L286](https://github.com/Behodler/sya-harvester/blob/62c19c86be1594dcf82e8af794fcd6c28f9a8fc0/src/SYAHarvester.sol#L265-L286) (`unlockCallback`; NatSpec at L265-268, borrow at L281)
- **Faithfulness**: F-04 (story-002 Background and Concerns, false safety premise, Law 2). See spec-conformance.

**Description.** story-002 and the NatSpec at L265-268 state that `calculateClaimAmount` "over-estimates by ~10% … the safe direction". The over-estimate actually depends on the strategy. Fork measurements of paid/estimate are 99.00% for USDC, 75.12% for USDe and **100.00% for DOLA**. The 1% `BORROW_BUFFER_BPS` applies to the *aggregate* estimate:

- A +2% DOLA over-delivery is absorbed in a full claim (1545.3 borrowed against 1539 paid).
- The same over-delivery reverts in a DOLA-only claim (454.5 against 459) on SYA's allowance pull.

Exempting the over-estimating strategies, which is the operator's natural reaction to L-01, removes the headroom.

**Impact.** A loud DoS at most, with no loss of value. No live strategy over-delivers today, and the invariant failures used a synthetic +2-3% double. If SYA ever adds a strategy that can deliver more than its estimate, this becomes Low. SYMBOLIC-002 adds a dust-level sub-observation: the buffer floors to 0 for estimates below 100 units.

**Recommendation.**
- Correct story-002's premise and the NatSpec.
- Size `BORROW_BUFFER_BPS` from the measured worst-case delivered/estimate ratio per strategy, not on the aggregate.
- Add an over-delivery mode to `MockSYA` (see Q-06).

**Cross-project**: SYA L-06 (`sya12l6`, fingerprint `90bcf3764e6c0feb26c96c07b5338b6cd6970dff20e40382820958c40d660317`, open) is the upstream cause: the preview estimate diverges from the amount actually charged, and there is no payment ceiling. This is a cross-reference only, because the 1% buffer and its false premise are harvester-side.

---

### [Q-02] Exact-input V4 swap with `sqrtPriceLimitX96 = MAX-1` can partially fill, leaving the unswapped reward token for the next caller <!-- id: sh1q2 -->

- **Issue ID**: `sh1q2` · **Fingerprint**: `0df667c2a685c4502488bf818e39f2211c6cd2a02544bd015d8cd79a033f23ce`
- **Location**: [SYAHarvester.sol#L328-L338](https://github.com/Behodler/sya-harvester/blob/62c19c86be1594dcf82e8af794fcd6c28f9a8fc0/src/SYAHarvester.sol#L328-L338) (`_swapSurplusAndSettle`)

**Description.** The swap is exact-input with a price limit. Debt is settled from the actual `delta.amount1()`, but any residue (`surplus - consumed`) is neither checked nor returned. This contradicts in principle story-002's acceptance criterion of "zero balances of every token".

**Impact.** Unreachable on the configured ETH/USDC 0.3% pool at harvest sizes, and the caller is protected by `minEthOut`. This is a hardening note. The `-delta.amount1()` negation panic at `int128.min` needs a swap of at least 2^127 units, so it cannot be reached.

**Recommendation.** `require(uint256(int256(-delta.amount1())) == surplus)`, or transfer any reward-token residue to `msg.sender`.

---

### [Q-03] No rescue path: stray non-strategy ERC20s and ERC1155 ids are stuck forever; stray strategy tokens, reward token and ETH go to the next caller through whole-balance logic <!-- id: sh1q3 -->

- **Issue ID**: `sh1q3` · **Fingerprint**: `fed35932d0f1f9975c900873be488504bf360f872861a35276050c07e146c200`
- **Location**: contract-wide (no sweep function) · [SYAHarvester.sol#L241-L248](https://github.com/Behodler/sya-harvester/blob/62c19c86be1594dcf82e8af794fcd6c28f9a8fc0/src/SYAHarvester.sol#L241-L248) (whole-balance NFT refund, `ethOut = address(this).balance`) · [#L312](https://github.com/Behodler/sya-harvester/blob/62c19c86be1594dcf82e8af794fcd6c28f9a8fc0/src/SYAHarvester.sol#L312) (whole-balance token sale)

**Description.** The design is stateless and pays out whole balances, and there is no owner sweep. Anything sent to the contract by mistake is either a gift to the next caller (strategy tokens, reward token, ETH, the caller's NFT id) or stuck permanently (any other ERC20 or ERC1155 id). The "pot theft" premise (PATTERN-MR-02) was **refuted**: no path lets a non-caller take an honest caller's ETH.

**Impact.** Value sent by mistake is lost. This is mainly an aggravator: the lack of a sweep is what makes M-01's stranded token and L-01's dust permanent.

**Recommendation.** Add an optional `onlyOwner` sweep for ERC20 and ERC1155 ids (the owner is trusted, Law 3). Ship it with the M-01 fix.

---

### [Q-04] Single aggregate slippage bound: intermediate legs run with `minOut` 0 and no price limit, `harvest()` has no deadline and accepts `minEthOut = 0`; MEV exposure if the private relay leaks <!-- id: sh1q4 -->

- **Issue ID**: `sh1q4` · **Fingerprint**: `dd56134239f856d7fb56b6a4ec790899b596d91b4d46b6ff6dcab75c0cfca354`
- **Location**: [SYAHarvester.sol#L226](https://github.com/Behodler/sya-harvester/blob/62c19c86be1594dcf82e8af794fcd6c28f9a8fc0/src/SYAHarvester.sol#L226) (`harvest`, no deadline) · [#L249](https://github.com/Behodler/sya-harvester/blob/62c19c86be1594dcf82e8af794fcd6c28f9a8fc0/src/SYAHarvester.sol#L249) (sole `minEthOut` check) · [#L285](https://github.com/Behodler/sya-harvester/blob/62c19c86be1594dcf82e8af794fcd6c28f9a8fc0/src/SYAHarvester.sol#L285) (`sya.claim(nftIndex, 0, exempt)`) · [#L318](https://github.com/Behodler/sya-harvester/blob/62c19c86be1594dcf82e8af794fcd6c28f9a8fc0/src/SYAHarvester.sol#L318) (`router.exchange(..., 0, ...)`) · [#L328-L334](https://github.com/Behodler/sya-harvester/blob/62c19c86be1594dcf82e8af794fcd6c28f9a8fc0/src/SYAHarvester.sol#L328-L334) (V4 swap, no price bound)

**Description.** This follows the documented design decision "One slippage check" in `src/CLAUDE.md`: a single end-to-end `minEthOut` bounds the atomic call. Every intermediate leg runs unbounded. `harvest()` has no deadline and accepts `minEthOut = 0`, so direct callers who bypass `harvest.sh` rely on the gas floor alone. If the transaction reaches the public mempool:

- A copier cannot replay it without holding the NFT and granting approval.
- A rival NFT holder can win the claim race (SYA QA-01). The victim's transaction then reverts atomically.
- A sandwich is bounded by `harvest.sh`'s `SLIPPAGE_BPS = 50` on `ethOut`, about 0.05 USD today.

**Impact.** Caller-only and sub-dollar at current sizes, scaling linearly with pending yield. The protocol is not exposed, because SYA's payment is fixed from `skimSurplus` and does not depend on the sale price (ECON-003).

**Recommendation.** This is hardening only, derived from the matched pattern's listed missing mitigations:
- Optionally add a `deadline` parameter to `harvest()` (`if (block.timestamp > deadline) revert Expired();`), and have `harvest.sh` set it a few blocks ahead.
- Document in the NatSpec that direct integrators must pass a non-zero `minEthOut` derived from a fee-carrying simulation.

The deadline sub-issue is counted once, as Q-07(a); this finding only cross-references it.

---

### [Q-05] Documented "double fee" mechanism on USDe/crvUSD pool `0xF55B` is wrong (opposite-direction trades, not an adverse price move); the direct USDe/USDC route avoids the round trip <!-- id: sh1q5 -->

- **Issue ID**: `sh1q5` · **Fingerprint**: `bec3cacbc1eff78a646aeed7ef43720e4fc61715ab3354067e9c44f3766bf5d0`
- **Location**: [test/fork/MainnetRoutes.sol#L35-L43](https://github.com/Behodler/sya-harvester/blob/62c19c86be1594dcf82e8af794fcd6c28f9a8fc0/test/fork/MainnetRoutes.sol#L35-L43) (route rationale and "Double fee" note) · [#L59-L67](https://github.com/Behodler/sya-harvester/blob/62c19c86be1594dcf82e8af794fcd6c28f9a8fc0/test/fork/MainnetRoutes.sol#L59-L67) (`usdeRoute`) · story-004 (Background > Routes, Concern [Double fee])

**Description.** The comment says the strategy's skim and the route's first hop both trade on `0xF55B…` and that this moves "its price against the second trade". The live sUSDe→USDe adapter route actually **buys** USDe from `0xF55B` (fork: pool USDe 134630.07 → 134624.36). The harvester then **sells** the delivered 4.29 USDe back into the same pool. The two trades go in opposite directions, so the first one's price impact *favours* the second. The real cost is two pool fees plus a needless crvUSD→USDe→crvUSD round trip. Both legs are atomic, so no third party can insert between them.

**Impact.** Cents per harvest at current sizes, affecting only the caller's profit. No security impact.

**Recommendation.**
- Correct the mechanism in the MainnetRoutes comment and in story-004.
- Consider registering the direct USDe/USDC pool `0x02950460E2b9529D0E00284A5fA2d7bDF3fA4d72`, which the same comment already names as a `setRoute` drop-in that quoted marginally better. It avoids the round trip entirely.

---

### [Q-06] Test-suite fidelity gaps hide M-01 and Q-01 regressions <!-- id: sh1q6 -->

- **Issue ID**: `sh1q6` · **Fingerprint**: `500b52898dea503576aef9ccf36106eb332ad4c7c39257f47305dd25fcfc8e81`
- **Location**: [test/SYAHarvester.registry.t.sol#L284-L287](https://github.com/Behodler/sya-harvester/blob/62c19c86be1594dcf82e8af794fcd6c28f9a8fc0/test/SYAHarvester.registry.t.sol#L284-L287) · [test/mocks/MockCurveRouter.sol#L33-L42](https://github.com/Behodler/sya-harvester/blob/62c19c86be1594dcf82e8af794fcd6c28f9a8fc0/test/mocks/MockCurveRouter.sol#L33-L42) · [test/mocks/MockSYA.sol#L125-L138](https://github.com/Behodler/sya-harvester/blob/62c19c86be1594dcf82e8af794fcd6c28f9a8fc0/test/mocks/MockSYA.sol#L125-L138)

**Description.**
1. `test_noHarvestFunction` calls `harvest(uint256,uint256,address[])`, a selector that never existed, so the test asserts nothing. It is a leftover story-001 point-in-time criterion that story-002 Decision 7 superseded.
2. `MockCurveRouter.exchange` takes the output token from the *last non-zero path entry*. That copies the harvester's own `setRoute` rule, so **M-01 cannot be seen by the unit suite**.
3. In `MockSYA`, the estimate is always at least the delivered amount by construction (`overEstimateBps` only ever adds), so Q-01's revert path is never exercised.

There are also no unit tests for donation DoS (L-01) or reward-token coupling (L-03). The fixture's deep 1:1 pool never exercises Q-02.

**Impact.** No direct security impact. The gaps reduce the suite's ability to catch M-01 and Q-01 regressions, which matters most when the M-01 fix lands.

**Recommendation.**
- Delete or rewrite `test_noHarvestFunction`.
- Make `MockCurveRouter` resolve the output token from the pool/`swapParams`, the way Router NG does, instead of from the last non-zero path entry.
- Add an under-estimate / over-delivery mode to `MockSYA`.
- Add unit tests for L-01 (1-wei donation), L-03 (reward-token rotation) and a shallow pool for Q-02.

Ship items 1-2 with the M-01 fix.

---

### [Q-07] Operator script (`script/harvest.sh`) residuals: no deadline, re-run after a `cast send` timeout, `PRIVATE_RPC_URL` not verified as private <!-- id: sh1q7 -->

- **Issue ID**: `sh1q7` · **Fingerprint**: `23efa795964de4115a8f95d706bdb0a9f3597203e51d9bfae2784df6dd1884ea` (parent; sub-issue (c) split out to L-04 / `sh1l4`)
- **Location**: [harvest.sh#L255-L276](https://github.com/Behodler/sya-harvester/blob/62c19c86be1594dcf82e8af794fcd6c28f9a8fc0/script/harvest.sh#L255-L276) (step 5, private submission) · range L152-L276

**Description.** The end-to-end review of the script found it sound:
- `bc` maths uses integer wei throughout.
- The fee-carrying `eth_call` reaches `tx.gasprice`.
- The floor `gasLimit * maxFee` is at least any inclusion-time gas cost.
- Parse failures die instead of sending.
- There is no public-mempool fallback.
- Signing is keystore-only.

Three residuals remain:
- **(a)** There is no deadline. `minEthOut` binds, but a Flashbots-Protect transaction may land several blocks later (same root as Q-04).
- **(b)** On a `cast send` timeout the script dies with `"cast send failed"` (L268-270), although the private transaction may still land. An immediate re-run builds a second transaction that reverts (`ZeroAmount` or the NFT pull) and costs gas.
- **(d)** `PRIVATE_RPC_URL` is only checked for its chain ID (L256-257), not for being a private relay.

**Impact.** Operator hardening only. `minEthOut` binds regardless of inclusion delay, a re-run loses only gas on a revert, and the choice of relay is the operator's.

**Recommendation.**
- (a) Pass the Q-04 deadline if it is added.
- (b) On a send failure, print the locally computed tx hash and the operator nonce, and tell the operator to check inclusion (or wait until the nonce advances) before re-running.
- (d) Warn when `PRIVATE_RPC_URL` is not on a known private-relay allowlist, such as the Flashbots Protect default.

---

## Centralization Risks

None. See the note under the summary.

---

## Appendix: automated QA/gas report

The 4naly3er output for `src/SYAHarvester.sol` and `src/interfaces/ICurveRouterNG.sol` is in **[4naly3er-report.md](./4naly3er-report.md)**. Its totals: 12 GAS, 14 NC, 5 L and 1 M (the bot's generic centralization item). It is untriaged. Its header records which bot items are noise under Law 3, and one false positive (GAS-7: the variables are already `immutable`). `script/harvest.sh` is outside the tool's reach and was reviewed manually (L-02, L-04, Q-07).
