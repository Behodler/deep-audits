# QA Report for phoenix-phase-2-staging, run 38 (script audit)

- **Run**: `phoenix-phase-2-staging-38`
- **Source**: [Behodler/phoenix-phase-2-staging @ `a309040`](https://github.com/Behodler/phoenix-phase-2-staging/tree/a3090408a6b83c74f1419936d2801635f7e8b14b), branch `master`, read-only
- **Nested source**: `lib/yield-claim-nft` pinned at [Behodler/yield-claim-nft @ `9c18020`](https://github.com/Behodler/yield-claim-nft/tree/9c180204d262955f34b6d9b80e69febec0e9c400) by the commit above
- **Entry point**: `balancer-holding` (`balancer-holding:preview` / `:broadcast` / `:verify`), story 099. This is a cold, first audit of the entry point.
- **Fork block**: 26,094,450
- **Inputs**: `reports/38/findings/low/balancer-holding__L-01.json`, `reports/38/findings/qa/balancer-holding__Q-01.json`
- **Fork tests**: `work/test/audit-run38/BalancerHoldingAudit.fork.t.sol` (audit-authored, in the writable `work/` clone, not part of the upstream repo)

> **Faithfulness is not in this file.** No F-label was assigned for this entry point in run 38; the reasoning is in [`spec-conformance.md`](./spec-conformance.md). Carryover QA from earlier runs is not merged or renumbered here.

## Summary

| Severity | Count |
|----------|------:|
| Low Risk | 1 |
| QA | 1 |
| Centralization | 0 |
| **Total** | **2** |

Neither finding involves value leaving protocol custody. L-01 is an owner footgun (Law 3): the holding-pattern safety signals stay green after a knowing grant they cannot see. Q-01 is a documentation inaccuracy.

---

## Low Risk Findings

### [L-01] Holding-pattern verifier and the story-103 step-0 precondition only check four hardcoded addresses; a later re-authorization of any other pooler stays green (and the proposed `authVersion()>1` hardening does not catch it) <!-- id: pps38l1 -->

- **Severity**: Low (owner footgun)
- **Fingerprint**: `59527bfa84786a87002d80b9bf678c5e798c4d9b2905609ac0f786bd46737632`
- **Root cause class**: `IncompletePostconditionCoverage`
- **Location**:
  - [script/VerifyBalancerHolding.s.sol#L17-L31](https://github.com/Behodler/phoenix-phase-2-staging/blob/a3090408a6b83c74f1419936d2801635f7e8b14b/script/VerifyBalancerHolding.s.sol#L17-L31) (`run`)
  - [script/RevokeBalancerPoolersHoldingPattern.s.sol#L65-L86](https://github.com/Behodler/phoenix-phase-2-staging/blob/a3090408a6b83c74f1419936d2801635f7e8b14b/script/RevokeBalancerPoolersHoldingPattern.s.sol#L65-L86) (`poolers`, `_isAuthorized`, `_countAuthorized`)
  - [script/RevokeBalancerPoolersHoldingPattern.s.sol#L116-L119](https://github.com/Behodler/phoenix-phase-2-staging/blob/a3090408a6b83c74f1419936d2801635f7e8b14b/script/RevokeBalancerPoolersHoldingPattern.s.sol#L116-L119) (idempotence early return)
  - [lib/yield-claim-nft/src/dispatchers/BalancerPoolerV2.sol#L190-L199](https://github.com/Behodler/yield-claim-nft/blob/9c180204d262955f34b6d9b80e69febec0e9c400/src/dispatchers/BalancerPoolerV2.sol#L190-L199) (`setAuthorizedPooler`)
  - Story 100 / story 103 step-0 precondition text (stories not yet implemented as a script)

**Description**: `VerifyBalancerHolding.run()` proves the holding pattern by requiring `poolerAuthVersion[p] != authVersion` for exactly four hardcoded addresses:

```solidity
// script/VerifyBalancerHolding.s.sol L17-31
function run() external view {
    console.log("=================================================");
    console.log("  VERIFY BALANCER HOLDING PATTERN (story 099)");
    console.log("=================================================");
    require(block.chainid == CHAIN_ID, "Wrong chain ID - expected Mainnet (1)");
    _logPoolers();
    address[4] memory ps = poolers();
    for (uint256 i = 0; i < 4; i++) {
        if (_isAuthorized(ps[i])) console.log("STILL AUTHORIZED:", ps[i]);
    }
    for (uint256 i = 0; i < 4; i++) {
        require(!_isAuthorized(ps[i]), "verify: pooler still authorized");
    }
    console.log("OK: all four poolers unauthorized on chain.");
}
```

```solidity
// script/RevokeBalancerPoolersHoldingPattern.s.sol L65-86
function poolers() public pure returns (address[4] memory ps) {
    ps[0] = OWNER;
    ps[1] = MULTI_POOLER;
    ps[2] = POOLER_7702_EOA;
    ps[3] = POOLER_EOA;
}

function _pooler() internal pure returns (IBalancerPoolerV2Holding) {
    return IBalancerPoolerV2Holding(BALANCER_POOLER_V2);
}

/// @dev EXACTLY the `onlyAuthorizedPooler` predicate: poolerAuthVersion[p] == authVersion.
function _isAuthorized(address p) internal view returns (bool) {
    return _pooler().poolerAuthVersion(p) == _pooler().authVersion();
}

function _countAuthorized() internal view returns (uint256 n) {
    address[4] memory ps = poolers();
    for (uint256 i = 0; i < 4; i++) {
        if (_isAuthorized(ps[i])) n++;
    }
}
```

`BalancerPoolerV2.setAuthorizedPooler(x, true)` stamps `x` with the *current* `authVersion`, so any authorization granted after the bump, for an address outside the four, is fully live:

```solidity
// lib/yield-claim-nft/src/dispatchers/BalancerPoolerV2.sol L190-199
function setAuthorizedPooler(address pooler, bool authorized) external onlyOwner {
    require(pooler != address(0), "BalancerPoolerV2: zero pooler");
    if (authorized) {
        poolerAuthVersion[pooler] = authVersion;
        emit PoolerAuthorized(pooler, authVersion);
    } else {
        delete poolerAuthVersion[pooler];
        emit PoolerDeauthorized(pooler);
    }
}
```

The verifier cannot see such a grant. Neither can `authVersion() > 1`, the hardening suggested in the story-099 review, because the version stays at 2. Stories 100 and 103 specify the cutover's step-0 "authorized-pooler set revoked" precondition with the same four-address predicate (story 100: *"check the four poolers as `onlyAuthorizedPooler` does"*; story 103: *"the script itself `require`s the revocation on-chain (all four poolers unauthorized on `0x7f68`)"*). So `:verify`, the `holding-broadcast` gate (a tx hash) and step 0 would all be green.

A related idempotence edge shares the root cause. If the four were ever individually deauthorized while another address held the current version, `run()` would send nothing:

```solidity
// script/RevokeBalancerPoolersHoldingPattern.s.sol L116-119
if (_countAuthorized() == 0) {
    console.log("All four poolers already unauthorized - nothing to do, no transaction sent (idempotent).");
    return;
}
```

That edge is unreachable today: on-chain history on `0x7f68` shows exactly 4 `PoolerAuthorized` events and 0 deauthorizations.

**Impact**: Failure scenario: after the 099 broadcast, the owner re-authorizes some address X for an ad-hoc `pool()`, for example a new automation key or a UI wallet, not one of the four. Every holding-pattern check stays green, so the 103 cutover proceeds. During its multi-tx `--slow` broadcast, X (or automation behind it) calls `pool()` between step 2 (`withdrawBPT(OWNER, all)`) and step 9 (`rescueERC20(sUSDS)`). Parked sUSDS then goes into the soon-to-be-paused Balancer pool as fresh BPT on the old pooler, after the BPT drain. Step 3 does not exit that BPT, so the owner has to recover it separately. Before 30 Oct this also re-exposes the zero-floor, sandwichable `pool()` that the holding pattern exists to prevent (yield-claim-nft L-06).

No value leaves protocol custody: BPT is minted to the pooler and remains owner-recoverable via `withdrawBPT`, and story 103's own verify would catch the leftover after the fact. The trigger is a knowing owner grant. The defect is that every safety signal is silent about that grant, which is a footgun rather than a loss.

- **Likelihood**: low. It needs a knowing owner grant to a fifth address between the 099 broadcast and the 103 run (a window that closes for `pool()` on 30 Oct), plus X actually pooling. No external attacker can trigger it, and the sandwich leg needs X to use a loose `minBPT`.
- **Assumptions**: the owner is non-malicious (Law 3). The story-103 side is unverified because that script does not exist yet; its precondition text is quoted from story 100 L49 and story 103 L59/L148.

**Evidence** (fork, block 26,094,450; independently reproduced):

- `test_r38_08_verifier_blind_to_reauth_outside_the_four`: after the bump, the owner grants a fifth address. `VerifyBalancerHolding.run()` passes, `authVersion() == 2 > 1`, and the fifth address calls `pool(0)` successfully and mints BPT. A re-authorization of `0x186c` (one of the four) *is* detected, which confirms the gap is specific to addresses outside the list.
- `test_r38_09_idempotence_guard_skips_bump_with_unknown_live_pooler`: with the four individually deauthorized and a fifth address holding the current version, the revoke script skips `incrementAuthVersion()`, logs success, and `:verify` passes while the fifth address can still `pool()`. This edge is latent (see above) and is included as supporting evidence, not as a separate finding.
- `test_r38_06_pre_revocation_7702_pooler_can_pool_with_zero_floor`: shows the contained hazard. Before revocation, the `0x186c` EIP-7702 account can `pool(0)` with a zero floor.

**Story evidence**: story 099 (`review/`, ISSUES_FOUND) says `:verify` "asserts all four poolers are unauthorized" and calls the revocation "a REQUIRED precondition of the mainnet cutover script (story 103, step 0)". Stories 100 and 103 (both `incomplete/`) reuse the four-address predicate as quoted above. The 099 verifier is faithful to its own spec, so this is a design gap in the gate the later stories rely on, not an implementation deviation, and it carries no F tag.

**Cross-references**: yield-claim-nft L-06 (`342075dfba3c8ec7c3bae1ae18c357591c5ea255bf649ee943c6c71f3ddd4c2e`, open) is the contract-level `pool()` sandwich hazard this holding pattern contains. It is not a duplicate: the root cause, project and fix are different.

**Watch (severity re-weigh)**: Low is the right rating for the landed 099 scripts. **Re-weigh toward Medium if story 103's step 0 ships with the four-address predicate** as its only revocation proof. At that point the mainnet cutover's own gate, not just an auxiliary verifier, would be blind to a live fifth pooler during the multi-tx broadcast. Re-assess when the story-103 script exists, and check whether an extra grant is actually live at cutover time.

**Recommendation**: In story 103 (and the story-100 core), do not reuse the four-address predicate as the revocation proof. Record the revoke tx's block and new `authVersion` as gate evidence, then at step 0 require `authVersion() == recordedVersion`, AND fail if any `PoolerAuthorized` event was emitted by 0x7f68 after the revoke block. Do this off-chain via `cast logs` feeding an env var the script `require`s, as 103 already does for `minAmountsOut`. Alternatively, make step 0 itself call `incrementAuthVersion()` immediately before `withdrawBPT`, which revokes everything regardless of who was granted since. In `VerifyBalancerHolding`, log `authVersion()` and add the same post-revoke `PoolerAuthorized` log check, or at minimum state in its NatSpec that it cannot detect grants outside the four. Note that `authVersion() > 1` alone is insufficient.

A minimal shape for the step-0 alternative:

```solidity
// story-103 step 0: revoke unconditionally, then drain
balancerPoolerV2.incrementAuthVersion();   // invalidates every grant, listed or not
balancerPoolerV2.withdrawBPT(OWNER, bpt);
```

---

## QA Findings

### [Q-01] Script NatSpec misattributes the 0x186c/0x6309 pooler grants to WhitelistPoolersV2 (actual source: OWNER `Temp.s.sol` txs); WhitelistPoolersV2 also whitelisted a different set <!-- id: pps38q1 -->

- **Severity**: QA (non-critical, documentation)
- **Fingerprint**: `b469855d97e475c98d72fd0fd71f0766f3f106d9704be2b4c48b780680f65788`
- **Root cause class**: `MisleadingDocumentation`
- **Location**: [script/RevokeBalancerPoolersHoldingPattern.s.sol#L14-L15](https://github.com/Behodler/phoenix-phase-2-staging/blob/a3090408a6b83c74f1419936d2801635f7e8b14b/script/RevokeBalancerPoolersHoldingPattern.s.sol#L14-L15) (contract NatSpec)

```solidity
// script/RevokeBalancerPoolersHoldingPattern.s.sol L14-15
 *           - 0x186c77B80Bbfd21b01C7D7FA44bA27031322a77F (7702-delegated EOA, WhitelistPoolersV2)
 *           - 0x630966B668b321Cc6441754f96519a55F72Cd476 (EOA, WhitelistPoolersV2)
```

**Description**: The header NatSpec labels `0x186c77B80Bbfd21b01C7D7FA44bA27031322a77F` and `0x630966B668b321Cc6441754f96519a55F72Cd476` as WhitelistPoolersV2 poolers, and so does the plan §4 table. On chain, their grants on `0x7f68` came from OWNER `Temp.s.sol` transactions (`0xcb56e196…`, block 25,792,038; `0xbf66c239…`, block 25,792,039). `script/archives/WhitelistPoolersV2.s.sol` targeted the older pooler `0x26F8…b38A` and also whitelisted `0x3E90…Eb28`, which is not authorized on `0x7f68`. Story 099 itself records the correct provenance, so the code comment contradicts its own story.

**Impact**: Informational. Execution is unaffected, because the hardcoded four-address list matches the complete on-chain grant set (4 `PoolerAuthorized`, 0 deauths). An operator who re-derived the pooler set from WhitelistPoolersV2 would get the wrong list: they would include `0x3E90` and miss the `Temp.s.sol` provenance, which is untracked (skip-worktree, with no broadcast logs in the repo). That could happen during story-103 step 7 ("setAuthorizedPooler for the same four") or when auditing who could pool. That path is unlikely in practice, because story 100 L40 lists the four addresses explicitly and story 099 records the correct provenance. That is why this was downgraded from a proposed Low to QA.

**Evidence**: static review plus on-chain logs (closure-manifest `authEventHistory`: exactly 4 `PoolerAuthorized` events on `0x7f68`, all at version 1, transactions listed); story 099, section "Pooler history (exploration)".

**Recommendation**: Change L14-15 to cite the authorizing txs (OWNER via `script/interactions/Temp.s.sol`, txs cb56e196…/bf66c239…) instead of WhitelistPoolersV2. Apply the same correction to the `docs/BalancerWinddownPlan.md` §4 table so story 103's step-7 re-authorization list is sourced from chain logs rather than the archived script.

```solidity
 *           - 0x186c77B80Bbfd21b01C7D7FA44bA27031322a77F (7702-delegated EOA; granted by OWNER via Temp.s.sol, tx 0xcb56e196…)
 *           - 0x630966B668b321Cc6441754f96519a55F72Cd476 (EOA; granted by OWNER via Temp.s.sol, tx 0xbf66c239…)
```

---

## Appendix: automated QA baseline (4naly3er)

**Attached: `script-audits/balancer-holding/4naly3er-report.md`.** The first attempt crashed the same way as runs 35 and 36 (`TypeError: Cannot read properties of undefined (reading 'contents')`). The cause was import resolution: 4naly3er only reads remappings from a `remappings.txt` at or above `basePath`, while this repo declares its remappings solely in `foundry.toml`, so `@forge-std/` was unresolvable and solc-js crashed on the undefined import result. Re-run against `phoenix-phase-2-staging/work/` (byte-identical scripts at a309040) with a `remappings.txt` generated by `forge remappings`, it completed: 0 Medium, 1 Low (`PUSH0` on 0.8.20+, irrelevant for a mainnet-only script), 11 NC and 6 Gas categories. None rises to a finding; all are style or gas items on one-shot operator scripts.
