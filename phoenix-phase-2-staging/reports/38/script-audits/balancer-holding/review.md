# Script review: `balancer-holding` (run 38)

| | |
|---|---|
| Project | `phoenix-phase-2-staging` |
| Run | `phoenix-phase-2-staging-38` |
| Entry point | `balancer-holding` (`:preview` / `:broadcast` / `:verify`) |
| Source | [Behodler/phoenix-phase-2-staging @ `a309040`](https://github.com/Behodler/phoenix-phase-2-staging/tree/a3090408a6b83c74f1419936d2801635f7e8b14b) (`a3090408a6b83c74f1419936d2801635f7e8b14b`), branch `master`, read-only |
| Nested source | `lib/yield-claim-nft` @ `9c180204d262955f34b6d9b80e69febec0e9c400` (top-level copy, which is the deployed build; the four nested copies are a stale pre-streamer pin with an identical auth model) |
| Mode | fork-preview, cold (first audit of this entry point) |
| Fork block | 26,094,450 (live reads up to head 26,094,460) |
| Story | phStaging2:099, `~/code/product-owner/stories/phStaging2/review/phStaging2-Balancexit/099-revoke-balancer-poolers-holding-pattern.md`. State `review/`, Review Status **ISSUES_FOUND** |
| Plan | `docs/BalancerWinddownPlan.md` §4 "Migration path", subsection "Holding pattern until the cutover" (commit `3943ae3`) |
| Commits | `54189f4` (script, verifier, fork test), `a309040` (npm keys) |
| Result | **0 High / 0 Medium.** 1 Low (L-01), 1 QA (Q-01), 0 F. No unintended on-chain side effects. |

**Bottom line.** The broadcast does what story 099 says. It sends one owner transaction, which changes exactly one storage slot on one contract (`0x7f68` slot 7, `authVersion` 1 → 2) and emits one event. That revokes the complete set of poolers that have ever been authorized. Mints keep working and the parked sUSDS stays owner-recoverable. The one real weakness is in what comes after: `:verify`, and the story-100/103 step-0 precondition built on the same predicate, only look at four hardcoded addresses. A later owner grant to any fifth address would leave every signal green (L-01, owner footgun). It is safe to broadcast before 30 Oct as written.

Companion artefacts: [`../../submissions/qa-report.md`](../../submissions/qa-report.md) (L-01, Q-01 in full), [`../../submissions/spec-conformance.md`](../../submissions/spec-conformance.md) (why there is no F entry), `intent.md`, `side-effects.json`, `cluster-analysis.md`, `classification-log.md`.

---

## Findings register

| Label | Sev | What | Mitigation | Where |
|---|---|---|---|---|
| **L-01** (`pps38l1`) | Low (owner footgun) | `:verify` and the four-address step-0 predicate in stories 100/103 cannot see a grant made after the bump to an address outside the four. `authVersion() > 1` does not catch it either. | Gate story 103 on a recorded `authVersion` plus "no `PoolerAuthorized` since the revoke block", or call `incrementAuthVersion()` inside step 0. Make `:verify` log `authVersion` and check post-revoke grants, or document the blind spot. | `script/VerifyBalancerHolding.s.sol` L17-31; `script/RevokeBalancerPoolersHoldingPattern.s.sol` L65-86, L116-119 |
| **Q-01** (`pps38q1`) | QA | The NatSpec says the `0x186c` and `0x6309` grants came from `WhitelistPoolersV2`. They actually came from OWNER `Temp.s.sol` txs. The plan §4 table repeats the mistake. | Cite the authorizing txs (`cb56e196…`, `bf66c239…`) in L14-15 and in the plan §4 table. | `script/RevokeBalancerPoolersHoldingPattern.s.sol` L14-15 |

Fingerprints, copied verbatim from the ledger:

- L-01 `pps38l1`: `59527bfa84786a87002d80b9bf678c5e798c4d9b2905609ac0f786bd46737632` (input `script/VerifyBalancerHolding.s.sol:run:IncompletePostconditionCoverage:balancer-holding`), status `open`
- Q-01 `pps38q1`: `b469855d97e475c98d72fd0fd71f0766f3f106d9704be2b4c48b780680f65788` (input `script/RevokeBalancerPoolersHoldingPattern.s.sol:(contract NatSpec):MisleadingDocumentation:balancer-holding`), status `open`

Watch notes raised (ledger `watchNotes`): `WN-38-BH-01`, `WN-38-BH-02`, `WN-38-BH-03`. See §3.

---

## 1. Does it do what it intends?

**Yes.** Every functional acceptance item of story 099 is met and was fork-verified. The one checklist item that is not met is a process attestation that the landed code neither causes nor touches.

### The mechanism

The contract has a single auth predicate, and `pool()` is the only function that uses it:

```solidity
// lib/yield-claim-nft/src/dispatchers/BalancerPoolerV2.sol L136-139
modifier onlyAuthorizedPooler() {
    require(poolerAuthVersion[msg.sender] == authVersion, "BalancerPoolerV2: caller not authorized pooler");
    _;
}
```

```solidity
// lib/yield-claim-nft/src/dispatchers/BalancerPoolerV2.sol L202-205
function incrementAuthVersion() external onlyOwner {
    authVersion += 1;
    emit AuthVersionIncremented(authVersion);
}
```

Bumping `authVersion` revokes every grant ever made, listed or not. The script reads auth with exactly the modifier's predicate:

```solidity
// script/RevokeBalancerPoolersHoldingPattern.s.sol L76-79
/// @dev EXACTLY the `onlyAuthorizedPooler` predicate: poolerAuthVersion[p] == authVersion.
function _isAuthorized(address p) internal view returns (bool) {
    return _pooler().poolerAuthVersion(p) == _pooler().authVersion();
}
```

Preconditions, the idempotence gate, the single call, and the local post-requires:

```solidity
// script/RevokeBalancerPoolersHoldingPattern.s.sol L104-106, L116-119, L126, L138-142
require(block.chainid == CHAIN_ID, "Wrong chain ID - expected Mainnet (1)");
require(BALANCER_POOLER_V2.code.length > 0, "preflight: BalancerPoolerV2 has no code");
require(_pooler().owner() == OWNER, "preflight: BalancerPoolerV2 owner is not OWNER");
...
if (_countAuthorized() == 0) {
    console.log("All four poolers already unauthorized - nothing to do, no transaction sent (idempotent).");
    return;
}
...
_pooler().incrementAuthVersion();
...
require(versionAfter == versionBefore + 1, "post: authVersion not bumped exactly once");
address[4] memory ps = poolers();
for (uint256 i = 0; i < 4; i++) {
    require(!_isAuthorized(ps[i]), "post: pooler still authorized");
}
```

### Story-099 checklist (Law 2)

| Story 099 item | Grade | Evidence |
|---|---|---|
| Fork test first: each of the four `pool()` calls reverts with the auth error after revocation; index-4 dispatch still succeeds; skips cleanly without RPC | **Met.** Test-first ordering cannot be proven, because test and script land in the same commit. | Upstream `test/RevokeBalancerPoolers.fork.t.sol`: 4/4 pass with RPC, 4/4 skip without. Dispatch is tested through `vm.prank(NFTMinter).dispatch`, which the story permits. Run 38 adds a real `NFTMinterV2.mint(4, …)` (`test_r38_04`). |
| Script calls `incrementAuthVersion()` on `0x7f68…11F1`, follows the PREVIEW_MODE convention, and asserts all four unauthorized "read the same way `onlyAuthorizedPooler` checks" | **Met** | `_isAuthorized` (L77-79) is the modifier predicate (BalancerPoolerV2 L136-139), character for character. |
| Read-only verify entry point | **Met** | `VerifyBalancerHolding.run()` is `view`. No `--broadcast` and no `--sender` in the key. |
| npm keys, `//BalancerHolding` citing 099, Ledger flags as template, no backup/patcher tail, `&& :verify` tail | **Met** | `package.json` L66-69. The HD path matches the other Ledger keys that sign as `0xCad1`. |
| `forge build` passes | **Met** | Workspace builds. |
| `forge test` passes (full suite) | **Not met as written** | 54 pre-existing failures: 39 in `CutoverStableStakerV2Mainnet.fork.t.sol` and 15 in `VerifyStableStakerV2CutoverGuards.t.sol`, all from the tracked `server/deployments/progress.stable-staker-v2-cutover.1.json`. They are identical at base `3943ae3`. The story's own review already records ISSUES_FOUND for this. No F entry (see `spec-conformance.md`); carried as `WN-38-BH-02`. |
| Preview runs clean, showing the version bump and all four unauthorized | **Met** | `work/test/audit-run38/preview.log` |
| `[story-099]` commits, explicit paths | **Met** | `54189f4`, `a309040` |
| HUMAN ACTION block | **Met in story; action still outstanding** | Live `authVersion == 1` at block 26,094,460. Nothing has been broadcast. |

Plan §4 conformance: the plan's "one owner transaction, `BalancerPoolerV2.incrementAuthVersion()`, revokes all four at once" is exactly what the payload is. The plan's other §4 items (extension decision by 16 Oct, contacting the `0xc65f…e8db` LP owner) are human actions outside this script.

### Is "all four" really "all"?

The script hardcodes four addresses. The full-range Etherscan `getLogs` on `0x7f68` shows **exactly four `PoolerAuthorized` events (all at version 1), zero `PoolerDeauthorized`, and zero `AuthVersionIncremented`** (closure-manifest `authEventHistory`). The hardcoded list is therefore the complete grant set today, so the broadcast is a full revocation. The gap only opens for grants made after the broadcast (L-01).

### Fork evidence (9/9 pass, independently reproduced by poc-validator)

`work/test/audit-run38/BalancerHoldingAudit.fork.t.sol`, block 26,094,450:

| Test | Shows |
|---|---|
| `test_r38_01_preview_statediff_only_authVersion` | `vm.startStateDiffRecording` across **all** accounts records exactly one changed slot (`0x7f68` slot 7, `authVersion` 1 → 2) and exactly one log (`AuthVersionIncremented(2)`). |
| `test_r38_02_verify_fails_before_passes_after_simulated_broadcast` | `:verify` reverts `verify: pooler still authorized` before the bump (it also fails live today, forge exit 1) and passes after. |
| `test_r38_03_second_run_sends_nothing` | Second run: 0 storage changes, 0 events, `authVersion` stays 2. |
| `test_r38_04_real_mint_after_revocation_parks_susds_and_accrues_debt` | A real `mint(4)` after revocation: 17.8815 USDS becomes 16.0907 sUSDS parked on `0x7f68`, 8.9408 phUSD of `mintDebt` accrues (50%), 0 BPT is minted, and no `Pooled` event is emitted. |
| `test_r38_05_permissionless_surface_cannot_move_funds` | `pool`, `unlockCallback`, `_psmDonate`, `dispatch`, `pause` and `unpause` all revert for outsiders, and `getIdealBPT` writes no pooler storage. |
| `test_r38_06_pre_revocation_7702_pooler_can_pool_with_zero_floor` | Before revocation, `0x186c` can `pool(0)` with no slippage floor. After revocation the same call reverts, which confirms the protective rationale. |
| `test_r38_07_multipooler_cannot_drive_balancer_pooler` | MultiPooler forwards only the 4-arg `pool`, so its `0x7f68` grant was never usable. |
| `test_r38_08_verifier_blind_to_reauth_outside_the_four` | L-01 (see §3). |
| `test_r38_09_idempotence_guard_skips_bump_with_unknown_live_pooler` | L-01, latent edge (see §3). |

---

## 2. Unintended side effects?

**None on-chain.** `side-effects.json` lists no `unintendedEffects`. The full state diff is one slot and the event log is one event (`test_r38_01`). `poolerAuthVersion[p]` for the four is not touched: they stay at 1, and revocation works purely through the version mismatch. No addresses change, so there is correctly no `mainnet-addresses.ts` backup or patcher tail.

### Intended consequences that look like side effects

- **Idle sUSDS builds up on the pooler during the holding pattern. This is intended.** Plan §4: *"A mint sends USDS to `BalancerPoolerV2`, which wraps it into sUSDS and keeps it … after that date the sUSDS simply accumulates."* Story 103's step 9 (`rescueERC20(sUSDS, UniPoolerV2, balance)`) is there to collect *"sUSDS accrued since the holding pattern began"*. Disabling index 4 is not part of the plan. The parked sUSDS earns sUSDS yield in place, and no permissionless path can move it (`test_r38_05`). Only the owner's `rescueERC20` and `withdrawBPT` can, and the revocation does not affect either.
- **Mint debt keeps accruing.** `BalancerPoolerMintDebtHook` adds 50% of each index-4 mint to `mintDebt`. Story-103 step 5 `pull()`s it before re-pointing the hook. This matches the plan.
- **Off-chain pooling stops working.** `scripts/compute-min-bpt-poolerv2.js`, the phlimbo-ui Admin pool action, and the automation behind `0x186c` (an EIP-7702 delegated EOA, nonce 495, last `Pooled` at block 26,086,089) will all revert after the broadcast. Any bot still calling them will burn gas. This is operational hygiene, so no finding.

### Broadcast ergonomics

```
// package.json L68 (balancer-holding:broadcast, abridged)
export BALANCER_HOLDING_GAS_PRICE_WEI=${BALANCER_HOLDING_GAS_PRICE_WEI:-300000000} && forge script … \
  --sender 0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6 --broadcast --skip-simulation --slow \
  --ledger --hd-paths "m/44'/60'/46'/0/0" --legacy --with-gas-price $BALANCER_HOLDING_GAS_PRICE_WEI \
  --gas-estimate-multiplier 200 -vvv && npm run balancer-holding:verify
```

- **Gas price is fine.** The default is 0.3 gwei legacy. The live base fee was about 0.137 gwei at head 26,094,444. Over the last 1,025 blocks it ran p50 0.093, p99 0.149 and max 0.163 gwei, with no block above 0.3 gwei. That is about 2× headroom, leaving a tip of about 0.15-0.2 gwei. The transaction would only get stuck if the base fee more than doubled before signing, and `BALANCER_HOLDING_GAS_PRICE_WEI` overrides the default.
- **`--skip-simulation` keeps the guards.** It skips only forge's on-chain re-simulation of the recorded transaction. The script's post-`require`s (bumped exactly once, all four unauthorized) still run in forge's local execution before signing, so a wrong local result aborts before anything is sent.
- **The `&& :verify` chain is sound.** `:verify` exits 1 on failure (verified). If the receipt times out, forge exits non-zero and `:verify` does not run. Re-running is safe: if the transaction was mined, `_countAuthorized() == 0` and nothing is sent. Even a second bump would only move the version 2 → 3, which leaves everything revoked.
- **The Ledger HD path is consistent.** `m/44'/60'/46'/0/0` is the same across all four Ledger-signing keys in `package.json`, each with `--sender 0xCad1…D0B6`. It matches the "Shared phStaging2 facts" in stories 099 and 103.

---

## 3. Knock-on effects: has anything else surfaced because of it?

### L-01: the verifier and the step-0 precondition are blind outside the four (Low, owner footgun)

`setAuthorizedPooler` stamps new grants with the **current** version:

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

The verifier, however, only iterates the four:

```solidity
// script/VerifyBalancerHolding.s.sol L23-29
address[4] memory ps = poolers();
for (uint256 i = 0; i < 4; i++) {
    if (_isAuthorized(ps[i])) console.log("STILL AUTHORIZED:", ps[i]);
}
for (uint256 i = 0; i < 4; i++) {
    require(!_isAuthorized(ps[i]), "verify: pooler still authorized");
}
```

After the broadcast, a grant to any X outside the four (for example a new automation key or a UI wallet) makes X a live pooler at version 2. `:verify` stays green, and so does the `authVersion() > 1` hardening proposed in the 099 review. Stories 100 (L49) and 103 (L59/L148) specify the cutover's step-0 precondition with the same predicate ("check the four poolers as `onlyAuthorizedPooler` does"). So the `holding-broadcast` gate, which takes a transaction hash, and step 0 would also pass. X could then `pool()` between story-103 step 2 (`withdrawBPT`) and step 9 (`rescueERC20`) of the multi-tx `--slow` broadcast. That strands fresh BPT on the old pooler, and before 30 Oct it reopens the zero-floor sandwich surface (yield-claim-nft L-06, `342075dfba3c8ec7c3bae1ae18c357591c5ea255bf649ee943c6c71f3ddd4c2e`, open). Fork-verified on the 099 side (`test_r38_08`). Re-authorizing one of the four *is* detected.

The latent edge (`test_r38_09`) has the same root cause. If the four were deauthorized individually while a fifth address held the current version, the L116-119 gate would skip the bump and `:verify` would pass. This cannot happen on today's chain history (0 deauths), so it is folded into L-01 as supporting evidence rather than filed separately.

**Why Low.** No value leaves protocol custody, because the BPT is minted to the pooler and stays owner-recoverable through `withdrawBPT`. The trigger is a knowing owner grant. Story 103's own verify would catch the leftover after the fact. The finding stays in scope because a competent owner would not expect *every* safety signal to hide that grant (Law 3 footgun).

**Mitigation (story 103 / 100 core).** Do not reuse the four-address predicate as the proof of revocation. Record the revoke block and the new `authVersion` as gate evidence. Then require `authVersion() == recordedVersion` and the absence of any `PoolerAuthorized` event from `0x7f68` after the revoke block, checked off-chain with `cast logs` feeding an env var the script `require`s. Alternatively, revoke unconditionally inside step 0:

```solidity
// story-103 step 0: revoke unconditionally, then drain
balancerPoolerV2.incrementAuthVersion();   // invalidates every grant, listed or not
balancerPoolerV2.withdrawBPT(OWNER, bpt);
```

The `withdrawBPT(OWNER, bpt)` call shape matches the deployed signature, `function withdrawBPT(address recipient, uint256 amount) external onlyOwner` (BalancerPoolerV2.sol L424). For `:verify`, log `authVersion()` and add the same post-revoke log check, or at minimum say in its NatSpec that it cannot see grants outside the four.

**Watch `WN-38-BH-01`:** if the story-103 script ships with the four-address predicate as its only revocation proof, re-weigh L-01 toward Medium at that audit.

### Q-01: NatSpec provenance (QA)

```solidity
// script/RevokeBalancerPoolersHoldingPattern.s.sol L14-15
 *           - 0x186c77B80Bbfd21b01C7D7FA44bA27031322a77F (7702-delegated EOA, WhitelistPoolersV2)
 *           - 0x630966B668b321Cc6441754f96519a55F72Cd476 (EOA, WhitelistPoolersV2)
```

On chain, these grants on `0x7f68` are OWNER `script/interactions/Temp.s.sol` transactions (`0xcb56e196…` at block 25,792,038 and `0xbf66c239…` at block 25,792,039). `Temp.s.sol` is untracked and its broadcast logs are not in the repo. The archived `WhitelistPoolersV2.s.sol` targeted the older pooler `0x26F8…b38A` and also granted `0x3E90…Eb28`, which is not authorized on `0x7f68`. Story 099 records the correct provenance, so the comment contradicts its own story. Execution is unaffected. This was downgraded from Low because story 100 L40 lists the four re-authorization addresses explicitly, so no plausible operator path derives the list from `WhitelistPoolersV2`.

### Cluster and successor stories

The story **documents** for 100, 101, 102 and 103 exist in `incomplete/`. Their **scripts are not yet written**, so anything on the 103 side below is unverified.

- **The story-103 gate needs 099 in `complete/` or `auto-complete/`.** 099 sits in `review/` (ISSUES_FOUND) and 102 sits in `incomplete/`. Story 103 aborts by design ("ABORTED: out-of-order execution") until a human moves 099 out of review. Broadcasting 099 does not move the story. This is a process-ordering dependency, not a code defect.
- **The `holding-broadcast` gate** (evidence: the revoke tx hash) can be satisfied as written. Preview shows exactly one transaction will be sent (4/4 authorized now), and `:verify` goes green afterwards (`test_r38_02`).
- **`WN-38-BH-02`, cross-entry-point carryover.** The 54 pre-existing failures belong to `stable-staker-v2-cutover`: the cutover fork tests are pinned at block 25,978,784, before the cutover, while reading the accurate post-cutover progress file, so Antimatter has no code at the fork block. They falsify 099's full-suite checkbox and will also block story 100 L136 and story 103 L191 until the progress file is reconciled with mainnet. They will be raised at that entry point's next audit.
- **`WN-38-BH-03`.** Story-103 step 7 re-authorizes "the same four" on UniPoolerV2, MultiPooler included. MultiPooler forwards only the 4-arg `pool`, while story 105 specifies a 3-arg `UniPoolerV2.pool`, so that grant may be dead weight, as it already was on `0x7f68` (`test_r38_07`). Verify at the story-103 audit.
- **Story 101 (DeployMocks rehearsal)** runs `incrementAuthVersion()` on anvil. DeployMocks is a UI mock, not a rehearsal, so no rehearsal-fidelity findings are raised against it.
- **Story 107** archives this script and its keys after the wind-down. No interaction.
- **Older pooler `0x26F8…b38A`** is registered at no minter index (`dispatcherToIndex == 0`) and holds 0 sUSDS, USDS and BPT, so its stale grants are irrelevant.
- **Deadline.** 099 has to be broadcast before 30 Oct to have any effect, because the Balancer pool pauses then and `pool()` reverts regardless. The 103 cutover itself is not bound to that date.
- **Drift.** The upstream fork test pins block 26,094,200. No auth-relevant events occurred between then and head 26,094,460.

---

## Evidence and tooling caveats

- **Bytecode is not Etherscan-verified.** Neither `BalancerPoolerV2` at `0x7f6874332c4629429d70D15f685A8230323F11F1` nor MultiPooler at `0xd1E5774159381915f5579dFd68507E2614f67b51` is verified on Etherscan. The source-to-bytecode match is corroborated only by selectors and storage layout. Every `IBalancerPoolerV2Holding` selector, plus `setNudgeStreamer`/`nudgeStreamer`/`rescueERC20`/`withdrawBPT`/`setHook`, is present in the runtime code. The storage slots match the layout (`slot 7 = authVersion`, `slot 6 = _pool`, …), and the live getters agree. The streamer selectors identify the top-level `lib/yield-claim-nft` copy as the deployed one. No full bytecode diff against a local `via_ir` build was performed.
- **4naly3er baseline attached after a fix** (`4naly3er-report.md`). The initial crash was an import-resolution failure: the repo has no `remappings.txt`, only `foundry.toml` remappings. Re-run from `work/` with a `forge remappings`-generated file: 0 Medium, 1 Low (`PUSH0`), 11 NC, 6 Gas, none material.
- **Story-103 side unverified.** L-01's cutover leg and `WN-38-BH-03` rest on story text (100 L40/L49, 103 L59/L148/L191), not code.
- **Fork-test provenance.** The audit tests live in `work/test/audit-run38/`, which is audit-authored and not part of upstream. They were independently re-run by poc-validator: 9/9 pass, and the single-slot diff, the real-mint numbers and the fifth-pooler blind spot were all reproduced. The upstream `test/RevokeBalancerPoolers.fork.t.sol` passes 4/4.
