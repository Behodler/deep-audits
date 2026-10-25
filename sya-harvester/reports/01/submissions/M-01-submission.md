<!--
ID: sh1m1
C4 Submission Metadata
Title: [M-01] `setRoute` validates the last non-zero path entry, but Curve Router NG stops at the first empty pool slot, so a gapped route is accepted and silently strands the intermediate token
Severity: Medium (non-obvious owner footgun, Law 3)
Root Cause Link: https://github.com/Behodler/sya-harvester/blob/62c19c86be1594dcf82e8af794fcd6c28f9a8fc0/src/SYAHarvester.sol#L124-L149
Ledger fingerprint: 004d4547d93b2d4431753bd11b17f2c86b50e65d1eaa37b530f34188feb739a3
Fingerprint input: src/SYAHarvester.sol:setRoute:validation-diverges-from-executor-semantics
Run: sya-harvester-01, commit 62c19c86be1594dcf82e8af794fcd6c28f9a8fc0 (branch master)
PoC File: M-01-poc.t.sol (diff: M-01-poc.diff, run log: M-01-poc-run.txt)
Cross-references: F-02 (spec-conformance, story-unsafe), Q-03 / sh1q3 (no rescue path), Q-06 / sh1q6 (test-suite fidelity)
-->

## Finding description and impact

### Summary

`SYAHarvester.setRoute` checks that the **last non-zero entry** of the 11-slot `path` equals `sya.rewardToken()`. Curve Router NG, which executes the route, does not use that rule. It stops at the **first empty pool slot** and pays out the token in the slot before it. A route with an empty middle slot, for example `[USDe, poolUSDe/crvUSD, crvUSD, 0, …, 0, USDC]`, passes the validator because USDC is the last non-zero entry. Router NG executes only the first hop and delivers crvUSD.

The harvest then completes without reverting whenever other proceeds cover the flash borrow. The caller has paid SYA the discounted price for that strategy's yield, but the sale proceeds stay in the harvester as an intermediate token that no code path ever sells or sweeps. This repeats on every harvest until someone notices the route.

- Severity: **Medium**
- Ledger fingerprint: `004d4547d93b2d4431753bd11b17f2c86b50e65d1eaa37b530f34188feb739a3`
- Issue ID: `sh1m1`
- Root cause: [`src/SYAHarvester.sol#L124-L149`](https://github.com/Behodler/sya-harvester/blob/62c19c86be1594dcf82e8af794fcd6c28f9a8fc0/src/SYAHarvester.sol#L124-L149) (validator loop [L133-L140](https://github.com/Behodler/sya-harvester/blob/62c19c86be1594dcf82e8af794fcd6c28f9a8fc0/src/SYAHarvester.sol#L133-L140)), commit `62c19c8` on `master`

### Root cause

The validator in [`SYAHarvester.sol#L133-L140`](https://github.com/Behodler/sya-harvester/blob/62c19c86be1594dcf82e8af794fcd6c28f9a8fc0/src/SYAHarvester.sol#L133-L140) scans all 11 slots and keeps the last non-zero one:

```solidity
address last;
for (uint256 i = 0; i < 11; i++) {
    if (path[i] != address(0)) {
        last = path[i];
    }
}
address rewardToken = sya.rewardToken();
if (last != rewardToken) revert InvalidRouteEnd(rewardToken, last);
```

`swapParams` and `pools` are stored without any check against `path`.

The router runs a different rule. In the verified Etherscan source of Curve Router NG v1.1 (`0x16C6521Dff6baB339122a0FE25a9116693265353`, Vyper 0.3.10), `exchange` sets `output_token = _route[(i + 1) * 2]` for each hop `i`, performs the swap, and then ends the loop:

```python
# check if this was the last swap
if i == 4 or _route[i * 2 + 3] == empty(address):
    break
# if there is another swap, the output token becomes the input for the next round
input_token = output_token
```

After the loop the router transfers `output_token` to the receiver. So for a path whose first empty pool slot is `path[2k+1]`, the delivered token is `path[2k]`. Any non-zero entries after that point, including a trailing reward token, are ignored. The validator and the executor disagree exactly when the path has an interior gap.

[`_sellYield`](https://github.com/Behodler/sya-harvester/blob/62c19c86be1594dcf82e8af794fcd6c28f9a8fc0/src/SYAHarvester.sol#L306-L321) passes `min_dy = 0` to the router and never checks which token arrived. The only backstop is the subtraction at [L290-L291](https://github.com/Behodler/sya-harvester/blob/62c19c86be1594dcf82e8af794fcd6c28f9a8fc0/src/SYAHarvester.sol#L290-L291), `balanceOf(reward) - owed`. That backstop fires only if the misrouted leg leaves too little reward token to repay the borrow. If the other legs (or the 1% `BORROW_BUFFER_BPS` headroom) cover `owed`, it does not fire.

The intermediate token is then lost for good. `_sellYield` iterates only over SYA strategy tokens. crvUSD is not one, so it is never sold, and the contract has no sweep or rescue function (Q-03 / `sh1q3`).

The Halmos run in this audit confirms that the interior gap is the **only** shape that misroutes silently:

| Check | Result | What it shows |
|---|---|---|
| `check_A1` / `check_A2` | FAIL | Witness: `path[0..8]` non-zero, `path[9] = 0`, `path[10] = USDC`. The router delivers `path[8]`. |
| `check_A3_noGapImpliesCorrectDelivery` | PASS | Every route the real `setRoute` accepts that has no interior gap either delivers the reward token or reverts loudly. |
| `check_A4_oddIndexEndNoGapIsLoud` | PASS | An accepted gap-free route that ends in a pool slot always reverts. |

`route_exhaustive.py` enumerated the full equality abstraction `{0,T,R,X,P}^10`: 9.7M paths, 2.44M of them accepted. It found 0 silent misroutes without a gap.

### Why this is an owner footgun (Law 3)

Only the owner can call `setRoute`, and the owner is assumed non-malicious. The precondition is an honest configuration slip: a two-hop route whose second pool address came out as `address(0)` (an unset deployment variable, a typo, or a route padded so the reward token sits in slot 10), with the reward token still entered later in the array.

This is not obvious misuse. `setRoute` presents itself as the route-end guard, and its NatSpec says it requires "that the last non-zero entry of `path` equals `sya.rewardToken()`". The PoC shows that the guard rejects a route that visibly ends at the intermediate token (`InvalidRouteEnd(USDC, crvUSD)`). It accepts the same executed route once a trailing USDC is added. An owner who has watched the validator reject wrong route ends would reasonably expect it to reject a route with a missing hop. They would be surprised to find that such a route is stored and then pays every harvest's proceeds into a dead balance with no revert and no event. That surprise is what makes this a footgun under Law 3, so it is classified by the impact it enables.

The rule comes from the specification itself (F-02, story-unsafe). Story-001 (`~/code/product-owner/stories/sya-harvester/auto-complete/sya-harvester-harvester-v1/001-dependencies-skeleton-route-registry.md`, Technical Details) prescribes it:

> `setRoute` validates `path[0] == token` (and that `token != address(0)`). It also checks that the last non-zero entry of `path` equals `sya.rewardToken()`, read at call time. Use the CurveAMMAdapter loop as the template.

The implementation follows story-001 faithfully. However, the rule cannot uphold story-002's acceptance criterion (`002-core-harvest-v4-unlock.md`, Acceptance):

> After a successful harvest the contract holds zero balances of every token.

It also cannot uphold the design invariant in `src/CLAUDE.md`: "The contract holds no balances between calls." Under Law 1 over Law 2, this is reported against both the code and the story rule.

The bug does not appear in the project's unit tests because `test/mocks/MockCurveRouter.sol` implements the same last-non-zero rule ("`_amount * rate[_route[0]] / 1e18` of the route's last non-zero token"). The mock therefore delivers the reward token on a gapped route, which the real router never does (Q-06 / `sh1q6`). The `ICurveRouterNG` NatSpec shows the contiguous layout but does not say that the router stops at the first empty slot.

### Impact

When a gapped route is stored for a strategy token, and other proceeds cover the flash borrow, every harvest has this outcome:

- SYA is paid in full for that strategy's yield. Protocol (SYA) funds are not at risk.
- The router delivers the intermediate token instead of the reward token. The whole sale output for that leg stays in the harvester.
- The harvest succeeds and pays the caller less ETH than the correct route would. Nothing reverts and no event flags the shortfall.
- The stranded balance is permanent. It is not a strategy token, so `_sellYield` never touches it, and there is no sweep (Q-03). A later harvest would sell it only if the intermediate token happened to be another routed strategy token. Even then, the value would move to an unrelated later caller rather than back to the caller who lost it.
- The loss repeats on every harvest until the route is noticed and replaced.

The loss falls on harvest callers. `harvest` is permissionless, so these include third parties as well as the operator. Per harvest, the loss is limited to one strategy's yield proceeds.

**Silence is conditional.** If the misrouted leg's proceeds are needed to repay `owed`, the subtraction at L291 underflows and the harvest reverts loudly. The silent loss only happens while other legs cover the borrow.

**The operator script was not tested.** `script/harvest.sh` computes `minEthOut` from an `eth_call` simulation, and that simulation would already include the misrouted leg. On that reasoning, the caller's slippage bound would not catch the loss. The PoC does not run `harvest.sh` and passes `minEthOut = 0`, so this point is reasoned, not demonstrated.

### Proof of concept

The PoC is supplied separately, in the C4 PoC field:

| File | Path |
|---|---|
| Test | `reports/01/pocs/M-01-poc.t.sol` |
| Diff | `reports/01/pocs/M-01-poc.diff` (adds `test/poc-M-01-gap-route-strand.t.sol`) |
| Run log | `reports/01/pocs/M-01-poc-run.txt` |

The diff applies cleanly at `62c19c86be1594dcf82e8af794fcd6c28f9a8fc0`. The test inherits the project's own mainnet fork fixture, `test/fork/SYAHarvester.fork.t.sol`: pinned block 26261000, the shipped `MainnetRoutes.configure`, and a keeper that holds the claim NFT.

Run it with:

```bash
git apply M-01-poc.diff
MAINNET_RPC_URL=<archive rpc> forge test --match-path test/poc-M-01-gap-route-strand.t.sol -vvv
```

Result: `Suite result: ok. 15 passed; 0 failed` (3 M-01 tests plus the 12 inherited fixture tests).

**`test_M01_validator_acceptsGap_rejectsHonestWrongEnd`**
- `setRoute(USDe, [USDe, poolUSDe/crvUSD, crvUSD, 0, …], …)` reverts `InvalidRouteEnd(USDC, crvUSD)`.
- The same route with `path[10] = USDC` added is accepted and stored.

**`test_M01_control_contiguousRoute_leavesNoCrvUsd`**
- With the shipped contiguous route, the router pays USDC for both legs and the harvester ends with no balances.

**`test_M01_gapRoute_strandsCrvUsd_andUnderpaysCaller`**
- Round 1 compares a control harvest with a gap-route harvest from the same snapshot. Both harvests run at gas price 0 (`vm.txGasPrice(0)`) to isolate the value effect from the `Unprofitable` gas gate. Whether a gap-route harvest also clears that gate at a real gas price depends on the size of the harvest, and the PoC does not test it. Key output from the run log:

```
control ETH to caller (wei)              4553583013453051
gap     ETH to caller (wei)              2757397646213466
caller loss (wei)                        1796185367239585
control USDC router->harvester (1e6)     20635140
gap     USDC router->harvester (1e6)     16346835
crvUSD stranded after harvest #1 (1e18)  4293593340380243980
crvUSD stranded after harvest #2 (1e18)  4321273398442802659
```

- The router makes one USDC transfer to the harvester instead of two; the USDe leg delivers 0 USDC. The harvester's crvUSD balance equals exactly the crvUSD the router paid. The USDe balance is 0, so the yield was claimed and sold. The caller receives less ETH than in the control.
- On this fork snapshot the shortfall is about 39.4% of the control payout. That figure depends on the snapshot: it reflects the USDe leg's share of this particular harvest and is not a general loss rate.
- Round 2 harvests again after a further accrual. The stranded crvUSD grows by exactly the new crvUSD the router delivers, and nothing recovers the earlier balance. Round 2 only shows that the strand recurs and accumulates. It runs at gas price 0 (at a realistic gas price this small round would revert `Unprofitable`), it exempts the USDC strategy to work around a stale Chainlink feed on the warped fork, and it has no control run. It does not measure a per-round loss.

Additional evidence from this audit run:

- **Invariant tests.** `invariant_routeRegistrySound` and `invariant_noStranding` fail in the adversarial configuration on both forge and Medusa. The counterexample is the USDe gap shape: the harvest succeeds and the crvUSD balance grows. A deterministic tripwire strands exactly 50e18 crvUSD from 50e18 USDe of yield, and the harvest still succeeds. Both invariants pass with honest routes.
- **Halmos.** A1/A2 FAIL with a gap witness; A3/A4 PASS. See the Root cause section.

## Recommended mitigation steps

**1. Validate the route the way Router NG executes it.** Find the first empty pool slot. Require that the token before it is the reward token, and that every slot after it is empty:

```solidity
error InvalidRouteGap(uint256 index); // new error, declared beside InvalidRouteEnd

address rewardToken = sya.rewardToken();

// Router NG executes hop k while path[2k+1] != 0 and delivers path[2k] at the first empty pool slot.
uint256 k;
while (k < 5 && path[2 * k + 1] != address(0)) k++;

address delivered = path[2 * k];
if (delivered != rewardToken) revert InvalidRouteEnd(rewardToken, delivered);

// Nothing may follow the executed prefix: a trailing entry is never executed.
for (uint256 i = 2 * k + 1; i < 11; i++) {
    if (path[i] != address(0)) revert InvalidRouteGap(i);
}
```

Halmos supports this rule:

| Check | Result | What it shows |
|---|---|---|
| `check_A5_contiguityFixSufficient` | PASS | Every route accepted under this rule delivers the reward token or reverts loudly. |
| `check_A6_contiguityNotOverStrict` | PASS | Every non-reverting route that delivers the reward token satisfies the rule, so it rejects no legitimate route. |

**2. Optionally, also check `swapParams` and `pools` against the path.** For example, require `swapParams` rows `k..4` to be zero, and the executed rows to be non-zero. This would reject inconsistent parameter matrices. It is defence in depth only: its combination with the contiguity rule (`check_A5b`) timed out in Halmos. It is supported only by the exhaustive abstraction and bounded fuzzing, not by a proof.

**3. Amend story-001's rule (F-02).** Replace "last non-zero entry of `path`" with the contiguity rule above, so that the specification and any code built from the CurveAMMAdapter template stop reintroducing this gap. The same template rule may exist in `reflax-mint/vault`'s `CurveAMMAdapter.setRoute` and should be checked there.

**4. Make `MockCurveRouter` model Router NG (Q-06).** It should stop at the first empty pool slot and deliver `path[2k]`. Add a unit test that a gapped route is rejected by `setRoute`. Optionally assert after each harvest that every touched non-reward token balance is zero, which is story-002's acceptance criterion.

**5. Add a rescue path as defence in depth (Q-03).** An owner-only sweep of non-strategy ERC-20 balances would make any future strand of this kind recoverable rather than permanent. It does not replace the validation fix.

**Safe-configuration guidance until fixed:**

- After every `setRoute`, read `getRoute(token)`. Find the first `k` with `path[2k+1] == address(0)`, and confirm that `path[2k] == sya.rewardToken()` and that every later slot is zero.
- Also `eth_call` Router NG's `exchange` with the stored route and confirm that the output is the reward token.
- Before relying on `harvest.sh`, confirm that the harvester holds no balance of any intermediate token after a simulated harvest.
