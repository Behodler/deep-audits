<!--
ID: 858e9e80 (ledger fingerprint — this record mints NO new finding ID)
C4 Submission Metadata — ⚠ EXPIRED-CLOSURE / LEDGER-REOPEN PROPOSAL
Title: Value-blind nudge gate — CLOSURE RATIONALE EXPIRED (ledger H-01, currently status=fixed)
Record kind: LEDGER-REOPEN-PROPOSAL (partial, leg 2 only). NOT a new finding. NOT a code regression.
Ledger fingerprint: 858e9e807abee888b378db210bae982f23fe7b5d91052321e204d7ba568579b7
Current ledger status: fixed
Proposed status: reopen (partial) — PROPOSAL ONLY. D-09 forbids an agent flipping the status.
Severity AT HEAD: Medium  (the historical `high` label carries NO weight in this assessment)
Contract: src/BatchNFTMinter.sol  (batchMint / qualification gate)
Root Cause Link: https://github.com/Behodler/phoenix-nft-staking/blob/main/src/BatchNFTMinter.sol#L351-L352
PoC Files: workspace/phoenix-nft-staking/test/PoC_NudgeLineage_H01.t.sol (4/4 PASS @0d1a0b2)
           workspace/phoenix-nft-staking/test/PoC_NudgeLineage_NudgeDrain.t.sol (3/3 PASS)
Replay verdict: STILL-LIVE, 4/4
Run: phoenix-nft-staking-20 @ 0d1a0b2
Provenance: CLASS-009 (classifier label "M-08" WITHDRAWN by orchestrator ruling R-2)
⚠ LABEL COLLISION: this record concerns LEDGER H-01 = 858e9e80…. Run-20's own H-01 is
1c222d54… (NFTStakerDepletion.depositFor) and is a DIFFERENT, UNRELATED finding.
Always disambiguate by fingerprint, never by label.
-->

## Finding description and impact

> ### ⚠ Read this framing first
>
> **The code did not regress. The reasoning that closed this finding expired.**
>
> This record asserts an **invalid closure**, not a code regression. Nothing got worse between the fix and HEAD. What changed is that one of the two legs the closure stood on is no longer true of the code as it exists today.
>
> **story-014's fix is intact, and is PROVEN intact.** The minter and `dispatcherIndex` are owner-pinned ([`BatchNFTMinter.sol#L101`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/BatchNFTMinter.sol#L101), resolved at [`#L315-L323`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/BatchNFTMinter.sol#L315-L323)), and this run's own replay confirms it: `test_AttackerCannotChooseACheapDispatcher_VariantA_IS_CLOSED` passes. **Do not use this report to argue that the pinning should be revisited.** The proposed reopen is deliberately **partial** — leg 1 only ever concerned the pinning, and leg 1 holds.
>
> Filing this as a regression would send a reader to restore a patch that already works. It is not that.

### What expired

The ledger closure rested on two legs:

| Leg | Closure's claim | Status at HEAD |
|---|---|---|
| **1 — zero-price pinned dispatcher** | An attacker cannot select a cheap dispatcher, because the dispatcher is owner-pinned. | **HOLDS ✅** — proven by `test_AttackerCannotChooseACheapDispatcher_VariantA_IS_CLOSED`. This is why the reopen is partial. |
| **2 — over-funded pot is owner-driven** | The residual value-blindness is only exploitable via owner misconfiguration ⇒ owner-driven ⇒ invalid under Law 3. | **✗ DEAD** — over-funding is not an owner action at all. |

**Leg 2 fails on its own premise.** At HEAD the contract's own NatSpec documents top-up as *permissionless* ([`#L44-L49`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/BatchNFTMinter.sol#L44-L49)):

> ```
> /// - **Permissionless top-up.** Anyone can seed the batch incentive with any
> ///   ERC20 simply by sending it here. No owner transaction is involved.
> ```

Ten lines below, the same NatSpec block states the closure's own conclusion ([`#L59-L61`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/BatchNFTMinter.sol#L59-L61)):

> ```
> ///      behaviour; the error was in the sender.
> ```

These two passages sit in the same comment block and contradict each other on the point the closure turns on. Law 3 protects the **owner-trusted** surface; it cannot reach a facet that a permissionless third-party stream and any unrelated address can reach **without the owner**. The inference *"over-funded ⇒ owner-driven ⇒ invalid"* therefore fails at its first step. This is not a re-litigation of Law 3 — it is the observation that the predicate Law 3 was applied to is **false at HEAD**.

The pot's own funding source is likewise not owner-gated: `StableYieldAccumulator.claim()` routes `nudgeSplit%` to the nudge address (`StableYieldAccumulator.sol:512-516`) on an unbounded, time-accumulating schedule with no relationship to mint cost.

### The underlying mechanic, at source level

The qualification gate is value-blind by construction ([`#L351-L352`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/BatchNFTMinter.sol#L351-L352)):

```solidity
uint256 _nudgeSize = nudgeSize;
qualifies = _nudgeSize != 0 && count >= _nudgeSize;
```

A **count** compared to a **count**. Nothing in the expression, and nothing downstream of it, relates the payout to what the caller paid. `nudgeSize` ([`#L106`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/BatchNFTMinter.sol#L106)) constrains a count and never a value — the NatSpec calls it *"the owner's ONLY lever over the nudge"*. A 1× payer and a 1000× payer receive byte-identical payouts.

The design document's safety claim ([`#L51-L61`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/BatchNFTMinter.sol#L51-L61)) — that the pot is *"by construction a fraction of the cost of the `nudgeSize` mints required to qualify"*, so *"every claim is net-positive for the protocol"* — is **backed by no code**. There is no construction. It is an operational expectation stated as a structural property, and this run measured counterexamples in both directions of magnitude:

| Scenario | Cost to qualify | Pot taken | Ratio |
|---|---|---|---|
| `test_PoC_H01_AttackerDrainsFullNudgePool` | 5,256.33 pay-token (count=5) | 50,000 | **9.5×** net-positive to the attacker |
| `test_NudgeDrain_modestPrice_stillNetProfitable` (Variant B) | 5e6 | 100,000e6 | **20,000×** |

Meanwhile the honest `count=50` batch that actually generated the demand pays 110,294.59 and receives **0**. Three refill cycles captured 150,000 (`test_PoC_H01_ThresholdGamingAcrossRefills`).

### Attack path

1. The pot accumulates from an unbounded, time-accumulating stream (`StableYieldAccumulator.claim()` → `nudgeSplit%`), with no relationship to mint cost.
2. Top-up is permissionless — anyone may add to it, no owner transaction involved ([`#L44-L49`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/BatchNFTMinter.sol#L44-L49)).
3. A searcher waits for the pot to exceed `nudgeSize × mintPrice`. Nothing in code brakes this — a lull in batching, bots offline, a gas spike, a UI outage all suffice.
4. The searcher submits the minimum qualifying batch and takes the entire balance-based payout.
5. The honest large batcher who generated the demand receives 0.

### Impact

Protocol incentive funds are claimable by a caller whose payment bears no relation to what they take, at ratios measured up to 20,000×, while the participant the incentive exists to reward receives nothing.

### Severity at HEAD, and honest bounds

**Medium at HEAD.** Assessed against the code as it exists today; the historical `high` label carries no weight in this classification.

- **Not High.** The profitability precondition (pot ≥ `nudgeSize × mintPrice`) is **not satisfied on mainnet today** — the observed margin is ~6× in the safe direction. Archive reads confirm the balance was also 0 at the block before the fix, so **no historical loss occurred via this path**. **No principal theft appears in any of the 11 replay tests.**
- **Not Low.** The mechanic is proven live by execution at HEAD; top-up is permissionless, so nothing owner-side bounds it; and the design document's safety claim is backed by no code. Only bot competition, not the contract, enforces the margin.

> **⚠ Bound this prominently.** D-22's read-only mainnet reads at block 25572875 show **zero present exposure**: `RatchetBatchNFTMinter` (`0x81896F48…`) holds 0 USDC, 0 USDS and 0 ETH; `NudgeRatchet.batchMinter()` has been repointed to `0x86866e01…`. **These PoCs prove the mechanic, not funds currently at risk.**

### Why this must not be double-counted

The **mechanic** is already filed live in this run as **M-01** (Medium), **M-02** (Medium) and **F-20-07** (`a7dffb34…`, spec-conformance track; record at `findings/faithfulness/F-20-07-watch-19-re-derivation-one-of-the-two.json`; no `L-xx` label per ruling R-4). This record mints **no new finding** and deliberately carries no `M-nn` label (orchestrator ruling R-2: publishing it as `M-08` alongside the new Mediums would make the report read as nine Mediums for roughly seven distinct defects).

What it does carry is the **ledger-side consequence**: an entry whose `fixed` status is no longer supported by the reasoning that set it. Both artefacts are required — fixing the report without touching the ledger leaves an entry reading as done.

### Proof of concept

```bash
forge test --match-path test/PoC_NudgeLineage_H01.t.sol -vvv        # 4/4 PASS @0d1a0b2
forge test --match-path test/PoC_NudgeLineage_NudgeDrain.t.sol -vvv # 3/3 PASS @0d1a0b2
```

Replay verdict: **STILL-LIVE, 4/4**. In `PoC_NudgeLineage_NudgeDrain.t.sol`, Variant A is **LIKELY-FIXED** (this is leg 1, the owner-pinning, working as intended) and Variant B is **STILL-LIVE**. Full replay narrative: `reports/phoenix-nft-staking-20/nudge-lineage-poc-replay.md`.

## Recommended mitigation steps

### Primary recommendation — ledger disposition (this is a proposal only)

Under D-09 an agent may not flip a ledger status. The proposal is:

> **REOPEN (partial, leg 2 only)** on fingerprint `858e9e80…`, at Medium-at-HEAD. Leg 1 — the owner-pinning of the minter and `dispatcherIndex` — **holds and must not be disturbed.**

**alternativeIfYouDisagree.** If the operator judges the leg-2 residual acceptable at HEAD, the correct disposition is `acknowledged` or `wont-fix` **with a rewritten rationale that does not rest on the dead owner-driven premise**. Leaving it `fixed` is the one option that is wrong under either reading, because `fixed` asserts the residual was **eliminated** when it was merely **dismissed** — and dismissed on a premise the contract's own NatSpec now contradicts.

### Code-level remediation, if the residual is to be closed

**No validated patch is offered here, and none should be inferred.** The property to establish is that
the payout is *related to the caller's realised spend* rather than to a bare count, so that clearing a
count gate cannot by itself unlock a value-unbounded pot.

> ⚠ **Unvalidated direction — do not implement as written.** This is a property to establish, not a
> reviewed patch. In particular, `totalPaid` is **not** usable as the basis without restructuring:
> it is `batchMint`'s named return, assigned only at step 10 (`:384`/`:386`), *after* `_payRewards`
> runs at `:378`. Any cap expressed against `totalPaid` at the payout site reads **zero** and would
> silently disable the nudge entirely. `totalPaid` is also floored at 0 on a net-positive call
> (run-20 Q-04, `47f2dc3a…`), is manipulable through the step-10 sweep filed as run-20 M-01, and
> under-reports true dispatcher cost whenever the contract's own balance funds an under-funded batch
> (run-20 M-07). Whatever basis is chosen must be derived and PoC'd before it is shipped.

If the "pot is by construction a fraction of the mint cost" property is genuinely intended, it should be **asserted in code** rather than asserted in a comment. Failing that, the NatSpec at [`#L51-L61`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/BatchNFTMinter.sol#L51-L61) should be corrected: it currently states as a structural guarantee something that is only an operational hope, and that comment is what the original closure relied on.
