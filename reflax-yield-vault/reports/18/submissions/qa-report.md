# QA Report: reflax-yield-vault, audit 18

| | |
|---|---|
| Run | `reflax-yield-vault-18` (regression, `cdd0743..4788ed4`) |
| Branch / HEAD | `master` @ `4788ed41747b923165745af748a078bfb534ba20` |
| Range | `25276b8` [story-051] revert `previewExitFor`; `4788ed4` [story-052] `CurveAMMAdapter.setRoute` contiguity validator |
| Scope | 7 first-party files (denylist scope; `lib/**` and `test/**` excluded) |
| Known issues | 0, so no finding below was suppressed on known-issue grounds |

This report holds only the findings that are **new in run 18**. Low and QA findings from earlier audits that are still open were not re-analysed here. They are carried, pruned to open entries, one file per originating audit:

- [carryover/qa-report-05.md](carryover/qa-report-05.md): L-01, C-01
- [carryover/qa-report-07.md](carryover/qa-report-07.md): L-03, L-04, L-05, L-07
- [carryover/qa-report-11.md](carryover/qa-report-11.md): L-01..L-09, L-11, L-12, QA-01
- [carryover/qa-report-12.md](carryover/qa-report-12.md): L-13, QA-02..QA-08
- [carryover/qa-report-14.md](carryover/qa-report-14.md): QA-09
- [carryover/qa-report-15.md](carryover/qa-report-15.md): L-14, L-15
- [carryover/qa-report-16.md](carryover/qa-report-16.md): L-16, L-17
- [carryover/qa-report-17.md](carryover/qa-report-17.md): L-18..L-29, QA-10..QA-12, INFO-01

Labels repeat across audits (for example, L-01 exists in both run 05 and run 11). The ledger fingerprint and the global issue ID are the unambiguous handles.

The run-18 faithfulness finding F-06 (CLAUDE.md overstates what the routeGap test covers) goes in the spec-conformance report, not here (Law 2). It is cross-referenced from M-05 (formerly L-30). Validity review found F-06 invalid, so it is a **proposed false-positive** (not applied), and its hardening point is absorbed into M-05 recommendation (d).

## Summary

| Severity | Count | Labels |
|----------|-------|--------|
| Low Risk | 2 | L-31, L-32 (L-30 promoted to M-05; see [M-05.md](M-05.md)) |
| QA | 2 | QA-13, QA-14 |
| Centralization | 0 | none (no new C-XX this run; run-05 C-01 stays in carryover) |
| **Total (new, this report)** | **4** | |

High: 0. Medium: 1 (M-05 `ryv18m5`, formerly L-30, submitted separately as [M-05.md](M-05.md)).

**Borderline items for the human.** Each has an escalation trigger stated below.

- M-05 (formerly L-30) is a borderline Medium. The severity-auditor rated it Medium, and the poc-validator agreed on the facts but rated it Low because the precondition is a future owner `setRoute`. The orchestrator chose Medium. The human may downgrade it.
- L-31 stays Low on the proven 1.38 bps shortfall alone. The manipulable autoUSD leg is unverified, so it is listed only as an escalation trigger.
- L-32 is a **draft**. It was a classifier observation (OBS-18-01), it has no PoC, and it was not probed this run. Its precondition was corrected at final review.
- QA-13 is borderline QA vs drop, and the validity review leans toward dropping it. It is kept so that nothing is dropped silently (Law 1). The owner has rejected MEV framings on this path before, and the disclosure is included.

Label continuity: L-30..L-32 and QA-13/QA-14 continue the project-wide sequence (L-29 and QA-12 were the last labels used, in run 17). M-05 continues the Medium sequence (M-04 was last, in run 07). L-30 was assigned and is now retired because of the promotion. It will not be reused.

---

## Low Risk Findings

### [L-30] Promoted to M-05 <!-- id: ryv18l30 → ryv18m5 -->

**Promoted to M-05 — see [submissions/M-05.md](M-05.md).** At final review the fork PoC (`work/test/poc-run18-L30-LiveAdapterGappedRouteStrand.t.sol`, 5/5 PASS, poc-validated) showed that a gapped USDe→sUSDe route on the live adapter `0x2D02…D6f` silently and permanently strands USDe deposits as crvUSD in the live strategy (1001.0035 crvUSD per 1000 USDe deposited; no recovery path). The withdraw direction reverts. The orchestrator promoted the finding to Medium (borderline; the human may downgrade). The fingerprint `d5a0f7dc1f9df28b04c28b7179e230bc9cb42ac02d013a760db384251769ad9c` is unchanged. The issue ID moved from `ryv18l30` to `ryv18m5`, and the old ID is kept as an alias. Label L-30 is retired, not reused.

---

### [L-31] Story-028 assumes the phUSD top-up through a direct `ERC4626YieldStrategy` is rounding-scale, but the live USDC strategy's autoUSD redeem delivers a non-rounding 1.38 bps shortfall with no exit floor <!-- id: ryv18l31 -->

**Severity**: Low (based on the proven shortfall only. A possible manipulation leg is unverified and appears only as an escalation trigger.)
**Fingerprint**: `b9203a0da756999a35ee8f9afed342b6e0f1d764cd706d2e499350d01b11717d`
**Location**: [src/concreteYieldStrategies/ERC4626YieldStrategy.sol:126-140](https://github.com/Behodler/reflax-yield-vault/blob/4788ed41747b923165745af748a078bfb534ba20/src/concreteYieldStrategies/ERC4626YieldStrategy.sol#L126-L140). Cross-repo consumer: `stable-staker/src/src/StableStakerV2.sol:494-499, :574-580`.

```solidity
// ERC4626YieldStrategy.sol:126-140
function _disposeShares(uint256 amount, address recipient) internal override returns (uint256 sharesDisposed) {
    uint256 sharesToRedeem = vault.convertToShares(amount);
    uint256 availableShares = vault.balanceOf(address(this));
    if (sharesToRedeem > availableShares) {
        sharesToRedeem = availableShares;
    }
    // Redeem shares for underlying tokens — sent directly to recipient
    vault.redeem(sharesToRedeem, recipient, address(this));   // no min-assets; return discarded
    sharesDisposed = sharesToRedeem;
}
```

```solidity
// StableStakerV2.sol:496-499 (story-028 NatSpec)
//  THE TOP-UP IS EXTRACTABLE, AND THAT IS ACCEPTED. A caller who sandwiches their own exit
//  through an AMM-backed strategy keeps the sandwich profit AND is still paid the frictionless
//  figure. It is bounded by the strategy's own `slippageToleranceBps` (which reverts below its
//  floor), by a real AMM round trip, and by the caller's own stake and accrual.
```

**Description**: `ERC4626YieldStrategy._disposeShares` calls `vault.redeem` with no minimum-assets check and discards the return value. StableStakerV2 measures the delta it actually receives and mints `(target − delivered)` as phUSD (`StableStakerV2.sol:574-580`).

Story-028 limits its `slippageToleranceBps` bound to **AMM-backed** strategies: the NatSpec above says "through an AMM-backed strategy", and the story's Concerns name `ERC4626MarketYieldStrategy`'s AMM. For **direct** strategies, the story assumes instead that the top-up is rounding-scale. Line 83 says "rounding-scale, not haircut-scale", and the checklist at line 310 tests the real `ERC4626YieldStrategy` at a non-integral share price.

That assumption fails on a live pool. The live USDC strategy (`0xaFDf8DeA…AB83`) is a direct `ERC4626YieldStrategy` over autoUSD. autoUSD delivers `previewRedeem`, which sits a static 1.38 bps below `convertToAssets` (16,356.04 vs 16,358.30 USDC). No floor applies, and V2 mints that non-rounding shortfall as phUSD on every USDC `autoAnnihilate`. The live DOLA strategy (`0x981c7BE1…B7EE`, over sDOLA) loses only to rounding, about 1 wei per call, which is what the story assumed. The premise is live: StableStakerV2 `0xA6d3…B58F` is the redeeming client of all three strategies, the cutover broadcast landed 21/21 receipts, and there have been 20 `AutoAnnihilated` logs since block 26,000,000.

**Impact**:
- *Proven*: autoUSD's static 1.38 bps discount is minted as unbacked phUSD on every USDC `autoAnnihilate`. That is dust (about $2 per full exit) and bounded by reward. sDOLA loses only to rounding.
- phUSD minted through V2 is real dilution, not opportunity cost, because V2 emits Antimatter.

**Proven path**:
1. A V2 staker with owed USDC-pool reward calls `autoAnnihilate(USDC)`, and `netWanted = min(owed reward, principal)`.
2. V2 routes the exit through the direct strategy `0xaFDf…AB83`. `_disposeShares` calls `autoUSD.redeem` with no minimum and discards the return value.
3. autoUSD delivers `previewRedeem`, about 1.38 bps below `convertToAssets`.
4. V2 mints `(target − delivered)` as phUSD. Story-028 assumed this shortfall away for direct strategies, and no `slippageToleranceBps` bound applies to this strategy class.

**Escalation trigger**:
- *Unverified manipulation leg* (not part of the proven finding): when an exit exceeds autoUSD's idle liquidity (707.5 USDC idle vs a 16,358 USDC position), an actor might be able to depress the redeem output of autoUSD's destination vaults within the same transaction or bundle. No Tokemak source is available locally and no fork manipulation probe was run. If the leg is proven, evaluate it against the next trigger.
- MEDIUM if a mainnet fork probe at the current block shows **both** of the following. Either one alone does not trigger the escalation:
  - for a redeem above autoUSD idle, a same-tx action can push delivered USDC more than 10 bps below `convertToAssets`;
  - that action costs less in total than 10 bps × the `netWanted` a single realistic V2 caller can request (total owed USDC-pool reward).
- MEDIUM if a live direct-strategy target is replaced by a vault whose `previewRedeem`/`convertToAssets` gap exceeds about 10 bps.
- Re-weigh if V2's per-call top-up cap is removed or raised, or if `netWanted` becomes bounded by principal instead of by reward.

**Recommendation**: Take one of two routes:
- Add a delivery floor to `ERC4626YieldStrategy._disposeShares`: capture the return of `vault.redeem` and require `assets >= previewRedeem(shares) * (MAX_BPS - tolerance) / MAX_BPS`.
- Or correct story-028's rounding-scale assumption for direct strategies, and add a consumer-side, per-call cap on the phUSD top-up for direct-strategy pools.

The story-028 rationale correction belongs to the **stable-staker** lane.

**Related (do not collapse)**: L-29 `704404968a8f` (same function, different root: missing measurement vs missing floor), ECON-A `c50c08f9ee58` (fee-blind credit), and L-27 `d9bd595066ef` (stable-staker lane).

---

### [L-32] DRAFT: Owner retiring the revoked OLD minter's USDe position via `withdrawAsOwner` while the market strategy is below par makes StableStakerV2 absorb the entire commingled loss <!-- id: ryv18l32 -->

**Severity**: Low (Law-3 owner footgun, operational hazard). **Lifecycle: draft. There is no PoC, and this mechanism was not probed in run 18.**
**Fingerprint**: `0ab8a6afdb0aa7bac59ded833d003877f4508332366cfbae43371405d264a32a`
**Location**: [src/AYieldStrategy.sol:644-646](https://github.com/Behodler/reflax-yield-vault/blob/4788ed41747b923165745af748a078bfb534ba20/src/AYieldStrategy.sol#L644-L646). Related: [src/AYieldStrategy.sol:732-755](https://github.com/Behodler/reflax-yield-vault/blob/4788ed41747b923165745af748a078bfb534ba20/src/AYieldStrategy.sol#L732-L755) and [src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:158-180](https://github.com/Behodler/reflax-yield-vault/blob/4788ed41747b923165745af748a078bfb534ba20/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L158-L180).

```solidity
// AYieldStrategy.sol:644-646
function withdrawAsOwner(address client, address recipient, uint256 amount) external onlyOwner nonReentrant {
    _withdrawInternal(address(underlyingToken), amount, recipient, client);
}

// ERC4626MarketYieldStrategy.sol:160 — exiter is paid the NAV of the principal debited
uint256 sharesToSell = vault.convertToShares(amount);
```

**Description**: The market strategy pays an exiter the NAV of the principal it debits. `_withdrawInternal` passes the requested (capped) amount to `_disposeShares`, which sells `vault.convertToShares(amount)`. When the commingled position is below par (V < D), the **first** exiter is made whole and the **last** exiters bear the whole loss. The I4 dominance invariant held at all 589 run-18 cap-binds, which is consistent with this ordering.

The live USDe strategy `0xaC2e…7f95` has these clients at block 26286995:

| client | address | principal (USDe) |
|---|---|---|
| OLD `PhusdStableMinter` (revoked) | `0x435B…77E5` | 3,749.62 (about 58% of D = 6,477.66) |
| StableStakerV2 | `0xA6d3…B58F` | 2,684.40 |
| new minter | `0x9485…E60C` | 43.65 |
| V1 | `0xbce8…079A` | 0 |

**Precondition (corrected at final review)**: the strategy is below par (V < D) only after one of these: an sUSDe NAV decline (never observed historically; Ethena absorbs losses in its reserve fund), a prior `emergencyWithdraw`, or an **M-05** strand (formerly L-30: a gapped deposit route on the live adapter). An sUSDe/USDe AMM discount **cannot** cause it, because valuation uses `convertToAssets` and deposit crediting is haircut, so `fairValueOfShares >= creditedPrincipal`. The mechanism itself is generic: any first exiter under V < D is paid full NAV, V2 included. The harm specific to the owner is that exiting the minter first reverses the intended cushion.

The minter-cushion design intends the non-redeeming minter to share V2's loss. Suppose the owner tidies up the revoked minter with `withdrawAsOwner(0x435B, recipient, 3749.62e18)` while V < D. The minter is then paid in full, and V2, the only redeeming client, absorbs the entire realised loss. V2 then emits Antimatter against under-backed principal. A competent owner retiring a revoked client would not expect the **order** of exits to decide who bears the loss.

This finding concerns exit ordering, not the commingled share cap. Socialised loss under the shared cap is by design, and this report does **not** recommend a per-client cap. By contrast, `totalWithdrawal` (`ERC4626MarketYieldStrategy._totalWithdraw`, pro-rata `totalShares * clientBalance / totalDeposited`) does not shift the loss.

**Impact**: No harm today. The strategy is not below par, and the action has not been taken. If the action were taken during a loss, up to about 58% of the realised loss would move onto V2 and be realised as unbacked Antimatter/phUSD dilution.

**Evidence and caveats**:
- Source: classifier observation OBS-18-01 (`severity-classification.json .observations`).
- Client balances come from `econ-scanner-findings.json onChainFacts.wiring.USDe`.
- Dominance grounding: `work/test/symbolic/DominanceRun17Grounding.t.sol`, 7/7 PASS at `4788ed4`.
- **No dedicated PoC exists.** The loss-shift arithmetic is analytical.
- The live USDe strategy runs pre-story-047 bytecode (`setAsideBufferRecipient()` reverts). The `withdrawAsOwner`/`_disposeShares` semantics were analysed at HEAD. **Reachability at the live bytecode has high confidence, based on source lineage rather than a bytecode diff.** The live `0xaC2e` exposes `withdrawAsOwner` (`0x879162f5`) and `totalWithdrawal` (`0x32e4036d`). `sharesToSell = vault.convertToShares(amount)` and the `withdrawAsOwner → _withdrawInternal` path are unchanged at `5cf462e`, `2306719`, `2f6774d` (story-046, before story-047) and HEAD. The Etherscan source is unverified, so this has not been bytecode-verified.

**Escalation trigger**:
- MEDIUM if `withdrawAsOwner`, or any non-pro-rata exit, is executed for a non-redeeming minter client while the strategy is below par and V2 or another redeeming client remains in the position.
- MEDIUM if a phStaging2 cleanup or cutover script schedules an OLD-minter `withdrawAsOwner` without an at-par precondition.
- Re-weigh if a second **redeeming** client is authorized on the same strategy.

**Recommendation (safe-config)**:
- Withdraw the OLD minter's position only while `totalBalance >= principal` (at or above par), or only after V2 has exited or migrated.
- When V < D, prefer the pro-rata `totalWithdrawal` over `withdrawAsOwner`.
- Document in the runbook and `src/CLAUDE.md` that `withdrawAsOwner` during a loss transfers the loss to the remaining clients.
- Before this is promoted from draft, add a fork PoC that runs the sequence on the deployed bytecode.

**Related**: M-05 `d5a0f7dc1f9d` (`ryv18m5`, formerly L-30; a third, owner-caused route to V < D), L-23 `e6088a0ec55e` (same NAV-of-principal mechanism, surplus direction), L-28 `38c9b2bae75f`, L-07-run11 `1177778f2c87` (event-field gap in `withdrawAsOwner`; different root).

---

## QA Findings

### [QA-13] NAV-anchored exit floor lets an unprivileged actor cheaply revert a pending exit, skim, or `totalWithdrawal` Phase-2 by front-running it with a Curve pool dump (transient griefing) <!-- id: ryv18q13 -->

**Severity**: QA (borderline QA vs drop; human to confirm)
**Validity concern**: Leaning drop. This is a transient revert that can be retried. Its meaningful content, that griefing pressures the owner to raise B, is cross-referenced into the L-01 annotation. It is kept at QA so that nothing is dropped silently (Law 1).
**Fingerprint**: `e98a15eb098b978788b534992231f06f8ab06d5f3652f2ec29971e0edacf5843`
**Location**: [src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:166-174](https://github.com/Behodler/reflax-yield-vault/blob/4788ed41747b923165745af748a078bfb534ba20/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L166-L174). The same pattern appears at `:223-231` (`_totalWithdraw`) and `:275-281` (`_skimSurplus`).

```solidity
uint256 idealUnderlying = vault.convertToAssets(sharesToSell);
uint256 minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;
...
uint256 underlyingReceived = ammAdapter.swap(address(vault), address(underlyingToken), sharesToSell, minOut);
```

**Description**: `minOut` is anchored to sUSDe NAV, while the AMM exit price sits below NAV. Live headroom is about 23.8 bps under B = 30. An actor with capital can see a public-mempool exit, skim, or `totalWithdrawal` Phase-2 and front-run it with a Curve pool dump that pushes the output below the floor. The victim's transaction reverts, and the attacker unwinds the dump.

**Impact**: Assets are not affected. The revert is transient and atomic. The fork probe `work/test/scan-run18/LiveAdapterFork.t.sol::test_frontRunDumpRevertsExitAndCost` (PASS) measured the attacker's round-trip cost:

| sUSDe dump | result | attacker cost |
|---|---|---|
| 10k, 50k, 100k | exit succeeds | n/a |
| 250k | exit **reverts** | about 101 sUSDe (about $127) |
| 500k | exit reverts | about 9,286 sUSDe |
| 1M | exit reverts | about 129,588 sUSDe |

The attacker gains nothing and must hold the capital across the bundle. The victim can retry or submit through a private relay.

*Flash-loan correction (final review)*: an earlier version of this report said the attack "cannot be flash-loaned". That claim is unverified and probably false: Morpho Blue `flashLoan` lends any token it holds, including sUSDe collateral. A flash loan lowers the attacker's capital requirement but adds no profit, and the grief is still transient and unprofitable, so the verdict (QA) is unchanged. **This is not a value leak or a solvency issue.**

**Re-file disclosure (prior owner triage on this code path)**:

- **M-02 `d7f6c2dfd580`** (false-positive, 2026-06-09), triage note verbatim:
  > "The use of convertToShares/convertToAssets is intentional — the design allows in-block swaps without MEV fear precisely because the AMM pool is concentrated liquidity. A small slippage tolerance covers 99% of deposit/withdrawal scenarios. The NAV reference is not exploitably skewed in this pool topology. No valid attack path."
- **M-02-run11 `c7329862eb0e`** (false-positive), suppression reason verbatim:
  > "donation to sUSDe is genuine non-recoverable yield (value-positive, self-defeating as attack). Deposit-DoS direction is backwards (higher share price lowers minOut). Withdraw-DoS requires the AMM/vault price to decouple and stay decoupled — closed by arbitrage and prevented by the NG rate oracle."
- **Why neither closure covers this finding**:
  - M-02 was closed under a *value-leak (sandwich)* framing ("no MEV fear", "no valid attack path" to extract value). QA-13 claims no extraction, only a same-bundle revert.
  - M-02-run11 was closed under a *persistent* withdraw-DoS framing that "requires the AMM/vault price to decouple and stay decoupled". QA-13 needs no persistent decoupling: the push and the revert happen in the same bundle, before any arbitrageur can act.
  - The finding is therefore re-filed at QA with disclosure. Neither closed framing is re-raised, and the donation variant (MR-003) was refuted on cost (about 0.24% of sUSDe `totalAssets`, about $2.8M gifted).
  - M-01-run12 `fdda8f53151a` (realizable-solvency framing) is also not re-raised.

**Escalation trigger**:
- LOW/MEDIUM if a revert can be made to consume a one-shot or time-bounded resource. Examples: Phase-2 state is reset before the swap without revert atomicity, or a V2 `initiateMigration` cannot be retried privately.
- This finding interacts with L-01. Repeated griefing pressures the owner to raise B, and raising B is the L-01/ECON-002 footgun trigger.

**Recommendation**: Route exits, skims, and `totalWithdrawal` Phase-2 through a private relay, and document that a revert at the floor is the expected protection working. Prefer private submission over raising `slippageToleranceBps`.

**Related**: L-01 `6460e35331df` (persistent-revert and cap variant), and L-22 `7a66fe7d5a96` (its quote-to-execute premise is gone; proposed obsolete below).

---

### [QA-14] `setRoute` validates `swap_type` with a denylist {0, 9} instead of Router NG v1.1's allowlist {1..8} <!-- id: ryv18q14 -->

**Severity**: QA (Law-3 footgun; follows the owner precedent for sya-harvester run-02 L-05)
**Fingerprint**: `46109c7be1f676f2c5d3ec1bc0ef80b613a97fa80f75f8c24fd85327c479ed91`
**Location**: [src/AMMAdapters/CurveAMMAdapter.sol:124-127](https://github.com/Behodler/reflax-yield-vault/blob/4788ed41747b923165745af748a078bfb534ba20/src/AMMAdapters/CurveAMMAdapter.sol#L124-L127). NatSpec at `:91-92` and `src/AMMAdapters/ICurveRouterNG.sol:19-20`.

```solidity
if (h < k) {
    uint256 swapType = swapParams[h][2];
    if (swapType == 0 || swapType == 9) revert InvalidRouteSwapParams(h);
}
```

**Description**: The check on an executed row's `swap_type` rejects only 0 and 9. Router NG v1.1 dispatches only swap types 1..8, so a `swap_type` from 10 to `type(uint256).max` is accepted and stored, and every later swap reverts until the owner overwrites the route. The NatSpec (`:91-92`) inherits the story's wording and reads as if `swap_type` validity is enforced. The code follows story-052 Technical Details step 7 to the letter ("not 0 and not 9"). The story itself lists fewer rejected values than Router NG actually rejects, which falls short of its own goal ("only store routes where the router actually delivers tokenOut"). The spec-conformance face of this issue is FAITH-001, and it is tracked under the same ledger entry.

**Impact**: No asset loss. The misconfiguration is authored by the owner, fails loudly on the first swap, and can be fixed by overwriting the route (there is no `clearRoute` lock-in). While the bad route is stored, the market strategy's `deposit`/`withdraw`/`skim` are frozen.

**Evidence**:
- Profiler probe `test_swapTypeAboveNineAccepted` PASS.
- Invariant P1 `RESIDUAL_swapTypeInRange` FAILs on forge and medusa, as expected.
- Halmos `check_residual_swapTypeInRange` FAILs, as expected. Its replay `test_replay_swapType12Accepted` PASSes (`work/test/symbolic/run18/SetRouteCexReplay.t.sol`).

**Escalation trigger**: LOW if an out-of-range `swap_type` is ever stored on a live adapter whose clients cannot exit during the overwrite window. M-05 (formerly L-30) matters here: the live adapter runs the older validator, which does not check `swap_type` at all.

**Recommendation**:

```solidity
if (swapType == 0 || swapType > 8) revert InvalidRouteSwapParams(h);
```

Avoid the `st - 1 >= 8` idiom, because it panics with 0x11 on zero. Amend story-052 step 7 to use an allowlist.

**Related**: L-07 `b28e77daefb3` (a sibling validation gap in `setRoute` with a different root), and L-10 `90f3fa166e20` (false-positive; concerned a different check that has since been deleted).

---

## Re-observed this run (still open; run-18 evidence materially changed)

None of these entries is re-filed or renumbered. Each body stays in its originating carryover file. The notes below record only what run 18 changed.

| Label | ID | Fingerprint | Carryover | What changed in run 18 |
|---|---|---|---|---|
| L-07 | `ryv7l7` | `b28e77daefb3` | [qa-report-07](carryover/qa-report-07.md) | **Partially fixed by story-052.** Halmos proves the internal zero-gap half fixed at HEAD (S1-S4 PASS, unbounded). The residual is the `tokenIn == tokenOut` self-pair and the unvalidated `i`/`j` coin indices. CODE-003 shows a wrong `i`/`j` fails loudly on live Router NG ("Received nothing"), and output can be stranded only if `slippageToleranceBps == MAX_BPS` and the router holds output-token dust, neither of which holds live. Severity stays Low, with QA possible after the narrowing (human). The zero-gap half is **not** fixed on the live adapter `0x2D02` (see M-05, formerly L-30). Keep the fingerprint and annotate the note with the residual scope. |
| L-23 | `ryv17l23` | `e6088a0ec55e` | [qa-report-17](carryover/qa-report-17.md) | **Documented trigger fired.** The trigger was "V2 wired ⇒ MEDIUM", and V2 is live. It was engaged explicitly, and the probe evidence refutes the harm: `OverDeliveryConservation.t.sol` shows the over-delivery comes from the AMM counterparty, not from co-clients or skim surplus. Co-client backing rises and surplus is unchanged. Under V2 an over-delivery mints no phUSD (delivered is capped at target, and the excess is forwarded to the caller). I4 held at all 589 cap-binds. Severity stays Low, because the undocumented surplus direction is a NatSpec mismatch (`:757-763`). **Erratum:** the run-17 note's claim that the over-delivery is paid from the commingled position is refuted. The human should correct the note and replace the "V2 ⇒ MEDIUM" trigger with these: (a) any path that disposes more than `convertToShares(amount)` (I9) or cap-binds while V ≥ D (I4); (b) a consumer that credits, mints, or re-stakes against the full delivered amount. |
| L-28 | `ryv17l28` | `38c9b2bae75f` | [qa-report-17](carryover/qa-report-17.md) | **New reachability path (I8 replay).** `work/test/invariant/run18/Run18I8Replay.t.sol` (18 steps, forge and medusa): a vault loss of about 3% plus a cap-bind exit sells all 58,535 shares while debiting only p1. Co-clients are left with 1,577.44e18 principal and 0 shares, and `totalWithdrawal(client2)` then "succeeds" without moving anything. This is the market-strategy site `ERC4626MarketYieldStrategy.sol:214-217` (formerly :293). Metadata gap: the `contract` field should list both strategy files (fingerprint unchanged). The market-only variant fingerprint `3cc33a9cd45b…` was computed but not minted, and maps back to L-28. Severity stays Low. |
| L-01 | `ryv5l1` † | `6460e35331df` | [qa-report-05](carryover/qa-report-05.md) | **New downstream consequence (ECON-002).** With V2 live, `slippageToleranceBps` is the only bound on V2's freshly minted phUSD top-up for USDe exits. At B = `MAX_BPS`, `minOut = 0` and the bound disappears. When the sUSDe discount widens past B, exits revert, and the natural remedy (raising B) raises the extractable phUSD ceiling. A competent owner would not expect this. Today B = 30, the extraction is reward-bounded, and a self-sandwich is unprofitable at live scale (headroom about 24 bps against a cost of about 101 sUSDe per 250k dump). Severity stays Low (borderline Low/Medium). Safe-config: cap B well below `MAX_BPS`. When exits revert, prefer pausing `autoAnnihilate` on the stable-staker side over a standing high B. Splitting the downstream-mint consequence into its own fingerprint is a human choice. **Final-review correction:** setting B = `MAX_BPS` (`minOut = 0`) is an obvious misconfiguration, so that sub-claim is trusted under Law 3 and carries no footgun weight. The valid footgun: **raising B to cure reverting exits silently raises StableStakerV2's phUSD-mint ceiling.** The Medium trigger is B above about 100 bps while material reward is owed, and it can be monitored through `SlippageToleranceSet`. QA-13's griefing pressure to raise B is cross-referenced here. |
| L-12 | `ryv11l12` † | `6e771a84e82d` | [qa-report-11](carryover/qa-report-11.md) | **Fork confirms `return == delivered`.** `LiveAdapterFork.t.sol::test_liveReturnEqualsDeliveredDelta` PASS. Through the live adapter, `swap()` returned exactly the USDe delta at `msg.sender`, and the adapter kept 0 of both tokens. Router NG prices each hop by its own `balanceOf(output)`, so a donation to the router only over-delivers to the next swapper, which the strategy forwards harmlessly. While T-1 holds (the router is genuine, immutable Router NG), no divergence path exists. L-12 stays open as defence-in-depth. `swap()` is byte-identical after story-052. |

† The ledger's `issueId` for this entry is `null`. The ID shown was derived per `docs/issue-id-scheme.md` (first-seen run plus original label) for finding-manager to back-fill. It is not yet authoritative.

---

## Proposed ledger actions (human)

These are proposals only. The pipeline applied none of them, and every status change requires a human `/ledger` command.

### Fixed by removal (story-051, `25276b8`, deleted `previewExitFor` / `_exitFloor`)

Evidence: a grep of `src/**/*.sol` (excluding `lib/`) at `4788ed4` finds no `previewExitFor` or `_exitFloor`. The code cannot come back: stable-staker `87b34c0` [story-027] pins vault `25276b8` and removed preview sizing (ECON-001b).

| Label | ID | Fingerprint | Command |
|---|---|---|---|
| L-18 | `ryv17l18` | `5351fd4d3f8c` | `/ledger reflax-yield-vault fixed 5351fd4d3f8c` |
| L-19 | `ryv17l19` | `302656e23443` | `/ledger reflax-yield-vault fixed 302656e23443` |
| L-20 | `ryv17l20` | `6f57473e6b01` | `/ledger reflax-yield-vault fixed 6f57473e6b01` |
| L-21 | `ryv17l21` | `833f7f6c728a` | `/ledger reflax-yield-vault fixed 833f7f6c728a` |
| L-24 | `ryv17l24` | `6476515055d8` | `/ledger reflax-yield-vault fixed 6476515055d8` |
| L-26 | `ryv17l26` | `63fa9e3e62bf` | `/ledger reflax-yield-vault fixed 63fa9e3e62bf` |
| QA-10 | `ryv17q10` | `e868f28953a9` | `/ledger reflax-yield-vault fixed e868f28953a9` |
| QA-11 | `ryv17q11` | `b5b58717f3b1` | `/ledger reflax-yield-vault fixed b5b58717f3b1` |
| INFO-01 | `ryv17i1` | `25d53af10717` | `/ledger reflax-yield-vault fixed 25d53af10717` |

These entries are still `open` and their bodies remain in [carryover/qa-report-17.md](carryover/qa-report-17.md) until a human disposes of them.

### Obsolete

| Label | ID | Fingerprint | Rationale | Command |
|---|---|---|---|---|
| L-22 | `ryv17l22` | `7a66fe7d5a96` | The premise ("quoted floor not honoured across the quote-to-execute gap") depended on `previewExitFor`'s quote, which story-051 deleted. `_disposeShares` itself survives. QA-13 now carries the revert-grief framing, and L-01 carries the persistent-revert framing. | `/ledger reflax-yield-vault fixed 7a66fe7d5a96` (or `wont-fix` "obsolete") |

### Expired wont-fix rationale (not a regression, not re-filed)

| Label | ID | Fingerprint | Status | Finding |
|---|---|---|---|---|
| L-02 | `ryv5l2` † | `81ee07506e42` | wont-fix | The triage reason was: *"This is almost certainly unlikely to become an issue as we're likely to never have more than 3 clients."* That numeric premise is false on-chain at block 26286995. The live USDe strategy has **four** authorized clients: OLD minter `0x435B…77E5`, V2 `0xA6d3…B58F`, new minter `0x9485…E60C`, and V1 `0xbce8…079A` (principal 0). The practical impact is unchanged, because a 4-iteration loop is nowhere near a gas brick. The same rationale also covers `ERC4626YieldStrategy._accrueSurplusShares`. **Action**: re-affirm wont-fix with a gas-bound rationale (`/ledger reflax-yield-vault wont-fix 81ee07506e42`), or deauthorize V1 via `setClient(V1, false)` to restore ≤ 3 clients. |

---

## Appendix: Automated findings (4naly3er)

**Status: ran successfully. 7/7 in-scope files, 0 import-resolution failures.** Raw output: [`reports/18/4naly3er-report.md`](../4naly3er-report.md) (2,910 lines).

**Invocation**:
- The first attempt used `basePath = reflax-yield-vault/src/` with the scope list as arg 3. It **failed** with `pauser/interfaces/IPausable.sol import not found` (solc-js `TypeError ... reading 'contents'`), because the committed `src/remappings.txt` holds only the `@openzeppelin` mapping. The `pauser/` remapping exists only in `foundry.toml`.
- The re-run used a scratchpad staging directory: a byte-identical copy of `src/src` (verified with `diff -r`), `lib/` symlinked to the submodule's `lib/`, and `remappings.txt` produced by `forge remappings`. It succeeded. The read-only submodule and `work/` were not modified.

**Totals**:

| Category | Issue types | Instances |
|---|---|---|
| High | 0 | 0 |
| Medium | 3 | 20 |
| Low | 13 | 43 |
| Non-Critical | 24 | 201 |
| Gas | 16 | 270 |

**Bot-tier dispositions.** None of these items was promoted to a finding. This output is the automated baseline, and C4 treats it as known or bot-reported.
- **M-1 (fee-on-transfer)**: invalid per C4 known-invalid rules. FoT tokens are not in scope (USDe/sUSDe/DOLA/USDC).
- **M-2 (centralization, 15 instances)**: the owner is trusted for knowing actions (Law 3). The general owner-privilege surface is already carried as run-05 C-01 ([carryover/qa-report-05.md](carryover/qa-report-05.md)). The non-obvious owner footguns are M-05 (formerly L-30; submitted separately), L-32, QA-14 and the L-01 update.
- **M-3 (USDT `increaseAllowance`)**: not applicable. OpenZeppelin 5.4.0's `safeIncreaseAllowance` calls `forceApprove`, which is USDT-safe, and no in-scope underlying is USDT.
- **L-1..L-13 and the NC/Gas items** are generic patterns. None of them shows a High/Medium path. L-6 (division by zero) and L-8/L-9 (rounding and precision) cover lines that the manual and invariant passes exercised, and none of them produced a finding this run.

Below are the Low and Medium sections reproduced verbatim from the raw report, followed by the Non-Critical and Gas indexes. Full NC and Gas instance bodies are only in the raw file, so the NC/GAS anchor links below resolve only in [`4naly3er-report.md`](../4naly3er-report.md).


### 4naly3er: Medium and Low sections (verbatim)

#### Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | `approve()`/`safeApprove()` may revert if the current approval is not zero | 1 |
| [L-2](#L-2) | Use a 2-step ownership transfer pattern | 2 |
| [L-3](#L-3) | Some tokens may revert when zero value transfers are made | 2 |
| [L-4](#L-4) | Missing checks for `address(0)` when assigning values to address state variables | 1 |
| [L-5](#L-5) | `abi.encodePacked()` should not be used with dynamic types when passing the result to a hash function such as `keccak256()` | 2 |
| [L-6](#L-6) | Division by zero not prevented | 7 |
| [L-7](#L-7) | Owner can renounce while system is paused | 1 |
| [L-8](#L-8) | Possible rounding issue | 7 |
| [L-9](#L-9) | Loss of precision | 11 |
| [L-10](#L-10) | Solidity version 0.8.20+ may not work on other chains due to `PUSH0` | 3 |
| [L-11](#L-11) | Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership` | 2 |
| [L-12](#L-12) | File allows a version of solidity that is susceptible to an assembly optimizer bug | 3 |
| [L-13](#L-13) | Unsafe ERC20 operation(s) | 1 |
##### <a name="L-1"></a>[L-1] `approve()`/`safeApprove()` may revert if the current approval is not zero
- Some tokens (like the *very popular* USDT) do not work when changing the allowance from an existing non-zero allowance value (it will revert if the current approval is not zero to protect against front-running changes of approvals). These tokens must first be approved for zero and then the actual allowance can be approved.
- Furthermore, OZ's implementation of safeApprove would throw an error if an approve is attempted from a non-zero value (`"SafeERC20: approve from non-zero to non-zero allowance"`)

Set the allowance to zero immediately before each of the existing allowance calls

*Instances (1)*:
```solidity
File: src/concreteYieldStrategies/ERC4626YieldStrategy.sol

50:         IERC20(_underlyingToken).approve(_erc4626Vault, type(uint256).max);

```

##### <a name="L-2"></a>[L-2] Use a 2-step ownership transfer pattern
Recommend considering implementing a two step process where the owner or admin nominates an account and the nominated account needs to call an `acceptOwnership()` function for the transfer of ownership to fully succeed. This ensures the nominated EOA account is a valid and active account. Lack of two-step procedure for critical operations leaves them error-prone. Consider adding two step procedure on the critical functions.

*Instances (2)*:
```solidity
File: src/AMMAdapters/CurveAMMAdapter.sol

25: contract CurveAMMAdapter is IAMMAdapter, Ownable {

```

```solidity
File: src/AYieldStrategy.sol

18: abstract contract AYieldStrategy is IYieldStrategy, IPausable, Ownable, ReentrancyGuard, Pausable {

```

##### <a name="L-3"></a>[L-3] Some tokens may revert when zero value transfers are made
Example: https://github.com/d-xo/weird-erc20#revert-on-zero-value-transfers.

In spite of the fact that EIP-20 [states](https://github.com/ethereum/EIPs/blob/46b9b698815abbfa628cd1097311deee77dd45c5/EIPS/eip-20.md?plain=1#L116) that zero-valued transfers must be accepted, some tokens, such as LEND will revert if this is attempted, which may cause transactions that involve other tokens (such as batch operations) to fully revert. Consider skipping the transfer if the amount is zero, which will also save gas.

*Instances (2)*:
```solidity
File: src/AMMAdapters/CurveAMMAdapter.sol

186:         IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

```

```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

199:         IERC20(address(vault)).safeTransfer(owner(), sharesToTransfer);

```

##### <a name="L-4"></a>[L-4] Missing checks for `address(0)` when assigning values to address state variables

*Instances (1)*:
```solidity
File: src/AYieldStrategy.sol

368:         emit PauserSet(oldPauser, newPauser);

```

##### <a name="L-5"></a>[L-5] `abi.encodePacked()` should not be used with dynamic types when passing the result to a hash function such as `keccak256()`
Use `abi.encode()` instead which will pad items to 32 bytes, which will [prevent hash collisions](https://docs.soliditylang.org/en/v0.8.13/abi-spec.html#non-standard-packed-mode) (e.g. `abi.encodePacked(0x123,0x456)` => `0x123456` => `abi.encodePacked(0x1,0x23456)`, but `abi.encode(0x123,0x456)` => `0x0...1230...456`). "Unless there is a compelling reason, `abi.encode` should be preferred". If there is only one argument to `abi.encodePacked()` it can often be cast to `bytes()` or `bytes32()` [instead](https://ethereum.stackexchange.com/questions/30912/how-to-compare-strings-in-solidity#answer-82739).
If all arguments are strings and or bytes, `bytes.concat()` should be used instead

*Instances (2)*:
```solidity
File: src/AYieldStrategy.sol

439:                         "AYieldStrategy: withdrawal still in waiting period, executable at timestamp: ",

440:                         _uint256ToString(executableAt)

```

##### <a name="L-6"></a>[L-6] Division by zero not prevented
The divisions below take an input parameter which does not have any zero-value checks, which may lead to the functions reverting when zero is passed.

*Instances (7)*:
```solidity
File: src/AYieldStrategy.sol

549:         return (totalValue * principal) / totalDeposited[token];

```

```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

220:         uint256 sharesToSell = (totalShares * clientStoredBalance) / totalDeposited[token];

325:                 uint256 total = (totalValue * principal) / td; // == totalBalanceOf(client)

360:             uint256 buf = underlyingReceived * bufferShares[i] / totalShares; // actual-tokens, proportional

```

```solidity
File: src/concreteYieldStrategies/ERC4626YieldStrategy.sol

190:         uint256 sharesToWithdraw = (totalShares * clientStoredBalance) / totalDeposited[token];

282:                 uint256 total = (totalValue * principal) / td; // == totalBalanceOf(client)

317:             uint256 buf = underlyingReceived * bufferShares[i] / totalShares; // actual-tokens, proportional

```

##### <a name="L-7"></a>[L-7] Owner can renounce while system is paused
The contract owner or single user with a role is not prevented from renouncing the role/ownership while the contract is paused, which would cause any user assets stored in the protocol, to be locked indefinitely.

*Instances (1)*:
```solidity
File: src/AYieldStrategy.sol

364:     function setPauser(address newPauser) external onlyOwner {

```

##### <a name="L-8"></a>[L-8] Possible rounding issue
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator. Also, there is indication of multiplication and division without the use of parenthesis which could result in issues.

*Instances (7)*:
```solidity
File: src/AYieldStrategy.sol

549:         return (totalValue * principal) / totalDeposited[token];

```

```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

220:         uint256 sharesToSell = (totalShares * clientStoredBalance) / totalDeposited[token];

325:                 uint256 total = (totalValue * principal) / td; // == totalBalanceOf(client)

360:             uint256 buf = underlyingReceived * bufferShares[i] / totalShares; // actual-tokens, proportional

```

```solidity
File: src/concreteYieldStrategies/ERC4626YieldStrategy.sol

190:         uint256 sharesToWithdraw = (totalShares * clientStoredBalance) / totalDeposited[token];

282:                 uint256 total = (totalValue * principal) / td; // == totalBalanceOf(client)

317:             uint256 buf = underlyingReceived * bufferShares[i] / totalShares; // actual-tokens, proportional

```

##### <a name="L-9"></a>[L-9] Loss of precision
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator

*Instances (11)*:
```solidity
File: src/AYieldStrategy.sol

549:         return (totalValue * principal) / totalDeposited[token];

```

```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

107:         return amount * (MAX_BPS - slippageToleranceBps) / MAX_BPS;

168:         uint256 minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;

220:         uint256 sharesToSell = (totalShares * clientStoredBalance) / totalDeposited[token];

225:             uint256 minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;

276:         uint256 minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;

325:                 uint256 total = (totalValue * principal) / td; // == totalBalanceOf(client)

360:             uint256 buf = underlyingReceived * bufferShares[i] / totalShares; // actual-tokens, proportional

```

```solidity
File: src/concreteYieldStrategies/ERC4626YieldStrategy.sol

190:         uint256 sharesToWithdraw = (totalShares * clientStoredBalance) / totalDeposited[token];

282:                 uint256 total = (totalValue * principal) / td; // == totalBalanceOf(client)

317:             uint256 buf = underlyingReceived * bufferShares[i] / totalShares; // actual-tokens, proportional

```

##### <a name="L-10"></a>[L-10] Solidity version 0.8.20+ may not work on other chains due to `PUSH0`
The compiler for Solidity 0.8.20 switches the default target EVM version to [Shanghai](https://blog.soliditylang.org/2023/05/10/solidity-0.8.20-release-announcement/#important-note), which includes the new `PUSH0` op code. This op code may not yet be implemented on all L2s, so deployment on these chains will fail. To work around this issue, use an earlier [EVM](https://docs.soliditylang.org/en/v0.8.20/using-the-compiler.html?ref=zaryabs.com#setting-the-evm-version-to-target) [version](https://book.getfoundry.sh/reference/config/solidity-compiler#evm_version). While the project itself may or may not compile with 0.8.20, other projects with which it integrates, or which extend this project may, and those projects will have problems deploying these contracts/libraries.

*Instances (3)*:
```solidity
File: src/AMMAdapters/CurveAMMAdapter.sol

2: pragma solidity ^0.8.13;

```

```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

2: pragma solidity ^0.8.13;

```

```solidity
File: src/concreteYieldStrategies/ERC4626YieldStrategy.sol

2: pragma solidity ^0.8.13;

```

##### <a name="L-11"></a>[L-11] Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership`
Use [Ownable2Step.transferOwnership](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable2Step.sol) which is safer. Use it as it is more secure due to 2-stage ownership transfer.

**Recommended Mitigation Steps**

Use <a href="https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable2Step.sol">Ownable2Step.sol</a>
  
  ```solidity
      function acceptOwnership() external {
          address sender = _msgSender();
          require(pendingOwner() == sender, "Ownable2Step: caller is not the new owner");
          _transferOwnership(sender);
      }
```

*Instances (2)*:
```solidity
File: src/AMMAdapters/CurveAMMAdapter.sol

6: import "@openzeppelin/contracts/access/Ownable.sol";

```

```solidity
File: src/AYieldStrategy.sol

6: import "@openzeppelin/contracts/access/Ownable.sol";

```

##### <a name="L-12"></a>[L-12] File allows a version of solidity that is susceptible to an assembly optimizer bug
In solidity versions 0.8.13 and 0.8.14, there is an [optimizer bug](https://github.com/ethereum/solidity-blog/blob/499ab8abc19391be7b7b34f88953a067029a5b45/_posts/2022-06-15-inline-assembly-memory-side-effects-bug.md) where, if the use of a variable is in a separate `assembly` block from the block in which it was stored, the `mstore` operation is optimized out, leading to uninitialized memory. The code currently does not have such a pattern of execution, but it does use `mstore`s in `assembly` blocks, so it is a risk for future changes. The affected solidity versions should be avoided if at all possible.

*Instances (3)*:
```solidity
File: src/AMMAdapters/CurveAMMAdapter.sol

2: pragma solidity ^0.8.13;

```

```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

2: pragma solidity ^0.8.13;

```

```solidity
File: src/concreteYieldStrategies/ERC4626YieldStrategy.sol

2: pragma solidity ^0.8.13;

```

##### <a name="L-13"></a>[L-13] Unsafe ERC20 operation(s)

*Instances (1)*:
```solidity
File: src/concreteYieldStrategies/ERC4626YieldStrategy.sol

50:         IERC20(_underlyingToken).approve(_erc4626Vault, type(uint256).max);

```


#### Medium Issues


| |Issue|Instances|
|-|:-|:-:|
| [M-1](#M-1) | Contracts are vulnerable to fee-on-transfer accounting-related issues | 1 |
| [M-2](#M-2) | Centralization Risk for trusted owners | 15 |
| [M-3](#M-3) | `increaseAllowance/decreaseAllowance` won't work on mainnet for USDT | 4 |
##### <a name="M-1"></a>[M-1] Contracts are vulnerable to fee-on-transfer accounting-related issues
Consistently check account balance before and after transfers for Fee-On-Transfer discrepancies. As arbitrary ERC20 tokens can be used, the amount here should be calculated every time to take into consideration a possible fee-on-transfer or deflation.
Also, it's a good practice for the future of the solution.

Use the balance before and after the transfer to calculate the received amount instead of assuming that it would be equal to the amount passed as a parameter. Or explicitly document that such tokens shouldn't be used and won't be supported

*Instances (1)*:
```solidity
File: src/AMMAdapters/CurveAMMAdapter.sol

186:         IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

```

##### <a name="M-2"></a>[M-2] Centralization Risk for trusted owners

#### Impact:
Contracts have owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds.

*Instances (15)*:
```solidity
File: src/AMMAdapters/CurveAMMAdapter.sol

25: contract CurveAMMAdapter is IAMMAdapter, Ownable {

71:     constructor(address _owner, address _router) Ownable(_owner) {

102:     ) external onlyOwner {

```

```solidity
File: src/AYieldStrategy.sol

18: abstract contract AYieldStrategy is IYieldStrategy, IPausable, Ownable, ReentrancyGuard, Pausable {

250:     constructor(address _owner, address _underlyingToken) Ownable(_owner) {

265:     function setClient(address client, bool _auth) external override onlyOwner {

309:     function setWithdrawer(address withdrawer, bool _auth) external onlyOwner {

335:     function setSetAsideBuffer(address client, uint256 bufferPercent) external override onlyOwner {

352:     function setSetAsideBufferRecipient(address _recipient) external onlyOwner {

364:     function setPauser(address newPauser) external onlyOwner {

402:     function emergencyWithdraw(uint256 amount) external override onlyOwner {

417:     function totalWithdrawal(address token, address client) external override onlyOwner nonReentrant whenNotPaused {

644:     function withdrawAsOwner(address client, address recipient, uint256 amount) external onlyOwner nonReentrant {

654:     function relinquishPrincipalAsOwner(address client, uint256 amount) external override onlyOwner nonReentrant {

```

```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

88:     function setSlippageTolerance(uint256 _bps) external onlyOwner {

```

##### <a name="M-3"></a>[M-3] `increaseAllowance/decreaseAllowance` won't work on mainnet for USDT
On mainnet, the mitigation to be compatible with `increaseAllowance/decreaseAllowance` isn't applied: https://etherscan.io/token/0xdac17f958d2ee523a2206206994597c13d831ec7#code, meaning it reverts on setting a non-zero & non-max allowance, unless the allowance is already zero.

*Instances (4)*:
```solidity
File: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol

142:         underlyingToken.safeIncreaseAllowance(address(ammAdapter), amount);

171:         IERC20(address(vault)).safeIncreaseAllowance(address(ammAdapter), sharesToSell);

228:             IERC20(address(vault)).safeIncreaseAllowance(address(ammAdapter), sharesToSell);

277:         IERC20(address(vault)).safeIncreaseAllowance(address(ammAdapter), totalShares);

```


### 4naly3er: Non-Critical index

#### Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | Missing checks for `address(0)` when assigning values to address state variables | 1 |
| [NC-2](#NC-2) | Array indices should be referenced via `enum`s rather than via numeric literals | 2 |
| [NC-3](#NC-3) | Use `string.concat()` or `bytes.concat()` instead of `abi.encodePacked` | 1 |
| [NC-4](#NC-4) | `constant`s should be defined rather than using magic numbers | 11 |
| [NC-5](#NC-5) | Control structures do not follow the Solidity Style Guide | 23 |
| [NC-6](#NC-6) | Consider disabling `renounceOwnership()` | 2 |
| [NC-7](#NC-7) | Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function | 22 |
| [NC-8](#NC-8) | Event missing indexed field | 1 |
| [NC-9](#NC-9) | Events that mark critical parameter changes should contain both the old and the new value | 7 |
| [NC-10](#NC-10) | Function ordering does not follow the Solidity style guide | 4 |
| [NC-11](#NC-11) | Functions should not be longer than 50 lines | 75 |
| [NC-12](#NC-12) | Lack of checks in setters | 1 |
| [NC-13](#NC-13) | Incomplete NatSpec: `@return` is missing on actually documented functions | 1 |
| [NC-14](#NC-14) | Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor | 4 |
| [NC-15](#NC-15) | Consider using named mappings | 6 |
| [NC-16](#NC-16) | Owner can renounce while system is paused | 1 |
| [NC-17](#NC-17) | Adding a `return` statement when the function defines a named return variable, is redundant | 16 |
| [NC-18](#NC-18) | Take advantage of Custom Error's return value property | 1 |
| [NC-19](#NC-19) | Contract does not follow the Solidity style guide's suggested layout ordering | 2 |
| [NC-20](#NC-20) | Use Underscores for Number Literals (add an underscore every 3 digits) | 1 |
| [NC-21](#NC-21) | Internal and private variables and functions names should begin with an underscore | 3 |
| [NC-22](#NC-22) | Event is missing `indexed` fields | 9 |
| [NC-23](#NC-23) | `public` functions not called by the contract should be declared `external` instead | 1 |
| [NC-24](#NC-24) | Variables need not be initialized to zero | 6 |

### 4naly3er: Gas index

#### Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings) | 8 |
| [GAS-2](#GAS-2) | Use assembly to check for `address(0)` | 26 |
| [GAS-3](#GAS-3) | Using bools for storage incurs overhead | 1 |
| [GAS-4](#GAS-4) | Cache array length outside of loop | 4 |
| [GAS-5](#GAS-5) | State variables should be cached in stack variables rather than re-reading them from storage | 3 |
| [GAS-6](#GAS-6) | For Operations that will not overflow, you could use unchecked | 100 |
| [GAS-7](#GAS-7) | Use Custom Errors instead of Revert Strings to save Gas | 53 |
| [GAS-8](#GAS-8) | Avoid contract existence checks by using low level calls | 13 |
| [GAS-9](#GAS-9) | Stack variable used as a cheaper cache for a state variable is only used once | 3 |
| [GAS-10](#GAS-10) | State variables only set in the constructor should be declared `immutable` | 5 |
| [GAS-11](#GAS-11) | Functions guaranteed to revert when called by normal users can be marked `payable` | 12 |
| [GAS-12](#GAS-12) | `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`) | 9 |
| [GAS-13](#GAS-13) | Using `private` rather than `public` for constants, saves gas | 4 |
| [GAS-14](#GAS-14) | Use of `this` instead of marking as `public` an `external` function | 2 |
| [GAS-15](#GAS-15) | Increments/decrements can be unchecked in for-loops | 8 |
| [GAS-16](#GAS-16) | Use != 0 instead of > 0 for unsigned integer comparison | 19 |
