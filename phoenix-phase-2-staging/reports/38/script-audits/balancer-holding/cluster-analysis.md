# Cluster analysis — balancer-holding (run 38)

Live state at head 26,094,460: `authVersion == 1`, all four poolers at 1, pooler holds 0 sUSDS / 20,401.81 BPT / 4.7e-7 USDS dust; NFTMinterV2 index 4 → 0x7f68, enabled, price 17.8815 USDS. Nothing from story 099 has been broadcast.

## Successor: story 103 — `unipooler-cutover:*` (NOT YET WRITTEN), incomplete/
1. **Gate `holding-broadcast`** — the evidence is just the revoke tx hash. Satisfiable by this entry point as written: the preview shows the one tx will be sent (4/4 authorized now), and `:verify` goes green afterwards (fork-verified, `test_r38_02`).
2. **Gate "predecessors 099 and 102 in complete/ or auto-complete/"** — 099 is in `review/` with ISSUES_FOUND (the false "full suite passes" checkbox: 54 pre-existing failures in `CutoverStableStakerV2Mainnet.fork.t.sol` / `VerifyStableStakerV2CutoverGuards.t.sol` from the tracked `server/deployments/progress.stable-staker-v2-cutover.1.json`); 102 is in `incomplete/`. Story 103's own checklist therefore aborts ("ABORTED: out-of-order execution") until a human moves 099 out of review. This is a **process ordering dependency, not a code defect**: broadcasting 099 does not move the story, and the 54 failures will also block 103's own "`forge test` (full suite) passes" item unless the progress file is fixed first, as both 099 reviewers recommended. Deadline note: the 103 cutover is not itself bound to 30 Oct (plan: recovery exit works after), but 099's broadcast is (`pool()` exposure ends on 30 Oct anyway).
3. **Step 0 precondition "authorized-pooler set revoked"** — stories 100/103 specify it as "check the four poolers as `onlyAuthorizedPooler` does", the same four-address predicate as `_isAuthorized` here. Fork-verified on the 099 side (`test_r38_08`): after the bump, an owner `setAuthorizedPooler(X, true)` for any X outside the four leaves `:verify` green and `authVersion() > 1` true, while X can `pool()`. If that happens between the 099 broadcast and the 103 run, 103's step-0 `require` passes, and X can `pool()` between step 2 (`withdrawBPT`) and step 9 (`rescueERC20`) of a multi-tx `--slow` broadcast. That would mint fresh BPT onto the old pooler after its BPT has been drained, which 103's verify ("old pooler … holds 0 sUSDS and 0 BPT") would then catch after the fact. The owner is the only one who can re-authorize, so this needs a knowing owner action. The footgun is that both green signals (099 verify, 103 step 0) would hide it. The 103 side is **unverified** because the script does not exist yet. → candidate finding #1.
4. **Step 7 re-authorizes "the same four" on UniPoolerV2**, MultiPooler included. MultiPooler only forwards the 4-arg `pool(uint256,uint256,uint256,uint256)`. The 0x7f68 auth was never exercisable (`test_r38_07`), and story 105 specifies a 3-arg `UniPoolerV2.pool(sUSDSIn, minPhusdOut, minLP)`, so MultiPooler's grant on UniPoolerV2 would likely be dead weight too. **Unverified**: UniPoolerV2 is not in the pinned `lib/yield-claim-nft` (story 100 pin bump pending). Deferred to the story-103 audit and not filed here.
5. **Steps 2/9 drain 0x7f68** via owner `withdrawBPT` / `rescueERC20`. The revocation leaves both untouched (owner-only, not pooler-gated). Every sUSDS a mint parks during the holding pattern is recoverable by step 9 (`test_r38_04`/`05`).
6. **Mint debt accrues during holding.** 50% of every index-4 mint (8.94 phUSD per 17.88 USDS mint at current price) lands in `mintDebt`, and story-103 step 5 `pull()`s it before `hook.setDispatcher`. This is consistent with the plan, so no finding.

## Successor: story 100 — `script/helpers/UniPoolerCutoverCore.sol` (NOT YET WRITTEN)
Same precondition text as item 3. Recommendation carried in finding #1.

## Successor: story 101 — DeployMocks rehearsal (NOT YET WRITTEN)
Runs `incrementAuthVersion()` on anvil before the core. This is a UI mock, not a rehearsal-fidelity target, so per the standing memo no rehearsal-fidelity findings are raised against it.

## Successor: story 107
Will archive this script, its fork test and the `balancer-holding:*` keys after the wind-down. No interaction.

## Predecessor: archived `DeployMainnetPromotionReady.s.sol` (story 072)
Deployed 0x7f68 at block 25,735,142 and authorized MultiPooler at 25,735,152. The selector mismatch (MultiPooler forwards only the 4-arg Uniboost `pool`) meant that grant was dead from the start (`test_r38_07`). It is historical, so no finding for this entry point.

## Predecessor: `script/interactions/Temp.s.sol` (untracked scratchpad)
This is the actual source of the OWNER/0x186c/0x6309 grants on 0x7f68 (txs `a5a8a191…`, `cb56e196…`, `bf66c239…`). Its broadcast logs are not in the repo. On-chain logs prove these four are the complete grant set, which makes this broadcast a full revocation.

## Evidence: `script/archives/WhitelistPoolersV2.s.sol`
It targeted the older pooler `0x26F8…b38A` and also `0x3E90…Eb28`, which is not authorized on 0x7f68. 0x26F8 is registered at no minter index (`dispatcherToIndex == 0`) and holds 0 sUSDS/USDS/BPT, so its stale authorizations are irrelevant to the wind-down. The script NatSpec cites WhitelistPoolersV2 as the provenance of 0x186c/0x6309. → candidate finding #2 (informational).

## Sibling-config: `scripts/compute-min-bpt-poolerv2.js`, phlimbo-ui Admin pool action, 0x186c automation
These lose function after the broadcast. 0x186c is an active EIP-7702 delegated pooler (nonce 495; last `Pooled` at block 26,086,089, about one day before audit). Any automation behind it will start reverting and burning gas. This is operational hygiene, not a protocol issue, so it gets no finding.

## Skipped steps / drift
- No skipped step makes the system non-functional after this entry point alone. Index-4 mints keep working through a real `mint(4)` (`test_r38_04`).
- Drift: the upstream fork test pins block 26,094,200. It has no auth-field drift up to head 26,094,460: no `AuthVersionIncremented` or `PoolerAuthorized` events since.
