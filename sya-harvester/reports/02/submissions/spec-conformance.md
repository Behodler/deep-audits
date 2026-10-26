# Spec-Conformance Report for sya-harvester (run 02)

- **Run**: `sya-harvester-02` (regression audit, baseline `62c19c8` to HEAD)
- **Source**: https://github.com/Behodler/sya-harvester @ `6b862aa0af3d3182d2fd311c4402a4056b69ef42` (branch `master`)
- **Stories graded**: story-006 and story-007 (the full delta: every commit in `62c19c8..6b862aa` carries one of these tags). story-001 was re-graded for run-01 F-02 only. Stories 002, 003 and 005 were checked only for the run-01 F-01, F-03, F-04 and F-05 carries.
- **Story source**: `~/code/product-owner/stories/sya-harvester/` (`storyDir` = `sya-harvester`). A whole-tree glob returns exactly seven documents (001-007), with no duplicates and no decimal insertions. Stories 006 and 007 are in `auto-complete/audit-fixes/`, and byte-identical copies are in [../stories/](../stories/). story-001 is in `auto-complete/sya-harvester-harvester-v1/` and has not been modified since run 01 (mtime 2026-10-24).
- **Router evidence**: the deployed Curve Router NG v1.1 Vyper source (`0x16C6521Dff6baB339122a0FE25a9116693265353`, `version = "1.1.0"`) is at [../profiles/evidence/RouterNG-v1.1-0x16C6.vy](../profiles/evidence/RouterNG-v1.1-0x16C6.vy). Line numbers below refer to that file.
- **Not in this report**: High/Medium and Low/QA security findings. See [qa-report.md](./qa-report.md) (L-05) and [M-01-C1.md](./M-01-C1.md).

Story states: `auto-complete` is a final state equivalent to `complete`. It means agent review passed and no formal human review has happened. It is noted here because stories 006 and 007 were approved with inline delegation, so reviewer independence was reduced.

## Summary

| Label | Issue ID | Story | Kind | Severity | Fingerprint |
|---|---|---|---|---|---|
| F-06 | sh2f6 | story-006 | The story's premise is false; NatSpec and test comments copy it | info | `f8cfb5533d826c9f5c316618af2626e18751845deb4b453965850baf5426583a` |
| F-07 | sh2f7 | story-007 | The story's premise is false; interface NatSpec copies it | info | `213ac286019b21d28ed9cf86b018e00a6391fe20d4de708da25e6fd027c22c47` |
| F-08 | sh2f8 | story-001 vs 006/007 | A terminal story was superseded but never amended, and it names a vulnerable template | qa | `7ae00c3a3743849dcb155d82e836c6419128875625733bd211c8e82783e57ce0` |

None of the three changes which routes `setRoute` accepts or rejects, and none is a Law-1 exploit. F-06 and F-07 are errors in the story's model of Router NG that were copied into shipped documentation. F-08 is a gap in the story tree itself: the code follows the latest story.

---

## [F-06] story-006's premise that a k=0 route "delivers `path[0]`" is false for Router NG v1.1, because hop 0 always executes. The `InvalidRouteEnd` @dev, the `ICurveRouterNG` NatSpec and three test comments repeat it <!-- id: sh2f6 -->

**Story text** (story-006, [006-router-ng-contiguity-route-validation.md](../stories/006-router-ng-contiguity-route-validation.md)):

> Background L20: "So with first empty pool slot at `path[2k+1]` (k in 0..4), delivered token = `path[2k]`"

> Implementation Notes L100: "`token == rewardToken` with `path[1] == 0` (k=0, delivered = path[0] = reward) is accepted by mitigation 1. This is harmless because `_sellYield` skips the reward token."

**Actual router behaviour.** The Router NG v1.1 `exchange` loop (L223-344) runs hop `i` unconditionally. It reads `swap = _route[i*2+1]`, sets `output_token = _route[(i+1)*2]`, performs the swap, and only then checks whether to stop:

```vyper
    for i in range(5):
        # 5 rounds of iteration to perform up to 5 swaps
        swap: address = _route[i * 2 + 1]
        ...
        output_token = _route[(i + 1) * 2]
        ...
        # check if this was the last swap
        if i == 4 or _route[i * 2 + 3] == empty(address):
            break
```

The termination test reads `_route[i*2+3]`, the *next* pool slot, and only after hop `i` has run. Slot `_route[1]` is never tested. With `path[1] == 0`, hop 0 therefore calls `address(0)` as the pool, and `output_token = _route[2]`. The call reverts with empty data, either on the call itself or at `assert amount - output_token_initial_balance != 0, "Received nothing"` (L336). The router never "delivers `path[0]`". The formula `delivered = path[2k]` is correct for k = 1..5 only. A k=0 route cannot be executed at all.

**Shipped text that repeats the premise** (all @ `6b862aa`):

- [src/SYAHarvester.sol#L81-L84](https://github.com/Behodler/sya-harvester/blob/6b862aa0af3d3182d2fd311c4402a4056b69ef42/src/SYAHarvester.sol#L81-L84):
  ```solidity
  /// @notice The token Curve Router NG would deliver for a route is not SYA's reward token
  /// @dev Router NG executes hop k while `path[2k+1] != 0` and delivers `path[2k]` at the first empty pool
  ///      slot (`path[10]` after five hops); `delivered` is that token, not the path's last non-zero entry.
  error InvalidRouteEnd(address expected, address delivered);
  ```
- [src/interfaces/ICurveRouterNG.sol#L16-L19](https://github.com/Behodler/sya-harvester/blob/6b862aa0af3d3182d2fd311c4402a4056b69ef42/src/interfaces/ICurveRouterNG.sol#L16-L19): "Execution stops at the FIRST empty pool slot: hop k runs while `_route[2k+1] != 0`, and the router delivers `_route[2k]` for the first k with `_route[2k+1] == 0`". At k = 0 this states that the router delivers `_route[0]`.
- [test/SYAHarvester.registry.t.sol#L298](https://github.com/Behodler/sya-harvester/blob/6b862aa0af3d3182d2fd311c4402a4056b69ef42/test/SYAHarvester.registry.t.sol#L298): `// path[1] == 0: Router NG executes nothing; the "delivered" token is path[0] itself`
- [test/SYAHarvester.registry.t.sol#L316](https://github.com/Behodler/sya-harvester/blob/6b862aa0af3d3182d2fd311c4402a4056b69ef42/test/SYAHarvester.registry.t.sol#L316): `/// @dev Documented harmless case: a reward-token "route" with no hop (k = 0) delivers path[0] = reward.`
- [test/mocks/MockCurveRouter.t.sol#L129](https://github.com/Behodler/sya-harvester/blob/6b862aa0af3d3182d2fd311c4402a4056b69ef42/test/mocks/MockCurveRouter.t.sol#L129): `// path[1] == 0: the real router would execute nothing and transfer nothing meaningful`

The `setRoute` NatSpec itself ([#L148-L149](https://github.com/Behodler/sya-harvester/blob/6b862aa0af3d3182d2fd311c4402a4056b69ef42/src/SYAHarvester.sol#L148-L149)) is correct: "A reward-token 'route' with `path[1] == 0` (k = 0) ... is accepted; it is never executed because `_sellYield` skips the reward token."

**Deviation.** The code meets the story's behavioural acceptance criteria. A k=0 non-reward route reverts `InvalidRouteEnd(reward, token)` (registry test L297), and a k=0 reward route is accepted (L318). The story's model of the router is wrong at k = 0, and the documentation copies that model. The accept/reject set does not change, because a k=0 route is either rejected or never executed.

**Law-1 assessment.** No exploit, and the failure is loud. The one reachable consequence is that, after an SYA `setRewardToken`, a stored k=0 route for the *old* reward token is no longer skipped. If a strategy then delivers that token, Router NG reverts on hop 0 and harvest bricks with nothing stranded. That case is already covered by L-03 (`sh1l3`, `4994fe853f`).

**Recommendation.** Reword the `InvalidRouteEnd` @dev and the `ICurveRouterNG` header: "hop 0 always executes; for k >= 1 the router delivers `path[2k]`; a k = 0 route is non-executable (the router reverts)". Fix the three test comments. Optionally, make `MockCurveRouter` model the real empty-data revert instead of `NoHop` (the residual in Q-06, `sh1q6`, `500b52898d`). If the owner amends stories, correct story-006 L20 ("k in 1..4") and L100.

---

## [F-07] story-007's premise that `_pools[i]` is used by "zap swap types 3/5/7" is false. Router NG v1.1 reads `_pools` only for swap_type 3, and the `ICurveRouterNG` NatSpec copies the error <!-- id: sh2f7 -->

**Story text** (story-007, [007-route-token-and-params-consistency.md](../stories/007-route-token-and-params-consistency.md)):

> Background L20: "Loop: for hop i, `output_token = _route[(i+1)*2]`; swap using `_swap_params[i]` (and `_pools[i]` only for zap swap types 3/5/7)"

> Autonomous Decisions L127: "we require `pools[k..4] == 0` (never read by the router) and leave executed-hop pools unconstrained because zap swap types legitimately use them."

**Actual router behaviour.** In the `exchange` loop, `pool: address = _pools[i]` (L226) is consumed only in the `params[2] == 3` branch (L256-261):

```vyper
        elif params[2] == 3:  # SWAP IS ZAP HERE !!!
            if params[3] in [1, 10]:  # stable and stable_ng
                LendingBasePoolMetaZap(swap).exchange_underlying(pool, convert(params[0], int128), convert(params[1], int128), amount, 0)
            else:  # crypto
                use_eth: bool = input_token == ETH_ADDRESS or output_token == ETH_ADDRESS
                CryptoMetaZap(swap).exchange(pool, params[0], params[1], amount, 0, use_eth, value=eth_amount)
```

The router's own NatSpec (L208) says: "`@param _pools` Array of pools for swaps via zap contracts. This parameter is only needed for swap_type = 3." Swap types 5 and 7 never read `_pools`.

**Shipped text that repeats the premise:**

- [src/interfaces/ICurveRouterNG.sol#L21-L23](https://github.com/Behodler/sya-harvester/blob/6b862aa0af3d3182d2fd311c4402a4056b69ef42/src/interfaces/ICurveRouterNG.sol#L21-L23):
  ```solidity
   *      Per hop: hop h reads row `_swap_params[h]` (dispatching on its `swap_type`, `_swap_params[h][2]`;
   *      unknown types revert "Bad swap type") and `_pools[h]` (only for the zap swap types 3/5/7). Rows and
   *      pools for hops h >= k, the ones never executed, are ignored by the router.
  ```
- [src/SYAHarvester.sol#L98](https://github.com/Behodler/sya-harvester/blob/6b862aa0af3d3182d2fd311c4402a4056b69ef42/src/SYAHarvester.sol#L98): "Pools of executed hops are unconstrained (zap swap types use them)." This wording is loose but not false.

**Deviation.** The interface NatSpec copies a wrong story premise. Behaviour is unaffected. Executed-hop pools stay unconstrained, which is still correct for type 3, and a stray pool on a hop of any other type is ignored. The wrong model would mislead a future validator that ties `pools[h]` to swap_type. For example, a rule requiring `pools[h] != 0` for types 5 or 7 would reject no real route, but it would encode a false model of the router.

**Law-1 assessment.** None.

**Recommendation.** In `ICurveRouterNG.sol` L22, change "3/5/7" to "swap_type 3 only". If the owner amends stories, make the same change in story-007 L20.

---

## [F-08] story-001 is terminal and was never amended. It still prescribes the last-non-zero route rule and the vulnerable `CurveAMMAdapter` template that stories 006 and 007 replaced, and the replacement is recorded only in a 006 Concerns bullet <!-- id: sh2f8 -->

**Lineage.** This is split from M-01 (`sh1m1`, `004d4547d93b2d4431753bd11b17f2c86b50e65d1eaa37b530f34188feb739a3`). Run 01 merged the faithfulness finding F-02 into DEDUP-001, which became M-01. The Law-1 half of F-02 closes with M-01 (code-scan replay: **LIKELY-FIXED**; `fixed` is proposed, and only a human applies it). The Law-2 half survives as this finding. It has its own `rootCauseClass` so that M-01 can be proposed `fixed` without hiding this residual.

**Story text** (story-001, `~/code/product-owner/stories/sya-harvester/auto-complete/sya-harvester-harvester-v1/001-dependencies-skeleton-route-registry.md`):

> L34: "**Route template:** `/home/justin/code/reflax-mint/vault/src/AMMAdapters/CurveAMMAdapter.sol`. It has the `Route` struct (lines 24-29) and the `setRoute` validation (lines 62-85): `path[0] == tokenIn`, and the last non-zero entry of `path` equals `tokenOut`."

> L130: "`setRoute` validates `path[0] == token` (and that `token != address(0)`). It also checks that the last non-zero entry of `path` equals `sya.rewardToken()`, read at call time. Use the CurveAMMAdapter loop as the template."

> L133: "Use custom errors, e.g. `InvalidRouteStart(address token, address first)`, `InvalidRouteEnd(address expected, address last)` and `InvalidEthPool()`."

**Superseding story text** (story-006):

> Out of Scope L109: "Mitigation 2 (swapParams/pools consistency check), mitigation 3 (amending story-001's rule text, and the same last-non-zero rule in `/home/justin/code/reflax-mint/vault/src/AMMAdapters/CurveAMMAdapter.sol` L73-80), mitigation 5 (owner-only sweep/rescue, audit Q-03). Do not implement them here."

> Concerns L136: "story-001's spec still prescribes the old last-non-zero rule (F-02). That story is terminal, so its text is left alone; this story supersedes the rule."

**Actual behaviour.** The shipped `setRoute` ([src/SYAHarvester.sol#L157-L173](https://github.com/Behodler/sya-harvester/blob/6b862aa0af3d3182d2fd311c4402a4056b69ef42/src/SYAHarvester.sol#L157-L173)) implements the story-006/007 contiguity rule:

```solidity
        // Router NG executes hop k while path[2k+1] != 0 and delivers path[2k] at the first empty pool slot.
        uint256 k;
        while (k < 5 && path[2 * k + 1] != address(0)) k++;
        // Nothing may follow the executed prefix: a trailing entry is never executed (empty when k == 5).
        for (uint256 i = 2 * k + 1; i < 11; i++) {
            if (path[i] != address(0)) revert InvalidRouteGap(i);
        }
        ...
        address delivered = path[2 * k];
        if (delivered != rewardToken) revert InvalidRouteEnd(rewardToken, delivered);
```

Graded literally against story-001, the code now fails story-001's acceptance criteria: story-001 would accept a gapped route that story-006 rejects. The second parameter of `InvalidRouteEnd` is now `delivered`, not `last`. The selector is unchanged.

**Deviation.** This is **not** an implementation deviation. The code follows the newest stories, and story-006 says explicitly that it supersedes the rule. A story-level conformance gap still remains:

1. The authoritative story tree holds two contradictory specs for `setRoute`, and the supersession is recorded only in a Concerns bullet of story-006, not in story-001.
2. Story-006 frames amending story-001 as a *deferred* mitigation ("mitigation 3 ... Do not implement them here"), not as "not needed". No story for it exists anywhere in the tree.
3. story-001 still points readers and agents at a template that is still vulnerable. Anyone who re-derives or re-implements from story-001 would re-introduce M-01. That includes a future agent grading against it, or one scaffolding a sibling harvester.

Supersession is enough to grade the code. It is not enough to close the spec, because the stale rule is still the first thing a reader of story-001 is told to copy.

**Law-1 assessment.** There is no live exploit in sya-harvester at `6b862aa`. The residual risk is that M-01 returns when the rule is re-derived from story-001, plus the live carrier of the same rule in the vault (below).

**Cross-project note: reflax-yield-vault.** The template story-001 names still has the rule, at `reflax-yield-vault/src/src/AMMAdapters/CurveAMMAdapter.sol` L72-80. The same text is in the working repo `~/code/reflax-mint/vault/src/AMMAdapters/CurveAMMAdapter.sol`:

```solidity
        // Find the last non-zero entry in path and confirm it equals tokenOut
        address lastToken;
        for (uint256 i = 0; i < 11; i++) {
            if (path[i] != address(0)) {
                lastToken = path[i];
            }
        }
        require(lastToken == tokenOut, "CurveAMMAdapter: path must end at tokenOut");
```

It is already tracked as reflax-yield-vault **L-07** (`ryv7l7`, fingerprint `b28e77daef…`, low, open, last seen `reflax-yield-vault-16`): "setRoute accepts tokenIn == tokenOut and paths with internal zero-gap segments". No new vault entry is filed. The rule's ancestor story is vault-RM story-039. **The next reflax-yield-vault run should re-weigh L-07** using the concrete Router NG evidence from this project: the M-01 PoC and the fork test `test_fork_M01_realRouterDeliversIntermediate_mockAgrees` both show that a gapped path delivers the intermediate token. Whether a strand is reachable there depends on how the vault's caller handles a wrong output token.

**Recommendation.** For the product owner, either step closes this finding:

- append a note such as "**Superseded by story-006/007**: `setRoute` validates the executed prefix (first empty pool slot), not the last non-zero entry; do not use the CurveAMMAdapter loop" to story-001 at L34, L130 and L133. Story documents are human-editable, while the audit treats the tree as read-only; or
- record an explicit policy that terminal stories are never amended and supersession lives only in the later story.

`src/CLAUDE.md` L35-37 also cites the vault `CurveAMMAdapter` as the "workspace precedent" for route storage. That reference is about format, not validation, so it does not contradict the shipped rule. It deserves a one-word caveat if story-001 is amended.

**Rescan check.** The next run should look for the supersession note in story-001 or a recorded no-amend policy. Without either, this finding stays open.

---

## Stories 006 and 007: conformance confirmed

Source: [../faithfulness/faithfulness-findings.json](../faithfulness/faithfulness-findings.json) (`conformanceSummary`, `lawOneOverride`).

**story-006 conforms on all 15 checklist acceptance criteria.** `setRoute` computes k at the first empty pool slot. It rejects any non-zero entry in `path[2k+1..10]` with `InvalidRouteGap(i)` and requires `path[2k] == rewardToken` (`InvalidRouteEnd`). The selector is unchanged. The registry tests, mock-fidelity tests, harvest-level `test_routeGap_*` tests and fork tests cover every acceptance criterion, and `harvest.sh` `KNOWN_ERRORS` decodes `InvalidRouteGap(uint256)`. The story's spec block checks End before Gap, while its checklist expects Gap first. Execution Decision 3 disclosed that conflict, and story-007 then codified Gap-first, which is the order that shipped. The accept/reject set is the same under either order. Law-1 override: **SAFE**. The contiguity rule removes the M-01 strand class. The only premise error is F-06.

**story-007 conforms on all 10 checklist acceptance criteria.** The check order is exactly ZeroAddress, Start, Gap, Token, End, then per hop params before pools, matching the spec block verbatim. All three new errors carry NatSpec. The tests and the order pins are present. The `_params(k)` and `_pools(k)` helpers are k-aware, and only fixture inputs changed: no assertion was weakened (verified by reading the diff). The mock adds `ZeroIntermediateToken` and `BadSwapType`. The fork tests pin the real router's empty-data revert and `Error("Bad swap type")`. Law-1 override: **SAFE**. Every new rule only rejects routes. The only premise error is F-07.

**Spot reproduction** (in `sya-harvester/work` @ `6b862aa`, skipping audit PoCs): the four affected unit suites pass 78 of 78 (registry 52/52, MockCurveRouter 11/11, routeGap 3/3, harvest 12/12), matching the story-007 record. The fork suite was not re-run in this audit. The story reviews report it at block 26261000.

**Cross-reference: the story-007 Goal overclaims (see L-05).** The story-007 Goal (L15) says that "`setRoute` stores only routes whose path, swap params and pools are mutually consistent with how Router NG will execute them". The spec block delivers less: the executed swap_type is checked only for `!= 0`, not for the router's range 1..8, and its Out of Scope (L106) excludes `i`/`j`/`pool_type`/`n_coins`. The implementation follows the spec block, so this is not filed as a separate F. The residual is reported once, at its security severity, as **L-05** (`sh2l5`, `3dc300229056…`) in [qa-report.md](./qa-report.md).

---

## Run-01 faithfulness findings: re-evaluation

| Run-01 tag | Story | Run-02 status | Carried by (ledger) |
|---|---|---|---|
| F-01 | story-003/005 vs `src/CLAUDE.md` Purpose | **Still holds, unchanged.** Neither the `Unprofitable` check (now L297) nor the `harvest.sh` `MIN_PROFIT_WEI` floor is touched by the delta | **L-02** `sh1l2` `464b942691` (open) |
| F-02 | story-001 | **Re-graded.** The security half is resolved together with M-01 `sh1m1` `004d4547d9` (**LIKELY-FIXED**; `fixed` is proposed, and only a human applies it). The Law-2 residual is split out as **F-08** above | M-01 `sh1m1` (fix-pending) for the security half; F-08 `sh2f8` for the residual |
| F-03 | story-002 | **Still holds, unchanged.** The balance-based skip in `_sellYield` and `RouteNotConfigured` are untouched | **L-01** `sh1l1` `d7744b9d24` (open) |
| F-04 | story-002 | **Still holds, unchanged.** The NatSpec at L310-311 still claims a "~10%" over-estimate, and the borrow at L326 is unchanged | **Q-01** `sh1q1` `e95e3c9bae` (open) |
| F-05 | story-005 | **Still holds.** The delta only adds the four new `setRoute` errors to `KNOWN_ERRORS`, as stories 006 and 007 require. Those errors are raised only by the owner-only `setRoute` and never during the harvest simulation, so the gap in story-005's "readable reason on any simulated revert" (SYA, strategy, oracle and Router NG reverts) is unchanged | **L-04** `sh1l4` `8cc1530764` (open) |

The full text of the carried Low/QA entries is in [carryover/qa-report-01.md](./carryover/qa-report-01.md).

## Process notes

- No story exists anywhere in the tree for run-01 mitigation 3 (amending story-001 and the vault `CurveAMMAdapter`) or for mitigation 5 (owner rescue, Q-03). Stories 006 and 007 defer to "follow-up stories" that have not been written.
- Some story line numbers in `faithfulness-findings.json` were computed against a concatenated copy. In this report, every story quote is cited by its line number in the story document itself. For example, story-007 Background is L20 and its pools decision is L127.
