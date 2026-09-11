# Cluster analysis — `dev` @ e6eded0

## 1. `script/archives/DeployMainnetPromotionReady.s.sol` — the mirror target (relation: mirror-target)
This is the script the local chain exists to rehearse. Two concrete divergences, both measured:

**(a) The rehearsal no longer exercises the mechanics the mainnet script fears most.** The mainnet
key's own documentation names the fail-closed ordering as the thing that "LEAKS VALUE SILENTLY" in
reverse: `pull() -> hook.setDispatcher(new) -> new.setHook(hook) -> replaceDispatcher(idx, new)`.
At 9563c68 the local chain executed all four once. At e6eded0 it executes none
(`pull` 1->0, `setDispatcher` 1->0, `replaceDispatcher` 1->0).

**(b) PhlimboV3's constructor arguments.** Mainnet Phase 4e reads them LIVE off the predecessor
(`address v2Reward = address(v2.rewardToken()); uint256 v2Duration = v2.depletionDuration();`,
`DeployMainnetPromotionReady.s.sol:1752`). The local helper now hardcodes
`uint256 oneWeekInSeconds = 604800` (`DeployMocks.s.sol:2262`). Its NatSpec justifies the literal as
"the ones V2 carried and V3 inherited at the mainnet cutover" — **that claim is false**:

| | mainnet (fork @ 25949772) | local anvil @ e6eded0 |
|---|---|---|
| PhlimboV2 `depletionDuration()` | 2,592,000 (30 d) | contract no longer deployed |
| PhlimboV3 `depletionDuration()` | 2,592,000 (30 d) | **604,800 (7 d)** |

The divergence itself predates e6eded0 (the local V2 was also constructed with 604800, so the live
read resolved to the same wrong number). What e6eded0 adds is a **false factual claim about mainnet
state** written into the source as the justification for the literal. Mitigating: Phase 4e has
already executed — mainnet PhlimboV3 is live at `0x8D3A8E3b…` with 13,684 phUSD staked — and the
mainnet script is archived, so nothing is pending against this divergence.

## 2. `verify-stable-staker.sh` / `test:stable-staker` (relation: sibling-consumer)
Consumes the same chain via `npm run deploy:local` (clean + forge). Its targets — StableStakerV2,
Antimatter, PhusdStableMinter — are all inside **retained exception #1**, which this run verified
executes and asserts end-to-end (`forge-head.log:169-190`). **No cluster breakage.**

## 3. `simulate-yield.sh` (relation: successor, step 6)
Reads `progress.31337.json` for MockDola/MockAutoDOLA. Both keys survive the 73->70 key reduction.
Ran clean this session: MockAutoDOLA totalAssets 7,200.24 -> 9,500.24 DOLA, exit 0.
**No cluster breakage.**

## 4. `script/archives/interactions/AddressLoader.sol` (relation: stranded-consumer) — **REFUTED**
The hypothesis was that deleting the `PhlimboEA` key strands `AddressLoader.getPhlimboV2()`.
It does not, for three independent reasons:
1. `AddressLoader.get()` reads **`server/deployments/local.json`** (the anvil address book), not
   `mainnet-addresses.ts`, and is hard-gated `require(block.chainid == 31337)`.
2. It fails **loudly**: `require(vm.keyExistsJson(...), "AddressLoader: '<name>' not in
   server/deployments/local.json - run `npm run extract:addresses`")`.
3. Every importer except one is under `script/archives/**` (excluded from the build). The one
   non-archived file, `script/interactions/ClaimWithdrawStableStaker.s.sol`, only *mentions*
   AddressLoader in a comment — it does not import it.
`AddressLoader`'s NatSpec does still assert that PhlimboV2 "is retained only so a late staker could
exit, mirroring mainnet", which the fork disproves (see finding pps30l4).

## 5. Skipped-step analysis: is the system functional without the deleted steps?
- **NFT mint path (indices 1/2/3):** functional on the chain as actually deployed — the pristine
  script plus a probe mint exits 0 (`s3-pristine-with-mintprobe.log:268`). But it is **no longer
  proven** functional by the run itself; see pps30l1.
- **Uniboost stakers:** functional-but-empty. Not bricked, and self-healing on the first
  `hook.pull()`; see pps30l2.
- **Both retained exceptions:** execute and assert. A retained-but-broken exception was the worst
  available outcome and did not occur.

## 6. Cluster items with no interaction
`script/interactions/Temp.s.sol` (committed empty), `script/interactions/StakeStableStaker.s.sol`,
`script/interactions/FundTestUser.s.sol` (ledger L-01 65db3324, bricked by the terminal sweep which
e6eded0 **retains** — unchanged, not re-filed).
