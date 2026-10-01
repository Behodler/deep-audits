# Classification log: balancer-holding (run 38, src a309040)

Classifier: severity-classifier. Input: sanitized-findings.json (2 findings). Output: classified-findings.json.
Counts: 0 H / 0 M / 1 L / 1 Q / 0 F / 0 regressions. Fingerprints are copied verbatim from sanitized-findings.json and were not recomputed.

## L-01 (pps38l1): `59527bfa84786a87002d80b9bf678c5e798c4d9b2905609ac0f786bd46737632`
**Four-address holding-pattern predicate hides post-bump grants (Low, Law-3 footgun)**

- **Evidence:** test_r38_08 (fork, reproduced). After the bump, an owner `setAuthorizedPooler(X, true)` gives X a live authorization. `:verify` passes, `authVersion()==2>1`, and X can `pool(0)` and mint BPT.
- **Added edge, test_r38_09 (reproduced):** if the four are individually deauthorized while X holds the current version, the revoke script's idempotence guard (L116-119) skips the bump, reports success, and `:verify` passes. This edge is latent: on-chain history on 0x7f68 has exactly 4 `PoolerAuthorized` events and 0 deauths, so it is unreachable today. It shares the root cause, so it is folded into this finding as evidence and does not raise severity.
- **Contained hazard:** yield-claim-nft L-06 (`342075df…`, open). test_r38_06 shows the pre-revocation 0x186c EIP-7702 account can `pool(0)` with a zero floor.
- **Law-3 surprise test:** a competent owner knows that granting X lets X pool. The surprise is that every safety signal stays green: 099 `:verify`, the reviewer-proposed `authVersion()>1` check, and the step-0 `require` in stories 100 (L49: "check the four poolers as `onlyAuthorizedPooler` does") and 103 (L148: "all four poolers unauthorized on `0x7f68`"). That makes it a footgun, so it is in scope.
- **Why Low and not Medium:** the impact the footgun unlocks is bounded.
  - No value leaves custody. BPT is minted to the pooler and is recoverable through `withdrawBPT`.
  - The sandwich leg re-exposes an existing Low (L-06) and does not create a new loss class.
  - Index-4 mints are unaffected.
  - A mid-cutover `pool()` strands BPT that story 103's verify catches after the fact, and the owner can recover it.
  - The trigger is a knowing owner action, and no external attacker path exists.
- **Not F-class:** story 099 itself specifies "asserts all four poolers are unauthorized". The verifier is faithful to that spec, and the gap lies in the story design that 100/103 inherit. The recommendation is aimed at those not-yet-written stories. Story 103's side is unverified because the script does not exist yet.
- **Recommendation:** kept as sanitized. Record the revoke block and version, then at step 0 require `authVersion()==recorded` plus no `PoolerAuthorized` event after the revoke block. Alternatively, bump inside step 0 itself. Note in NatSpec that `authVersion()>1` alone is insufficient.

## Q-01 (pps38q1): `b469855d97e475c98d72fd0fd71f0766f3f106d9704be2b4c48b780680f65788`
**NatSpec L14-15 misattributes the 0x186c/0x6309 grants to WhitelistPoolersV2 (QA, non-critical)**

- **Downgraded from the proposed Low.** C4 puts comment issues in QA. The dedup argued the comment could mislead the story-103 step-7 re-auth list. That does not hold, because story 100 L40 lists the four explicitly ("the same four poolers as today (owner, `MultiPooler`, `0x186c…a77F`, `0x6309…d476`)"), and story 099 "Pooler history" records the correct Temp.s.sol provenance. Execution is unaffected because the hardcoded list equals the full on-chain grant set.
- **Kept, not dropped:** the comment contradicts the story it implements, and plan §4 carries the same error. Not F-class, because no story acceptance item specifies the NatSpec text.

## Faithfulness (Law 2): no F entry
- **Story 099** (`review/phStaging2-Balancexit/099-…md`, ISSUES_FOUND). The checklist item "`forge test` passes (full suite), and `RPC_MAINNET=<rpc> forge test --match-path test/RevokeBalancerPoolers.fork.t.sol -vvv` passes." is ticked but literally false.
  - There are 54 failures, all in `CutoverStableStakerV2Mainnet.fork.t.sol` and `VerifyStableStakerV2CutoverGuards.t.sol`, caused by `server/deployments/progress.stable-staker-v2-cutover.1.json`. The failures are identical at base 3943ae3.
  - The landed 099 code and script neither cause nor touch them. Every functional acceptance item is met and fork-verified (see intent.md).
  - The defect is a false process attestation, not a behaviour deviation of the landed code, and the story's own Review Results already record it visibly. So no F entry.
- **Story 103 gate:** "predecessor stories (phStaging2:099 and phStaging2:102 …) are in complete/ or auto-complete/ (NOT merely review/)". This is a process-ordering dependency. 103 aborts by design, so the gate works as written and is not a code defect.
- **Carryover (visible, not filed here):** the same 54 failures will block story 103 L191 and story 100 L136 ("`forge test` (full suite) passes") until the stable-staker-v2-cutover progress file is reconciled with mainnet. That belongs to the `stable-staker-v2-cutover` entry point and should be raised there.

## Flags for human review
- None borderline. L-01 could become Medium only if story 103's step 0 ships with the four-address predicate and an extra grant is actually live at cutover time. Re-weigh it when the 103 script exists.
