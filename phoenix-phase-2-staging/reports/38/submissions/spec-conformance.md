# Spec Conformance (Law 2): phoenix-phase-2-staging, script audit run 38 (`balancer-holding`)

- **Repository**: https://github.com/Behodler/phoenix-phase-2-staging
- **Commit**: `a3090408a6b83c74f1419936d2801635f7e8b14b` (branch `master`)
- **Entry point**: `balancer-holding` (`balancer-holding:preview` / `:broadcast` / `:verify`). This is a cold, first audit of the entry point.
- **Fork block**: 26,094,450
- **Faithfulness findings**: **none.** No F-label is assigned for this entry point in run 38.

## Story resolution

The `[story-099]` tag was resolved by globbing the whole `~/code/product-owner/stories/phStaging2/` tree. It matched exactly one document:

| Story | Path (under `~/code/product-owner/stories/phStaging2/`) | State folder |
|---|---|---|
| 099 | `review/phStaging2-Balancexit/099-revoke-balancer-poolers-holding-pattern.md` | `review` (Review Results: ISSUES_FOUND) |

Stories 100 (`incomplete/`) and 103 (`incomplete/`) were also read, because they consume this script's revocation as the cutover's step-0 precondition.

## Why there is no F entry

Story 099's checklist item reads, verbatim:

> - [x] `forge test` passes (full suite), and `RPC_MAINNET=<rpc> forge test --match-path test/RevokeBalancerPoolers.fork.t.sol -vvv` passes.

This item is ticked but literally false. With `RPC_MAINNET` set, 54 tests fail: 39 in `test/CutoverStableStakerV2Mainnet.fork.t.sol` and 15 in `test/VerifyStableStakerV2CutoverGuards.t.sol`. All of them fail on "Progress file names Antimatter at an address with NO CODE". The cause is the tracked `server/deployments/progress.stable-staker-v2-cutover.1.json`, and the failures are identical at base commit `3943ae3`. The landed story-099 code and script neither cause nor touch them. Every functional acceptance item is met and was fork-verified in this run: one owner call, `incrementAuthVersion()` on `0x7f68…11F1`; the preview writes exactly one slot, `authVersion` 1 → 2; all four poolers are unauthorized afterwards, and the NFTMinter index-4 dispatch still succeeds. The defect is therefore a false process attestation, not a behaviour deviation of the landed code. It is also already recorded in a visible channel, the story's own Review Results (ISSUES_FOUND). So no F entry is filed.

The story-103 gate ("predecessor stories … are in complete/ or auto-complete/ (NOT merely review/)") is a process-ordering dependency. Story 103 aborts by design while 099 sits in `review/`, so that gate works as written and is not a code defect.

## Carryover (visible, not filed here)

The same 54 failures will also block the full-suite items in story 100 (L136) and story 103 (L191) until the two stale cutover test files are retired. The progress file itself is accurate: the tests fork at block 25,978,784, before the cutover, where the Antimatter address it records has no code yet, so the script's fail-closed guard fires. That defect belongs to the `stable-staker-v2-cutover` entry point. It is recorded in the ledger as watch note `WN-38-BH-02` so it is raised at that entry point's next audit.

## Related non-F findings from this run (QA report)

- **L-01** (`pps38l1`, `59527bfa…`): the verifier, and the four-address step-0 predicate in stories 100/103, cannot detect a post-bump grant to a fifth pooler. The verifier is faithful to story 099's own spec ("asserts all four poolers are unauthorized"). The gap is in the story design, so this is not F-class.
- **Q-01** (`pps38q1`, `b469855d…`): the NatSpec misattributes the pooler grants to WhitelistPoolersV2. No story acceptance item specifies that text, so this is not F-class.
