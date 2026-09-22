# Spec Conformance (Law 2): phoenix-phase-2-staging, script audit run 37 (`stable-staker-v2-cutover`)

- **Repository**: https://github.com/Behodler/phoenix-phase-2-staging
- **Commit**: `1349be82a717fcf9a30725d2e9cc047b4f3721d6` (branch `master`), subject "Cutover: ZERO set-aside buffer for V2 on the sDOLA destination strategy". The commit has no `[story-NNN]` tag.
- **Entry point**: `stable-staker-v2-cutover` (baselined at `91ed727`, run 36)
- **Faithfulness findings**: 1. **F-05** (`pps37f5`), Low, standalone. It has no H/M counterpart because it has no asset, value or availability impact. `F-05` comes after `F-04` (run 36, a cross-reference of M-01 `pps36m1`) in this entry point's F sequence.

## Story resolution

Each tag was resolved by globbing the whole `~/code/product-owner/stories/phStaging2/` tree. Each matched exactly one document. The tree's latest story is 097, and no story in it records the zero-buffer decision.

| Story | Path (under `~/code/product-owner/stories/phStaging2/`) | State folder |
|---|---|---|
| 091 | `auto-complete/phStaging2-stable-staker-v2/091-cutover-sdola-strategy-source-destination-split.md` | `auto-complete` |
| 082 | `auto-complete/phStaging2-stable-staker-v2/082-mainnet-stable-staker-v2-cutover-script.md` | `auto-complete` |

`auto-complete` is a final state, equivalent to `complete`.

---

## F-05 (`pps37f5`): zero set-aside buffer on the sDOLA destination departs from story 091 Decision 6 and story 082 Phase 4, and no story authorises it

- **Fingerprint**: `566ff01323c3ded2012685017a40ec662f67f8fcd574576333a505f7ba4ebfdf`
  (`sha256("lib/phoenix-phase-2-staging/script/CutoverStableStakerV2Mainnet.s.sol:_targetBufferPct:UnauthorisedStoryDeviation:stable-staker-v2-cutover")`, reproduces)
- **Location**: [`script/CutoverStableStakerV2Mainnet.s.sol#L2102-L2105`](https://github.com/Behodler/phoenix-phase-2-staging/blob/1349be82a717fcf9a30725d2e9cc047b4f3721d6/script/CutoverStableStakerV2Mainnet.s.sol#L2102-L2105) (`_targetBufferPct`)
- **Severity**: Low (faithfulness only). **Status**: open.
- **Record**: `reports/37/findings/faithfulness/stable-staker-v2-cutover__F-05.json`

### What the stories say

**Story 091 (`auto-complete`), L97, verbatim:**
> Read V1's buffer pct from the source strategy and apply it to the destination for V2 (`setSetAsideBuffer(V2, pct)`).

**Story 091 (`auto-complete`), Decision 6, verbatim** (the classifier cited L196; the text is on **L197**, inside the line's "**Decision**" bullet):
> V2's buffer pct on the destination = V1's pct read from the source in Phase 0.

**Story 082 (`auto-complete`), Phase 4, L73, verbatim excerpt:**
> `setSetAsideBuffer(v2, <value read from V1>)`

**Story 082 (`auto-complete`), result, L172, verbatim:**
> **Set-aside buffers copied**: DOLA 10%, USDC 10%, USDe 25%.

### What the code does

At `1349be8`, `_targetBufferPct` returns `0` for any token whose destination is the sDOLA strategy, which in practice means DOLA. Every other token still gets `v1BufferPct[t]`:

```solidity
function _targetBufferPct(address t) internal view returns (uint256) {
    if (_destinationStrategyFor(t) == address(sdolaStrategy)) return 0; // DOLA only
    return v1BufferPct[t];
}
```

Both stories say V2's DOLA buffer pct must be V1's pct (10%). The code sets 0 and asserts 0 in Phase 4, Phase 8 and the verifier. The NatSpec at L2092-2101 gives the reason, but no story or decision record makes the change, and the commit that made it has no story tag.

### Impact

None to assets, value or availability. Under Law 1 the deviation is the **safer** choice. The fork harness `work/test/audit-run37/SdolaZeroBuffer.fork.t.sol` (5/5 pass, reproduced) shows that V2 on the sDOLA strategy cannot go below par without an owner `emergencyWithdraw`. A 10% pct would idle about 10% of DOLA yield, and that yield could only be recovered by `rescueERC20`. This finding is about traceability: the code no longer matches the stories that define it.

Related (not F-class): L-13 (`pps37l13`, `071ce9f9120a…`), the stale runbook comment at `package.json` L49, and Q-07 (`pps37q7`, `7c0c0c7c443a…`), the migration rounding cushion that a zero buffer removes. Both are in `qa-report.md`.

### Recommendation

Keep the code. Write a story or decision record that amends 091 Decision 6 and 082 Phase 4 (L73) to say that V2's set-aside buffer pct on the sDOLA destination is 0, with the monotone-rate / no-yield-diversion rationale already in the `_targetBufferPct` NatSpec (L2094-2101). Tag the commit that lands it. Optionally note the 082 L172 "DOLA 10%" result as superseded.
