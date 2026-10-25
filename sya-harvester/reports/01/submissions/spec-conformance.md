# Spec-Conformance Report (Law 2: Faithfulness to Stories): sya-harvester

- **Run**: `sya-harvester-01` (full audit, cold)
- **Source**: https://github.com/Behodler/sya-harvester @ `62c19c86be1594dcf82e8af794fcd6c28f9a8fc0` (branch `master`)
- **Story tree**: `~/code/product-owner/stories/sya-harvester/` (`storyDir` = `sya-harvester`, read-only)
- **Scope judged**: `src/SYAHarvester.sol`, `src/interfaces/ICurveRouterNG.sol`, the operator script `script/harvest.sh` and its Anvil-fork test `test/script/harvest_anvil.sh` (story-005, judged like a contract), plus the test and mock files where a story names them as acceptance evidence.
- **Companion reports**: [M-01-submission.md](./M-01-submission.md) and [qa-report.md](./qa-report.md). Each F-XX below is a **faithfulness cross-reference** carried on a parent finding. It is not a separate ledger entry and is not double-counted. Its severity is the parent's.

## Summary

| F-tag | Story | Class | Parent | Parent issueId | Parent fingerprint |
|---|---|---|---|---|---|
| F-01 | story-003, story-005 vs `src/CLAUDE.md` Purpose | Spec self-conflict (owner must reconcile) | L-02 | `sh1l2` | `464b94269170a41b1f22c0e8fdc901faf0f402b9d2365d41e406b618c1f6619c` |
| F-02 | story-001 (rule), breaks story-002 | **Story-unsafe**: Law 1 overrides, the story must be amended | M-01 | `sh1m1` | `004d4547d93b2d4431753bd11b17f2c86b50e65d1eaa37b530f34188feb739a3` |
| F-03 | story-002 | **Story-unsafe**: Law 1 overrides, the story must be amended | L-01 | `sh1l1` | `d7744b9d2400d7bde1e1b89ec20eb85b0c45aee30e148d5d78eff4f72288c8da` |
| F-04 | story-002 | Informational: the story's premise is factually wrong | Q-01 | `sh1q1` | `e95e3c9bae91d923ba6c1a25d0610ade70582d461dba4afc61ca802493134d97` |
| F-05 | story-005 | Acceptance gap (operator script) | L-04 | `sh1l4` | `8cc1530764fe5a82b97f32c17df0ca2ab803093cd8404ed11705cfb166a4adee` |

The implementation follows its stories closely. **No deviation is an implementation slip in which the code ignores its story.** F-02 and F-03 are cases where the code does exactly what the story says and the story's own rule is unsafe. F-01 is a contradiction inside the project spec. F-04 is a false safety premise in a story. F-05 is the only case in which the deliverable falls short of its own acceptance wording.

## Story Resolution

Each tag was resolved by globbing the whole `sya-harvester` story tree across every state and sprint folder. Every tag resolves to exactly one document, so no tag is ambiguous.

| Story | Document (under `~/code/product-owner/stories/sya-harvester/`) | State | Commits |
|---|---|---|---|
| story-001 | `auto-complete/sya-harvester-harvester-v1/001-dependencies-skeleton-route-registry.md` | auto-complete | `f2ddcab`, `bf114d0`, `c7707d9` |
| story-002 | `auto-complete/sya-harvester-harvester-v1/002-core-harvest-v4-unlock.md` | auto-complete | `3b67097`, `4a07960` |
| story-003 | `auto-complete/sya-harvester-harvester-v1/003-nft-pull-refund-gas-check.md` | auto-complete | `13c9aef`, `3969fbb` |
| story-004 | `auto-complete/sya-harvester-harvester-v1/004-mainnet-fork-integration.md` | auto-complete | `3ffb307`, `b4f0f7d` |
| story-005 | `auto-complete/sya-harvester-harvester-v1/005-operator-script-private-submit.md` | auto-complete | `cc6066b`, `62c19c8` |

**Commit accounting (13 commits on `master`):**

- **11 commits carry a `[story-NNN]` tag.** All 11 are mapped above. No tag lacks a document, so there are no orphan tags.
- **2 commits are untagged**, and neither adds first-party code:
  - `068f3ad` "Initial scaffold: Foundry project with forge-std". It adds config files, `CLAUDE.md`, `README.md` and empty `src/`, `script/` and `test/` `.gitkeep` placeholders.
  - `5079cf7` "Document Curve Router NG route design". It changes `CLAUDE.md` text only.
- **Untagged first-party code: none.** Every first-party file under `src/`, `script/` and `test/` was added by a `[story-NNN]` commit.

**State notes.** All five stories are in `auto-complete`, which is a final state equivalent to `complete`. The product-owner story-batch workflow approved them after agent review. No formal human review is recorded. No story sits in `incomplete` or `review`.

## Per-Story Conformance Verdicts

| Story | Verdict | Notes |
|---|---|---|
| **story-001**: dependencies, skeleton, route registry | **CONFORMS** (story rule unsafe: see F-02) | The constructor rejects zero addresses. `setRoute` checks `token != 0`, `path[0] == token`, and that the last non-zero entry of `path` equals the live `rewardToken`. `clearRoute`, `getRoute`, `setEthPool` (currency0 native, currency1 rewardToken) and `getEthPool` are present. The toolchain is solc 0.8.26, cancun, optimizer on, via_ir off. The remappings are identical in both files. The "no harvest function" criterion was point-in-time and story-002 superseded it, so `test_noHarvestFunction` is now vacuous (see the cross-reference notes). |
| **story-002**: core harvest inside a V4 unlock | **CONFORMS** to Flow steps 1–8 (story rules unsafe: F-03; story premise wrong: F-04) | It covers the access check, the live `rewardToken` read, the borrow of `calculateClaimAmount * 1.01`, and approve/claim/reset. The sell loop skips the zero token, the reward token and zero balances, and reverts `RouteNotConfigured`. It settles by the actual delta (disclosed as Decision 4), reverts `EthPoolNotSet`, and gates `receive` to the PoolManager. |
| **story-003**: NFT pull/refund and gas check | **CONFORMS** (feeds F-01) | `g0 = gasleft()` is the first statement (L230). The pull runs only when `nftIndex != 0 && nftMinter != 0`. The whole-balance refund runs after the unlock and before payout. The `Unprofitable` formula matches the document. The required NatSpec is present. |
| **story-004**: mainnet-fork integration | **CONFORMS** | The fork suite is pinned at block 26261000 and skips loudly when no RPC is set. Every address is verified, routes are asserted on chain, and there is a deepest-pool assertion. The end-to-end harvest asserts the NFT burn and zero balances. There is an explicit no-nested-unlock test, an each-strategy-exempt loop, and `Unprofitable` / `InsufficientEthOut` tests. `GAS_OVERHEAD` = 60k, with a calibration comment and an assertion. The "double fee" comment copies the story's own wrong mechanism (see the ECON-002 / Q-05 note). |
| **story-005**: operator script and private submit (`script/harvest.sh`, `test/script/harvest_anvil.sh`) | **CONFORMS on every Technical-Details step; one acceptance gap: F-05** (feeds F-01) | Fees are `2*base + tip`. Both the estimate and the simulation call carry fees (the order is swapped, disclosed as Decision 3, and at least as strict). Wei arithmetic is integer `bc`. The `minEthOut` formula aborts when the floor is not met. Signing is keystore-only and a raw key is refused. `PRIVATE_RPC_URL` defaults to Flashbots, with a chain-id cross-check. `DRY_RUN` is supported. A summary is printed before sending and no secret is echoed. The Anvil test proves the success path, and proves abort-before-send with the nonce unchanged. |

**Verified conformant (no deviation):**

- `src/CLAUDE.md` "Nested unlock hazard": no route step touches V4. The fork test `test_fork_harvest_usdeStrategyNonExempt_noNestedUnlock` and the full three-strategy harvest prove that the live USDC, USDe and DOLA strategies do not nest an unlock.
- `src/CLAUDE.md` "One slippage check": routes run with `_expected = 0` and SYA `minRewardTokenSupplied = 0`. `minEthOut` is the only bound.
- `src/CLAUDE.md` "Reward-token skip": `rewardToken` is read live (L280) and never hard-coded.
- story-005 "minEthOut guarantees the gas is covered": the floor `gasLimit * maxFeePerGas` is at least `gasUsed * effectiveGasPrice` for any includable transaction, and it also dominates the on-chain `Unprofitable` check. The only exception is the NFT cost (F-01).
- story-005 key handling: no raw-key path exists and the password is never printed. The Anvil test asserts both. There is no public-mempool fallback.
- The nested pin `lib/stable-yield-accumulator` @ `6eab35c` equals the sibling project's top-level HEAD `6eab35c`, so the cross-repo claims below read the same code.

---

## F-01: The project Purpose promises "> gas + NFT cost", but every lower-level spec prices gas only

- **Story / spec**: `src/CLAUDE.md` Purpose, against `src/CLAUDE.md` "Gas check" design decision, story-003 Acceptance and story-005 Overview / Technical Details step 4
- **Location**: [`src/SYAHarvester.sol#L248-L252`](https://github.com/Behodler/sya-harvester/blob/master/src/SYAHarvester.sol#L248-L252) (`harvest`, `Unprofitable` check) and [`script/harvest.sh#L237`](https://github.com/Behodler/sya-harvester/blob/master/script/harvest.sh#L237) (step 4, `GAS_FLOOR`)
- **Classification**: **Spec self-conflict.** Law 2, not story-unsafe under Law 1. The **owner must reconcile** the spec.
- **Parent**: **L-02** · issueId `sh1l2` · fingerprint `464b94269170a41b1f22c0e8fdc901faf0f402b9d2365d41e406b618c1f6619c`

**Spec text.** The `src/CLAUDE.md` Purpose says:

> A claim therefore has positive expected value whenever `market value of the yield tokens - discounted USDC payment > gas + NFT cost`.

Every lower-level specification names gas only. story-003 Acceptance says:

> The gas check reverts `Unprofitable` when `ethOut < (gasUsedSoFar + GAS_OVERHEAD) * tx.gasprice`, and passes at gas price 0.

story-005 Overview step 4 says:

> Derives a `minEthOut` that guarantees the gas is covered.

**Actual behaviour.** Both gates price gas only. The on-chain check is `(g0 - gasleft() + 60k) * tx.gasprice`. The script floor is `gasLimit * maxFee + MIN_PROFIT_WEI`, and `MIN_PROFIT_WEI` defaults to `0`. Neither gate prices the claim NFT that SYA burns. Story-005's own Anvil "profitable" case reports success after burning NFT index 1 (mint price about 10.78 USDC) for a net of about 0.00365 ETH (about 8.5 USD), which is a loss.

**Deviation.** The code implements stories 003 and 005 faithfully, and those stories implement the settled Gas-check decision faithfully. Only the Purpose invariant ("> gas + NFT cost") fails to hold. The project specification contradicts itself: the Purpose names NFT cost, while the design decision, story-003, story-005 and the README name only gas. This is a gap at the spec level, not an implementation slip.

**Law assessment.** This is not story-unsafe under Law 1. The loss falls on the operator (at most one NFT per transaction). No third party extracts value and the protocol is not harmed. Severity stays with L-02.

**Recommendation.** The owner should reconcile the spec in one of two ways:

- Amend story-005, or add a follow-up story, so the floor includes `NFTMinterV2.getPrice(nftIndex)` converted to ETH, or so `MIN_PROFIT_WEI` must be set at least that high.
- Reword the `src/CLAUDE.md` Purpose to match the gas-only design.

Until then, the README should state that `MIN_PROFIT_WEI` must cover the NFT's value.

---

## F-02: story-001's "last non-zero entry" route rule cannot uphold story-002's zero-balance invariant (story-unsafe)

- **Story / spec**: story-001 Technical Details (Contract surface), against story-002 Acceptance and the `src/CLAUDE.md` Design decisions
- **Location**: [`src/SYAHarvester.sol#L133-L140`](https://github.com/Behodler/sya-harvester/blob/master/src/SYAHarvester.sol#L133-L140) (`setRoute`)
- **Classification**: **Story-unsafe. Law 1 overrides Law 2**: the faithful implementation is still a defect, and **story-001 itself must be amended**. This is also a non-obvious owner footgun, which is in scope under Law 3.
- **Parent**: **M-01** · issueId `sh1m1` · fingerprint `004d4547d93b2d4431753bd11b17f2c86b50e65d1eaa37b530f34188feb739a3`

**Spec text.** story-001 Technical Details says:

> `setRoute` validates `path[0] == token` (and that `token != address(0)`). It also checks that the last non-zero entry of `path` equals `sya.rewardToken()`, read at call time. Use the CurveAMMAdapter loop as the template.

The invariants this rule is meant to protect are stated in `src/CLAUDE.md`:

> Route coverage invariant … otherwise the harvest reverts rather than stranding tokens in the contract.

> The contract holds no balances between calls.

and in story-002 Acceptance:

> After a successful harvest the contract holds zero balances of every token.

**Actual behaviour.** `setRoute` implements story-001's last-non-zero rule exactly. Curve Router NG stops at the first empty pool slot, so a path with an interior gap passes validation, delivers the intermediate token (crvUSD in the M-01 fork run) and strands it in the harvester permanently. The harvest still succeeds, and `harvest.sh` sends it.

**Deviation.** The code is faithful to story-001, but story-001's rule cannot uphold the invariants that story-002 and `src/CLAUDE.md` promise. The story's validation rule is the root cause, so a fix must amend the story's rule as well as the code. `MockCurveRouter` copies the same rule (CODE-007(2)), which hides the problem in the unit tests.

**Law assessment.** Law 1 overrides Law 2. The validator is presented as the guard on where a route ends, so an owner who registers a gapped route would not expect the result: a non-obvious owner footgun. The impact is silent, recurring stranding of the caller's paid-for yield. There is no third-party theft. Severity is carried by M-01.

**Recommendation.** Amend story-001's rule and the code together. Require contiguity: for the first empty pool slot `k`, require `path[2k] == rewardToken` and every entry after it to be zero. Also add an end-of-callback zero-balance assertion, and make `MockCurveRouter` follow Router NG semantics.

---

## F-03: story-002's raw-balance coverage rule lets any outsider brick the harvest (story-unsafe)

- **Story / spec**: story-002 Technical Details (Flow step 5), against the `src/CLAUDE.md` Design decisions
- **Location**: [`src/SYAHarvester.sol#L312-L318`](https://github.com/Behodler/sya-harvester/blob/master/src/SYAHarvester.sol#L312-L318) (`_sellYield`)
- **Classification**: **Story-unsafe. Law 1 overrides Law 2**: **story-002's Flow rule itself must be amended.**
- **Parent**: **L-01** · issueId `sh1l1` · fingerprint `d7744b9d2400d7bde1e1b89ec20eb85b0c45aee30e148d5d78eff4f72288c8da`

**Spec text.** story-002 Flow step 5 says:

> Skip if `IERC20(token).balanceOf(this) == 0`. Otherwise, if `!routes[token].configured`, revert `RouteNotConfigured(token)`.

This conflicts with `src/CLAUDE.md`:

> Public, stateless between calls … The contract holds no balances between calls.

**Actual behaviour.** The implementation follows the story: it acts on the raw `balanceOf`, not on what SYA delivered in this call. A 1-wei donation of a non-delivering strategy's token makes every harvest revert, either through `RouteNotConfigured` or through a Router NG dust revert.

**Deviation.** The code is faithful to story-002. The story's balance-based rule assumes the "holds no balances" invariant, and any outsider can break that invariant by donating tokens. The story's own mechanism therefore enables the denial of service.

**Law assessment.** This is the story-level root of a liveness griefing vector. No funds are lost. The fix must change the story's rule, for example by selling only the claim's balance delta or by applying a dust threshold. Severity is carried by L-01.

**Recommendation.** As in L-01: amend story-002 Flow step 5 to act on the balance delta from `sya.claim` (or apply a dust threshold), and change `_sellYield` to match.

---

## F-04: story-002's "over-estimates by about 10%" safety premise is false (informational)

- **Story / spec**: story-002 Background and Concerns
- **Location**: [`src/SYAHarvester.sol#L265-L286`](https://github.com/Behodler/sya-harvester/blob/master/src/SYAHarvester.sol#L265-L286) (`unlockCallback`: NatSpec at L265-268, borrow at L281)
- **Classification**: **Informational (Law 2).** The story's premise is factually wrong, and the implementation and NatSpec inherit it. There is no exploit.
- **Parent**: **Q-01** · issueId `sh1q1` · fingerprint `e95e3c9bae91d923ba6c1a25d0610ade70582d461dba4afc61ca802493134d97`

**Spec text.** story-002 Background says:

> `calculateClaimAmount` (lines 777-814) applies the same skips and sums `totalBalanceOf − principalOf`. It returns 0 when there is no yield. On live strategies it **over-estimates by about 10%**, because `_distributeBuffer` sends 10% of the skim to `setAsideBufferRecipient` and SYA charges on the reduced amount. This is the safe direction: over-borrowing is free and the excess is settled back.

story-002 Concern [Borrow over-estimate] says:

> `calculateClaimAmount` over-estimates by about 10% on live strategies (the set-aside buffer), on top of `BORROW_BUFFER_BPS = 100`. This is the safe direction: the excess is repaid at settle. No change needed.

**Actual behaviour.** The live SYA `calculateClaimAmount` (`../stable-yield-accumulator/src/src/StableYieldAccumulator.sol:807-813`) returns the discounted, denormalised payment, not gross surplus. How far it over-estimates depends on the strategy. Measured paid/estimate ratios are USDC 99.00%, USDe 75.12% and DOLA 100.00%. For DOLA, the 1% `BORROW_BUFFER_BPS` is the only headroom. The harvester NatSpec (L266-267) repeats the false "~10%" claim. The story-002 reviewer noticed the "gross" mismatch but filed it only as an observation about the mock.

**Deviation.** The code meets the story's behavioural criterion: it borrows `calc * 1.01` and settles the excess back. The story's safety reasoning is false for at least one live strategy, so its "safe direction" assurance does not hold as written. A strategy that delivers more than `estimate * 1.01` would make the claim revert on SYA's allowance pull. That is a loud denial of service, not a loss.

**Law assessment.** No exploit. The failure mode is fail-loud only.

**Recommendation.** Correct the story-002 premise and the NatSpec. Optionally, size `BORROW_BUFFER_BPS` from the measured worst-case delivery/estimate ratio, and add a `MockSYA` mode in which delivery exceeds the estimate.

---

## F-05: story-005 acceptance, "readable reason on any simulated revert", is only partly met

- **Story / spec**: story-005 Acceptance and Technical Details step 2
- **Location**: [`script/harvest.sh#L152-L181`](https://github.com/Behodler/sya-harvester/blob/master/script/harvest.sh#L152-L181) (`decode_revert` / `KNOWN_ERRORS`)
- **Classification**: **Acceptance gap (Law 2).** The operator script falls short of its own acceptance wording. Safety is unaffected.
- **Parent**: **L-04** · issueId `sh1l4` · fingerprint `8cc1530764fe5a82b97f32c17df0ca2ab803093cd8404ed11705cfb166a4adee`

**Spec text.** story-005 Acceptance says:

> It aborts with a readable reason on any simulated revert or an unprofitable estimate.

The narrower mandate in story-005 Technical Details step 2 says:

> On revert, abort and print the decoded reason (`cast call` prints it; map the custom errors `Unprofitable`, `InsufficientEthOut` and `RouteNotConfigured` by name, e.g. with `cast 4byte-decode` or a known-selector table).

**Actual behaviour.** `KNOWN_ERRORS` lists only SYAHarvester's 10 custom errors. Errors raised inside `SYA.claim` and the strategies are not decoded and fall through to the raw passthrough. Examples:

- `ZeroAmount()` `0x1f2a2005`, the normal "nothing to claim" outcome
- `NoValidNFT()` `0x0d78b379`, raised when the operator lacks the NFT
- `ExemptStrategyNotRegistered`
- Pausable `EnforcedPause`
- Tokemak `InvalidDataReturned()` `0x8d54ba1f`, the stale-oracle mode that story-004 flagged for story-005
- Router NG empty-data dust reverts

Verified locally with cast 1.5.1 and anvil: a `ZeroAmount` revert in a fee-carrying `cast call` or `cast estimate` prints `execution reverted: * , data: "0x1f2a2005"`, and `decode_revert` passes it through unchanged.

**Deviation.** The script meets the narrower step-2 mandate: it decodes the three named errors and seven more. It does not meet the acceptance wording "readable reason on any simulated revert". For the most common abort causes, the operator sees only a bare 4-byte selector and cannot tell which strategy to exempt. Abort-before-send still holds.

**Law assessment.** No exploit. The script still aborts before sending.

**Recommendation.** Add the SYA, strategy and oracle error signatures to `KNOWN_ERRORS`, or fall back to `cast decode-error` or the openchain signature lookup. For `InvalidDataReturned`, print an "exempt the USDC strategy" hint, as story-004's review requested.

---

## Cross-Reference-Only Notes (no new finding)

These items trace an existing finding back to a story. Each is recorded here so the story's role is visible. None adds a finding or changes a severity.

| Ref | Parent | Story | Note |
|---|---|---|---|
| ECON-002 | **Q-05** (`sh1q5`, `bec3cacbc1eff78a646aeed7ef43720e4fc61715ab3354067e9c44f3766bf5d0`) | story-004 | The wrong "double fee" mechanism originates in story-004's own text. Background > Routes "Profitability note" says the shared pool `0xF55B…0442` "pays the pool fee twice and moves its price against the second trade", and Concern [Double fee on pool 0xF55B…] repeats it. `test/fork/SYAHarvester.fork.t.sol` and `MainnetRoutes.sol` copy the text faithfully. The fix belongs in the story text and the code comments. There is no code deviation. |
| CODE-007(1) | Q-06 (`sh1q6`) | story-001 / story-002 | `test_noHarvestFunction` encoded story-001's point-in-time acceptance ("**no harvest function**"). Story-002 superseded that criterion and disclosed the stale test as **Decision 7** ("001's `test_noHarvestFunction` left untouched"). No later story removed the test. It is vacuous, not a deviation. |
| CODE-004 | **L-03** (`sh1l3`, `4994fe853f916ac91f7b79b6789e0644535a7687c65ba889481fcc0baac0d51b`) | story-001 | Story-001's Implementation Notes accepted the set-time `rewardToken` check as "harmless, because the harvest-time coverage check (002) and the settle step would fail loudly". L-03 shows the owner also cannot pre-stage the new configuration, so the accepted risk is **broader than the story assumed**. Severity stays with L-03. |
| CODE-006 | **Q-02** (`sh1q2`, `0df667c2a685c4502488bf818e39f2211c6cd2a02544bd015d8cd79a033f23ce`) | story-002 | Story-002 **Decision 4** says that if the price limit ever cut the swap short, settling the actual delta "would still net every currency to zero". That holds **only for the PoolManager**. The unswapped reward token then stays in the harvester, against story-002's acceptance "zero balances of every token". This cannot happen at harvest sizes, so it is already covered as informational by Q-02. |

## Owner Actions

1. **Amend story-001** (F-02 / M-01) and **story-002 Flow step 5** (F-03 / L-01). Under Law 1, a code fix alone leaves an unsafe story on record, and a future re-implementation would reintroduce the bug.
2. **Reconcile the `src/CLAUDE.md` Purpose with the gas-only design** (F-01 / L-02): either price the NFT into the floor or reword the Purpose.
3. **Correct the false premises** in story-002 (F-04 / Q-01, Decision 4 / Q-02) and story-004 (Q-05).
4. **Close story-005's acceptance gap** (F-05 / L-04).

Triage with `/ledger sya-harvester <issueId>`.
